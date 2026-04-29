import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';

/// Dio client for battle / legacy HTTP. Without explicit timeouts Dio
/// defaults to 0 = infinite, which used to freeze the UI when a request
/// stalled on a flaky LTE/WiFi connection (common in Tajikistan / rural
/// Central Asia). We inherit the same 45/45s budget as [ApiService] so
/// every HTTP path in the app fails loud instead of hanging silently.
final dioProvider = Provider(
  (_) => Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.receiveTimeout,
    ),
  ),
);
