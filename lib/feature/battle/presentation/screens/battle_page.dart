import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/battle/data/battle_phase.dart';
import 'package:vozhaomuz/feature/battle/data/battle_state.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'create_room_page.dart';
import 'join_room_page.dart';
import 'public_rooms_page.dart';
import 'waiting_opponent_page.dart';
import 'battle_game_page.dart';
import 'battle_finished_page.dart';
import 'package:vozhaomuz/core/services/deep_link_service.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Главная страница Battle — 3 вкладки: Создать / Вступить / Список.
class BattlePage extends ConsumerStatefulWidget {
  const BattlePage({super.key});

  @override
  ConsumerState<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends ConsumerState<BattlePage> {
  int _tabIndex = 0; // 0 = Создать, 1 = Вступить, 2 = Список

  /// Prevents the "room closed" dialog from stacking if `delete_room`
  /// somehow fires twice (unlikely, but cheap insurance). Reset in
  /// `_dismissRoomClosedDialog` once the user acknowledges.
  bool _roomClosedDialogShown = false;

  @override
  void initState() {
    super.initState();
    // A deep-linked battle invite means the user came here specifically
    // to join a room — flip to the "Join" tab so the room code lands
    // in the text field instantly. JoinRoomPage itself clears the
    // provider once it reads the code.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(pendingBattleInviteProvider);
      if (pending != null && pending.isNotEmpty && _tabIndex != 1) {
        setState(() => _tabIndex = 1);
      }
    });
  }

  /// Surface a modal when the server tells us the battle room is gone.
  /// Shown on `delete_room` (admin grace expired / creator explicitly
  /// left) and on `room_not_found` (joined after the room was already
  /// purged). Message is tailored to the user's role:
  ///
  /// - admin (creator) — "Ваша комната закрыта из-за длительного
  ///   отсутствия", because "creator left" is nonsensical when the
  ///   viewer IS the creator. Usually means they backgrounded the app
  ///   past the grace window while sharing.
  /// - non-admin — "Создатель покинул комнату", the classic phrasing.
  void _showRoomClosedDialog({
    required bool wasAdmin,
    required String reason,
  }) {
    final vm = ref.read(battleProvider.notifier);
    final isRoomClosed = reason.contains('battle_room_closed');
    final titleKey = wasAdmin
        ? 'battle_room_closed_admin_title'
        : (isRoomClosed
              ? 'battle_room_closed_title'
              : 'battle_room_not_found');
    final bodyKey = wasAdmin
        ? 'battle_room_closed_admin_body'
        : 'battle_room_closed_body';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3F2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.meeting_room_outlined,
                    size: 44,
                    color: Color(0xFFF04438),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                titleKey.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bodyKey.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),
              MyButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Clear the battle state so the user lands on the
                  // main battle menu cleanly, with no lingering error
                  // banner.
                  vm.reset();
                  if (mounted) {
                    setState(() {
                      _roomClosedDialogShown = false;
                      // Snap to the Create tab — most natural landing
                      // after a room was torn down, admin or member.
                      _tabIndex = 0;
                    });
                  }
                },
                width: double.infinity,
                buttonColor: const Color(0xFF2E90FA),
                backButtonColor: const Color(0xFF1570EF),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'ok'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exit confirmation dialog — matching Unity 3D design.
  void _showExitDialog() {
    final st = ref.read(battleProvider);
    final vm = ref.read(battleProvider.notifier);
    final penalty = st.moneyCount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/battle/coinfull.png',
                    width: 44,
                    height: 44,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on_rounded,
                      size: 44,
                      color: Color(0xFFF79009),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'battle_penalty_coins'.tr(args: [penalty.toString()]),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF79009),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'battle_exit_title'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'battle_exit_description'.tr(args: [penalty.toString()]),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF1A4B8C),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'battle_continue_playing'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Tell the server we're leaving so the backend can
                    // delete the room (if we're admin pre-start) and
                    // purge it from the public list. `disconnectAll()`
                    // alone only closes the socket — the server then has
                    // to wait for a timeout to notice we're gone.
                    vm.leaveRoom();

                    // Локалӣ кам мекунем барои UI-и фаврӣ
                    ref
                        .read(getProfileInfoProvider.notifier)
                        .deductCoins(penalty);

                    // Аз сервер refresh мекунем — сервер ҳам кам мекунад,
                    // getProfile натиҷаи дурусти серверро мегирад
                    // (локалиро иваз мекунад, на илова)
                    Future.delayed(const Duration(seconds: 2), () {
                      ref.read(getProfileInfoProvider.notifier).getProfile();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'battle_exit_game'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(battleProvider);
    final profileAsync = ref.watch(getProfileInfoProvider);
    final isPremium = profileAsync.value?.userType == 'pre';

    // Surface a "room closed" dialog whenever the server signals the
    // room has been torn down — `delete_room` (admin grace expired /
    // explicit leave) or `room_not_found` (joined after the room was
    // already purged). Message differs for admin vs member — the
    // admin whose grace expired shouldn't read "creator left the
    // game" (that'd be nonsensical; they ARE the creator).
    ref.listen<BattleState>(battleProvider, (prev, next) {
      final becameError = next.phase == BattlePhase.error &&
          prev?.phase != BattlePhase.error;
      if (!becameError) return;
      // Агар бозӣ табиатан ба охир расида буд, баъди намоиши натиҷа
      // сервер room-ро тоза мекунад ва паёми `battle_room_closed` ё
      // `room_not_found`-ро мефиристад. Phase transitions ҳангоми
      // тамом шудани бозӣ:
      //   playing → waitingResults → (2с) → finished
      // Cleanup-и сервер дар ҳама се ҳолат метавонад биёяд. Ҳардуи
      // `waitingResults` ва `finished`-ро ба сифати "бозӣ табиатан ба
      // охир расид"-и signal истифода мебарем. Dialog-ро дар чунин
      // ҳолатҳо нишон надиҳем — натиҷа аз болои худ навишта мешавад.
      if (prev?.phase == BattlePhase.finished ||
          prev?.phase == BattlePhase.waitingResults) {
        return;
      }
      final msg = next.errorMessage ?? '';
      final isRoomGone =
          msg.contains('battle_room_closed') ||
          msg.contains('room_not_found');
      if (!isRoomGone) return;
      if (_roomClosedDialogShown) return;
      _roomClosedDialogShown = true;
      // Capture the "were we the admin before the error hit" signal
      // before the listener returns — `prev` still holds the pre-error
      // state, while by the time the post-frame callback runs the
      // state may have been reset.
      final wasAdmin = prev?.isAdmin ?? false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showRoomClosedDialog(
          wasAdmin: wasAdmin,
          reason: msg,
        );
      });
    });

    // Determine if we need to block back button. `reconnecting` is
    // included only when we still hold a roomId — i.e. the socket
    // dropped mid-match and we're waiting to come back. A plain back
    // press in that window would bounce the user out of the match
    // entirely without confirmation, which throws away any progress
    // even though the server's admin grace is still running.
    final hasRoomForPop = st.roomId.isNotEmpty;
    final isInGame =
        st.phase == BattlePhase.waitingRoom ||
        st.phase == BattlePhase.countdown ||
        st.phase == BattlePhase.playing ||
        st.phase == BattlePhase.waitingResults ||
        (st.phase == BattlePhase.reconnecting && hasRoomForPop);

    // ── Роутинг по фазам ──
    // If the socket drops mid-match (e.g. the user went to share the
    // invite in Telegram and their phone paused network), phase
    // becomes `reconnecting` while `BattleWsService` retries. Without
    // the special-case below we'd briefly drop back to the main
    // battle menu — users perceive this as "I was kicked out of the
    // room" even though the server's admin grace window is still
    // running. Keep showing the correct in-room page during reconnect:
    //   - if the game had already started (startTime is set) → stay
    //     on BattleGamePage, so the user doesn't get yanked back to
    //     the waiting lobby mid-match
    //   - otherwise → WaitingOpponentPage (the user was still in the
    //     waiting lobby when the socket dropped).
    //
    // `_onSocketReconnected` will re-auth and `room_restored` (or
    // `start_game` if the timer already fired) will restore the exact
    // phase as soon as the WebSocket is back up.
    final hasActiveRoom = st.roomId.isNotEmpty;
    final isReconnectingInRoom =
        st.phase == BattlePhase.reconnecting && hasActiveRoom;
    final gameHadStarted = st.startTime != null;

    Widget child;
    if (st.phase == BattlePhase.waitingRoom ||
        st.phase == BattlePhase.countdown ||
        (isReconnectingInRoom && !gameHadStarted)) {
      child = const WaitingOpponentPage();
    } else if (st.phase == BattlePhase.playing ||
        st.phase == BattlePhase.waitingResults ||
        (isReconnectingInRoom && gameHadStarted)) {
      child = const BattleGamePage();
    } else if (st.phase == BattlePhase.finished) {
      child = const BattleFinishedPage();
    } else {
      child = _buildMainContent(st, isPremium);
    }

    // Wrap with PopScope to intercept back button during game
    return PopScope(
      canPop: !isInGame,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isInGame) {
          _showExitDialog();
        }
      },
      child: child,
    );
  }

  Widget _buildMainContent(dynamic st, bool isPremium) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'battle_game_mode'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTabs(isPremium),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Tab content fills remaining space — no scroll
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _tabIndex == 0
                    ? const CreateRoomPage()
                    : _tabIndex == 1
                    ? const JoinRoomPage()
                    : const PublicRoomsFullPage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Баннер с изображением самураев ──
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      height: 160,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF007AFF), width: 0.3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF007AFF), offset: const Offset(0, 3)),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF53B1FD), Color(0xFF2E90FA), Color(0xFF1570EF)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Фоновый паттерн
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            // Изображение самураев
            Positioned(
              top: 0,
              right: -55,
              child: Image.asset(
                'assets/images/samurai.png',
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // Текст «Соревнование»
            Positioned(
              left: 20,
              top: 20,
              child: Text(
                'battle_competition'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Вкладки (3 для всех) ──
  Widget _buildTabs(bool isPremium) {
    return Row(
      children: [
        _buildTab(0, 'battle_tab_create'.tr()),
        const SizedBox(width: 8),
        _buildTab(1, 'battle_tab_join'.tr()),
        const SizedBox(width: 8),
        _buildTab(2, 'battle_tab_list'.tr()),
      ],
    );
  }

  // ── Диалог для обычных пользователей ──
  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Frame.png', width: 120, height: 120),
              const SizedBox(height: 20),
              Text(
                'battle_premium_only'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              MyButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MySubscriptionPage(),
                    ),
                  );
                },
                width: double.infinity,
                buttonColor: const Color(0xFFFDB022),
                backButtonColor: const Color(0xFFF79009),
                borderRadius: 14,
                child: Text(
                  'battle_buy_premium'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              MyButton(
                onPressed: () => Navigator.of(context).pop(),
                width: double.infinity,
                buttonColor: Colors.white,
                backButtonColor: const Color(0xFFD0D5DD),
                borderRadius: 14,
                border: 1.5,
                borderColor: const Color(0xFFD0D5DD),
                child: Text(
                  'battle_got_it'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tabIndex = index);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2E90FA)
                    : const Color(0xFFF5F8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1570EF)
                      : const Color(0xFFD0D5DD),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF1570EF)
                        : const Color(0xFFD0D5DD),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF344054),
                    height: 1.3,
                  ),
                ),
              ),
            ),
            // Галочка
            if (isSelected)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E90FA),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1570EF),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
