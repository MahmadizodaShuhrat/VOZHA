import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Microsoft Cognitive Services Speech SDK configuration
class AzureSpeechConfig {
  /// Azure Speech subscription key — passed via --dart-define at
  /// build time. Never hardcode the real key here: it would end up in
  /// the public APK and the GitHub secret scanner will reject the
  /// commit.
  static const String subscriptionKey = String.fromEnvironment(
    'AZURE_SPEECH_KEY',
    defaultValue: '',
  );
  static const String region = String.fromEnvironment('AZURE_SPEECH_REGION', defaultValue: 'eastasia');
  static const String endpoint = 'https://$region.stt.speech.microsoft.com';
}

/// Pronunciation assessment result model (matches Unity RecognitionResult)
class PronunciationResult {
  final String? displayText;
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double pronScore;
  final List<WordAssessment> words;
  final String? errorMessage;
  final bool isSuccess;

  PronunciationResult({
    this.displayText,
    this.accuracyScore = 0,
    this.fluencyScore = 0,
    this.completenessScore = 0,
    this.pronScore = 0,
    this.words = const [],
    this.errorMessage,
    this.isSuccess = true,
  });

  factory PronunciationResult.fromJson(Map<String, dynamic> json) {
    try {
      final nBest = json['NBest'] as List?;
      if (nBest == null || nBest.isEmpty) {
        return PronunciationResult(
          displayText: json['DisplayText'] ?? '',
          isSuccess: true,
        );
      }

      final best = nBest[0] as Map<String, dynamic>;
      final wordsJson = best['Words'] as List? ?? [];

      // Azure returns scores at NBest level, not in a nested PronunciationAssessment
      // Check both locations for compatibility
      final assessment =
          best['PronunciationAssessment'] as Map<String, dynamic>? ?? {};

      // Get AccuracyScore from NBest level (where Azure puts it) or from assessment
      final accuracyScore =
          (best['AccuracyScore'] ?? assessment['AccuracyScore'] ?? 0)
              .toDouble();
      final fluencyScore =
          (best['FluencyScore'] ?? assessment['FluencyScore'] ?? 100)
              .toDouble();
      final completenessScore =
          (best['CompletenessScore'] ?? assessment['CompletenessScore'] ?? 100)
              .toDouble();

      // PronScore might not be present, calculate as average if missing
      var pronScore = (best['PronScore'] ?? assessment['PronScore'] ?? 0)
          .toDouble();
      if (pronScore == 0 && accuracyScore > 0) {
        pronScore = (accuracyScore + fluencyScore + completenessScore) / 3;
      }

      debugPrint(
        '📊 Parsed scores: accuracy=$accuracyScore, fluency=$fluencyScore, completeness=$completenessScore, pronScore=$pronScore',
      );

      return PronunciationResult(
        displayText: json['DisplayText'] ?? best['Display'] ?? '',
        accuracyScore: accuracyScore,
        fluencyScore: fluencyScore,
        completenessScore: completenessScore,
        pronScore: pronScore,
        words: wordsJson.map((w) => WordAssessment.fromJson(w)).toList(),
        isSuccess: true,
      );
    } catch (e) {
      debugPrint('❌ Error parsing pronunciation result: $e');
      return PronunciationResult(
        errorMessage: 'Failed to parse result: $e',
        isSuccess: false,
      );
    }
  }

  factory PronunciationResult.error(String message) {
    return PronunciationResult(errorMessage: message, isSuccess: false);
  }
}

class WordAssessment {
  final String word;
  final double accuracyScore;
  final List<PhonemeAssessment> phonemes;
  final List<SyllableAssessment> syllables;

  WordAssessment({
    required this.word,
    this.accuracyScore = 0,
    this.phonemes = const [],
    this.syllables = const [],
  });

