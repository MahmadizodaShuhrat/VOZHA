import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/profile/business/coins_repository.dart';
import 'package:vozhaomuz/feature/profile/data/model/coin_item.dart';

final coinsListProvider = FutureProvider<List<CoinItem>>((ref) async {
  final repository = CoinsRepository();
  return repository.getCoinsList();
});
