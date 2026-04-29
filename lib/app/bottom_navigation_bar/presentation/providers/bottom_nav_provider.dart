import 'package:flutter_riverpod/flutter_riverpod.dart';

// Notifier class
class BottomNavNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final bottomNavProvider = NotifierProvider<BottomNavNotifier, int>(BottomNavNotifier.new);
