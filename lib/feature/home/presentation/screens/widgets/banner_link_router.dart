import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/providers/bottom_nav_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/course_detail_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/invite_friend_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_coins_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/profile_page.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/all_my_trophies.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/all_top_vozhaomuzes.dart';
import 'package:vozhaomuz/shared/widgets/streak_history_dialog.dart';

/// Routes a backend-supplied banner [link] (`https://...` or
/// `app://Page[/<arg>]`) to the right action on the device.
///
/// Source of truth: §7 of TZ_BANNERS_FROM_BACKEND.md. Unknown routes
/// are logged but never throw — that way an admin pushing a brand-new
/// `app://...` route to an out-of-date client just becomes a no-op
/// instead of a crash.
class BannerLinkRouter {
  /// Bottom-nav indices — keep in sync with `navigation_bar.dart`:
  /// 0 home / 1 my words / 2 courses / 3 battle / 4 rating.
  static const _myWordsTab = 1;
  static const _coursesTab = 2;
  static const _battleTab = 3;

  static Future<void> handle(BuildContext context, String link) async {
    if (link.isEmpty) return;

    if (link.startsWith('https://') || link.startsWith('http://')) {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      return;
    }

    if (!link.startsWith('app://')) {
      debugPrint('Banner link: unsupported scheme — $link');
      return;
    }

    final route = link.substring('app://'.length);
    final segments = route.split('/');
    final action = segments.first;
    final arg = segments.length > 1 ? segments.sublist(1).join('/') : null;

    final container = ProviderScope.containerOf(context);
    final nav = container.read(bottomNavProvider.notifier);

    switch (action) {
      case 'Premium':
      case 'UISubscriptionPage':
      case 'UIFreeSubscriptionPage':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MySubscriptionPage()),
        );
        return;
      case 'UIBuyCoins':
      case 'UICoinPage':
      case 'Shop':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyCoinsPage()),
        );
        return;
      case 'UIInviteFriend':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InviteFriendPage()),
        );
        return;
      case 'UIBattlePage':
        nav.setIndex(_battleTab);
        return;
      case 'Rating':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllTop30Vozhaomuz()),
        );
        return;
      case 'Courses':
        nav.setIndex(_coursesTab);
        return;
      case 'CourseDetail':
        if (arg != null && arg.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CourseDetailPage(courseId: arg)),
          );
        }
        return;
      case 'Streak':
        await StreakHistoryDialog.show(context);
        return;
      case 'Achievements':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllMyTrophies()),
        );
        return;
      case 'Profile':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage()),
        );
        return;
      case 'MyWords':
        nav.setIndex(_myWordsTab);
        return;
      case 'Settings':
        // Settings live inside ProfilePage — open profile and let the
        // user dive in. When a dedicated settings route exists, swap
        // this out.
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage()),
        );
        return;
      case 'Promo':
        // No dedicated promo screen yet — log and ignore so backend
        // can start scheduling the route safely.
        debugPrint('Banner link: Promo route not implemented (code=$arg)');
        return;
      default:
        debugPrint('Banner link: unknown action "$action" in $link');
    }
  }
}
