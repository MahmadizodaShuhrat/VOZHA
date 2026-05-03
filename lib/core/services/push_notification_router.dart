import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/providers/bottom_nav_provider.dart';
import 'package:vozhaomuz/core/services/deep_link_service.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_detail_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/invite_friend_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_coins_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/profile_page.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/all_my_trophies.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/all_top_vozhaomuzes.dart';
import 'package:vozhaomuz/shared/widgets/streak_history_dialog.dart';

/// Routes a tapped push (or its `data` payload arriving via the cold-
/// start `getInitialMessage()` path) to the right in-app destination.
///
/// Source of truth: [TZ_PUSH_DEEPLINKS_V2.md](../../../docs/TZ_PUSH_DEEPLINKS_V2.md).
///
/// Two routing tiers, applied in order:
///
/// 1. **`data.deep_link`** — explicit destination set by the admin
///    panel's "click_action" picker. Supports parameters:
///       - `app://Battle?room_id=12345` — open Battle and auto-join
///       - `app://CourseDetail/5` — open course #5
///       - `app://Promo/SUMMER50` — subscription page with promo
///       - `https://...` — external browser
/// 2. **`data.type`** — legacy fallback for system templates that
///    pre-date the deep_link picker (`streak_premium_bonus`,
///    `premium_expiry_*`). Maps to a canonical destination.
///
/// Unknown routes are logged but never throw — that way an admin
/// pushing a brand-new campaign type to an out-of-date client just
/// becomes a no-op instead of a crash.
class PushNotificationRouter {
  /// GoRouter instance, set once during bootstrap from `main.dart`'s
  /// MyApp build (where `appRouterProvider` is read). Push handlers
  /// use it to navigate without needing a BuildContext, which lets us
  /// route cold-start pushes that fire before any widget exists.
  static GoRouter? _router;
  static set router(GoRouter r) => _router = r;

  /// Riverpod container, captured the same way as [router]. Required
  /// for stashing a pending Battle invite and for switching bottom-nav
  /// tabs from a context-less push handler.
  static ProviderContainer? _container;
  static set container(ProviderContainer c) => _container = c;

  // Bottom-nav indices — keep in sync with `navigation_bar.dart`:
  // 0 home / 1 my words / 2 courses / 3 battle / 4 rating.
  static const _myWordsTab = 1;
  static const _coursesTab = 2;
  static const _battleTab = 3;

  /// Entry point — call from `FcmService.onPushTapped` listener.
  static Future<void> handle(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final deepLink = data['deep_link'] as String?;
    debugPrint(
      '🔔 [PushRouter] tap type="$type" deep_link="$deepLink" data=$data',
    );

    HapticFeedback.lightImpact();

    // Tier 1 — admin-supplied deep_link wins. This handles every
    // route the admin panel exposes plus external URLs.
    if (deepLink != null && deepLink.isNotEmpty) {
      await _handleDeepLink(deepLink, data);
      return;
    }

    // Tier 2 — legacy system templates without deep_link.
    if (type == null || type.isEmpty) return;
    switch (type) {
      case 'premium_expiry_7':
      case 'premium_expiry_3':
      case 'premium_expiry_1':
      case 'premium_expiry_reminder':
        await _openSubscription(promo: data['promo_code'] as String?);
        return;
      case 'streak_premium_bonus':
        await _openStreak();
        return;
      default:
        debugPrint('🔔 [PushRouter] unknown type "$type" — ignored');
    }
  }

  // ─────────────────── deep_link parser ───────────────────

