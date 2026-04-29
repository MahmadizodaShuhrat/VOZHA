import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Callback when a card is swiped.
/// [direction] is -1 for left, +1 for right.
/// [item] is the swiped data item.
typedef SwipeCallback<T> = void Function(int direction, T item);

/// A Tinder-style swipeable card stack widget.
///
/// Uses pure Flutter animations (no external packages) for maximum
/// performance on low-end devices. GPU-composited via [Transform].
class SwipeCardStack<T> extends StatefulWidget {
  /// List of data items to display as cards.
  final List<T> items;

  /// Builder for the card content given a data item and its index.
  final Widget Function(BuildContext context, T item, int index) cardBuilder;

  /// Called when a card is swiped away.
  final SwipeCallback<T>? onSwiped;

  /// Called when the card stack is empty (all swiped).
  final VoidCallback? onEmpty;

  /// Called when a card starts being dragged (for e.g. audio playback).
  final void Function(T item)? onCardAppeared;

  /// Called when undo is triggered, passing the restored item and its
  /// original swipe direction (-1 left, +1 right).
  final void Function(T item, int direction)? onUndo;

  /// Called when the audio button is tapped on the current card.
  final void Function(T item)? onAudioTap;

  /// Distance threshold (in px) to trigger swipe-away vs snap-back.
  final double swipeThreshold;

  /// Maximum rotation angle (radians) during drag.
  final double maxRotation;

  const SwipeCardStack({
    super.key,
    required this.items,
    required this.cardBuilder,
    this.onSwiped,
    this.onEmpty,
    this.onCardAppeared,
    this.onUndo,
    this.onAudioTap,
    this.swipeThreshold = 100.0,
    this.maxRotation = 0.35, // ~20 degrees
  });

  @override
  State<SwipeCardStack<T>> createState() => SwipeCardStackState<T>();
}

