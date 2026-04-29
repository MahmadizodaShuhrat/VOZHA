import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_lessons_page.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class DownloadDialog extends ConsumerStatefulWidget {
  const DownloadDialog({super.key, required this.category});
  final CategoryFlutterDto category;

  @override
  ConsumerState<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<DownloadDialog> {
  double _currentProgress = 0;
  bool _isDownloading = false;
  bool _navigated = false;
  bool _hasError = false;
  CancelToken? _cancelToken;

  Future<void> _startDownload() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _hasError = false;
      // Don't reset _currentProgress — resume from where we stopped
    });

    _cancelToken = CancelToken();

    final result = await CategoryResourceService.downloadAndExtract(
      widget.category,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _currentProgress = progress);
        }
      },
      cancelToken: _cancelToken,
    );

    if (!mounted) return;

    if (result != null) {
      // Донлоад муваффақ! Re-enrich progress words with newly downloaded category
      ref.read(progressProvider.notifier).fetchProgressFromBackend();
      setState(() => _currentProgress = 1.0);
      _navigateToLearnPage();
    } else if (!(_cancelToken?.isCancelled ?? false)) {
      // Хатогӣ (на бекоркардашуда)
      setState(() {
        _hasError = true;
        _isDownloading = false;
      });
    }
  }

  void _navigateToLearnPage() {
    if (_navigated || !mounted) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final locale = context.locale;
      final langCode = locale.languageCode == 'tg' ? 'tj' : locale.languageCode;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'CourseLessonsPage'),
          builder: (_) => CourseLessonsPage(
            categoryId: widget.category.id,
            categoryTitle: widget.category.getLocalizedName(langCode),
          ),
        ),
      );
    });
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_currentProgress * 100).clamp(0, 100).toStringAsFixed(0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'download_please_wait'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _isDownloading ? (_currentProgress > 0 ? _currentProgress : null) : 0,
                    strokeWidth: 10,
                    backgroundColor: Colors.blue.shade50,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ),
                // Иконка категории аз API
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.category.icon,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const SizedBox(
                      width: 60,
                      height: 60,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.category,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _hasError
                  ? 'download_error'.tr()
                  : _isDownloading
                  ? 'download_preparing'.tr()
                  : 'download_start_prompt'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (_isDownloading || _hasError)
              Text(
                _hasError
                    ? 'download_please_retry'.tr()
                    : 'download_progress'.tr(args: [percent]),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 24),
            MyButton(
              depth: (_isDownloading && !_hasError) ? 0 : 4,
              buttonColor: const Color(0xFFFDE047),
              backButtonColor: const Color(0xFFEAB308),
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              onPressed: _isDownloading && !_hasError ? null : _startDownload,
              child: Text(
                _hasError
                    ? 'download_retry'.tr()
                    : 'download_ready_button'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 10),
            MyButton(
              depth: 4,
              buttonColor: const Color(0xFFE3E8EF),
              backButtonColor: const Color(0xFFCDD5DF),
              borderRadius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              onPressed: _cancelDownload,
              child: Text(
                'download_cancel_button'.tr(),
                style: TextStyle(
                  color: Color(0xFF9AA4B2),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
