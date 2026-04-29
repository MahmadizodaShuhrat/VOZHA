import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/rating/business/top_users_repository.dart';
import 'package:vozhaomuz/feature/rating/data/models/top_30_users_dto.dart';

final top30UsersProvider = AsyncNotifierProvider<Top30UsersProvider, List<Top30UsersDto>>(
  Top30UsersProvider.new,
);

class Top30UsersProvider extends AsyncNotifier<List<Top30UsersDto>> {
  @override
  FutureOr<List<Top30UsersDto>> build() {
    return []; // Изначально пустой список или загрузка дефолтного периода
  }

  Future<void> fetchUsers(String period) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await TopUsersRepository().getTopUsers(period);
    });
  }
}