class SwipeCardStackState<T> extends State<SwipeCardStack<T>>
    with TickerProviderStateMixin {
  /// Current top-card index in [widget.items].
  int _currentIndex = 0;

  // ── Drag state ──────────────────────────────────────────────
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  // ── Animations ──────────────────────────────────────────────
  late AnimationController _flyAwayCtrl;
  late AnimationController _snapBackCtrl;
  Animation<Offset>? _flyAwayAnim;
  Animation<Offset>? _snapBackAnim;

  // ── Undo stack ──────────────────────────────────────────────
  final List<T> _undoStack = [];
  final List<int> _undoDirections = []; // direction of each swiped card

  @override
  void initState() {
    super.initState();
    _flyAwayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addStatusListener(_onFlyAwayDone);

    _snapBackCtrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          if (_snapBackAnim != null) {
            setState(() => _dragOffset = _snapBackAnim!.value);
          }
        });

    // Trigger onCardAppeared for the very first card after build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.items.isNotEmpty && _currentIndex < widget.items.length) {
        widget.onCardAppeared?.call(widget.items[_currentIndex]);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SwipeCardStack<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the items list changes (e.g. subcategory switch), reset state
    // and trigger onCardAppeared for the new first card.
    if (!_listEquals(widget.items, oldWidget.items)) {
      setState(() {
        _currentIndex = 0;
        _dragOffset = Offset.zero;
        _undoStack.clear();
        _undoDirections.clear();
      });
      // Cancel any in-progress animations
      if (_flyAwayCtrl.isAnimating) _flyAwayCtrl.stop();
      if (_snapBackCtrl.isAnimating) _snapBackCtrl.stop();
      // Auto-play audio for the new first card
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.items.isNotEmpty && _currentIndex < widget.items.length) {
          widget.onCardAppeared?.call(widget.items[_currentIndex]);
        }
      });
    }
  }

  /// Shallow list equality check (by identity, not deep equality).
  bool _listEquals(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _flyAwayCtrl.dispose();
    _snapBackCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  PUBLIC API (for external undo / auto-swipe buttons)
  // ═══════════════════════════════════════════════════════════════

  /// Programmatically swipe the top card left.
  void swipeLeft() => _autoSwipe(-1);

  /// Programmatically swipe the top card right.
  void swipeRight() => _autoSwipe(1);

  /// Undo the last swipe, restoring the card to the top.
  void undo() {
    if (_undoStack.isEmpty || _currentIndex <= 0) return;
    final restoredItem = _undoStack.removeLast();
    final restoredDirection = _undoDirections.removeLast();
    setState(() {
      _currentIndex--;
      _dragOffset = Offset.zero;
    });
    widget.onUndo?.call(restoredItem, restoredDirection);
  }

  bool get canUndo => _undoStack.isNotEmpty && _currentIndex > 0;
  int get currentIndex => _currentIndex;
  int get remainingCards => widget.items.length - _currentIndex;

  // ═══════════════════════════════════════════════════════════════
  //  DRAG HANDLING
  // ═══════════════════════════════════════════════════════════════

  void _onPanStart(DragStartDetails _) {
    if (_flyAwayCtrl.isAnimating || _snapBackCtrl.isAnimating) return;
    _isDragging = true;
    _snapBackCtrl.stop();
    _flyAwayCtrl.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() => _dragOffset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final dx = _dragOffset.dx;
    if (dx.abs() >= widget.swipeThreshold) {
      // Fly away
      _startFlyAway(dx > 0 ? 1 : -1, details.velocity.pixelsPerSecond);
    } else {
      // Snap back
      _startSnapBack();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  ANIMATIONS
  // ═══════════════════════════════════════════════════════════════

  void _startFlyAway(int direction, Offset velocity) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = direction * (screenWidth * 1.5);
    final targetY = _dragOffset.dy + velocity.dy * 0.15;

    _flyAwayAnim = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, targetY),
    ).animate(CurvedAnimation(parent: _flyAwayCtrl, curve: Curves.easeOut));

    _flyAwayCtrl.forward(from: 0);

    // Add listener for smooth animation
    _flyAwayCtrl.addListener(_onFlyAwayTick);
  }

  void _onFlyAwayTick() {
    if (_flyAwayAnim != null) {
      setState(() => _dragOffset = _flyAwayAnim!.value);
    }
  }

  void _onFlyAwayDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _flyAwayCtrl.removeListener(_onFlyAwayTick);

      final direction = _dragOffset.dx > 0 ? 1 : -1;
      final swipedItem = widget.items[_currentIndex];

      _undoStack.add(swipedItem);
      _undoDirections.add(direction);

      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
      });

      widget.onSwiped?.call(direction, swipedItem);

      if (_currentIndex >= widget.items.length) {
        widget.onEmpty?.call();
      } else {
        widget.onCardAppeared?.call(widget.items[_currentIndex]);
      }
    }
  }

  void _startSnapBack() {
    _snapBackAnim = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _snapBackCtrl, curve: const SpringCurve()),
    );

    _snapBackCtrl.forward(from: 0);
  }

  void _autoSwipe(int direction) {
    if (_currentIndex >= widget.items.length) return;
    if (_flyAwayCtrl.isAnimating) return;

    _isDragging = false;
    _dragOffset = Offset.zero;
    _startFlyAway(direction, Offset.zero);
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.items.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Color(0xFF2E90FA),
            ),
            const SizedBox(height: 16),
            Text(
              'all_words_learned_title'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // Show up to 3 stacked cards (back → front)
    final visibleCount = math.min(3, widget.items.length - _currentIndex);
    final children = <Widget>[];

    for (int i = visibleCount - 1; i >= 0; i--) {
      final itemIndex = _currentIndex + i;
      if (itemIndex >= widget.items.length) continue;

      final isTop = i == 0;
      children.add(
        _buildCard(
          item: widget.items[itemIndex],
          index: itemIndex,
          stackIndex: i,
          isTop: isTop,
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              ...children,
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSwipeHints(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCard({
    required T item,
    required int index,
    required int stackIndex,
    required bool isTop,
  }) {
    // Back cards: progressively smaller and offset down
    final backScale = 1.0 - (stackIndex * 0.05);
    final backOffsetY = stackIndex * 10.0;

    if (!isTop) {
      // Background card — no interaction
      return Positioned.fill(
        child: Center(
          child: RepaintBoundary(
            child: Transform.translate(
              offset: Offset(0, backOffsetY),
              child: Transform.scale(
                scale: backScale,
                child: _cardContainer(
                  child: widget.cardBuilder(context, item, index),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Top card with drag interaction ──
    final angle =
        (_dragOffset.dx / MediaQuery.of(context).size.width) *
        widget.maxRotation;
    final dragProgress = (_dragOffset.dx.abs() / widget.swipeThreshold).clamp(
      0.0,
      1.0,
    );

    return Positioned.fill(
      child: Center(
        child: RepaintBoundary(
          child: Transform.translate(
            offset: _dragOffset,
            child: Transform.rotate(
              angle: angle,
              // Outer Stack: separates the drag-card from the audio button
              // so they NEVER compete in the same gesture arena.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Layer 1: Card with swipe overlays ──
                  // This inner Stack + GestureDetector handles ONLY dragging.
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _cardContainer(
                          child: widget.cardBuilder(context, item, index),
                        ),
                        // LEFT overlay — "МЕДОНАМ ✓"
                        if (_dragOffset.dx < 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _buildOverlay(
                                label: 'I_already_know'.tr().toUpperCase(),
                                icon: Icons.check_circle,
                                color: const Color(0xFF12B76A),
                                opacity: dragProgress,
                                alignment: Alignment.topRight,
                              ),
                            ),
                          ),
                        // RIGHT overlay — "ОМӮЗИШ 📖"
                        if (_dragOffset.dx > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _buildOverlay(
                                label: 'Learn'.tr().toUpperCase(),
                                icon: Icons.menu_book_rounded,
                                color: const Color(0xFF2E90FA),
                                opacity: dragProgress,
                                alignment: Alignment.topLeft,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ── Layer 2: Audio button ──
                  // Completely separate from the pan GestureDetector above.
                  // Uses Listener (raw pointer events) to bypass gesture arena entirely.
                  if (widget.onAudioTap != null)
                    Positioned(
                      top: 12,
                      right: 32,
                      child: _AudioButton(
                        onTap: () => widget.onAudioTap?.call(item),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }

  Widget _buildOverlay({
    required String label,
    required IconData icon,
    required Color color,
    required double opacity,
    required Alignment alignment,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignment == Alignment.topLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            end: alignment == Alignment.topLeft
                ? Alignment.centerRight
                : Alignment.centerLeft,
            colors: [
              color.withValues(alpha: 0.2 * opacity),
              Colors.transparent,
            ],
          ),
        ),
        child: Align(
          alignment: alignment + const Alignment(0, 0.15),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: alignment == Alignment.topLeft ? -0.35 : 0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeHints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _hintButton(
            icon: Icons.close_rounded,
            label: 'I_already_know'.tr(),
            color: const Color(0xFF12B76A),
            onTap: swipeLeft,
          ),
          if (canUndo)
            _hintButton(
              icon: Icons.undo_rounded,
              label: 'back'.tr(),
              color: Colors.grey,
              onTap: undo,
            ),
          _hintButton(
            icon: Icons.menu_book_rounded,
            label: 'Learn'.tr(),
            color: const Color(0xFF2E90FA),
            onTap: swipeRight,
          ),
        ],
      ),
    );
  }

  Widget _hintButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A spring-like curve for snap-back animation.
class SpringCurve extends Curve {
  const SpringCurve();

  @override
  double transformInternal(double t) {
    // Damped spring simulation approximation
    return 1 - math.pow(1 - t, 3) * math.cos(t * math.pi * 1.5);
  }
}

/// Audio-replay button that bypasses Flutter's gesture arena completely.
///
/// Uses [Listener] (raw pointer events) instead of [GestureDetector] so
/// it fires even when a parent [GestureDetector] with `onPan*` is competing
/// in the gesture arena. The button tracks pointer-down/up directly and
/// fires [onTap] on pointer-up if the finger hasn't moved far.
class _AudioButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AudioButton({required this.onTap});

  @override
  State<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<_AudioButton> {
  bool _pressed = false;
  Offset? _downPos;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _downPos = event.position;
        setState(() => _pressed = true);
      },
      onPointerUp: (event) {
        final distance = _downPos != null
            ? (event.position - _downPos!).distance
            : 0.0;
        setState(() => _pressed = false);
        // Only fire if finger didn't move far (it's a tap, not a drag)
        if (distance < 30) {
          widget.onTap();
        }
        _downPos = null;
      },
      onPointerCancel: (_) {
        setState(() => _pressed = false);
        _downPos = null;
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.volume_up_rounded,
            color: Color(0xFF2E90FA),
            size: 24,
          ),
        ),
      ),
    );
  }
}
