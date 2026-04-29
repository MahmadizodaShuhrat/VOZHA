import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/feature/battle/providers/lobby_provider.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/battle/data/battle_state.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';

import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/core/services/unity_ad_service.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/battle_download_dialog.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/shared/widgets/energy_paywall_dialog.dart';

/// Список публичных комнат в реальном времени.
/// Встраивается в JoinRoomPage.
class PublicRoomsPage extends ConsumerStatefulWidget {
  /// ID выбранной комнаты (для подсветки)
  final String? selectedRoomId;

  /// Колбэк при выборе комнаты
  final ValueChanged<String>? onRoomSelected;

  const PublicRoomsPage({super.key, this.selectedRoomId, this.onRoomSelected});

  @override
  ConsumerState<PublicRoomsPage> createState() => _PublicRoomsPageState();
}

class _PublicRoomsPageState extends ConsumerState<PublicRoomsPage> {
  @override
  void initState() {
    super.initState();
    // Подключаемся к лобби для получения публичных комнат
    Future.microtask(() {
      ref.read(lobbyProvider.notifier).connect();
    });
  }

  /// Get category name by ID from categories provider
  String _getCategoryName(WidgetRef ref, int categoryId, BuildContext context) {
    final categoriesAsync = ref.watch(categoriesFlutterProvider);
    final langCode = context.locale.languageCode == 'tg'
        ? 'tj'
        : context.locale.languageCode;
    return categoriesAsync.whenOrNull(
          data: (categories) {
            final cat = categories.where((c) => c.id == categoryId);
            if (cat.isNotEmpty) {
              return cat.first.getLocalizedName(langCode);
            }
            return null;
          },
        ) ??
        'battle_category_fallback'.tr(args: ['$categoryId']);
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyProvider);

