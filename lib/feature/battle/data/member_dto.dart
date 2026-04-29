import 'package:vozhaomuz/core/constants/app_constants.dart';

/// Модель участника комнаты — точное соответствие серверному JSON.
class MemberDto {
  static const String _baseUrl = ApiConstants.baseUrl;

  final int id;
  final String name;
  final String? avatarUrl;
  final int answered;
  final int correctAnswers;
  final int score;
  final bool isAdmin;
  final int wonCoins;

  /// Бозигар аз бозӣ баромад (мошини вайроншуда нишон дода мешавад).
  final bool hasLeft;

  /// Серверная нумерация места среди реальных доигравших людей: 1, 2,
  /// 3, … Боты и ушедшие получают `null` — UI рендерит их без медали.
  /// Клиент использует это значение напрямую, без собственной
  /// сортировки, чтобы ranking был согласован между устройствами.
  final int? place;

  /// Время окончания теста этим игроком (UTC). Устанавливается на
  /// сервере на последнем ответе / `finish_test` / истечении таймера.
  /// Клиент показывает `finish_time - start_time` в таблице лидеров.
  final DateTime? finishTime;

  const MemberDto({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.answered = 0,
    this.correctAnswers = 0,
    this.score = 0,
    this.isAdmin = false,
    this.wonCoins = 0,
    this.hasLeft = false,
    this.place,
    this.finishTime,
  });

  /// Бот = отрицательный ID
  bool get isBot => id < 0;

  /// Полный URL аватарки (сервер может вернуть относительный путь).
  String? get fullAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (avatarUrl!.startsWith('http')) return avatarUrl;
    return '$_baseUrl$avatarUrl';
  }

  /// Нусхаи нав бо тағйироти муайян (барои hasLeft истифода мешавад).
  MemberDto copyWith({
    int? id,
    String? name,
    String? avatarUrl,
    int? answered,
    int? correctAnswers,
    int? score,
    bool? isAdmin,
    int? wonCoins,
    bool? hasLeft,
    int? place,
    DateTime? finishTime,
  }) {
    return MemberDto(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      answered: answered ?? this.answered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      score: score ?? this.score,
      isAdmin: isAdmin ?? this.isAdmin,
      wonCoins: wonCoins ?? this.wonCoins,
      hasLeft: hasLeft ?? this.hasLeft,
      place: place ?? this.place,
      finishTime: finishTime ?? this.finishTime,
    );
  }

  factory MemberDto.fromJson(Map<String, dynamic> json) {
    DateTime? parseFinishTime(dynamic raw) {
      if (raw is! String || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw).toUtc();
      } catch (_) {
        return null;
      }
    }

    return MemberDto(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      answered: json['answered'] as int? ?? 0,
      correctAnswers: json['correct_answers'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      isAdmin: json['is_admin'] as bool? ?? false,
      wonCoins: json['won_coins'] as int? ?? 0,
      hasLeft: json['has_left'] as bool? ?? false,
      place: json['place'] as int?,
      finishTime: parseFinishTime(json['finish_time']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar_url': avatarUrl,
    'answered': answered,
    'correct_answers': correctAnswers,
    'score': score,
    'is_admin': isAdmin,
    'won_coins': wonCoins,
    if (place != null) 'place': place,
    if (finishTime != null) 'finish_time': finishTime!.toIso8601String(),
  };
}
