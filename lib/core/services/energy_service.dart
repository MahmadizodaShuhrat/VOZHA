import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Immutable snapshot of a user's energy state.
///
/// The persisted [balance] is the value as of [lastRefillAt]; callers must
/// apply regen via [applyRegen] before using it (e.g. when gating a game).
/// This "balance + anchor timestamp" scheme avoids clock-drift bugs from
/// storing the already-regenerated value on every tick.
@immutable
class EnergyState {
  final double balance;
  final int max;
  final DateTime lastRefillAt;
  final int refillSeconds;
  final bool isPremium;

  const EnergyState({
    required this.balance,
    required this.max,
    required this.lastRefillAt,
    required this.refillSeconds,
    required this.isPremium,
  });

  /// First-launch default before the server has been contacted.
  factory EnergyState.initial({required bool isPremium}) => EnergyState(
        balance: AppConstants.energyStartingBalance.toDouble(),
        max: AppConstants.energyMax,
        lastRefillAt: DateTime.now().toUtc(),
        refillSeconds: AppConstants.energyRefillSeconds,
        isPremium: isPremium,
      );

  /// Display value (premium users see the cap).
  double get displayBalance => isPremium ? max.toDouble() : balance;

  /// Whether the user has enough energy to start a game session.
  /// Requires at least `energyMinToPlay` (3.0) on the balance so the user
  /// can't start a session and immediately run out on the first mistake.
  bool get canPlay => isPremium || balance >= AppConstants.energyMinToPlay;

  /// Time until +1 energy is granted. Null if already full or premium.
  Duration? nextRefillIn(DateTime now) {
    if (isPremium || balance >= max) return null;
    final elapsed = now.toUtc().difference(lastRefillAt).inSeconds;
    final remainder = refillSeconds - (elapsed % refillSeconds);
    return Duration(seconds: remainder.clamp(0, refillSeconds));
  }

