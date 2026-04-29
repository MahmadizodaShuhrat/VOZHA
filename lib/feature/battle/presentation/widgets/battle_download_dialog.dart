import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Диалог скачивания категории для Battle.
/// Как DownloadDialog, но без навигации — просто pop(true/false).
class BattleDownloadDialog extends ConsumerStatefulWidget {
  const BattleDownloadDialog({super.key, required this.category});
  final CategoryFlutterDto category;

  @override
  ConsumerState<BattleDownloadDialog> createState() =>
      _BattleDownloadDialogState();
}

class _BattleDownloadDialogState extends ConsumerState<BattleDownloadDialog> {
  double _currentProgress = 0;
  bool _isDownloading = false;
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
      setState(() => _currentProgress = 1.0);
      // Просто закрываем диалог — загрузка вопросов продолжится
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } else if (!(_cancelToken?.isCancelled ?? false)) {
      setState(() {
        _hasError = true;
        _isDownloading = false;
      });
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  /// Иконка категории (сеть или placeholder)
  Widget _buildCategoryIcon(CategoryFlutterDto cat) {
    if (cat.icon.isNotEmpty &&
        (cat.icon.startsWith('http://') || cat.icon.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: cat.icon,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildPlaceholderIcon(),
          errorWidget: (_, __, ___) => _buildPlaceholderIcon(),
        ),
      );
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFD1E9FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.category_rounded,
        size: 32,
        color: Color(0xFF2E90FA),
      ),
    );
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
              'battle_download_wait'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    value: _isDownloading ? _currentProgress : null,
                    strokeWidth: 10,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ),
                _buildCategoryIcon(widget.category),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _hasError ? 'loading_error'.tr() : 'battle_preparing_words'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            // ── Название категории ──
            // Text(
            //   widget.category.getLocalizedName(context.locale.languageCode),
            //   textAlign: TextAlign.center,
            //   style: GoogleFonts.inter(
            //     fontSize: 14,
            //     fontWeight: FontWeight.w600,
            //     color: const Color(0xFF2E90FA),
            //   ),
            // ),
            const SizedBox(height: 6),
            if (_isDownloading || _hasError)
              Text(
                _hasError
                    ? 'retry'.tr()
                    : '$percent% ${'battle_out_of'.tr()} 100%',
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
                _hasError ? 'retry'.tr() : 'battle_prepare_btn'.tr(),
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
                'cancel'.tr(),
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
