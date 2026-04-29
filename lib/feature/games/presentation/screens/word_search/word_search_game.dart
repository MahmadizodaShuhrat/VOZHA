import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/dots_progress_indicator.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'dart:math';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/data/models/model_result_page.dart';
import 'widgets/direction_arrow.dart';
import 'widgets/word_to_find_hint.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';

class WormyWordSearch extends ConsumerStatefulWidget {
  final String title;
  late final String wordToFind;
  final int wordId;
  final Function onSuccess;
  final Function onIDKTap;
  final Function onDifferentWordTap;

  WormyWordSearch({
    super.key,
    required this.title,
    required String wordToFind,
    required this.wordId,
    required this.onSuccess,
    required this.onIDKTap,
    required this.onDifferentWordTap,
  }) : wordToFind = wordToFind.toLowerCase();

  @override
  WormyWordSearchState createState() => WormyWordSearchState();
}

class WormyWordSearchState extends ConsumerState<WormyWordSearch> {
  final AudioPlayer player = AudioPlayer();
  final AudioPlayer _wsCorrectPlayer = AudioPlayer()..setPlaybackRate(1.2);
  final AudioPlayer _wsWrongPlayer = AudioPlayer()..setPlaybackRate(1.2);

  late List<List<String>> board;
  late List<Point<int>> wordPath;
  List<Point<int>> currentPath = [];
  final random = Random();
  bool showWordToFindHint = false;
  double cellSize = 0;
  Offset gridTopLeft = Offset.zero;

  @override
  void initState() {
    super.initState();
    _generateNewPuzzle();
  }

