import 'package:flutter_test/flutter_test.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import 'package:vozhaomuz/feature/progress/progress_merge_helper.dart';

void main() {
  group('ProgressMergeHelper', () {
    test('keeps fresh pending local state when backend looks older', () {
      final now = DateTime(2026, 3, 26, 16);
      final pending = PendingProgressSync(
        langKey: 'RuToEn',
        wordId: 100,
        state: 2,
        timeout: now.add(const Duration(days: 7)),
        writeTime: now.subtract(const Duration(seconds: 15)),
      );
      final backendWord = WordProgress(
        categoryId: 1,
        wordId: 100,
        state: 1,
        timeout: now.subtract(const Duration(minutes: 1)),
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

    test('does not keep local state when backend already caught up', () {
      final now = DateTime(2026, 3, 26, 16);
      final timeout = now.add(const Duration(days: 7));
      final pending = PendingProgressSync(
        langKey: 'RuToEn',
        wordId: 100,
        state: 2,
        timeout: timeout,
        writeTime: now.subtract(const Duration(seconds: 15)),
      );
      final backendWord = WordProgress(
        categoryId: 1,
        wordId: 100,
        state: 2,
        timeout: timeout,
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

    test('does not keep local state when backend is clearly newer', () {
      final now = DateTime(2026, 3, 26, 16);
      final pending = PendingProgressSync(
        langKey: 'RuToEn',
        wordId: 100,
        state: 2,
        timeout: now.add(const Duration(days: 7)),
        writeTime: now.subtract(const Duration(seconds: 15)),
      );
      final backendWord = WordProgress(
        categoryId: 1,
        wordId: 100,
        state: 3,
        timeout: now.add(const Duration(days: 11)),
        firstDone: false,
      );

      expect(
        ProgressMergeHelper.backendLooksNewerThanPending(backendWord, pending),
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

    test('does not keep expired pending local state', () {
      final now = DateTime(2026, 3, 26, 16);
      final pending = PendingProgressSync(
        langKey: 'RuToEn',
        wordId: 100,
        state: 2,
        timeout: now.add(const Duration(days: 7)),
        writeTime: now.subtract(
          ProgressMergeHelper.pendingSyncHold + const Duration(seconds: 1),
        ),
      );
      final backendWord = WordProgress(
        categoryId: 1,
        wordId: 100,
        state: 1,
        timeout: now.subtract(const Duration(minutes: 1)),
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
