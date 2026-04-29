import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/rating/business/top_users_repository.dart';
import 'package:vozhaomuz/feature/rating/data/models/top_30_users_dto.dart';

final top3UsersDayProvider = AsyncNotifierProvider<Top3DayProvider, List<Top30UsersDto>>(
  Top3DayProvider.new,
);

class Top3DayProvider extends AsyncNotifier<List<Top30UsersDto>> {
  @override
  FutureOr<List<Top30UsersDto>> build() async {
    final allUsers = await TopUsersRepository().getTopUsers('day');
    return allUsers.take(3).toList();
  }
}
