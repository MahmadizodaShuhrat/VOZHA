import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/providers/dio_provider.dart';
import 'package:vozhaomuz/core/providers/service_providers.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/profile/data/model/shop_item.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(storageServiceProvider);
  return ShopRepository(dio: dio, storage: storage);
});

class ShopRepository {
  final Dio dio;
  final StorageService storage;

  ShopRepository({required this.dio, required this.storage});

  Future<List<ShopItem>> getShopItems() async {
    try {
      final token = await storage.getAccessToken();
      final response = await dio.get(
        ApiConstants.storeList,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> itemsList;

        if (data is String) {
          itemsList = json.decode(data) as List<dynamic>;
        } else if (data is List) {
          itemsList = data;
        } else {
          itemsList = [];
        }

        return itemsList
            .map((item) => ShopItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching shop items: $e');
      rethrow;
    }
  }

  /// POST /api/v1/store/order. Returns a structured result so the UI can
  /// distinguish "not enough coins" from "streak too low" (HTTP 403 with
  /// `streak_requirement_not_met`) and surface the new `order_id`.
  Future<OrderResult> orderItem({
    required int itemId,
    required String phone,
    required String description,
  }) async {
    try {
      final token = await storage.getAccessToken();
      final response = await dio.post(
        ApiConstants.storeOrdering,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          // Don't throw on 4xx so we can read the error body ourselves.
          validateStatus: (s) => s != null && s < 500,
        ),
        data: {'item_id': itemId, 'phone': phone, 'description': description},
      );

      final status = response.statusCode ?? 0;
      final body = response.data is Map
          ? response.data as Map
          : const <String, dynamic>{};

      if (status == 200 || status == 201) {
        final orderId = body['order_id'];
        return OrderResult.success(
          orderId is int ? orderId : int.tryParse('$orderId'),
        );
      }
      if (status == 403 && body['error'] == 'streak_requirement_not_met') {
        return OrderResult.streakRequired(
          required: (body['required_streak'] as num?)?.toInt() ?? 0,
          current: (body['current_streak'] as num?)?.toInt() ?? 0,
        );
      }
      return OrderResult.failure(body['error']?.toString());
    } catch (e) {
      debugPrint('Error ordering item: $e');
      return const OrderResult.failure(null);
    }
  }
}

/// Result of a `POST /store/order` attempt. Distinguishes the new
/// server-side gates so the UI can show the right message.
class OrderResult {
  final bool success;
  final int? orderId;
  /// One of `streak_requirement_not_met`, `not_enough_coins`, or null
  /// for unspecified failures (network, 5xx, parsing).
  final String? errorCode;
  final int? requiredStreak;
  final int? currentStreak;

  const OrderResult._({
    required this.success,
    this.orderId,
    this.errorCode,
    this.requiredStreak,
    this.currentStreak,
  });

  const OrderResult.success(int? id)
      : this._(success: true, orderId: id);

  const OrderResult.streakRequired({
    required int required,
    required int current,
  }) : this._(
          success: false,
          errorCode: 'streak_requirement_not_met',
          requiredStreak: required,
          currentStreak: current,
        );

  const OrderResult.failure(String? code)
      : this._(success: false, errorCode: code);
}
