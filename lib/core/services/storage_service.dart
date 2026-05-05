import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Storage Service for secure token storage and general preferences
///
/// Uses:
/// - [FlutterSecureStorage] for sensitive data (tokens)
/// - [SharedPreferences] as fallback when secure storage fails (release mode)
///
/// IMPORTANT: In release mode, FlutterSecureStorage with
/// encryptedSharedPreferences can fail on some devices due to:
/// - Different signing keys (debug vs release)
/// - KeyStore corruption or migration issues
/// - Android backup/restore edge cases
/// To prevent the app from breaking, all secure storage operations
/// have a SharedPreferences fallback.
class StorageService extends ChangeNotifier {
  late final FlutterSecureStorage _secureStorage;
  late final SharedPreferences _prefs;
  bool _initialized = false;

  /// Whether FlutterSecureStorage is working. If false, we use SharedPreferences fallback.
  bool _secureStorageAvailable = true;

  // In-memory token cache to avoid EncryptedSharedPreferences read latency
  String? _accessTokenCache;
  String? _refreshTokenCache;

  // SharedPreferences fallback keys (used when secure storage fails)
  static const _fallbackAccessTokenKey = '_fb_access_token';
  static const _fallbackRefreshTokenKey = '_fb_refresh_token';

  StorageService._();

  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;

  /// Initialize the storage service
  /// Must be called before using any storage methods
  Future<void> init() async {
    if (_initialized) return;

    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      // `first_unlock_this_device` = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
      // Keeps the refresh token local to this device (no iCloud Keychain sync
      // to other signed-in Apple devices), which was intermittently dropping
      // the token on iOS-only sessions. Still accessible in the background
      // after the user's first unlock post-reboot.
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );

    _prefs = await SharedPreferences.getInstance();

    // Test if secure storage is actually working
    await _testSecureStorage();

    // iOS Keychain persists after app uninstall, but SharedPreferences doesn't.
    // Check if this is a fresh install and clear any stale Keychain tokens.
    const String firstLaunchKey = 'app_has_launched_before';
    final bool hasLaunchedBefore = _prefs.getBool(firstLaunchKey) ?? false;

    if (!hasLaunchedBefore) {
      // Fresh install: clear any stale tokens from previous installation
      try {
        await _secureStorage.deleteAll();
      } catch (e) {
        debugPrint('⚠️ SecureStorage deleteAll failed: $e');
      }
      await _prefs.setBool(firstLaunchKey, true);
    }

    // Токенро аз ҷои боамн мехонем ва кеш мекунем —
    // GoRouter redirect зудтар кор мекунад
    try {
      _accessTokenCache = await _readToken(StorageKeys.accessToken, _fallbackAccessTokenKey);
      _refreshTokenCache = await _readToken(StorageKeys.refreshToken, _fallbackRefreshTokenKey);
    } catch (e) {
      debugPrint('⚠️ Token pre-cache failed: $e');
    }

