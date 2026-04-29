// Import words dialog - picks a .vozha or .json file and imports lessons
// Mirrors Unity's UIImportPak + UIImportPakFiles flow
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Data model for imported lesson (mirrors Unity's LessonTableJson)
class ImportedLesson {
  final String name;
  final String userCreator;
  final List<ImportedWord> words;

  ImportedLesson({
    required this.name,
    required this.userCreator,
    required this.words,
  });

  factory ImportedLesson.fromJson(Map<String, dynamic> json) {
    final wordList =
        (json['WordTable'] as List?)
            ?.map((w) => ImportedWord.fromJson(w as Map<String, dynamic>))
            .toList() ??
        [];
    return ImportedLesson(
      name: json['Name'] as String? ?? '',
      userCreator: json['UserCreator'] as String? ?? '',
      words: wordList,
    );
  }

  Map<String, dynamic> toJson() => {
    'Name': name,
    'UserCreator': userCreator,
    'WordTable': words.map((w) => w.toJson()).toList(),
  };
}

class ImportedWord {
  final int id;
  final String wordOriginal;
  final String wordTranslate;
  final String wordTranscription;

  ImportedWord({
    required this.id,
    required this.wordOriginal,
    required this.wordTranslate,
    this.wordTranscription = '',
  });

  factory ImportedWord.fromJson(Map<String, dynamic> json) {
    return ImportedWord(
      id: json['Id'] as int? ?? 0,
      wordOriginal: json['WordOriginal'] as String? ?? '',
      wordTranslate: json['WordTranslate'] as String? ?? '',
      wordTranscription: json['WordTranscription'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'WordOriginal': wordOriginal,
    'WordTranslate': wordTranslate,
    'WordTranscription': wordTranscription,
  };
}

/// Picks a file (.json or .vozha) and imports it as a lesson.
/// Mirrors Unity's UIImportPak flow:
/// 1. NativeFilePicker.PickFile → pick file
/// 2. Parse JSON → extract lesson info
/// 3. Show UIImportPakFiles popup with creator + word count
/// 4. On download → copy to app directory
Future<void> importWordsDialog(BuildContext context) async {
  HapticFeedback.lightImpact();

  // 1. Pick a file (mirrors Unity's NativeFilePicker.PickFile)
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json', 'vozha'],
  );

  if (result == null || result.files.isEmpty) return;

  final file = result.files.single;
  if (file.path == null) return;

  // 2. Read and parse the file
  final filePath = file.path!;

  // Check file extension (mirrors Unity: if (!path.EndsWith(".vozha")))
  if (!filePath.endsWith('.json') && !filePath.endsWith('.vozha')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('invalid_file_type'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    return;
  }

  try {
    final fileContent = await File(filePath).readAsString();
    final jsonData = json.decode(fileContent) as Map<String, dynamic>;
    final lesson = ImportedLesson.fromJson(jsonData);

    if (lesson.words.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_words_in_file'.tr()),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    // 3. Show import confirmation dialog (mirrors Unity UIImportPakFiles)
    if (context.mounted) {
      _showImportConfirmation(context, lesson, filePath);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('import_error'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}

/// Shows import confirmation popup (mirrors Unity's UIImportPakFiles)
/// Displays: lesson name, creator, word count, Download button
void _showImportConfirmation(
  BuildContext context,
  ImportedLesson lesson,
  String sourcePath,
) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.file_download_outlined, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'import_words'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Color(0xFF314456),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(dialogContext).pop();
              },
              child: const Icon(Icons.close, size: 24),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lesson icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: Colors.blue,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Lesson name
            Text(
              lesson.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Color(0xFF314456),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Creator info (mirrors Unity Popup.SetPakInfo(Lesson.UserCreator))
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Color(0xFF8A97AB),
                ),
                const SizedBox(width: 4),
                Text(
                  lesson.userCreator.isNotEmpty
                      ? lesson.userCreator
                      : 'unknown'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A97AB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Word count (mirrors Unity Popup.SetPakInfo(count))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'n_words'.tr(args: ['${lesson.words.length}']),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Word preview list
            if (lesson.words.length <= 6)
              ...lesson.words.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 6,
                        color: Color(0xFF8A97AB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${w.wordOriginal} — ${w.wordTranslate}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A97AB),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ...lesson.words
                  .take(4)
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFF8A97AB),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${w.wordOriginal} — ${w.wordTranslate}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A97AB),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '... +${lesson.words.length - 4}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A97AB),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Download button (mirrors Unity Popup.UIDownload.onClick)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await _saveImportedLesson(lesson);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('import_success'.tr()),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download, color: Colors.white),
              label: Text(
                'import_download'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Saves imported lesson to app directory as JSON
/// (mirrors Unity: File.Copy(path, persistentDataPath/name.vozha))
Future<void> _saveImportedLesson(ImportedLesson lesson) async {
  final appDir = await getApplicationDocumentsDirectory();
  final lessonsDir = Directory('${appDir.path}/lessons');
  if (!await lessonsDir.exists()) {
    await lessonsDir.create(recursive: true);
  }

  final fileName = '${lesson.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
  final file = File('${lessonsDir.path}/$fileName');
  await file.writeAsString(json.encode(lesson.toJson()));
}
