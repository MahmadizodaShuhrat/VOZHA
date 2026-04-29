import 'package:flutter/foundation.dart';
import 'battle_phase.dart';
import 'member_dto.dart';

/// Полное состояние системы Battle.
@immutable
class BattleState {
  // ── Фаза ──
  final BattlePhase phase;

  // ── Комната ──
  final String roomId;
  final String gameType;
  final int moneyCount;
  final int questionsCategoryId;
  final int questionsCount;
  final String gameDirectionMode;
  final List<int> questionsId;
  final bool isPublic;
  final bool isAdmin;

  // ── Участники ──
  final List<MemberDto> members;

  // ── Таймер ──
  final DateTime? startTime;
  final DateTime? endTime;

  // ── Игровой процесс ──
  final int currentScore;
  final int currentQuestionIndex;

  // ── Результат ──
  final String? errorMessage;
  final bool dailyLimitReached;

  /// Seconds the server will wait in `waitingRoom` before auto-starting
  /// with bots / deleting the room. Populated from
  /// `room_created.data.wait_time_seconds`. `null` means the server
  /// didn't send a value (old backend) — UI just shows "Ожидание
  /// игроков…" without a countdown.
  final int? waitTimeSeconds;

  const BattleState({
    this.phase = BattlePhase.idle,
    this.roomId = '',
    this.gameType = 'multiplayer',
    this.moneyCount = 6,
    this.questionsCategoryId = 0,
    this.questionsCount = 0,
    this.gameDirectionMode = 'English',
    this.questionsId = const [],
    this.isPublic = true,
    this.isAdmin = false,
    this.members = const [],
    this.startTime,
    this.endTime,
    this.currentScore = 0,
    this.currentQuestionIndex = 0,
    this.errorMessage,
    this.dailyLimitReached = false,
    this.waitTimeSeconds,
  });

  factory BattleState.initial() => const BattleState();

  BattleState copyWith({
    BattlePhase? phase,
    String? roomId,
    String? gameType,
    int? moneyCount,
    int? questionsCategoryId,
    int? questionsCount,
    String? gameDirectionMode,
    List<int>? questionsId,
    bool? isPublic,
    bool? isAdmin,
    List<MemberDto>? members,
    DateTime? startTime,
    DateTime? endTime,
    int? currentScore,
    int? currentQuestionIndex,
    String? errorMessage,
    bool? dailyLimitReached,
    int? waitTimeSeconds,
  }) {
    return BattleState(
      phase: phase ?? this.phase,
      roomId: roomId ?? this.roomId,
      gameType: gameType ?? this.gameType,
      moneyCount: moneyCount ?? this.moneyCount,
      questionsCategoryId: questionsCategoryId ?? this.questionsCategoryId,
      questionsCount: questionsCount ?? this.questionsCount,
      gameDirectionMode: gameDirectionMode ?? this.gameDirectionMode,
      questionsId: questionsId ?? this.questionsId,
      isPublic: isPublic ?? this.isPublic,
      isAdmin: isAdmin ?? this.isAdmin,
      members: members ?? this.members,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      currentScore: currentScore ?? this.currentScore,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      errorMessage: errorMessage,
      dailyLimitReached: dailyLimitReached ?? this.dailyLimitReached,
      waitTimeSeconds: waitTimeSeconds ?? this.waitTimeSeconds,
    );
  }
}
