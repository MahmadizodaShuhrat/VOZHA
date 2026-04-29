import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_models.dart';
import 'package:vozhaomuz/feature/courses/data/repository/course_loader.dart';

/// Get translation for CourseWord based on locale code
String _getTranslation(CourseWord word, String localeCode) {
  if (localeCode == 'ru') {
    return word.translations['Russian'] ?? word.translation;
  }
  return word.translations['Tajik'] ?? word.translation;
}

/// Screen showing words from a specific lesson
class LessonWordsPage extends StatefulWidget {
  final LessonInfo lesson;
  final int lessonIndex;
  final String lessonDir;

  const LessonWordsPage({
    super.key,
    required this.lesson,
    required this.lessonIndex,
    required this.lessonDir,
  });

  @override
  State<LessonWordsPage> createState() => _LessonWordsPageState();
}

class _LessonWordsPageState extends State<LessonWordsPage> {
  LearningWordsData? _wordsData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      if (widget.lesson.learningWordsPath == null) {
        setState(() {
          _error = 'no_words_in_lesson'.tr();
          _loading = false;
        });
        return;
      }

      final wordsData = await CourseLoader.loadLearningWords(
        widget.lessonDir,
        widget.lesson.learningWordsPath!,
      );

      if (wordsData == null) {
        setState(() {
          _error = 'words_load_failed'.tr();
          _loading = false;
        });
        return;
      }

      setState(() {
        _wordsData = wordsData;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '${'error'.tr()}: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5FAFF),
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        ),
        title: Text(
          '${'lesson'.tr()} ${widget.lessonIndex + 1}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2E90FA)),
            SizedBox(height: 16),
            Text('loading_words'.tr()),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('back'.tr()),
            ),
          ],
        ),
      );
    }

    final words = _wordsData!.words;
    if (words.isEmpty) {
      return Center(child: Text('words_not_found'.tr()));
    }

    return Column(
      children: [
        // Lesson title header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E90FA), Color(0xFF1570EF)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                widget.lesson.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${words.length} ${'words_count'.tr()}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        // Words list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              return _buildWordCard(word, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(CourseWord word, int index) {
    // Get current locale from context
    final localeCode = context.locale.languageCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _playWordAudio(word),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Word number
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E90FA),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Word content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.word.replaceAll(RegExp(r'_\d+$'), ''),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (word.transcription.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '[${word.transcription}]',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _getTranslation(word, localeCode),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2E90FA),
                        ),
                      ),
                    ],
                  ),
                ),
                // Audio button
                if (word.audio.isNotEmpty)
                  IconButton(
                    onPressed: () => _playWordAudio(word),
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFF2E90FA),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _playWordAudio(CourseWord word) {
    if (word.audio.isEmpty) return;
    HapticFeedback.lightImpact();
    // TODO: Implement audio playback with just_audio
    debugPrint('🔊 Playing: ${word.audio}');
  }
}
