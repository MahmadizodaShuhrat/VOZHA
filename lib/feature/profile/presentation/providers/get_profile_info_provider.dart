import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/profile/business/profile_repository.dart';
import 'package:vozhaomuz/feature/profile/data/model/profile_info_dto.dart';

final getProfileInfoProvider =
    AsyncNotifierProvider<GetProfileInfoProvider, ProfileInfoDto?>(
      GetProfileInfoProvider.new,
    );

class GetProfileInfoProvider extends AsyncNotifier<ProfileInfoDto?> {
  @override
  FutureOr<ProfileInfoDto?> build() {
    return null;
  }

  Future<void> getProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final profile = await ProfileRepository().getProfile();
        final storage = StorageService.instance;
        await storage.setIsPremium(profile.userType == 'pre');

        if (profile.id != null) {
          await storage.setUserId(profile.id!);
        }
        if (profile.name != null && profile.name!.isNotEmpty) {
          await storage.setUserName(profile.name!);
        }
        var fixedProfile = profile;
        if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
          await storage.setUserAvatar(profile.avatarUrl!);
        } else {
          final cachedAvatar = storage.getUserAvatar();
          if (cachedAvatar != null && cachedAvatar.isNotEmpty) {
            fixedProfile = profile.copyWith(avatarUrl: cachedAvatar);
          }
        }

        return _applyPendingDeduction(fixedProfile);
      } on NoTokenException {
        rethrow; // No token = not logged in, must show login page
      } catch (e) {
        // Network error — try to build profile from local cache
        debugPrint('⚠️ [getProfile] API failed, using local cache: $e');
        final cached = _buildCachedProfile();
        if (cached != null) return cached;
        rethrow; // No cached data either — show error
      }
    });
  }

  /// Build a minimal ProfileInfoDto from locally cached data.
  /// Returns null if no cached user data exists.
  ProfileInfoDto? _buildCachedProfile() {
    final storage = StorageService.instance;
    final userId = storage.getUserId();
    if (userId == null) return null; // Never logged in

    return ProfileInfoDto(
      id: userId,
      name: storage.getUserName(),
      avatarUrl: storage.getUserAvatar(),
      userType: storage.isPremium() ? 'pre' : 'free',
      money: storage.getLastKnownServerMoney(),
    );
  }

  /// Apply pending deductions to server profile.
  /// If server already deducted, clear local pending.
  ProfileInfoDto _applyPendingDeduction(ProfileInfoDto profile) {
    final storage = StorageService.instance;
    final pendingDeduction = storage.getPendingCoinDeduction();
    final lastKnownServerMoney = storage.getLastKnownServerMoney();
    final serverMoney = profile.money ?? 0;

    debugPrint(
      '[getProfile] serverMoney=$serverMoney, '
      'lastKnownServer=$lastKnownServerMoney, pending=$pendingDeduction',
    );

    if (pendingDeduction <= 0) {
      // No pending deductions. The usual case is serverMoney ≥ lastKnown
      // (we earned coins or stayed flat) and we just trust the server.
      //
      // But there's a race: right after a `syncProgress` credits coins
      // we call `syncMoneyFromServer(localOld + delta)` which bumps
      // `lastKnownServerMoney` to the new optimistic value. If a
      // getProfile fires before the backend's money-credit worker has
      // caught up, `serverMoney` will still report the OLD balance
      // (lower than what we just optimistically applied) and without a
      // guard we'd overwrite the correct local value with the stale
      // server one — causing "I just earned +3 coins but my balance
      // didn't change" reports from QA.
      //
      // Heuristic: if there's no pending deduction and the server
      // value is LOWER than our last-known, keep the higher local value.
      // The server will align on its next tick and this branch will
      // become a no-op. We preserve `lastKnownServerMoney` so the
      // guard stays armed until the server reports the matching or
      // higher balance.
      if (lastKnownServerMoney != null && serverMoney < lastKnownServerMoney) {
        debugPrint(
          '[getProfile] server lagging behind local optimistic '
          'balance ($serverMoney < $lastKnownServerMoney) — keeping local',
        );
        return profile.copyWith(money: lastKnownServerMoney);
      }
      storage.setLastKnownServerMoney(serverMoney);
      return profile;
    }

    // Check if server already deducted (server money went down)
    if (lastKnownServerMoney != null && serverMoney < lastKnownServerMoney) {
      // Server has processed the deduction — clear pending
      debugPrint('[getProfile] Server deducted coins, clearing pending');
      storage.clearPendingCoinDeduction();
      storage.setLastKnownServerMoney(serverMoney);
      return profile;
    }

    // Server hasn't deducted yet — apply local deduction
    final adjustedMoney = (serverMoney - pendingDeduction).clamp(0, 999999);
    debugPrint(
      '[getProfile] Applying local deduction: $serverMoney - $pendingDeduction = $adjustedMoney',
    );
    storage.setLastKnownServerMoney(serverMoney);
    return profile.copyWith(money: adjustedMoney);
  }

  /// Overwrite the local money balance with a server-authoritative value.
  /// Used after an atomic coin-debit endpoint (e.g. `/user/energy/refill`)
  /// — backend deducted already, so we skip the pending-deduction flow
  /// and just reflect the new balance in the UI.
  void syncMoneyFromServer(int newMoney) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(money: newMoney));
    StorageService.instance.setLastKnownServerMoney(newMoney);
    // Clear any stale pending deduction — the server balance supersedes it.
    StorageService.instance.clearPendingCoinDeduction();
    debugPrint('[syncMoneyFromServer] money=$newMoney (server-authoritative)');
  }

  /// Like Unity3D RemoveCoinsLocal — deduct coins locally + persist to storage
  void deductCoins(int amount) {
    final current = state.value;
    debugPrint('[deductCoins] amount=$amount, current=${current?.money}');
    if (current != null) {
      final currentMoney = current.money ?? 0;
      final newMoney = (currentMoney - amount).clamp(0, currentMoney);
      state = AsyncData(current.copyWith(money: newMoney));
      debugPrint('[deductCoins] newMoney=$newMoney');
    }
    // Always persist the deduction (survives app restart & getProfile refresh)
    StorageService.instance.addPendingCoinDeduction(amount);
    debugPrint('[deductCoins] Persisted pending deduction: +$amount');
  }
}
