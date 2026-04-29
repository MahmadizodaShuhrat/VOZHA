import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Ordering game — tap words to build a sentence in correct order.
///
/// Interaction:
///  - Shuffled words shown as chips
///  - Tap a word → it moves to the sentence area (bottom)
///  - Tap a placed word → it returns back to available pool
///  - CHECK button when all words placed → validate order
class OrderingGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const OrderingGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    Key? key,
  }) : super(key: key);

  @override
  State<OrderingGameWidget> createState() => _OrderingGameWidgetState();
}

class _OrderingGameWidgetState extends State<OrderingGameWidget> {
  late List<String> _correctOrder;
  late List<String> _shuffledWords; // Words available to pick
  final List<String> _placedWords = []; // Words placed in sentence area
  bool _submitted = false;
  List<bool> _results = [];

  @override
  void initState() {
    super.initState();
    _correctOrder = widget.question.dataSources
        .map((ds) => ds.correctAnswer ?? ds.text)
        .toList();

    // Fisher-Yates shuffle
    _shuffledWords = List.from(_correctOrder);
    final rng = Random();
    for (int i = _shuffledWords.length - 1; i > 0; i--) {
      int j = rng.nextInt(i + 1);
      final temp = _shuffledWords[i];
      _shuffledWords[i] = _shuffledWords[j];
      _shuffledWords[j] = temp;
    }
  }

  bool get _allPlaced => _shuffledWords.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Sentence area (placed words) ───
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _submitted ? Colors.transparent : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _submitted ? Colors.transparent : const Color(0xFFDAE0E8),
              width: 1.5,
              style: _submitted ? BorderStyle.none : BorderStyle.solid,
            ),
          ),
          child: _placedWords.isEmpty && !_submitted
              ? Center(
                  child: Text(
                    'tap_words_hint'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_placedWords.length, (i) {
                    if (_submitted) {
                      return _buildResultChip(i);
                    }
                    return _buildPlacedChip(i);
                  }),
                ),
        ),

        const SizedBox(height: 16),

        // ─── Available words (shuffled pool) ───
        if (!_submitted && _shuffledWords.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_shuffledWords.length, (i) {
              return _buildAvailableChip(i);
            }),
          ),

        // ─── CHECK button ───
        if (!_submitted) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: MyButton(
              height: 48,
              borderRadius: 14,
              buttonColor: _allPlaced
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFB0B0B0),
              backButtonColor: _allPlaced
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF9E9E9E),
              onPressed: _allPlaced ? _onCheck : null,
              child: Text(
                'check'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Available word chip — tap to add to sentence area
  Widget _buildAvailableChip(int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _placedWords.add(_shuffledWords.removeAt(index));
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD0D5DD), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _shuffledWords[index],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
      ),
    );
  }

  /// Placed word chip — small chip with close icon in top-right
  Widget _buildPlacedChip(int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C81FF), width: 1.5),
          ),
          child: Text(
            _placedWords[index],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1565C0),
            ),
          ),
        ),
        // Close button in top-right
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _shuffledWords.add(_placedWords.removeAt(index));
              });
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2C81FF),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Result chip — green if correct position, red if wrong
  Widget _buildResultChip(int index) {
    final isCorrect = index < _results.length && _results[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFE5FFEE) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? const Color(0xFF1BD259) : const Color(0xFFFF3700),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCorrect
                  ? const Color(0xFF1BD259)
                  : const Color(0xFFFF3700),
            ),
            child: Center(
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _placedWords[index],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isCorrect
                  ? const Color(0xFF15803D)
                  : const Color(0xFFC62828),
            ),
          ),
          // Show correct word if wrong
          if (!isCorrect && index < _correctOrder.length) ...[
            const SizedBox(width: 6),
            Text(
              '→ ${_correctOrder[index]}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onCheck() {
    HapticFeedback.mediumImpact();

    final results = <bool>[];
    for (int i = 0; i < _placedWords.length; i++) {
      if (i < _correctOrder.length) {
        results.add(
          _placedWords[i].trim().toLowerCase() ==
              _correctOrder[i].trim().toLowerCase(),
        );
      } else {
        results.add(false);
      }
    }

    setState(() {
      _submitted = true;
      _results = results;
    });
    widget.onAnswered(results);
  }
}
