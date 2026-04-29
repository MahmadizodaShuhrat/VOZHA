import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import '../business/battle_ws_service.dart';
import '../data/battle_state.dart';
import '../data/member_dto.dart';
import '../data/battle_phase.dart';
import '../data/ws_models.dart';
import 'lobby_provider.dart';
import 'websocket_provider.dart';

/// Провайдер состояния Battle.
final battleProvider = NotifierProvider<BattleNotifier, BattleState>(
  BattleNotifier.new,
);

class BattleNotifier extends Notifier<BattleState>
    with WidgetsBindingObserver {
  BattleWsService? _ws;
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// Pending finish members — stored when server sends results before timer.
  List<MemberDto>? _pendingFinishMembers;
  Timer? _finishTimer;
  Timer? _fallbackFinishTimer;

  @override
  BattleState build() {
    // Lifecycle subscription: вақте корбар (admin) дар waiting room аст
    // ва app-ро ба background мегузорад ё мекушад → `leaveRoom()` фиристад,
    // то room-и пуч-и шохис боқӣ намонад.
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _sub?.cancel();
      _finishTimer?.cancel();
      _fallbackFinishTimer?.cancel();
    });
    return BattleState.initial();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    // Танҳо ҳангоми paused/detached амал мекунем.
    if (appState != AppLifecycleState.paused &&
        appState != AppLifecycleState.detached) {
      return;
    }
    final s = state;
    final inLiveRoom = s.roomId.isNotEmpty &&
        (s.phase == BattlePhase.waitingRoom ||
            s.phase == BattlePhase.countdown ||
            s.phase == BattlePhase.checkingRoom);
    // Танҳо admin-ҳои ҳолати интизорро мебарорем — дар playing/waitingResults
    // grace + reconnect худаш кор мекунад. Не-admin-ҳоро намебарорем то
    // ҳангоми кӯтоҳ ба background рафтан хориҷ нашаванд.
    if (inLiveRoom && s.isAdmin) {
      leaveRoom();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  Подключение
  // ═══════════════════════════════════════════════════════════

  Future<void> connectAndListen() async {
    state = state.copyWith(phase: BattlePhase.connecting, errorMessage: null);

    _ws = ref.read(battleWsProvider);
    // Re-authenticate the socket on every reconnect so the backend can
    // call `tryRestoreAdminSession` during its admin grace window. The
    // server only triggers the restore after the first authenticated
    // frame on a fresh socket — a silent reconnect (no user action) would
    // otherwise expire the 60s grace and nuke the room even though we're
    // technically back. `check_room` is the cheapest JWT-bearing message
    // we already have and doubles as a sanity-check that the room still
    // exists.
    _ws!.onReconnected = _onSocketReconnected;
    await _ws!.connect();

    if (!_ws!.isConnected) {
      state = state.copyWith(
        phase: BattlePhase.error,
        errorMessage: 'battle_connection_failed',
      );
      return;
    }

    _sub?.cancel();
    _sub = _ws!.messages.listen(
      _onMessage,
      onError: (e) {
        state = state.copyWith(
          phase: BattlePhase.error,
          errorMessage: e.toString(),
        );
      },
      onDone: () {
        if (state.phase != BattlePhase.finished &&
            state.phase != BattlePhase.error) {
          state = state.copyWith(
            phase: BattlePhase.reconnecting,
            errorMessage: 'battle_connection_closed',
          );
        }
      },
    );
  }

  /// Called by `BattleWsService` the moment a reconnect succeeds. If we
  /// were mid-room when the drop happened, fire a JWT-bearing frame so
  /// the backend's `tryRestoreAdminSession` can recognise the user and
  /// cancel its grace timer.
  Future<void> _onSocketReconnected() async {
    final roomId = state.roomId;
    if (roomId.isEmpty) return;
    // Only re-authenticate while the user is still "inside" a match.
    // Once results land we're done; sending check_room after `finished`
    // would just bounce a room_not_found back.
    const liveRoomPhases = {
      BattlePhase.waitingRoom,
      BattlePhase.countdown,
      BattlePhase.playing,
      BattlePhase.waitingResults,
      BattlePhase.reconnecting,
    };
    if (!liveRoomPhases.contains(state.phase)) return;
    final jwt = await _getJwt();
    if (jwt == null || _ws == null || !_ws!.isConnected) return;
    debugPrint('[Battle] WS reconnected — re-auth for room $roomId');
    _ws!.send(
      CheckRoomRequest(jwtToken: jwt, roomId: roomId).toJsonString(),
    );
  }

  void disconnectAll() {
    _sub?.cancel();
    _ws?.disconnect();
    state = BattleState.initial();
  }

  /// Leave the current room, telling the server first so it can clean up.
  /// When the admin leaves before `start_game`, the server tears the room
  /// down and drops it from the public list — without this message the
  /// server only notices after the socket times out and the room lingers
  /// as a ghost entry that nobody can actually start.
  Future<void> leaveRoom() async {
    final jwt = await _getJwt();
    // `isConnected`-ро санҷида намерасонем — `BattleWsService.send` худ
    // дар buffer-и `_pendingMessages` сабт мекунад агар connected набошад.
    // Ин ҳангоми reconnect/background муҳим аст: пеш аз ин агар ҳамон
    // лаҳза connection пайдо набуд, `leave_room` куштор намешуд ва room
    // дар сервер шохис мемонд.
    if (jwt != null && _ws != null) {
      _ws!.send(LeaveRoomRequest(jwtToken: jwt).toJsonString());
      // Give the sink a brief moment to flush the frame before close().
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    disconnectAll();
  }

  /// Дедупликатсия ва нормализатсияи рӯйхати members аз сервер.
  ///
  /// Сервер баъзан як юзерро якчанд маротиба дар як массив пас мефиристад
  /// (масалан вақте корбар reconnect мекунад ва сервер entry-и қаблиашро
  /// тоза накард). Бе dedup UI ҳамон як юзерро 5-20 маротиба нишон
  /// медод. Аз ҳамин рӯ ҳамаи усулҳое, ки `data.members`-ро мегиранд,
  /// бояд тавассути ин helper гузаранд.
  ///
  /// `hasLeft`-и местиро ҳам merge мекунад: сервер flag-ро намефиристад,
  /// мо аз state-и қаблӣ нигоҳ медорем.
  List<MemberDto> _normalizeMembers(List<MemberDto> serverMembers) {
    if (serverMembers.isEmpty) return const [];
    // LinkedHashMap тартиби форсиродан-ро нигоҳ медорад, охирин entry-и
    // ҳар id ғолиб мемонад (нави сервер навтарин маълумотро дорад).
    final seen = <int, MemberDto>{};
    for (final m in serverMembers) {
      seen[m.id] = m;
    }
    final leftIds = <int>{
      for (final m in state.members)
        if (m.hasLeft) m.id,
    };
    if (leftIds.isEmpty) return seen.values.toList(growable: false);
    return seen.values
        .map((m) => leftIds.contains(m.id) ? m.copyWith(hasLeft: true) : m)
        .toList(growable: false);
  }

  /// Сброс состояния в idle (без отключения WS).
  void reset() {
    _sub?.cancel();
    _sub = null;
    state = BattleState.initial();
  }

  /// Тафтиш мекунад оё ҳамаи бозигарони фаъол ба ҳамаи саволҳо ҷавоб доданд.
  /// Агар ҳа — finishTest() зану мезанад то сервер results-ро ба ҳама бифиристад.
  void _checkAllPlayersFinished() {
    if (state.phase != BattlePhase.playing) return;

    final totalQ = state.questionsCount;
    if (totalQ <= 0) return;

    // Танҳо бозигарони фаъол (на баромада)-ро тафтиш мекунем
    final activePlayers = state.members.where((m) => !m.hasLeft).toList();
    if (activePlayers.isEmpty) return;

    final allDone = activePlayers.every((m) => m.answered >= totalQ);

    if (allDone) {
      debugPrint(
        '[Battle] ✅ All ${activePlayers.length} active players finished '
        '($totalQ questions) — calling finishTest()',
      );
      finishTest();
    }
  }

  Future<String?> _getJwt() async {
    return StorageService.instance.getAccessToken();
  }

  // ═══════════════════════════════════════════════════════════
  //  Действия (клиент → сервер)
  // ═══════════════════════════════════════════════════════════

  /// Создать комнату.
  Future<void> createRoom({
    required int questionsQuantity,
    required int questionsCategoryId,
    required List<int> questionsId,
    required int moneyCount,
    required String gameDirectionMode,
    bool isPublic = true,
  }) async {
    // Как в Unity: DisconnectAll() перед созданием комнаты
    disconnectAll();

    await connectAndListen();

    final jwt = await _getJwt();
    if (jwt == null || _ws == null) {
      debugPrint('[Battle] JWT не найден — невозможно создать комнату');
      state = state.copyWith(
        phase: BattlePhase.error,
        errorMessage: 'Ошибка авторизации. Перезайдите в аккаунт.',
      );
      return;
    }

    final req = CreateRoomRequest(
      jwtToken: jwt,
      questionsQuantity: questionsQuantity,
      questionsCategoryId: questionsCategoryId,
      questionsId: questionsId,
      moneyCount: moneyCount,
      gameDirectionMode: gameDirectionMode,
      isPublic: isPublic,
    );

    _ws!.send(req.toJsonString());
  }

  /// Проверить комнату по коду.
  Future<void> checkRoom(String roomId) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    state = state.copyWith(phase: BattlePhase.checkingRoom);
    await connectAndListen();

    _ws!.send(CheckRoomRequest(jwtToken: jwt, roomId: roomId).toJsonString());
  }

  /// Присоединиться к комнате.
  Future<void> joinRoom(String roomId) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    await connectAndListen();

    _ws!.send(JoinRoomRequest(jwtToken: jwt, roomId: roomId).toJsonString());
  }

  /// Запустить игру (только для админа).
  Future<void> startGame() async {
    final jwt = await _getJwt();
    if (jwt == null || _ws == null) return;

    _ws!.send(StartGameRequest(jwtToken: jwt).toJsonString());
  }

  /// Отправить ответ.
  Future<void> sendAnswer({required bool isCorrect}) async {
    final jwt = await _getJwt();
    if (jwt == null || _ws == null) return;

    // Подсчёт очков как в Unity: +20 за правильный, -5 за неправильный
    final newScore = state.currentScore + (isCorrect ? 20 : -5);

    state = state.copyWith(
      currentScore: newScore,
      currentQuestionIndex: state.currentQuestionIndex + 1,
    );

    _ws!.send(
      AnsweredRequest(
        jwtToken: jwt,
        isQuestionCorrect: isCorrect,
        score: newScore,
      ).toJsonString(),
    );
  }

  /// Завершить тест досрочно.
  Future<void> finishTest() async {
    final jwt = await _getJwt();
    if (jwt == null || _ws == null) return;

    state = state.copyWith(phase: BattlePhase.waitingResults);
    _ws!.send(FinishTestRequest(jwtToken: jwt).toJsonString());

    // Safety fallback: force-finish after 2s to avoid waiting.
    // If _deferFinish arrives with server data, it cancels this.
    _fallbackFinishTimer?.cancel();
    _fallbackFinishTimer = Timer(const Duration(seconds: 2), () {
      if (state.phase != BattlePhase.finished) {
        debugPrint('[Battle] ⚠️ Fallback: forcing finish after 2s');
        state = state.copyWith(phase: BattlePhase.finished);
      }
    });
  }

  /// Defer phase=finished until endTime passes.
  /// If endTime already passed, is null, or ALL players finished — finish immediately.
  void _deferFinish(List<MemberDto> members) {
    _fallbackFinishTimer?.cancel(); // Results arrived, cancel fallback
    _finishTimer?.cancel();

    // Check if all active players answered all questions
    final totalQ = state.questionsCount;
    final activePlayers = members.where((m) => !m.hasLeft).toList();
    final allDone =
        totalQ > 0 &&
        activePlayers.isNotEmpty &&
        activePlayers.every((m) => m.answered >= totalQ);

    final endTime = state.endTime;
    final now = DateTime.now().toUtc();
    final timerExpired =
        endTime == null ||
        endTime.difference(now).isNegative ||
        endTime.difference(now).inSeconds <= 1;

    // Finish immediately if: timer expired OR all players done
    if (timerExpired || allDone) {
      debugPrint(
        '[Battle] Finishing immediately: timerExpired=$timerExpired, allDone=$allDone',
      );
      state = state.copyWith(
        phase: BattlePhase.waitingResults,
        members: members,
      );
      _finishTimer = Timer(const Duration(seconds: 2), () {
        state = state.copyWith(phase: BattlePhase.finished, members: members);
      });
      return;
    }

    // Store pending members, keep phase as waitingResults
    _pendingFinishMembers = members;
    state = state.copyWith(phase: BattlePhase.waitingResults, members: members);

    debugPrint(
      '[Battle] Deferring finish for ${endTime.difference(now).inSeconds}s until $endTime',
    );

    // Wait until endTime, then show loading 2s, then finish
    _finishTimer = Timer(endTime.difference(now), () {
      final pending = _pendingFinishMembers ?? state.members;
      _pendingFinishMembers = null;
      state = state.copyWith(
        phase: BattlePhase.waitingResults,
        members: pending,
      );
      _finishTimer = Timer(const Duration(seconds: 2), () {
        state = state.copyWith(phase: BattlePhase.finished, members: pending);
      });
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  Обработка входящих сообщений (сервер → клиент)
  // ═══════════════════════════════════════════════════════════

  void _onMessage(Map<String, dynamic> json) {
    final response = WsResponse.fromJson(json);
    final type = response.type;

    debugPrint('[Battle] type=$type message=${response.message}');

    switch (type) {
      // ── Комната создана ──
      case 'room_created':
        final data = response.data;
        if (data == null) return;
        state = state.copyWith(
          phase: BattlePhase.waitingRoom,
          roomId: data.roomId ?? '',
          gameType: data.gameType ?? 'multiplayer',
          moneyCount: data.moneyCount ?? 6,
          questionsCategoryId: data.questionsCategoryId ?? 0,
          questionsCount: data.questionsCount ?? 0,
          gameDirectionMode: data.gameDirectionMode ?? 'English',
          questionsId: data.questionsId ?? [],
          members: _normalizeMembers(data.members),
          isAdmin: true,
          // Store server-driven wait window. The waiting screen reads
          // this to render an accurate countdown ("Ожидание игроков —
          // 42с"). If absent (older backend), the screen falls back to
          // a generic "Ожидание игроков…" message.
          waitTimeSeconds: data.waitTimeSeconds,
        );
        break;

      // ── Информация о комнате ──
      case 'check_room':
        final data = response.data;
        if (data == null) return;
        // Reconnect-safety: when `_onSocketReconnected` re-auths after a
        // backgrounding (e.g. sharing the invite to Telegram), we send
        // `check_room` to trigger the backend's `tryRestoreAdminSession`.
        // The backend responds with BOTH `room_restored` (proper
        // recovery) AND a trailing `check_room` echo. If we blindly
        // applied this echo we'd flip phase from `waitingRoom` back to
        // `checkingRoom` — which routes the admin back to the main
        // battle menu, making them feel "kicked out" even though the
        // room is alive. Suppress the echo whenever it matches the
        // room we're already running as admin (or as a joined member
        // in any live phase): the payload can't tell us anything our
        // existing state doesn't already know.
        const liveRoomPhases = {
          BattlePhase.waitingRoom,
          BattlePhase.countdown,
          BattlePhase.playing,
          BattlePhase.waitingResults,
          BattlePhase.reconnecting,
        };
        final echoingOurRoom = data.roomId == state.roomId &&
            state.roomId.isNotEmpty &&
            liveRoomPhases.contains(state.phase);
        if (echoingOurRoom) {
          debugPrint(
            '[Battle] ignoring check_room echo for own room ${state.roomId} '
            '(phase=${state.phase})',
          );
          // Still refresh members in case the echo carries newer data
          // (joins that happened during grace) but keep the phase.
          state = state.copyWith(members: _normalizeMembers(data.members));
          break;
        }
        state = state.copyWith(
          phase: BattlePhase.checkingRoom,
          roomId: data.roomId ?? '',
          moneyCount: data.moneyCount ?? 6,
          questionsCategoryId: data.questionsCategoryId ?? 0,
          questionsCount: data.questionsCount ?? 0,
          gameDirectionMode: data.gameDirectionMode ?? 'English',
          questionsId: data.questionsId ?? [],
          members: _normalizeMembers(data.members),
        );
        break;

      // ── Новый участник присоединился ──
      case 'join_new_member':
        final data = response.data;
        if (data == null) return;
        state = state.copyWith(
          phase: BattlePhase.waitingRoom,
          roomId: data.roomId ?? state.roomId,
          members: _normalizeMembers(data.members),
          // Capture game config for joined players
          questionsId: data.questionsId ?? state.questionsId,
          questionsCategoryId:
              data.questionsCategoryId ?? state.questionsCategoryId,
          questionsCount: data.questionsCount ?? state.questionsCount,
          moneyCount: data.moneyCount ?? state.moneyCount,
          gameDirectionMode: data.gameDirectionMode ?? state.gameDirectionMode,
        );
        break;

      // ── Игра началась ──
      case 'start_game':
        final data = response.data;
        if (data == null) return;
        DateTime? start, end;
        try {
          // Backend sends ISO-8601 strings; force UTC so a locally-set
          // system timezone doesn't shift the 90s match window by ±5h
          // (Dushanbe is UTC+5). Without toUtc(), devices with the
          // clock set to local time would see the game ending 5 hours
          // late or finishing instantly.
          start = DateTime.parse(data.startTime ?? '').toUtc();
          end = DateTime.parse(data.endTime ?? '').toUtc();
        } catch (_) {}
        debugPrint(
          '[Battle] start_game: questionsId=${data.questionsId}, '
          'categoryId=${data.questionsCategoryId}, '
          'startTime=${data.startTime}, endTime=${data.endTime}',
        );
        state = state.copyWith(
          phase: BattlePhase.playing,
          members: _normalizeMembers(data.members),
          startTime: start,
          endTime: end,
          currentScore: 0,
          currentQuestionIndex: 0,
          // Critical: pass game config to ALL players (not just creator)
          questionsId: data.questionsId ?? state.questionsId,
          questionsCategoryId:
              data.questionsCategoryId ?? state.questionsCategoryId,
          questionsCount: data.questionsCount ?? state.questionsCount,
          moneyCount: data.moneyCount ?? state.moneyCount,
          gameDirectionMode: data.gameDirectionMode ?? state.gameDirectionMode,
        );
        break;

      // ── Кто-то ответил ──
      case 'answered':
        final data = response.data;
        if (data == null) return;
        final mergedMembers = _normalizeMembers(data.members);
        state = state.copyWith(members: mergedMembers);

        // Тафтиш: агар ҳамаи бозигарони фаъол ба ҳамаи саволҳо ҷавоб доданд,
        // finishTest() зану занем то сервер results-ро ба ҳама бифиристад.
        _checkAllPlayersFinished();
        break;

      // ── Финальные результаты ──
      case 'results':
        final data = response.data;
        if (data == null) return;
        _deferFinish(_normalizeMembers(data.members));
        break;

      // ── Участник покинул комнату ──
      case 'left_member':
        // Мисли Unity: бозигарро аз рӯйхат нест намекунем, балки
        // ишора мекунем ки баромад (мошини вайроншуда нишон дода мешавад).
        final leftId = int.tryParse(response.message ?? '');
        if (leftId != null) {
          final updated = state.members
              .map((m) => m.id == leftId ? m.copyWith(hasLeft: true) : m)
              .toList();
          state = state.copyWith(members: updated);
        }
        break;

      // ── Админ вернулся в течение grace window ──
      case 'room_restored':
        // Backend confirmed our admin session was rescued before the
        // grace timer fired. Re-sync the room state from the payload
        // (members, phase, game config) and clear any "reconnecting"
        // banner so the waiting / playing UI resumes cleanly.
        final data = response.data;
        if (data == null) {
          // Even without a payload, just knowing the server accepted
          // us back is enough to exit the reconnecting phase.
          if (state.phase == BattlePhase.reconnecting) {
            state = state.copyWith(
              phase: state.roomId.isNotEmpty
                  ? BattlePhase.waitingRoom
                  : BattlePhase.idle,
              errorMessage: null,
            );
          }
          break;
        }
        DateTime? restoredStart, restoredEnd;
        try {
          if (data.startTime != null && data.startTime!.isNotEmpty) {
            restoredStart = DateTime.parse(data.startTime!).toUtc();
          }
          if (data.endTime != null && data.endTime!.isNotEmpty) {
            restoredEnd = DateTime.parse(data.endTime!).toUtc();
          }
        } catch (_) {}
        // Phase is inferred from server payload: if the game has a
        // start/end window, we're back in `playing`; otherwise still
        // waiting. (Backend may later add an explicit phase field — if
        // so, extend WsResponseData and read it directly.)
        final wasPlaying = restoredStart != null && restoredEnd != null;
        state = state.copyWith(
          phase: wasPlaying
              ? BattlePhase.playing
              : BattlePhase.waitingRoom,
          errorMessage: null,
          roomId: data.roomId ?? state.roomId,
          members: _normalizeMembers(data.members),
          questionsId: data.questionsId ?? state.questionsId,
          questionsCategoryId:
              data.questionsCategoryId ?? state.questionsCategoryId,
          questionsCount: data.questionsCount ?? state.questionsCount,
          moneyCount: data.moneyCount ?? state.moneyCount,
          gameDirectionMode: data.gameDirectionMode ?? state.gameDirectionMode,
          startTime: restoredStart ?? state.startTime,
          endTime: restoredEnd ?? state.endTime,
        );
        debugPrint(
          '[Battle] ✅ room_restored — admin session recovered, '
          'roomId=${state.roomId}, members=${state.members.length}',
        );
        break;

      // ── Админ передан (старый админ отключился во время игры) ──
      case 'admin_changed':
        // Backend fires this when an admin's connection drops
        // during `playing` phase and the in-game grace timer
        // expires — instead of tearing the room down (waiting-room
        // rule), the server hands the admin crown to a random
        // active human member so the match can finish.
        //
        // Expected payload:
        //   data.new_admin_id  — user_id of the new admin
        //   data.members       — full updated list with new
        //                        `is_admin` flags
        final data = response.data;
        if (data == null) break;
        final mergedMembers = _normalizeMembers(data.members);
        // We no longer receive the user id of the promoted member
        // as a separate field from `WsResponseData`, so we derive
        // it from the members list — whichever member carries
        // `isAdmin == true` is the new crown-holder. Fall back to
        // the existing state if the payload is malformed.
        final newAdmin = mergedMembers
            .where((m) => m.isAdmin && !m.hasLeft)
            .firstOrNull;
        final myId = StorageService.instance.getUserId();
        final amINewAdmin =
            newAdmin != null && myId != null && newAdmin.id == myId;
        state = state.copyWith(
          members: mergedMembers,
          isAdmin: amINewAdmin,
        );
        debugPrint(
          '[Battle] 👑 admin_changed — new admin=${newAdmin?.id} '
          '(me=$myId, amINewAdmin=$amINewAdmin)',
        );
        break;

      // ── Комната удалена (админ вышел) ──
      case 'delete_room':
        final closedRoomId = state.roomId;
        state = state.copyWith(
          phase: BattlePhase.error,
          errorMessage: 'battle_room_closed',
        );
        _ws?.disconnect();
        // Kick the lobby's public-rooms cache so the closed room
        // disappears from the list immediately instead of waiting for
        // the server's next push. The `public-rooms` WS pushes updates
        // on changes, but there's a small window where a closed-but-
        // still-in-list room would be tappable by other users who'd
        // then hit `room_not_found`. Refresh + optimistic removal
        // keeps the list honest.
        if (closedRoomId.isNotEmpty) {
          try {
            ref.read(lobbyProvider.notifier).removeRoomOptimistic(closedRoomId);
            ref.read(lobbyProvider.notifier).refresh();
          } catch (e) {
            debugPrint('[Battle] lobby refresh after delete_room failed: $e');
          }
        }
        break;

      // ── Обратный отсчёт (бот-комнаты) ──
      case 'countdown_started':
        state = state.copyWith(phase: BattlePhase.countdown);
        break;

      // ── Ошибки ──
      case 'daily_limit_reached':
        // Intentionally discard the server's `response.message` here —
        // the backend only ships a Russian copy, which leaked onto
        // Tajik- / English-locale phones via the error dialogs. Use a
        // stable translation key instead; the UI resolves it through
        // `_friendlyError` / `.tr()` to the user's current language.
        //
        // Structured payload (backend TZ §5):
        //   data.limit       — сколько попыток в день разрешено
        //   data.resets_at   — когда сбрасывается (ISO-8601 UTC)
        // UI uses them to render "Вы использовали N/N. Сброс через ..."
        // We encode both into `errorMessage` as a query string so UI
        // can parse without needing extra state fields.
        final data = response.data;
        final parts = <String>['daily_limit_reached'];
        if (data?.limit != null) parts.add('limit=${data!.limit}');
        if (data?.resetsAt != null) {
          parts.add('resets_at=${data!.resetsAt}');
        }
        state = state.copyWith(
          phase: BattlePhase.error,
          dailyLimitReached: true,
          errorMessage: parts.join('|'),
        );
        break;

      case 'room_not_found':
        state = state.copyWith(
          phase: BattlePhase.error,
          errorMessage: 'room_not_found',
        );
        _ws?.disconnect();
        break;

      case 'room_is_full':
        state = state.copyWith(
          phase: BattlePhase.error,
          errorMessage: 'room_is_full',
        );
        _ws?.disconnect();
        break;

      case 'game_started':
        state = state.copyWith(
          phase: BattlePhase.error,
          errorMessage: 'game_already_started',
        );
        _ws?.disconnect();
        break;

      case 'not_admin':
        state = state.copyWith(
          errorMessage: 'Только админ может запустить игру',
        );
        break;

      case 'room_empty':
        state = state.copyWith(errorMessage: 'Недостаточно участников');
        break;

      case 'jwt_expired':
        state = state.copyWith(
          phase: BattlePhase.error,
          errorMessage: 'Токен истёк. Перезайдите.',
        );
        _ws?.disconnect();
        break;

      case 'error':
      case 'invalid_message_type':
        state = state.copyWith(
          phase: BattlePhase.error,
          errorMessage: response.message ?? 'Ошибка',
        );
        break;

      // ── Тест завершён (сервер подтвердил) ──
      case 'finish_test':
        final data = response.data;
        final members = (data != null && data.members.isNotEmpty)
            ? _normalizeMembers(data.members)
            : state.members;
        _deferFinish(members);
        break;

      default:
        debugPrint('[Battle] Неизвестный тип: $type');
        break;
    }
  }
}
