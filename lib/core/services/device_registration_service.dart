import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/fcm_service.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

/// Registers the current device's FCM token with the backend so the
/// server can target it for premium-expiry reminders, streak-bonus
/// pushes, and any future targeted campaigns (see `TZ_PUSH_NOTIFICATIONS.md`).
///
/// Endpoint: `POST /api/v1/user/devices` (auth via existing JWT).
/// Backend UPSERTs by `fcm_token` so multiple registrations from the
/// same device are idempotent — we just want to call it whenever the
/// inputs (token / locale / app version) might have changed.
class DeviceRegistrationService {
  DeviceRegistrationService._();
  static final DeviceRegistrationService instance =
      DeviceRegistrationService._();

  static const _url = '${ApiConstants.baseUrl}${ApiConstants.apiVersion}'
      '/user/devices';

  /// Decimal app version, matching the format we already send as
  /// `App-Version` header (e.g. `2.66` from `2.66.0`). Backend stores
  /// it for analytics — not load-bearing.
  static String _appVersion() {
    const v = AppConstants.appVersion;
    final parts = v.split('.');
    if (parts.length >= 2) return '${parts[0]}.${parts[1]}';
    return v;
  }

  static String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Best-effort registration. Logs failures and returns silently —
  /// pushes aren't critical to the user flow, and a transient network
  /// blip during login shouldn't block the home screen. The next
  /// trigger (cold start, locale change, token refresh) re-registers.
  Future<void> register({
    required String fcmToken,
    required String interfaceLanguage,
  }) async {
    try {
      final auth = await StorageService.instance.getAccessToken();
      if (auth == null || auth.isEmpty) {
        debugPrint('🔔 [device-register] skipped — no JWT yet');
        return;
      }

      // Backend keys templates by `tg` (not `tj`). easy_localization
      // returns `tg` already — coerce defensively in case any caller
      // wires a non-standard locale.
      final lang = interfaceLanguage == 'tj' ? 'tg' : interfaceLanguage;

      final body = jsonEncode({
        'fcm_token': fcmToken,
        'platform': _platformName(),
        'app_version': _appVersion(),
        'interface_language': lang,
      });

      final res = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $auth',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(ApiConstants.receiveTimeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('🔔 [device-register] ok ($lang, ${_platformName()})');
      } else {
        debugPrint(
          '🔔 [device-register] ${res.statusCode}: ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('🔔 [device-register] failed: $e');
    }
  }

  /// Convenience: pull the freshest FCM token off [FcmService] and
  /// pair it with the locale read from the app's `BuildContext`.
  /// If no token is available yet (iOS waits for APNs handshake),
  /// the FCM service's `tokenStream` will fire later and the caller
  /// should re-invoke this method.
  Future<void> registerCurrent(BuildContext context) async {
    final token = FcmService.instance.currentToken;
    if (token == null || token.isEmpty) {
      debugPrint('🔔 [device-register] no FCM token yet — skipping');
      return;
    }
    final locale = context.locale.languageCode;
    await register(fcmToken: token, interfaceLanguage: locale);
  }

  /// Same as [registerCurrent] but takes the locale string directly,
  /// so it's safe to call from places where no `BuildContext` is
  /// handy (e.g. `tokenStream` listener at app boot).
  Future<void> registerWithLocale(String locale) async {
    final token = FcmService.instance.currentToken;
    if (token == null || token.isEmpty) {
      debugPrint('🔔 [device-register] no FCM token yet — skipping');
      return;
    }
    await register(fcmToken: token, interfaceLanguage: locale);
  }
}
