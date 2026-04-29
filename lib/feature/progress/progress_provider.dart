// lib/feature/progress/progress_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/utils/app_locale_utils.dart';
import 'package:vozhaomuz/feature/games/data/remember_new_words_repository.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/feature/home/data/categories_repository.dart';
import 'package:vozhaomuz/feature/progress/progress_merge_helper.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/core/services/word_text_cache.dart';
import 'package:vozhaomuz/core/services/app_logger.dart';
import 'package:vozhaomuz/feature/games/data/models/user_words_with_upload.dart';

/// Заглушка. Будет заменена в main.dart через ProviderScope.overrides
final progressProvider = NotifierProvider<ProgressNotifier, ProgressFile>(
  ProgressNotifier.new,
);

/// True once `fetchProgressFromBackend` has completed at least once this app run
/// (success OR failure). Used by `repeatStateProvider` to avoid flashing the
/// "Learn" button while progress is still loading on slow connections.
final progressFetchedProvider =
    NotifierProvider<ProgressFetchedNotifier, bool>(
      ProgressFetchedNotifier.new,
    );

class ProgressFetchedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void markFetched() => state = true;
}

class ProgressNotifier extends Notifier<ProgressFile> {
  Map<String, PendingProgressSync> _pendingProgressSync = {};

  int? get userId {
    return null;
  }

  @override
  ProgressFile build() {
    // Load persisted selectedIds from SharedPreferences (like Unity's PlayerPrefs)
    final saved = StorageService.instance.getSelectedCategories();
    final selectedIds =
        saved
            ?.map((s) => int.tryParse(s))
            .where((v) => v != null)
            .cast<int>()
            .toList() ??
        [];

    // Load cached progress from local storage (like Unity's PlayerPrefs["UserWords"])
    // This ensures optimistic state updates survive hot restarts
    final localDirs = _loadProgressFromLocal();
    if (localDirs.isNotEmpty) {
      debugPrint('📂 [build] Loaded ${localDirs.entries.map((e) => '${e.key}:${e.value.length}').join(', ')} from local cache');
    }

    _pendingProgressSync = _loadPendingProgressSyncFromLocal();
    if (_pendingProgressSync.isNotEmpty) {
      debugPrint(
        '💾 [build] Loaded ${_pendingProgressSync.length} pending progress sync entries',
      );
    }

    return ProgressFile(dirs: localDirs, selectedIds: selectedIds, achievements: []);
  }

