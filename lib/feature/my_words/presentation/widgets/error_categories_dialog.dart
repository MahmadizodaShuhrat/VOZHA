// Error categories dialog - shows categories that have error words
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/utils/app_locale_utils.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/battle_download_dialog.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/my_words/presentation/screens/error_words_page.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

/// Groups error words (state < 0) by category and shows a dialog
/// with categories that have errors (mirrors Unity's GetWordsErrorsByCategory).
void alertDialogWidget(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, _) {
          final progress = ref.watch(progressProvider);

          // Collect all error words from all directions
          final List<WordProgress> errorWords = [];
          for (final entry in progress.dirs.entries) {
            for (final word in entry.value) {
              if (word.state < 0) {
                errorWords.add(word);
              }
            }
          }

          // Look up categories from provider for icons
          final categoriesAsync = ref.watch(categoriesFlutterProvider);
          final Map<String, String> nameToIcon = {};
          final Map<int, String> idToName = {};

          categoriesAsync.whenData((cats) {
            final lang = normalizeCategoryLanguageCode(
              context.locale.languageCode,
            );
            for (final cat in cats) {
              if (cat.icon.isNotEmpty) {
                nameToIcon[cat.getLocalizedName(lang)] = cat.icon;
                for (final name in cat.name.values) {
                  nameToIcon[name] = cat.icon;
                }
              }
              idToName[cat.id] = cat.getLocalizedName(lang);
            }
          });

          // Group by categoryName (enriched by progress_provider)
          final Map<String, ({String? icon, int count, List<WordProgress> words})> errorCategories = {};
          for (final word in errorWords) {
            // Resolve category name: enriched name → API lookup → skip if unknown
            String name = idToName[word.categoryId] ?? word.categoryName;
            // Агар номи категория холӣ бошад — "Дигар" нишон медиҳем
            if (name.isEmpty) name = 'other'.tr();

            final existing = errorCategories[name];
            if (existing != null) {
              errorCategories[name] = (
                icon: existing.icon,
                count: existing.count + 1,
                words: [...existing.words, word],
              );
            } else {
              errorCategories[name] = (
                icon: nameToIcon[name],
                count: 1,
                words: [word],
              );
            }
          }

          final categories = errorCategories.entries.toList();

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
                    'my_errors'.tr(),
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
              constraints: const BoxConstraints(
                maxHeight: 400,
                minHeight: 300,
                maxWidth: 350,
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
                          final errorCount = entry.value.count;

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
                                final categoryErrors = entry.value.words;

                                // Check if category resources are downloaded
                                final hasRes = await CategoryResourceService.hasResources(categoryId);
                                if (!hasRes) {
                                  // Find category DTO from provider
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
                                    builder: (_) => ErrorWordsPage(
                                      categoryId: categoryId,
                                      categoryName: categoryName,
                                      categoryIconUrl: entry.value.icon,
                                      errorWords: categoryErrors,
                                    ),
                                  ),
                                );
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                              child: _buildCategoryIcon(entry.value.icon),
                              ),
                              title: Text(
                                categoryName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$errorCount',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
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
}

/// Builds a category icon widget from a network URL, or fallback icon
Widget _buildCategoryIcon(String? iconUrl) {
  const size = 40.0;
  if (iconUrl != null &&
      iconUrl.isNotEmpty &&
      (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'))) {
    return CachedNetworkImage(
      imageUrl: iconUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFD1E9FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.error_outline, color: Colors.red, size: 22),
      ),
    );
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.error_outline, color: Colors.red, size: 22),
  );
}
