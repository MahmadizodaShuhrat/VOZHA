/// Core constants for the VozhaOmuz application
library;

/// API Configuration - Matches Unity3D RestApiManager
class ApiConstants {
  ApiConstants._();

  /// Base URL for REST API (matches Unity)
  static const String baseUrl = 'https://api.vozhaomuz.com';

  /// API Version prefix
  static const String apiVersion = '/api/v1';

  /// WebSocket URLs for Battle mode
  static const String wsGameUrl =
      'wss://api.vozhaomuz.com/api/v1/ws/computation';
  static const String wsLobbyUrl = String.fromEnvironment(
    'WS_LOBBY_URL',
    defaultValue: 'wss://api.vozhaomuz.com/api/v1/ws/public-rooms',
  );

  /// Auth Endpoints (matches Unity auth_repository.dart)
  static const String authBase = '$apiVersion/auth';
  static const String authSendCode = '$authBase/sms/send-code';
  static const String authConfirmCode = '$authBase/sms/confirm-code';
  static const String authLogin = '$authBase/login';
  static const String authRefresh = '$authBase/refresh-token';
  static const String authGoogleOAuth =
      '$authBase/google/oauth2-google-get-user';
  static const String authAppleOAuth = '$authBase/apple/oauth2-apple-get-user';
  static const String authRegisterOAuth = '$authBase/register-oauth2';

  /// User Endpoints
  static const String userProfile = '$apiVersion/user/profile';
  static const String userUpdate = '$apiVersion/user/update';
  static const String userSync = '$apiVersion/user/sync-activity';
  static const String userActivity = '$apiVersion/user/activity';

  /// Content Endpoints
  static const String words = '$apiVersion/words';
  static const String categories = '$apiVersion/categories';
  static const String courses = '$apiVersion/courses';

  /// Game Endpoints
  static const String rating = '$apiVersion/rating';
  static const String achievements = '$apiVersion/achievements';
  static const String statistics = '$apiVersion/statistics';
  static const String gameResults = '$apiVersion/games/results';

  /// Shop Endpoints
  static const String storeList = '$apiVersion/store/list';
  static const String storeOrdering = '$apiVersion/store/ordering';
  static const String storeFiles = 'files/store/';
  static const String coins = '$apiVersion/coins';
  static const String subscription = '$apiVersion/subscription';

  /// Premium / Tariff Endpoints
  static const String tariffsList = '$apiVersion/dict/tariffs-list';
  static const String applyPromoCode = '$apiVersion/dict/apply-promo-code';
  static const String paymentAlif = '$apiVersion/payments/alif/pay';
  static const String coinsList = '$apiVersion/dict/coins-list';
  static const String paymentCoin = '$apiVersion/payments/alif/pay-coin';

  /// Energy Endpoints (placeholder — backend to implement)
  static const String energyGet = '$apiVersion/user/energy';
  static const String energyConsume = '$apiVersion/user/energy/consume';
  static const String energyRefill = '$apiVersion/user/energy/refill';

  /// Request timeout — 45s accommodates slow LTE / 3G in rural Central Asia
  /// (Tajikistan, Afghanistan). Large payloads like course ZIPs and audio
  /// files were timing out at 30s despite the connection being alive.
  static const Duration connectTimeout = Duration(seconds: 45);
  static const Duration receiveTimeout = Duration(seconds: 45);

  /// Commonly used base paths (used by repositories)
  static const String dictBase = '$apiVersion/dict';
  static const String usersBase = '$apiVersion/users';
  static const String battleBase = '$apiVersion/battle';

  /// Streak milestones (manual claim — backend doesn't auto-grant these)
  static const String learningStreak = '$dictBase/learning-streak';
  static const String claimMilestone = '$dictBase/claim-milestone';

  /// File paths
  static const String filesResources = '/files/resources/get-resource/';
  static const String filesAvatars = '/files/avatars/';

  /// Resource access key — passed via --dart-define at build time
  static const String resourceSecret = String.fromEnvironment(
    'RESOURCE_SECRET',
    defaultValue: '?key=JBKK5jndfnkdfBJBj4H',
  );
}

