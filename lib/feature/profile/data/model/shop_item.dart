class ShopCategory {
  final String id;
  final Map<String, String> nameLocalized;

  ShopCategory({required this.id, required this.nameLocalized});

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    return ShopCategory(
      id: json['id']?.toString() ?? '',
      nameLocalized:
          (json['name'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},
    );
  }

  String getLocalizedName(String langCode) {
    return nameLocalized[langCode] ?? nameLocalized.values.firstOrNull ?? '';
  }
}

class ShopItem {
  final String id;
  final Map<String, String> nameLocalized;
  final Map<String, String> description;
  final int price;
  final ShopCategory category;
  final List<String> photos;
  final int strikes;

  ShopItem({
    required this.id,
    required this.nameLocalized,
    required this.description,
    required this.price,
    required this.category,
    required this.photos,
    this.strikes = 0,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id']?.toString() ?? '',
      nameLocalized:
          (json['name'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},
      description:
          (json['description'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},
      price: json['price'] ?? 0,
      category: ShopCategory.fromJson(json['category'] ?? {}),
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      strikes: json['strikes'] ?? 0,
    );
  }

  String getLocalizedName(String langCode) {
    return nameLocalized[langCode] ?? nameLocalized.values.firstOrNull ?? '';
  }

  String getLocalizedDescription(String langCode) {
    return description[langCode] ?? description.values.firstOrNull ?? '';
  }

  String getFirstPhotoUrl(String baseUrl, String filesPath) {
    if (photos.isEmpty) return '';
    return '$baseUrl/$filesPath${photos.first}';
  }

  List<String> getPhotoUrls(String baseUrl, String filesPath) {
    return photos.map((p) => '$baseUrl/$filesPath$p').toList();
  }
}
