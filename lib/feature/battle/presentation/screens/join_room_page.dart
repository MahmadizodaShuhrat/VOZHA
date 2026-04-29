import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/battle/data/battle_phase.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/core/services/deep_link_service.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/shared/widgets/energy_paywall_dialog.dart';

/// Вкладка «Вступить в комнату» — ввод ID + подтверждение (как Unity UIBattlePage check_room).
class JoinRoomPage extends ConsumerStatefulWidget {
  const JoinRoomPage({super.key});

  @override
  ConsumerState<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends ConsumerState<JoinRoomPage> {
  final _codeController = TextEditingController();
  bool _isSearching = false;
  bool _isJoining = false;
  bool _codeValid = false;

  /// Tracks which category ids we've already kicked off a prefetch for
  /// in this page's lifetime. Prevents re-triggering on every rebuild
  /// when the state snapshot re-exposes the same `questionsCategoryId`.
  final Set<int> _prefetchedCategoryIds = {};

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      final valid = _codeController.text.trim().length == 6;
      if (valid != _codeValid) {
        setState(() => _codeValid = valid);
        // Auto-search when 6 digits entered
        if (valid && !_isSearching) {
          _handleFind();
        }
      }
    });
    // Apply any pending deep-link room invite. When the user taps a
    // "battle?room_id=XXXXXX" link, `DeepLinkService` captures it into
    // `pendingBattleInviteProvider` and routes to /home — which lands
    // here after the Battle tab becomes visible. We seed the text
    // field with the captured code, which triggers the auto-search
    // path above exactly as if the user had typed it by hand.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(pendingBattleInviteProvider);
      if (pending != null && pending.isNotEmpty) {
        _codeController.text = pending;
        ref.read(pendingBattleInviteProvider.notifier).clear();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Kick off a background download of the room's category course ZIP
  /// the moment `check_room` reveals which category it uses. The game
  /// page still has its own blocking-dialog fallback, but in practice
  /// the download will be done (or close to it) by the time the user
  /// presses "Join" and the server fires `start_game`. This avoids
  /// the UX where every deep-link joiner hits a modal download bar
  /// before they can enter the match.
  void _prefetchCategoryResources(int categoryId) {
    if (categoryId <= 0) return;
    if (_prefetchedCategoryIds.contains(categoryId)) return;
    _prefetchedCategoryIds.add(categoryId);

    Future<void>(() async {
      // Skip if already on disk.
      final has = await CategoryResourceService.hasResources(categoryId);
      if (has) {
        debugPrint(
          '⏭️ [JoinRoom prefetch] category $categoryId already extracted',
        );
        return;
      }
      // Find the CategoryFlutterDto so we know the ZIP resource name.
      final catsAsync = ref.read(categoriesFlutterProvider);
      final cats = catsAsync.hasValue ? catsAsync.value : null;
      if (cats == null) {
        debugPrint(
          '⚠️ [JoinRoom prefetch] categories not loaded yet, skipping '
          '$categoryId (game page will handle fallback download)',
        );
        return;
      }
      CategoryFlutterDto? cat;
      for (final c in cats) {
        if (c.id == categoryId) {
          cat = c;
          break;
        }
      }
      if (cat == null) {
        debugPrint(
          '⚠️ [JoinRoom prefetch] category $categoryId not in provider, '
          'game page will handle',
        );
        return;
      }
      debugPrint(
        '⏩ [JoinRoom prefetch] background-downloading category $categoryId',
      );
      try {
        await CategoryResourceService.downloadAndExtract(cat);
        debugPrint(
          '✅ [JoinRoom prefetch] category $categoryId ready',
        );
      } catch (e) {
        debugPrint('❌ [JoinRoom prefetch] failed for $categoryId: $e');
        // Swallow: game page's fallback dialog will retry if needed.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(battleProvider);

    // После check_room — показать информацию о комнате
    if (st.phase == BattlePhase.checkingRoom && st.members.isNotEmpty) {
      // Start downloading the course ZIP in the background the moment
      // we know the category. Fires at most once per category id. By
      // the time the user taps Join and `start_game` arrives, the
      // resources should already be on disk, so BattleGamePage's
      // fallback download dialog no longer blocks entry.
      if (st.questionsCategoryId > 0) {
        _prefetchCategoryResources(st.questionsCategoryId);
      }
      return _buildRoomInfo(st);
    }

    return _buildSearchForm(st);
  }

  // ═══════════════════════════════════════════════════
  // 1) Форма поиска комнаты (ввод ID)
  // ═══════════════════════════════════════════════════
  Widget _buildSearchForm(dynamic st) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Заголовок ──
        const SizedBox(height: 15),
        Text(
          'battle_enter_room_id'.tr(),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 10),

        // ── Поле ввода ──
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF344054),
          ),
          decoration: InputDecoration(
            hintText: '258003..',
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF98A2B3),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2E90FA), width: 2),
            ),
          ),
        ),

        // ── Ошибка ──
        if (st.phase == BattlePhase.error && st.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDCA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFD92D20),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _friendlyError(st.errorMessage as String),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD92D20),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'battle_check_room_id_hint'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF912018),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Push button to bottom
        const Spacer(),

        // ── Кнопка «Найти комнату» ──
        MyButton(
          onPressed: (_isSearching || !_codeValid) ? null : _handleFind,
          width: double.infinity,
          buttonColor: const Color(0xFF2E90FA),
          backButtonColor: const Color(0xFF1570EF),
          borderRadius: 14,
          child: _isSearching
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'battle_find_room'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // 2) Экран подтверждения комнаты (как Unity UIContentRoomView)
  // ═══════════════════════════════════════════════════
  Widget _buildRoomInfo(dynamic st) {
    final admin = st.members.isNotEmpty ? st.members.first : null;
    final wordsCount = (st.questionsCount / 5).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Карточка комнаты ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD0D5DD),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Создатель комнаты
              if (admin != null) ...[
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8F0FE),
                        border: Border.all(
                          color: const Color(0xFF2E90FA),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF2E90FA),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                          Text(
                            'battle_room_creator'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Количество игроков
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2E90FA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: Color(0xFF2E90FA),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${st.members.length}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2E90FA),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE4E7EC)),
                const SizedBox(height: 16),
              ],

              // Детали комнаты
              _infoRow(
                Icons.monetization_on_rounded,
                'battle_bet'.tr(),
                'battle_coins_count'.tr(args: ['${st.moneyCount}']),
                const Color(0xFFF79009),
              ),
              const SizedBox(height: 12),
              _infoRow(
                Icons.text_snippet_rounded,
                'battle_words_label'.tr(),
                '$wordsCount',
                const Color(0xFF12B76A),
              ),
              const SizedBox(height: 12),
              _infoRow(
                Icons.language_rounded,
                'battle_direction'.tr(),
                st.gameDirectionMode,
                const Color(0xFF2E90FA),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Кнопки ──
        Row(
          children: [
            // Назад
            Expanded(
              child: MyButton(
                onPressed: () {
                  ref.read(battleProvider.notifier).reset();
                },
                buttonColor: Colors.white,
                backButtonColor: const Color(0xFFD0D5DD),
                borderRadius: 14,
                child: Text(
                  'battle_back'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF344054),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Вступить
            Expanded(
              flex: 2,
              child: MyButton(
                onPressed: _isJoining ? null : _handleJoin,
                buttonColor: const Color(0xFF2E90FA),
                backButtonColor: const Color(0xFF1570EF),
                borderRadius: 14,
                child: _isJoining
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'battle_join'.tr(),
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
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF667085),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D2939),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // Handlers
  // ═══════════════════════════════════════════════════
  /// Free daily join quota for non-premium users. Two attempts per local
  /// calendar day; after that the premium dialog is shown. Premium
  /// users bypass the gate entirely.
  static const int _freeDailyJoins = 2;

  Future<void> _handleFind() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    // Premium check: non-premium gets [_freeDailyJoins] free joins per
    // day; after that, the premium dialog is shown.
    final profileAsync = ref.read(getProfileInfoProvider);
    final isPremium = profileAsync.value?.userType == 'pre';
    if (!isPremium) {
      final joinsToday =
          StorageService.instance.getBattleJoinCountToday();
      if (joinsToday >= _freeDailyJoins) {
        _showPremiumDialog();
        return;
      }
    }

    setState(() => _isSearching = true);
    await ref.read(battleProvider.notifier).checkRoom(code);
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _handleJoin() async {
    final st = ref.read(battleProvider);
    final roomId = st.roomId;
    if (roomId.isEmpty) return;

    // Re-check the daily join quota here too — a non-premium user can
    // reach this path via a friend's invite link without going through
    // `_handleFind`, so the check in that method alone isn't enough.
    final profileAsync = ref.read(getProfileInfoProvider);
    final isPremium = profileAsync.value?.userType == 'pre';
    if (!isPremium) {
      final joinsToday =
          StorageService.instance.getBattleJoinCountToday();
      if (joinsToday >= _freeDailyJoins) {
        _showPremiumDialog();
        return;
      }
    }

    // Energy gate — paywall if balance < 1. Premium short-circuits canPlay().
    final canPlay = ref.read(energyProvider.notifier).canPlay();
    if (!canPlay) {
      if (context.mounted) {
        await showEnergyPaywallDialog(context);
      }
      return;
    }

    setState(() => _isJoining = true);
    await ref.read(battleProvider.notifier).joinRoom(roomId);
    // Only count the join AGAINST the daily quota for non-premium users
    // and only after the WS `joinRoom` call actually fired. Premium
    // bypasses the counter entirely so their quota never ticks.
    if (!isPremium) {
      await StorageService.instance.incrementBattleJoinCountToday();
    }
    if (mounted) setState(() => _isJoining = false);
  }

  /// Premium dialog — same design as BattlePage._showPremiumDialog
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

  /// Map raw error strings to user-friendly localized messages
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    // Daily limit — catch the client-side key AND the Russian phrase
    // the backend still emits, so users on Tajik / English locales
    // don't see Cyrillic text in their error banner.
    if (lower.contains('daily_limit') ||
        lower.contains('участвовал') ||
        lower.contains('соревнован') ||
        lower.contains('лимит')) {
      return 'battle_daily_limit_body'.tr();
    }
    if (lower.contains('not_found') || lower.contains('not found')) {
      return 'battle_room_not_found'.tr();
    }
    if (lower.contains('room_closed') || lower.contains('room closed')) {
      return 'battle_room_closed'.tr();
    }
    if (lower.contains('full')) {
      return 'battle_room_full'.tr();
    }
    if (lower.contains('started') || lower.contains('in_progress')) {
      return 'battle_room_already_started'.tr();
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'battle_connection_timeout'.tr();
    }
    return raw;
  }
}
