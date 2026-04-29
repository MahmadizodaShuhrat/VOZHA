import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:audioplayers/audioplayers.dart'
    as ap
    show
        AudioContext,
        AudioContextAndroid,
        AudioContextIOS,
        AndroidAudioFocus,
        AndroidAudioMode,
        AVAudioSessionCategory,
        AVAudioSessionOptions;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/core/utils/zip_resource_loader.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_loader.dart';

/// Static holder for current lesson directory (set by course flow)
class AudioContext {
  static String? currentLessonDir;
}

/// Обёртка: воспроизводит аудио-файл из ZIP-архива
class AudioHelper {
  // Cache directory for temp audio files
  static Directory? _cacheDir;

  /// In-memory cache: fileName → resolved absolute path on disk.
  /// Avoids expensive recursive directory walks on every play.
  static final Map<String, String> _pathCache = {};

  /// Get or create cache directory for audio files
  static Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory('${tempDir.path}/audio_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  /// Play audio from cached file or extract & cache first
  static Future<void> _playFromBytes(
    AudioPlayer player,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final cacheDir = await _getCacheDir();
      final tempFile = File('${cacheDir.path}/$fileName');
      if (!await tempFile.exists()) {
        await tempFile.writeAsBytes(bytes);
      }
      // Remember resolved path
      _pathCache[fileName] = tempFile.path;
      await player.stop();
      await player.play(DeviceFileSource(tempFile.path));
    } catch (e) {
      debugPrint('Error playing audio from bytes: $e');
    }
  }

  /// Play directly from cached file if it exists (skip ZIP extraction)
  static Future<bool> _playFromCache(
    AudioPlayer player,
    String fileName,
  ) async {
    try {
      final cacheDir = await _getCacheDir();
      // Try original filename first
      final tempFile = File('${cacheDir.path}/$fileName');
      if (await tempFile.exists()) {
        _pathCache[fileName] = tempFile.path;
        await player.stop();
        await player.play(DeviceFileSource(tempFile.path));
        return true;
      }
      // Try alternative extension (.mp3 ↔ .ogg)
      final altFileName = _alternateExtension(fileName);
      if (altFileName != null) {
        final altFile = File('${cacheDir.path}/$altFileName');
        if (await altFile.exists()) {
          _pathCache[altFileName] = altFile.path;
          await player.stop();
          await player.play(DeviceFileSource(altFile.path));
          return true;
        }
      }
    } catch (e) {
      debugPrint('Cache play error: $e');
    }
    return false;
  }

  /// Play word audio. Supports optional [categoryId] to resolve
  /// the correct course path for multi-category repeat sessions.
  /// Will try: cache → category disk files → currentLessonDir → archive ZIP
  static Future<void> playWord(
    AudioPlayer player,
    String category,
    String fileName, {
    int? categoryId,
  }) async {
    // 0. Check in-memory path cache first (instant — no I/O)
    final cachedPath = _pathCache[fileName];
    if (cachedPath != null && File(cachedPath).existsSync()) {
      try {
        await player.stop();
        await player.play(DeviceFileSource(cachedPath));
        return;
      } catch (_) {}
    }
    // Also check alternate extension in path cache
    final altName = _alternateExtension(fileName);
    if (altName != null) {
      final altPath = _pathCache[altName];
      if (altPath != null && File(altPath).existsSync()) {
        try {
          await player.stop();
          await player.play(DeviceFileSource(altPath));
          return;
        } catch (_) {}
      }
    }

    // 1. Try playing from cached temp file (fastest I/O — flat directory)
    if (await _playFromCache(player, fileName)) {
      return;
    }

    Uint8List? bytes;

    // 2. If categoryId provided, resolve course path for THIS word's category
    //    This fixes multi-category repeat sessions where currentLessonDir
    //    only points to one category.
    if (categoryId != null && categoryId > 0) {
      final catCoursePath = await CategoryResourceService.getCoursePath(
        categoryId,
      );
      if (catCoursePath != null) {
        final diskFile = await _findAudioOnDisk(catCoursePath, fileName);
        if (diskFile != null && await diskFile.exists()) {
          try {
            _pathCache[fileName] = diskFile.path;
            await player.stop();
            await player.play(DeviceFileSource(diskFile.path));
            // Cache in background for faster future access
            _cacheFileInBackground(diskFile);
            return;
          } catch (e) {
            debugPrint('⚠️ Error playing category $categoryId audio: $e');
          }
        }
        // Try ZIP in category course path
        final audioPath = 'Audios/$fileName';
        bytes = await CourseLoader.getWordAudio(catCoursePath, audioPath);
        if (bytes != null && bytes.isNotEmpty) {
          await _playFromBytes(player, bytes, fileName);
          return;
        }
        final altFileName = _alternateExtension(fileName);
        if (altFileName != null) {
          bytes = await CourseLoader.getWordAudio(
            catCoursePath,
            'Audios/$altFileName',
          );
          if (bytes != null && bytes.isNotEmpty) {
            await _playFromBytes(player, bytes, altFileName);
            return;
          }
        }
      }
    }

    // 3. Fallback: try AudioContext.currentLessonDir (single-category flow)
    final lessonDir = AudioContext.currentLessonDir;
    if (lessonDir != null) {
      final diskFile = await _findAudioOnDisk(lessonDir, fileName);
      if (diskFile != null && await diskFile.exists()) {
        try {
          _pathCache[fileName] = diskFile.path;
          await player.stop();
          await player.play(DeviceFileSource(diskFile.path));
          // Cache in background for faster future access
          _cacheFileInBackground(diskFile);
          return;
        } catch (e) {
          debugPrint('⚠️ Error playing disk audio: $e');
        }
      }

      // Try loading from course ZIP
      final audioPath = 'Audios/$fileName';
      bytes = await CourseLoader.getWordAudio(lessonDir, audioPath);
      if (bytes != null && bytes.isNotEmpty) {
        await _playFromBytes(player, bytes, fileName);
        return;
      }
      final altFileName = _alternateExtension(fileName);
      if (altFileName != null) {
        bytes = await CourseLoader.getWordAudio(
          lessonDir,
          'Audios/$altFileName',
        );
        if (bytes != null && bytes.isNotEmpty) {
          await _playFromBytes(player, bytes, altFileName);
          return;
        }
      }
    }

    // 4. Fall back to archive ZIP
    bytes = await ZipResourceLoader.load(
      category: category,
      fileName: fileName,
      type: ZipResourceType.audio,
    );

    if (bytes != null && bytes.isNotEmpty) {
      await _playFromBytes(player, bytes, fileName);
    } else {
      debugPrint(
        'Аудиофайл ёфт нашуд: $fileName (категория: $category, catId: $categoryId, lessonDir: $lessonDir)',
      );
    }
  }

