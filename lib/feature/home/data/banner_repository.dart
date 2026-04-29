import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/auth_session_handler.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/app_logger.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';

/// Repository for fetching banners from backend.
/// API: GET /api/v1/dict/banners
/// Matches Unity3D UIHomePage.InitBanners()
class BannerRepository {
  static const _baseUrl = '${ApiConstants.baseUrl}${ApiConstants.dictBase}';

  /// Returns platform name matching Unity PlatformUtils.GetPlatformName()
  static String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Converts semver "1.0.0" to decimal "1.0" matching Unity's format.
  /// Server parses with decimal.Parse, so only major.minor is needed.
  static String _getDecimalVersion() {
    const version = AppConstants.appVersion; // e.g. "1.0.0"
    final parts = version.split('.');
    if (parts.length >= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return version;
  }

  static double _parseCurrentVersion() {
    return double.tryParse(_getDecimalVersion()) ?? 0.0;
  }

  static bool _isBannerSupported(BannerDto banner) {
    if (banner.platform != _getPlatformName()) {
      debugPrint(
        '⏭️ Skipping banner "${banner.title}" due to platform mismatch: '
        '${banner.platform} != ${_getPlatformName()}',
      );
      return false;
    }

    final currentVersion = _parseCurrentVersion();
    if (currentVersion > banner.appVersion) {
      debugPrint(
        '⏭️ Skipping banner "${banner.title}" due to appVersion mismatch: '
        '$currentVersion > ${banner.appVersion}',
      );
      return false;
    }

    return true;
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
              // Server expects decimal version (e.g. "1.0", "2.5"), not semver
              // Unity sends Application.version which is parsed by decimal.Parse
              'App-Version': _getDecimalVersion(),
              'App-Platform': _getPlatformName(),
            },
          )
          .timeout(ApiConstants.receiveTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final rawBanners = data
            .map((json) => BannerDto.fromJson(json as Map<String, dynamic>))
            .toList();

        final bannersByPosition = <int, BannerDto>{};
        for (final banner in rawBanners) {
          if (!_isBannerSupported(banner)) continue;

          // Matches Unity: first banner that claims a position wins.
          bannersByPosition.putIfAbsent(banner.position, () => banner);
        }

        final banners = bannersByPosition.values.toList()
          ..sort((a, b) => a.position.compareTo(b.position));

        debugPrint('✅ Loaded ${banners.length} banners from API');
        for (final b in banners) {
          debugPrint(
            '🖼️ Banner #${b.id}: title="${b.title}", fileName="${b.fileName}", link="${b.link}", position=${b.position}, platform="${b.platform}", localization=${b.localization}',
          );
        }
        return banners;
      } else {
        debugPrint('❌ Banners API error: ${response.statusCode}');
        debugPrint('❌ Banners API body: ${response.body}');
        // Агар токен муҳлаташ гузашт — handle401() зану кунем
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
