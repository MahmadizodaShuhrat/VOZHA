import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// Unity Ads Service — порт Unity GoogleAds.cs
///
/// Инициализируется после 3+ входов (как в Unity: CountSignIn > 3).
/// Показывает rewarded interstitial ad перед действием.
class UnityAdService {
  UnityAdService._();
  static final UnityAdService instance = UnityAdService._();

  // Unity Dashboard Game IDs (из Main.unity Scene)
  static const String _androidGameId = '5824886';
  static const String _iosGameId = '5824887'; // iOS обычно +1

  // Ad Placement IDs (из GoogleAds.cs)
  static const String _androidAdUnitId = 'Interstitial_Android';
  static const String _iosAdUnitId = 'Interstitial_iOS';

  static const String _signInCountKey = 'CountSignIn';

  bool _initialized = false;
  bool _adLoaded = false;

  bool get isInitialized => _initialized;

  String get _gameId => Platform.isIOS ? _iosGameId : _androidGameId;

  String get _adUnitId => Platform.isIOS ? _iosAdUnitId : _androidAdUnitId;

  /// Инициализация — вызывать при каждом входе.
  /// Реклама включается только после 3+ входов (как в Unity).
  Future<void> init() async {
    if (_initialized) return;

    // Web не поддерживается
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt(_signInCountKey) ?? 0;
    count++;
    await prefs.setInt(_signInCountKey, count);

    if (count <= 3) {
      debugPrint('[UnityAds] Пропуск инициализации: вход #$count (нужно > 3)');
      return;
    }

    try {
      await UnityAds.init(
        gameId: _gameId,
        testMode: false,
        onComplete: () {
          _initialized = true;
          debugPrint('[UnityAds] Инициализация завершена');
        },
        onFailed: (UnityAdsInitializationError error, String message) {
          _initialized = false;
          debugPrint('[UnityAds] Ошибка инициализации: $error — $message');
        },
      );
    } catch (e) {
      debugPrint('[UnityAds] Исключение при инициализации: $e');
    }
  }

  /// Загрузить rewarded ad.
  /// [onLoaded] вызывается с true при успехе, true при ошибке тоже
  /// (как в Unity — OnUnityAdsFailedToLoad вызывает OnSuccessLoad(true)).
  Future<void> loadRewardedAd({required Function(bool) onLoaded}) async {
    if (!_initialized) {
      onLoaded(false);
      return;
    }

    try {
      UnityAds.load(
        placementId: _adUnitId,
        onComplete: (placementId) {
          debugPrint('[UnityAds] Ad загружен: $placementId');
          _adLoaded = true;
          onLoaded(true);
        },
        onFailed: (placementId, UnityAdsLoadError error, String message) {
          debugPrint(
            '[UnityAds] Ошибка загрузки: $placementId — $error — $message',
          );
          _adLoaded = false;
          // Как в Unity: при ошибке тоже вызываем true
          onLoaded(true);
        },
      );
    } catch (e) {
      debugPrint('[UnityAds] Исключение при загрузке: $e');
      _adLoaded = false;
      onLoaded(true);
    }
  }

  /// Показать rewarded ad.
  /// [onComplete] вызывается после завершения/закрытия (как Unity OnClosed).
  /// Если не инициализирован — сразу вызывает onComplete (как в Unity).
  Future<void> showRewardedAd({required VoidCallback onComplete}) async {
    if (!_initialized) {
      debugPrint('[UnityAds] Не инициализирован — пропускаем рекламу');
      onComplete();
      return;
    }

    try {
      _adLoaded = false; // Сброс флага после показа
      UnityAds.showVideoAd(
        placementId: _adUnitId,
        onComplete: (placementId) {
          debugPrint('[UnityAds] Ad завершён: $placementId');
          onComplete();
        },
        onFailed: (placementId, UnityAdsShowError error, String message) {
          debugPrint(
            '[UnityAds] Ошибка показа: $placementId — $error — $message',
          );
          onComplete();
        },
        onSkipped: (placementId) {
          debugPrint('[UnityAds] Ad пропущен: $placementId');
          onComplete();
        },
        onStart: (placementId) {
          debugPrint('[UnityAds] Ad начался: $placementId');
        },
      );
    } catch (e) {
      debugPrint('[UnityAds] Исключение при показе: $e');
      onComplete();
    }
  }

  /// Загрузить и показать: сначала load, затем show.
  /// Если реклама уже предзагружена, показывает сразу.
  Future<void> loadAndShowRewardedAd({required VoidCallback onComplete}) async {
    if (!_initialized) {
      debugPrint('[UnityAds] Не инициализирован — пропускаем рекламу');
      onComplete();
      return;
    }

    // Если реклама уже предзагружена, показываем мгновенно
    if (_adLoaded) {
      showRewardedAd(onComplete: onComplete);
      return;
    }

    loadRewardedAd(
      onLoaded: (success) {
        if (success) {
          showRewardedAd(onComplete: onComplete);
        } else {
          onComplete();
        }
      },
    );
  }
}
