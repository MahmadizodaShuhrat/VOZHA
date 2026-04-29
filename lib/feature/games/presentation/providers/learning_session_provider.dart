// lib/feature/home/presentation/providers/learning_session_provider.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Tracks the start time of a learning/repeat session for activity reporting.
class LearningSessionState {
  final DateTime? startTime;
  const LearningSessionState({this.startTime});
}

class LearningSessionNotifier extends Notifier<LearningSessionState> {
  @override
  LearningSessionState build() => const LearningSessionState();

  /// Call when user starts a learning/repeat session (e.g., CountdownPage).
  void startSession() {
    state = LearningSessionState(startTime: DateTime.now());
  }

  /// Returns the start time and resets the session.
  DateTime? endSession() {
    final start = state.startTime;
    state = const LearningSessionState();
    return start;
  }
}

final learningSessionProvider =
    NotifierProvider<LearningSessionNotifier, LearningSessionState>(
      LearningSessionNotifier.new,
    );