  EnergyState copyWith({
    double? balance,
    int? max,
    DateTime? lastRefillAt,
    int? refillSeconds,
    bool? isPremium,
  }) {
    return EnergyState(
      balance: balance ?? this.balance,
      max: max ?? this.max,
      lastRefillAt: lastRefillAt ?? this.lastRefillAt,
      refillSeconds: refillSeconds ?? this.refillSeconds,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}

/// Response for the coin→energy refill endpoint
/// (`POST /user/energy/refill`, backend commit bcef49e).
class EnergyRefillResult {
  final EnergyState energy;
  final double money; // user's new coin balance after server deduction
  final int coinsSpent; // always equals AppConstants.energyRefillCoinPrice
  const EnergyRefillResult({
    required this.energy,
    required this.money,
    required this.coinsSpent,
  });
}

/// Business-level errors from `POST /user/energy/refill`. Transient errors
/// (500, network timeouts, parse failures) don't throw — the service just
/// returns null so the caller can show a generic retry toast.
enum EnergyRefillError {
  insufficientCoins, // 402 — user has fewer than 50 coins
  alreadyFull,       // 409 already_full — balance == max after regen
  premiumUser,       // 409 premium_user — premium accounts never need refill
  unauthorized,      // 401 — token expired / invalid
}

class EnergyRefillException implements Exception {
  final EnergyRefillError error;
  const EnergyRefillException(this.error);
  @override
  String toString() => 'EnergyRefillException($error)';
}

/// Handles energy arithmetic, local caching, and server sync.
///
/// Backend contract (placeholder — routes live in [ApiConstants.energyGet] /
/// [ApiConstants.energyConsume]). Expected JSON shape:
/// ```
/// { "balance": 27.5, "max": 30,
///   "last_refill_at": "2026-04-18T10:22:00Z",
///   "refill_seconds": 300 }
/// ```
/// [consumeOnServer] POSTs `{ "mistakes": N, "completed": bool }` and the
/// server returns the same shape with the new balance.
class EnergyService {
  final ApiService _api;

  EnergyService({required ApiService api}) : _api = api;

  /// Pure regen math: advance [state.balance] by whole refill units earned
  /// since [state.lastRefillAt], and move the anchor forward by that many
  /// whole units so sub-unit time does not get lost.
  ///
  /// The anchor ALSO advances while the balance sits at cap — otherwise time
  /// spent at full would silently "bank" regen credits that fire the moment
  /// the user spends energy. Regen is a real-time clock, not a reservoir.
  static EnergyState applyRegen(EnergyState state, {DateTime? now}) {
    if (state.isPremium) return state;
    if (state.refillSeconds <= 0) return state; // defend against bad server data
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final elapsed = nowUtc.difference(state.lastRefillAt).inSeconds;
    if (elapsed <= 0) return state;

    final unitsEarned = elapsed ~/ state.refillSeconds;
    if (unitsEarned <= 0) return state;

    final newBalance =
        (state.balance + unitsEarned).clamp(0, state.max).toDouble();
    final newAnchor = state.lastRefillAt
        .add(Duration(seconds: unitsEarned * state.refillSeconds));
    return state.copyWith(balance: newBalance, lastRefillAt: newAnchor);
  }

  /// Compute the cost of a completed game.
  static double computeCost({required int mistakes, required bool completed}) {
    return (completed ? AppConstants.energyBaseCost : 0) +
        (mistakes * AppConstants.energyMistakePenalty);
  }

  // ============ Local cache ============

  /// Read cached state. Returns null on first launch (caller should seed).
  /// Clamps cached balance to the current max so shrinking [energyMax]
  /// between builds doesn't leave users with balances above the cap.
  EnergyState? loadFromCache({required bool isPremium}) {
    final storage = StorageService.instance;
    final balance = storage.getEnergyBalance();
    final lastRefill = storage.getEnergyLastRefillAt();
    if (balance == null || lastRefill == null) return null;
    final max = AppConstants.energyMax;
    final clamped = balance.clamp(0.0, max.toDouble()).toDouble();
    return EnergyState(
      balance: clamped,
      max: max,
      lastRefillAt: lastRefill,
      refillSeconds: AppConstants.energyRefillSeconds,
      isPremium: isPremium,
    );
  }

  Future<void> saveToCache(EnergyState state) async {
    final storage = StorageService.instance;
    await storage.setEnergyBalance(state.balance);
    await storage.setEnergyLastRefillAt(state.lastRefillAt);
  }

  // ============ Server sync ============

  /// Fetch server-authoritative energy. Returns null if the endpoint is not
  /// yet implemented (404) or on transient errors — callers should fall back
  /// to local cache in that case.
  Future<EnergyState?> fetchFromServer({required bool isPremium}) async {
    try {
      final res = await _api.get(ApiConstants.energyGet);
      final parsed = _parseResponse(res.data, isPremium: isPremium);
      if (parsed != null) {
        debugPrint(
          '⚡ [EnergyService] fetchFromServer OK: '
          'balance=${parsed.balance}, max=${parsed.max}, '
          'lastRefillAt=${parsed.lastRefillAt.toIso8601String()}',
        );
      } else {
        debugPrint(
          '⚠️ [EnergyService] fetchFromServer: unexpected response: ${res.data}',
        );
      }
      return parsed;
    } on DioException catch (e) {
      debugPrint(
        '⚠️ [EnergyService] fetchFromServer failed: '
        'status=${e.response?.statusCode}, msg=${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('⚠️ [EnergyService] fetchFromServer error: $e');
      return null;
    }
  }

  /// Report a completed game to the server. Body:
  /// `{ "mistakes": N, "completed": bool }` — server deducts and returns new
  /// state. Returns null if the request fails (caller should have already
  /// deducted optimistically).
  Future<EnergyState?> consumeOnServer({
    required int mistakes,
    required bool completed,
    required bool isPremium,
  }) async {
    if (isPremium) return null; // premium never deducts server-side
    try {
      debugPrint(
        '⚡ [EnergyService] consumeOnServer: mistakes=$mistakes, '
        'completed=$completed',
      );
      final res = await _api.post(
        ApiConstants.energyConsume,
        data: {'mistakes': mistakes, 'completed': completed},
      );
      final parsed = _parseResponse(res.data, isPremium: isPremium);
      if (parsed != null) {
        debugPrint(
          '⚡ [EnergyService] consumeOnServer OK: new balance=${parsed.balance}',
        );
      }
      return parsed;
    } on DioException catch (e) {
      debugPrint(
        '⚠️ [EnergyService] consumeOnServer failed: '
        'status=${e.response?.statusCode}, msg=${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('⚠️ [EnergyService] consumeOnServer error: $e');
      return null;
    }
  }

  /// Trade [AppConstants.energyRefillCoinPrice] coins for a full energy
  /// refill. Backend (commit bcef49e) performs the coin deduction and
  /// energy top-up atomically, so the client must NOT deduct coins
  /// optimistically — just handle the server response / error codes.
  ///
  /// Returns [EnergyRefillResult] with the new energy state + new money
  /// balance on success. Throws [EnergyRefillException] on business errors
  /// (insufficient coins, already full, premium user). Returns null for
  /// transient/server errors so callers can show a generic retry toast.
  Future<EnergyRefillResult?> refillEnergyOnServer({
    required bool isPremium,
  }) async {
    try {
      debugPrint('⚡ [EnergyService] refillEnergy: requesting server top-up');
      final res = await _api.post(ApiConstants.energyRefill);
      final data = res.data;
      if (data is! Map) return null;
      final energy = _parseResponse(data['energy'], isPremium: isPremium);
      if (energy == null) return null;
      final money = (data['money'] as num?)?.toDouble() ?? 0.0;
      final spent = (data['coins_spent'] as num?)?.toInt() ?? 0;
      debugPrint(
        '⚡ [EnergyService] refillEnergy OK: balance=${energy.balance}, '
        'money=$money, spent=$spent',
      );
      return EnergyRefillResult(energy: energy, money: money, coinsSpent: spent);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] as String?)
          : null;
      final status = e.response?.statusCode;
      debugPrint(
        '⚠️ [EnergyService] refillEnergy failed: status=$status, msg=$msg',
      );
      final error = switch (status) {
        402 => EnergyRefillError.insufficientCoins,
        409 when msg == 'premium_user' => EnergyRefillError.premiumUser,
        409 when msg == 'already_full' => EnergyRefillError.alreadyFull,
        409 => EnergyRefillError.alreadyFull,
        401 => EnergyRefillError.unauthorized,
        _ => null,
      };
      if (error != null) throw EnergyRefillException(error);
      return null;
    } catch (e) {
      debugPrint('⚠️ [EnergyService] refillEnergy error: $e');
      return null;
    }
  }

  EnergyState? _parseResponse(dynamic data, {required bool isPremium}) {
    if (data is! Map) return null;
    final balance = (data['balance'] as num?)?.toDouble();
    final maxVal = (data['max'] as num?)?.toInt();
    final lastRefillStr = data['last_refill_at'] as String?;
    final refillSecs = (data['refill_seconds'] as num?)?.toInt();
    if (balance == null || lastRefillStr == null) return null;
    final lastRefill = DateTime.tryParse(lastRefillStr)?.toUtc();
    if (lastRefill == null) return null;
    return EnergyState(
      balance: balance,
      max: maxVal ?? AppConstants.energyMax,
      lastRefillAt: lastRefill,
      refillSeconds: refillSecs ?? AppConstants.energyRefillSeconds,
      isPremium: isPremium,
    );
  }
}