  factory WordAssessment.fromJson(Map<String, dynamic> json) {
    final assessment =
        json['PronunciationAssessment'] as Map<String, dynamic>? ?? {};

    // Parse syllables with grapheme (Unity uses Syllable.Grapheme for coloring)
    final List<SyllableAssessment> syllables = [];
    final List<PhonemeAssessment> phonemes = [];
    final syllablesJson = json['Syllables'] as List? ?? [];
    for (final syl in syllablesJson) {
      final sylAssess =
          syl['PronunciationAssessment'] as Map<String, dynamic>? ?? {};
      syllables.add(
        SyllableAssessment(
          grapheme: syl['Grapheme'] ?? '',
          accuracyScore: (sylAssess['AccuracyScore'] ?? 0).toDouble(),
        ),
      );

      // Also parse phonemes for backward compatibility
      final phons = syl['Phonemes'] as List? ?? [];
      for (final p in phons) {
        final pAssess =
            p['PronunciationAssessment'] as Map<String, dynamic>? ?? {};
        phonemes.add(
          PhonemeAssessment(
            phoneme: p['Phoneme'] ?? '',
            accuracyScore: (pAssess['AccuracyScore'] ?? 0).toDouble(),
          ),
        );
      }
    }

    return WordAssessment(
      word: json['Word'] ?? '',
      accuracyScore: (assessment['AccuracyScore'] ?? 0).toDouble(),
      phonemes: phonemes,
      syllables: syllables,
    );
  }
}

/// Unity: Syllable with Grapheme (visible letters) and AccuracyScore
class SyllableAssessment {
  final String grapheme;
  final double accuracyScore;

  SyllableAssessment({required this.grapheme, this.accuracyScore = 0});
}

class PhonemeAssessment {
  final String phoneme;
  final double accuracyScore;

  PhonemeAssessment({required this.phoneme, this.accuracyScore = 0});
}

/// Speech Bridge using Microsoft Cognitive Services REST API
/// Equivalent to Unity's MicrosoftSpeechRecognition class
class SpeechBridge {
  final AudioRecorder _recorder = AudioRecorder();
  AudioRecorder get recorder => _recorder;
  bool _isInitialized = false;
  String _lang = 'en-US';
  String? _audioFilePath;

  /// Initialize the speech bridge
  Future<void> init({
    required String key,
    required String region,
    String lang = 'en-US',
  }) async {
    try {
      _lang = lang;

      // Permission is intentionally NOT requested here — that would fire
      // the OS dialog the moment the speech game opens, before our
      // explainer dialog ever runs. Callers (speech_game_page,
      // pronounce_word_game, …) gate `startRecording()` with their own
      // permission flow, which shows the explainer first.
      _isInitialized = true;
      debugPrint('✅ Speech SDK Initialized (Azure Cognitive Services)');
    } catch (e) {
      debugPrint('❌ Failed to initialize Speech SDK: $e');
      rethrow;
    }
  }

