import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

/// Local optimistic update that has not been fully reconciled with backend yet.
class PendingProgressSync {
  final String langKey;
  final int wordId;
  final int state;
  final DateTime timeout;
  final DateTime writeTime;
  final List<String> errorInGames;

  const PendingProgressSync({
    required this.langKey,
    required this.wordId,
    required this.state,
    required this.timeout,
    required this.writeTime,
    this.errorInGames = const [],
  });

  factory PendingProgressSync.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.tryParse(value.toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return PendingProgressSync(
      langKey: json['langKey']?.toString() ?? '',
      wordId: json['wordId'] is int
          ? json['wordId'] as int
          : int.tryParse(json['wordId']?.toString() ?? '') ?? 0,
      state: json['state'] is int
          ? json['state'] as int
          : int.tryParse(json['state']?.toString() ?? '') ?? 0,
      timeout: parseDate(json['timeout']),
      writeTime: parseDate(json['writeTime']),
      errorInGames: (json['errorInGames'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'langKey': langKey,
        'wordId': wordId,
        'state': state,
        'timeout': timeout.toIso8601String(),
        'writeTime': writeTime.toIso8601String(),
        'errorInGames': errorInGames,
      };
}

/// Pure helpers for deciding whether local optimistic progress should win
/// over backend data during a narrow sync race window.
class ProgressMergeHelper {
  /// Long hold period — keeps optimistic updates alive until server
  /// explicitly confirms them (backendMatchesPending). Previously 5 minutes,
  /// which caused repeat words to reappear if server was slow to process.
  static const Duration pendingSyncHold = Duration(days: 7);
  static const Duration timestampTolerance = Duration(seconds: 1);

  static String pendingKey(String langKey, int wordId) => '$langKey:$wordId';

  static bool sameTimeout(DateTime a, DateTime b) {
    return a.toUtc().difference(b.toUtc()).abs() <= timestampTolerance;
  }

  static bool backendMatchesPending(
    WordProgress backendWord,
    PendingProgressSync pending,
  ) {
    return backendWord.state == pending.state &&
        sameTimeout(backendWord.timeout, pending.timeout);
  }

  static bool isPendingFresh(PendingProgressSync pending, DateTime now) {
    // Safety: if writeTime is unreasonably old (e.g. device clock bug),
    // treat it as "just written now" to avoid losing progress on devices
    // with wrong system time.
    if (pending.writeTime.isBefore(DateTime(2020))) return true;
    return pending.writeTime.add(pendingSyncHold).isAfter(now);
  }

  /// Backend with a later timeout is treated as newer than our pending state.
  /// This avoids keeping stale local cache after backend has already advanced.
  static bool backendLooksNewerThanPending(
    WordProgress backendWord,
    PendingProgressSync pending,
  ) {
    if (backendWord.state == 4) return true;
    if (backendMatchesPending(backendWord, pending)) return false;
    return backendWord.timeout.isAfter(pending.timeout);
  }

  static bool shouldKeepLocalPendingState({
    required WordProgress backendWord,
    required PendingProgressSync pending,
    required DateTime now,
  }) {
    if (backendMatchesPending(backendWord, pending)) return false;
    if (!isPendingFresh(pending, now)) return false;
    if (backendLooksNewerThanPending(backendWord, pending)) return false;
    return true;
  }

  static WordProgress copyWordProgress(WordProgress source) {
    return WordProgress(
      categoryId: source.categoryId,
      categoryName: source.categoryName,
      wordId: source.wordId,
      original: source.original,
      transcription: source.transcription,
      translate: source.translate,
      state: source.state,
      timeout: source.timeout,
      firstDone: source.firstDone,
      errorInGames: List<String>.from(source.errorInGames),
      isKnownLocally: source.isKnownLocally,
    );
  }
}
