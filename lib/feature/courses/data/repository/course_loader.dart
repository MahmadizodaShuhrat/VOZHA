import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_models.dart';

/// Loads and parses course ZIP files
class CourseLoader {
  CourseLoader._();

  static Archive? _currentArchive;
  static String? _currentCoursePath;

  /// Load course from Flutter assets
  static Future<CourseManifest?> loadFromAssets(String assetPath) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      _currentArchive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
      _currentCoursePath = assetPath;

      // Find and parse manifest.json
      final manifestFile = _currentArchive!.files.firstWhere(
        (f) => f.name == 'manifest.json',
        orElse: () => ArchiveFile.noCompress('', 0, Uint8List(0)),
      );

      if (manifestFile.size == 0) {
        debugPrint('manifest.json not found in ZIP');
        return null;
      }

      final jsonStr = utf8.decode(manifestFile.content as Uint8List);
      return CourseManifest.fromJson(json.decode(jsonStr));
    } catch (e) {
      debugPrint('Error loading course from assets: $e');
      return null;
    }
  }

  /// Load course from a ZIP file path
  static Future<CourseManifest?> loadCourse(String zipPath) async {
    try {
      final file = File(zipPath);
      if (!await file.exists()) {
        debugPrint('Course ZIP not found: $zipPath');
        return null;
      }

      final bytes = await file.readAsBytes();
      _currentArchive = ZipDecoder().decodeBytes(bytes);
      _currentCoursePath = zipPath;

      // Find and parse manifest.json
      final manifestFile = _currentArchive!.files.firstWhere(
        (f) => f.name == 'manifest.json',
        orElse: () => ArchiveFile.noCompress('', 0, Uint8List(0)),
      );

      if (manifestFile.size == 0) {
        debugPrint('manifest.json not found in ZIP');
        return null;
      }

      final jsonStr = utf8.decode(manifestFile.content as Uint8List);
      return CourseManifest.fromJson(json.decode(jsonStr));
    } catch (e) {
      debugPrint('Error loading course: $e');
      return null;
    }
  }

  /// Load a lesson info from the course
  static Future<LessonInfo?> loadLesson(String lessonPath) async {
    if (_currentArchive == null) return null;

    try {
      final lessonFile = _currentArchive!.files.firstWhere(
        (f) => f.name == lessonPath,
        orElse: () => ArchiveFile.noCompress('', 0, Uint8List(0)),
      );

      if (lessonFile.size == 0) return null;

      final jsonStr = utf8.decode(lessonFile.content as Uint8List);
      return LessonInfo.fromJson(json.decode(jsonStr));
    } catch (e) {
      debugPrint('Error loading lesson: $e');
      return null;
    }
  }

  /// Load learning words from a lesson
  static Future<LearningWordsData?> loadLearningWords(
    String lessonDir,
    String wordsPath,
  ) async {
    if (_currentArchive == null) return null;

    try {
      final fullPath = lessonDir + wordsPath;
      debugPrint('🔍 Looking for words at: $fullPath');
      
      // Log all files in archive for debugging
      debugPrint('📁 Archive files:');
      for (final f in _currentArchive!.files.take(20)) {
        debugPrint('   - ${f.name}');
      }
      
      // Try exact match first
      var wordsFile = _currentArchive!.files.firstWhere(
        (f) => f.name == fullPath,
        orElse: () => ArchiveFile.noCompress('', 0, Uint8List(0)),
      );
      
      // If not found, try partial match (ends with wordsPath)
      if (wordsFile.size == 0) {
        debugPrint('⚠️ Exact match failed, trying partial match for: $wordsPath');
        wordsFile = _currentArchive!.files.firstWhere(
          (f) => f.name.endsWith(wordsPath) || f.name.contains('learning_words'),
          orElse: () => ArchiveFile.noCompress('', 0, Uint8List(0)),
        );
        if (wordsFile.size > 0) {
          debugPrint('✅ Found via partial match: ${wordsFile.name}');
        }
      }

      if (wordsFile.size == 0) {
        debugPrint('❌ Words file not found');
        return null;
      }

      final jsonStr = utf8.decode(wordsFile.content as Uint8List);
      final data = LearningWordsData.fromJson(json.decode(jsonStr));
      debugPrint('✅ Loaded ${data.words.length} words');
      return data;
    } catch (e) {
      debugPrint('Error loading words: $e');
      return null;
    }
  }

  /// Get audio bytes for a word from the course
  static Future<Uint8List?> getWordAudio(
    String lessonDir,
    String audioPath,
  ) async {
    if (_currentArchive == null) {
      debugPrint('⚠️ getWordAudio: _currentArchive is null! Course not loaded?');
      return null;
    }

    try {
      // audioPath is like "Audios/agree.mp3"
      // lessonDir is like "Lesson1/"
      // Full path: Lesson1/LearningWords1/Audios/agree.mp3
      final fullPath = '${lessonDir}LearningWords1/$audioPath';
      debugPrint('🔊 Looking for audio: $fullPath');
      
      final audioFile = _currentArchive!.files.firstWhere(
        (f) => f.name == fullPath,
        orElse: () => ArchiveFile.noCompress('', 0, Uint8List(0)),
      );

      if (audioFile.size == 0) {
        debugPrint('❌ Audio not found in archive: $fullPath');
        // List available audio files for debugging
        final audioFiles = _currentArchive!.files
            .where((f) => f.name.contains('.mp3'))
            .take(5)
            .map((f) => f.name)
            .toList();
        debugPrint('📁 Available audio files (first 5): $audioFiles');
        return null;
      }
      
      debugPrint('✅ Found audio: $fullPath (${audioFile.size} bytes)');
      return audioFile.content as Uint8List;
    } catch (e) {
      debugPrint('Error loading audio: $e');
      return null;
    }
  }

  /// Extract course to local directory for faster access
  static Future<String?> extractCourse(String zipPath) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final coursesDir = Directory(p.join(appDir.path, 'courses'));
      if (!await coursesDir.exists()) {
        await coursesDir.create(recursive: true);
      }

      final file = File(zipPath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final courseName = p.basenameWithoutExtension(zipPath);
      final extractDir = Directory(p.join(coursesDir.path, courseName));
      
      if (await extractDir.exists()) {
        // Already extracted
        return extractDir.path;
      }

      await extractDir.create(recursive: true);

      for (final file in archive.files) {
        final filePath = p.join(extractDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as Uint8List);
        }
      }

      return extractDir.path;
    } catch (e) {
      debugPrint('Error extracting course: $e');
      return null;
    }
  }

  /// Clear cached archive
  static void clear() {
    _currentArchive = null;
    _currentCoursePath = null;
  }
}
