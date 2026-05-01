// lib/core/services/words_sync_service.dart
import 'package:vozhaomuz/feature/games/data/models/remember_word_dto.dart';
import 'package:vozhaomuz/feature/games/data/models/user_words_with_upload.dart';
import 'package:vozhaomuz/feature/rating/data/models/premium_bonus_dto.dart';

abstract class IRememberNewWordsRepository {
  /// Синхронизирует прогресс слов с сервером.
  /// POST /api/v1/users/flutter/sync-user-progress-words
  /// Принимает полный список [UserWordsWithUpload] с computed state/timeout.
  Future<RememberNewWordsResponse> syncProgress({
    required List<UserWordsWithUpload> words,
  });

  /// Получить прогресс слов с сервера.
  /// GET /api/v1/users/flutter/get-user-progress-words
  Future<Map<String, dynamic>?> getUserProgressWords();

  /// Отправляет статистику учебной сессии на сервер.
  /// POST /api/v1/users/flutter/activity
  ///
  /// Returns the optional `premium_bonus` block when the streak just
  /// crossed a milestone (TZ §1). Callers can show
  /// [showPremiumBonusDialog] for the grant. `null` on normal sessions
  /// or when the request fails.
  Future<PremiumBonusDto?> sendActivity({
    required DateTime startTime,
    required DateTime endTime,
    required List<int> learned,
    required List<int> errors,
    required List<int> repeated,
  });
}
