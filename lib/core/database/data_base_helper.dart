// import 'dart:io';
// import 'dart:math';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'package:vozhaomuz/core/services/connectivity_service.dart';
// import 'package:vozhaomuz/core/utils/resource_downloader.dart';
// import 'package:vozhaomuz/core/database/db_lang_column.dart';
// import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
// import 'package:vozhaomuz/feature/auth/presentation/providers/selected_level_provider.dart';
// import 'package:vozhaomuz/feature/games/presentation/screens/choose_learn_know_page.dart';
// import 'package:logger/logger.dart';
// import 'package:vozhaomuz/feature/progress/progress_provider.dart';
// import 'package:vozhaomuz/shared/widgets/download_dialog.dart';
// import 'package:vozhaomuz/shared/widgets/my_button.dart';
// import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
// class DatabaseHelper {
//   static Database? _db;
//   final Logger log = Logger();
//   static Future<Database> get database async {
//     if (_db != null) return _db!;
//     _db = await _initDB();
//     await checkAndAddStatusColumn();
//     return _db!;
//   }

//   static Future<Database> _initDB() async {
//     Directory appDoc = await getApplicationDocumentsDirectory();
//     String dbPath = join(appDoc.path, 'dbv2.db');

//     if (!File(dbPath).existsSync()) {
//       ByteData data = await rootBundle.load('assets/db/dbv2.db');
//       List<int> bytes = data.buffer.asUint8List();
//       await File(dbPath).writeAsBytes(bytes, flush: true);
//     }

//     return await openDatabase(dbPath, version: 1, readOnly: false);
//   }

//   // пример в DatabaseHelper
//   Future<List<Map<String, Object?>>> safeQuery(String sql) async {
//     try {
//       final db = await database;
//       final res = await db.rawQuery(sql);
//       log.i('SQL OK (${res.length} rows): $sql');
//       return res;
//     } catch (e, st) {
//       log.e('SQL ERROR: $sql', error: e, stackTrace: st);
//       rethrow;
//     }
//   }

//   /// ✅ Агар сутуни 'Status' вуҷуд надошта бошад, илова мекунад
//   static Future<void> checkAndAddStatusColumn() async {
//     final db = await database;
//     final res = await db.rawQuery("PRAGMA table_info(TjToEn)");
//     final columns = res.map((e) => e['name']).toList();

//     if (!columns.contains('Status')) {
//       await db.execute("ALTER TABLE TjToEn ADD COLUMN Status TEXT DEFAULT ''");
//       print("✅ Сутуни 'Status' илова шуд.");
//     } else {
//       print("ℹ️ Сутуни 'Status' аллакай вуҷуд дорад.");
//     }
//   }

//   /// ✅ Барои навсозии статус
//   static Future<void> markWordStatus(int wordId, String status) async {
//     final db = await database;
//     await db.update(
//       'TjToEn',
//       {'Status': status},
//       where: 'Id = ?',
//       whereArgs: [wordId],
//     );
//   }
// }

// class Category {
//   final int id;
//   final String name;
//   final String image;
//   final int wordCount;

//   Category({
//     required this.id,
//     required this.name,
//     required this.image,
//     required this.wordCount,
//   });

//   factory Category.fromMap(Map<String, dynamic> map) {
//     return Category(
//       id: map['Id'] as int,
//       name: map['name']?.toString() ?? '',
//       image: map['image']?.toString() ?? 'assets/images/img.png',
//       wordCount:
//           map['wordCount'] is int
//               ? map['wordCount']
//               : int.tryParse(map['wordCount'].toString()) ?? 0,
//     );
//   }
// }

// class Subcategory {
//   final int id;
//   final String name;
//   final int categoryId;

//   Subcategory({required this.id, required this.name, required this.categoryId});

//   factory Subcategory.fromMap(Map<String, dynamic> map) {
//     return Subcategory(
//       id: map['Id'],
//       name: map['name'] ?? '',
//       categoryId: map['CategoryId'],
//     );
//   }
// }

// class Word {
//   final int id;
//   final String word;
//   final String translation;
//   final String transcription;
//   final String status;
//   final int categoryId;

