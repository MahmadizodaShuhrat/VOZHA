import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/providers/bottom_nav_provider.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/banner_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/banner_link_router.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/banner_widgets.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/rating_banner_widget.dart';

/// Home-page banner carousel — fully driven by `GET /api/v1/dict/banners`.
/// No hardcoded slides: when the admin has zero active banners the
/// carousel collapses (zero-height) and the home page keeps flowing
/// without an empty placeholder. The rating slide is just another row
/// the admin publishes with `type='rating'` (TZ §3 / §10.6).
///
/// Refresh policy (TZ §11):
/// - cold start: hydrate from disk cache, then refetch in background
/// - app foregrounded after >10 min: lifecycle observer kicks `refreshIfStale`
/// - returning to the home tab after >5 min: `ref.listen` on bottom-nav
/// - pull-to-refresh: wired in `home_page.dart`
///
/// SWR semantics: while the controller refetches in the background the
/// previous list stays on screen, so users never see an empty carousel
/// during a routine refresh.
class HomeBannerSection extends ConsumerStatefulWidget {
  const HomeBannerSection({super.key});

  @override
  ConsumerState<HomeBannerSection> createState() => _HomeBannerSectionState();
}

class _HomeBannerSectionState extends ConsumerState<HomeBannerSection>
    with WidgetsBindingObserver {
  /// Threshold for `AppLifecycleState.resumed` — app coming back from
  /// background. Longer because we expect the user to have been gone
  /// for a while (TZ §11 calls this out as ~10 min).
  static const _staleAfterResume = Duration(minutes: 10);

  /// Threshold for tab-return — user was just on another bottom-nav
  /// tab and came back. Shorter because the round-trip is cheap and
  /// admin changes feel snappier this way (TZ §11: "5 min on home tab").
  static const _staleAfterTabReturn = Duration(minutes: 5);

  /// Bottom-nav index where this section lives. Must match the
  /// home-tab index in `navigation_bar.dart` (currently 0).
  static const _homeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(bannersControllerProvider.notifier)
          .refreshIfStale(_staleAfterResume);
    }
  }

  /// Synthetic rating slide that's always present in the carousel
  /// regardless of what the backend returns. The leaderboard is a
  /// permanent home-page feature — admin disabling/restoring it via
  /// the admin panel is out of scope for now. If the backend later
  /// publishes its own `type='rating'` row, [_withRatingFallback]
  /// drops this synthetic one to avoid duplicates.
  static final BannerDto _ratingFallback = BannerDto(
    id: -1,
    type: 'rating',
    title: 'Rating',
    fileName: '',
    link: 'app://Rating',
    position: 0,
    appVersion: 0,
    platform: '',
  );

  /// Inserts the rating slide at the top unless the server already
  /// included one. Order is preserved otherwise.
  List<BannerDto> _withRatingFallback(List<BannerDto> serverBanners) {
    final hasServerRating = serverBanners.any((b) => b.type == 'rating');
    if (hasServerRating) return serverBanners;
    return [_ratingFallback, ...serverBanners];
  }

  @override
  Widget build(BuildContext context) {
    // Watch bottom-nav transitions: every time the user lands back on
    // the home tab from somewhere else, ask the controller for a
    // refresh if the cache is older than 5 min. Cheap enough to do on
    // every transition because `refreshIfStale` short-circuits when
    // data is fresh.
    ref.listen<int>(bottomNavProvider, (previous, next) {
      if (previous != _homeTabIndex && next == _homeTabIndex) {
        ref
            .read(bannersControllerProvider.notifier)
            .refreshIfStale(_staleAfterTabReturn);
      }
    });

    final asyncState = ref.watch(bannersControllerProvider);
    // Show the previous list (if any) during a background refresh —
    // `asData` carries data through both loading and error states.
    final serverBanners =
        asyncState.asData?.value.banners ?? const <BannerDto>[];
    final banners = _withRatingFallback(serverBanners);
    return BannerCarousel(banners: banners);
  }
}

/// Auto-scrolling banner carousel — every slide is a row from the
/// backend list. `type='rating'` renders the leaderboard widget,
/// everything else falls back to the image-card builder so unknown
/// future types stay safe (TZ §3 forward-compat).
class BannerCarousel extends StatefulWidget {
  final List<BannerDto> banners;
  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  static const _autoScrollDelay = Duration(seconds: 10);

  late final PageController _controller;
  int _currentPage = 0;
  bool _autoScrollStarted = false;

  int get _totalPages => widget.banners.length;

  static const int _virtualCount = 10000;
  int get _initialPage => _totalPages == 0
      ? 0
      : (_virtualCount ~/ 2) - ((_virtualCount ~/ 2) % _totalPages);

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _initialPage);
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

  Widget _buildSlide(BannerDto banner) {
    switch (banner.type) {
      case 'rating':
        return RatingBannerWidget(banner: banner);
      case 'image':
      default:
        // Forward-compat: an unknown type from a newer backend still
        // renders as a regular image card so the app doesn't crash.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: BannerWidgetBuilder.buildBanner(banner),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_totalPages == 0) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SizedBox(
          height: (MediaQuery.of(context).size.height * 0.20).clamp(130.0, 165.0),
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) =>
                setState(() => _currentPage = i % _totalPages),
            itemBuilder: (_, index) {
              final realIndex = index % _totalPages;
              final banner = widget.banners[realIndex];
              return GestureDetector(
                onTap: () => BannerLinkRouter.handle(context, banner.link),
                child: SizedBox.expand(child: _buildSlide(banner)),
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

