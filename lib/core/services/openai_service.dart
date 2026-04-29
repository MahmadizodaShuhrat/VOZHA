import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';

/// OpenAI API service — mirrors Unity's OpenAIServices.cs
///
/// Flow (same as Unity):
///  1. Fetch base prompt from server (english_exam_prompt.txt)
///  2. Build full prompt: base + language + story + promptAdditional + user data
///  3. POST to OpenAI /v1/responses with gpt-5-mini
///  4. Parse AIExamResult from response
class OpenAIService {
  static final OpenAIService instance = OpenAIService._();
  OpenAIService._();

  final Dio _dio = Dio();

  /// Cached base prompt (loaded once from server)
  String? _cachedBasePrompt;

  // ════════════════════════════════════════
  //  FETCH BASE PROMPT (Unity: english_exam_prompt.txt from server)
  // ════════════════════════════════════════

  /// Load the base exam prompt from the server.
  /// Unity: RestApiManager.Instance.Get("files/bundles/get-bundle/english_exam_prompt.txt")
  Future<String> fetchBasePrompt({String? accessToken}) async {
    if (_cachedBasePrompt != null && _cachedBasePrompt!.isNotEmpty) {
      return _cachedBasePrompt!;
    }

    try {
      final url =
          '${ApiConstants.baseUrl}/${OpenAIConstants.examPromptPath}${ApiConstants.resourceSecret}';
      debugPrint('🤖 Loading base prompt: $url');

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        _cachedBasePrompt = response.data.toString();
        debugPrint('✅ Base prompt loaded (${_cachedBasePrompt!.length} chars)');
        return _cachedBasePrompt!;
      }
    } catch (e) {
      debugPrint('❌ Base prompt load error: $e');
    }
    return '';
  }

  // ════════════════════════════════════════
  //  SEND AI REQUEST (Unity: OpenAIServices.SendAIRequest)
  // ════════════════════════════════════════

  /// Send text prompt to OpenAI and get response.
  /// Unity: POST https://api.openai.com/v1/responses
  ///        { model: "gpt-5-mini", input: prompt }
  Future<OpenAIResult> sendAIRequest(String prompt) async {
    final requestData = {'model': OpenAIConstants.model, 'input': prompt};

    final json = jsonEncode(requestData);
    debugPrint('🤖 OpenAI request (${prompt.length} chars)');

    try {
      final response = await _dio.post(
        '${OpenAIConstants.openAIBaseUrl}/responses',
        data: json,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${OpenAIConstants.apiKey}',
          },
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        return OpenAIResult(
          statusCode: 200,
          response: response.data is String
              ? response.data
              : jsonEncode(response.data),
        );
      }

      return OpenAIResult(
        statusCode: response.statusCode ?? -1,
        response: response.data?.toString() ?? '',
      );
    } on DioException catch (e) {
      debugPrint('❌ OpenAI error: ${e.message}');
      return OpenAIResult(
        statusCode: e.response?.statusCode ?? -1,
        response: e.response?.data?.toString() ?? e.message ?? 'Error',
      );
    }
  }

  // ════════════════════════════════════════
  //  PARSE EXAM RESULTS (Unity: AIExamResult)
  // ════════════════════════════════════════

  /// Parse the OpenAI response into a list of AIExamResult.
  /// Unity: deserialize output[].content[].text → List<AIExamResult>
  List<AIExamResult> parseExamResults(String rawResponse) {
    try {
      final responseMap = jsonDecode(rawResponse) as Map<String, dynamic>;
      final outputList = responseMap['output'] as List<dynamic>? ?? [];

      // Find the output_text content
      String? aiJson;
      for (final output in outputList) {
        final contentList = output['content'] as List<dynamic>? ?? [];
        for (final content in contentList) {
          if (content['type'] == 'output_text') {
            aiJson = content['text'] as String?;
            break;
          }
        }
        if (aiJson != null) break;
      }

      if (aiJson == null || aiJson.isEmpty) {
        debugPrint('⚠️ No output_text found');
        return [];
      }

      debugPrint('🤖 AI JSON: $aiJson');

      // Try parsing as list first (Unity tries single first, then list)
      try {
        final list = jsonDecode(aiJson) as List<dynamic>;
        return list
            .map((e) => AIExamResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Try single object
        try {
          final single = AIExamResult.fromJson(
            jsonDecode(aiJson) as Map<String, dynamic>,
          );
          return [single];
        } catch (_) {
          debugPrint('⚠️ Could not parse AI response: $aiJson');
          return [];
        }
      }
    } catch (e) {
      debugPrint('❌ Parse error: $e');
      return [];
    }
  }

  // ════════════════════════════════════════
  //  BUILD WRITE PROMPT (Unity: UIWriteWithAI.OnEnable)
  // ════════════════════════════════════════

  /// Build the full prompt for WriteWithAI, exactly like Unity:
  ///   basePrompt + "\nru\n" + "STORY:\n" + storyText + promptAdditional
  ///   + evaluation criteria + JSON([{Question, Answer}])
  Future<String> buildWritePrompt({
    required List<String> questions,
    required List<String> answers,
    String? storyText,
    String? promptAdditional,
    String languageCode = 'ru',
    String? accessToken,
  }) async {
    final basePrompt = await fetchBasePrompt(accessToken: accessToken);

    final buffer = StringBuffer();
    buffer.writeln(basePrompt);
    buffer.writeln('\n$languageCode\n');

    // Additional evaluation criteria for grammar & spelling
    buffer.writeln('''
EVALUATION CRITERIA:
When evaluating each answer, check ALL of the following:
1. CONTENT ACCURACY: Does the answer correctly match the story/context? Is the information factually correct based on the provided story?
2. GRAMMAR: Is the sentence grammatically correct? Check verb tenses, subject-verb agreement, articles, prepositions, word order.
3. SPELLING: Are all words spelled correctly? Flag any misspelled words.
4. SENTENCE STRUCTURE: Is it a complete sentence with proper punctuation?

SCORING RULES:
- Perfect answer (correct content + perfect grammar + no spelling errors) = 1.0
- Correct content but minor grammar/spelling errors = 0.7-0.9
- Correct content but major grammar errors = 0.4-0.6
- Incorrect content OR incomprehensible = 0.0-0.3

In the "mistakes" field, categorize errors like:
- "Grammar: [explanation]" for grammar errors
- "Spelling: [word] → [correct spelling]" for spelling errors
- "Content: [explanation]" for factual/content errors
If there are no mistakes, set "mistakes" to empty string "".

In the "correct_answer" field, always provide the ideal grammatically perfect answer.
''');

    buffer.writeln('STORY:');
    buffer.writeln(storyText ?? '');
    buffer.writeln();

    if (promptAdditional != null && promptAdditional.isNotEmpty) {
      buffer.writeln(promptAdditional);
    }

    // Unity: JsonConvert.SerializeObject(userAnswers)
    // where userAnswers = [{Question, Answer}]
    final userAnswers = <Map<String, String>>[];
    for (int i = 0; i < questions.length; i++) {
      userAnswers.add({
        'Question': questions[i].replaceAll('*Input...*', ''),
        'Answer': i < answers.length ? answers[i] : '',
      });
    }
    buffer.write(jsonEncode(userAnswers));

    return buffer.toString();
  }

  // ════════════════════════════════════════
  //  SEND SPEAKING AI REQUEST (Unity: SendAIRequest with AudioClip)
  // ════════════════════════════════════════

  /// Send audio file + prompt to OpenAI for speaking evaluation.
  /// Unity: OpenAIServices.Instance.SendAIRequest(prompt, Clips[i])
  /// Transcribes with Whisper, then evaluates with GPT.
  Future<OpenAIResult> sendSpeakingAIRequest(
    String prompt,
    String audioFilePath,
  ) async {
    debugPrint('🎤 OpenAI speaking request (audio: $audioFilePath)');

    try {
      final formData = FormData.fromMap({
        'model': 'whisper-1',
        'file': await MultipartFile.fromFile(
          audioFilePath,
          filename: 'recording.m4a',
        ),
        'prompt': prompt,
      });

      // Step 1: Transcribe audio
      final transcriptionResponse = await _dio.post(
        '${OpenAIConstants.openAIBaseUrl}/audio/transcriptions',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${OpenAIConstants.apiKey}'},
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (transcriptionResponse.statusCode != 200) {
        return OpenAIResult(
          statusCode: transcriptionResponse.statusCode ?? -1,
          response: transcriptionResponse.data?.toString() ?? '',
        );
      }

      final transcribedText = transcriptionResponse.data is Map
          ? (transcriptionResponse.data['text'] ?? '')
          : transcriptionResponse.data?.toString() ?? '';

      debugPrint('📝 Transcribed: $transcribedText');

      // Step 2: Send transcription + prompt for evaluation
      final evalPrompt =
          '$prompt\n\nStudent\'s spoken answer (transcribed):\n$transcribedText';

      return sendAIRequest(evalPrompt);
    } on DioException catch (e) {
      debugPrint('❌ Speaking AI error: ${e.message}');
      return OpenAIResult(
        statusCode: e.response?.statusCode ?? -1,
        response: e.response?.data?.toString() ?? e.message ?? 'Error',
      );
    }
  }

  // ════════════════════════════════════════
  //  BUILD SPEAKING PROMPT (Unity: UISpeakingWithAI.StartAnalyze)
  // ════════════════════════════════════════

  /// Build prompt for speaking evaluation.
  /// Unity: basePrompt + "\nru\n" + "STORY:\n" + storyText
  ///        + "\nQuestion in English:\n" + questionText + promptAdditional
  Future<String> buildSpeakingPrompt({
    required String questionText,
    String? storyText,
    String? promptAdditional,
    String languageCode = 'ru',
    String? accessToken,
  }) async {
    final basePrompt = await fetchBasePrompt(accessToken: accessToken);

    final buffer = StringBuffer();
    buffer.writeln(basePrompt);
    buffer.writeln('\n$languageCode\n');
    buffer.writeln('STORY:');
    buffer.writeln(storyText ?? '');
    buffer.writeln();
    buffer.writeln('Question in English:');
    buffer.writeln(questionText);

    if (promptAdditional != null && promptAdditional.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(promptAdditional);
    }

    return buffer.toString();
  }
}

// ════════════════════════════════════════
//  DATA MODELS (Unity: AIExamResult, OpenAIResponse)
// ════════════════════════════════════════

/// Raw result from the OpenAI API call
class OpenAIResult {
  final int statusCode;
  final String response;
  OpenAIResult({required this.statusCode, required this.response});
}

/// AI exam result per question (Unity: AIExamResult)
class AIExamResult {
  final String? text;
  final String? answer;
  final String? correctAnswer;
  final String? mistakes;
  final double score;

  AIExamResult({
    this.text,
    this.answer,
    this.correctAnswer,
    this.mistakes,
    this.score = 0.0,
  });

  factory AIExamResult.fromJson(Map<String, dynamic> json) {
    return AIExamResult(
      text: json['text'],
      answer: json['answer'],
      correctAnswer: json['correct_answer'],
      mistakes: json['mistakes'],
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
