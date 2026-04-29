import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/feature/auth/data/choosing_level_model.dart';

const _kUserLevel = 'selected_level_index';

/// Levels: 0 = Начальный (level 1), 1 = Средний (level 2), 2 = Продвинутый (level 3)
final selectedLevelProvider =
    NotifierProvider<SelectedLevelNotifier, ChoosingLevelModel?>(
      SelectedLevelNotifier.new,
    );

class SelectedLevelNotifier extends Notifier<ChoosingLevelModel?> {
  static const _levels = [
    ChoosingLevelModel(grade: 'Начальный', description: 'Знаю несколько слов'),
    ChoosingLevelModel(
      grade: 'Средний',
      description: 'Знаю много, но хочу больше',
    ),
    ChoosingLevelModel(
      grade: 'Продвинутый',
      description: 'Хочу учить сложные слова',
    ),
  ];

  @override
  ChoosingLevelModel? build() {
    // Load saved level on init
    _loadSaved();
    return null;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kUserLevel);
    if (idx != null && idx >= 0 && idx < _levels.length) {
      state = _levels[idx];
    }
  }

  Future<void> set(ChoosingLevelModel? value) async {
    state = value;
    if (value != null) {
      final idx = _levels.indexWhere((l) => l.grade == value.grade);
      if (idx >= 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kUserLevel, idx);
      }
    }
  }

  /// Returns the saved level as 1/2/3 (for JSON filtering), or null if not set.
  static Future<int?> getSavedLevelValue() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kUserLevel);
    if (idx == null) return null;
    return idx + 1; // index 0→level 1, index 1→level 2, index 2→level 3
  }
}
