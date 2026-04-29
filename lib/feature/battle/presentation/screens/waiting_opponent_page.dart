import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/battle/data/battle_phase.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Комната ожидания — дизайн как в Unity 3D.
class WaitingOpponentPage extends ConsumerStatefulWidget {
  const WaitingOpponentPage({super.key});

  @override
  ConsumerState<WaitingOpponentPage> createState() =>
      _WaitingOpponentPageState();
}

class _WaitingOpponentPageState extends ConsumerState<WaitingOpponentPage>
    with SingleTickerProviderStateMixin {
  /// Safety-net watchdog applied on TOP of the server's `wait_time_seconds`.
  /// Fires only if the backend somehow fails to advance the room past
  /// the advertised wait window — e.g. bot-spawn logic crashes or
  /// countdown_started never arrives. Without it the user would sit
  /// on a frozen "0s" screen indefinitely.
  static const int _safetyWatchdogGraceSeconds = 30;

  /// Visible countdown driven by `state.waitTimeSeconds` from the
  /// server's `room_created` payload. Updated once per second; UI shows
  /// "Ожидание игроков — N с" until 0, then just "Ожидание игроков…".
  int? _secondsLeft;
  Timer? _countdownTimer;
  Timer? _botFallbackTimer;
  bool _noOpponentsDialogShown = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Read the server-driven wait window from provider state. If the
    // backend didn't send one (older server, or a flow where it isn't
    // relevant), we skip the countdown and just show "Ожидание
    // игроков…" without a number.
    final serverWait = ref.read(battleProvider).waitTimeSeconds;
    if (serverWait != null && serverWait > 0) {
      _secondsLeft = serverWait;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if ((_secondsLeft ?? 0) > 0) _secondsLeft = (_secondsLeft ?? 0) - 1;
        });
      });
      // Safety watchdog = server wait + grace buffer. This way a late
      // bot-spawn (e.g. server delays by a few seconds) doesn't trigger
      // the "no opponents found" dialog before the server's own retry
      // logic has had a chance.
      _botFallbackTimer = Timer(
        Duration(seconds: serverWait + _safetyWatchdogGraceSeconds),
        _onBotFallbackTimeout,
      );
    } else {
      // Fallback: generous 180-second watchdog so the screen never
      // freezes forever even when the server omits `wait_time_seconds`.
      _botFallbackTimer = Timer(
        const Duration(seconds: 180),
        _onBotFallbackTimeout,
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _botFallbackTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Fires once the visible countdown + grace window have elapsed. If we
  /// still only see the room creator (no bots, no real players) and the
  /// server hasn't advanced us out of `waitingRoom`, show a friendly
  /// "no opponents found" dialog so the user can retry instead of
  /// staring at a stuck screen.
  void _onBotFallbackTimeout() {
    if (!mounted || _noOpponentsDialogShown) return;
    final st = ref.read(battleProvider);
    // If the server already moved us into countdown / playing / finished
    // we've got opponents — stand down.
    if (st.phase != BattlePhase.waitingRoom) return;
    if (st.members.length >= 2) return;
    _noOpponentsDialogShown = true;
    _showNoOpponentsDialog();
  }

  void _showNoOpponentsDialog() {
    final vm = ref.read(battleProvider.notifier);
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
                    Icons.search_off_rounded,
                    size: 44,
                    color: Color(0xFFF04438),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'battle_no_opponents_title'.tr(),
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
                'battle_no_opponents_body'.tr(),
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
                  // Tear the stuck room down server-side and reset the
                  // client so the user lands back on the battle main
                  // menu and can create a fresh room.
                  vm.leaveRoom();
                },
                width: double.infinity,
                buttonColor: const Color(0xFF2E90FA),
                backButtonColor: const Color(0xFF1570EF),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'battle_try_again'.tr(),
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
              // ── Coin icon in circle ──
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
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

              // ── Penalty amount ──
              Text(
                'battle_penalty_coins'.tr(args: ['$penalty']),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF79009),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ──
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

              // ── Description ──
              Text(
                'battle_exit_description'.tr(args: ['$penalty']),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),

              // ── Continue button (MyButton with border) ──
              MyButton(
                onPressed: () => Navigator.of(context).pop(),
                width: double.infinity,
                buttonColor: Colors.white,
                backButtonColor: const Color(0xFFD0D5DD),
                border: 1.5,
                borderColor: const Color(0xFFD0D5DD),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'battle_continue_playing'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Exit button (MyButton red) ──
              MyButton(
                onPressed: () {
                  final profileNotifier = ref.read(
                    getProfileInfoProvider.notifier,
                  );
                  final penalty = ref.read(battleProvider).moneyCount;
                  Navigator.of(context).pop();
                  // Notify the server before tearing the socket down.
                  // If this user is the room admin and the game hasn't
                  // started yet, the backend uses this signal to delete
                  // the room so it stops appearing in the public list.
                  vm.leaveRoom();
                  // Deduct coins locally like Unity's RemoveCoinsLocal
                  profileNotifier.deductCoins(penalty);
                },
                width: double.infinity,
                buttonColor: const Color(0xFFEF4444),
                backButtonColor: const Color(0xFFB91C1C),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'battle_exit_game'.tr(),
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

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(battleProvider);
    final vm = ref.read(battleProvider.notifier);
    final hasEnoughPlayers = st.members.length >= 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A4B8C),
        body: SafeArea(
          child: Column(
            children: [
              // ── Верхняя навигация ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: _showExitDialog,
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // ── Контент ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // ── Карточка с кодом комнаты ──
                      _buildRoomCodeCard(st.roomId),

                      const SizedBox(height: 20),

                      // ── Таймер ожидания ──
                      _buildWaitingTimer(hasEnoughPlayers),

                      const SizedBox(height: 20),

                      // ── Участники ──
                      _buildMembersList(st),
                    ],
                  ),
                ),
              ),

              // ── Кнопка «Начать игру» (только при ≥2 участниках) ──
              if (hasEnoughPlayers) _buildStartButton(st, vm),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Карточка с кодом комнаты
  // ═══════════════════════════════════════════════════════

  Widget _buildRoomCodeCard(String roomId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Заголовок + кнопка «Поделиться»
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'battle_multiple_opponents'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _shareRoomCode(roomId),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Код комнаты — жёлтый бейдж
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: roomId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'battle_code_copied'.tr(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: const Color(0xFF12B76A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEDF89),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                roomId,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D2939),
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'battle_share_code_hint'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF667085),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Таймер ожидания
  // ═══════════════════════════════════════════════════════

  Widget _buildWaitingTimer(bool hasEnoughPlayers) {
    // Show a countdown if the server gave us a wait window. Once the
    // counter hits zero (or if the server didn't send one), just show
    // the generic "Waiting for players…" label.
    final hasCountdown = _secondsLeft != null && _secondsLeft! > 0;
    final label = hasCountdown
        ? 'battle_waiting_players_seconds'.tr(
            args: ['$_secondsLeft'],
          )
        : 'battle_waiting_players'.tr();
    return FadeTransition(
      opacity: hasEnoughPlayers
          ? const AlwaysStoppedAnimation(1.0)
          : _pulseController.drive(Tween(begin: 0.5, end: 1.0)),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Список участников
  // ═══════════════════════════════════════════════════════

  Widget _buildMembersList(dynamic st) {
    // Defense-in-depth dedup: ҳарчанд `battle_provider._normalizeMembers`
    // server-data-ро тоза мекунад, инҷо боз дубораҳоро рад мекунем то
    // агар ягон call-site дар оянда normalize-ро гум кунад UI вайрон
    // нашавад.
    final seenIds = <int>{};
    final unique = <dynamic>[];
    for (final m in st.members) {
      if (seenIds.add(m.id)) unique.add(m);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 cards per row with 12px spacing
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final m in unique)
              _buildPlayerCard(
                // ValueKey бо id — то Flutter ҳангоми reorder/insertion
                // instance-и сана-ро эҳтиёт кунад (avatar/animation
                // state аз даст наравад).
                key: ValueKey('member_${m.id}'),
                name: m.name,
                avatarUrl: m.fullAvatarUrl,
                isAdmin: m.isAdmin,
                cardWidth: cardWidth,
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerCard({
    Key? key,
    required String name,
    String? avatarUrl,
    bool isAdmin = false,
    bool isBot = false,
    double cardWidth = 140,
  }) {
    return SizedBox(
      key: key,
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Иконка онлайн + аватарка
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Аватарка
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isBot
                        ? const Color(0xFFFEDF89).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.15),
                    image: avatarUrl != null && avatarUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Center(
                          child: isBot
                              ? const Icon(
                                  Icons.smart_toy_rounded,
                                  size: 36,
                                  color: Color(0xFFF79009),
                                )
                              : Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                        )
                      : null,
                ),
                // Индикатор онлайн
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12B76A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1A4B8C),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Имя
            Text(
              name.isNotEmpty ? name : 'battle_player'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Статус
            if (isAdmin) ...[
              const SizedBox(height: 4),
              Text(
                'battle_room_creator'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFEDF89),
                ),
                maxLines: 1,
              ),
            ] else if (isBot) ...[
              const SizedBox(height: 4),
              Text(
                'battle_bot'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFF79009),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Кнопка «Начать игру»
  // ═══════════════════════════════════════════════════════

  Widget _buildStartButton(dynamic st, dynamic vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Для не-админа — текст ожидания
          if (!st.isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'battle_waiting_start'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Кнопка «Начать игру» — только для админа
          if (st.isAdmin)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => vm.startGame(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEDF89),
                  foregroundColor: const Color(0xFF1D2939),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'battle_start_game'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Утилиты
  // ═══════════════════════════════════════════════════════

  void _shareRoomCode(String roomId) {
    // Universal link → backend's /api/v1/deeplink endpoint. Backend now
    // hosts the verification files (assetlinks.json + apple-app-site-
    // association) at api.vozhaomuz.com, so Android + iOS open the app
    // directly when the link is tapped in most messengers.
    final deeplink =
        'https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=$roomId';
    // Custom-scheme fallback for Telegram's in-app browser, which never
    // honors universal links. Recipients on Telegram can tap this
    // second link manually to force the app open.
    final customSchemeLink = 'vozhaomuz://battle?room_id=$roomId';
    final shareText = 'battle_share_text'.tr(
      args: [roomId, deeplink, customSchemeLink],
    );

    SharePlus.instance.share(ShareParams(text: shareText));
  }
}
