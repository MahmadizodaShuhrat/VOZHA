// lib/model/progress_models.dart
class WordProgress {
  int categoryId;
  String categoryName;
  final int wordId;
  String original;
  String transcription;
  String translate;
  int state; // -3..5
  DateTime timeout;
  bool firstDone;
  List<String>
  errorInGames; // games where user made errors (e.g. ["Select translation", "Memoria"])

  /// Калимае, ки истифодабаранда дар ChoseLearnKnowPage "Медонам" зада — танҳо локалӣ.
  bool isKnownLocally;

  WordProgress({
    required this.categoryId,
    this.categoryName = '',
    required this.wordId,
    this.original = '',
    this.transcription = '',
    this.translate = '',
    required this.state,
    required this.timeout,
    required this.firstDone,
    this.errorInGames = const [],
    this.isKnownLocally = false,
  });

  /// Гибкий парсер: принимает и int, и String для числовых полей,
  /// bool и String для IsFirstSubmitIsLearning.
  /// Текстовые поля (CategoryName, WordOriginal и т.д.) опциональны.
  factory WordProgress.fromJson(Map<String, dynamic> j) {
    // Универсальный парсер int: принимает int, String, null
    int parseInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    // Универсальный парсер bool
    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    // Парсим timeout с защитой от разных форматов.
    // `.toUtc()` normalizes the result regardless of whether the server
    // emitted a "Z" suffix — without it, timeouts parsed on a device
    // that isn't at UTC+0 get stored with a hidden offset and later
    // round-trip through toIso8601String() as local-time strings the
    // backend rejects / treats as different wallclocks.
    DateTime parseTimeout(dynamic v) {
      if (v == null) return DateTime.now().toUtc();
      final s = v.toString();
      try {
        return DateTime.parse(s).toUtc();
      } catch (_) {
        return DateTime.now().toUtc();
      }
    }

    return WordProgress(
      categoryId: parseInt(j['CategoryId']),
      categoryName: j['CategoryName']?.toString() ?? '',
      wordId: parseInt(j['WordId']),
      original: j['WordOriginal']?.toString() ?? '',
      transcription: j['WordTranscription']?.toString() ?? '',
      translate: j['WordTranslate']?.toString() ?? '',
      state: parseInt(j['CurrentLearningState']),
      timeout: parseTimeout(j['Timeout']),
      firstDone: parseBool(j['IsFirstSubmitIsLearning']),
      errorInGames:
          (j['ErrorInGames'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'CategoryId': categoryId.toString(),
    'CategoryName': categoryName,
    'WordId': wordId.toString(),
    'WordOriginal': original,
    'WordTranscription': transcription,
    'WordTranslate': translate,
    'CurrentLearningState': state.toString(),
    'Timeout': timeout.toIso8601String(),
    'IsFirstSubmitIsLearning': firstDone ? 'True' : 'False',
    'ErrorInGames': errorInGames,
  };
}

class Achievement {
  String key;
  int value;
  Achievement(this.key, this.value);
  factory Achievement.fromJson(Map<String, dynamic> j) =>
      Achievement(j['Key'], j['Value']);
  Map<String, dynamic> toJson() => {'Key': key, 'Value': value};
}

class ProgressFile {
  Map<String, List<WordProgress>> dirs;
  List<int> selectedIds;
  List<Achievement> achievements;

  ProgressFile({
    required this.dirs,
    required this.selectedIds,
    required this.achievements,
  });

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

  factory ProgressFile.empty() => ProgressFile(
    dirs: {'TjToEn': [], 'TjToRu': [], 'RuToEn': [], 'RuToTj': []},
    selectedIds: [1, 2, 19, 20, 23, 24], // 🔹 default 6 категория
    achievements: [],
  );

  factory ProgressFile.fromJson(Map<String, dynamic> j) {
    // Сохтани харитаи калимаҳо
    Map<String, List<WordProgress>> m = {};
    for (var k in ['TjToEn', 'TjToRu', 'RuToEn', 'RuToTj']) {
      m[k] = (j[k] as List? ?? [])
          .map((e) => WordProgress.fromJson(e))
          .toList();
    }

    // Гирифтани selectedIds бо parse дуруст
    final selectedIds = (j['SelectedCategory'] as List? ?? [])
        .map((e) {
          final raw = e['Id'];
          return raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
        })
        .where((id) => id > 0) // бартараф кардани 0 ё нодуруст
        .toList();

    // Гирифтани achievements
    final achievements = (j['Achievements'] as List? ?? [])
        .map((e) => Achievement.fromJson(e))
        .toList();

    return ProgressFile(
      dirs: m,
      selectedIds: selectedIds,
      achievements: achievements,
    );
  }

  Map<String, dynamic> toJson() => {
    ...dirs.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
    'SelectedCategory': selectedIds.map((id) => {'Id': id}).toList(),
    'Achievements': achievements.map((e) => e.toJson()).toList(),
  };

  int get totalCoins {
    final learn = achievements
        .firstWhere(
          (a) => a.key == 'LearnWords',
          orElse: () => Achievement('LearnWords', 0),
        )
        .value;

    final daily = achievements
        .firstWhere(
          (a) => a.key == 'DailyActive',
          orElse: () => Achievement('DailyActive', 0),
        )
        .value;

    return learn + daily;
  }
}
