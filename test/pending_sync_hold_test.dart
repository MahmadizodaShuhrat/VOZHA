import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import 'package:vozhaomuz/feature/progress/progress_merge_helper.dart';

/// Tests for the extended pendingSyncHold window (7 days).
///
/// Previously 5 minutes — if server was slow to process a repeat result,
/// stale backend data would overwrite local optimistic update.
/// Now 7 days — keeps local state alive until backend explicitly catches up.
void main() {
  group('ProgressMergeHelper pendingSyncHold (7 days)', () {
    test('pending fresh within 7-day window', () {
      final now = DateTime(2026, 4, 13);
      final pending = PendingProgressSync(
        langKey: 'TjToEn',
        wordId: 100,
        state: 2,
        timeout: now.add(const Duration(days: 7)),
        writeTime: now.subtract(const Duration(days: 3)), // 3 days old
      );
      expect(ProgressMergeHelper.isPendingFresh(pending, now), isTrue);
    });

    test('pending stale after 7 days', () {
      final now = DateTime(2026, 4, 13);
      final pending = PendingProgressSync(
        langKey: 'TjToEn',
        wordId: 100,
        state: 2,
        timeout: now,
        writeTime: now.subtract(const Duration(days: 8)), // 8 days old
      );
      expect(ProgressMergeHelper.isPendingFresh(pending, now), isFalse);
    });

    test('keeps local state when backend is slow (TjToEn repeat bug)', () {
      // Scenario: User repeats word, state 1→2, timeout +7d.
      // Server hasn't processed yet, returns old state=1 with past timeout.
      // Local must win.
      final now = DateTime(2026, 4, 13, 14, 0);
      final pending = PendingProgressSync(
        langKey: 'TjToEn',
        wordId: 100,
        state: 2,
        timeout: now.add(const Duration(days: 7)),
        writeTime: now.subtract(const Duration(seconds: 10)),
      );
      // Backend still shows old state
      final backendWord = WordProgress(
        categoryId: 1,
        wordId: 100,
        state: 1,
        timeout: now.subtract(const Duration(days: 2)), // expired, old data
        firstDone: false,
      );

      expect(
        ProgressMergeHelper.shouldKeepLocalPendingState(
          backendWord: backendWord,
          pending: pending,
          now: now,
        ),
        isTrue,
      );
    });

    test('accepts backend when it catches up with our pending state', () {
      final now = DateTime(2026, 4, 13);
      final timeout = now.add(const Duration(days: 7));
      final pending = PendingProgressSync(
        langKey: 'TjToEn',
        wordId: 100,
        state: 2,
        timeout: timeout,
        writeTime: now.subtract(const Duration(seconds: 5)),
      );
      final backendWord = WordProgress(
        categoryId: 1,
        wordId: 100,
        state: 2,
        timeout: timeout, // matches pending
        firstDone: false,
      );

      expect(
        ProgressMergeHelper.backendMatchesPending(backendWord, pending),
        isTrue,
      );
      expect(
        ProgressMergeHelper.shouldKeepLocalPendingState(
          backendWord: backendWord,
          pending: pending,
          now: now,
        ),
        isFalse,
      );
    });

    test('accepts backend state=4 (learned) as newer even if pending lower', () {
      // If server confirms the word is fully learned, trust it
      final now = DateTime(2026, 4, 13);
      final pending = PendingProgressSync(
        langKey: 'TjToEn',
        wordId: 100,
        state: 2,
        timeout: now.add(const Duration(days: 7)),
        writeTime: now.subtract(const Duration(seconds: 5)),
      );
      final backendWord = WordProgress(
        categoryId: 1,
        wordId: 100,
        state: 4,
        timeout: now,
        firstDone: false,
      );

      expect(
        ProgressMergeHelper.shouldKeepLocalPendingState(
          backendWord: backendWord,
          pending: pending,
          now: now,
        ),
        isFalse,
      );
    });
  });
}
