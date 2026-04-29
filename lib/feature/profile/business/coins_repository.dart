import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/profile/data/model/coin_item.dart';

class CoinsRepository {
  Future<List<CoinItem>> getCoinsList() async {
    final token = await StorageService.instance.getAccessToken();
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.coinsList}'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      final coins = jsonList.map((e) => CoinItem.fromJson(e)).toList();
      // Sort by id like Unity does
      coins.sort((a, b) => a.id.compareTo(b.id));
      return coins;
    } else {
      throw Exception('Failed to load coins list: ${response.statusCode}');
    }
  }
}