  /// Copy disk file to cache in background (non-blocking optimization)
  static void _cacheFileInBackground(File diskFile) {
    Future(() async {
      try {
        final cacheDir = await _getCacheDir();
        final actualName = diskFile.path.split('/').last.split('\\').last;
        final cachedFile = File('${cacheDir.path}/$actualName');
        if (!await cachedFile.exists() && await diskFile.exists()) {
          await diskFile.copy(cachedFile.path);
        }
      } catch (_) {
        // Ignore cache errors — playback already succeeded
      }
    });
  }

  /// Get alternate audio extension: .mp3 → .ogg, .ogg → .mp3
  static String? _alternateExtension(String fileName) {
    if (fileName.endsWith('.mp3')) {
      return '${fileName.substring(0, fileName.length - 4)}.ogg';
    } else if (fileName.endsWith('.ogg')) {
      return '${fileName.substring(0, fileName.length - 4)}.mp3';
    }
    return null;
  }

  /// Recursively search for an audio file in the extracted course directory.
  /// Matches by word stem (ignoring extension) to handle .mp3/.ogg mismatch.
  static Future<File?> _findAudioOnDisk(
    String courseDir,
    String fileName,
  ) async {
    try {
      final dir = Directory(courseDir);
      if (!await dir.exists()) return null;

      // Extract word stem without extension for flexible matching
      final dotIndex = fileName.lastIndexOf('.');
      final stem = dotIndex > 0
          ? fileName.substring(0, dotIndex).toLowerCase()
          : fileName.toLowerCase();

      // Fast path: check known subdirectory structure first (Audios/)
      // This avoids expensive recursive walk in the common case.
      for (final subDir in ['Audios', 'audios', '']) {
        final base = subDir.isEmpty ? courseDir : '$courseDir/$subDir';
        for (final ext in ['.mp3', '.ogg']) {
          final candidate = File('$base/$stem$ext');
          if (await candidate.exists()) {
            return candidate;
          }
        }
        // Also try original filename as-is
        final exact = File('$base/$fileName');
        if (await exact.exists()) {
          return exact;
        }
      }

      // Slow fallback: recursive search (only if fast path misses)
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          final basename = entity.path.split('/').last.split('\\').last;
          final baseLower = basename.toLowerCase();
          if (baseLower == fileName.toLowerCase() ||
              baseLower == '$stem.ogg' ||
              baseLower == '$stem.mp3') {
            return entity;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка поиска аудио на диске: $e');
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────
  // SFX: Low-latency sound effects that DON'T steal audio focus.
  // Using PlayerMode.lowLatency + AndroidAudioFocus.none ensures
  // SFX plays alongside word pronunciation without interruption.
  // ──────────────────────────────────────────────────────────────

  static final AudioPlayer _sfxCorrect = AudioPlayer(playerId: 'sfx_correct');
  static final AudioPlayer _sfxWrong = AudioPlayer(playerId: 'sfx_wrong');
  static final AudioPlayer _sfxClick = AudioPlayer(playerId: 'sfx_click');
  static final AudioPlayer _sfxRemove = AudioPlayer(playerId: 'sfx_remove');

  static bool _sfxLoaded = false;

  /// Call once at game start (e.g. in GamePage.initState).
  /// Primes low-latency buffers so first playback is instant.
  static Future<void> preloadSfx() async {
    if (_sfxLoaded) return;
    try {
      // Configure all SFX players: no audio focus, low latency
      for (final p in [_sfxCorrect, _sfxWrong, _sfxClick, _sfxRemove]) {
        await p.setAudioContext(
          ap.AudioContext(
            android: ap.AudioContextAndroid(
              isSpeakerphoneOn: false,
              audioFocus: ap.AndroidAudioFocus.none, // ← don't steal focus!
              audioMode: ap.AndroidAudioMode.normal,
            ),
            iOS: ap.AudioContextIOS(
              category: ap.AVAudioSessionCategory.playback,
              options: {ap.AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(1.0);
      }
      // Pre-load sources so first play is fast
      await _sfxCorrect.setSource(AssetSource('sounds/Accepted.mp3'));
      await _sfxWrong.setSource(AssetSource('sounds/WrongStatus.mp3'));
      await _sfxClick.setSource(AssetSource('sounds/ClickLetter.mp3'));
      await _sfxRemove.setSource(AssetSource('sounds/RemoveLetter.mp3'));
      _sfxLoaded = true;
      debugPrint('🔊 SFX preloaded (lowLatency, no audioFocus)');
    } catch (e) {
      debugPrint('⚠️ SFX preload error: $e');
    }
  }

  /// Play correct answer sound.
  /// If [awaitCompletion] is true, awaits until the clip finishes playing —
  /// use this when the next audio (e.g. a word) must not overlap the SFX.
  /// Cap the wait at ~500ms so callers never feel "stuck" after tapping an
  /// answer; the Accepted.mp3 clip is ~400ms so this matches the real audio
  /// length without burning user-perceived latency.
  static Future<void> playCorrect({bool awaitCompletion = false}) async {
    try {
      await _sfxCorrect.stop();
      await _sfxCorrect.play(AssetSource('sounds/Accepted.mp3'));
      if (awaitCompletion) {
        try {
          await _sfxCorrect.onPlayerComplete.first.timeout(
            const Duration(milliseconds: 500),
          );
        } on TimeoutException {
          // SFX didn't complete in 500ms — continue without blocking next audio
        }
      }
    } catch (e) {
      debugPrint('SFX correct error: $e');
    }
  }

  /// Play wrong answer sound.
  /// If [awaitCompletion] is true, awaits until the clip finishes playing —
  /// use this when the next audio (e.g. a word) must not overlap the SFX.
  /// Same 500ms cap as [playCorrect] so the post-answer UX stays snappy.
  static Future<void> playWrong({bool awaitCompletion = false}) async {
    try {
      await _sfxWrong.stop();
      await _sfxWrong.play(AssetSource('sounds/WrongStatus.mp3'));
      if (awaitCompletion) {
        try {
          await _sfxWrong.onPlayerComplete.first.timeout(
            const Duration(milliseconds: 500),
          );
        } on TimeoutException {
          // SFX didn't complete in 500ms — continue without blocking next audio
        }
      }
    } catch (e) {
      debugPrint('SFX wrong error: $e');
    }
  }

  /// Play key click sound (keyboard game)
  static Future<void> playClick() async {
    try {
      await _sfxClick.stop();
      await _sfxClick.play(AssetSource('sounds/ClickLetter.mp3'));
    } catch (e) {
      debugPrint('SFX click error: $e');
    }
  }

  /// Play key remove sound (keyboard game)
  static Future<void> playRemove() async {
    try {
      await _sfxRemove.stop();
      await _sfxRemove.play(AssetSource('sounds/RemoveLetter.mp3'));
    } catch (e) {
      debugPrint('SFX remove error: $e');
    }
  }

  /// Stop all SFX players — used before microphone recording to prevent
  /// speaker audio from being captured by the mic.
  static Future<void> stopSfx() async {
    try {
      await _sfxCorrect.stop();
      await _sfxWrong.stop();
      await _sfxClick.stop();
      await _sfxRemove.stop();
    } catch (e) {
      debugPrint('SFX stop error: $e');
    }
  }
}
