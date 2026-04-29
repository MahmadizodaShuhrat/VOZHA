import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/profile/business/shop_repository.dart';
import 'package:vozhaomuz/feature/profile/data/model/shop_item.dart';

/// Async provider that fetches shop items from the server
final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  final repository = ref.watch(shopRepositoryProvider);
  return repository.getShopItems();
});

/// Selected category filter
final selectedShopCategoryProvider =
    NotifierProvider<SelectedShopCategoryNotifier, String>(
      SelectedShopCategoryNotifier.new,
    );

class SelectedShopCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'all';
  void set(String value) => state = value;
}

/// Filtered shop items based on selected category
final filteredShopItemsProvider = Provider<AsyncValue<List<ShopItem>>>((ref) {
  final selectedCategory = ref.watch(selectedShopCategoryProvider);
  final itemsAsync = ref.watch(shopItemsProvider);

  return itemsAsync.whenData((items) {
    if (selectedCategory == 'all') return items;
    return items.where((item) => item.category.id == selectedCategory).toList();
  });
});

/// Selected shop item for detail page
final selectedShopItemProvider =
    NotifierProvider<SelectedShopItemNotifier, ShopItem?>(
      SelectedShopItemNotifier.new,
    );

class SelectedShopItemNotifier extends Notifier<ShopItem?> {
  @override
  ShopItem? build() => null;
  void set(ShopItem? value) => state = value;
}
