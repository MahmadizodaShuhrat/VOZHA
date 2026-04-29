import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';
import 'package:vozhaomuz/feature/courses/presentation/widgets/games/game_text_utils.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/shared/widgets/my_key_board.dart';

/// CrossWord game — mirrors Unity CrosswordUI + UICrossWord.
///
/// Unity design (from screenshot):
///  - Grid fills available width, cells auto-sized
///  - Empty cells = transparent/light gray, editable cells = white with pink/red border
///  - Word numbers in top-left corner of start cells
///  - Selected word cells highlighted in light blue
///  - Custom keyboard at bottom: blue letter tiles + red backspace
///  - Tap letter → places in next empty cell of selected word
///  - Backspace → removes last letter from selected word
///  - CHECK → green/red per cell
class CrossWordGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const CrossWordGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<CrossWordGameWidget> createState() => _CrossWordGameWidgetState();
}

class _CrossWordGameWidgetState extends State<CrossWordGameWidget> {
  late List<List<String>> _grid;
  late List<CrosswordWord> _words;
  late String _emptyChar;

  // "x,y" → placed letter (uppercase)
  final Map<String, String> _placedLetters = {};
  // all editable cell keys
  final Set<String> _editableCells = {};

  int? _selectedWordIdx;
  bool _submitted = false;
  List<bool> _wordResults = [];

  // Letters for the custom keyboard
  List<_KeyboardLetter> _keyboardLetters = [];

  @override
  void initState() {
    super.initState();
    _grid = [];
    _words = [];
    _emptyChar = '-';

    // Find DataSource with crossword grid & words
    for (final ds in widget.question.dataSources) {
      if (ds.grid.isNotEmpty && ds.words.isNotEmpty) {
        _grid = ds.grid.map((row) => row.split('')).toList();
        _words = ds.words;
        _emptyChar = ds.empty ?? '-';
        break;
      }
    }

    // Collect editable cells
    for (final word in _words) {
      for (final letter in word.letters) {
        _editableCells.add('${letter.x},${letter.y}');
      }
    }

    // Build keyboard letters (count occurrences + add distractors)
    _initKeyboardLetters();

    // Auto-select first word
    if (_words.isNotEmpty) {
      _selectedWordIdx = 0;
    }
  }

