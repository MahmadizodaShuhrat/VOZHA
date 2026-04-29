import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/feature/auth/business/auth_repository.dart';
import 'package:vozhaomuz/feature/auth/state/auth_state.dart';
import 'package:vozhaomuz/feature/auth/state/response_register_token.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/app/router/app_router.dart';

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState.initial();
  }

  // ── Google Sign-In (External Browser + Deep Link — same as Unity3D) ──
  // Flow (identical to Unity3D GooglePlayAuth.cs):
  //   1. Open OAuth URL in external browser (like Unity Application.OpenURL)
  //   2. User picks account → Google redirects to server
  //   3. Server 302 → app://com.vozhaomuz?code=AUTH_CODE
  //   4. app_links catches the deep link (like Unity onDeepLinkActivated)
  //   5. Extract code → send to API

  static const _gClientId =
      '521063033191-13f12qqal5lvusc944tjstkfmspqkipg.apps.googleusercontent.com';
  static const _authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const _redirectUri =
      '${ApiConstants.baseUrl}${ApiConstants.authBase}/google/oauth2redirect';

  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();
    debugPrint('🟢 signInWithGoogle: START (Chrome Custom Tab + CallbackActivity)');

    try {
      // Build the same OAuth URL as Unity GooglePlayAuth.cs
      final nonce = _generateNonce();
      final stateParam = _generateNonce();
      const scope = 'openid email profile';

      final url =
        '$_authorizationEndpoint'
        '?response_type=code'
        '&scope=${Uri.encodeComponent(scope)}'
        '&nonce=$nonce'
        '&client_id=$_gClientId'
        '&state=$stateParam'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
        '&response_mode=query';

      debugPrint('🟢 signInWithGoogle: opening Chrome Custom Tab...');

      // Use flutter_web_auth_2 — opens Chrome Custom Tab,
      // CallbackActivity catches the app://com.vozhaomuz redirect
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'app',
      );

      debugPrint('🟢 signInWithGoogle: callback result=$result');

      // Extract auth code from callback URL
      final callbackUri = Uri.parse(result);
      final authCode = callbackUri.queryParameters['code'];

      if (authCode == null || authCode.isEmpty) {
        throw Exception('No auth code in callback');
      }

      debugPrint(
        '🟢 signInWithGoogle: got authCode (${authCode.length} chars)',
      );

      // Send to API (same as Unity RestApiManager.Instance.GetQuery)
      debugPrint('🟢 signInWithGoogle: sending authCode to API...');
      final resp = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(authCode);
      debugPrint('🟢 signInWithGoogle: API response=$resp');

      await _handleOAuthResponse(resp, 'google');
      debugPrint('🟢 signInWithGoogle: DONE → $state');

      // Navigate
      final router = ref.read(appRouterProvider);
      state.when(
        initial: () {},
        loading: () {},
        authenticated: (_) {
          debugPrint('🟢 signInWithGoogle: → /home');
          router.go('/home');
        },
        needsSignUp: (_, __) {
          debugPrint('🟢 signInWithGoogle: → /auth/referral');
          router.go('/auth/referral');
        },
        error: (_) {},
      );
    } catch (e, s) {
      debugPrint('🔴 signInWithGoogle: Exception: $e');
      debugPrint('🔴 signInWithGoogle: StackTrace: $s');
      if (e.toString().contains('CANCELED') ||
          e.toString().contains('cancelled') ||
          e.toString().contains('canceled')) {
        state = const AuthState.initial();
      } else if (e is TimeoutException) {
        state = const AuthState.error('auth_timeout');
      } else {
        state = AuthState.error(e.toString());
      }
    }
  }

  // ── Apple Sign-In ──
  Future<void> signInWithApple() async {
    state = const AuthState.loading();

    try {
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final authCode = credential.authorizationCode;
      final resp = await ref
          .read(authRepositoryProvider)
          .signInWithApple(authCode);
      await _handleOAuthResponse(resp, 'apple');

      final router = ref.read(appRouterProvider);
      state.when(
        initial: () {},
        loading: () {},
        authenticated: (_) {
          debugPrint('🍎 signInWithApple: → /home');
          router.go('/home');
        },
        needsSignUp: (_, __) {
          debugPrint('🍎 signInWithApple: → /auth/referral');
          router.go('/auth/referral');
        },
        error: (_) {},
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = const AuthState.initial();
      } else {
        state = AuthState.error(e.message);
      }
    } catch (e) {
      if (!kIsWeb && Platform.isAndroid) {
        state = const AuthState.error('apple_sign_in_not_available');
      } else {
        state = AuthState.error(e.toString());
      }
    }
  }

  /// Handles OAuth response from server
  Future<void> _handleOAuthResponse(
    Map<String, dynamic> resp,
    String service,
  ) async {
    final type = resp['type'] as String?;
    final data = resp['response'] as Map<String, dynamic>?;

    debugPrint('🟢 _handleOAuthResponse: type=$type, service=$service');

    if (type == 'login' && data != null) {
      final user = ResponseRegisterToken.fromJson(data);
      debugPrint('🟢 _handleOAuthResponse: LOGIN — saving tokens...');

      await StorageService.instance.setAccessToken(user.accessToken);
      await StorageService.instance.setRefreshToken(user.refreshToken);

      state = AuthState.authenticated(user);
      debugPrint('🟢 _handleOAuthResponse: tokens saved, state=authenticated');
    } else if (data != null) {
      state = AuthState.needsSignUp(data, service);
      debugPrint('🟢 _handleOAuthResponse: REGISTER → needsSignUp');
    } else {
      state = const AuthState.error('invalid_server_response');
      debugPrint('🔴 _handleOAuthResponse: invalid response');
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
