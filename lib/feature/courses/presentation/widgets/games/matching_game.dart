import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// MatchingGame — textbook-style drag-to-draw lines between columns.
///
/// Touch left dot → drag finger → release on right dot → line drawn.
/// Just like drawing lines with a pen in a notebook exercise.
class MatchingGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const MatchingGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<MatchingGameWidget> createState() => _MatchingGameWidgetState();
}

// Unique color for each drawn line
const _lineColors = [
  Color(0xFF6366F1),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFFF97316),
];

class _MatchingGameWidgetState extends State<MatchingGameWidget> {
  late List<_MatchPair> _pairs;
  late List<String> _rightItems;

  // Matched pairs: leftIndex -> rightIndex
  final Map<int, int> _matches = {};

  bool _submitted = false;
  List<bool> _results = [];

  // Drag state
  int? _draggingFromLeft;
  Offset? _dragCurrentPos;

  // Keys for position computation
  final Map<int, GlobalKey> _leftDotKeys = {};
  final Map<int, GlobalKey> _rightDotKeys = {};
  final GlobalKey _areaKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    debugPrint('🎮 [MatchingGame] question.type: ${widget.question.type}');
    debugPrint('🎮 [MatchingGame] dataSources.length: ${widget.question.dataSources.length}');
    for (int i = 0; i < widget.question.dataSources.length; i++) {
      final ds = widget.question.dataSources[i];
      debugPrint('🎮 [MatchingGame] dataSource[$i]: text="${ds.text}", correctAnswer="${ds.correctAnswer}"');
    }
    debugPrint('🎮 [MatchingGame] question.wordBank: ${widget.question.wordBank}');

    _pairs = widget.question.dataSources
        .where((ds) => ds.text.isNotEmpty)
        .map((ds) => _MatchPair(
              text: ds.text.trim(),
              correctAnswer: (ds.correctAnswer ?? '').trim(),
            ))
        .toList();

