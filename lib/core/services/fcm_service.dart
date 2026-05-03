import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background-isolate handler. Must be a top-level function (annotated
/// with `@pragma('vm:entry-point')` so it survives tree-shaking) and
/// must call `Firebase.initializeApp()` because the background isolate
/// has its own Dart VM with no shared state.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal: just log. Anything user-visible should be
  // sent by the server inside the `notification` block — FCM displays
  // it automatically in the system tray when the app is backgrounded
  // or terminated. We only get the data payload here.
  debugPrint('🔔 [FCM bg] ${message.messageId} data=${message.data}');
}

/// Firebase Cloud Messaging integration. Owns the device token,
/// listens for incoming pushes, and routes them through
/// `flutter_local_notifications` while the app is in the foreground
/// (since FCM does NOT show notifications automatically when the app
/// is open).
///
/// Wire-up sequence (call from `main()` AFTER `Firebase.initializeApp`):
///   await FcmService.instance.init();
///   await FcmService.instance.registerWithBackend(api);  // when logged in
///
/// Server-side payload contract:
/// ```
///   {
///     "to": "FCM_TOKEN_HERE",
///     "notification": { "title": "...", "body": "..." },
///     "data": { "type": "battle_invite", "room_id": "..." }
///   }
/// ```
/// `data` is optional; the app reads `type` to decide where to deep-link
/// when the user taps the push.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  /// FCM only supports the default Firebase app — the
  /// `firebase_messaging` plugin's `instanceFor` is private and
  /// Android/iOS native FCM bindings are wired against
  /// `google-services.json` / `GoogleService-Info.plist`. So push
  /// notifications and the rest of Firebase (auth, analytics) MUST
  /// share the same project.
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _cachedToken;

  /// Stream of `data` payloads from pushes the user actually tapped
  /// (either while the app was in the background or because the push
  /// cold-launched the app). Callers (e.g. `app_router.dart`) listen
  /// here to deep-link into the right screen.
  final StreamController<Map<String, dynamic>> _onPushTapped =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPushTapped => _onPushTapped.stream;

  /// One-shot init. Idempotent. Boots the secondary "messaging"
  /// Firebase app if it isn't already alive, then wires every FCM
  /// listener to it.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Background handler — registered before any other listener.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. iOS: ask the user. Android 13+: ask via the OS prompt.
    //    `provisional: false` means we want the standard prompt rather
    //    than silent / quiet notifications.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔔 [FCM] permission: ${settings.authorizationStatus}');

    // 3. iOS only: tell APNs we want notifications shown in foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Token. May be null on iOS until APNs delivers, in which case
    //    `onTokenRefresh` will fire later.
    _cachedToken = await _messaging.getToken();
    if (_cachedToken != null) {
      // Full token in logs so QA can copy/paste into Firebase Console's
      // "Send test message" → "Add an FCM registration token" field.
      debugPrint('🔔 [FCM] ===== FCM TOKEN =====');
      debugPrint('🔔 [FCM] $_cachedToken');
      debugPrint('🔔 [FCM] ======================');
    } else {
      debugPrint('🔔 [FCM] token NOT YET AVAILABLE '
          '(iOS waits for APNs first; rerun after a few seconds)');
    }
    if (_cachedToken != null) {
      await _persistToken(_cachedToken!);
    }
    _messaging.onTokenRefresh.listen((token) async {
      debugPrint('🔔 [FCM] token refreshed: ${token.substring(0, 16)}…');
      _cachedToken = token;
      await _persistToken(token);
      // Server registration is the caller's responsibility — they
      // listen on `tokenStream` (below) or call `registerWithBackend`
      // manually after every fresh login.
      _tokenStream.add(token);
    });

    // 5. Foreground messages — FCM does NOT auto-display these. We
    //    forward to flutter_local_notifications so the user sees a
    //    real system notification even when the app is open. We also
    //    re-initialize the plugin here to register our tap handler:
    //    NotificationService.init() called `initialize()` earlier
    //    without a callback, so foreground notification taps would
    //    have been routed nowhere. The second call wins for the
    //    callback (the underlying plugin uses one global instance).
    await _localNotif.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 6. Tapped from background → app brought back to foreground.
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromBackground);

    // 7. Cold-launched by tapping a push (app was terminated).
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onOpenedFromBackground(initial);
  }

  /// Send the current token to your backend so it can target this
  /// device when emitting pushes. Call once per app open after the
  /// user has a valid auth session, and again whenever
  /// [tokenStream] emits a new token.
  ///
  /// Pass a callback that handles the actual HTTP call so this
  /// service stays decoupled from the API client.
  Future<void> registerWithBackend(
    Future<void> Function(String token) sendToServer,
  ) async {
    final token = _cachedToken ?? await _messaging.getToken();
    if (token == null) return;
    try {
      await sendToServer(token);
    } catch (e) {
      debugPrint('🔔 [FCM] registerWithBackend failed: $e');
    }
  }

  final StreamController<String> _tokenStream =
      StreamController<String>.broadcast();

  /// Listen here to react to fresh tokens (e.g. re-register with backend).
  Stream<String> get tokenStream => _tokenStream.stream;

  /// Last known FCM token, or null if we haven't received one yet.
  String? get currentToken => _cachedToken;

  // ──────────────────────────── handlers ────────────────────────────

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 [FCM fg] ${message.messageId} data=${message.data}');
    final n = message.notification;
    if (n == null) return;

    // Re-use the daily-reminder channel created by NotificationService.
    // Importance.max guarantees a heads-up notification on Android.
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Push messages',
      channelDescription: 'Push notifications from server',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _localNotif.show(
      id: message.hashCode & 0x7fffffff,
      title: n.title ?? '',
      body: n.body ?? '',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: _encodeData(message.data),
    );
  }

  void _onOpenedFromBackground(RemoteMessage message) {
    debugPrint('🔔 [FCM tap] ${message.messageId} data=${message.data}');
    if (message.data.isNotEmpty) {
      _onPushTapped.add(Map<String, dynamic>.from(message.data));
    }
  }

  /// Tap on a foreground notification (the one [_localNotif.show] put
  /// in the system tray while the app was open). The payload is the
  /// JSON-encoded `data` map from the original [RemoteMessage] — we
  /// decode it back and emit through the same [onPushTapped] stream
  /// so [PushNotificationRouter] handles foreground / background /
  /// cold-start taps uniformly.
  void _onLocalNotificationTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    debugPrint('🔔 [FCM fg-tap] payload=$raw');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded.isNotEmpty) {
        _onPushTapped.add(decoded);
      }
    } catch (e) {
      debugPrint('🔔 [FCM fg-tap] payload decode failed: $e');
    }
  }

  // ──────────────────────────── helpers ────────────────────────────

  /// Cache the token in SharedPreferences so the rest of the app (and
  /// the backend re-register loop) can pick it up without an async
  /// FCM call.
  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Round-trip safely through `flutter_local_notifications.payload`,
  /// which is a single string field. JSON survives `=`, `&`, `?`,
  /// spaces, and Unicode — the previous `key=value&key=value` scheme
  /// silently corrupted any value containing those characters (which
  /// includes URL-encoded promo codes and deep-link query strings).
  String _encodeData(Map<String, dynamic> data) {
    if (data.isEmpty) return '';
    return jsonEncode(data);
  }
}
