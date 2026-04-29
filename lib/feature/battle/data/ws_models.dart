import 'dart:convert';
import 'member_dto.dart';

// ═══════════════════════════════════════════════════════════════
//  ЗАПРОСЫ: клиент → сервер
// ═══════════════════════════════════════════════════════════════

class CreateRoomRequest {
  final String jwtToken;
  final String gameType;
  final int questionsQuantity;
  final int questionsCategoryId;
  final List<int> questionsId;
  final int moneyCount;
  final String gameDirectionMode;
  final bool isPublic;

  const CreateRoomRequest({
    required this.jwtToken,
    this.gameType = 'multiplayer',
    required this.questionsQuantity,
    required this.questionsCategoryId,
    required this.questionsId,
    required this.moneyCount,
    required this.gameDirectionMode,
    this.isPublic = true,
  });

  String toJsonString() => jsonEncode({
    'type': 'create_room',
    'jwt_token': 'Bearer $jwtToken',
    'game_type': gameType,
    'questions_quantity': questionsQuantity,
    'questions_category_id': questionsCategoryId,
    'questions_id': questionsId,
    'money_count': moneyCount,
    'game_direction_mode': gameDirectionMode,
    'is_public': isPublic,
  });
}

class JoinRoomRequest {
  final String jwtToken;
  final String roomId;

  const JoinRoomRequest({required this.jwtToken, required this.roomId});

  String toJsonString() => jsonEncode({
    'type': 'join_to_room',
    'jwt_token': 'Bearer $jwtToken',
    'room_id': roomId,
  });
}

class CheckRoomRequest {
  final String jwtToken;
  final String roomId;

  const CheckRoomRequest({required this.jwtToken, required this.roomId});

  String toJsonString() => jsonEncode({
    'type': 'check_room',
    'jwt_token': 'Bearer $jwtToken',
    'room_id': roomId,
  });
}

class StartGameRequest {
  final String jwtToken;

  const StartGameRequest({required this.jwtToken});

  String toJsonString() =>
      jsonEncode({'type': 'start_game', 'jwt_token': 'Bearer $jwtToken'});
}

class AnsweredRequest {
  final String jwtToken;
  final bool isQuestionCorrect;
  final int score;
  final String? wordId;
  final String? selectedAnswer;
  final String? correctAnswer;
  final int? answerTimeMs;

  const AnsweredRequest({
    required this.jwtToken,
    required this.isQuestionCorrect,
    required this.score,
    this.wordId,
    this.selectedAnswer,
    this.correctAnswer,
    this.answerTimeMs,
  });

  String toJsonString() => jsonEncode({
    'type': 'answered',
    'jwt_token': 'Bearer $jwtToken',
    'is_question_correct': isQuestionCorrect,
    'score': score,
    if (wordId != null) 'word_id': wordId,
    if (selectedAnswer != null) 'selected_answer': selectedAnswer,
    if (correctAnswer != null) 'correct_answer': correctAnswer,
    if (answerTimeMs != null) 'answer_time_ms': answerTimeMs,
  });
}

class FinishTestRequest {
  final String jwtToken;

  const FinishTestRequest({required this.jwtToken});

  String toJsonString() =>
      jsonEncode({'type': 'finish_test', 'jwt_token': 'Bearer $jwtToken'});
}

class LeaveRoomRequest {
  final String jwtToken;

  const LeaveRoomRequest({required this.jwtToken});

  String toJsonString() =>
      jsonEncode({'type': 'leave_room', 'jwt_token': 'Bearer $jwtToken'});
}

// ═══════════════════════════════════════════════════════════════
//  ОТВЕТЫ: сервер → клиент
// ═══════════════════════════════════════════════════════════════

class WsResponseData {
  final String? roomId;
  final String? gameType;
  final int? moneyCount;
  final int? questionsCategoryId;
  final int? questionsCount;
  final String? gameDirectionMode;
  final List<int>? questionsId;
  final List<MemberDto> members;
  final String? startTime;
  final String? endTime;