  static Future<void> _handleDeepLink(
    String deepLink,
    Map<String, dynamic> data,
  ) async {
    // External URLs — let the OS open them in the browser.
    if (deepLink.startsWith('http://') || deepLink.startsWith('https://')) {
      try {
        await launchUrl(
          Uri.parse(deepLink),
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('🔔 [PushRouter] launchUrl failed for $deepLink: $e');
      }
      return;
    }

    if (!deepLink.startsWith('app://')) {
      debugPrint('🔔 [PushRouter] unsupported scheme: $deepLink');
      return;
    }

    final uri = Uri.parse(deepLink);
    final host = uri.host;
    final segments = uri.pathSegments;
    final query = uri.queryParameters;

    switch (host) {
      case 'Premium':
      case 'UISubscriptionPage':
      case 'UIFreeSubscriptionPage':
        // `data.promo_code` (top-level) takes precedence over an
        // empty link, so a `streak_premium_bonus`-style template
        // that started carrying explicit promo gets honored.
        await _openSubscription(promo: data['promo_code'] as String?);
        return;

      case 'UIBuyCoins':
      case 'UICoinPage':
      case 'Shop':
        await _push(const MyCoinsPage());
        return;

      case 'UIInviteFriend':
        await _push(const InviteFriendPage());
        return;

      case 'Rating':
        await _push(const AllTop30Vozhaomuz());
        return;

      case 'Streak':
        await _openStreak();
        return;

      case 'Achievements':
        await _push(const AllMyTrophies());
        return;

      case 'Profile':
        await _push(ProfilePage());
        return;

      case 'MyWords':
        _switchTab(_myWordsTab);
        return;

      case 'Courses':
        _switchTab(_coursesTab);
        return;

      case 'Settings':
        // No dedicated settings screen yet — Profile holds them.
        await _push(ProfilePage());
        return;

      // ── Routes with parameters ────────────────────────────────

      case 'Battle':
      case 'UIBattlePage':
        // `app://Battle` — just switch to the Battle tab.
        // `app://Battle?room_id=12345` — same, plus auto-join the
        // room. We park the room_id in `pendingBattleInviteProvider`
        // exactly like the existing universal-link flow does, so
        // BattlePage's mount-time logic picks it up uniformly.
        final roomId = query['room_id'];
        if (roomId != null && roomId.isNotEmpty) {
          // TZ §3 — refuse to hijack an active room. The user's
          // current battle would otherwise get torn down silently
          // when BattlePage's auto-join kicks in.
          final inRoom =
              _container?.read(battleProvider).roomId.isNotEmpty ?? false;
          if (inRoom) {
            _showSnack('battle_leave_current_first'.tr());
            return;
          }
          _container?.read(pendingBattleInviteProvider.notifier).set(roomId);
        }
        _switchTab(_battleTab);
        return;

      case 'CourseDetail':
        // `app://CourseDetail/5` → segments=['5']
        if (segments.isNotEmpty && segments.first.isNotEmpty) {
          await _push(CourseDetailPage(courseId: segments.first));
        }
        return;

      case 'Promo':
        // `app://Promo/SUMMER50` → segments=['SUMMER50']
        // No dedicated promo page yet — open MySubscriptionPage with
        // the code prefilled so the user can apply it on the pricing
        // screen.
        final code = segments.isNotEmpty ? segments.first : null;
        await _openSubscription(promo: code);
        return;

      default:
        debugPrint('🔔 [PushRouter] unknown app:// host "$host" — ignored');
    }
  }

  // ─────────────────── helpers ───────────────────

  /// Pull the live `BuildContext` off the GoRouter's navigator. Returns
  /// `null` until the router's `MaterialApp` is mounted.
  static BuildContext? get _context =>
      _router?.routerDelegate.navigatorKey.currentContext;

  static Future<void> _push(Widget page) async {
    final ctx = _context;
    if (ctx == null) return;
    await Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => page));
  }

  static void _switchTab(int index) {
    _container?.read(bottomNavProvider.notifier).setIndex(index);
  }

  static Future<void> _openSubscription({String? promo}) async {
    final ctx = _context;
    if (ctx == null) return;
    await Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => MySubscriptionPage(prefilledPromo: promo),
      ),
    );
  }

  static Future<void> _openStreak() async {
    final ctx = _context;
    if (ctx == null) return;
    await StreakHistoryDialog.show(ctx);
  }

  /// Brief in-app message via the nearest ScaffoldMessenger. Used for
  /// the "you're already in a battle" warning — too small to deserve
  /// a full dialog, but worth telling the user something happened so
  /// the tap doesn't feel ignored.
  static void _showSnack(String message) {
    final ctx = _context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
