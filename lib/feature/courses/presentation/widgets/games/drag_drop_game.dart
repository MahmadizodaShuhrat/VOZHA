import 'package:flutter/material.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/game_text_utils.dart';

/// DragDrop game — drag words from a pool into blank slots in text.
/// Unity: UIDragDropItems + DragDropBlanksUI
///
/// Text: "Столицой ... является *DropElement* а столицой ..."
/// Pool: correctAnswers + distractors (shuffled)
/// Check: compares slot content with correctAnswers[i]
class DragDropGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const DragDropGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<DragDropGameWidget> createState() => _DragDropGameWidgetState();
}

class _DragDropGameWidgetState extends State<DragDropGameWidget> {
  late List<String> _correctAnswers;
  late List<String> _sourceTexts;
  late List<String> _wordPool;
  final Map<int, String> _slotValues = {};
  bool _submitted = false;
  List<bool> _results = [];

  @override
  void initState() {
    super.initState();
    // Unity: CorrectAnswers = DataSources.Select(q => q.CorrectAnswer)
    _correctAnswers = widget.question.dataSources
        .map((ds) => ds.correctAnswer ?? '')
        .toList();
    // Unity: SourceText = DataSources.Select(q => q.Text)
    _sourceTexts = widget.question.dataSources.map((ds) => ds.text).toList();

    // Unity: Distractors = WordBank minus CorrectAnswers, then shuffle
    final distractors = List<String>.from(widget.question.wordBank);
    distractors.removeWhere((d) => _correctAnswers.contains(d));
    _wordPool = [..._correctAnswers, ...distractors]..shuffle();
  }

  @override
  Widget build(BuildContext context) {
    final usedWords = _slotValues.values.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text lines with drop slots (Unity: FlowWrapLayout with *DropElement*)
        ...List.generate(_sourceTexts.length, (i) {
          final placed = _slotValues[i];

          // Unity colors
          Color slotBorder = const Color(0xFFCCCCCC);
          Color slotBg = const Color(0xFFF5F5F5);
          Color textColor = const Color(0xFF333333);

          if (_submitted && i < _results.length) {
            slotBg = _results[i]
                ? const Color(0xFFE5FFEE)
                : const Color(0xFFFFF0F0);
            slotBorder = _results[i]
                ? const Color(0xFF1BD259)
                : const Color(0xFFFF3700);
            textColor = _results[i]
                ? const Color(0xFF1BD259)
                : const Color(0xFFFF3700);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Source text
                Expanded(
                  flex: 3,
                  child: buildRichTextFromHtml(
                    stripDropElement(_sourceTexts[i]),
                    baseStyle: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                // Drop target slot
                Expanded(
                  flex: 2,
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (_) =>
                        !_submitted && placed == null,
                    onAcceptWithDetails: (details) {
                      setState(() => _slotValues[i] = details.data);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      return Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: placed != null
                              ? slotBg
                              : (isHovering
                                    ? const Color(0xFFE3F2FD)
                                    : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: placed != null
                                ? slotBorder
                                : (isHovering
                                      ? const Color(0xFF2196F3)
                                      : const Color(0xFFCCCCCC)),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: placed != null
                              ? GestureDetector(
                                  onTap: _submitted
                                      ? null
                                      : () {
                                          setState(() => _slotValues.remove(i));
                                        },
                                  child: Text(
                                    placed,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                )
                              : const Text(
                                  '___',
                                  style: TextStyle(
                                    color: Color(0xFFBDBDBD),
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 16),

        // Word pool (Unity: shuffled correctAnswers + distractors)
        if (!_submitted)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _wordPool.where((w) => !usedWords.contains(w)).map((
              word,
            ) {
              return Draggable<String>(
                data: word,
                feedback: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      word,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildPoolChip(word),
                ),
                child: _buildPoolChip(word),
              );
            }).toList(),
          ),

        const SizedBox(height: 12),

        // CHECK button (Unity: UIButtonCheck, checks AreAllSlotsFilled first)
        if (!_submitted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _slotValues.length == _correctAnswers.length
                  ? _submit
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                disabledBackgroundColor: const Color(0xFFCCCCCC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'CHECK',
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

  Widget _buildPoolChip(String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A90D9)),
      ),
      child: Text(
        word,
        style: const TextStyle(
          color: Color(0xFF4A90D9),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _submit() {
    // Unity: Answers[i].Label == UIGame.correctAnswers[i]
    final results = <bool>[];
    for (int i = 0; i < _correctAnswers.length; i++) {
      final placed = _slotValues[i]?.trim().toLowerCase() ?? '';
      final correct = _correctAnswers[i].trim().toLowerCase();
      results.add(placed == correct);
    }
    setState(() {
      _submitted = true;
      _results = results;
    });
    widget.onAnswered(results);
  }
}
