import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_test_models.dart';

/// Categorize game — sort items into category buckets by drag.
/// Unity: UICategorizeGame + CategorizeUI
///
/// Layout: Each category = row with [Label | DropArea]
/// Pool at bottom with shuffled items
/// Check: verifies each category has exactly correct items
class CategorizeGameWidget extends StatefulWidget {
  final CourseTestQuestion question;
  final String basePath;
  final void Function(List<bool> results) onAnswered;

  const CategorizeGameWidget({
    required this.question,
    required this.basePath,
    required this.onAnswered,
    super.key,
  });

  @override
  State<CategorizeGameWidget> createState() => _CategorizeGameWidgetState();
}

class _CategorizeGameWidgetState extends State<CategorizeGameWidget> {
  // Unity: correctPlacements[category] = items
  late Map<String, List<String>> _correctPlacements;
  late Map<String, List<String>> _userPlacements;
  late List<String> _pool;
  // Unity: spritePath per category
  final Map<String, String> _categorySprites = {};
  bool _submitted = false;
  Map<String, bool> _categoryResults = {};

  @override
  void initState() {
    super.initState();
    _correctPlacements = {};
    _userPlacements = {};
    _pool = [];

    // Unity: foreach(ds in DataSources) { category=ds.Category??ds.Text }
    for (final ds in widget.question.dataSources) {
      final categoryName = ds.category ?? ds.text;
      _correctPlacements[categoryName] = List.from(ds.items);
      _userPlacements[categoryName] = [];
      _pool.addAll(ds.items);

      // Unity: spritePath = Path.Combine(CurrentPath, ds.SpriteName)
      final sprite = ds.spriteName ?? '';
      if (sprite.isNotEmpty) {
        final fullPath = '${widget.basePath}/$sprite';
        _categorySprites[categoryName] = fullPath;
      }
    }
    // Unity: ShuffleList(allItems)
    _pool.shuffle();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _correctPlacements.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category rows (Unity: [Label | DropArea] horizontal layout)
        ...categories.map((cat) {
          final userItems = _userPlacements[cat] ?? [];
          final catResult = _categoryResults[cat];

          // Unity: ShowContainerResult → green/red background
          Color rowBg = const Color(0xFFF5F5FA);
          Color rowBorder = const Color(0xFFE0E0E0);
          if (_submitted && catResult != null) {
            rowBg = catResult
                ? const Color(0xFFE5FFEE)
                : const Color(0xFFFFF0F0);
            rowBorder = catResult
                ? const Color(0xFF1BD259)
                : const Color(0xFFFF3700);
          }

          return DragTarget<String>(
            onWillAcceptWithDetails: (_) => !_submitted,
            onAcceptWithDetails: (details) {
              setState(() {
                _userPlacements[cat]!.add(details.data);
                _pool.remove(details.data);
              });
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isHovering ? const Color(0xFFE3F2FD) : rowBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isHovering ? const Color(0xFF2196F3) : rowBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Category label (Unity: categoryLabelWidth=200)
                    Container(
                      width: 120,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Unity: if hasSprite → show image above text
                          if (_categorySprites.containsKey(cat))
                            _buildCategoryImage(_categorySprites[cat]!),
                          Text(
                            cat,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Right: Drop area with placed items
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 50),
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...userItems.map((item) {
                              return GestureDetector(
                                onTap: _submitted
                                    ? null
                                    : () {
                                        setState(() {
                                          _userPlacements[cat]!.remove(item);
                                          _pool.add(item);
                                        });
                                      },
                                child: Chip(
                                  label: Text(
                                    item,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  backgroundColor: const Color(0xFFE3F2FD),
                                  deleteIcon: _submitted
                                      ? null
                                      : const Icon(Icons.close, size: 16),
                                  onDeleted: _submitted
                                      ? null
                                      : () {
                                          setState(() {
                                            _userPlacements[cat]!.remove(item);
                                            _pool.add(item);
                                          });
                                        },
                                ),
                              );
                            }),
                            if (userItems.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Drop here',
                                  style: TextStyle(
                                    color: Color(0xFFBDBDBD),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),

        const SizedBox(height: 12),

        // Pool area (Unity: bottom pool with FlowWrapLayout, rounded corners)
        if (!_submitted && _pool.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _pool.map((item) {
                return Draggable<String>(
                  data: item,
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
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _buildItemChip(item),
                  ),
                  child: _buildItemChip(item),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 12),

        // CHECK button
        if (!_submitted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pool.isEmpty ? _submit : null,
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

  /// Unity: category label with sprite image (vertical layout: image + text)
  Widget _buildCategoryImage(String path) {
    final file = File(path);
    if (!file.existsSync()) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildItemChip(String item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF999999)),
      ),
      child: Text(
        item,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _submit() {
    // Unity: checks correctItems.All(item => currentItems.Contains(item)) &&
    //        currentItems.All(item => correctItems.Contains(item))
    final results = <bool>[];
    final catResults = <String, bool>{};

    for (final cat in _correctPlacements.keys) {
      final correct = _correctPlacements[cat]!;
      final user = _userPlacements[cat]!;
      final isCorrect =
          correct.every((i) => user.contains(i)) &&
          user.every((i) => correct.contains(i));
      results.add(isCorrect);
      catResults[cat] = isCorrect;
    }

    // Unity: if pool has items left, add false
    if (_pool.isNotEmpty) {
      results.add(false);
    }

    setState(() {
      _submitted = true;
      _categoryResults = catResults;
    });
    widget.onAnswered(results);
  }
}
