import 'package:vozhaomuz/core/constants/app_constants.dart';

/// Builds the full avatar URL from whatever format the API returns.
///
/// The API sometimes returns:
///   - Full path: `/files/avatars/uuid.png`
///   - Just filename: `uuid.jpg`
///
/// This helper ensures a correct URL in both cases.
String buildAvatarUrl(String url) {
  if (url.startsWith('http')) return url; // already a full URL
  if (url.startsWith('/files/avatars/')) {
    return '${ApiConstants.baseUrl}$url';
  }
  return '${ApiConstants.baseUrl}${ApiConstants.filesAvatars}$url';
}

/// Public Cloudflare R2 bucket where banner artwork actually lives.
/// `api.vozhaomuz.com/files/banners/...` returns 404 because the API
/// host doesn't serve banner media; verified by direct probe on
/// 2026-05-03. The `file_name` column in Postgres is just the R2
/// object key with a `files/` prefix that we strip here.
const _bannerCdnBase = 'https://pub-d585333316fe4038b47813111c1609e0.r2.dev';

/// Builds the full banner URL from whatever format the backend admin
/// stored. Observed shapes from production:
///   - Full URL: `https://...png` — used as-is.
///   - Legacy Unity key: `files/banners/banner_premium_android`
///     → R2 object: `banners/banner_premium_android` (no extension).
///   - Modern admin upload: `files/banners/20260503T...png`
///     → R2 object: `banners/20260503T...png` (extension already there).
///
/// In both legacy and modern cases the R2 object key is exactly the
/// `file_name` minus the `files/` prefix — extension handling is the
/// admin's responsibility, never ours.
///
/// Returns the empty string for a missing/empty `fileName` so callers
/// can short-circuit to a placeholder.
String buildBannerUrl(String fileName) {
  if (fileName.isEmpty) return '';
  if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
    return fileName;
  }
  // Strip leading slash and the `files/` prefix the API attaches —
  // R2 object keys live at the bucket root.
  var key = fileName;
  if (key.startsWith('/')) key = key.substring(1);
  if (key.startsWith('files/')) key = key.substring('files/'.length);
  return '$_bannerCdnBase/$key';
}
