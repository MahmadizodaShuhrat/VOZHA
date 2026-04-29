import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/providers/dio_provider.dart';
import 'package:vozhaomuz/core/providers/service_providers.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

/// Tariff model matching Unity's Tariff class
class Tariff {
  final int id;
  final Map<String, String> name; // Localized name
  final int price;
  final int duration; // in days

  Tariff({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) {
    Map<String, String> nameMap = {};
    final nameRaw = json['name'];
    if (nameRaw is String) {
      // Unity stores localized name as JSON string
      try {
        final decoded = jsonDecode(nameRaw);
        if (decoded is Map) {
          nameMap = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {
        nameMap = {'ru': nameRaw};
      }
    } else if (nameRaw is Map) {
      nameMap = nameRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    return Tariff(
      id: json['id'] ?? 0,
      name: nameMap,
      price: (json['price'] is num) ? (json['price'] as num).toInt() : 0,
      duration: json['duration'] ?? 0,
    );
  }

  String getLocalizedName(String langCode) {
    return name[langCode] ?? name.values.firstOrNull ?? '';
  }
}

/// Promo code apply result matching Unity's ApplyPromocodeTariff
class PromoResult {
  final int amount; // before discount
  final int discountPercent;
  final int tariffPrice;

  PromoResult({
    required this.amount,
    required this.discountPercent,
    required this.tariffPrice,
  });

  factory PromoResult.fromJson(Map<String, dynamic> json) {
    return PromoResult(
      amount: (json['amount'] is num) ? (json['amount'] as num).toInt() : 0,
      discountPercent: (json['discount_percent'] is num)
          ? (json['discount_percent'] as num).toInt()
          : 0,
      tariffPrice: (json['tariff_price'] is num)
          ? (json['tariff_price'] as num).toInt()
          : 0,
    );
  }
}

final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(storageServiceProvider);
  return PremiumRepository(dio: dio, storage: storage);
});

class PremiumRepository {
  final Dio dio;
  final StorageService storage;

  PremiumRepository({required this.dio, required this.storage});

  /// Fetch tariffs from server (matches Unity GetTariffList)
  Future<List<Tariff>> getTariffs() async {
    try {
      final response = await dio.get(
        ApiConstants.tariffsList,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        Map<String, dynamic> body;

        if (data is String) {
          body = jsonDecode(data) as Map<String, dynamic>;
        } else if (data is Map<String, dynamic>) {
          body = data;
        } else {
          return [];
        }

        final tariffsList = body['tariffs'] as List<dynamic>? ?? [];
        final tariffs = tariffsList
            .map((t) => Tariff.fromJson(t as Map<String, dynamic>))
            .toList();

        // Sort by duration ascending (like Unity)
        tariffs.sort((a, b) => a.duration.compareTo(b.duration));
        return tariffs;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching tariffs: $e');
      rethrow;
    }
  }

  /// Apply promo code (matches Unity GetApplyPromocode)
  Future<PromoResult?> applyPromoCode(String promoCode, int tariffId) async {
    try {
      final response = await dio.get(
        ApiConstants.applyPromoCode,
        queryParameters: {'promo_code': promoCode, 'tariff_id': tariffId},
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        Map<String, dynamic> body;
        if (data is String) {
          body = jsonDecode(data) as Map<String, dynamic>;
        } else {
          body = data as Map<String, dynamic>;
        }
        return PromoResult.fromJson(body);
      }
      return null;
    } catch (e) {
      debugPrint('Error applying promo code: $e');
      return null;
    }
  }

  /// Build payment URL (matches Unity CreateOrder)
  /// paymentType: 0=Korti Milli/Alif/Salom, 1=MasterCard, 2=VisaCard
  Future<String> getPaymentUrl(
    int tariffId,
    String promoCode,
    int paymentType,
  ) async {
    final token = await storage.getAccessToken();
    var url =
        '${ApiConstants.baseUrl}${ApiConstants.paymentAlif}?tariff_id=$tariffId&promo_code=$promoCode&token=$token';

    if (paymentType == 1) {
      url += '&gate=mcr';
    } else if (paymentType == 2) {
      url += '&gate=vsa';
    }

    return url;
  }

  /// Build coin payment URL (matches Unity CreateOrderCoins)
  /// paymentType: 0=Korti Milli/Alif/Salom, 1=MasterCard, 2=VisaCard
  Future<String> getCoinPaymentUrl(int coinId, int paymentType) async {
    final token = await storage.getAccessToken();
    var url =
        '${ApiConstants.baseUrl}${ApiConstants.paymentCoin}?coin_id=$coinId&token=$token';

    if (paymentType == 1) {
      url += '&gate=mcr';
    } else if (paymentType == 2) {
      url += '&gate=vsa';
    }

    return url;
  }
}