  /// Server-driven wait window before auto-starting with bots /
  /// cancelling the room. Comes in `room_created.data.wait_time_seconds`.
  /// Client uses it for the visible countdown and the safety watchdog.
  final int? waitTimeSeconds;

  /// Daily battle limit for the current user (non-premium). Attached
  /// to `daily_limit_reached.data.limit` so UI can show "Вы
  /// использовали X/X попыток".
  final int? limit;

  /// UTC timestamp when the daily battle limit resets. Attached to
  /// `daily_limit_reached.data.resets_at`. Client renders a relative
  /// countdown ("сброс через 4ч 12м").
  final String? resetsAt;

  const WsResponseData({
    this.roomId,
    this.gameType,
    this.moneyCount,
    this.questionsCategoryId,
    this.questionsCount,
    this.gameDirectionMode,
    this.questionsId,
    this.members = const [],
    this.startTime,
    this.endTime,
    this.waitTimeSeconds,
    this.limit,
    this.resetsAt,
  });

  factory WsResponseData.fromJson(Map<String, dynamic> json) {
    return WsResponseData(
      roomId: json['room_id'] as String?,
      gameType: json['game_type'] as String?,
      moneyCount: json['money_count'] as int?,
      questionsCategoryId: json['questions_category_id'] as int?,
      questionsCount: json['questions_count'] as int?,
      gameDirectionMode: json['game_direction_mode'] as String?,
      questionsId: (json['questions_id'] as List?)?.cast<int>(),
      members:
          (json['members'] as List?)
              ?.map((e) => MemberDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      startTime: (json['StartTime'] ?? json['start_time']) as String?,
      endTime: (json['EndTime'] ?? json['end_time']) as String?,
      waitTimeSeconds: json['wait_time_seconds'] as int?,
      limit: json['limit'] as int?,
      resetsAt: json['resets_at'] as String?,
    );
  }
}

class WsResponse {
  final bool? isSuccess;
  final String type;
  final String? message;
  final WsResponseData? data;
  final List<PublicRoomInfo>? rooms;

  const WsResponse({
    this.isSuccess,
    required this.type,
    this.message,
    this.data,
    this.rooms,
  });

  factory WsResponse.fromJson(Map<String, dynamic> json) {
    return WsResponse(
      isSuccess: json['is_success'] as bool?,
      type: json['type'] as String? ?? '',
      message: json['message'] as String?,
      data: json['data'] != null
          ? WsResponseData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      rooms: (json['rooms'] as List?)
          ?.map((e) => PublicRoomInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ПУБЛИЧНЫЕ КОМНАТЫ (лобби)
// ═══════════════════════════════════════════════════════════════

class PublicRoomInfo {
  final String roomId;
  final String creatorName;
  final String? creatorAvatar;
  final int categoryId;
  final int moneyCount;
  final int currentMembers;
  final int maxMembers;
  final int wordsCount;
  final String gameType;

  const PublicRoomInfo({
    required this.roomId,
    required this.creatorName,
    this.creatorAvatar,
    required this.categoryId,
    required this.moneyCount,
    required this.currentMembers,
    required this.maxMembers,
    required this.wordsCount,
    required this.gameType,
  });

  factory PublicRoomInfo.fromJson(Map<String, dynamic> json) {
    return PublicRoomInfo(
      roomId: json['room_id'] as String? ?? '',
      creatorName: json['creator_name'] as String? ?? '',
      creatorAvatar: json['creator_avatar'] as String?,
      categoryId: json['category_id'] as int? ?? 0,
      moneyCount: json['money_count'] as int? ?? 0,
      currentMembers: json['current_members'] as int? ?? 0,
      maxMembers: json['max_members'] as int? ?? 20,
      wordsCount: json['words_count'] as int? ?? 4,
      gameType: json['game_type'] as String? ?? 'multiplayer',
    );
  }
}
