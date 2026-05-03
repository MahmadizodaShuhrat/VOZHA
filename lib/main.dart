import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'core/l10n/tajik_material_localizations.dart';
import 'core/l10n/tajik_cupertino_localizations.dart';

import 'core/core.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/device_registration_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_notification_router.dart';
import 'core/services/unity_ad_service.dart';
import 'app/router/app_router.dart';
import 'feature/auth/presentation/providers/locale_provider.dart';
import 'feature/progress/progress_provider.dart';
import 'feature/rating/presentation/widgets/achievement_checker.dart';
import 'core/providers/theme_provider.dart';

/// Application entry point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Silence all debugPrint() calls in release builds so log statements
  // throughout the app don't leak to `adb logcat` when users install from
  // the Play Store / App Store. Flutter's default debugPrint DOES still
  // print in release mode — it's only the `assert()` statements that get
  // stripped. We override it with a no-op for release / profile builds.
  if (kReleaseMode || kProfileMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // ── Critical init (must complete before app starts) ──
  // Initialize Firebase. Android/iOS auto-init Firebase natively from
  // `google-services.json` / `GoogleService-Info.plist`, so calling
  // `initializeApp()` after that throws `[core/duplicate-app]`. We
  // skip the redundant init when a default app already exists — that
  // way the rest of the bootstrap (Crashlytics, FCM) still runs even
  // though native already did the heavy lifting.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));
    }
  } catch (e) {
    debugPrint('⚠️ Firebase init failed: $e');
  }

  // ── Crashlytics: catch all errors in release mode ──
  // (Outside the try/catch above so a duplicate-app warning doesn't
  // skip Crashlytics setup.)
  try {
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } catch (e) {
    debugPrint('⚠️ Crashlytics init failed: $e');
  }

  // ── FCM: register token + listen for incoming pushes ──
  // Fire-and-forget so a slow APNs handshake on iOS can't delay the
  // splash. Token registration with the backend happens later, once
  // the user is authenticated (handled by AuthSessionHandler).
  unawaited(
    FcmService.instance.init().catchError(
      (e) => debugPrint('⚠️ FCM init failed: $e'),
    ),
  );

  // Route push taps (background/cold start) to the right screen via
  // PushNotificationRouter. The router uses the global navigatorKey
  // wired below into MaterialApp so it can navigate without a
  // BuildContext when handling cold-start pushes.
  FcmService.instance.onPushTapped.listen(PushNotificationRouter.handle);

  // FCM token can rotate at any time (cleared cache, reinstall, OS
  // refresh). Whenever a fresh token arrives we re-POST it to the
  // backend so reminders keep landing on the live device. The
  // initial registration after login is triggered from the auth flow
  // (see code_message.dart) — this listener handles refreshes only.
  // We default to `tg` here because we don't have a BuildContext at
  // bootstrap and easy_localization's persisted locale isn't read
  // yet; a follow-up registration with the real locale lands as soon
  // as the user opens any context-aware screen (locale listener).
  FcmService.instance.tokenStream.listen((_) {
    DeviceRegistrationService.instance.registerWithLocale('tg');
  });

  await EasyLocalization.ensureInitialized();
  await StorageService.instance.init();
  await StorageService.instance.ensureFirstLaunchDate();

  // Register the device's FCM token with the backend whenever the user
  // transitions from logged-out to logged-in. We hook the global
  // StorageService listener (which fires on `setAccessToken`) instead
  // of registering from inside `code_message.dart`, because GoRouter's
  // `refreshListenable` already unmounts the auth screen the moment
  // the token is saved — anything that runs after the await in the
  // login handler gets bailed out by `if (!mounted) return`. Hooking
  // into StorageService bypasses widget lifecycle entirely.
  String? lastSeenToken = await StorageService.instance.getAccessToken();
  // Also register on cold start if user is already logged in — the
  // listener won't fire because the token didn't *change*, it was
  // already there when the listener attached.
  if (lastSeenToken != null && lastSeenToken.isNotEmpty) {
    unawaited(
      DeviceRegistrationService.instance.registerWithLocale('tg'),
    );
  }
  StorageService.instance.addListener(() async {
    final current = await StorageService.instance.getAccessToken();
    final wasLoggedOut = lastSeenToken == null || lastSeenToken!.isEmpty;
    final isLoggedIn = current != null && current.isNotEmpty;
    lastSeenToken = current;
    if (wasLoggedOut && isLoggedIn) {
      debugPrint('🔔 [device-register] login detected → registering');
      unawaited(
        DeviceRegistrationService.instance.registerWithLocale('tg'),
      );
    }
  });

  // ── Non-critical init (don't block app start) ──
  // Run in parallel, with timeouts, so app opens even if these fail
  unawaited(Future.wait([
    UnityAdService.instance.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('⚠️ UnityAds init timeout'),
    ).catchError((e) => debugPrint('⚠️ UnityAds init error: $e')),
    NotificationService.instance.init().then<void>((_) async {
      await NotificationService.instance.rescheduleFromStorage();
      // Re-arm the 10-day inactivity queue on every cold start. The
      // previous "seed once per install" gate was too eager — if the
      // very first scheduling failed (permission still pending, OEM
      // battery-saver revoking exact alarms, app force-stopped), the
      // seeded flag flipped to true and the queue was never
      // re-attempted. Refreshing every launch is cheap (cancel + 10
      // schedule calls) and resilient to single-shot failures.
      //
      // We deliberately do NOT call `requestPermission()` here. Doing
      // so silently consumed Android 13's one-shot system prompt
      // before the user reached StartPage, which then only saw the
      // microphone prompt — making it look like push was never asked.
      // StartPage's `_requestInitialPermissions` keeps the explicit
      // push → microphone order; for already-logged-in users who skip
      // StartPage entirely, they can enable push from
      // Profile → Notifications later.
      try {
        await NotificationService.instance.refreshInactivityReminders();
        if (!StorageService.instance.isInactivitySeeded()) {
          await StorageService.instance.setInactivitySeeded(true);
        }
      } catch (e) {
        debugPrint('⚠️ refreshInactivityReminders failed: $e');
      }
    }).timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('⚠️ Notification init timeout'),
    ).catchError((e) => debugPrint('⚠️ Notification init error: $e')),
  ]));

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Startup pending-sync retry: if the previous session had unsent progress,
  // try to send it as soon as the app opens. Wrapped in a ProviderContainer
  // so we can fire-and-forget without blocking app startup.
  final startupContainer = ProviderContainer();
  Future.microtask(() async {
    try {
      await startupContainer.read(progressProvider.notifier).retryPendingProgressSync();
    } catch (_) {}
  });

  runApp(
    UncontrolledProviderScope(
      container: startupContainer,
      child: EasyLocalization(
        supportedLocales: const [Locale('tg'), Locale('ru'), Locale('en')],
        path: 'assets/translate',
        fallbackLocale: const Locale('tg'),
        startLocale: const Locale('tg'), // Always start in Tajik on first launch
        saveLocale: true,
        child: const VozhaOmuzApp(),
      ),
    ),
  );
}

