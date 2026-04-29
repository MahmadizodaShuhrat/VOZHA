import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/app_logger.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';

/// Сервис для управления ресурсами категорий:
/// скачивание ZIP, извлечение Course (manifest + lessons + words + sprites + audios).
class CategoryResourceService {
  static const _downloadBase =
      '${ApiConstants.baseUrl}${ApiConstants.filesResources}';
  static const _secret = ApiConstants.resourceSecret;

  /// Проверяет, существует ли скачанный курс для категории.
  /// Проверяет наличие manifest.json в папке курса.
  static Future<bool> hasResources(int categoryId) async {
    final dir = await _categoryDir(categoryId);
    debugPrint('🔍 hasResources($categoryId): checking ${dir.path}');

    // Сначала проверяем manifest.json в корне категории
    final rootManifest = File(p.join(dir.path, 'manifest.json'));
    if (rootManifest.existsSync()) {
      debugPrint('✅ hasResources($categoryId): manifest.json найден в корне');
      return true;
    }

    // Затем ищем в подпапках
    try {
      final entities = dir.listSync();
      debugPrint(
        '📂 hasResources($categoryId): ${entities.length} элементов в папке',
      );
      for (final entity in entities) {
        if (entity is Directory) {
          final manifest = File(p.join(entity.path, 'manifest.json'));
          if (manifest.existsSync()) {
            debugPrint(
              '✅ hasResources($categoryId): manifest.json найден в ${entity.path}',
            );
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ hasResources($categoryId): ошибка чтения папки: $e');
    }

    debugPrint('❌ hasResources($categoryId): manifest.json не найден');
    return false;
  }

  /// Проверяет, нужно ли обновить ресурсы категории.
  /// Возвращает true, если ресурсов нет или версия отличается от серверной.
  static Future<bool> needsUpdate(CategoryFlutterDto category) async {
    final hasRes = await hasResources(category.id);
    if (!hasRes) {
      debugPrint('🔄 needsUpdate(${category.id}): ресурсы отсутствуют');
      return true;
    }

    final localVersion = await _getLocalVersion(category.id);
    if (localVersion == null) {
      debugPrint('🔄 needsUpdate(${category.id}): нет локальной версии');
      return true;
    }

    final needsUp = localVersion != category.version;
    debugPrint(
      '🔄 needsUpdate(${category.id}): local=$localVersion, '
      'server=${category.version}, update=$needsUp',
    );
    return needsUp;
  }

  /// Читает сохранённую версию ресурсов категории.
  static Future<String?> _getLocalVersion(int categoryId) async {
    try {
      final dir = await _categoryDir(categoryId);
      final versionFile = File(p.join(dir.path, 'version.json'));
      if (!versionFile.existsSync()) return null;
      final data = jsonDecode(await versionFile.readAsString());
      return data['version']?.toString();
    } catch (e) {
      debugPrint('⚠️ _getLocalVersion($categoryId): $e');
      return null;
    }
  }

  /// Сохраняет версию скачанных ресурсов категории.
  static Future<void> _saveVersion(int categoryId, String version) async {
    final dir = await _categoryDir(categoryId);
    final versionFile = File(p.join(dir.path, 'version.json'));
    await versionFile.writeAsString(jsonEncode({'version': version}));
    debugPrint('💾 _saveVersion($categoryId): $version');
  }

  /// Возвращает путь к извлечённой папке курса.
  static Future<String?> getCoursePath(int categoryId) async {
    final dir = await _categoryDir(categoryId);
    // Ищем manifest.json в подпапках курса
    final courseDirs = dir.listSync().whereType<Directory>();
    for (final courseDir in courseDirs) {
      final manifest = File(p.join(courseDir.path, 'manifest.json'));
      if (manifest.existsSync()) return courseDir.path;
    }
    // Проверяем корень
    final rootManifest = File(p.join(dir.path, 'manifest.json'));
    if (rootManifest.existsSync()) return dir.path;
    return null;
  }

  /// Директория ресурсов для конкретной категории.
  static Future<Directory> _categoryDir(int categoryId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'Resources', '$categoryId'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Скачивает ZIP ресурс и извлекает весь курс.
  /// [onProgress] вызывается с прогрессом от 0.0 до 1.0.
  /// Возвращает путь к папке курса, или null при ошибке.
  static Future<String?> downloadAndExtract(
    CategoryFlutterDto category, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // Найти ресурс _course.zip
    final courseResource = category.resources.firstWhere(
      (r) => r.name.toLowerCase().contains('course'),
      orElse: () => category.resources.isNotEmpty
          ? category.resources.first
          : ResourceItemDto(name: '', size: 0),
    );

    if (courseResource.name.isEmpty) {
      debugPrint('❌ Нет ресурсов для категории ${category.id}');
      return null;
    }

    final url = '$_downloadBase${courseResource.name}$_secret';
    final dir = await _categoryDir(category.id);
    final zipPath = p.join(dir.path, courseResource.name);
    final tmpPath = '$zipPath.part';

    debugPrint('⏩ Скачиваем: $url');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
    ));

    // ── Retry up to 3 times on network error ──
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // ── Resume support: check if partial file exists ──
        final tmpFile = File(tmpPath);
        int existingBytes = 0;
        if (await tmpFile.exists()) {
          existingBytes = await tmpFile.length();
          debugPrint(
            '📎 Partial file found: $existingBytes bytes '
            '(attempt $attempt/$maxRetries)',
          );
        }

        // Use stream-based download with manual file append for resume
        final response = await dio.get<ResponseBody>(
          url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            headers: existingBytes > 0
                ? {'Range': 'bytes=$existingBytes-'}
                : null,
          ),
        );

        // Check if server supports Range (206 = partial, 200 = full restart)
        final statusCode = response.statusCode ?? 200;
        final bool isResume = statusCode == 206 && existingBytes > 0;

        if (!isResume && existingBytes > 0) {
          // Server doesn't support Range — delete partial and start fresh
          debugPrint(
            '⚠️ Server returned $statusCode (not 206), restarting from 0',
          );
          await tmpFile.delete();
          existingBytes = 0;
        }

        // Get total file size
        // For 206: content-length = remaining bytes, totalBytes = existing + remaining
        // For 200: content-length = total bytes
        final contentLength = int.tryParse(
          response.headers.value('content-length') ?? '',
        ) ?? -1;

        int totalBytes = -1;
        if (isResume && contentLength > 0) {
          // 206: content-range may have total, else content-length = remaining
          final contentRange = response.headers.value('content-range') ?? '';
          final slashIdx = contentRange.indexOf('/');
          if (slashIdx >= 0) {
            totalBytes = int.tryParse(
              contentRange.substring(slashIdx + 1),
            ) ?? (contentLength + existingBytes);
          } else {
            totalBytes = contentLength + existingBytes;
          }
        } else if (contentLength > 0) {
          totalBytes = contentLength;
        }

        // Open file in append mode (resume) or write mode (fresh)
        final fileSink = tmpFile.openWrite(
          mode: isResume ? FileMode.append : FileMode.write,
        );

        int receivedBytes = existingBytes;

        try {
          await for (final chunk in response.data!.stream) {
            fileSink.add(chunk);
            receivedBytes += chunk.length;

            if (totalBytes > 0 && onProgress != null) {
              onProgress(
                (receivedBytes / totalBytes).clamp(0.0, 1.0),
              );
            }
          }
          await fileSink.flush();
        } finally {
          await fileSink.close();
        }

        debugPrint('✅ Download complete: $receivedBytes bytes total');

        // Переименуем temp файл → zip
        final completedTmpFile = File(tmpPath);
        if (!await completedTmpFile.exists()) {
          debugPrint('❌ Временный файл не найден: $tmpPath');
          return null;
        }

        final zipFile = File(zipPath);
        if (await zipFile.exists()) await zipFile.delete();
        await completedTmpFile.rename(zipFile.path);

        debugPrint(
          '✅ ZIP скачан: ${zipFile.path} (${zipFile.lengthSync()} байт)',
        );

        // Извлекаем весь ZIP в папку категории
        final coursePath = await _extractAllFromZip(zipFile, dir.path);
        if (coursePath != null) {
          debugPrint('✅ Курс извлечён: $coursePath');

          // Сохраняем версию ресурсов
          await _saveVersion(category.id, category.version);

          // Удаляем ZIP после успешного извлечения
          try {
            await zipFile.delete();
          } catch (_) {}

          return coursePath;
        } else {
          debugPrint('❌ Не удалось извлечь курс из ZIP');
          // Corrupted ZIP — delete partial + zip so next attempt starts fresh
          try {
            await zipFile.delete();
          } catch (_) {}
          try {
            final tmp = File(tmpPath);
            if (await tmp.exists()) await tmp.delete();
          } catch (_) {}
          return null;
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          debugPrint('⚠️ Скачивание отменено пользователем');
          // On cancel: KEEP partial file for resume next time
          return null;
        }
        // Network error — keep partial file and retry
        debugPrint(
          '⚠️ Attempt $attempt/$maxRetries failed: ${e.type} — '
          '${e.message} (partial file kept for resume)',
        );
        if (attempt >= maxRetries) {
          debugPrint('❌ All $maxRetries attempts failed');
          return null;
        }
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: attempt * 2));
      } catch (e) {
        debugPrint(
          '❌ Unexpected error on attempt $attempt: $e '
          '(partial file kept for resume)',
        );
        if (attempt >= maxRetries) return null;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return null;
  }

  /// Извлекает все файлы из ZIP архива в папку категории.
  /// Возвращает путь к папке, содержащей manifest.json.
  static Future<String?> _extractAllFromZip(
    File zipFile,
    String targetDir,
  ) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      debugPrint('📦 ZIP содержит ${archive.files.length} файлов');

      int extractedCount = 0;
      for (final file in archive.files) {
        final filePath = p.join(targetDir, file.name);

        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          extractedCount++;
        } else {
          // Это директория
          await Directory(filePath).create(recursive: true);
        }
      }

      debugPrint('✅ Извлечено $extractedCount файлов в $targetDir');

      // Ищем manifest.json рекурсивно
      final manifestFile = _findManifest(targetDir);
      if (manifestFile != null) {
        final coursePath = manifestFile.parent.path;
        debugPrint('✅ manifest.json найден: ${manifestFile.path}');
        return coursePath;
      }

      debugPrint('❌ manifest.json не найден в извлечённых файлах');
      return null;
    } catch (e, st) {
      AppLogger.error('CategoryResource.extractZip', e, st);
      return null;
    }
  }

  /// Рекурсивно ищет manifest.json в директории.
  static File? _findManifest(String dirPath) {
    final dir = Directory(dirPath);
    // Сначала ищем в корне
    final rootManifest = File(p.join(dirPath, 'manifest.json'));
    if (rootManifest.existsSync()) return rootManifest;

    // Ищем в подпапках (макс 2 уровня)
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && p.basename(entity.path) == 'manifest.json') {
          return entity;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Удаляет все ресурсы категории.
  static Future<void> deleteResources(int categoryId) async {
    final dir = await _categoryDir(categoryId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      debugPrint('🗑️ Ресурсы категории $categoryId удалены');
    }
  }

  /// Удаляет ВСЕ скачанные категории (все ZIP-ы и извлечённые файлы).
  /// Используется при logout, чтобы не занимать память следующего пользователя.
  static Future<void> deleteAllResources() async {
    try {
      final base = await getApplicationSupportDirectory();
      final resourcesDir = Directory(p.join(base.path, 'Resources'));
      if (await resourcesDir.exists()) {
        await resourcesDir.delete(recursive: true);
        debugPrint('🗑️ Все ресурсы категорий удалены');
      }
      // Также удаляем temp audio cache
      final tempDir = await getTemporaryDirectory();
      final audioCache = Directory(p.join(tempDir.path, 'audio_cache'));
      if (await audioCache.exists()) {
        await audioCache.delete(recursive: true);
        debugPrint('🗑️ Audio cache очищен');
      }
    } catch (e) {
      debugPrint('⚠️ deleteAllResources error: $e');
    }
  }
}
