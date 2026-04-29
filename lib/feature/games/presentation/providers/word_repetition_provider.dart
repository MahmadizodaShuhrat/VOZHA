// lib/feature/home/presentation/providers/word_repetition_provider.dart
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/word_repetition_service.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

/// Состояние повторения слов
class RepeatState {
  final int repeatCount;
  final bool needsRepeat;
  final List<WordProgress> wordsForRepeat;
  final String langKey; // Направление, из которого взяты слова для повторения
  final bool isReady; // True когда категории загружены и данные готовы
  /// Слова, которые ПРОШЛИ бы предикат "нужны для повторения", но юзер
  /// не может их открыть из-за премиум-замка (потерял премиум, но прогресс
  /// в премиум-категориях остался). Считается по всем направлениям.
  /// UI может показать "+N в премиум" вместо тихого скрытия.
  final int lockedRepeatCount;

  /// Калимаҳое, ки барои бозомӯзӣ тавассути Learn-flow тайёранд
  /// (state ∈ [-3..0], timeout гузашта). Ҳамеш аз direction-и
  /// `langKey` гирифта мешаванд (мисли `wordsForRepeat`).
  final int relearnCount;
  final List<WordProgress> wordsForRelearn;
  final int lockedRelearnCount;

  const RepeatState({
    this.repeatCount = 0,
    this.needsRepeat = false,
    this.wordsForRepeat = const [],
    this.langKey = '',
    this.isReady = false,
    this.lockedRepeatCount = 0,
    this.relearnCount = 0,
    this.wordsForRelearn = const [],
    this.lockedRelearnCount = 0,
  });
}