    if (lobby.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (lobby.rooms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
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
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 40,
              color: const Color(0xFF98A2B3).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'battle_no_public_rooms'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'battle_create_yours'.tr(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: lobby.rooms.map((room) {
        final isSelected = widget.selectedRoomId == room.roomId;
        return GestureDetector(
          onTap: () {
            widget.onRoomSelected?.call(room.roomId);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color.fromARGB(255, 254, 254, 254)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color.fromARGB(255, 57, 209, 223)
                    : const Color(0xFFE4E7EC),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color.fromARGB(255, 57, 209, 223)
                      : const Color(0xFFD0D5DD),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Аватар создателя
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected
                      ? const Color(0xFF2E90FA).withValues(alpha: 0.15)
                      : const Color(0xFFEFF8FF),
                  child: Text(
                    room.creatorName.isNotEmpty
                        ? room.creatorName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E90FA),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Информация
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.creatorName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getCategoryName(ref, room.categoryId, context),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                // Кол-во слов
                Text(
                  'battle_words_count'.tr(args: ['${room.wordsCount}']),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF344054),
                  ),
                ),
                const SizedBox(width: 12),
                // Монеты
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/battle/coinfull.png',
                      height: 16,
                      width: 16,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${room.moneyCount}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF79009),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Счётчик участников
                Text(
                  '${room.currentMembers}/${room.maxMembers}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
                // Иконка выбора
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    size: 22,
                    color: Color(0xFF2E90FA),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Полноценная страница «Список комнат» — 3-я вкладка.
class PublicRoomsFullPage extends ConsumerStatefulWidget {
  const PublicRoomsFullPage({super.key});

  @override
  ConsumerState<PublicRoomsFullPage> createState() =>
      _PublicRoomsFullPageState();
}

class _PublicRoomsFullPageState extends ConsumerState<PublicRoomsFullPage> {
  String? _selectedRoomId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(lobbyProvider.notifier).connect();
    });
    // Предзагрузка рекламы для быстрого показа
    if (UnityAdService.instance.isInitialized) {
      UnityAdService.instance.loadRewardedAd(onLoaded: (_) {});
    }
  }

  // ── Диалог «Дневной лимит исчерпан» (фоллбэк от сервера) ──
  void _showDailyLimitDialog(String message) {
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
                // The backend only ships a Russian copy of this message,
                // so using its text directly breaks Tajik and English
                // users. Read the localised string instead — the server
                // already told us WHICH error to show (`daily_limit_reached`)
                // via the enum/phase; the wording belongs to the client.
                'battle_daily_limit_body'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // «Купить премиум»
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
                buttonColor: const Color(0xff57A931),
                backButtonColor: const Color.fromARGB(255, 61, 113, 36),
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
              // «Ясно»
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

  // ── Диалог «Премиум + Реклама» (Unity UIRequirePremiumWithAd) ──
  // Показывается ПЕРЕД joinRoom для нон-премиум пользователей
  void _showPremiumWithAdDialog() {
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // «Купить премиум»
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
                buttonColor: const Color(0xff57A931),
                backButtonColor: const Color.fromARGB(255, 61, 113, 36),
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
              // «Продолжить за рекламу»
              const SizedBox(height: 10),
              MyButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Как в Unity: показать рекламу → joinRoom (первая попытка, сервер разрешит)
                  UnityAdService.instance.loadAndShowRewardedAd(
                    onComplete: () {
                      if (_selectedRoomId != null) {
                        _downloadAndJoin(_selectedRoomId!);
                      }
                    },
                  );
                },
                width: double.infinity,
                buttonColor: const Color(0xff2E90FA),
                backButtonColor: const Color.fromARGB(255, 29, 62, 98),
                borderRadius: 14,
                child: Text(
                  'battle_continue_with_ad'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // «Ясно»
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

  // ── Обработчик кнопки «Вступить в комнату» (как Unity UIJoinToRoomList) ──
  void _handleJoinRoom() async {
    if (_selectedRoomId == null) return;

    final profileAsync = ref.read(getProfileInfoProvider);
    final isPremium = profileAsync.value?.userType == 'pre';

    // Как в Unity: нон-премиум + реклама инициализирована → показать диалог ПЕРЕД joinRoom
    if (!isPremium && UnityAdService.instance.isInitialized) {
      _showPremiumWithAdDialog();
      return;
    }

    // Energy gate — paywall if balance < 1. Premium short-circuits canPlay().
    final canPlay = ref.read(energyProvider.notifier).canPlay();
    if (!canPlay) {
      if (context.mounted) {
        await showEnergyPaywallDialog(context);
      }
      return;
    }

    // Премиум или реклама не доступна → скачать категорию и присоединиться
    _downloadAndJoin(_selectedRoomId!);
  }

  /// Скачать категорию (как Unity CollectResources) и присоединиться к комнате
  Future<void> _downloadAndJoin(String roomId) async {
    // Найти categoryId из выбранной комнаты
    final lobby = ref.read(lobbyProvider);
    final room = lobby.rooms.where((r) => r.roomId == roomId);
    if (room.isEmpty) return;

    final categoryId = room.first.categoryId;

    // Проверить, скачан ли курс
    final hasRes = await CategoryResourceService.hasResources(categoryId);
    if (!hasRes) {
      // Найти CategoryFlutterDto
      final categoriesAsync = ref.read(categoriesFlutterProvider);
      final categories = categoriesAsync.value ?? [];
      final catDto = categories.where((c) => c.id == categoryId);

      if (catDto.isNotEmpty && mounted) {
        // Показать диалог скачивания
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BattleDownloadDialog(category: catDto.first),
        );

        // Проверить ещё раз
        final downloaded = await CategoryResourceService.hasResources(
          categoryId,
        );
        if (!downloaded) return; // Скачивание отменено
      } else {
        return;
      }
    }

    // Присоединиться к комнате
    if (mounted) {
      ref.read(battleProvider.notifier).joinRoom(roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyProvider);

    // Слушаем daily_limit_reached от сервера
    ref.listen<BattleState>(battleProvider, (prev, next) {
      if (next.dailyLimitReached && !(prev?.dailyLimitReached ?? false)) {
        // Не вызываем reset() — диалог сам управляет состоянием
        _showDailyLimitDialog(next.errorMessage ?? '');
      }
    });

    if (lobby.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (lobby.rooms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
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
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 48,
              color: const Color(0xFF98A2B3).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'battle_no_available_rooms'.tr(),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF344054),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'battle_create_or_try_later'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      );
    }

    // Если выбранная комната больше не существует — сбросить выбор
    if (_selectedRoomId != null &&
        !lobby.rooms.any((r) => r.roomId == _selectedRoomId)) {
      _selectedRoomId = null;
    }

    final hasSelection = _selectedRoomId != null;

    return Column(
      children: [
        // Scrollable room list
        Expanded(
          child: SingleChildScrollView(
            child: PublicRoomsPage(
              selectedRoomId: _selectedRoomId,
              onRoomSelected: (roomId) {
                setState(() {
                  if (_selectedRoomId == roomId) {
                    _selectedRoomId = null;
                  } else {
                    _selectedRoomId = roomId;
                  }
                });
              },
            ),
          ),
        ),

        // Pinned button at bottom
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: MyButton(
              onPressed: hasSelection ? () => _handleJoinRoom() : null,
              buttonColor: hasSelection
                  ? const Color(0xFF2E90FA)
                  : const Color(0xFF2E90FA),
              backButtonColor: hasSelection
                  ? const Color(0xFF1570EF)
                  : const Color(0xFFffffff),
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(vertical: 16),
              depth: hasSelection ? 4 : 2,
              child: Text(
                'battle_join_room'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
