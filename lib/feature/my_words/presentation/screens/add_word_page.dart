import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/feature/my_words/presentation/screens/edit_word_page.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/import_words_dialog.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class AddWordPage extends StatefulWidget {
  const AddWordPage({super.key});

  @override
  State<AddWordPage> createState() => _AddWordPageState();
}

class _AddWordPageState extends State<AddWordPage> {
  final TextEditingController _wordOriginalController = TextEditingController();
  final TextEditingController _wordTranslateController =
      TextEditingController();
  final TextEditingController _categoryNameController = TextEditingController();

  /// Mirrors Unity's `LastSave` flag — prevents duplicate saves.
  bool _lastSave = true;

  /// List of added words: [{english, translation}]
  final List<Map<String, String>> _addedWords = [];

  @override
  void initState() {
    super.initState();
    _wordOriginalController.addListener(_onFieldChanged);
    _wordTranslateController.addListener(_onFieldChanged);
    _categoryNameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _wordOriginalController.dispose();
    _wordTranslateController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  // ── Validation (mirrors Unity's CheckWord) ──

  /// Validates that the word contains only letters, spaces, commas, apostrophes, or hyphens.
  bool _isValidWord(String word) {
    if (word.trim().isEmpty) return false;
    for (int i = 0; i < word.length; i++) {
      final ch = word[i];
      if (!RegExp(r'[\p{L}\s,\x27\-]', unicode: true).hasMatch(ch)) {
        return false;
      }
    }
    return true;
  }

  /// Add button is active when both fields have >= 2 chars (Unity logic).
  double _getAddButtonDepth() {
    return (_wordOriginalController.text.length >= 2 &&
            _wordTranslateController.text.length >= 2)
        ? 3
        : 0;
  }

  /// Save is allowed when there are words and category name >= 3 chars.
  /// Also checks Unity's LastSave flag to prevent double saves.
  bool _canSave() =>
      _addedWords.isNotEmpty &&
      _categoryNameController.text.length >= 3 &&
      !_lastSave;

  // ── Actions ──

  /// Add word to the list (mirrors Unity UIAddWordLesson click handler).
  void _addWord() {
    HapticFeedback.lightImpact();
    final original = _wordOriginalController.text.trim();
    final translation = _wordTranslateController.text.trim();

    // Validate length >= 2 (Unity logic)
    if (original.length < 2 || translation.length < 2) return;

    // Validate word characters (Unity CheckWord)
    if (!_isValidWord(original) || !_isValidWord(translation)) {
      _showSnackBar('invalid_word_name'.tr(), Colors.red);
      return;
    }

    // Check for duplicates (Unity logic)
    final isDuplicate = _addedWords.any((w) => w['english'] == original);
    if (isDuplicate) {
      _showSnackBar('duplicate_word'.tr(), Colors.orange);
      return;
    }

    setState(() {
      _addedWords.add({'english': original, 'translation': translation});
      _wordOriginalController.clear();
      _wordTranslateController.clear();
      _lastSave = false; // Enable save button
    });
  }

  /// Save lesson (mirrors Unity SavePak).
  /// Unity: serializes LessonTableJson → writes to .vozha file
  /// Flutter: serializes ImportedLesson → writes to documents/lessons/ as JSON
  Future<void> _saveLesson() async {
    HapticFeedback.lightImpact();

    if (_lastSave) return;

    // Validate category name >= 3 chars (Unity UIErrorNameMyLesson)
    if (_categoryNameController.text.trim().length < 3) {
      _showSnackBar('category_name_too_short'.tr(), Colors.red);
      return;
    }

    // Get current user name
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? '';

    // Build ImportedLesson (mirrors Unity LessonTableJson)
    final lesson = ImportedLesson(
      name: _categoryNameController.text.trim(),
      userCreator: userName,
      words: _addedWords.asMap().entries.map((entry) {
        return ImportedWord(
          id: entry.key,
          wordOriginal: entry.value['english']!,
          wordTranslate: entry.value['translation']!,
        );
      }).toList(),
    );

    // Save to documents/lessons/ directory as JSON
    // (mirrors Unity: StaticArchive.WriteToFile(PakPath, FilesData, ...))
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final lessonsDir = Directory('${appDir.path}/lessons');
      if (!await lessonsDir.exists()) {
        await lessonsDir.create(recursive: true);
      }

      final fileName =
          '${lesson.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.json';
      final file = File('${lessonsDir.path}/$fileName');
      await file.writeAsString(json.encode(lesson.toJson()));

      setState(() {
        _lastSave = true;
      });

      _showSnackBar('saved_successfully'.tr(), Colors.green);
    } catch (e) {
      _showSnackBar('save_error'.tr(), Colors.red);
    }
  }

