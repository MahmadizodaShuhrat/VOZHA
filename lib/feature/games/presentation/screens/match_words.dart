// import 'dart:io'; // removed: no longer loading DB from assets

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'package:path_provider/path_provider.dart'; // removed: no longer loading DB
// import 'package:sqflite/sqflite.dart'; // removed: no longer using SQLite directly
// import 'package:path/path.dart'; // removed: no longer constructing DB paths
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/home/data/categories_repository.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_lessons_page.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/choose_learn_know_page.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/user_level_provider.dart';
import 'package:vozhaomuz/shared/widgets/download_dialog.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/core/providers/service_providers.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/category_setting.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

// Old local Category class replaced by CategoryFlutterDto from API
// class Category { ... }

class Subcategory {
  final int id;
  final String name;
  final int categoryId;

  Subcategory({required this.id, required this.name, required this.categoryId});

  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['Id'],
      name: map['name'] ?? '',
      categoryId: map['CategoryId'],
    );
  }
}

class Word {
  final int id;
  final String word;
  final String translation;
  final String transcription;
  final String status;
  final int categoryId;

  Word({
    required this.id,
    required this.word,
    required this.translation,
    required this.transcription,
    required this.status,
    required this.categoryId,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['Id'] as int,
      word: map['word'] as String,
      translation: map['translation'] as String,
      transcription: map['transcription'] as String? ?? '',
      status: map['Status'] ?? '',
      categoryId: map['categoryId'] != null ? map['categoryId'] as int : 0,
    );
  }
}

// Old getCategories from SQLite replaced by CategoriesRepository
Future<List<CategoryFlutterDto>> getCategories(Locale locale) async {
  final repository = CategoriesRepository();
  return await repository.getCategories();
}