  void _initKeyboardLetters() {
    final counts = <String, int>{};
    for (final word in _words) {
      for (final letter in word.letters) {
        final c = letter.char.toUpperCase();
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }

    // Add 2-3 distractor letters
    final rng = Random();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final distractorCount = max(
      2,
      counts.values.fold(0, (a, b) => a + b) ~/ 10,
    );
    for (int i = 0; i < distractorCount; i++) {
      final c = alphabet[rng.nextInt(26)];
      counts[c] = (counts[c] ?? 0) + 1;
    }

    // Shuffle
    final keys = counts.keys.toList()..shuffle(rng);
    _keyboardLetters = keys
        .map((c) => _KeyboardLetter(char: c, total: counts[c]!, used: 0))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_grid.isEmpty) {
      // No crossword data from backend — show skip option
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            const Icon(Icons.extension_off, size: 40, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              'crossword_data_missing'.tr(),
              style: const TextStyle(fontSize: 14, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            MyButton(
              height: 40,
              borderRadius: 10,
              depth: 4,
              buttonColor: Colors.orange,
              backButtonColor: Colors.orange.shade700,
              onPressed: () {
                widget.onAnswered([false]);
              },
              child: Text(
                'skip'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    final rows = _grid.length;
    final cols = _grid.isNotEmpty ? _grid[0].length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Clue text for selected word ───
        if (_selectedWordIdx != null && _selectedWordIdx! < _words.length)
          _buildClueHeader(),

        const SizedBox(height: 8),

        // ─── Crossword grid (scrollable if too wide) ───
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            // Auto-size cells: try to fit all columns, min 28px
            final spacing = 2.0;
            final calcSize = (availableWidth - (cols - 1) * spacing) / cols;
            final cellSize = calcSize.clamp(32.0, 52.0);
            final totalGridWidth = cols * cellSize + (cols - 1) * spacing;

            final gridWidget = Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (y) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(cols, (x) {
                    return _buildCell(x, y, cellSize);
                  }),
                );
              }),
            );

            // Always wrap in scrollable if grid wider than screen
            if (totalGridWidth > availableWidth) {
              return SizedBox(
                width: availableWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: gridWidget,
                ),
              );
            }
            return Center(child: gridWidget);
          },
        ),

        const SizedBox(height: 16),

        // ─── Custom keyboard (Unity style: blue tiles + red backspace) ───
        if (!_submitted) _buildKeyboard(),

        if (!_submitted) const SizedBox(height: 16),

        // ─── CHECK button ───
        if (!_submitted)
          SizedBox(
            width: double.infinity,
            child: MyButton(
              height: 48,
              borderRadius: 14,
              buttonColor: const Color(0xFF2563EB),
              backButtonColor: const Color(0xFF1D4ED8),
              onPressed: _submit,
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

        // ─── Word clues list (after submit — show results) ───
        if (_submitted) ...[
          const SizedBox(height: 16),
          ...List.generate(_words.length, (i) => _buildClueResult(i)),
        ],
      ],
    );
  }

  // ════════════════════════════════════
  //  CLUE HEADER
  // ════════════════════════════════════
  Widget _buildClueHeader() {
    final word = _words[_selectedWordIdx!];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C81FF), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2C81FF),
            ),
            child: Center(
              child: Text(
                '${_selectedWordIdx! + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: buildRichTextFromHtml(
              word.question ?? '',
              baseStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2C81FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _isHorizontal(word) ? '→' : '↓',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C81FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isHorizontal(CrosswordWord word) {
    final d = word.direction.toLowerCase();
    return d == 'horizontal' || d == 'across';
  }

  // ════════════════════════════════════
  //  GRID CELL
  // ════════════════════════════════════
  Widget _buildCell(int x, int y, double cellSize) {
    final key = '$x,$y';
    final isEditable = _editableCells.contains(key);

    // Non-editable cell (empty or filler)
    if (!isEditable) {
      final gridChar = (y < _grid.length && x < _grid[y].length)
          ? _grid[y][x]
          : _emptyChar;
      final isEmpty =
          gridChar == _emptyChar || gridChar == ' ' || gridChar == '';

      return SizedBox(
        width: cellSize,
        height: cellSize,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isEmpty ? Colors.transparent : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    // Find which word(s) this cell belongs to
    int? primaryWordIdx;
    String? expectedChar;
    bool isHighlighted = false;

    for (int w = 0; w < _words.length; w++) {
      for (final letter in _words[w].letters) {
        if (letter.x == x && letter.y == y) {
          primaryWordIdx ??= w;
          expectedChar ??= letter.char.toUpperCase();
          if (_selectedWordIdx == w) isHighlighted = true;
        }
      }
    }

    // Word number at start cell
    int? wordNumber;
    for (int w = 0; w < _words.length; w++) {
      if (_words[w].letters.isNotEmpty &&
          _words[w].letters.first.x == x &&
          _words[w].letters.first.y == y) {
        wordNumber = w + 1;
        break;
      }
    }

    final placedLetter = _placedLetters[key];

    // Colors — Unity style
    Color cellBg = Colors.white;
    Color borderColor = const Color(0xFFE8A0A0); // Pink/red border (Unity)

    if (isHighlighted && !_submitted) {
      cellBg = const Color(0xFFDCEEFF); // Light blue highlight
      borderColor = const Color(0xFF2C81FF); // Blue border
    }

    if (_submitted && expectedChar != null) {
      final isCorrect = placedLetter?.toUpperCase() == expectedChar;
      cellBg = isCorrect ? const Color(0xFFE5FFEE) : const Color(0xFFFFF0F0);
      borderColor = isCorrect
          ? const Color(0xFF1BD259)
          : const Color(0xFFFF3700);
    }

    return GestureDetector(
      onTap: () {
        if (_submitted) return;
        HapticFeedback.selectionClick();
        if (primaryWordIdx != null) {
          setState(() => _selectedWordIdx = primaryWordIdx);
        }
      },
      child: SizedBox(
        width: cellSize,
        height: cellSize,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Stack(
            children: [
              // Word number (top-left)
              if (wordNumber != null)
                Positioned(
                  top: 1,
                  left: 2,
                  child: Text(
                    '$wordNumber',
                    style: TextStyle(
                      fontSize: cellSize * 0.22,
                      fontWeight: FontWeight.w700,
                      color: _submitted ? borderColor : const Color(0xFF999999),
                    ),
                  ),
                ),
              // Placed letter
              if (placedLetter != null)
                Center(
                  child: Text(
                    _submitted
                        ? (placedLetter.toUpperCase() == expectedChar
                              ? placedLetter
                              : expectedChar!)
                        : placedLetter,
                    style: TextStyle(
                      fontSize: cellSize * 0.48,
                      fontWeight: FontWeight.w700,
                      color: _submitted ? borderColor : const Color(0xFF333333),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════
  //  CUSTOM KEYBOARD (Unity style)
  // ════════════════════════════════════
  Widget _buildKeyboard() {
    // Split keyboard letters into rows of 6
    const lettersPerRow = 6;
    final totalRows = (_keyboardLetters.length / lettersPerRow).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth - 8; // horizontal padding
        // Calculate key size: last row has lettersPerRow + backspace
        // We size all keys based on the most crowded row (last row)
        final maxKeysInRow = lettersPerRow + 1; // +1 for backspace
        final totalMargin = maxKeysInRow * 4; // 2px margin on each side
        final keySize = ((availW - totalMargin) / maxKeysInRow).clamp(
          32.0,
          44.0,
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(totalRows, (rowIdx) {
              final startIdx = rowIdx * lettersPerRow;
              final endIdx = min(
                startIdx + lettersPerRow,
                _keyboardLetters.length,
              );
              final rowLetters = _keyboardLetters.sublist(startIdx, endIdx);

              // Last row includes backspace button
              final isLastRow = rowIdx == totalRows - 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...rowLetters.map((kl) => _buildKeyTile(kl, keySize)),
                    if (isLastRow) ...[
                      const SizedBox(width: 4),
                      _buildBackspaceKey(keySize),
                    ],
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildKeyTile(_KeyboardLetter kl, double keySize) {
    final remaining = kl.total - kl.used;
    final isDisabled = remaining <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MyKeyBoard(
        width: keySize,
        height: keySize,
        borderRadius: 8,
        depth: 3,
        padding: EdgeInsets.zero,
        buttonColor: isDisabled
            ? const Color(0xFFB0C4DE)
            : const Color(0xFF3B7DD8),
        backButtonColor: isDisabled
            ? const Color(0xFF8FA8C8)
            : const Color(0xFF2A5FA8),
        onPressed: isDisabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                _placeLetter(kl);
              },
        child: Stack(
          children: [
            Center(
              child: Text(
                kl.char,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: keySize * 0.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (remaining > 0 && kl.total > 1)
              Positioned(
                top: 1,
                right: 3,
                child: Text(
                  '$remaining',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: keySize * 0.22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(double keySize) {
    return MyKeyBoard(
      width: keySize + 4,
      height: keySize,
      borderRadius: 8,
      depth: 3,
      padding: EdgeInsets.zero,
      buttonColor: const Color(0xFFCC3333),
      backButtonColor: const Color(0xFF9A1A1A),
      onPressed: () {
        HapticFeedback.lightImpact();
        _removeLast();
      },
      child: Center(
        child: Icon(
          Icons.backspace_rounded,
          color: Colors.white,
          size: keySize * 0.45,
        ),
      ),
    );
  }

  // ════════════════════════════════════
  //  LETTER PLACEMENT LOGIC
  // ════════════════════════════════════

  /// Place a letter in the next empty cell of the selected word
  void _placeLetter(_KeyboardLetter kl) {
    if (_selectedWordIdx == null) return;
    final word = _words[_selectedWordIdx!];

    // Find next empty cell
    for (final letter in word.letters) {
      final key = '${letter.x},${letter.y}';
      if (!_placedLetters.containsKey(key)) {
        setState(() {
          _placedLetters[key] = kl.char;
          kl.used++;
        });
        return;
      }
    }
  }

  /// Remove last placed letter from selected word
  void _removeLast() {
    if (_selectedWordIdx == null) return;
    final word = _words[_selectedWordIdx!];

    // Find last filled cell (go backwards)
    for (int i = word.letters.length - 1; i >= 0; i--) {
      final letter = word.letters[i];
      final key = '${letter.x},${letter.y}';
      if (_placedLetters.containsKey(key)) {
        final removedChar = _placedLetters[key]!;
        // Return to keyboard
        for (final kl in _keyboardLetters) {
          if (kl.char == removedChar && kl.used > 0) {
            setState(() {
              _placedLetters.remove(key);
              kl.used--;
            });
            return;
          }
        }
        // If no keyboard letter found, still remove
        setState(() => _placedLetters.remove(key));
        return;
      }
    }
  }

  // ════════════════════════════════════
  //  RESULTS (after submit)
  // ════════════════════════════════════
  Widget _buildClueResult(int i) {
    final word = _words[i];
    final isCorrect = i < _wordResults.length && _wordResults[i];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFE5FFEE) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect ? const Color(0xFF1BD259) : const Color(0xFFFF3700),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCorrect
                  ? const Color(0xFF1BD259)
                  : const Color(0xFFFF3700),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isHorizontal(word) ? '→' : '↓',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isCorrect
                  ? const Color(0xFF1BD259)
                  : const Color(0xFFFF3700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: buildRichTextFromHtml(
              '${word.word}: ${word.question ?? ''}',
              baseStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
              ),
            ),
          ),
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: isCorrect
                ? const Color(0xFF1BD259)
                : const Color(0xFFFF3700),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════
  //  SUBMIT / CHECK
  // ════════════════════════════════════
  void _submit() {
    HapticFeedback.mediumImpact();

    final results = <bool>[];
    for (final word in _words) {
      bool wordCorrect = true;
      for (final letter in word.letters) {
        final key = '${letter.x},${letter.y}';
        final expected = letter.char.toUpperCase();
        final placed = _placedLetters[key]?.toUpperCase() ?? '';
        if (placed != expected) wordCorrect = false;
      }
      results.add(wordCorrect);
    }

    setState(() {
      _submitted = true;
      _wordResults = results;
    });
    widget.onAnswered(results);
  }
}

/// Keyboard letter with usage tracking
class _KeyboardLetter {
  final String char;
  final int total;
  int used;

  _KeyboardLetter({required this.char, required this.total, this.used = 0});
}
