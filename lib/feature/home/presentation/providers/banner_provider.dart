import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/home/data/banner_repository.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';

/// Provider that fetches banners from the backend API.
/// Returns AsyncValue<List<BannerDto>> — integrates with Riverpod's
/// loading/error/data states for the home page carousel.
final bannersProvider = FutureProvider.autoDispose<List<BannerDto>>((
  ref,
) async {
  final repository = BannerRepository();
  return repository.getBanners();
});
