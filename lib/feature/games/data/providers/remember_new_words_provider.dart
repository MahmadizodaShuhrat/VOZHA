// lib/models/remember_new_words_provider.dart

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/games/data/remember_new_words_repository.dart';
import 'package:vozhaomuz/core/services/words_sync_service.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';

/// Провайдер репозитория
final rememberNewWordsRepositoryProvider =
    Provider<IRememberNewWordsRepository>((ref) {
      return RememberNewWordsRepository(baseUrl: ApiConstants.baseUrl);
    });
