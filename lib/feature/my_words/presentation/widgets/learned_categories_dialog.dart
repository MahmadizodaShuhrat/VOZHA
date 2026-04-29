// Learned words categories dialog - shows categories that have learned words
// Mirrors Unity's UIMyLessonsPage UILearnedWords click handler
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/battle_download_dialog.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/my_words/presentation/screens/learned_words_page.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

/// Groups learned words (state >= 4) by category and shows a dialog
/// with categories that have learned words.
/// Also includes locally known words (swiped "Медонам") from DatabaseHelper.
/// Mirrors Unity's UILearnedWords.onClick → UIPopupSelectionCategory flow.
void learnedWordsDialogWidget(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) {
          final progress = ref.watch(progressProvider);

          // Build iconMap from categories: name → iconUrl
          final categoriesAsync = ref.watch(categoriesFlutterProvider);
          final Map<String, String> nameToIcon = {};

          // Build nameMap from categories: id → localized name
          final Map<int, String> idToName = {};
          // Build categoryId set for resolving known words
          final Map<int, CategoryFlutterDto> idToCat = {};

          categoriesAsync.whenData((cats) {
            final lang = context.locale.languageCode;
            for (final cat in cats) {
              if (cat.icon.isNotEmpty) {
                // Map all name variants to icon
                nameToIcon[cat.getLocalizedName(lang)] = cat.icon;
                for (final name in cat.name.values) {
                  nameToIcon[name] = cat.icon;
                }
              }
              idToName[cat.id] = cat.getLocalizedName(lang);
              idToCat[cat.id] = cat;
            }
          });

          // Collect all learned words from all directions
          // Must match the counter in my_words_page._computeWordCounts:
          // Unity: IsWordLearned = State > 0 && !IsFirstSubmitIsLearning
          final List<WordProgress> learnedWords = [];
          final Set<int> learnedWordIds = {};
          for (final entry in progress.dirs.entries) {
            for (final word in entry.value) {
              if (word.state > 0 && !word.firstDone) {
                learnedWords.add(word);
                learnedWordIds.add(word.wordId);
              }
            }
          }

          // Use FutureBuilder to async load locally known words
          return FutureBuilder<List<WordProgress>>(
            future: _loadKnownWordsNotInProgress(learnedWordIds, idToName),
            builder: (context, snapshot) {
              final knownWords = snapshot.data ?? [];
              final allLearned = [...learnedWords, ...knownWords];

              // Unity: if (GetCountLearnedWords() < 4) show UINotEnoughLearnedWords
              if (allLearned.length < 4) {
                // Close the dialog and show SnackBar instead
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('not_enough_learned_words'.tr()),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                });
                return const SizedBox.shrink();
              }

              // Group by categoryName
              final Map<String, ({String? icon, int count, int knownCount, List<WordProgress> words})> learnedCategories = {};
              for (final word in allLearned) {
                String name = '';
                if (idToName.containsKey(word.categoryId)) {
                  name = idToName[word.categoryId]!;
                } else if (word.categoryName.isNotEmpty) {
                  name = word.categoryName;
                }
                if (name.isEmpty) name = 'other'.tr();

                final existing = learnedCategories[name];
                if (existing != null) {
                  learnedCategories[name] = (
                    icon: existing.icon,
                    count: existing.count + 1,
                    knownCount: existing.knownCount + (word.isKnownLocally ? 1 : 0),
                    words: [...existing.words, word],
                  );
                } else {
                  learnedCategories[name] = (
                    icon: nameToIcon[name],
                    count: 1,
                    knownCount: word.isKnownLocally ? 1 : 0,
                    words: [word],
                  );
                }
              }

              final categories = learnedCategories.entries.toList();

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'words_learned_count'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Color(0xFF314456),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Icon(Icons.close, size: 24),
                    ),
                  ],
                ),
                content: ConstrainedBox(
                  // Responsive bounds: on iPhone SE (667pt) minHeight 300
                  // was pushing the dialog past the safe area. On tablets
                  // the 350-wide / 400-tall cap felt cramped. Derive
                  // both from the current screen so the dialog scales
                  // from phone → tablet gracefully.
                  constraints: BoxConstraints(
                    maxHeight: (MediaQuery.of(dialogContext).size.height * 0.6)
                        .clamp(260.0, 560.0),
                    maxWidth: (MediaQuery.of(dialogContext).size.width * 0.9)
                        .clamp(280.0, 480.0),
                  ),
                  child: SizedBox(
                    width: double.maxFinite,
                    child: categories.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'no_words_yet'.tr(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8A97AB),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final entry = categories[index];
                              final categoryName = entry.key;
                              final learnedCount = entry.value.count;
                              final knownCount = entry.value.knownCount;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFEEF2F6),
                                    width: 1.5,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final categoryId = entry.value.words.first.categoryId;
                                    final categoryWords = entry.value.words;

                                    // Check if category resources are downloaded
                                    final hasRes = await CategoryResourceService.hasResources(categoryId);
                                    if (!hasRes) {
                                      final catsAsync = ref.read(categoriesFlutterProvider);
                                      CategoryFlutterDto? catDto;
                                      catsAsync.whenData((cats) {
                                        catDto = cats.cast<CategoryFlutterDto?>().firstWhere(
                                          (c) => c?.id == categoryId,
                                          orElse: () => null,
                                        );
                                      });
                                      if (catDto != null && context.mounted) {
                                        final downloaded = await showDialog<bool>(
                                          context: dialogContext,
                                          barrierDismissible: false,
                                          builder: (_) => BattleDownloadDialog(category: catDto!),
                                        );
                                        if (downloaded != true) return;
                                      }
                                    }
                                    if (!context.mounted) return;
                                    Navigator.of(dialogContext).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LearnedWordsPage(
                                          categoryId: categoryId,
                                          categoryName: categoryName,
                                          learnedWords: categoryWords,
                                        ),
                                      ),
                                    );
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  leading: _buildCategoryIcon(
                                    entry.value.icon,
                                  ),
                                  title: Text(
                                    categoryName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Show known count badge if any
                                      if (knownCount > 0) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2E90FA).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.local_library_outlined,
                                                color: Color(0xFF2E90FA),
                                                size: 12,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '$knownCount',
                                                style: const TextStyle(
                                                  color: Color(0xFF2E90FA),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$learnedCount',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

/// Load locally known wordIds that are NOT already in server progress,
/// enrich them from CategoryDbHelper, and return as WordProgress list.
Future<List<WordProgress>> _loadKnownWordsNotInProgress(
  Set<int> alreadyLearnedIds,
  Map<int, String> idToName,
) async {
  final knownIds = await DatabaseHelper.getKnownWordIds();
  // Filter out words already in server progress
  final newKnownIds = knownIds.difference(alreadyLearnedIds);
  if (newKnownIds.isEmpty) return [];

  // Group by category — we need to load word texts from CategoryDbHelper
  // Since we don't know the categoryId for each wordId upfront,
  // we scan all downloaded categories
  final List<WordProgress> result = [];
  final Set<int> resolved = {};

  // Try to resolve from all available categories
  for (final catId in idToName.keys) {
    final unresolved = newKnownIds.difference(resolved);
    if (unresolved.isEmpty) break;

    try {
      final catWords = await CategoryDbHelper.getWordsForCategory(catId);
      for (final w in catWords) {
        if (unresolved.contains(w.id)) {
          result.add(WordProgress(
            categoryId: catId,
            categoryName: idToName[catId] ?? '',
            wordId: w.id,
            original: w.word,
            transcription: w.transcription,
            translate: w.translation,
            state: 5, // fully learned
            timeout: DateTime.now().add(const Duration(days: 365)),
            firstDone: false,
            isKnownLocally: true,
          ));
          resolved.add(w.id);
        }
      }
    } catch (_) {
      // Category not downloaded — skip
    }
  }

  return result;
}

/// Builds category icon: network image if available, green checkmark fallback
Widget _buildCategoryIcon(String? iconUrl) {
  if (iconUrl != null &&
      iconUrl.isNotEmpty &&
      (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'))) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: iconUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 22,
          ),
        ),
      ),
    );
  }

  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.green.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(
      Icons.check_circle_outline,
      color: Colors.green,
      size: 22,
    ),
  );
}