  /// Loads progress dirs from SharedPreferences (local-first cache).
  Map<String, List<WordProgress>> _loadProgressFromLocal() {
    final jsonData = StorageService.instance.loadProgressDirs();
    if (jsonData == null) return {};

    final dirs = <String, List<WordProgress>>{};
    for (final key in jsonData.keys) {
      final value = jsonData[key];
      if (value is List) {
        final words = <WordProgress>[];
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            try {
              words.add(WordProgress.fromJson(item));
            } catch (e, st) {
              AppLogger.error('loadProgressLocal', e, st);
            }
          }
        }
        if (words.isNotEmpty) {
          dirs[key] = words;
        }
      }
    }
    return dirs;
  }

  /// Saves current progress dirs to SharedPreferences.
  void _saveProgressToLocal() {
    final dirsJson = <String, List<Map<String, dynamic>>>{};
    for (final entry in state.dirs.entries) {
      dirsJson[entry.key] = entry.value.map((w) => w.toJson()).toList();
    }
    StorageService.instance.saveProgressDirs(dirsJson);
  }

  Map<String, PendingProgressSync> _loadPendingProgressSyncFromLocal() {
    final jsonData = StorageService.instance.loadPendingProgressSync();
    if (jsonData == null) return {};

    final pending = <String, PendingProgressSync>{};
    for (final entry in jsonData.entries) {
      if (entry.value is Map<String, dynamic>) {
        try {
          pending[entry.key] = PendingProgressSync.fromJson(
            entry.value as Map<String, dynamic>,
          );
        } catch (e, st) {
          AppLogger.error('loadPendingProgressSync', e, st);
        }
      }
    }
    return pending;
  }

  void _savePendingProgressSyncToLocal() {
    final pendingJson = <String, Map<String, dynamic>>{};
    for (final entry in _pendingProgressSync.entries) {
      pendingJson[entry.key] = entry.value.toJson();
    }
    StorageService.instance.savePendingProgressSync(pendingJson);
  }

  void _removePendingProgressSyncKeys(
    Iterable<String> keys, {
    String reason = '',
  }) {
    final uniqueKeys = keys.toSet();
    if (uniqueKeys.isEmpty) return;

    int removed = 0;
    for (final key in uniqueKeys) {
      if (_pendingProgressSync.remove(key) != null) {
        removed++;
      }
    }

    if (removed == 0) return;

    debugPrint(
      '🧹 [pendingProgressSync] Cleared $removed entries${reason.isNotEmpty ? " ($reason)" : ""}',
    );
    _savePendingProgressSyncToLocal();
  }

  void markPendingProgressSync({
    required String langKey,
    required List<UserWordsWithUpload> words,
  }) {
    if (words.isEmpty) return;

    for (final word in words) {
      _pendingProgressSync[ProgressMergeHelper.pendingKey(langKey, word.wordId)] =
          PendingProgressSync(
        langKey: langKey,
        wordId: word.wordId,
        state: word.currentLearningState,
        // `.toUtc()` normalizes regardless of whether the server string
        // carries a "Z" suffix. Without it, timeouts round-trip through
        // `toIso8601String()` in a mix of local and UTC formats, breaking
        // the backend's timeout-based repeat scheduling on users whose
        // device tz ≠ server tz.
        timeout: DateTime.parse(word.timeout).toUtc(),
        writeTime: DateTime.parse(word.writeTime).toUtc(),
        errorInGames: List<String>.from(word.errorInGames),
      );
    }

    debugPrint(
      '🕓 [pendingProgressSync] Marked ${words.length} pending entries for $langKey',
    );
    _savePendingProgressSyncToLocal();
  }

  bool _isFetching = false;
  bool _isRetryingPending = false;

  /// Отправляет все pending-изменения прогресса на сервер.
  /// Вызывается при запуске приложения и когда появляется интернет.
  /// Слова, сыгранные оффлайн, синхронизируются автоматически.
  Future<void> retryPendingProgressSync() async {
    if (_isRetryingPending) return;
    if (_pendingProgressSync.isEmpty) return;

    _isRetryingPending = true;
    try {
      // Build upload list from pending (group by langKey not needed — server accepts mixed)
      final uploads = <UserWordsWithUpload>[];
      for (final pending in _pendingProgressSync.values) {
        // Find categoryId from local progress
        final words = state.dirs[pending.langKey] ?? [];
        final wp = words.where((w) => w.wordId == pending.wordId).firstOrNull;
        final categoryId = wp?.categoryId ?? 0;
        if (categoryId == 0) continue; // Skip if no valid category

        uploads.add(UserWordsWithUpload(
          categoryId: categoryId,
          wordId: pending.wordId,
          currentLearningState: pending.state,
          isFirstSubmitIsLearning: false,
          learningLanguage: pending.langKey,
          timeout: pending.timeout.toIso8601String(),
          errorInGames: pending.errorInGames,
          writeTime: pending.writeTime.toIso8601String(),
          wordOriginal: wp?.original ?? '',
          wordTranslate: wp?.translate ?? '',
        ));
      }

      if (uploads.isEmpty) {
        debugPrint('⏭️ [retryPending] No valid uploads to retry');
        return;
      }

      debugPrint('🔁 [retryPending] Retrying ${uploads.length} pending uploads...');
      try {
        final repo = RememberNewWordsRepository(baseUrl: ApiConstants.baseUrl);
        await repo.syncProgress(words: uploads);
        debugPrint('✅ [retryPending] Successfully synced ${uploads.length} pending uploads');
        // Don't clear pending here — let fetchProgressFromBackend verify via merge
        // The merge will clear entries where backend caught up.
        await Future.delayed(const Duration(seconds: 2));
        await fetchProgressFromBackend();
      } catch (e) {
        debugPrint('⚠️ [retryPending] Failed: $e — will retry later');
      }
    } finally {
      _isRetryingPending = false;
    }
  }

  /// Загружает прогресс слов с бэкенда и обновляет state.
  /// Вызывается при открытии главной страницы.
  Future<void> fetchProgressFromBackend() async {
    // Prevent duplicate parallel calls
    if (_isFetching) {
      debugPrint(
        '⚠️ [fetchProgress] Already fetching, skipping duplicate call',
      );
      return;
    }
    _isFetching = true;
    try {
      final repo = RememberNewWordsRepository(baseUrl: ApiConstants.baseUrl);
      final data = await repo.getUserProgressWords();

      if (data == null) {
        debugPrint('⚠️ [fetchProgress] No data from server');
        return;
      }

      final newDirs = <String, List<WordProgress>>{};

      // Сервер возвращает: { "RuToEn": [...], "TjToEn": [...], ... }
      for (final key in data.keys) {
        final value = data[key];
        if (value is List) {
          // Debug: show raw JSON keys of first word to verify field names
          if (value.isNotEmpty && value.first is Map) {
            final first = value.first as Map;
            debugPrint('🔑 [$key] First word raw keys: ${first.keys.toList()}');
            debugPrint('🔑 [$key] First word raw data: $first');
          }
          final words = <WordProgress>[];
          for (final item in value) {
            if (item is Map<String, dynamic>) {
              try {
                final wp = WordProgress.fromJson(item);
                if (words.length < 2) {
                  debugPrint(
                    '📝 [$key] Parsed word: original="${wp.original}" translate="${wp.translate}" state=${wp.state}',
                  );
                }
                // Debug: track specific repeat words
                const debugWordIds = {450399, 450396, 450404, 450405, 450393, 450373, 450375, 450367, 450369, 130117};
                if (debugWordIds.contains(wp.wordId)) {
                  debugPrint(
                    '🎯 [BACKEND] word=${wp.wordId}: state=${wp.state}, timeout=${wp.timeout}',
                  );
                }
                words.add(wp);
              } catch (e) {
                debugPrint('⚠️ [fetchProgress] Error parsing word: $e');
              }
            }
          }
          if (words.isNotEmpty) {
            newDirs[key] = words;
          }
        }
      }

      debugPrint(
        '✅ [fetchProgress] Loaded ${newDirs.keys.toList()} from backend',
      );
      for (final entry in newDirs.entries) {
        debugPrint('   📚 ${entry.key}: ${entry.value.length} words');
      }

      // ── Merge with local optimistic updates ──
      // When user exits result page, animation_button calls fetchProgressFromBackend()
      // which may run BEFORE syncProgress completes. Backend returns OLD data that
      // would overwrite optimistic updates. Fix: keep local word state if its
      // timeout is in the future (set by optimistic update), meaning a recent
      // session result hasn't been synced to backend yet.
      final now = DateTime.now();
      final stalePendingKeys = _pendingProgressSync.entries
          .where((entry) => !ProgressMergeHelper.isPendingFresh(entry.value, now))
          .map((entry) => entry.key)
          .toList();
      _removePendingProgressSyncKeys(
        stalePendingKeys,
        reason: 'expired before merge',
      );
      for (final entry in newDirs.entries) {
        final langKey = entry.key;
        final backendWords = entry.value;
        final localWords = state.dirs[langKey] ?? [];

        // Build lookup of local words by ID
        final localMap = <int, WordProgress>{};
        for (final w in localWords) {
          localMap[w.wordId] = w;
        }

        // For each backend word, check if local version has a newer timeout
        for (var i = 0; i < backendWords.length; i++) {
          final bw = backendWords[i];
          final pendingKey = ProgressMergeHelper.pendingKey(langKey, bw.wordId);
          final pending = _pendingProgressSync[pendingKey];
          final lw = localMap[bw.wordId];
          if (lw == null) {
            if (pending != null &&
                ProgressMergeHelper.backendMatchesPending(bw, pending)) {
              _removePendingProgressSyncKeys(
                [pendingKey],
                reason: 'backend caught up without local cache',
              );
            }
            continue;
          }

          // Debug: log all words where local differs from backend
          if (lw.state != bw.state || lw.timeout != bw.timeout) {
            debugPrint(
              '🔍 [merge] word=${bw.wordId}: local(state=${lw.state}, timeout=${lw.timeout}) '
              'vs backend(state=${bw.state}, timeout=${bw.timeout})',
            );
          }

          // RULE 1: Never downgrade from state=4 (fully learned)
          // If backend says learned, keep backend version always.
          //
          // Without a pending entry we normally trust backend, but there's
          // a race: a successful sync clears the pending marker while the
          // backend's read replica can still serve the pre-sync value for
          // a few seconds. If we blindly trusted backend here, the user's
          // freshly-advanced state (e.g. 2→3 after a clean repeat session)
          // would flip back to 2 and the word would re-enter the repeat
          // pool — exactly the "repeated 3× without mistakes but word keeps
          // coming back" symptom. So we hold onto a strictly-newer local
          // value (higher state AND later timeout) until the backend catches
          // up.
          if (pending == null) {
            // Keep local when local is "not worse": state is at least as high
            // AND timeout is strictly later. This covers:
            //   - state=3, timeout later than backend (already-learned advance)
            //   - state=-1, timeout later than backend (error-word whose next
            //     due-date was extended locally; backend still serves pre-sync
            //     value, so its older timeout would wrongly push the word
            //     back into the repeat queue).
            // If local state is strictly lower than backend we always trust
            // backend — never downgrade from a higher learned state.
            if (lw.state >= bw.state &&
                lw.timeout.isAfter(bw.timeout)) {
              backendWords[i] = ProgressMergeHelper.copyWordProgress(lw);
              debugPrint(
                '🔒 [fetchProgress] Keeping newer local state for word=${bw.wordId}: '
                'local(state=${lw.state}, timeout=${lw.timeout}) >= '
                'backend(state=${bw.state}, timeout=${bw.timeout})',
              );
            }
            continue;
          }

          // RULE 2: If local has a timeout in the future AND state differs from
          // backend → local was updated by an optimistic game result.
          // Keep local version to prevent stale backend data from overwriting
          // our recent game results. This works for BOTH:
          //  • Positive upgrades: state -1→1 (error word answered correctly)
          //  • Error downgrades: state -1→-2 (error word answered wrong again)
          // We DON'T compare timeouts because after sync, backend may have
          // exactly the same timeout as local (it accepted our data).
          if (ProgressMergeHelper.backendMatchesPending(bw, pending)) {
            _removePendingProgressSyncKeys(
              [pendingKey],
              reason: 'backend caught up',
            );
            debugPrint(
              '✅ [fetchProgress] Backend caught up for word=${bw.wordId}: '
              'state=${bw.state}, timeout=${bw.timeout}',
            );
            continue;
          }

          if (ProgressMergeHelper.shouldKeepLocalPendingState(
            backendWord: bw,
            pending: pending,
            now: now,
          )) {
            backendWords[i] = ProgressMergeHelper.copyWordProgress(lw);
            debugPrint(
              '🔒 [fetchProgress] Keeping tracked local pending state for word=${bw.wordId}: '
              'state=${lw.state}, timeout=${lw.timeout} (backend had state=${bw.state}, timeout=${bw.timeout})',
            );
            continue;
          }

          _removePendingProgressSyncKeys(
            [pendingKey],
            reason: 'backend newer or pending expired',
          );
          debugPrint(
            '🌐 [fetchProgress] Trusting backend for word=${bw.wordId}: '
            'pending local state is stale or backend is newer',
          );
        }
      }

      // ── Set state immediately so UI shows counts right away ──
      state = ProgressFile(
        dirs: newDirs,
        selectedIds: state.selectedIds,
        achievements: state.achievements,
      );

      // ── Enrich words with text from local category database ──
      // API may return WordOriginal/WordTranslate, but not always.
      // Local course files serve as a fallback; missing courses are auto-downloaded.
      await _enrichWordsWithText(newDirs);

      // Update state again with enriched data
      state = ProgressFile(
        dirs: newDirs,
        selectedIds: state.selectedIds,
        achievements: state.achievements,
      );

      // Persist merged+enriched data to local storage (like Unity's PlayerPrefs)
      _saveProgressToLocal();

      // One-time repair: fix word states corrupted by whitespace comparison bug
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('whitespace_repair_done') ?? false)) {
        final repaired = await repairCorruptedStates();
        if (repaired > 0) {
          debugPrint('🔧 [fetchProgress] Repaired $repaired corrupted word states');
        } else {
          // No words needed repair — mark as done anyway
          await prefs.setBool('whitespace_repair_done', true);
        }
      }
    } catch (e, st) {
      AppLogger.error('fetchProgress', e, st);
    } finally {
      _isFetching = false;
      // Mark fetch attempt complete (success or failure) so repeatStateProvider
      // knows it's safe to compute needsRepeat from current dirs.
      ref.read(progressFetchedProvider.notifier).markFetched();
    }
  }

  /// Enrich WordProgress items with text data from local course files.
  /// The progress API only returns WordId + state; we look up original/translate
  /// from CategoryDbHelper (local JSON files downloaded with the course bundle).
  /// Also enriches categoryName from CategoriesRepository.
  Future<void> _enrichWordsWithText(
    Map<String, List<WordProgress>> dirs,
  ) async {
    // 1. Collect all unique category IDs across all dirs
    final primaryCategoryIds = <int>{}; // IDs from words — download OK
    bool hasZeroCategoryWords = false;
    for (final words in dirs.values) {
      for (final w in words) {
        if (w.categoryId > 0) {
          primaryCategoryIds.add(w.categoryId);
        } else {
          hasZeroCategoryWords = true;
        }
      }
    }

    // 2. Load categories from API (names for display)
    final categoryNameMap = <int, String>{};
    final reverseLookupCategoryIds = <int>{}; // For categoryId=0 — local only
    try {
      final repo = CategoriesRepository();
      final categories = await repo.getCategories();
      final locale = ref.read(localeProvider);
      final lang = normalizeCategoryLanguageCode(locale.languageCode);
      for (final cat in categories) {
        // Use getLocalizedName which correctly maps 'tg'/'ru'/'en' keys
        categoryNameMap[cat.id] = cat.getLocalizedName(lang);
      }
      // If some words have categoryId=0, collect ALL category IDs for local-only lookup
      if (hasZeroCategoryWords) {
        for (final cat in categories) {
          if (!primaryCategoryIds.contains(cat.id)) {
            reverseLookupCategoryIds.add(cat.id);
          }
        }
      }
      debugPrint(
        '📖 [enrichWords] Loaded ${categoryNameMap.length} category names',
      );
    } catch (e) {
      debugPrint('⚠️ [enrichWords] Failed to load categories: $e');
    }

    if (primaryCategoryIds.isEmpty && reverseLookupCategoryIds.isEmpty) {
      debugPrint('⚠️ [enrichWords] No category IDs to enrich');
      return;
    }

    // 3. Load words from each category and build wordId → Word lookup
    //    Also build wordId → categoryId reverse map for categoryId=0 fix
    final wordLookup = <int, Word>{};
    final wordToCategoryMap = <int, int>{}; // wordId → categoryId

    // 3a. Primary categories — LOCAL ONLY (no background downloading)
    //     Categories are downloaded explicitly via DownloadDialog or RepeatDownloadDialog
    for (final catId in primaryCategoryIds) {
      try {
        final courseWords = await CategoryDbHelper.getWordsForCategory(catId);

        for (final w in courseWords) {
          wordLookup[w.id] = w;
          wordToCategoryMap[w.id] = catId;
        }
        if (courseWords.isNotEmpty) {
          debugPrint(
            '📖 [enrichWords] Category $catId: loaded ${courseWords.length} words for lookup',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [enrichWords] Failed to load category $catId: $e');
      }
    }

    // 3b. Reverse lookup categories — LOCAL ONLY (no downloading)
    //     These words have unknown categories, so we search locally available ones
    if (hasZeroCategoryWords) {
      // Collect wordIds that still haven't been found
      final zeroWordIds = <int>{};
      for (final words in dirs.values) {
        for (final w in words) {
          if (w.categoryId == 0 && !wordLookup.containsKey(w.wordId)) {
            zeroWordIds.add(w.wordId);
          }
        }
      }

      if (zeroWordIds.isNotEmpty) {
        debugPrint(
          '🔍 [enrichWords] ${zeroWordIds.length} words with categoryId=0 need reverse lookup: $zeroWordIds',
        );

        for (final catId in reverseLookupCategoryIds) {
          if (zeroWordIds.isEmpty) break; // All found

          try {
            // Only check locally available categories — NO downloading
            final courseWords = await CategoryDbHelper.getWordsForCategory(
              catId,
            );
            if (courseWords.isEmpty) continue;

            for (final w in courseWords) {
              if (zeroWordIds.contains(w.id)) {
                wordLookup[w.id] = w;
                wordToCategoryMap[w.id] = catId;
                zeroWordIds.remove(w.id);
                debugPrint(
                  '✅ [enrichWords] Found word ${w.id} ("${w.word}") in category $catId via reverse lookup',
                );
              }
            }
            debugPrint(
              '📖 [enrichWords] Category $catId (reverse lookup): ${courseWords.length} words, ${zeroWordIds.length} still missing',
            );
          } catch (e) {
            debugPrint('⚠️ [enrichWords] Failed to load category $catId: $e');
          }
        }
      }
    }

    // 4. Fill in text fields on each WordProgress
    int enriched = 0;
    int missing = 0;
    int catFixed = 0;
    final cacheEntries = <WordTextEntry>[]; // Collect for batch cache save
    final missingWordIds = <int>[]; // Words not found in course ZIPs

    for (final words in dirs.values) {
      for (final wp in words) {
        if (wp.categoryId == 0 && wordToCategoryMap.containsKey(wp.wordId)) {
          wp.categoryId = wordToCategoryMap[wp.wordId]!;
          catFixed++;
        }

        if (categoryNameMap.containsKey(wp.categoryId)) {
          wp.categoryName = categoryNameMap[wp.categoryId]!;
        }
        // Enrich word text — only fill empty fields (server may already provide text)
        final courseWord = wordLookup[wp.wordId];
        if (courseWord != null) {
          if (wp.original.isEmpty) wp.original = courseWord.word;
          if (wp.translate.isEmpty) wp.translate = courseWord.translation;
          if (wp.transcription.isEmpty) {
            wp.transcription = courseWord.transcription;
          }
          enriched++;
          // Save to cache for future lookups (keyed by server wordId)
          cacheEntries.add(
            WordTextEntry(
              wordId: wp.wordId,
              word: wp.original,
              translation: wp.translate,
              transcription: wp.transcription,
              categoryId: wp.categoryId,
            ),
          );
        } else if (wp.original.isEmpty) {
          // Course ZIP doesn't have this word — collect for cache lookup
          missingWordIds.add(wp.wordId);
          missing++;
        }
      }
    }

    // 5. Try local word text cache for missing words
    if (missingWordIds.isNotEmpty) {
      debugPrint(
        '🔍 [enrichWords] Trying local cache for ${missingWordIds.length} missing words...',
      );
      try {
        final cached = await WordTextCache.instance.getWords(missingWordIds);
        int cacheHits = 0;
        for (final words in dirs.values) {
          for (final wp in words) {
            if (wp.original.isEmpty && cached.containsKey(wp.wordId)) {
              final entry = cached[wp.wordId]!;
              wp.original = entry.word;
              wp.translate = entry.translation;
              wp.transcription = entry.transcription;
              cacheHits++;
            }
          }
        }
        debugPrint(
          '✅ [enrichWords] Cache hits: $cacheHits/${missingWordIds.length}',
        );
        missing -= cacheHits;
      } catch (e) {
        debugPrint('⚠️ [enrichWords] Cache lookup failed: $e');
      }
    }

    // 6. Batch save enriched words to local cache
    if (cacheEntries.isNotEmpty) {
      try {
        await WordTextCache.instance.cacheWords(cacheEntries);
      } catch (e) {
        debugPrint('⚠️ [enrichWords] Cache save failed: $e');
      }
    }

    debugPrint(
      '✅ [enrichWords] Enriched $enriched words, $missing not found, $catFixed categoryId=0 fixed',
    );
  }

  /* ---------- приватное сохранение ---------- */
  Future<void> _save() async {
    // Persist selectedIds to SharedPreferences
    // (like Unity's PlayerPrefs.SetString("SelectedCategory", ...))
    final ids = state.selectedIds.map((id) => id.toString()).toList();
    await StorageService.instance.setSelectedCategories(ids);
  }

  /// Update dirs (e.g. after optimistic state update or orphan removal)
  /// Creates a NEW map so Riverpod detects the state change and rebuilds
  /// Also persists to SharedPreferences (like Unity's PlayerPrefs)
  void updateDirs(Map<String, List<WordProgress>> newDirs) {
    // Create a new map with new list references so Riverpod sees a change
    final copied = <String, List<WordProgress>>{};
    for (final entry in newDirs.entries) {
      copied[entry.key] = List<WordProgress>.from(entry.value);
    }
    state = ProgressFile(
      dirs: copied,
      selectedIds: state.selectedIds,
      achievements: state.achievements,
    );
    // Persist to local storage so optimistic updates survive hot restarts
    _saveProgressToLocal();
  }

  /* ---------- выбор категорий ---------- */
  void toggleCategory(int categoryId) {
    final current = state.selectedIds.toSet();

    if (current.contains(categoryId)) {
      debugPrint("❌ Removing category $categoryId");
      current.remove(categoryId);
    } else {
      if (current.length >= 6) return;
      debugPrint("✅ Adding category $categoryId");
      current.add(categoryId);
    }

    state = ProgressFile(
      dirs: state.dirs,
      selectedIds: current.toList(),
      achievements: state.achievements,
    );

    _save();
  }

  var _kLearnWords = 'LearnWords';

  /* ---------- изучили слово ---------- */
  Future<void> addLearnedWord(WordProgress wp) async {
    final tableKey = StorageService.instance
        .getTableWords(); // e.g. "TjToEn", "RuToEn"
    final newDirs = Map<String, List<WordProgress>>.from(state.dirs);
    if (!newDirs.containsKey(tableKey)) newDirs[tableKey] = [];

    newDirs[tableKey]!.removeWhere((e) => e.wordId == wp.wordId);
    newDirs[tableKey]!.add(wp..state = 5);

    // Обновляем стейт чтобы работал иммутабельно (или частично)
    state = state.copyWith(dirs: newDirs);

    // Achievements update logic...
    _incAch('LearnWords');
    await _save();
  }

  /* начисление монет */
  Future<void> addCoins(int n) async {
    final ach = _ensureAch(_kLearnWords);
    ach.value += n;
    // Нужно обновить state.achievements, если они иммутабельны.
    // Если Achievements это объекты-ссылки, то state обновлять не обязательно для изменения значения,
    // но для уведомления UI нужно:
    state = state.copyWith(); // trigger rebuild
    await _save();
  }

  /* геттер */
  int get learnedCoins => state.achievements
      .firstWhere(
        (e) => e.key == _kLearnWords,
        orElse: () => Achievement(_kLearnWords, 0),
      )
      .value;

  /* ---------- ежедневный бонус ---------- */
  Future<void> addDailyActive() async {
    _incAch('DailyActive');
    await _save();
  }

  /* ---------- +N слов сразу ---------- */
  Future<void> addLearnedWordCount(int n) async {
    final a = _ensureAch('LearnWords');
    a.value = n;
    state = state.copyWith();
    await _save();
  }

  /* ---------- вспомогательные ---------- */
  void _incAch(String key) {
    _ensureAch(key).value++;
    state = state.copyWith();
  }

  Achievement _ensureAch(String key) {
    try {
      return state.achievements.firstWhere((e) => e.key == key);
    } catch (_) {
      final ach = Achievement(key, 0);
      final newAch = List<Achievement>.from(state.achievements)..add(ach);
      state = state.copyWith(achievements: newAch);
      return ach;
    }
  }

  /// One-time repair: fix word states corrupted by the whitespace comparison bug.
  /// Words with state <= -2 were incorrectly penalized because correct answers
  /// were marked wrong due to trailing whitespace in translations.
  /// Resets them to state=0 with timeout=now so they enter repeat normally.
  /// Returns the number of words repaired.
  Future<int> repairCorruptedStates() async {
    final langKey = StorageService.instance.getTableWords();
    final allWords = state.dirs[langKey] ?? [];
    final now = DateTime.now();
    int repaired = 0;

    final List<UserWordsWithUpload> toUpload = [];

    for (final wp in allWords) {
      // Only repair words stuck in deep negative states (likely caused by bug)
      // Normal errors only go to -1; states <= -2 indicate repeated false negatives
      if (wp.state <= -2) {
        debugPrint(
          '🔧 [repair] word=${wp.wordId} ("${wp.original}"): state ${wp.state} → 0, timeout → now',
        );
        
        wp.state = 0;
        wp.timeout = now;
        wp.errorInGames = []; // Clear error game markers too
        repaired++;
        
        toUpload.add(
          UserWordsWithUpload(
            categoryId: wp.categoryId,
            wordId: wp.wordId,
            currentLearningState: 0,
            isFirstSubmitIsLearning: false,
            learningLanguage: langKey,
            timeout: now.toIso8601String(),
            errorInGames: [],
            writeTime: now.toIso8601String(),
            wordOriginal: wp.original,
            wordTranslate: wp.translate,
          ),
        );
      }
    }

    if (repaired > 0) {
      debugPrint('🔧 [repair] Fixed $repaired words with corrupted states');
      
      // Update local state
      updateDirs(state.dirs);
      
      // Sync to server
      try {
        final repo = RememberNewWordsRepository(baseUrl: ApiConstants.baseUrl);
        await repo.syncProgress(words: toUpload);
        debugPrint('✅ [repair] Synced $repaired repaired words to server');
      } catch (e) {
        debugPrint('⚠️ [repair] Server sync failed (local state is fixed): $e');
      }
      
      // Mark as done so we don't repair again
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('whitespace_repair_done', true);
    }
    
    return repaired;
  }
}

// Extension для удобства copyWith в ProgressFile если его нет
extension ProgressFileCopy on ProgressFile {
  ProgressFile copyWith({
    Map<String, List<WordProgress>>? dirs,
    List<int>? selectedIds,
    List<Achievement>? achievements,
  }) {
    return ProgressFile(
      dirs: dirs ?? this.dirs,
      selectedIds: selectedIds ?? this.selectedIds,
      achievements: achievements ?? this.achievements,
    );
  }
}
