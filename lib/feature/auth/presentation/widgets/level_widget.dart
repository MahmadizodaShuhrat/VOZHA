import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/feature/auth/data/choosing_level_model.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/selected_level_provider.dart';

final selectedIndexProvider = NotifierProvider<SelectedIndexNotifier, int?>(
  SelectedIndexNotifier.new,
);

class SelectedIndexNotifier extends Notifier<int?> {
  @override
  int? build() {
    _loadSavedLevel();
    return null;
  }

  Future<void> _loadSavedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('user_level');
    if (savedLevel != null && savedLevel >= 1 && savedLevel <= 3) {
      state = savedLevel - 1; // level 1 = index 0
    } else {
      state = 0; // default: якум урован (Начальный)
    }
  }

  void set(int? value) => state = value;
}

class LevelWidget extends ConsumerStatefulWidget {
  final ChoosingLevelModel model;
  final int index;
  const LevelWidget({super.key, required this.model, required this.index});

  @override
  ConsumerState<LevelWidget> createState() => _LevelWidgetState();
}

class _LevelWidgetState extends ConsumerState<LevelWidget> {
  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final isSelected = selectedIndex == widget.index;
    final sourses = [
      ChoosingLevelModel(
        grade: 'Начальный',
        description: 'Знаю несколько слов',
      ),
      ChoosingLevelModel(
        grade: 'Средний',
        description: 'Знаю много, но хочу больше',
      ),
      ChoosingLevelModel(
        grade: 'Продвинутый',
        description: 'Хочу учить сложные слова',
      ),
    ];
    return GestureDetector(
      onTap: () {
        ref.read(selectedIndexProvider.notifier).set(widget.index);
        ref.read(selectedLevelProvider.notifier).set(sourses[widget.index]);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: 20),
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.model.grade,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                ),
                Text(
                  widget.model.description,
                  style: TextStyle(fontWeight: FontWeight.w100, fontSize: 15),
                ),
              ],
            ),
            if (isSelected)
              Icon(Icons.check_box, color: Colors.blue, size: 30)
            else
              SizedBox(),
          ],
        ),
      ),
    );
  }
}
