class CoinItem {
  final int id;
  final String name;
  final int count;
  final int price;

  CoinItem({
    required this.id,
    required this.name,
    required this.count,
    required this.price,
  });

  factory CoinItem.fromJson(Map<String, dynamic> json) {
    return CoinItem(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      count: (json['count'] is num) ? (json['count'] as num).toInt() : 0,
      price: (json['price'] is num) ? (json['price'] as num).toInt() : 0,
    );
  }
}