    _initialized = true;
    debugPrint(
      '✅ StorageService initialized '
      '(secureStorage=${_secureStorageAvailable ? "OK" : "FALLBACK"}, '
      'hasToken=${_accessTokenCache != null})',
    );
  }

  /// Test if FlutterSecureStorage actually works on this device.
  /// Some devices/configurations fail silently in release mode.
  Future<void> _testSecureStorage() async {
    const testKey = '_secure_storage_test';
    const testValue = 'test_ok';
    try {
      await _secureStorage.write(key: testKey, value: testValue);
      final readBack = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);
      if (readBack == testValue) {
        _secureStorageAvailable = true;
        debugPrint('✅ FlutterSecureStorage test passed');
      } else {
        _secureStorageAvailable = false;
        debugPrint('⚠️ FlutterSecureStorage test: read-back mismatch, using fallback');
      }
    } catch (e) {
      _secureStorageAvailable = false;
      debugPrint('⚠️ FlutterSecureStorage test failed: $e — using SharedPreferences fallback');
      // Migrate any existing fallback tokens
      _migrateFromFallback();
    }
  }

  /// If secure storage broke after tokens were stored, try to make them
  /// available via the fallback mechanism.
  void _migrateFromFallback() {
    // Tokens may already exist in SharedPreferences fallback from a previous session
    final fbAccess = _prefs.getString(_fallbackAccessTokenKey);
    final fbRefresh = _prefs.getString(_fallbackRefreshTokenKey);
    if (fbAccess != null) {
      debugPrint('📦 Found fallback access token, using it');
    }
    if (fbRefresh != null) {
      debugPrint('📦 Found fallback refresh token, using it');
    }
  }

  /// Read a token: try secure storage first, fall back to SharedPreferences.
  ///
  /// iOS Keychain with `first_unlock_this_device` accessibility occasionally
  /// returns transient nulls or throws on the *first* read right after the
  /// app is foregrounded — especially when two API calls race the token
  /// lookup. Blindly trusting that null would cascade into
  /// `AuthSessionHandler.handle401()` → `clearTokens()` → unwanted logout
  /// while the user's actual session is still valid.
  ///
  /// Protections here:
  ///   1. Retry the keychain read up to 3 times with small backoff on null
  ///      (null-but-no-exception is a common iOS transient state).
  ///   2. If every keychain attempt returns null/fails, fall back to the
  ///      SharedPreferences mirror (which `_writeToken` always keeps in sync).
  Future<String?> _readToken(String secureKey, String fallbackKey) async {
    if (_secureStorageAvailable) {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final token = await _secureStorage.read(key: secureKey);
          if (token != null && token.isNotEmpty) {
            // Mirror to fallback so later reads survive even if keychain
            // becomes unavailable mid-session.
            await _prefs.setString(fallbackKey, token);
            return token;
          }
          // null-but-no-exception: transient iOS Keychain state. Wait a beat
          // and retry before falling back.
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 120));
          }
        } catch (e) {
          debugPrint(
            '⚠️ SecureStorage read($secureKey) attempt $attempt failed: $e',
          );
          // Hard failure → stop retrying and rely on fallback.
          _secureStorageAvailable = false;
          break;
        }
      }
    }
    // Fallback: read from SharedPreferences (always kept in sync by _writeToken)
    return _prefs.getString(fallbackKey);
  }

  /// Write a token: write to both secure storage AND fallback.
  Future<void> _writeToken(String secureKey, String fallbackKey, String token) async {
    // Always write to fallback first (guaranteed to work)
    await _prefs.setString(fallbackKey, token);
    
    if (_secureStorageAvailable) {
      try {
        await _secureStorage.write(key: secureKey, value: token);
      } catch (e) {
        debugPrint('⚠️ SecureStorage write($secureKey) failed: $e');
        _secureStorageAvailable = false;
      }
    }
  }

  /// Delete a token from both stores. Verifies the Keychain copy was
  /// actually removed — on iOS the delete can silently no-op when the
  /// device is locked / the app is backgrounded, leaving the stale
  /// token readable on next launch and making logout appear to fail.
  /// If we detect that, we mark secure storage unavailable so future
  /// reads go to the (already-cleared) SharedPreferences fallback.
  Future<void> _deleteToken(String secureKey, String fallbackKey) async {
    await _prefs.remove(fallbackKey);
    if (_secureStorageAvailable) {
      try {
        await _secureStorage.delete(key: secureKey);
        // Verification read — if the key is still present, the delete
        // was a silent no-op (iOS Keychain locked, or accessibility
        // mismatch). We can't retry usefully, so we stop trusting
        // secure storage for the rest of this session.
        try {
          final leftover = await _secureStorage.read(key: secureKey);
          if (leftover != null && leftover.isNotEmpty) {
            debugPrint(
              '⚠️ SecureStorage delete($secureKey) left a stale value — '
              'marking storage unavailable to force fallback reads',
            );
            _secureStorageAvailable = false;
          }
        } catch (_) {
          // Read-back failed too — assume storage is unhealthy.
          _secureStorageAvailable = false;
        }
      } catch (e) {
        debugPrint('⚠️ SecureStorage delete($secureKey) failed: $e');
        _secureStorageAvailable = false;
      }
    }
  }

  // ==================== Secure Storage (Tokens) ====================

  Future<String?> getAccessToken() async {
    // Return cached value first (avoids async read latency from secure storage)
    if (_accessTokenCache != null) return _accessTokenCache;
    final token = await _readToken(StorageKeys.accessToken, _fallbackAccessTokenKey);
    _accessTokenCache = token;
    return token;
  }

  /// Synchronous read of the in-memory token cache populated by `init()`.
  /// Used by GoRouter's redirect so the very first frame already knows
  /// whether the user is logged in — avoids the "/home flashes for one
  /// frame, then bounces to /auth/start" issue caused by awaiting the
  /// async getter on cold start.
  String? get cachedAccessToken => _accessTokenCache;

  Future<void> setAccessToken(String token) async {
    _accessTokenCache = token; // Cache immediately
    await _writeToken(StorageKeys.accessToken, _fallbackAccessTokenKey, token);
    notifyListeners();
  }

  Future<String?> getRefreshToken() async {
    if (_refreshTokenCache != null) return _refreshTokenCache;
    final token = await _readToken(StorageKeys.refreshToken, _fallbackRefreshTokenKey);
    _refreshTokenCache = token;
    return token;
  }

  Future<void> setRefreshToken(String token) async {
    _refreshTokenCache = token; // Cache immediately
    await _writeToken(StorageKeys.refreshToken, _fallbackRefreshTokenKey, token);
  }

  Future<void> clearTokens() async {
    _accessTokenCache = null;
    _refreshTokenCache = null;
    await _deleteToken(StorageKeys.accessToken, _fallbackAccessTokenKey);
    await _deleteToken(StorageKeys.refreshToken, _fallbackRefreshTokenKey);
    notifyListeners();
  }

  // ==================== User Data ====================

  int? getUserId() {
    return _prefs.getInt(StorageKeys.userId);
  }

  Future<void> setUserId(int id) async {
    await _prefs.setInt(StorageKeys.userId, id);
  }

  String? getUserName() {
    return _prefs.getString(StorageKeys.userName);
  }

  Future<void> setUserName(String name) async {
    await _prefs.setString(StorageKeys.userName, name);
  }

  String? getUserAvatar() {
    return _prefs.getString(StorageKeys.userAvatar);
  }

  Future<void> setUserAvatar(String avatarUrl) async {
    await _prefs.setString(StorageKeys.userAvatar, avatarUrl);
  }

  bool isPremium() {
    return _prefs.getBool(StorageKeys.isPremium) ?? false;
  }

  Future<void> setIsPremium(bool value) async {
    await _prefs.setBool(StorageKeys.isPremium, value);
  }

  // ==================== Battle Stats ====================

  int getBattleWins() {
    return _prefs.getInt('battle_wins') ?? 0;
  }

  Future<void> incrementBattleWins() async {
    final current = getBattleWins();
    await _prefs.setInt('battle_wins', current + 1);
  }

  // ==================== First Launch ====================

  DateTime? getFirstLaunchDate() {
    final s = _prefs.getString('first_launch_date');
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  Future<void> ensureFirstLaunchDate() async {
    if (_prefs.getString('first_launch_date') == null) {
      await _prefs.setString(
        'first_launch_date',
        DateTime.now().toIso8601String(),
      );
    }
  }

  // ==================== Streak Popup ====================

  String? getLastStreakPopupDate() {
    return _prefs.getString('last_streak_popup_date');
  }

  Future<void> setLastStreakPopupDate(String yyyyMmDd) async {
    await _prefs.setString('last_streak_popup_date', yyyyMmDd);
  }

  // ==================== Settings ====================

  List<String>? getSelectedCategories() {
    return _prefs.getStringList(StorageKeys.selectedCategories);
  }

  Future<void> setSelectedCategories(List<String> categories) async {
    await _prefs.setStringList(StorageKeys.selectedCategories, categories);
  }

  String getInterfaceLanguage() {
    return _prefs.getString(StorageKeys.interfaceLanguage) ?? 'ru';
  }

  Future<void> setInterfaceLanguage(String lang) async {
    await _prefs.setString(StorageKeys.interfaceLanguage, lang);
  }

  String getLearnLanguage() {
    return _prefs.getString(StorageKeys.learnLanguage) ?? 'en';
  }

  Future<void> setLearnLanguage(String lang) async {
    await _prefs.setString(StorageKeys.learnLanguage, lang);
  }

  /// Get table words name in Unity format (e.g., "RuToEn", "TjToEn")
  /// Format: {InterfaceLanguage}To{LearningLanguage}
  /// Matches Unity's DataResources.TableWords
  String getTableWords() {
    final interfaceLang = getInterfaceLanguage(); // "ru" or "tg"
    final learnLang = getLearnLanguage(); // "en", "ru", "tg"

    // Convert short codes to Unity format codes
    String toUnityCode(String code) {
      switch (code) {
        case 'ru':
          return 'Ru';
        case 'tg':
          return 'Tj';
        case 'en':
          return 'En';
        default:
          return 'Ru';
      }
    }

    final from = toUnityCode(interfaceLang);
    final to = toUnityCode(learnLang);

    return '${from}To$to'; // e.g., "RuToEn", "TjToEn"
  }

  // ==================== Energy ====================

  /// Get cached energy balance (null if never written).
  /// The live value must be computed by applying regen since [getEnergyLastRefillAt].
  double? getEnergyBalance() {
    return _prefs.getDouble(StorageKeys.energyBalance);
  }

  Future<void> setEnergyBalance(double value) async {
    await _prefs.setDouble(StorageKeys.energyBalance, value);
  }

  DateTime? getEnergyLastRefillAt() {
    final ts = _prefs.getInt(StorageKeys.energyLastRefillAt);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
  }

  Future<void> setEnergyLastRefillAt(DateTime time) async {
    await _prefs.setInt(
      StorageKeys.energyLastRefillAt,
      time.toUtc().millisecondsSinceEpoch,
    );
  }

  Future<void> clearEnergy() async {
    await _prefs.remove(StorageKeys.energyBalance);
    await _prefs.remove(StorageKeys.energyLastRefillAt);
  }

  // ==================== Sync ====================

  DateTime? getLastSyncTime() {
    final timestamp = _prefs.getInt(StorageKeys.lastSyncTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await _prefs.setInt(StorageKeys.lastSyncTime, time.millisecondsSinceEpoch);
  }

  // ==================== Onboarding ====================

  /// Check if user has completed initial language selection
  bool isOnboardingCompleted() {
    return _prefs.getBool('onboarding_completed') ?? false;
  }

  /// Mark onboarding as completed
  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool('onboarding_completed', value);
  }

  // ==================== Achievements ====================

  /// Key for storing acknowledged achievement codes
  static const _acknowledgedAchievementsKey = 'acknowledged_achievements';

  /// Get the list of achievement codes that user has already seen the popup for
  List<String> getAcknowledgedAchievements() {
    return _prefs.getStringList(_acknowledgedAchievementsKey) ?? [];
  }

  /// Mark an achievement as acknowledged (popup was shown and user pressed Accept)
  Future<void> addAcknowledgedAchievement(String achievementCode) async {
    final list = getAcknowledgedAchievements();
    if (!list.contains(achievementCode)) {
      list.add(achievementCode);
      await _prefs.setStringList(_acknowledgedAchievementsKey, list);
    }
  }

  // ==================== Battle Coin Penalty ====================
  // Like Unity's RemoveCoinsLocal: stores pending deduction in SharedPreferences

  /// Get total pending coin deduction (accumulated from battle exits)
  int getPendingCoinDeduction() {
    return _prefs.getInt('pending_coin_deduction') ?? 0;
  }

  /// Add a coin deduction (called when user exits battle)
  Future<void> addPendingCoinDeduction(int amount) async {
    final current = getPendingCoinDeduction();
    await _prefs.setInt('pending_coin_deduction', current + amount);
  }

  /// Clear pending deductions (called after server confirms deduction)
  Future<void> clearPendingCoinDeduction() async {
    await _prefs.remove('pending_coin_deduction');
  }

  /// Get last known server money (to detect server-side deduction)
  int? getLastKnownServerMoney() {
    return _prefs.getInt('last_known_server_money');
  }

  /// Save the last known server money value
  Future<void> setLastKnownServerMoney(int money) async {
    await _prefs.setInt('last_known_server_money', money);
  }

  // ==================== Reminder Notifications ====================

  /// Get saved reminder hour (null if not set)
  int? getReminderHour() {
    return _prefs.getInt('reminder_hour');
  }

  /// Get saved reminder minute (default 0)
  int? getReminderMinute() {
    return _prefs.getInt('reminder_minute');
  }

  /// Save reminder time
  Future<void> setReminderTime(int hour, int minute) async {
    await _prefs.setInt('reminder_hour', hour);
    await _prefs.setInt('reminder_minute', minute);
  }

  /// Whether the 10-day inactivity push queue has been seeded at least once.
  /// We only auto-schedule on first app launch; after that the queue is
  /// re-armed only when the user completes a learning session (streak-tick).
  bool isInactivitySeeded() {
    return _prefs.getBool('inactivity_pushes_seeded') ?? false;
  }

  Future<void> setInactivitySeeded(bool value) async {
    await _prefs.setBool('inactivity_pushes_seeded', value);
  }

  // ==================== Premium Welcome ====================

  /// Check if premium welcome dialog was already shown
  bool isPremiumWelcomeShown() {
    return _prefs.getBool('premium_welcome_shown') ?? false;
  }

  /// Mark premium welcome dialog as shown
  Future<void> setPremiumWelcomeShown(bool value) async {
    await _prefs.setBool('premium_welcome_shown', value);
  }

  // ==================== Battle daily join quota ====================
  // Non-premium users get a small number of free battle joins per local
  // calendar day. The counter resets on the first join of a new day.
  static const _battleJoinCountKey = 'battle_join_count';
  static const _battleJoinDateKey = 'battle_join_count_date';

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// How many times the user has joined a battle today.
  int getBattleJoinCountToday() {
    final storedDate = _prefs.getString(_battleJoinDateKey);
    if (storedDate != _todayKey()) return 0;
    return _prefs.getInt(_battleJoinCountKey) ?? 0;
  }

  /// Increment today's battle join counter. Resets to 1 on a new day.
  Future<void> incrementBattleJoinCountToday() async {
    final today = _todayKey();
    final storedDate = _prefs.getString(_battleJoinDateKey);
    final int next;
    if (storedDate != today) {
      next = 1;
    } else {
      next = (_prefs.getInt(_battleJoinCountKey) ?? 0) + 1;
    }
    await _prefs.setString(_battleJoinDateKey, today);
    await _prefs.setInt(_battleJoinCountKey, next);
  }

  // ==================== Progress Dirs (Local-First, like Unity PlayerPrefs["UserWords"]) ====================

  static const _progressDirsKey = 'progress_dirs_json';
  static const _pendingProgressSyncKey = 'pending_progress_sync_json';

  /// Save word progress dirs to SharedPreferences as JSON.
  /// Equivalent to Unity's `PlayerPrefs.SetString("UserWords", json)`.
  /// This ensures optimistic state updates survive hot restarts.
  Future<void> saveProgressDirs(Map<String, List<Map<String, dynamic>>> dirsJson) async {
    try {
      final jsonStr = jsonEncode(dirsJson);
      await _prefs.setString(_progressDirsKey, jsonStr);
      debugPrint('💾 [saveProgressDirs] Saved ${dirsJson.entries.map((e) => '${e.key}:${e.value.length}').join(', ')}');
    } catch (e) {
      debugPrint('⚠️ [saveProgressDirs] Error: $e');
    }
  }

  /// Load word progress dirs from SharedPreferences.
  /// Returns null if no local data exists.
  Map<String, dynamic>? loadProgressDirs() {
    final jsonStr = _prefs.getString(_progressDirsKey);
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('⚠️ [loadProgressDirs] Error: $e');
    }
    return null;
  }

  /// Clear local progress cache (on logout)
  Future<void> clearProgressDirs() async {
    await _prefs.remove(_progressDirsKey);
  }

  /// Save pending optimistic progress updates so short-lived sync races do not
  /// overwrite recent local results after hot restart.
  Future<void> savePendingProgressSync(
    Map<String, Map<String, dynamic>> pendingJson,
  ) async {
    try {
      if (pendingJson.isEmpty) {
        await _prefs.remove(_pendingProgressSyncKey);
        return;
      }
      final jsonStr = jsonEncode(pendingJson);
      await _prefs.setString(_pendingProgressSyncKey, jsonStr);
      debugPrint(
        '💾 [savePendingProgressSync] Saved ${pendingJson.length} pending entries',
      );
    } catch (e) {
      debugPrint('⚠️ [savePendingProgressSync] Error: $e');
    }
  }

  /// Load pending optimistic progress updates from SharedPreferences.
  Map<String, dynamic>? loadPendingProgressSync() {
    final jsonStr = _prefs.getString(_pendingProgressSyncKey);
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('⚠️ [loadPendingProgressSync] Error: $e');
    }
    return null;
  }

  Future<void> clearPendingProgressSync() async {
    await _prefs.remove(_pendingProgressSyncKey);
  }

  // ==================== Logout ====================

  /// Clear all user data on logout.
  ///
  /// NOTES:
  ///   - `userAvatar` is intentionally NOT cleared. The API sometimes
  ///     returns an empty `avatar_url` on re-login, so we keep the
  ///     cached URL as a fallback (see getProfileInfoProvider).
  ///   - `progress_dirs_json` + pending-sync entries are intentionally
  ///     NOT cleared either. Users want their "Омӯхташуда" counter
  ///     and learned-word history to survive a logout or an accidental
  ///     token expiry — the cache hydrates the home screen instantly
  ///     the next time they log back in, and the server fetch that
  ///     follows reconciles any drift. If a DIFFERENT user logs in
  ///     on the same device the first `/user/profile` round-trip
  ///     overwrites stale per-user data anyway.
  Future<void> clearAll() async {
    await clearTokens();
    await _prefs.remove(StorageKeys.userId);
    await _prefs.remove(StorageKeys.userName);
    // userAvatar is preserved across logout/login
    await _prefs.remove(StorageKeys.isPremium);
    await _prefs.remove(StorageKeys.selectedCategories);
    await _prefs.remove(StorageKeys.lastSyncTime);
    await _prefs.remove(_acknowledgedAchievementsKey);
    await _prefs.remove('pending_coin_deduction');
    await _prefs.remove('last_known_server_money');
    await _prefs.remove('premium_welcome_shown');
    // progress_dirs_json + pending sync entries preserved across logout
    // so the "Омӯхташуда" counter on the home page doesn't reset
    // whenever the user briefly loses their session.
    await clearEnergy();
  }
}
