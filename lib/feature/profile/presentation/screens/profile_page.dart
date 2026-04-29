import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/about_vozhaomuz_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/change_language.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/change_level_english.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/change_notification.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/edit_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/invite_friend_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_coins_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/privacy_policy_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/shop_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/word_text_cache.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/screens/start_page.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/banner_provider.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/achievements_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_3_users_day_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_30_users_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/app_version_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends HookConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) => ref.read(getProfileInfoProvider.notifier).getProfile(),
      );
      return null;
    }, []);
    final profileInfo = ref.watch(getProfileInfoProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF0D1117)
        : const Color(0xFFF5FAFF);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? const Color(0xFFF0F6FC) : Colors.black;
    final subTextColor = isDark ? const Color(0xFF8B949E) : Colors.grey;

    return Scaffold(
      backgroundColor: scaffoldBg,

      appBar: AppBar(
        surfaceTintColor: scaffoldBg,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Icon(Icons.arrow_back, color: textColor),
        ),
        title: Text(
          'Profile'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: textColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: scaffoldBg,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            // ─── Profile Info Card (Unity-style) ───
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      // ── Avatar with edit button ──
                      SizedBox(
                        width: 100,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Avatar
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF30363D)
                                      : const Color(0xFFE4E7EC),
                                  width: 2.5,
                                ),
                              ),
                              child: profileInfo.when(
                                data: (data) {
                                  final url = data?.avatarUrl;
                                  final hasAvatar =
                                      url != null && url.isNotEmpty;
                                  final avatarWidget = CircleAvatar(
                                    radius: 40,
                                    backgroundColor: isDark
                                        ? const Color(0xFF21262D)
                                        : Colors.grey.shade100,
                                    backgroundImage: hasAvatar
                                        ? CachedNetworkImageProvider(
                                            buildAvatarUrl(url),
                                          )
                                        : null,
                                    child: !hasAvatar
                                        ? Image.asset(
                                            'assets/images/UIHome/usercircle.png',
                                            width: 45,
                                            height: 45,
                                          )
                                        : null,
                                  );
                                  if (!hasAvatar) return avatarWidget;
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
                                          opaque: false,
                                          barrierColor: Colors.black87,
                                          barrierDismissible: true,
                                          pageBuilder: (_, __, ___) =>
                                              _FullScreenAvatar(
                                                imageUrl: buildAvatarUrl(url),
                                              ),
                                          transitionsBuilder:
                                              (_, anim, __, child) {
                                                return FadeTransition(
                                                  opacity: anim,
                                                  child: child,
                                                );
                                              },
                                        ),
                                      );
                                    },
                                    child: Hero(
                                      tag: 'profile_avatar',
                                      child: avatarWidget,
                                    ),
                                  );
                                },
                                loading: () => Shimmer.fromColors(
                                  baseColor: Colors.grey.shade300,
                                  highlightColor: Colors.grey.shade100,
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                error: (error, _) => const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                            // Edit button
                            Positioned(
                              bottom: -4,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditPage(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF30363D)
                                          : const Color(0xFFE4E7EC),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: isDark
                                        ? const Color(0xFF8B949E)
                                        : const Color(0xFF667085),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Name ──
                      profileInfo.when(
                        data: (data) => Text(
                          data?.name ?? '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        error: (e, st) => Text('error'.tr()),
                        loading: () => Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            width: 100,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ── Email / Phone ──
                      profileInfo.when(
                        data: (data) {
                          String info = data?.email ?? '';
                          if (info.isEmpty) {
                            info = data?.phone ?? '';
                          }
                          if (info.isEmpty) return const SizedBox.shrink();
                          return Text(
                            info,
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 6),
                      // ── User ID chip — clickable to copy ──
                      profileInfo.when(
                        data: (data) {
                          final userId = data?.id;
                          if (userId == null) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: userId.toString()),
                              );
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('ID $userId ${'copied'.tr()}'),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: const Color(0xFF2E90FA),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0D2847)
                                    : const Color(0xFFEFF8FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2E90FA,
                                  ).withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fingerprint_rounded,
                                    size: 14,
                                    color: const Color(0xFF2E90FA),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ID: $userId',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2E90FA),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 13,
                                    color: const Color(
                                      0xFF2E90FA,
                                    ).withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      // ── Divider ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          height: 1,
                          color: isDark
                              ? const Color(0xFF21262D)
                              : const Color(0xFFF2F4F7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── Account status label ──
                      Text(
                        'Account_status'.tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: subTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ── Account status badge ──
                      profileInfo.when(
                        data: (data) {
                          final isPremium = data?.userType == 'pre';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isPremium
                                  ? const Color(0xFFFFF3D0)
                                  : (isDark
                                        ? const Color(0xFF1A2332)
                                        : const Color(0xFFF2F4F7)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPremium) ...[
                                  Image.asset(
                                    'assets/images/group_2.png',
                                    width: 14,
                                    height: 14,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  isPremium ? "Premium".tr() : "Ordinary".tr(),
                                  style: TextStyle(
                                    color: isPremium
                                        ? const Color(0xFFF9A628)
                                        : subTextColor,
                                    fontSize: 12,
                                    fontWeight: isPremium
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            width: 80,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        error: (_, __) => Text(
                          "Ordinary".tr(),
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ─── Quick Actions Card ───
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: cardBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      buildMenuItem(
                        image: Image.asset(
                          'assets/images/users.png',
                          width: 20,
                          height: 20,
                        ),
                        title: 'Invite_a_friend'.tr(),
                        icon2: Icon(Icons.chevron_right_rounded),
                        page: InviteFriendPage(),
                        context: context,
                      ),
                      _divider(context),
                      buildMenuItem(
                        image: Image.asset(
                          'assets/images/UIHome/store.png',
                          width: 23,
                          height: 23,
                        ),
                        title: 'Shop'.tr(),
                        icon2: Icon(Icons.chevron_right_rounded),
                        page: ShopPage(),
                        context: context,
                      ),
                      _divider(context),
                      buildMenuItem(
                        image: Image.asset(
                          'assets/images/crown.png',
                          width: 20,
                          height: 20,
                        ),
                        title: 'My_subscriptions'.tr(),
                        icon2: Icon(Icons.chevron_right_rounded),
                        page: MySubscriptionPage(),
                        context: context,
                      ),
                      _divider(context),
                      buildMenuItem(
                        image: Image.asset(
                          'assets/images/coin.png',
                          width: 20,
                          height: 20,
                        ),
                        title: 'My_coins'.tr(),
                        icon2: Icon(Icons.chevron_right_rounded),
                        page: MyCoinsPage(),
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Settings Card ───
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A2332)
                                  : const Color(0xFFEFF8FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              size: 16,
                              color: const Color(0xFF2E90FA),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Settings'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    buildMenuItem(
                      image: Image.asset(
                        'assets/images/language_icon.png',
                        width: 20,
                        height: 20,
                      ),
                      title: 'Change_language'.tr(),
                      icon2: Icon(Icons.chevron_right_rounded),
                      page: ChangeLanguage(),
                      context: context,
                    ),
                    _divider(context),
                    buildMenuItem(
                      image: Image.asset(
                        'assets/images/information.png',
                        width: 20,
                        height: 20,
                      ),
                      title: 'Change_difficulty_level'.tr(),
                      icon2: Icon(Icons.chevron_right_rounded),
                      page: ChangeLevelEnglish(),
                      context: context,
                    ),
                    _divider(context),
                    buildMenuItem(
                      image: Image.asset(
                        'assets/images/notification.png',
                        width: 20,
                        height: 20,
                      ),
                      title: 'Notifications'.tr(),
                      icon2: Icon(Icons.chevron_right_rounded),
                      page: ChangeNotification(),
                      context: context,
                    ),
                    _divider(context),
                    buildMenuItem(
                      image: Image.asset(
                        'assets/images/lock.png',
                        width: 20,
                        height: 20,
                      ),
                      title: 'Confidentiality'.tr(),
                      icon2: Icon(Icons.chevron_right_rounded),
                      page: PrivacyPolicyPage(),
                      context: context,
                    ),
                    _divider(context),
                    // Delete account
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 14,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          launchUrl(
                            Uri.parse(
                              'https://donishsoft.com/vozhaomuz-deletion/',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Container(
                          height: 44,
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE4E2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/delete.png',
                                    width: 18,
                                    height: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Delete_account'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFD92D20),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: const Color(
                                  0xFFD92D20,
                                ).withValues(alpha: 0.5),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _divider(context),
                    buildMenuItem(
                      image: Image.asset(
                        'assets/images/information.png',
                        width: 20,
                        height: 20,
                      ),
                      title: 'About_VozhaOmuz'.tr(),
                      icon2: Icon(Icons.chevron_right_rounded),
                      page: AboutVozhaOmuzPage(),
                      context: context,
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            // ─── Logout Button ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: MyButton(
                height: 48,
                borderRadius: 7,
                buttonColor: cardBg,
                backButtonColor: Colors.blueGrey.shade100,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                width: double.infinity,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showLogoutDialog(context, ref);
                },
                child: Text(
                  'Exit_account'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // App version
            Consumer(
              builder: (context, ref, _) {
                final versionAsync = ref.watch(appVersionProvider);
                final version = versionAsync.value ?? '...';
                return Text(
                  'profile_version'.tr(
                    args: [version, '${DateTime.now().year}'],
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: subTextColor,
                    fontWeight: FontWeight.w400,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'profile_logout_confirm'.tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                MyButton(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  backButtonColor: Color(0xFFD3D3D3),
                  buttonColor: Color(0xFFF1F1F1),
                  borderRadius: 12,
                  child: Text(
                    "profile_stay".tr(),
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: 20),
                MyButton(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  borderRadius: 12,
                  backButtonColor: Color(0xFFFF6F77),
                  buttonColor: Color(0xFFFF4B55),
                  child: Text(
                    'profile_logout'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    // Clear user storage (tokens, preferences, progress cache)
                    await StorageService.instance.clearAll();
                    // NOTE: downloaded category ZIPs/extracted resources are
                    // intentionally preserved across logout — re-downloading
                    // the 4000-word courses on every sign-out/sign-in
                    // wastes hundreds of MB of mobile data and slows the
                    // first session. Access is still gated by login.
                    // Clear cached word text database (safe — rebuilt on demand)
                    await WordTextCache.instance.clearAll();
                    // NOTE: known/learning word statuses are intentionally
                    // preserved across logout so user keeps their "I know" marks.

                    // Invalidate every provider that holds the previous user's
                    // data. Without this, a free user logging in right after a
                    // premium user would briefly see the premium paywall,
                    // their old rating, achievements, banners, and selected
                    // categories until the next app restart.
                    ref.invalidate(energyProvider);
                    ref.invalidate(progressProvider);
                    ref.invalidate(progressFetchedProvider);
                    ref.invalidate(getProfileInfoProvider);
                    ref.invalidate(profileRatingProvider);
                    ref.invalidate(achievementsProvider);
                    ref.invalidate(top3UsersDayProvider);
                    ref.invalidate(top30UsersProvider);
                    ref.invalidate(bannersProvider);

                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const StartPage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        height: 1,
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF2F4F7),
      ),
    );
  }
}

class buildMenuItem extends StatelessWidget {
  final Image image;
  final String title;
  final Icon icon2;
  final Widget page;
  final BuildContext context;
  const buildMenuItem({
    super.key,
    required this.image,
    required this.title,
    required this.icon2,
    required this.page,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF344054);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
        child: Container(
          height: 44,
          child: Row(
            children: [
              // Icon with tinted background
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2332)
                      : const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: image),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? const Color(0xFF8B949E)
                    : const Color(0xFF98A2B3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
Widget _buildMenuItem(
  IconData icon,
  String title,
  Widget page,
  BuildContext context,
) {
  return ListTile(
    minTileHeight: 30,
    horizontalTitleGap: 30,
    leading: Icon(icon, color: Colors.black),
    title: Text(title),
    trailing: Icon(Icons.arrow_forward_ios, size: 16),
    onTap: () {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    },
  );
}

/// WhatsApp-style fullscreen avatar viewer with pinch-to-zoom.
class _FullScreenAvatar extends StatelessWidget {
  final String imageUrl;
  const _FullScreenAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Hero(
              tag: 'profile_avatar',
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.error, color: Colors.white, size: 60),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
