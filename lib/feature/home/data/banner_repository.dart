import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/app_logger.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';

/// Repository for `GET /api/v1/dict/banners`.
///
/// As of backend commit `ba58fcc` the server already filters by
/// `is_active`, `valid_from/to`, `target_user_type`, `platform` and
/// `app_version`. The client keeps a defensive filter only for the
/// pieces that depend on local state (current platform, app version,
/// active flag) so a stale cache or misconfigured backend can't crash
/// the carousel.
class BannerRepository {
  static const _baseUrl = '${ApiConstants.baseUrl}${ApiConstants.dictBase}';

  static String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Server expects decimal version (e.g. `1.0`, `2.5`) parsed by
  /// `decimal.Parse`, so we ship only major.minor.
  static String _getDecimalVersion() {
    const version = AppConstants.appVersion;
    final parts = version.split('.');
    if (parts.length >= 2) return '${parts[0]}.${parts[1]}';
    return version;
  }

  /// Defensive client-side filter — the server handles these cases too,
  /// but a stale cache or proxy could feed us a banner that no longer
  /// matches. We deliberately skip the `app_version` check here: the
  /// backend's version semantics aren't documented consistently
  /// (TZ §5 vs the original Unity logic), so we trust whatever the
  /// server already filtered and log the rest for diagnosis.
  static bool _isVisible(BannerDto b) {
    if (!b.isActive) {
      debugPrint('⏭️ Skip banner #${b.id} "${b.title}" — is_active=false');
      return false;
    }
    if (b.platform != _getPlatformName()) {
      debugPrint(
        '⏭️ Skip banner #${b.id} "${b.title}" — platform=${b.platform} '
        '(client=${_getPlatformName()})',
      );
      return false;
    }
    final now = DateTime.now().toUtc();
    if (b.validFrom != null && now.isBefore(b.validFrom!)) {
      debugPrint(
        '⏭️ Skip banner #${b.id} "${b.title}" — valid_from in future '
        '(${b.validFrom})',
      );
      return false;
    }
    if (b.validTo != null && now.isAfter(b.validTo!)) {
      debugPrint(
        '⏭️ Skip banner #${b.id} "${b.title}" — valid_to in past '
        '(${b.validTo})',
      );
      return false;
    }
    // Reject legacy Unity AssetBundle records. Verified 2026-05-03:
    // 7 image banners point to extensionless R2 keys whose payload
    // starts with the magic bytes `UnityFS` (Unity 2022 bundle format).
    // Flutter has no way to render those, so admin needs to either
    // upload PNG replacements or delete the rows.
    if (b.type == 'image' &&
        b.fileName.isNotEmpty &&
        !_looksLikeImageFile(b.fileName)) {
      debugPrint(
        '⏭️ Skip banner #${b.id} "${b.title}" — file_name has no image '
        'extension (likely a Unity AssetBundle): ${b.fileName}',
      );
      return false;
    }
    return true;
  }

  static const _imageExtensions = ['.png', '.jpg', '.jpeg', '.webp', '.gif'];

  static bool _looksLikeImageFile(String fileName) {
    final lower = fileName.toLowerCase().split('?').first;
    return _imageExtensions.any(lower.endsWith);
  }

  Future<List<BannerDto>> getBanners() async {
    try {
      final token = await StorageService.instance.getAccessToken();
      if (token == null || token.isEmpty) {
        AppLogger.warning('Banners', 'No auth token — skipping banner fetch');
        return [];
      }
      final url = '$_baseUrl/banners';
      debugPrint('🖼️ Fetching banners: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'App-Version': _getDecimalVersion(),
              'App-Platform': _getPlatformName(),
            },
          )
          .timeout(ApiConstants.receiveTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final banners = data
            .map((json) => BannerDto.fromJson(json as Map<String, dynamic>))
            .where(_isVisible)
            .toList()
          // Stable sort: `position ASC`, ties broken by `priority DESC`
          // (matches backend ordering — see §6 of the TZ).
          ..sort((a, b) {
            final byPos = a.position.compareTo(b.position);
            if (byPos != 0) return byPos;
            return b.priority.compareTo(a.priority);
          });

        debugPrint('✅ Loaded ${banners.length} banners from API');
        for (final b in banners) {
          debugPrint(
            '🖼️ Banner #${b.id}: type="${b.type}", title="${b.title}", '
            'fileName="${b.fileName}", link="${b.link}", '
            'position=${b.position}, priority=${b.priority}',
          );
        }
        return banners;
      } else {
        debugPrint('❌ Banners API error: ${response.statusCode}');
        debugPrint('❌ Banners API body: ${response.body}');
        if (response.statusCode == 401) {
          await AuthSessionHandler.handle401();
        }
        return [];
      }
    } catch (e, st) {
      AppLogger.error('Banners', e, st);
      return [];
    }
  }
}
