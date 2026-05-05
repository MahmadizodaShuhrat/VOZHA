import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/core.dart';

import '../../app/bottom_navigation_bar/presentation/screens/navigation_bar.dart';

// Use existing auth screens from feature/auth
import '../../feature/auth/presentation/screens/start_page.dart';
import '../../feature/auth/presentation/screens/sgin_in_page.dart';
import '../../feature/auth/presentation/screens/code_message.dart';
import '../../feature/auth/presentation/screens/about_page.dart';
import '../../feature/auth/presentation/screens/language_page.dart';
import '../../feature/auth/presentation/screens/learn_language_page.dart';
import '../../feature/auth/presentation/screens/choose_english_level.dart';
import '../../feature/auth/presentation/screens/referral_source_page.dart';
import '../../feature/auth/presentation/screens/push_notification.dart';
import '../../feature/auth/presentation/screens/sign_up_page.dart';

import '../../core/services/auth_session_handler.dart';

/// App Router Provider using go_router
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: StorageService.instance,
    redirect: (context, state) {
      // Intercept deep-link URIs before the normal matcher runs.
      // `vozhaomuz://battle?room_id=X` arrives with authority=battle and
      // path=/ — GoRouter sees no matching route and shows "Page not
      // found". Likewise, a universal-link `https://…/?page=battle&…`
      // lands on an unknown path. In both cases we redirect to /battle
      // (which builds NavigationPage(initialIndex: 2)). DeepLinkService
      // has already parked the room id in pendingBattleInviteProvider,
      // so the Battle page auto-fills the code on mount.
      final uri = state.uri;
      final isBattleInvite =
          uri.host == 'battle' ||
          uri.queryParameters['page'] == 'battle' ||
          uri.authority == 'battle';
      if (isBattleInvite && state.matchedLocation != '/battle') {
        debugPrint('🔀 Deep-link → /battle (uri=$uri)');
        return '/battle';
      }

      // Sync read from the in-memory cache populated by `await
      // StorageService.instance.init()` in main() before runApp().
      // Awaiting `getAccessToken()` here previously caused the very
      // first frame to land on `/home` (the initialLocation) before
      // the redirect resolved, briefly flashing the home shell on
      // cold start when the user wasn't actually logged in.
      final storage = StorageService.instance;
      final token = storage.cachedAccessToken;
      final isLoggedIn = token != null && token.isNotEmpty;

      final matchedLocation = state.matchedLocation;
      final isOnAuth = matchedLocation.startsWith('/auth');

      // Onboarding routes that logged-in users should be able to access
      final onboardingRoutes = [
        '/auth/level',
        '/auth/referral',
        '/auth/notifications',
      ];
      final isOnOnboarding = onboardingRoutes.contains(matchedLocation);

      // Check onboarding first
      final isOnboardingCompleted = storage.isOnboardingCompleted();

      debugPrint(
        '🔀 GoRouter redirect: location=$matchedLocation, '
        'isLoggedIn=$isLoggedIn, isOnAuth=$isOnAuth, '
        'isOnOnboarding=$isOnOnboarding, '
        'onboardingCompleted=$isOnboardingCompleted',
      );

      if (!isLoggedIn && !isOnAuth) {
        // Not logged in → check onboarding
        if (!isOnboardingCompleted) {
          debugPrint('🔀 → redirecting to /auth/language');
          return '/auth/language';
        }
        debugPrint('🔀 → redirecting to /auth/start');
        return '/auth/start';
      }

      // If logged in and on auth pages — but NOT on onboarding pages.
      // This includes `/auth/start`: once a fresh token lands, any stale
      // auth-page navigation must immediately bounce to `/home` instead
      // of leaving the user stranded on StartPage until a full restart.
      if (isLoggedIn &&
          isOnAuth &&
          !isOnOnboarding) {
        debugPrint('🔀 → redirecting to /home');
        return '/home';
      }

      debugPrint('🔀 → no redirect (null)');
      return null;
    },
    routes: [
      // ==================== Auth Routes ====================
      GoRoute(path: '/auth', redirect: (context, state) => '/auth/start'),
      GoRoute(
        path: '/auth/start',
        name: 'start',
        builder: (context, state) => const StartPage(),
      ),
      GoRoute(
        path: '/auth/loading',
        name: 'auth-loading',
        builder: (context, state) => const _OAuthLoadingPage(),
      ),
      GoRoute(
        path: '/auth/signin',
        name: 'signin',
        builder: (context, state) {
          final isRegistration = state.extra as bool? ?? false;
          return SignInPage(isRegistration: isRegistration);
        },
      ),
      GoRoute(
        path: '/auth/verify',
        name: 'verify',
        builder: (context, state) {
          final isRegistration = state.extra as bool? ?? false;
          return CodeMessage(isRegistration: isRegistration);
        },
      ),
      GoRoute(
        path: '/auth/about',
        name: 'about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/auth/language',
        name: 'language',
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: '/auth/learn-language',
        name: 'learn-language',
        builder: (context, state) => const LearnLanguagePage(),
      ),
      GoRoute(
        path: '/auth/level',
        name: 'level',
        builder: (context, state) => const ChooseEnglishLevel(),
      ),
      GoRoute(
        path: '/auth/referral',
        name: 'referral',
        builder: (context, state) => const ReferralSourcePage(),
      ),
      GoRoute(
        path: '/auth/notifications',
        name: 'notifications',
        builder: (context, state) => const PushNotification(),
      ),
      GoRoute(
        path: '/auth/signup',
        name: 'signup',
        builder: (context, state) => const SignUpPage(),
      ),

      // ==================== Main App ====================
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const NavigationPage(),
      ),
      // Deep-link sink: Flutter auto-dispatches URIs like
      // `vozhaomuz://battle?room_id=X` (custom scheme) or
      // `https://…/?page=battle&room_id=X` (universal link) into
      // GoRouter. Without a matching route the user would see
      // `errorBuilder` ("Page not found"). DeepLinkService already
      // stashes the invite in `pendingBattleInviteProvider` via its own
      // `app_links` subscription; here we land the user on the Battle
      // tab directly (initialIndex: 3) so there's no visible flash of
      // the home tab before the switch. BattlePage reads the pending
      // invite on mount and flips its inner tab to "Join".
      // (Battle moved from index 2 → 3 after the Courses tab was added.)
      GoRoute(
        path: '/battle',
        builder: (context, state) => const NavigationPage(initialIndex: 3),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );

  AuthSessionHandler.init(router);
  return router;
});

/// Loading page shown during OAuth token processing
class _OAuthLoadingPage extends StatelessWidget {
  const _OAuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/vozhaomuz_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              Image.asset(
                'assets/images/vozhaomuz_logo.png',
                width: 120,
                height: 120,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.language, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 32),
              // Shimmer loading bar
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Color(0x33FFFFFF),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Боргузорӣ...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
