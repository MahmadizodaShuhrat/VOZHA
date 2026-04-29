import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';

/// CollectWords game — assemble sentences from shuffled word tokens.
/// Unity: UICollectWords + AssembleSentenceUI
///
/// Correct answers = DataSources.Select(q => q.Text)
/// Tokens = split text by spaces and shuffle
/// On check: show "Верно/Неверно, Верный ответ: {correct}" below each sentence
class CollectWordsGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const CollectWordsGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<CollectWordsGameWidget> createState() => _CollectWordsGameWidgetState();
}

class _CollectWordsGameWidgetState extends State<CollectWordsGameWidget> {
  late List<String> _correctSentences;
  late List<List<String>> _availableTokens;
  late List<List<String>> _assembled;
  bool _submitted = false;
  List<bool> _results = [];

  @override
  void initState() {
    super.initState();
    // Unity: CorrectAnswers = DataSources.Select(q => q.Text)
    _correctSentences = widget.question.dataSources
        .map((ds) => ds.text)
        .toList();
    _availableTokens = _correctSentences.map((sentence) {
      final tokens = sentence.split(' ');
      return List<String>.from(tokens)..shuffle();
    }).toList();
    _assembled = List.generate(_correctSentences.length, (_) => <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int sIdx = 0; sIdx < _correctSentences.length; sIdx++) ...[
          // Sentence header
          Text(
            '${sIdx + 1}.',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 6),

          // Assembled area (where user taps words to build sentence)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _submitted
                  ? (sIdx < _results.length && _results[sIdx]
                        ? const Color(0xFFE5FFEE)
                        : const Color(0xFFFFF0F0))
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _submitted
                    ? (sIdx < _results.length && _results[sIdx]
                          ? const Color(0xFF1BD259)
                          : const Color(0xFFFF3700))
                    : const Color(0xFFE0E0E0),
              ),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._assembled[sIdx].asMap().entries.map((entry) {
                  return GestureDetector(
                    onTap: _submitted
                        ? null
                        : () {
                            setState(() {
                              _availableTokens[sIdx].add(entry.value);
                              _assembled[sIdx].removeAt(entry.key);
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90D9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }),
                if (_assembled[sIdx].isEmpty && !_submitted)
                  Text(
                    'tap_words_hint'.tr(),
                    style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Available tokens (word bank)
          if (!_submitted)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _availableTokens[sIdx].asMap().entries.map((entry) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _assembled[sIdx].add(entry.value);
                      _availableTokens[sIdx].removeAt(entry.key);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4A90D9)),
                    ),
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Color(0xFF4A90D9),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          // Unity: after check shows "Верно/Неверно, Верный ответ: {correct}"
          if (_submitted && sIdx < _results.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13),
                  children: [
                    TextSpan(
                      text: _results[sIdx] ? 'correct_label'.tr() : 'incorrect_label'.tr(),
                      style: TextStyle(
                        color: _results[sIdx]
                            ? const Color(0xFF1BD259)
                            : const Color(0xFFFF3700),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: ', ${'correct_answer_label'.tr()}: ',
                      style: TextStyle(color: Color(0xFF666666)),
                    ),
                    TextSpan(
                      text: _correctSentences[sIdx],
                      style: const TextStyle(
                        color: Color(0xFF1BD259),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],

        // CHECK button (Unity disables after first check)
        if (!_submitted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assembled.every((a) => a.isNotEmpty) ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                disabledBackgroundColor: const Color(0xFFCCCCCC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'check'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _submit() {
    // Unity: CorrectAnswers[i] == Answers[i] (exact string match)
    final results = <bool>[];
    for (int i = 0; i < _correctSentences.length; i++) {
      final assembled = _assembled[i].join(' ');
      results.add(assembled == _correctSentences[i]);
    }
    setState(() {
      _submitted = true;
      _results = results;
    });
    widget.onAnswered(results);
  }
}