class CategoryPage extends ConsumerStatefulWidget {
  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  List<CategoryFlutterDto> _allCategories = [];
  bool _loadingDone = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Fetch word progress from backend so learnedWords count is correct
    Future.microtask(() {
      ref.read(progressProvider.notifier).fetchProgressFromBackend();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await ref.read(categoriesFlutterProvider.future);

    if (!mounted) return;
    setState(() {
      _allCategories = categories;
      _loadingDone = true;
    });
  }

  // TODO: Remove or replace with API-based logic
  // void printTableColumns() async {
  //   final db = await DatabaseHelper.database;
  //   final result = await db.rawQuery("PRAGMA table_info(TjToEn)");
  //   for (var row in result) {
  //     print(row['name']);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    ref.listen<Locale>(localeProvider, (previous, next) {
      _loadCategories();
    });
    final locale = ref.watch(localeProvider);
    final langCode = locale.languageCode == 'tg' ? 'tj' : locale.languageCode;
    return Scaffold(
      backgroundColor: Color(0xFFF5FAFF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Color(0xFFF5FAFF),
        title: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  // Shrink the title when OS font scale is >1.0 so long
                  // Cyrillic headers aren't clipped on phones where the
                  // user bumped accessibility font size.
                  child: Text(
                    'What_do_you_want_to_learn?'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                icon: Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
      body: (_loadingDone && _allCategories.isEmpty)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'no_internet_title'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _loadingDone = false);
                        ref.invalidate(categoriesFlutterProvider);
                        _loadCategories();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E90FA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('retry'.tr(), style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          : _allCategories.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                final selectedIds = ref.watch(
                  progressProvider.select((p) => p.selectedIds),
                );
                final isPremium = ref.watch(isPremiumProvider);
                final userLevel = ref.watch(userLevelProvider);
                final progress = ref.watch(progressProvider);
                final userOrgId =
                    ref.watch(getProfileInfoProvider).value?.organizationId ?? 0;

                // Показываем только категории, выбранные пользователем
                var filteredCategories = selectedIds.isEmpty
                    ? _allCategories
                    : _allCategories
                          .where((cat) => selectedIds.contains(cat.id))
                          .toList();

                // Unity UIHomePage.cs L540: non-premium users only see
                // !Category.IsPremium && !Category.IsSpecial
                if (!isPremium) {
                  filteredCategories = filteredCategories
                      .where((cat) => !cat.isPremium && !cat.isSpecial)
                      .toList();
                }

                // Organization filter: org-specific categories (English 24 etc.)
                // require BOTH user in organization AND user is premium.
                filteredCategories = filteredCategories.where((cat) {
                  final orgs = cat.parsedInfo?.organizations ?? [];
                  if (orgs.isEmpty) return true;
                  return orgs.contains(userOrgId) && isPremium;
                }).toList();

                // Fully learned categories stay visible (shown with yellow background)

                if (filteredCategories.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'no_categories_selected'.tr(),
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView(
                  children: filteredCategories.map((cat) {
                    final info = cat.parsedInfo;

                    // Count learned words for this category
                    int learnedWords = 0;
                    for (final entry in progress.dirs.values) {
                      for (final wp in entry) {
                        if (wp.categoryId == cat.id &&
                            wp.state != 0) {
                          learnedWords++;
                        }
                      }
                    }

                    // Compute effective level for THIS category
                    // Only auto-bump UP from global userLevel, never down
                    // Categories not yet completed stay at userLevel (from settings)
                    final lvl1 = info?.countWordsLevels[1] ?? 0;
                    final lvl2 = info?.countWordsLevels[2] ?? 0;
                    int effectiveLevel = userLevel;
                    if (lvl1 > 0 && learnedWords >= lvl1 && effectiveLevel < 2) {
                      effectiveLevel = 2;
                    }
                    if (lvl1 > 0 && lvl2 > 0 && learnedWords >= lvl1 + lvl2 && effectiveLevel < 3) {
                      effectiveLevel = 3;
                    }

                    // Cumulative word count for progress bar (sum levels 1..effectiveLevel)
                    int totalWords = 0;
                    for (int l = 1; l <= effectiveLevel; l++) {
                      totalWords += info?.countWordsLevels[l] ?? 0;
                    }
                    // Fallback: if no per-level data, use total category words
                    if (totalWords == 0) totalWords = info?.countWords ?? 0;

                    final progressValue = totalWords > 0
                        ? (learnedWords / totalWords).clamp(0.0, 1.0)
                        : 0.0;

                    // Check if ALL levels are fully learned
                    final totalAllLevels = info?.countWords ?? 0;
                    final isFullyLearned = totalAllLevels > 0 && learnedWords >= totalAllLevels;

                    return GestureDetector(
                      onTap: () async {
                        final needsDownload =
                            await CategoryResourceService.needsUpdate(cat);
                        if (!needsDownload) {
                          if (context.mounted) {
                            // Check if category has tests/workbook
                            final hasExtra =
                                await CategoryDbHelper.categoryHasTestsOrWorkbook(cat.id);
                            if (!context.mounted) return;
                            if (hasExtra) {
                              // Has tests/workbook → show lesson list
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                    name: 'CourseLessonsPage',
                                  ),
                                  builder: (_) => CourseLessonsPage(
                                    categoryId: cat.id,
                                    categoryTitle: cat.getLocalizedName(langCode),
                                  ),
                                ),
                              );
                            } else {
                              // Only learning words → go directly to word learning
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChoseLearnKnowPage(
                                    categoryId: cat.id,
                                  ),
                                ),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) {
                            await showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => DownloadDialog(category: cat),
                            );
                            // After download, auto-navigate
                            if (!context.mounted) return;
                            final downloaded =
                                await CategoryResourceService.hasResources(cat.id);
                            if (!downloaded || !context.mounted) return;
                            final hasExtra =
                                await CategoryDbHelper.categoryHasTestsOrWorkbook(cat.id);
                            if (!context.mounted) return;
                            if (hasExtra) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                    name: 'CourseLessonsPage',
                                  ),
                                  builder: (_) => CourseLessonsPage(
                                    categoryId: cat.id,
                                    categoryTitle: cat.getLocalizedName(langCode),
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChoseLearnKnowPage(
                                    categoryId: cat.id,
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 10,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isFullyLearned ? const Color(0xFFFFF3C4) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // ── Category icon ──
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  cat.icon.isNotEmpty &&
                                      (cat.icon.startsWith('http://') ||
                                          cat.icon.startsWith('https://'))
                                  ? CachedNetworkImage(
                                      imageUrl: cat.icon,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      placeholder: (_, s) => Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Color(0xFFD1E9FF),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, e, s) => Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Color(0xFFD1E9FF),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.category,
                                          size: 26,
                                          color: Color(0xFF2E90FA),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFD1E9FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.category,
                                        size: 26,
                                        color: Color(0xFF2E90FA),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),

                            // ── Name + Progress bar + Count ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.getLocalizedName(langCode),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Color(0xFF344054),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Progress bar
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: progressValue,
                                            minHeight: 8,
                                            backgroundColor: const Color(
                                              0xFFD1E9FF,
                                            ),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  const Color(0xFF2E90FA),
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Word count
                                      Text(
                                        '$learnedWords / $totalWords',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF475467),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(3, (lvlIdx) {
                                          final level = lvlIdx + 1;
                                          // Compute cumulative threshold for badge:
                                          // countWordsLevels values are per-level, so sum up to check
                                          // Badge 1 gold: learned >= lvl1
                                          // Badge 2 gold: learned >= lvl1 + lvl2
                                          // Badge 3 gold: learned >= lvl1 + lvl2 + lvl3
                                          int cumulativeThreshold = 0;
                                          for (int l = 1; l <= level; l++) {
                                            cumulativeThreshold += info?.countWordsLevels[l] ?? 0;
                                          }
                                          // Badge is done if:
                                          // - Category has words AND cumulative threshold is 0
                                          //   (no words at any level up to this one → auto-done)
                                          // - OR learned >= cumulative threshold
                                          final totalCatWords = info?.countWords ?? 0;
                                          final isLvlDone = totalCatWords > 0 &&
                                              (cumulativeThreshold == 0 || learnedWords >= cumulativeThreshold);

                                          // Ранги контейнер ва расм
                                          Color bgColor;
                                          String imgAsset;
                                          if (isLvlDone) {
                                            bgColor = const Color(
                                              0xFFFFAB00,
                                            ); // gold
                                            imgAsset =
                                                'assets/images/UIHome/vozhalevelwhite.png';
                                          } else if (level == effectiveLevel) {
                                            bgColor = const Color(
                                              0xFF2E90FA,
                                            ); // blue
                                            imgAsset =
                                                'assets/images/UIHome/vozhalevelwhite.png';
                                          } else {
                                            bgColor = const Color(
                                              0xFFE8EDF2,
                                            ); // light gray
                                            imgAsset =
                                                'assets/images/UIHome/vozhalevel.png';
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                child: Image.asset(
                                                  imgAsset,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // const SizedBox(width: 10),

                            // ── 3 Vozha level icons ──
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}

void showCategoryDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: 650,
          decoration: BoxDecoration(
            color: Color(0xFFF5FAFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                Expanded(child: CategoryPage()),
                // ── Add category button (fixed at bottom) ──
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: 20,
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      return MyButton(
                        height: 48,
                        borderRadius: 12,
                        backButtonColor: const Color(0xFF1849A9),
                        buttonColor: const Color(0xFF2E90FA),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          final user = ref.read(getProfileInfoProvider).value;
                          if (user != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategorySetting(user: user),
                              ),
                            ).then((_) {
                              if (context.mounted) {
                                ref.invalidate(categoriesFlutterProvider);
                              }
                            });
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'add_category'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}
