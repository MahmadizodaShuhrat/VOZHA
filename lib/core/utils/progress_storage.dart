import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';

class ProgressStorage {
  /// ⬇️ Ба даст овардани роҳ ба файли маҳаллии progress бо номи `userId.json`
  static Future<File> _getFile(int userId) async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, '$userId.json');
    return File(path);
  }

  /// 📖 Хондани файл ва баргардонидани объекти [ProgressFile]
  static Future<ProgressFile> read(int userId) async {
    final file = await _getFile(userId);
    if (!await file.exists()) {
      return ProgressFile.empty(); // агар файл вуҷуд надорад, холӣ бармегардонад
    }
    final content = await file.readAsString();
    return ProgressFile.fromJson(jsonDecode(content));
  }

  /// 💾 Сабти маълумот ба файл
  static Future<void> save(int userId, ProgressFile data) async {
    final file = await _getFile(userId);
    final jsonString = jsonEncode(data.toJson());
    await file.writeAsString(jsonString, flush: true);
  }
}
