import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/energy_service.dart';
import '../services/storage_service.dart';
import 'service_providers.dart';

/// Singleton EnergyService bound to the ApiService.
final energyServiceProvider = Provider<EnergyService>((ref) {
  final api = ref.watch(apiServiceProvider);
  return EnergyService(api: api);
});

/// Holds the user's current energy state and exposes actions the UI needs:
/// loading on startup, gating before a game, and reporting results.
///
/// The notifier is optimistic: [consume] deducts locally immediately so the
/// UI reflects the change, then syncs with the server. If the server
/// response comes back, we trust it and overwrite.
final energyProvider =
    NotifierProvider<EnergyNotifier, EnergyState>(EnergyNotifier.new);

class EnergyNotifier extends Notifier<EnergyState> {
  @override
  EnergyState build() {
    final isPremium = StorageService.instance.isPremium();
    final svc = ref.read(energyServiceProvider);
    final cached = svc.loadFromCache(isPremium: isPremium);
    final seed = cached ?? EnergyState.initial(isPremium: isPremium);
    // Persist the initial state on first launch so cache is always populated.
    if (cached == null) {
      unawaited(svc.saveToCache(seed));
    }
    return EnergyService.applyRegen(seed);
  }

  /// Call once on app start / home load: fetch canonical state from server,
  /// fall back to cached+regen if the backend isn't available yet.
  Future<void> refreshFromServer() async {
    final svc = ref.read(energyServiceProvider);
    final server = await svc.fetchFromServer(isPremium: state.isPremium);
    if (server != null) {
      state = EnergyService.applyRegen(server);
      await svc.saveToCache(state);
    } else {
      // Server unavailable — recompute regen on the local anchor so a long
      // app close still shows the correct current balance.
      state = EnergyService.applyRegen(state);
      await svc.saveToCache(state);
    }
  }

  /// Called when premium status flips (purchase / expiry) so the UI stops
  /// gating games without a full app restart.
  void setPremium(bool isPremium) {
    if (state.isPremium == isPremium) return;
    state = state.copyWith(isPremium: isPremium);
  }

  /// Recompute regen against the live clock (cheap — used by the countdown
  /// ticker so the indicator shows correct balance each second).
  void tick() {
    final next = EnergyService.applyRegen(state);
    if (next.balance != state.balance || next.lastRefillAt != state.lastRefillAt) {
      state = next;
    }
  }

  /// Returns true if the user has enough energy to start a game.
  /// Also rolls any pending regen into state before answering.
  bool canPlay() {
    state = EnergyService.applyRegen(state);
    return state.canPlay;
  }

  /// Trade [AppConstants.energyRefillCoinPrice] coins for a full energy
  /// refill via the backend. Backend (commit bcef49e) deducts coins AND
  /// resets energy atomically, so we MUST NOT deduct coins locally first —
  /// the caller should instead use the returned money balance from
  /// [EnergyRefillResult].
  ///
  /// Returns the server response on success. Throws [EnergyRefillException]
  /// on business errors (insufficient_coins / already_full / premium_user /
  /// unauthorized). Returns null for transient server errors (caller shows
  /// a generic retry toast).
  Future<EnergyRefillResult?> refillToMax() async {
    debugPrint('⚡ [refillToMax] called. balance=${state.balance}');
    if (state.isPremium) {
      throw const EnergyRefillException(EnergyRefillError.premiumUser);
    }
    final svc = ref.read(energyServiceProvider);
    final result = await svc.refillEnergyOnServer(isPremium: state.isPremium);
    if (result == null) return null;
    state = EnergyService.applyRegen(result.energy);
    await svc.saveToCache(state);
    debugPrint('⚡ [refillToMax] OK: balance=${state.balance}/${state.max}');
    return result;
  }

  /// Grant +1 energy as the reward for watching a rewarded ad. Updates
  /// state optimistically so the UI reacts instantly; a real backend
  /// integration should also POST to the server (to prevent
  /// client-side abuse), but for MVP we stay local-only.
  ///
  /// No-ops for premium users (they're already at cap) and when the
  /// balance is already at max.
  Future<void> grantFromAd() async {
    if (state.isPremium) return;
    final regened = EnergyService.applyRegen(state);
    if (regened.balance >= regened.max) {
      state = regened;
      return;
    }
    final newBalance =
        (regened.balance + 1).clamp(0.0, regened.max.toDouble()).toDouble();
    state = regened.copyWith(balance: newBalance);
    await ref.read(energyServiceProvider).saveToCache(state);
  }

  /// Deduct energy for a finished game and sync with the server.
  /// Optimistic: local state changes first, then the server response
  /// (if any) overwrites. Premium users are exempt.
  Future<void> consume({
    required int mistakes,
    required bool completed,
  }) async {
    if (state.isPremium) return;

    final cost = EnergyService.computeCost(
      mistakes: mistakes,
      completed: completed,
    );
    if (cost <= 0) return;

    final regened = EnergyService.applyRegen(state);
    final newBalance =
        (regened.balance - cost).clamp(0.0, regened.max.toDouble()).toDouble();
    final optimistic = regened.copyWith(balance: newBalance);
    state = optimistic;

    final svc = ref.read(energyServiceProvider);
    await svc.saveToCache(optimistic);

    final server = await svc.consumeOnServer(
      mistakes: mistakes,
      completed: completed,
      isPremium: state.isPremium,
    );
    if (server != null) {
      state = EnergyService.applyRegen(server);
      await svc.saveToCache(state);
    }
  }
}

/// Fire-and-forget helper for async work we don't want to await in sync code.
void unawaited(Future<void> future) {
  future.catchError((e) {
    debugPrint('⚠️ [energyProvider] async error: $e');
  });
}