/// Main application widget
class VozhaOmuzApp extends ConsumerWidget {
  const VozhaOmuzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Hand the GoRouter to PushNotificationRouter so push taps that
    // fired before this widget mounted (cold start) can navigate now.
    PushNotificationRouter.router = router;

    // Arm the battle-invite deep link listener the first time the app
    // widget builds. `DeepLinkService.start` guards against double
    // subscription so subsequent rebuilds are no-ops. We capture the
    // container + router synchronously here so the Future.microtask
    // doesn't reach back into `context` across an async gap.
    final container = ProviderScope.containerOf(context);
    // PushNotificationRouter needs the container too — for stashing
    // pending Battle invites and switching bottom-nav tabs from a
    // BuildContext-less FCM listener.
    PushNotificationRouter.container = container;
    Future.microtask(() {
      DeepLinkService.instance.start(
        container: container,
        router: router,
      );
    });

    // Sync localeProvider with easy_localization's persisted locale
    final easyLocale = context.locale;
    final riverpodLocale = ref.read(localeProvider);
    if (easyLocale != riverpodLocale) {
      Future.microtask(() => ref.read(localeProvider.notifier).set(easyLocale));
    }

    // When internet comes back, retry pending progress sync (offline-first).
    ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      final wasOffline = prev?.value == false;
      final isOnline = next.value == true;
      if (wasOffline && isOnline) {
        debugPrint('🌐 Internet is back — retrying pending progress sync');
        ref.read(progressProvider.notifier).retryPendingProgressSync();
      }
    });
    return MaterialApp.router(
      title: 'VozhaOmuz',
      debugShowCheckedModeBanner: false,

      // Localization
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: [
        TajikMaterialLocalizations.delegate,
        TajikCupertinoLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        ...context.localizationDelegates,
      ],

      // Theme
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ref.watch(themeProvider),

      // Router
      routerConfig: router,

      // Global achievement checker — shows congratulatory popup from any page
      builder: (context, child) {
        ScreenUtil.init(context, designSize: const Size(375, 812));
        return AchievementChecker(
          child: SafeArea(
            top: false,    // AppBar handles top inset
            bottom: true,  // Prevent content from going behind system nav bar
            // Never let the router resolve to a transparent `SizedBox.shrink()`
            // while the page stack is mid-transition. On some Android devices
            // the transparent fallback exposed the raw Material/Window
            // background, which rendered as a full black screen between
            // imperative pops (e.g. leaving the Result page after a repeat
            // session). Wrap in a solid Material with the app background so
            // any transition gap is at worst a single white frame.
            child: Material(
              color: const Color(0xFFF2F7FF),
              child: child ?? const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF6366F1); // Indigo
    const secondaryColor = Color(0xFF10B981); // Emerald

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: const CardThemeData(elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF818CF8); // Lighter indigo for dark mode
    const secondaryColor = Color(0xFF34D399); // Lighter emerald

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: const CardThemeData(elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