//   Word({
//     required this.id,
//     required this.word,
//     required this.translation,
//     required this.transcription,
//     required this.status,
//     required this.categoryId,
//   });

//   factory Word.fromMap(Map<String, dynamic> map) {
//     return Word(
//       id: map['Id'] as int,
//       word: map['word'] as String,
//       translation: map['translation'] as String,
//       transcription: map['transcription'] as String? ?? '',
//       status: map['Status'] ?? '',
//       categoryId: map['categoryId'] != null ? map['categoryId'] as int : 0,
//     );
//   }
// }

// class CategoryPage extends ConsumerStatefulWidget {
//   @override
//   _CategoryPageState createState() => _CategoryPageState();
// }

// class _CategoryPageState extends ConsumerState<CategoryPage> {
//   List<Category> _allCategories = [];
//   Set<int> _selectedIds = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadCategories();
//   }

//   Future<void> _loadCategories() async {
//     final db = await DatabaseHelper.database;
//     final locale = ref.read(localeProvider);
//     final langColumn = dbLangColumn(locale);
//     print('➡️  locale = $locale  ->  db column = ${dbLangColumn(locale)}');
//     // SQL-и нав бо шумораи калимаҳо (wordCount)
//     final rows = await db.rawQuery('''
//     SELECT
//       c.Id,
//       c.$langColumn AS name,
//       c.English AS image,
//       (SELECT COUNT(*) FROM TjToEn WHERE CategoryId = c.Id) AS wordCount
//     FROM Category c
//     ORDER BY c.Id
//   ''');

//     setState(() {
//       _allCategories = rows.map((r) => Category.fromMap(r)).toList();
//     });
//     final lang = dbLangColumn(locale);
//     final rowss = await DatabaseHelper().safeQuery(
//       "SELECT Id, $lang AS name FROM Category",
//     );
//   }

//   void _onToggle(int id, bool selected) {
//     setState(() {
//       if (selected)
//         _selectedIds.add(id);
//       else
//         _selectedIds.remove(id);
//     });
//   }

//   void printTableColumns() async {
//     final db = await DatabaseHelper.database;
//     final result = await db.rawQuery("PRAGMA table_info(TjToEn)");
//     for (var row in result) {
//       print(row['name']);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedLevel = ref.watch(selectedLevelProvider);
//     return Scaffold(
//       backgroundColor: Color(0xFFF5FAFF),
//       appBar: AppBar(
//         automaticallyImplyLeading: false,
//         elevation: 0,
//         backgroundColor: Color(0xFFF5FAFF),
//         title: Center(
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               SizedBox(),
//               Expanded(
//                 child: Text(
//                   'What_do_you_want_to_learn?'.tr(),
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
//                 ),
//               ),
//               IconButton(
//                 onPressed: () {
//                   HapticFeedback.lightImpact();
//                   Navigator.pop(context);
//                 },
//                 icon: Icon(Icons.close),
//               ),
//             ],
//           ),
//         ),
//       ),
//       body:
//           _allCategories.isEmpty
//               ? Center(child: CircularProgressIndicator())
//               : ListView(
//                 children:
//                     _allCategories
//     .where((cat) => ref.watch(progressProvider).selectedIds.contains(cat.id))
//     .map((cat) {

