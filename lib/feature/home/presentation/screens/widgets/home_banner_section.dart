import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/banner_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_coins_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/invite_friend_page.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/banner_widgets.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_3_users_day_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/all_top_vozhaomuzes.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/providers/bottom_nav_provider.dart';

/// Баннерҳои саҳифаи асосӣ: рейтинг + баннерҳои динамикӣ аз backend.
class HomeBannerSection extends ConsumerWidget {
  const HomeBannerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(bannersProvider);

    // Rating slide
    final ratingSlide = GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllTop30Vozhaomuz()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Stack(
              children: [
                // Background gradient image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/banner_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
                // Ellipse 1199
                Positioned(
                  bottom: -8,
                  right: -65,
                  child: Image.asset(
                    'assets/images/Ellipse 1199.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
                // Cloud overlay
                Positioned(
                  top: 1,
                  child: Image.asset(
                    'assets/images/banner_cloud.png',
                    fit: BoxFit.cover,
                    height: 200,
                  ),
                ),
                // Content: users + trophy
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Left: title + top 3 users
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "rating".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Consumer(
                              builder: (context, ref, _) {
                                final topUsersAsync = ref.watch(
                                  top3UsersDayProvider,
                                );
                                return topUsersAsync.when(
                                  data: (users) {
                                    if (users.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Column(
                                      children: users.asMap().entries.map((
                                        entry,
                                      ) {
                                        final index = entry.key;
                                        final user = entry.value;
                                        final avatarUrl = user.avatarUrl;
                                        final isUserPremium =
                                            user.userType == 'pre';
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 1,
                                          ),
                                          child: Row(
                                            children: [
                                              Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isUserPremium
                                                            ? const Color(
                                                                0xFFF9A628,
                                                              )
                                                            : Colors.white
                                                                  .withOpacity(
                                                                    0.6,
                                                                  ),
                                                        width: 1.5,
                                                      ),
                                                      image: DecorationImage(
                                                        image:
                                                            (avatarUrl !=
                                                                    null &&
                                                                avatarUrl
                                                                    .isNotEmpty)
                                                            ? CachedNetworkImageProvider(
                                                                buildAvatarUrl(
                                                                  avatarUrl,
                                                                ),
                                                              )
                                                            : const AssetImage(
                                                                    'assets/images/UIHome/usercircle.png',
                                                                  )
                                                                  as ImageProvider,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isUserPremium)
                                                    Positioned(
                                                      top: -15,
                                                      right: 0,
                                                      left: -5,
                                                      child: Center(
                                                        child: Image.asset(
                                                          'assets/images/group_2.png',
                                                          width: 20,
                                                          height: 20,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      user.name ?? '',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      "n_words".tr(
                                                        args: [
                                                          '${user.count ?? 0}',
                                                        ],
                                                      ),
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(0.8),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                  loading: () => const SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  error: (_, __) => const SizedBox.shrink(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Right: trophy
                      Image.asset(
                        'assets/images/banner (3).png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return bannersAsync.when(
      data: (banners) {
        debugPrint('📢 Banners loaded: ${banners.length}');
        return BannerCarousel(banners: banners, ratingSlide: ratingSlide);
      },
      loading: () {
        debugPrint('📢 Banners loading...');
        return BannerCarousel(banners: const [], ratingSlide: ratingSlide);
      },
      error: (e, st) {
        debugPrint('📢 Banners error: $e');
        debugPrint('📢 Banners stacktrace: $st');
        return BannerCarousel(banners: const [], ratingSlide: ratingSlide);
      },
    );
  }
}

/// Auto-scrolling banner carousel that displays rating + banners from backend.
class BannerCarousel extends StatefulWidget {
  final List<BannerDto> banners;
  final Widget ratingSlide;
  const BannerCarousel({
    super.key,
    required this.banners,
    required this.ratingSlide,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  static const _autoScrollDelay = Duration(seconds: 10);

  late final PageController _controller;
  int _currentPage = 0;
  bool _autoScrollStarted = false;

  int get _totalPages => 1 + widget.banners.length;

  // Large virtual count for infinite effect
  static const int _virtualCount = 10000;
  int get _initialPage =>
      (_virtualCount ~/ 2) - ((_virtualCount ~/ 2) % _totalPages);

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _initialPage);
    _currentPage = 0;
    _maybeStartAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _maybeStartAutoScroll();
    }
  }

  void _maybeStartAutoScroll() {
    if (!_autoScrollStarted && _totalPages > 1) {
      _autoScrollStarted = true;
      Future.delayed(_autoScrollDelay, _autoScroll);
    }
  }

  void _autoScroll() {
    if (!mounted) return;
    if (_totalPages <= 1) return;
    final nextVirtual = (_controller.page?.round() ?? _initialPage) + 1;
    _controller.animateToPage(
      nextVirtual,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    Future.delayed(_autoScrollDelay, _autoScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBannerTap(BannerDto banner) {
    final link = banner.link;
    if (link.isEmpty) return;

    // Matches Unity: links drive banner behavior. HTTPS opens externally,
    // app:// routes open in-app pages.
    if (link.startsWith('https://') || link.startsWith('http://')) {
      launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      return;
    }

    if (!link.startsWith('app://')) return;

    final pageName = link.replaceFirst('app://', '');
    switch (pageName) {
      case 'Premium':
      case 'UISubscriptionPage':
      case 'UIFreeSubscriptionPage':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MySubscriptionPage()),
        );
        return;
      case 'UIBuyCoins':
      case 'UICoinPage':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyCoinsPage()),
        );
        return;
      case 'UIInviteFriend':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InviteFriendPage()),
        );
        return;
      case 'UIBattlePage':
        final container = ProviderScope.containerOf(context);
        // Battle is at index 3 after the Courses tab was added.
        container.read(bottomNavProvider.notifier).setIndex(3);
        return;
      default:
        debugPrint('Unknown app route: $pageName');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Adaptive height: proportional to screen, max 165
        SizedBox(
          height: (MediaQuery.of(context).size.height * 0.20).clamp(130.0, 165.0),
          child: PageView.builder(
            controller: _controller,
            // No itemCount = infinite scrolling
            onPageChanged: (i) =>
                setState(() => _currentPage = i % _totalPages),
            itemBuilder: (_, index) {
              final realIndex = index % _totalPages;
              if (realIndex == 0) {
                return widget.ratingSlide;
              }
              final banner = widget.banners[realIndex - 1];
              return GestureDetector(
                onTap: () => _handleBannerTap(banner),
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: BannerWidgetBuilder.buildBanner(banner),
                  ),
                ),
              );
            },
          ),
        ),
        if (_totalPages > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _totalPages,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentPage == i
                      ? const Color(0xFF2E90FA)
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
