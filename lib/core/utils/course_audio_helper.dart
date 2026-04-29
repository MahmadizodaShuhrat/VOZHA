import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_loader.dart';

/// Helper to play audio from course ZIP archive
class CourseAudioHelper {
  /// Play word audio from course ZIP
  /// lessonDir: e.g. "Lesson1/"
  /// audioPath: e.g. "Audios/agree.mp3"
  static Future<void> playWord(
    AudioPlayer player,
    String lessonDir,
    String audioPath,
  ) async {
    try {
      final bytes = await CourseLoader.getWordAudio(lessonDir, audioPath);
      
      if (bytes != null && bytes.isNotEmpty) {
        await player.play(BytesSource(bytes));
      } else {
        debugPrint('Course audio not found: $lessonDir$audioPath');
      }
    } catch (e) {
      debugPrint('Error playing course audio: $e');
    }
  }
  
  /// Play word by name (convenience method)
  /// word: the English word like "agree"
  /// lessonDir: e.g. "Lesson1/"
  static Future<void> playWordByName(
    AudioPlayer player,
    String lessonDir,
    String word,
  ) async {
    final audioPath = 'Audios/$word.mp3';
    await playWord(player, lessonDir, audioPath);
  }
}
