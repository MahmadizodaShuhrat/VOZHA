import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

/// Тип ресурса внутри архива
enum ZipResourceType { images, audio }

/// Класс-одиночка: лениво грузит ZIP один раз,
/// достаёт оттуда байты конкретного файла и
/// минимально кэширует содержимое.
class ZipResourceLoader {
  ZipResourceLoader._();

  // ---------- Public API ----------

  /// Возвращает байты нужного файла.
  static Future<Uint8List?> load({
    required String category,
    required String fileName,
    required ZipResourceType type,
  }) async {
    final key = _makeCacheKey(category, type);
    Archive? archive = _archives[key];
    if (archive == null) {
      final bytes = await _loadArchiveBytes(category, type);
      if (bytes == null) return null;
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
      _archives[key] = archive;
    }

    // 3) Ищем нужный файл
    final file = archive.files.firstWhere(
      (f) => p.basename(f.name) == fileName,
      orElse: () {
        debugPrint('‼️ В архиве ${category}_${type.name}.zip нет $fileName. '
            'Содержимое: ${archive?.files.map((e) => e.name).toList()}');
        return ArchiveFile.noCompress('', 0, Uint8List(0));
      },
    );
    if (file.size == 0) return null;
    return file.content;
  }

  /// Освобождает память: стираем все распакованные ZIP-ы.
  static void clear() => _archives.clear();

  static final Map<String, File> _externalFiles = {};

  /// Зарегистрировать файл, который лежит НЕ в assets, а в памяти.
  static void registerExternal(File f) {
    _externalFiles[p.basename(f.path)] = f;
  }

  // ---------- Private ----------

  static final Map<String, Archive> _archives = {};

  static String _makeCacheKey(String c, ZipResourceType t) =>
      '${c.toLowerCase()}_${t.name}';

  static Future<Uint8List?> _loadArchiveBytes(
      String category, ZipResourceType type) async {
    // Сначала пробуем получить файл из внешних зарегистрированных
    final local = _externalFiles['${category}_${type.name}.zip'];
    if (local != null && await local.exists()) {
      return await local.readAsBytes();
    }

    // Если нет, то загружаем из assets
    final path = 'assets/archives/${category}_${type.name}.zip';
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (e) {
      debugPrint('Не удалось загрузить архив по пути: $path\nОшибка: $e');
      return null;
    }
  }
}