//                       bool isSel = _selectedIds.contains(cat.id);
//                       return Column(
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
//                             child: MyButton(
//                               onPressed: (){
//                                 GamePage(categoryId: cat.id);
//                                 _openCategory(context, ref, cat.id);
//                               },
//                               width: double.infinity,
//                               padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
//                               buttonColor: Colors.white,
//                               borderRadius:10 ,
//                               backButtonColor: Color(0xFFEEF2F6),
//                               depth: 4,
//                               child: Row(
//                                 children: [
//                                   ClipRRect(
//                                     borderRadius: BorderRadius.circular(8),
//                                     child: Image.asset(
//                                       'assets/images/categories/${cat.id}.png',
//                                       width: 40,
//                                       height: 40,
//                                       fit: BoxFit.cover,
//                                     ),
//                                   ),
//                                   SizedBox(width: 12),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           cat.name,
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.bold,
//                                             fontSize: 16,
//                                           ),
//                                         ),
//                                         SizedBox(height: 6),
//                                         Row(
//                                           children: [
//                                             Expanded(
//                                               child: SizedBox(
//                                                 height:
//                                                     8, // 👉 ҳаминҷо баландиро муайян мекунӣ
//                                                 child: LinearProgressIndicator(
//                                                   value: 36 / 265,
//                                                   borderRadius:
//                                                       BorderRadius.circular(15),
//                                                   backgroundColor: Color(
//                                                     0xFFD1E9FF,
//                                                   ),
//                                                   color: Colors.blue,
//                                                 ),
//                                               ),
//                                             ),
//                                             SizedBox(width: 5),
//                                             Text(
//                                               '36',
//                                               style: TextStyle(
//                                                 fontSize: 10,
//                                                 color: Color(0xFF2E90FA),
//                                               ),
//                                             ),
//                                             Text(
//                                               '/${cat.wordCount}',
//                                               style: TextStyle(
//                                                 fontSize: 10,
//                                                 color: Colors.black,
//                                               ),
//                                             ),
//                                             const SizedBox(width: 4),
//                                             SvgPicture.asset(
//                                               "assets/images/coin (1).svg",
//                                             ),
//                                             const SizedBox(width: 4),
//                                             SvgPicture.asset(
//                                               "assets/images/coin (2).svg",
//                                             ),
//                                             const SizedBox(width: 4),
//                                             SvgPicture.asset(
//                                               "assets/images/coin (2).svg",
//                                             ),
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),

//                         ],
//                       );
//                     }).toList(),
//               ),
//     );
//   }
// }

// Future<void> _openCategory(BuildContext ctx, WidgetRef ref, int id) async {
//   final hasNet = ref.read(connectivityProvider).value ?? true;
//   if (!hasNet) {
//     ScaffoldMessenger.of(
//       ctx,
//     ).showSnackBar(const SnackBar(content: Text('Нет интернета')));
//     return;
//   }
//   final lang = ref.read(localeProvider).languageCode;
//   final okAudio = await showDialog<bool>(
//     context: ctx,
//     barrierDismissible: false,
//     builder:
//         (_) => DownloadDialog(
//           id: id,
//         ),
//   );
//   if (okAudio != true) return;
//   final okImg = await showDialog<bool>(
//     context: ctx,
//     barrierDismissible: false,
//     builder:
//         (_) => DownloadDialog(
//           id: id,
//         ),
//   );
//   if (okImg != true) return;
//   if (ctx.mounted) {
//     Navigator.push(
//       ctx,
//       MaterialPageRoute(builder: (_) => ChoseLearnKnowPage(categoryId: id)),
//     );
//   }
// }

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

/// Помощник для работы со статусами слов (JSON-файл).
/// Все методы, связанные с dbv2.db, удалены — слова загружаются
/// из ресурсов курса через CategoryDbHelper.
class DatabaseHelper {
  /// Путь к файлу с сохранёнными статусами слов.
  static String? _statusFilePath;

  static Future<String> _getStatusFilePath() async {
    if (_statusFilePath != null) return _statusFilePath!;
    final dir = await getApplicationDocumentsDirectory();
    _statusFilePath = join(dir.path, 'word_statuses.json');
    return _statusFilePath!;
  }

  static Map<String, String>? _statusCache;

  static Future<Map<String, String>> _loadStatuses() async {
    if (_statusCache != null) return _statusCache!;
    try {
      final path = await _getStatusFilePath();
      final file = File(path);
      if (file.existsSync()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        _statusCache = decoded.map((k, v) => MapEntry(k, v.toString()));
      } else {
        _statusCache = {};
      }
    } catch (e) {
      debugPrint('⚠️ _loadStatuses error: $e');
      _statusCache = {};
    }
    return _statusCache!;
  }

  static Future<void> _saveStatuses(Map<String, String> statuses) async {
    try {
      final path = await _getStatusFilePath();
      await File(path).writeAsString(jsonEncode(statuses));
    } catch (e) {
      debugPrint('⚠️ _saveStatuses error: $e');
    }
  }