  /// Show exit confirmation dialog (mirrors Unity UIExitFromAddLesson).
  void _showExitConfirmation() {
    if (_addedWords.isEmpty || _lastSave) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'unsaved_changes'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'discard'.tr(),
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _saveLesson();
              if (_lastSave && mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'save_lesson'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAFF),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _buildHeader(),
              const SizedBox(height: 10),

              // ── Category Name Input ──
              _buildCategoryInput(),
              const SizedBox(height: 20),

              // ── Word Input Card ──
              _buildWordInputCard(),
              const SizedBox(height: 20),

              // ── Added Words List ──
              ..._buildWordsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _showExitConfirmation,
          child: const Icon(Icons.arrow_back_ios, size: 28),
        ),
        Text(
          'add_word_title'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        MyButton(
          backButtonColor: _canSave()
              ? const Color(0xFF15803D)
              : const Color(0xFFCDD5DF),
          buttonColor: _canSave()
              ? const Color(0xFF22C55E)
              : const Color(0xFFE3E8EF),
          depth: 3,
          height: 30,
          borderRadius: 7,
          padding: EdgeInsets.zero,
          onPressed: _saveLesson,
          child: Row(
            children: [
              const Icon(Icons.save_outlined, color: Colors.white, size: 20),
              Text(
                'save_lesson'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _categoryNameController,
          decoration: InputDecoration(
            hintText: 'category_name_hint'.tr(),
            hintStyle: TextStyle(color: Colors.grey.shade500),
          ),
        ),
        Text(
          'category_name_label'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildWordInputCard() {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0xFFCDD5DF), blurRadius: 1, spreadRadius: 1),
        ],
        border: Border.all(color: const Color(0xFFCDD5DF)),
      ),
      child: Column(
        children: [
          // Original word input
          _buildTextInput(
            controller: _wordOriginalController,
            hintText: 'enter_word_original'.tr(),
          ),
          const SizedBox(height: 20),

          // Translation input
          _buildTextInput(
            controller: _wordTranslateController,
            hintText: 'enter_translation'.tr(),
          ),
          const SizedBox(height: 20),

          // Add button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MyButton(
                depth: _getAddButtonDepth(),
                borderRadius: 8,
                backButtonColor: Colors.blue.shade700,
                buttonColor: Colors.blue.shade500,
                padding: EdgeInsets.zero,
                onPressed: _addWord,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 10,
                  ),
                  child: Text(
                    'add_word_button'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFCDD5DF), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFCDD5DF), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF84CAFF), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  List<Widget> _buildWordsList() {
    return _addedWords.asMap().entries.map((entry) {
      final index = entry.key;
      final word = entry.value;
      return _SwipeRevealWordCard(
        key: ValueKey('${word['english']}_$index'),
        word: word,
        onDelete: () {
          HapticFeedback.lightImpact();
          setState(() {
            _addedWords.removeAt(index);
            _lastSave = false;
          });
        },
        onEdit: () {
          HapticFeedback.lightImpact();
          _showEditDialog(index, word);
        },
      );
    }).toList();
  }

  /// Navigate to edit word page (mirrors Unity UIEditWord)
  Future<void> _showEditDialog(int index, Map<String, String> word) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditWordPage(
          wordOriginal: word['english'] ?? '',
          wordTranslation: word['translation'] ?? '',
          wordTranscription: word['transcription'] ?? '',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _addedWords[index] = {
          'english': result['english'] ?? word['english'] ?? '',
          'translation': result['translation'] ?? word['translation'] ?? '',
          if (result['transcription'] != null &&
              result['transcription']!.isNotEmpty)
            'transcription': result['transcription']!,
          if (result['imagePath'] != null) 'imagePath': result['imagePath']!,
        };
        _lastSave = false;
      });
    }
  }
}

/// Swipe-to-reveal word card (mirrors Unity UIItemMyLesson).
/// Swipe left to reveal Edit + Delete buttons behind the card.
class _SwipeRevealWordCard extends StatefulWidget {
  final Map<String, String> word;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _SwipeRevealWordCard({
    super.key,
    required this.word,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_SwipeRevealWordCard> createState() => _SwipeRevealWordCardState();
}

class _SwipeRevealWordCardState extends State<_SwipeRevealWordCard>
    with SingleTickerProviderStateMixin {
  /// Max horizontal slide distance (Unity: -540 localPosition.x)
  static const double _maxSlide = 140.0;

  /// Threshold to snap open (Unity: -300 of -540 ≈ 55%)
  static const double _snapThreshold = 0.55;

  late AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // Negative dx = swipe left → open; positive dx = swipe right → close
    final delta = details.primaryDelta ?? 0;
    _controller.value = (_controller.value - delta / _maxSlide).clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_controller.value > _snapThreshold) {
      _controller.animateTo(1.0);
      _isOpen = true;
    } else {
      _controller.animateTo(0.0);
      _isOpen = false;
    }
  }

  void _close() {
    _controller.animateTo(0.0);
    _isOpen = false;
  }

  /// Subtle shake animation on tap (hint that card is swipeable)
  Future<void> _shake() async {
    HapticFeedback.lightImpact();
    await _controller.animateTo(
      0.15,
      duration: const Duration(milliseconds: 100),
    );
    await _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.elasticOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            // ── Background: Edit + Delete buttons ──
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit button (blue)
                  GestureDetector(
                    onTap: () {
                      _close();
                      widget.onEdit();
                    },
                    child: Container(
                      width: 65,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit, size: 18, color: Colors.white),
                          const SizedBox(height: 2),
                          Text(
                            'edit'.tr(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Delete button (red)
                  GestureDetector(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: Container(
                      width: 65,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'delete'.tr(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Foreground: sliding word card ──
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-_maxSlide * _controller.value, 0),
                  child: child,
                );
              },
              child: GestureDetector(
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                onTap: () {
                  if (_isOpen) {
                    _close();
                  } else {
                    _shake();
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFCDD5DF), width: 3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    child: Row(
                      children: [
                        // Image placeholder (Unity style)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image,
                            color: Color(0xFF60A5FA),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.word['english']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.word['translation']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF8A97AB),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Arrow rotates when swiped (Unity: SmoothRotateZ 180°)
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _controller.value * 3.14159, // 180°
                              child: child,
                            );
                          },
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.black,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
