import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

/// Global helper to handle 401 (unauthorized) responses.
/// Аввал токенро refresh мекунад; агар нашавад — logout мекунад.
class AuthSessionHandler {
  AuthSessionHandler._();

  static GoRouter? _router;

  /// Guard to prevent multiple concurrent 401 handlers from firing.
  static bool _handling = false;

  /// Shared mutex for the refresh RPC — both the Dio interceptor (in
  /// api_service.dart) and this handler ultimately call into it, so we
  /// collapse parallel refreshes onto a single in-flight Future. Without
  /// this, two 401s arriving together both POST with the same old
  /// refresh_token — one wins, the other 401s with "invalid token" and
  /// logs the user out.
  static Completer<bool>? _inflightRefresh;

  /// Initialize with the GoRouter instance (call once from app_router).
  static void init(GoRouter router) {
    _router = router;
  }

  /// Call when a 401 is received from any API call.
  /// Аввал кӯшиш мекунад токенро refresh кунад.
  /// Агар refresh муваффақ шавад — `true` бармегардонад (request-ро боз иҷро кунед).
  /// Агар не — токенро пок мекунад ва ба /auth/start мебарад.
  static Future<bool> handle401() async {
    // If we're already handling a 401, skip to avoid redirect loops
    if (_handling) {
      debugPrint('🔒 401 received — already handling, skipping');
      return false;
    }

    // If user is already on an auth/onboarding page, don't redirect
    final currentLocation =
        _router?.routeInformationProvider.value.uri.path ?? '';
    if (currentLocation.startsWith('/auth')) {
      debugPrint(
        '🔒 401 received — already on auth page ($currentLocation), skipping redirect',
      );
      return false;
    }

    _handling = true;

    try {
      // Аввал кӯшиш мекунем токенро refresh кунем
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        debugPrint('🔒 401 → Token refreshed successfully!');
        return true; // Caller should retry their request
      }

      // Refresh нашуд — logout мекунем
      debugPrint(
        '🔒 401 → Refresh failed — clearing tokens and redirecting to login',
      );
      final storage = StorageService.instance;
      await storage.clearTokens();

      _router?.go('/auth/start');
      return false;
    } finally {
      // Reset after a short delay to allow redirect to complete
      Future.delayed(const Duration(seconds: 2), () {
        _handling = false;
      });
    }
  }

  /// Public entry so Dio's interceptor and [handle401] can share the same
  /// single-flight refresh. Returns true if tokens were rotated.
  static Future<bool> tryRefreshToken() => _tryRefreshToken();

  /// Кӯшиш мекунад аз refresh_token нави access_token гирад.
  /// Single-flight: parallel callers share the same Future, so the old
  /// refresh_token is never POSTed twice in a row.
  static Future<bool> _tryRefreshToken() {
    final existing = _inflightRefresh;
    if (existing != null) {
      debugPrint('🔒 Refresh already in flight — awaiting shared result');
      return existing.future;
    }
    final completer = Completer<bool>();
    _inflightRefresh = completer;
    _performRefresh().then((ok) {
      completer.complete(ok);
      _inflightRefresh = null;
    }).catchError((e) {
      debugPrint('🔒 Refresh crashed: $e');
      completer.complete(false);
      _inflightRefresh = null;
    });
    return completer.future;
  }

  static Future<bool> _performRefresh() async {
    try {
      final storage = StorageService.instance;
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('🔒 No refresh token available');
        return false;
      }

      debugPrint('🔒 Attempting token refresh...');
      final url = '${ApiConstants.baseUrl}${ApiConstants.authRefresh}';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          // Slow mobile networks (especially LTE on iOS) occasionally
          // take >10s for this RPC. 30s gives the server room without
          // making the UI feel frozen — handle401 only runs after a 401
          // already landed, so the user isn't actively waiting on a tap.
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await storage.setAccessToken(newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await storage.setRefreshToken(newRefreshToken);
          }
          debugPrint('🔒 Token refresh successful!');
          return true;
        }
      }

      debugPrint('🔒 Token refresh failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('🔒 Token refresh error: $e');
      return false;
    }
  }
}
