import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:vozhaomuz/feature/auth/business/auth_repository.dart';

final getAccessTokenProvider = StateNotifierProvider(
  (ref) => GetAccessTokenProvider(ref),
);

class GetAccessTokenProvider extends StateNotifier<AsyncValue<String>> {
  final Ref ref;
  GetAccessTokenProvider(this.ref) : super(AsyncLoading());

  Future<void> refreshToken() async {
    try {
      state = AsyncLoading();
      final newToken = await AuthRepository(ref).refreshToken();
      state = AsyncData(newToken ?? '');
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