    _rightItems = widget.question.wordBank
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w.trim())
        .toList();

    if (_pairs.isEmpty || _rightItems.isEmpty) {
      debugPrint('⚠️ [MatchingGame] No data! Using hardcoded fallback');
      _pairs = [
        _MatchPair(text: 'expens', correctAnswer: 'ive'),
        _MatchPair(text: 'holi', correctAnswer: 'day'),
        _MatchPair(text: 'pop', correctAnswer: 'ular'),
        _MatchPair(text: 'moun', correctAnswer: 'tain'),
        _MatchPair(text: 'mill', correctAnswer: 'ion'),
      ];
      _rightItems = ['ion', 'ular', 'tain', 'ive', 'day'];
    }

    _rightItems.shuffle();

    for (int i = 0; i < _pairs.length; i++) {
      _leftDotKeys[i] = GlobalKey();
    }
    for (int i = 0; i < _rightItems.length; i++) {
      _rightDotKeys[i] = GlobalKey();
    }
  }

  bool _isRightMatched(int ri) => _matches.containsValue(ri);
  bool _isLeftMatched(int li) => _matches.containsKey(li);
  bool get _allMatched => _matches.length >= _pairs.length;

  /// Get center of a dot relative to _areaKey
  Offset? _dotCenter(GlobalKey? key) {
    try {
      if (key?.currentContext == null || _areaKey.currentContext == null) return null;
      final renderObj = key!.currentContext!.findRenderObject();
      final areaObj = _areaKey.currentContext!.findRenderObject();
      if (renderObj == null || areaObj == null) return null;
      final RenderBox box = renderObj as RenderBox;
      final RenderBox area = areaObj as RenderBox;
      if (!box.hasSize || !area.hasSize) return null;
      final pos = box.localToGlobal(
        Offset(box.size.width / 2, box.size.height / 2),
        ancestor: area,
      );
      return pos;
    } catch (_) {
      return null;
    }
  }

  /// Find if drag end position is near a right dot
  int? _findNearestRightDot(Offset pos) {
    for (int i = 0; i < _rightItems.length; i++) {
      if (_isRightMatched(i)) continue;
      final center = _dotCenter(_rightDotKeys[i]!);
      if (center == null) continue;
      if ((center - pos).distance < 30) return i;
    }
    return null;
  }

  void _onDragStart(int leftIndex, DragStartDetails details) {
    if (_submitted || _isLeftMatched(leftIndex)) return;
    HapticFeedback.selectionClick();
    final RenderBox area = _areaKey.currentContext!.findRenderObject() as RenderBox;
    setState(() {
      _draggingFromLeft = leftIndex;
      _dragCurrentPos = area.globalToLocal(details.globalPosition);
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_draggingFromLeft == null) return;
    final RenderBox area = _areaKey.currentContext!.findRenderObject() as RenderBox;
    setState(() {
      _dragCurrentPos = area.globalToLocal(details.globalPosition);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_draggingFromLeft == null || _dragCurrentPos == null) {
      setState(() {
        _draggingFromLeft = null;
        _dragCurrentPos = null;
      });
      return;
    }

    final rightIdx = _findNearestRightDot(_dragCurrentPos!);
    if (rightIdx != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _matches[_draggingFromLeft!] = rightIdx;
      });
    }

    setState(() {
      _draggingFromLeft = null;
      _dragCurrentPos = null;
    });
  }

  void _undoMatch(int leftIndex) {
    if (_submitted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _matches.remove(leftIndex);
    });
  }

  void _onCheck() {
    HapticFeedback.mediumImpact();
    final results = <bool>[];
    for (int i = 0; i < _pairs.length; i++) {
      final ri = _matches[i];
      if (ri == null) {
        results.add(false);
        continue;
      }
      results.add(
        _rightItems[ri].toLowerCase().trim() ==
            _pairs[i].correctAnswer.toLowerCase().trim(),
      );
    }
    setState(() {
      _submitted = true;
      _results = results;
    });
    widget.onAnswered(results);
  }

  @override
  Widget build(BuildContext context) {
    if (_pairs.isEmpty) {
      return _buildEmptyFallback();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Drawing area: two columns + lines ──
        Container(
          key: _areaKey,
          child: CustomPaint(
            foregroundPainter: _NotebookLinePainter(
              matches: _matches,
              results: _submitted ? _results : null,
              draggingFrom: _draggingFromLeft,
              dragPos: _dragCurrentPos,
              getLeftDot: (i) => _dotCenter(_leftDotKeys[i]!),
              getRightDot: (i) => _dotCenter(_rightDotKeys[i]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                Expanded(flex: 5, child: _buildLeftColumn()),
                // Gap between columns (where lines cross)
                const SizedBox(width: 40),
                // Right column
                Expanded(flex: 5, child: _buildRightColumn()),
              ],
            ),
          ),
        ),

        // ── Combined words preview ──
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildCombinedWords(),
        ],

        // ── Correct answers shown after submit ──
        if (_submitted) ...[
          const SizedBox(height: 8),
          _buildCorrectAnswers(),
        ],

        // ── CHECK button ──
        if (!_submitted) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: MyButton(
              height: 48,
              borderRadius: 14,
              buttonColor:
                  _allMatched ? const Color(0xFF2563EB) : const Color(0xFFB0B0B0),
              backButtonColor:
                  _allMatched ? const Color(0xFF1D4ED8) : const Color(0xFF9E9E9E),
              onPressed: _allMatched ? _onCheck : null,
              child: Text(
                'check'.tr(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ────────────────── Left column ──────────────────

  Widget _buildLeftColumn() {
    return Column(
      children: List.generate(_pairs.length, (i) {
        final matched = _isLeftMatched(i);
        final dragging = _draggingFromLeft == i;
        final color = _lineColors[i % _lineColors.length];

        Color bg, border;
        Color textCol = const Color(0xFF1A1A2E);

        if (_submitted && i < _results.length) {
          bg = _results[i] ? const Color(0xFFE5FFEE) : const Color(0xFFFFF0F0);
          border =
              _results[i] ? const Color(0xFF1BD259) : const Color(0xFFFF3700);
          textCol =
              _results[i] ? const Color(0xFF15803D) : const Color(0xFFC62828);
        } else if (dragging) {
          bg = color.withOpacity(0.1);
          border = color;
        } else if (matched) {
          bg = color.withOpacity(0.06);
          border = color.withOpacity(0.5);
        } else {
          bg = const Color(0xFFF8F9FA);
          border = const Color(0xFFDDE1E6);
        }

        return GestureDetector(
          onPanStart: (d) => _onDragStart(i, d),
          onPanUpdate: _onDragUpdate,
          onPanEnd: _onDragEnd,
          onTap: matched ? () => _undoMatch(i) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: dragging ? 2 : 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _pairs[i].text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textCol,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // ● dot (drag handle)
                Container(
                  key: _leftDotKeys[i],
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: matched || dragging
                        ? color
                        : const Color(0xFFB0B0B0),
                    border: Border.all(
                      color: matched || dragging
                          ? color
                          : const Color(0xFF999999),
                      width: 1.5,
                    ),
                    boxShadow: dragging
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ────────────────── Right column ──────────────────

  Widget _buildRightColumn() {
    return Column(
      children: List.generate(_rightItems.length, (i) {
        final matched = _isRightMatched(i);
        final matchedLeft =
            _matches.entries.where((e) => e.value == i).firstOrNull?.key;
        final color = matchedLeft != null
            ? _lineColors[matchedLeft % _lineColors.length]
            : null;

        // Highlight if dragging near this dot
        bool isHovered = false;
        if (_draggingFromLeft != null &&
            _dragCurrentPos != null &&
            !_isRightMatched(i)) {
          try {
            final c = _dotCenter(_rightDotKeys[i]);
            if (c != null) {
              isHovered = (c - _dragCurrentPos!).distance < 30;
            }
          } catch (_) {}
        }

        Color bg, border;
        Color textCol = const Color(0xFF1A1A2E);

        if (_submitted && matchedLeft != null && matchedLeft < _results.length) {
          bg = _results[matchedLeft]
              ? const Color(0xFFE5FFEE)
              : const Color(0xFFFFF0F0);
          border = _results[matchedLeft]
              ? const Color(0xFF1BD259)
              : const Color(0xFFFF3700);
          textCol = _results[matchedLeft]
              ? const Color(0xFF15803D)
              : const Color(0xFFC62828);
        } else if (isHovered) {
          bg = const Color(0xFFFFF7ED);
          border = const Color(0xFFF59E0B);
        } else if (matched && color != null) {
          bg = color.withOpacity(0.06);
          border = color.withOpacity(0.5);
        } else {
          bg = const Color(0xFFFFFBF5);
          border = const Color(0xFFE0DAD0);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: border,
              width: isHovered ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              // ● dot
              Container(
                key: _rightDotKeys[i],
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: matched && color != null
                      ? color
                      : (isHovered
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFB0B0B0)),
                  border: Border.all(
                    color: matched && color != null
                        ? color
                        : (isHovered
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF999999)),
                    width: 1.5,
                  ),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _rightItems[i],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textCol,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ────────────────── Combined words chips ──────────────────

  Widget _buildCombinedWords() {
    final sorted = _matches.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: sorted.map((e) {
        final li = e.key;
        final ri = e.value;
        final word = '${_pairs[li].text}${_rightItems[ri]}';
        final lc = _lineColors[li % _lineColors.length];

        Color bg, bc, tc;
        IconData? icon;

        if (_submitted && li < _results.length) {
          bg = _results[li] ? const Color(0xFFE5FFEE) : const Color(0xFFFFF0F0);
          bc = _results[li] ? const Color(0xFF1BD259) : const Color(0xFFFF3700);
          tc = _results[li] ? const Color(0xFF15803D) : const Color(0xFFC62828);
          icon = _results[li] ? Icons.check_circle : Icons.cancel;
        } else {
          bg = lc.withOpacity(0.08);
          bc = lc.withOpacity(0.4);
          tc = lc;
        }

        return GestureDetector(
          onTap: _submitted ? null : () => _undoMatch(li),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bc),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: bc),
                  const SizedBox(width: 4),
                ],
                Text(word,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: tc)),
                if (!_submitted) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.close, size: 12, color: tc.withOpacity(0.5)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ────────────────── Correct answers after submit ──────────────────

  Widget _buildCorrectAnswers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_pairs.length, (i) {
        if (i >= _results.length || _results[i]) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Color(0xFF15803D)),
              const SizedBox(width: 6),
              Text(
                '${_pairs[i].text}${_pairs[i].correctAnswer}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ────────────────── Empty fallback ──────────────────

  Widget _buildEmptyFallback() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 40, color: Colors.orange.shade400),
          const SizedBox(height: 12),
          Text('matching_data_missing'.tr(),
              style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          MyButton(
            height: 44,
            borderRadius: 12,
            buttonColor: Colors.orange,
            backButtonColor: Colors.orange.shade700,
            onPressed: () => widget.onAnswered([false]),
            child: Text('skip'.tr(),
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Draws lines between matched dots + live drag line
class _NotebookLinePainter extends CustomPainter {
  final Map<int, int> matches;
  final List<bool>? results;
  final int? draggingFrom;
  final Offset? dragPos;
  final Offset? Function(int) getLeftDot;
  final Offset? Function(int) getRightDot;

  _NotebookLinePainter({
    required this.matches,
    this.results,
    this.draggingFrom,
    this.dragPos,
    required this.getLeftDot,
    required this.getRightDot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed match lines
    for (final entry in matches.entries) {
      final li = entry.key;
      final ri = entry.value;
      final start = getLeftDot(li);
      final end = getRightDot(ri);
      if (start == null || end == null) continue;

      Color color;
      if (results != null && li < results!.length) {
        color = results![li] ? const Color(0xFF1BD259) : const Color(0xFFFF3700);
      } else {
        color = _lineColors[li % _lineColors.length];
      }

      _drawLine(canvas, start, end, color, 2.5);
    }

    // Draw live drag line (follows finger)
    if (draggingFrom != null && dragPos != null) {
      final start = getLeftDot(draggingFrom!);
      if (start != null) {
        final color = _lineColors[draggingFrom! % _lineColors.length];
        _drawLine(canvas, start, dragPos!, color.withOpacity(0.5), 2.0);
      }
    }
  }

  void _drawLine(Canvas canvas, Offset start, Offset end, Color color,
      double width) {
    // Straight line like pen on paper
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);

    // Small filled dots at both ends
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 4, dotPaint);
    canvas.drawCircle(end, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _NotebookLinePainter old) => true;
}

class _MatchPair {
  final String text;
  final String correctAnswer;
  _MatchPair({required this.text, required this.correctAnswer});
}