  /// Сохранить статус слова (known / learning / none) в локальный JSON файл.
  static Future<void> markWordStatus(int wordId, String status) async {
    try {
      final statuses = await _loadStatuses();
      if (status == 'none' || status.isEmpty) {
        statuses.remove(wordId.toString());
      } else {
        statuses[wordId.toString()] = status;
      }
      _statusCache = statuses;
      await _saveStatuses(statuses);
    } catch (e) {
      debugPrint('⚠️ markWordStatus failed: $e');
    }
  }

  /// Получить сохранённый статус слова.
  static Future<String> getWordStatus(int wordId) async {
    final statuses = await _loadStatuses();
    return statuses[wordId.toString()] ?? '';
  }

  /// Clear ALL word statuses (known/learning). Called on logout to prevent
  /// next user from inheriting previous user's "known" words.
  static Future<void> clearAllStatuses() async {
    try {
      _statusCache = {};
      final path = await _getStatusFilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      debugPrint('🗑️ All word statuses cleared');
    } catch (e) {
      debugPrint('⚠️ clearAllStatuses error: $e');
    }
  }

  /// Clear all 'learning' statuses (called when starting a fresh session from home).
  static Future<void> clearLearningStatuses() async {
    final statuses = await _loadStatuses();
    statuses.removeWhere((_, v) => v == 'learning');
    _statusCache = statuses;
    await _saveStatuses(statuses);
  }

  /// Гирифтани ҳамаи wordId-ҳо бо статуси 'known' (калимаҳои "Медонам").
  static Future<Set<int>> getKnownWordIds() async {
    final statuses = await _loadStatuses();
    final result = <int>{};
    for (final entry in statuses.entries) {
      if (entry.value == 'known') {
        final id = int.tryParse(entry.key);
        if (id != null) result.add(id);
      }
    }
    return result;
  }
}

class Category {
  final int id;
  final String name;
  final String image;
  final int wordCount;

  Category({
    required this.id,
    required this.name,
    required this.image,
    required this.wordCount,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['Id'] as int,
      name: map['name']?.toString() ?? '',
      image: map['image']?.toString() ?? 'assets/images/img.png',
      wordCount: map['wordCount'] is int
          ? map['wordCount']
          : int.tryParse(map['wordCount'].toString()) ?? 0,
    );
  }
}

class Subcategory {
  final int id;
  final String name;
  final int categoryId;

  Subcategory({required this.id, required this.name, required this.categoryId});

  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['Id'],
      name: map['name'] ?? '',
      categoryId: map['CategoryId'],
    );
  }
}

class Word {
  final int id;
  final String word;
  final String translation;
  final String transcription;
  final String status;
  final int categoryId;

  /// Уровень слова: 1 = Начальный, 2 = Средний, 3 = Продвинутый.
  final int level;

  /// Индекс урока/субкатегории (0-based). Используется для подбора
  /// dummy-слов из того же урока (напр. овощи→овощи, а не овощи→фрукты).
  final int lessonIndex;

  /// Absolute path to the word's image file on disk (from extracted course).
  final String? photoPath;

  /// Absolute path to the word's audio file on disk (from extracted course).
  final String? audioPath;

  Word({
    required this.id,
    required this.word,
    required this.translation,
    required this.transcription,
    required this.status,
    required this.categoryId,
    this.level = 0,
    this.lessonIndex = -1,
    this.photoPath,
    this.audioPath,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['Id'] as int,
      word: map['word'] as String,
      translation: map['translation'] as String,
      transcription: map['transcription'] as String? ?? '',
      status: map['Status'] ?? '',
      categoryId: map['categoryId'] != null ? map['categoryId'] as int : 0,
    );
  }

  /// Word name for display — strips trailing _N suffixes (e.g. "knife_2" → "knife").
  /// Use [word] for image/audio file lookups, [displayWord] for user-visible text.
  String get displayWord => word.replaceAll(RegExp(r'_\d+$'), '');
}

// Helper function to map ChoosingLevelModel to an integer level
// int getLevelIntFromChoosingLevelModel(ChoosingLevelModel? levelModel) {
//   ...
// }

// CategoryPage and showCategoryDialog are dead code here.
// Active versions live in match_words.dart.
// class CategoryPage extends ConsumerStatefulWidget { ... }
// class _CategoryPageState extends ConsumerState<CategoryPage> { ... }
// void showCategoryDialog(BuildContext context) { ... }