  /// Start recording audio
  Future<void> startRecording() async {
    if (!_isInitialized) {
      throw Exception('❗SpeechBridge not initialized. Call init() first.');
    }

    _hadVoiceActivity = false;

    try {
      // Get temporary directory for audio file
      final dir = await getTemporaryDirectory();
      _audioFilePath = '${dir.path}/pronunciation_recording.wav';

      // Start recording with WAV format (16kHz, mono, 16-bit)
      // record v6 API
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: _audioFilePath!,
      );

      debugPrint('🎤 Recording started: $_audioFilePath');
    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      rethrow;
    }
  }

  bool _hadVoiceActivity = false;

  /// Whether voice was detected during the last recording
  bool get hadVoiceActivity => _hadVoiceActivity;

  /// Monitor amplitude during recording for the given duration.
  /// Returns true if voice activity was detected (amplitude > threshold).
  Future<bool> monitorAmplitude(
    Duration duration, {
    double threshold = -30.0,
  }) async {
    final stopwatch = Stopwatch()..start();
    double maxAmplitude = -160.0;

    while (stopwatch.elapsed < duration) {
      try {
        final amp = await _recorder.getAmplitude();
        if (amp.current > maxAmplitude) {
          maxAmplitude = amp.current;
        }
        if (amp.current > threshold) {
          _hadVoiceActivity = true;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint(
      '🎤 Max amplitude: $maxAmplitude dB, voice detected: $_hadVoiceActivity',
    );
    return _hadVoiceActivity;
  }

  /// Stop recording and get the audio file path
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      debugPrint('🎤 Recording stopped: $path');
      return path;
    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
      return null;
    }
  }

  /// Perform pronunciation assessment on recorded audio
  /// This is equivalent to Unity's StartAnalyzeAssessPronunciation
  Future<PronunciationResult> assessPronunciation({
    required String referenceText,
    String? audioFilePath,
  }) async {
    if (!_isInitialized) {
      return PronunciationResult.error('SpeechBridge not initialized');
    }

    final filePath = audioFilePath ?? _audioFilePath;
    if (filePath == null) {
      return PronunciationResult.error('No audio file available');
    }

    try {
      // Read audio file
      final audioFile = File(filePath);
      if (!await audioFile.exists()) {
        return PronunciationResult.error('Audio file not found');
      }

      final audioBytes = await audioFile.readAsBytes();
      debugPrint(
        '📤 Sending ${audioBytes.length} bytes to Azure Speech for assessment',
      );

      // Build pronunciation assessment config (same as Unity)
      final pronunciationConfig = {
        'referenceText': referenceText,
        'gradingSystem': 'HundredMark',
        'granularity': 'Phoneme',
        'enableMiscue': true,
        'phonemeAlphabet': 'IPA',
        'enableProsodyAssessment': true,
      };

      // Encode config as Base64 for header
      final configJson = jsonEncode(pronunciationConfig);
      final configBase64 = base64Encode(utf8.encode(configJson));

      // Call Azure Speech API
      final url = Uri.parse(
        '${AzureSpeechConfig.endpoint}/speech/recognition/conversation/cognitiveservices/v1?language=$_lang',
      );

      final response = await http.post(
        url,
        headers: {
          'Ocp-Apim-Subscription-Key': AzureSpeechConfig.subscriptionKey,
          'Content-Type': 'audio/wav',
          'Accept': 'application/json',
          'Pronunciation-Assessment': configBase64,
        },
        body: audioBytes,
      );

      debugPrint('📥 Azure Speech Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        debugPrint('📊 Pronunciation Assessment Result: ${response.body}');
        return PronunciationResult.fromJson(json);
      } else {
        debugPrint(
          '❌ Azure Speech API Error: ${response.statusCode} ${response.body}',
        );
        return PronunciationResult.error('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Pronunciation assessment failed: $e');
      return PronunciationResult.error('Assessment failed: $e');
    }
  }

  /// Simple speech recognition (without pronunciation assessment)
  Future<String?> recognizeOnce() async {
    if (!_isInitialized) {
      throw Exception('❗SpeechBridge not initialized. Call init() first.');
    }

    try {
      // Start recording
      await startRecording();

      // Record for 5 seconds
      await Future.delayed(const Duration(seconds: 5));

      // Stop recording
      final audioPath = await stopRecording();
      if (audioPath == null) {
        return null;
      }

      // Read audio file
      final audioFile = File(audioPath);
      final audioBytes = await audioFile.readAsBytes();

      // Call Azure Speech API for simple recognition
      final url = Uri.parse(
        '${AzureSpeechConfig.endpoint}/speech/recognition/conversation/cognitiveservices/v1?language=$_lang',
      );

      final response = await http.post(
        url,
        headers: {
          'Ocp-Apim-Subscription-Key': AzureSpeechConfig.subscriptionKey,
          'Content-Type': 'audio/wav',
          'Accept': 'application/json',
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final displayText = json['DisplayText'] as String?;
        debugPrint('🎤 Recognized: $displayText');
        return displayText;
      } else {
        debugPrint('❌ Recognition failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Speech recognition failed: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _recorder.dispose();
    // Delete temporary audio file
    if (_audioFilePath != null) {
      try {
        File(_audioFilePath!).deleteSync();
      } catch (_) {}
    }
  }
}
