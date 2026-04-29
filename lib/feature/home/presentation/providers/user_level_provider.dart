import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User's current English level (1-3).
/// Persisted in SharedPreferences as 'user_level'.
/// Mirrors Unity's DataResources.Level.
final userLevelProvider = NotifierProvider<UserLevelNotifier, int>(
  UserLevelNotifier.new,
);

class UserLevelNotifier extends Notifier<int> {
  static const _key = 'user_level';

  @override
  int build() {
    _load();
    return 1; // default level
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key);
    if (saved != null && saved >= 1 && saved <= 3) {
      state = saved;
    }
  }

  Future<void> setLevel(int level) async {
    if (level < 1 || level > 3) return;
    state = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, level);
  }
}
