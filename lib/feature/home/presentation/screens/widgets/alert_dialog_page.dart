import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_lessons_page.dart';
import 'package:vozhaomuz/shared/widgets/download_dialog.dart';

void showCustomDialog(BuildContext context, bool isShowProgress) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: _CategoryDialogContent(isShowProgress: isShowProgress),
      );
    },
  );
}

class _CategoryDialogContent extends ConsumerWidget {
  final bool isShowProgress;
  const _CategoryDialogContent({required this.isShowProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesFlutterProvider);
    final locale = ref.watch(localeProvider);
    final langCode = locale.languageCode == 'tg' ? 'tj' : locale.languageCode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  // FittedBox keeps the title at 20pt on normal screens
                  // and shrinks it just enough to fit when the OS font
                  // scale is >1.0 (Honor / elderly users bump it to 1.3+).
                  // Without this, long Tajik headers are ellipsized to
                  // "Шумо чӣ омӯхтан мех..." on ~30 % of Android devices.
                  child: Text(
                    'What_do_you_want_to_learn?'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close),
                  ),
                  SizedBox(height: 50),
                ],
              ),
            ],
          ),

          // Categories list from API
          categoriesAsync.when(
            data: (categories) {
              return Column(
                children: categories.map((cat) {
                  return _buildCategoryCard(
                    cat,
                    langCode,
                    context,
                    isShowProgress,
                  );
                }).toList(),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('loading_error'.tr(), style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    CategoryFlutterDto cat,
    String langCode,
    BuildContext context,
    bool isShowProgress,
  ) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context); // Close dialog
        final langCode2 = langCode;
        final catTitle = cat.getLocalizedName(langCode2);
        final needsDownload = await CategoryResourceService.needsUpdate(cat);
        if (!needsDownload) {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'CourseLessonsPage'),
                builder: (_) => CourseLessonsPage(
                  categoryId: cat.id,
                  categoryTitle: catTitle,
                ),
              ),
            );
          }
        } else {
          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => DownloadDialog(category: cat),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  cat.icon.isNotEmpty &&
                      (cat.icon.startsWith('http://') ||
                          cat.icon.startsWith('https://'))
                  ? CachedNetworkImage(
                      imageUrl: cat.icon,
                      width: 35,
                      height: 35,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Color(0xFFD1E9FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Color(0xFFD1E9FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.category,
                          size: 20,
                          color: Color(0xFF2E90FA),
                        ),
                      ),
                    )
                  : Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: Color(0xFFD1E9FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category,
                        size: 20,
                        color: Color(0xFF2E90FA),
                      ),
                    ),
            ),
            SizedBox(width: 12),

            // Category info
            isShowProgress
                ? Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.getLocalizedName(langCode),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: 0,
                                borderRadius: BorderRadius.circular(10),
                                backgroundColor: Colors.grey.shade300,
                                color: Colors.blue,
                                minHeight: 6,
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              "0",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(width: 5),
                            SvgPicture.asset("assets/images/coin (1).svg"),
                            SizedBox(width: 5),
                            SvgPicture.asset("assets/images/coin (1).svg"),
                            SizedBox(width: 5),
                            SvgPicture.asset("assets/images/coin (2).svg"),
                          ],
                        ),
                      ],
                    ),
                  )
                : Expanded(
                    child: Text(
                      cat.getLocalizedName(langCode),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

            // Premium badge
            if (cat.isPremium)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFFFAA00),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