/// Storage Keys
class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userName = 'user_name';
  static const String userAvatar = 'user_avatar';
  static const String isPremium = 'is_premium';
  static const String selectedCategories = 'selected_categories';
  static const String interfaceLanguage = 'interface_language';
  static const String learnLanguage = 'learn_language';
  static const String lastSyncTime = 'last_sync_time';

  // Energy cache (local optimistic state between server syncs)
  static const String energyBalance = 'energy_balance';
  static const String energyLastRefillAt = 'energy_last_refill_at';
}

/// App Configuration
class AppConstants {
  AppConstants._();

  static const String appName = 'VozhaOmuz';

  /// Keep in sync with `pubspec.yaml` `version:` (the part before `+`).
  /// Sent as the `App-Version` header to the backend so banners and
  /// other version-gated endpoints filter correctly.
  static const String appVersion = '2.66.0';

  /// Game configuration
  static const int wordsPerGame = 10;
  static const int maxGameRounds = 8;
  static const int battleRounds = 5;

  /// Spaced repetition intervals (in days)
  static const List<int> repeatIntervals = [1, 3, 7, 14, 30, 60, 90];

  /// Coins rewards
  static const int coinsPerCorrectAnswer = 1;
  static const int coinsPerLevelComplete = 10;
  static const int coinsPerDailyReward = 5;

  /// Sync interval
  static const Duration syncInterval = Duration(minutes: 3);

  /// Fallback countdown for the SMS OTP screen when the backend doesn't
  /// return an explicit expiry in the /auth/sms/send-code response.
  static const int smsCodeExpiryFallbackSeconds = 60;

  /// Energy system (Duolingo-style gate for non-premium users).
  /// Canonical values live on the server; these are only used as fallbacks
  /// when the backend is unreachable or for the very first render.
  static const int energyMax = 15;
  static const int energyStartingBalance = 15;

  /// Seconds per 1 energy regen. 1200s = 20 min → 5h for full refill.
  static const int energyRefillSeconds = 1200;

  /// Deducted once per completed game session.
  static const double energyBaseCost = 1.0;

  /// Deducted per wrong attempt within a game session.
  static const double energyMistakePenalty = 0.5;

  /// Minimum balance the user must have BEFORE starting a game. A session
  /// can accumulate up to 1 base cost + several 0.5 penalties, so we gate
  /// entry at 3 so they don't run out mid-game.
  static const double energyMinToPlay = 3.0;

  /// Coin price to top up energy to the max (15). Shown as a button in
  /// `energyPaywallDialog` — lets users trade hard-earned coins for a
  /// full refill instead of waiting 5h for natural regen.
  static const int energyRefillCoinPrice = 50;
}

/// Database Configuration
class DbConstants {
  DbConstants._();

  static const String dbName = 'vozhaomuz.db';
  static const int dbVersion = 1;

  // Table names
  static const String tableUsers = 'users';
  static const String tableWords = 'words';
  static const String tableCategories = 'categories';
  static const String tableSubCategories = 'sub_categories';
  static const String tableLearnedWords = 'learned_words';
  static const String tableErrorWords = 'error_words';
  static const String tableProgress = 'progress';
  static const String tableAchievements = 'achievements';
}

/// OpenAI Configuration — mirrors Unity's OpenAIServices.cs
class OpenAIConstants {
  OpenAIConstants._();

  /// OpenAI API key — passed via --dart-define at build time. Never
  /// hardcode the real key here: it would end up in the public APK
  /// and the GitHub secret scanner will reject the commit.
  static const String apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  /// Model name (Unity: gpt-5-mini)
  static const String model = 'gpt-5-mini';

  /// OpenAI API base URL
  static const String openAIBaseUrl = 'https://api.openai.com/v1';

  /// Server path for the base exam prompt
  /// Unity: RestApiManager.Instance.Get("files/bundles/get-bundle/english_exam_prompt.txt")
  static const String examPromptPath =
      'files/bundles/get-bundle/english_exam_prompt.txt';
}
