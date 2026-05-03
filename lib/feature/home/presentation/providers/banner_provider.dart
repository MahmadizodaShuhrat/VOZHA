import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/home/data/banner_cache.dart';
import 'package:vozhaomuz/feature/home/data/banner_repository.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';

/// SWR-style state: keep the list around between fetches and remember
/// when it was last loaded so callers can ask for a refresh only when
/// the data is actually stale (TZ §11).
class BannerListState {
  final List<BannerDto> banners;
  final DateTime? fetchedAt;

  /// `true` while the in-memory list came from the on-disk snapshot
  /// rather than a fresh network response. Lets callers decide whether
  /// to also kick off a network refresh.
  final bool fromCache;

  const BannerListState({
    this.banners = const [],
    this.fetchedAt,
    this.fromCache = false,
  });

  BannerListState copyWith({
    List<BannerDto>? banners,
    DateTime? fetchedAt,
    bool? fromCache,
  }) =>
      BannerListState(
        banners: banners ?? this.banners,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        fromCache: fromCache ?? this.fromCache,
      );
}

/// Banner controller — exposes an `AsyncValue<BannerListState>` so the
/// UI can show shimmer on cold start while still rendering the previous
/// list during background refresh. Backed by [BannerRepository] +
/// [BannerCache], with a lifecycle-aware [refreshIfStale] that the
/// home page calls after the app comes back from background, after the
/// user returns to the home tab, or on pull-to-refresh.
///
/// Cold-start flow (TZ §11):
/// 1. Read disk snapshot (instant if present and < 30 min old).
/// 2. Kick off a background `getBanners()` to refresh.
/// 3. When the network call lands, replace state and re-persist.
///
/// If the disk is empty or expired we just await the network call —
/// mirrors the previous behaviour and keeps cold-no-cache fast.
class BannerController extends AsyncNotifier<BannerListState> {
  late final BannerRepository _repo = BannerRepository();

  /// Coalesces concurrent network calls. A pull-to-refresh, the
  /// background-refetch kicked off after a cache hit, and an
  /// `AppLifecycleState.resumed` event can all fire within the same
  /// few hundred ms. Without this guard they race — two `getBanners()`
  /// calls land out of order and the older response can clobber the
  /// newer state. With the guard, late callers piggyback on the
  /// in-flight request instead.
  Future<List<BannerDto>>? _inFlight;

  @override
  Future<BannerListState> build() async {
    final cached = await BannerCache.read();
    if (cached != null) {
      // Hand the UI a usable list immediately, then refresh in the
      // background so admin changes still propagate within minutes.
      Future.microtask(_refreshFromNetwork);
      return BannerListState(
        banners: cached.banners,
        fetchedAt: cached.fetchedAt,
        fromCache: true,
      );
    }
    final list = await _fetchOnce();
    return BannerListState(banners: list, fetchedAt: DateTime.now());
  }

  /// Single source of truth for "go to the network and persist". All
  /// concurrent callers share the same future — last-writer-wins on
  /// the cache file is impossible because there's only ever one writer
  /// in flight.
  Future<List<BannerDto>> _fetchOnce() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final fresh = () async {
      try {
        final list = await _repo.getBanners();
        await BannerCache.write(list);
        return list;
      } finally {
        _inFlight = null;
      }
    }();
    _inFlight = fresh;
    return fresh;
  }

  /// Background refresh kicked off after a cache hit on cold start.
  /// Coalesces with any concurrent explicit refresh (see [_fetchOnce]).
  Future<void> _refreshFromNetwork() async {
    final list = await _fetchOnce();
    state = AsyncData(
      BannerListState(banners: list, fetchedAt: DateTime.now()),
    );
  }

  /// Force-refresh — used by pull-to-refresh and after background.
  /// Keeps the previous list visible while the new request runs (SWR).
  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final list = await _fetchOnce();
      return BannerListState(banners: list, fetchedAt: DateTime.now());
    });
  }

  /// Refresh only if the cached list is older than [maxAge]. Called
  /// from `AppLifecycleState.resumed` and on home-tab focus to keep
  /// the carousel reasonably fresh without hammering the API. A `null`
  /// `fetchedAt` (e.g. previous fetch failed) also triggers a refresh.
  Future<void> refreshIfStale(Duration maxAge) async {
    final fetched = state.asData?.value.fetchedAt;
    if (fetched != null && DateTime.now().difference(fetched) < maxAge) {
      return;
    }
    await refresh();
  }
}

final bannersControllerProvider =
    AsyncNotifierProvider<BannerController, BannerListState>(
  BannerController.new,
);
