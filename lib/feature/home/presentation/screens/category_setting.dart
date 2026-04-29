import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/feature/profile/data/model/profile_info_dto.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/choice_only_six_category.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class CategorySetting extends ConsumerStatefulWidget {
  final ProfileInfoDto user;
  const CategorySetting({super.key, required this.user});

  @override
  ConsumerState<CategorySetting> createState() => _CategorySettingState();
}

class _CategorySettingState extends ConsumerState<CategorySetting> {
  List<CategoryFlutterDto> _allCategories = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(getProfileInfoProvider.notifier).getProfile();
    });
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ref.read(categoriesFlutterProvider.future);
      if (!mounted) return;
      setState(() {
        _allCategories = categories;
      });
    } catch (e) {
      debugPrint('❌ [CategorySetting] Failed to load categories: $e');
    }
  }

  bool _isCategoryUnlocked(int index) {
    final isPremium = widget.user.userType == 'pre';
    if (isPremium) return true;
    // Unity UIChangeSelectionCategory.cs L109: lock if Category.IsPremium
    if (index < 0 || index >= _allCategories.length) return false;
    return !_allCategories[index].isPremium;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(
      progressProvider.select((p) => p.selectedIds),
    );
    final progressDirs = ref.watch(progressProvider.select((p) => p.dirs));
    final locale = ref.watch(localeProvider);
    final langCode = locale.languageCode == 'tg' ? 'tj' : locale.languageCode;

    // Count learned words (state == 5) per category
    final learnedPerCategory = <int, int>{};
    for (final words in progressDirs.values) {
      for (final w in words) {
        if (w.state == 5) {
          learnedPerCategory[w.categoryId] =
              (learnedPerCategory[w.categoryId] ?? 0) + 1;
        }
      }
    }

    // Filter by organization: org-specific categories (English 24 etc.)
    // require BOTH user in organization AND user is premium.
    final userOrgId = widget.user.organizationId ?? 0;
    final userIsPremium = widget.user.userType == 'pre';
    final visibleCategories = _allCategories.where((cat) {
      final orgs = cat.parsedInfo?.organizations ?? [];
      if (orgs.isEmpty) return true;
      return orgs.contains(userOrgId) && userIsPremium;
    }).toList();

    // Разделяем категории на открытые и закрытые
    final unlockedCategories = <MapEntry<int, CategoryFlutterDto>>[];
    final lockedCategories = <MapEntry<int, CategoryFlutterDto>>[];

    for (int i = 0; i < visibleCategories.length; i++) {
      final cat = visibleCategories[i];
      final originalIndex = _allCategories.indexOf(cat);
      if (_isCategoryUnlocked(originalIndex)) {
        unlockedCategories.add(MapEntry(originalIndex, cat));
      } else {
        lockedCategories.add(MapEntry(originalIndex, cat));
      }
    }

    // Интихобшудаҳо ба боло, дар дохили гурӯҳ аз рӯйи ID
    unlockedCategories.sort((a, b) {
      final aSelected = selectedIds.contains(a.value.id) ? 0 : 1;
      final bSelected = selectedIds.contains(b.value.id) ? 0 : 1;
      if (aSelected != bSelected) return aSelected.compareTo(bSelected);
      return a.value.id.compareTo(b.value.id);
    });
    lockedCategories.sort((a, b) => a.value.id.compareTo(b.value.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Кнопка назад ───
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 5),
                  child: Icon(Icons.arrow_back_ios, size: 28),
                ),
              ),

              // ─── Заголовок ───
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: Text(
                  'select_categories'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D2939),
                  ),
                ),
              ),

              // ─── Список категорий ───
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Открытые категории ──
                    if (unlockedCategories.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            for (
                              int i = 0;
                              i < unlockedCategories.length;
                              i++
                            ) ...[
                              _buildCategoryTile(
                                cat: unlockedCategories[i].value,
                                langCode: langCode,
                                isSelected: selectedIds.contains(
                                  unlockedCategories[i].value.id,
                                ),
                                isLocked: false,
                                selectedIds: selectedIds,
                                learnedCount:
                                    learnedPerCategory[unlockedCategories[i]
                                        .value
                                        .id] ??
                                    0,
                              ),
                              if (i < unlockedCategories.length - 1)
                                const Divider(
                                  color: Color(0xFFF2F4F7),
                                  height: 0,
                                  indent: 55,
                                ),
                            ],
                          ],
                        ),
                      ),

                    // ── Закрытые категории (серая секция) ──
                    if (lockedCategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAEDF1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            for (
                              int i = 0;
                              i < lockedCategories.length;
                              i++
                            ) ...[
                              _buildCategoryTile(
                                cat: lockedCategories[i].value,
                                langCode: langCode,
                                isSelected: false,
                                isLocked: true,
                                selectedIds: selectedIds,
                                learnedCount:
                                    learnedPerCategory[lockedCategories[i]
                                        .value
                                        .id] ??
                                    0,
                              ),
                              if (i < lockedCategories.length - 1)
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  height: 0,
                                  indent: 55,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // ─── Кнопка сохранить ───
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MyButton(
                  depth: 4,
                  buttonColor: const Color(0xFF2E90FA),
                  backButtonColor: const Color(0xFF1849A9),
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (selectedIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('select_at_least_one_category'.tr()),
                          backgroundColor: Colors.red.shade400,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                  },
                  child: Text(
                    'save_and_exit'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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

  /// Один элемент категории (простой: иконка + название + чекбокс/замок)
  Widget _buildCategoryTile({
    required CategoryFlutterDto cat,
    required String langCode,
    required bool isSelected,
    required bool isLocked,
    required List<int> selectedIds,
    required int learnedCount,
  }) {
    // Check if category is fully learned
    final totalWords = cat.parsedInfo?.countWords ?? 0;
    final isFullyLearned = totalWords > 0 && learnedCount >= totalWords;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isLocked) {
          _showPremiumDialog();
        } else {
          final notifier = ref.read(progressProvider.notifier);
          if (isSelected) {
            notifier.toggleCategory(cat.id);
          } else {
            if (selectedIds.length < 6) {
              notifier.toggleCategory(cat.id);
            } else {
              showOnlySixCategory(context);
            }
          }
        }
      },
      child: Container(
        decoration: isFullyLearned
            ? BoxDecoration(
                color: const Color(0xFFFFF3C4), // yellow highlight
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // ─── Иконка категории ───
              _buildCategoryIcon(cat),
              const SizedBox(width: 12),

              // ─── Название ───
              Expanded(
                child: Text(
                  cat.getLocalizedName(langCode),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isLocked
                        ? const Color(0xFF98A2B3)
                        : const Color(0xFF344054),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ─── Checkbox или замок ───
              if (isLocked)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: Color(0xFF98A2B3),
                  ),
                )
              else
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    activeColor: const Color(0xFF2E90FA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: const BorderSide(color: Color(0xFFD0D5DD), width: 1.5),
                    value: isSelected,
                    onChanged: (value) {
                      final notifier = ref.read(progressProvider.notifier);
                      if (value == true) {
                        if (selectedIds.length < 6) {
                          notifier.toggleCategory(cat.id);
                        } else {
                          showOnlySixCategory(context);
                        }
                      } else {
                        notifier.toggleCategory(cat.id);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Иконка категории (сеть или placeholder)
  Widget _buildCategoryIcon(CategoryFlutterDto cat) {
    if (cat.icon.isNotEmpty &&
        (cat.icon.startsWith('http://') || cat.icon.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: cat.icon,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorWidget: (_, e, s) => _buildPlaceholderIcon(),
        ),
      );
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFD1E9FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.category_rounded,
        size: 20,
        color: Color(0xFF2E90FA),
      ),
    );
  }

  /// Premium dialog — shows when non-premium user taps locked category
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
}