/// Провайдер состояния повторения слов.
/// ПРИОРИТЕТ: активное направление пользователя (StorageService.getTableWords()).
/// Фильтрует orphaned слова (categoryId не существует в API) —
/// зеркалит Unity GetAllWordsIdWithRepeat() → AviableCategories.
final repeatStateProvider = Provider<RepeatState>((ref) {
  final progress = ref.watch(progressProvider);

  // Get valid category IDs from API (mirrors Unity AviableCategories)
  // Агар категорияҳо ҳанӯз load нашуда бошанд — repeat нишон намедиҳем,
  // то ки калимаҳои бе категория ба рӯйхат дохил нашаванд.
  // Premium / org-lock дигар дар ин ҷо санҷида намешавад — қарори product
  // ин аст, ки дар Repeat ҳамаи калимаҳои такрор-ёбанда нишон дода шаванд,
  // новобаста аз ҳолати premium ё organization.
  final categoriesAsync = ref.watch(categoriesFlutterProvider);
  final validCategoryIds = <int>{};
  bool categoriesLoaded = false;
  categoriesAsync.whenData((cats) {
    categoriesLoaded = true;
    for (final cat in cats) {
      validCategoryIds.add(cat.id);
    }
  });

  // Агар категорияҳо ҳанӯз load нашудаанд — интизор мешавем
  if (!categoriesLoaded) {
    debugPrint('🔄 [repeatStateProvider] Categories not loaded yet, waiting...');
    return const RepeatState();
  }

  // Also wait for the first backend progress fetch to complete — otherwise
  // on slow networks the button flashes "Learn" (from empty local cache) and
  // switches to "Repeat" once dirs arrive from the server.
  final progressFetched = ref.watch(progressFetchedProvider);
  if (!progressFetched) {
    debugPrint('🔄 [repeatStateProvider] Progress not fetched yet, waiting...');
    return const RepeatState();
  }

  // User's active learning direction (e.g. "TjToEn", "RuToEn")
  final activeLangKey = StorageService.instance.getTableWords();

  debugPrint(
    '🔄 [repeatStateProvider] Rebuilding... dirs keys: ${progress.dirs.keys.toList()}, '
    'activeLangKey=$activeLangKey, validCategories: ${validCategoryIds.length}',
  );

  // Helper: get filtered repeat words for a direction.
  // Excludes words from deleted categories (not in API). Premium-locked
  // категорияҳо аз ҳисоб НЕ партоф мешаванд — корбар онҳоро бубинад ва
  // тавонад такрор кунад (қарори product: дар Repeat ягон category-ро lock
  // намекунем).
  List<WordProgress> getFilteredRepeat(String langKey) {
    final words = progress.dirs[langKey] ?? [];
    var repeatWords = WordRepetitionService.getWordsForRepeat(words);
    if (validCategoryIds.isNotEmpty) {
      repeatWords = repeatWords
          .where((w) => validCategoryIds.contains(w.categoryId))
          .toList();
    }
    return repeatWords;
  }

  // PRIORITY 1: Use user's active direction.
  String selectedLangKey = activeLangKey;
  List<WordProgress> selectedRepeatWords = getFilteredRepeat(activeLangKey);

  debugPrint(
    '   📊 [$activeLangKey] (active) total=${progress.dirs[activeLangKey]?.length ?? 0}, '
    'repeat=${selectedRepeatWords.length}',
  );

  // PRIORITY 2: If the active direction has fewer than the threshold worth
  // of repeat words, fall back to whichever other direction has the most.
  // Without this, a user studying RuToEn with 7 RuToEn-due + 13 TjToEn-due
  // words would never see the Repeat button — the active-lang count alone
  // is below threshold and the 13 TjToEn-due words sit there indefinitely.
  if (selectedRepeatWords.length < WordRepetitionService.minRepeatCount) {
    for (final entry in progress.dirs.entries) {
      if (entry.key == activeLangKey) continue;
      final candidate = getFilteredRepeat(entry.key);
      if (candidate.length > selectedRepeatWords.length) {
        selectedLangKey = entry.key;
        selectedRepeatWords = candidate;
      }
    }
    if (selectedLangKey != activeLangKey) {
      debugPrint(
        '   ↪️ Fallback to $selectedLangKey (repeat=${selectedRepeatWords.length})',
      );
    }
  }

  final count = selectedRepeatWords.length;
  final needsRepeat = count >= WordRepetitionService.minRepeatCount;

  debugPrint(
    '🔄 [repeatStateProvider] Selected: $selectedLangKey with $count repeat words, needsRepeat=$needsRepeat',
  );

  // For pickWordsForSession, filter only by valid categories (deleted ones
  // excluded). Premium-locked categories are NOT filtered out — корбар
  // метавонад ҳамаи калимаҳои гузаштаашро такрор кунад, новобаста аз
  // ҳолати premium.
  List<WordProgress> filteredAllWords = progress.dirs[selectedLangKey] ?? [];
  if (validCategoryIds.isNotEmpty) {
    filteredAllWords = filteredAllWords
        .where((w) => validCategoryIds.contains(w.categoryId))
        .toList();
  }

  // `lockedRepeatCount` / `lockedRelearnCount` ҳамеш 0 аст, чунки калимаҳои
  // premium-locked акнун дар ҳисоби асосӣ дохиланд. Майдонҳо барои
  // мутобиқати API нигоҳ дошта мешаванд (snackbar-и upsell-и қаблӣ дигар
  // фаъол намешавад — ин амдан аст).
  const lockedRepeatCount = 0;
  const lockedRelearnCount = 0;

  // Калимаҳои relearn (state ≤ 0) аз ҳамон direction-и `selectedLangKey`
  // гирифта мешаванд — то ҳарду рақамҳо ҳамеш ба як direction рост оянд.
  final relearnWords =
      WordRepetitionService.getWordsForRelearn(filteredAllWords);

  return RepeatState(
    repeatCount: count,
    needsRepeat: needsRepeat,
    wordsForRepeat: needsRepeat
        ? WordRepetitionService.pickWordsForSession(filteredAllWords)
        : [],
    langKey: selectedLangKey,
    isReady: true,
    lockedRepeatCount: lockedRepeatCount,
    relearnCount: relearnWords.length,
    wordsForRelearn: relearnWords,
    lockedRelearnCount: lockedRelearnCount,
  );
});

/// Флаг: сейчас идёт сессия повторения (а не обычного обучения)
final isRepeatModeProvider = NotifierProvider<IsRepeatModeNotifier, bool>(
  IsRepeatModeNotifier.new,
);

class IsRepeatModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}
