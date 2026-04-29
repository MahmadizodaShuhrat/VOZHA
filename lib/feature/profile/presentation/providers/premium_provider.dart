import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/profile/business/premium_repository.dart';

/// Async provider that fetches tariffs from server
final tariffsProvider = FutureProvider<List<Tariff>>((ref) async {
  final repository = ref.watch(premiumRepositoryProvider);
  return repository.getTariffs();
});

/// Selected tariff index
final selectedTariffIdProvider =
    NotifierProvider<SelectedTariffIdNotifier, int?>(
      SelectedTariffIdNotifier.new,
    );

class SelectedTariffIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? value) => state = value;
}

/// Promo code result
final promoResultProvider = NotifierProvider<PromoResultNotifier, PromoResult?>(
  PromoResultNotifier.new,
);

class PromoResultNotifier extends Notifier<PromoResult?> {
  @override
  PromoResult? build() => null;
  void set(PromoResult? value) => state = value;
}
