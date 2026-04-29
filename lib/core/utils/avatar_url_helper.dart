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