  @override
  void dispose() {
    player.dispose();
    _wsCorrectPlayer.dispose();
    _wsWrongPlayer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WormyWordSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordToFind != widget.wordToFind) {
      _generateNewPuzzle();
    }
  }

  void _generateNewPuzzle() {
    board = _generateEmptyBoard();
    wordPath = _generateRandomPath(widget.wordToFind.length);
    _placeWordOnBoard(wordPath);
    _fillRestOfBoardWithRandomLetters();
    currentPath.clear();
    showWordToFindHint = false;
  }

  List<List<String>> _generateEmptyBoard() {
    return List.generate(5, (_) => List.filled(5, ''));
  }

  List<Point<int>> _generateRandomPath(int length) {
    while (true) {
      final path = <Point<int>>[];
      Point<int> current = Point(random.nextInt(5), random.nextInt(5));
      path.add(current);

      const directions = [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)];

      for (int i = 1; i < length; i++) {
        final possibleMoves = directions
            .map((dir) => current + dir)
            .where(
              (next) =>
                  next.x >= 0 &&
                  next.x < 5 &&
                  next.y >= 0 &&
                  next.y < 5 &&
                  !path.contains(next),
            )
            .toList();

        if (possibleMoves.isEmpty) break;
        current = possibleMoves[random.nextInt(possibleMoves.length)];
        path.add(current);
      }

      if (path.length == length) return path;
    }
  }

  void _placeWordOnBoard(List<Point<int>> wordPath) {
    for (int i = 0; i < wordPath.length; i++) {
      final pos = wordPath[i];
      board[pos.x][pos.y] = widget.wordToFind[i];
    }
  }

  void _fillRestOfBoardWithRandomLetters() {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if (board[i][j].isEmpty) {
          board[i][j] = letters[random.nextInt(letters.length)];
        }
      }
    }
  }

  void _handlePanStart(DragStartDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final row = ((localPosition.dy - gridTopLeft.dy) / cellSize).floor();
    final col = ((localPosition.dx - gridTopLeft.dx) / cellSize).floor();

    if (row >= 0 && row < 5 && col >= 0 && col < 5) {
      setState(() {
        currentPath = [Point(row, col)];
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, BuildContext context) {
    if (currentPath.isEmpty) return;

    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final row = ((localPosition.dy - gridTopLeft.dy) / cellSize).floor();
    final col = ((localPosition.dx - gridTopLeft.dx) / cellSize).floor();

    if (row < 0 || row >= 5 || col < 0 || col >= 5) return;

    final newPoint = Point(row, col);
    final lastPoint = currentPath.last;

    // Check if adjacent horizontally or vertically
    final isAdjacent =
        (row == lastPoint.x &&
            (col == lastPoint.y - 1 || col == lastPoint.y + 1)) ||
        (col == lastPoint.y &&
            (row == lastPoint.x - 1 || row == lastPoint.x + 1));

    setState(() {
      if (isAdjacent) {
        if (currentPath.contains(newPoint)) {
          // Backtracking
          if (currentPath.length > 1 &&
              currentPath[currentPath.length - 2] == newPoint) {
            currentPath.removeLast();
          }
        } else {
          currentPath.add(newPoint);
        }
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final userWord = currentPath.map((p) => board[p.x][p.y]).join();
    final isCorrect = userWord == widget.wordToFind;
    final currentWord = widget.wordToFind;
    final currentTranslation = widget.title;
    final currentId = widget.wordId;
    ref
        .read(gameResultProvider.notifier)
        .addResult(
          word: currentWord,
          translation: currentTranslation,
          isCorrect: isCorrect,
          gameIndex: 7,
          wordId: currentId,
          gameName: GameNames.findTheWord,
        );
    if (isCorrect == true) {
      ref.read(dotsProvider.notifier).markAnswer(isCorrect: isCorrect);
      ref.read(currentWordIndexProvider.notifier).increment();
    }
    try {
      if (isCorrect) {
        _wsCorrectPlayer.stop();
        _wsCorrectPlayer.play(AssetSource('sounds/Accepted.mp3'));
      } else {
        _wsWrongPlayer.stop();
        _wsWrongPlayer.play(AssetSource('sounds/WrongStatus.mp3'));
      }
    } catch (e) {
      debugPrint('Audio error (ignored): $e');
    }
    Future.delayed(Duration(seconds: 1));
    if (isCorrect) {
      setState(() {
        showWordToFindHint = true;
      });
      widget.onSuccess();
    } else {
      setState(() {
        currentPath.clear();
      });
    }
  }

  Point<int> _getDirection(Point<int> from, Point<int> to) {
    return Point(to.x - from.x, to.y - from.y);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gridSize = screenWidth - 32; // учитываем padding 16 с каждой стороны

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(height: 50),
          // ═══ Карточка: верхняя часть (серая) + нижняя часть (белая) ═══
          // Верхняя часть — серая
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Color(0xFFEEF2F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Find_the_word".tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF697586),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF202939),
                  ),
                ),
              ],
            ),
          ),
          // Нижняя часть — белая с hint
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEF2F6), width: 4),
              ),
            ),
            child: Center(
              child: WordToFindHint(
                word: widget.wordToFind,
                show: showWordToFindHint,
              ),
            ),
          ),
          SizedBox(height: 20),
          // ═══ Тугмаҳо: "Намедонам" + "Вожаи дигар" ═══
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MyButton(
                  width: 130,
                  height: 35,
                  depth: 3,
                  padding: EdgeInsets.zero,
                  backButtonColor: showWordToFindHint
                      ? Color(0xFFEAB308)
                      : Color(0xFFEEF2F6),
                  buttonColor: showWordToFindHint
                      ? Color(0xFFFDE047)
                      : Colors.white,
                  borderRadius: 20,
                  child: Text(
                    showWordToFindHint ? "skip".tr() : "i_dont_know".tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF202939),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (showWordToFindHint) {
                      // Second click — skip the word
                      widget.onDifferentWordTap();
                    } else {
                      // First click — show hint
                      setState(() {
                        showWordToFindHint = true;
                      });
                      widget.onIDKTap();
                    }
                  },
                ),
                MyButton(
                  width: 130,
                  height: 35,
                  depth: 3,
                  padding: EdgeInsets.zero,
                  backButtonColor: Color(0xFF1570EF),
                  buttonColor: Color(0xFF2E90FA),
                  borderRadius: 20,
                  child: Text(
                    "Another_word".tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () => widget.onDifferentWordTap(),
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
          // ═══ Сетка бозӣ ═══
          SizedBox(
            width: gridSize,
            height: gridSize,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actualGridSize = min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                cellSize = actualGridSize / 5;
                gridTopLeft = Offset(
                  (constraints.maxWidth - actualGridSize) / 2,
                  (constraints.maxHeight - actualGridSize) / 2,
                );

                return Center(
                  child: GestureDetector(
                    onPanStart: (details) => _handlePanStart(details, context),
                    onPanUpdate: (details) =>
                        _handlePanUpdate(details, context),
                    onPanEnd: _handlePanEnd,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: actualGridSize,
                        height: actualGridSize,
                        child: Stack(
                          children: [
                            for (int row = 0; row < 5; row++)
                              for (int col = 0; col < 5; col++)
                                _buildCell(row, col),
                          ],
                        ),
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
  }

  Widget _buildCell(int row, int col) {
    final currentPoint = Point(row, col);
    final isInPath = currentPath.contains(currentPoint);
    final isFirst = isInPath && currentPath.first == currentPoint;

    Point<int>? direction;
    if (isInPath && !isFirst) {
      final pos = currentPath.indexOf(currentPoint);
      if (pos > 0) {
        direction = _getDirection(currentPath[pos - 1], currentPoint);
      }
    }
    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: isFirst
              ? Color(0xff84efaa)
              : isInPath
              ? Color(0xffbaf6d1)
              : Colors.white,
          border: Border.fromBorderSide(
            BorderSide(
              color: Colors.blueGrey[100]!,
              width: 0.7,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                board[row][col],
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (direction != null) DirectionArrow(direction: direction),
          ],
        ),
      ),
    );
  }
}
