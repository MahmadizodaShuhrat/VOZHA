// lib/core/providers/auth_repository.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:vozhaomuz/core/providers/user_provider.dart';
import 'package:vozhaomuz/shared/connectivity_helper.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref),
);

/// 404 — account not found
class AccountNotFoundException implements Exception {}

/// 429 — too many requests. [retryAfterSeconds] is populated from the
/// backend's `retry_after_seconds` field so the UI can tell the user exactly
/// how long to wait before trying again.
class TooManyRequestsException implements Exception {
  final int? retryAfterSeconds;
  TooManyRequestsException({this.retryAfterSeconds});
  @override
  String toString() => retryAfterSeconds != null
      ? 'TooManyRequestsException(retryAfter=${retryAfterSeconds}s)'
      : 'TooManyRequestsException';
}

/// 409 — account already exists
class AccountAlreadyExistsException implements Exception {}

class AuthRepository {
  final Ref ref;
  final _base = '${ApiConstants.baseUrl}${ApiConstants.authBase}';

  AuthRepository(this.ref);

  /// Sends the SMS code and returns the seconds until it expires.
  /// Backend may include `expires_in` / `expires_at_seconds` / `ttl` in the
  /// 200 response body; otherwise the client falls back to a safe default.
  Future<int> sendSmsCode({
    String phone = '',
    String email = '',
    String action = 'login',
  }) async {
    final url = Uri.parse('$_base/sms/send-code');
    final formattedPhone = phone.isEmpty ? '' : '+992$phone';
    final body = {'phone': formattedPhone, 'email': email, 'action': action};

    debugPrint('*** sendSmsCode → URL: $url');
    debugPrint('*** sendSmsCode → Body: $body');

    late http.Response resp;
    try {
      resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      debugPrint('*** sendSmsCode → timeout');
      rethrow;
    } catch (e) {
      debugPrint('*** sendSmsCode → exception: $e');
      rethrow;
    }

    debugPrint('*** sendSmsCode → status: ${resp.statusCode}');
    debugPrint('*** sendSmsCode → body: ${resp.body}');

    if (resp.statusCode == 200) {
      return _parseExpirySeconds(resp.body);
    }

    // 404 = account not found (phone or email)
    if (resp.statusCode == 404) {
      throw AccountNotFoundException();
    }

    // 409 = account already exists (registration with existing number)
    if (resp.statusCode == 409) {
      throw AccountAlreadyExistsException();
    }

    // 429 = too many requests. Pull backend's `retry_after_seconds` so the
    // UI can show a concrete countdown instead of a generic "try later".
    if (resp.statusCode == 429) {
      int? retryAfter;
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map) {
          final v = decoded['retry_after_seconds'];
          if (v is num && v > 0) retryAfter = v.toInt();
        }
      } catch (_) {}
      throw TooManyRequestsException(retryAfterSeconds: retryAfter);
    }

    throw Exception('send_code_failed');
  }

  /// Pull the code-expiry duration (seconds) from the backend response.
  /// Backend canonical field is `ttl_seconds` (how long the SMS code stays
  /// valid). Other synonyms are accepted so we stay tolerant to naming
  /// drift. Falls back to [AppConstants.smsCodeExpiryFallbackSeconds]
  /// only if the response body carries no usable value.
  int _parseExpirySeconds(String responseBody) {
    const fallback = AppConstants.smsCodeExpiryFallbackSeconds;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) {
        debugPrint('⏱️ sendSmsCode: body not a JSON object, using fallback ${fallback}s');
        return fallback;
      }
      for (final key in const [
        'ttl_seconds', // ← canonical, backend's chosen name
        'expires_in',
        'expires_at_seconds',
        'ttl',
        'seconds',
        'expiry_seconds',
      ]) {
        final v = decoded[key];
        if (v is num && v > 0) {
          debugPrint('⏱️ sendSmsCode: backend expiry "$key"=${v.toInt()}s');
          return v.toInt();
        }
      }
      debugPrint(
        '⏱️ sendSmsCode: no expiry key in response, using fallback ${fallback}s. '
        'Body keys: ${decoded.keys.toList()}',
      );
    } catch (e) {
      debugPrint('⏱️ sendSmsCode: body parse failed ($e), using fallback ${fallback}s');
    }
    return fallback;
  }

  /// Verify the SMS code and authenticate the user.
  ///
  /// Works the same for both login and registration: backend creates the
  /// account on `send-code?action=register`, activates it on confirm, and
  /// `/auth/login` returns tokens in either case. If login still says
  /// "user not found" (backend hasn't caught up), the caller catches
  /// [AccountNotFoundException] and falls through to the signup wizard.
  Future<void> confirmSmsCode({
    String phone = '',
    String email = '',
    required String code,
    bool isRegistration = false,
  }) async {
    final url = Uri.parse('$_base/sms/confirm-code');
    final formattedPhone = phone.isEmpty
        ? ''
        : phone.startsWith('+992')
        ? phone
        : '+992$phone';
    final body = {'phone': formattedPhone, 'email': email, 'sms_code': code};

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    debugPrint('→ API URL: $url');
    debugPrint('→ Body: $body');
    debugPrint('confirm → ${resp.statusCode}');
    debugPrint('confirm → ${resp.body}');

    if (resp.statusCode != 200) {
      // Surface the human-readable message from the server
      // (e.g. "Invalid SMS code", "Code expired") without leaking
      // status codes, URLs, or raw JSON.
      throw Exception(_extractServerMessage(resp.body) ?? 'confirm_code_failed');
    }

    // For registration, do NOT hit /auth/login here — even a 404 response
    // burns the sms_code on the server (used=true), leaving the final
    // /auth/register call to fail with code_used. We keep the code
    // unspent for the wizard's final register step.
    if (isRegistration) return;

    await login(smsCode: code, phone: formattedPhone, email: email);
  }

  /// Pulls a user-friendly string out of a JSON error body. Returns null
  /// when the body isn't JSON or doesn't carry a known message field.
  String? _extractServerMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        for (final key in const ['message', 'error', 'detail', 'reason']) {
          final v = decoded[key];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> login({
    String phone = '',
    String email = '',
    required String smsCode,
  }) async {
    final url = Uri.parse('$_base/login');
    final deviceId = await _getDeviceId();
    final body = {
      'phone': phone.isEmpty
          ? ''
          : phone.startsWith('+992')
          ? phone
          : '+992$phone',
      'email': email,
      'sms_code': smsCode,
      'deviceId': deviceId,
    };

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      // Backend accepts send-code for any number (no 404 there) so the only
      // way we learn a phone isn't registered is here — when login says
      // "user not found". Surface it as a dedicated exception so the UI
      // can drop the user straight into the signup wizard.
      final body = resp.body.toLowerCase();
      if (resp.statusCode == 404 ||
          body.contains('user not found') ||
          body.contains('user_not_found')) {
        throw AccountNotFoundException();
      }
      throw Exception('Ошибка входа: ${resp.body}');
    }

    final Map<String, dynamic> result = jsonDecode(resp.body);

    // Сохраняем токены
    final accessToken = result['access_token'] as String;
    final refreshToken = result['refresh_token'] as String;
    await StorageService.instance.setAccessToken(accessToken);
    await StorageService.instance.setRefreshToken(refreshToken);

    // Приводим id к строке, чтобы User.id был String
    final String idAsString = result['id'].toString();
    // Берём имя пользователя из ответа
    final String name = result['name'] as String? ?? '';

    // Обновляем состояние пользователя в Riverpod
    ref
        .read(userProvider.notifier)
        .set(User(id: idAsString, name: name, jwtToken: accessToken));
  }

  Future<Map<String, dynamic>> signInWithGoogle(String code) async {
    final uri = Uri.parse('$_base/google/oauth2-google-get-user');

    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'AuthCode': code},
    );

    debugPrint('*** signInWithGoogle → URL: $uri');
    debugPrint('*** Response status: ${res.statusCode}');
    debugPrint('*** Response body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Google auth failed: ${res.statusCode}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> signInWithApple(String code) async {
    final uri = Uri.parse('$_base/apple/oauth2-apple-get-user');
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'AuthCode': code},
    );
    if (res.statusCode != 200) {
      throw Exception('Apple auth failed: ${res.statusCode}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Phone / email registration — step 3 of the SMS flow.
  ///
  /// Backend consumes the SMS code verified in step 2 (confirm-code) and
  /// creates the user in one multipart POST. Response carries
  /// `access_token` / `refresh_token`, so the caller can save them and
  /// jump straight to /home without a separate /auth/login round-trip.
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String smsCode,
    String email = '',
    String? aboutUs,
    String? inviteCode,
    String? userCategory,
    String? avatarFilePath,
  }) async {
    final url = Uri.parse('$_base/register');
    final deviceId = await _getDeviceId();
    final deviceOS = kIsWeb ? 'Web' : (Platform.isAndroid ? 'Android' : 'iOS');

    // Backend is Go; existing register-oauth2 already uses PascalCase
    // multipart field names (Email/Name/DeviceID/…). The spec table shows
    // snake_case, but the 400 "phone or email required" we were getting
    // while phone was set proves the server only reads the PascalCase
    // variant. Matching register-oauth2's convention keeps both endpoints
    // consistent.
    final req = http.MultipartRequest('POST', url)
      ..fields['Name'] = name
      ..fields['Phone'] = phone
      ..fields['Email'] = email
      ..fields['SmsCode'] = smsCode
      ..fields['DeviceID'] = deviceId
      ..fields['DeviceOS'] = deviceOS;

    if (aboutUs != null && aboutUs.isNotEmpty) {
      req.fields['HearAbutAs'] = aboutUs;
    }
    if (inviteCode != null && inviteCode.isNotEmpty) {
      req.fields['InviteCode'] = inviteCode;
    }
    if (userCategory != null && userCategory.isNotEmpty) {
      req.fields['UserCategory'] = userCategory;
    }

    if (avatarFilePath != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'AvatarFile',
          avatarFilePath,
          filename: 'avatar.jpg',
        ),
      );
    }

    debugPrint('*** register → URL: $url');
    debugPrint('*** register → Fields: ${req.fields}');

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    debugPrint('*** register → Status: ${resp.statusCode}');
    debugPrint('*** register → Body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception(
        _extractServerMessage(resp.body) ?? 'register_failed',
      );
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registerOauth2({
    required String email,
    required String name,
    required String age,
    required String inviteCode,
    required String userCategory,
    required String aboutUs,
    String? avatarFilePath,
  }) async {
    final url = Uri.parse('$_base/register-oauth2');
    final deviceId = await _getDeviceId();
    final deviceOS = kIsWeb ? 'Web' : (Platform.isAndroid ? 'Android' : 'iOS');

    final req = http.MultipartRequest('POST', url)
      ..fields['Email'] = email
      ..fields['Name'] = name
      ..fields['Age'] = age
      ..fields['InviteCode'] = inviteCode
      ..fields['UserCategory'] = userCategory
      ..fields['HearAbutAs'] = aboutUs
      ..fields['DeviceID'] = deviceId
      ..fields['DeviceOS'] = deviceOS;

    if (avatarFilePath != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'AvatarFile',
          avatarFilePath,
          filename: 'avatar.jpg',
        ),
      );
    }

    debugPrint('*** registerOauth2 → URL: $url');
    debugPrint('*** registerOauth2 → Fields: ${req.fields}');

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    debugPrint('*** registerOauth2 → Status: ${resp.statusCode}');
    debugPrint('*** registerOauth2 → Body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('Регистрация OAuth не удалась: ${resp.body}');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  Future<String> _getDeviceId() async {
    if (kIsWeb) {
      return 'web-device';
    }
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return info.id ?? '';
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return info.identifierForVendor ?? '';
    } else {
      return '';
    }
  }

  Future<String?> refreshToken() async {
    try {
      final hasNet = await ConnectivityHelper.hasInternet();
      if (!hasNet) {
        debugPrint('❌ Нет интернета');
        throw Exception('Нет подключения к интернету');
      }

      final token = await StorageService.instance.getRefreshToken();
      if (token == null || token.isEmpty) {
        debugPrint('❌ No refresh token available');
        return null;
      }

      final response = await http.post(
        Uri.parse('$_base/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': token}),
      );

      debugPrint('Refresh token request to: $_base/refresh-token');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        // Save both tokens
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await StorageService.instance.setAccessToken(newAccessToken);
        }
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await StorageService.instance.setRefreshToken(newRefreshToken);
        }
        return newAccessToken;
      } else {
        debugPrint('Response error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error $e');
      throw Exception(e);
    }
  }
}
