import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dotsProvider = NotifierProvider<DotsNotifier, DotsState>(
  DotsNotifier.new,
);

class DotsNotifier extends Notifier<DotsState> {
  @override
  DotsState build() {
    return DotsState(
      dotColors: List.generate(20, (_) => Color(0xFFB2DDFF)),
      currentIndex: 0,
    );
  }

  int get currentIndex => state.currentIndex;
  int get totalDots => state.dotColors.length;

  void markAnswer({required bool isCorrect}) {
    if (state.currentIndex >= state.dotColors.length) return;
    final newColors = List<Color>.from(state.dotColors);
    newColors[state.currentIndex] = isCorrect
        ? Color(0xFF22C55E)
        : Color(0xFFF87171);
    state = DotsState(
      dotColors: newColors,
      currentIndex: state.currentIndex + 1,
    );
  }

  void reset() {
    state = DotsState(
      dotColors: List.generate(20, (_) => Color(0xFFB2DDFF)),
      currentIndex: 0,
    );
  }

  void resetWithCount(int total) {
    state = DotsState(
      dotColors: List.generate(total, (_) => Color(0xFFB2DDFF)),
      currentIndex: 0,
    );
  }
}

final selectedAnswerProvider =
    NotifierProvider<SelectedAnswerNotifier, String?>(
      SelectedAnswerNotifier.new,
    );

class SelectedAnswerNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

class DotsState {
  final List<Color> dotColors;
  final int currentIndex;

  DotsState({required this.dotColors, required this.currentIndex});

  DotsState copyWith({List<Color>? dotColors, int? currentIndex}) {
    return DotsState(
      dotColors: dotColors ?? this.dotColors,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
