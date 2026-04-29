import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/game_ui_providers.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/game_page.dart';
import 'package:vozhaomuz/feature/games/presentation/widgets/close_page.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/learning_session_provider.dart';

final countdownProvider = NotifierProvider.autoDispose<CountdownNotifier, int>(
  CountdownNotifier.new,
);

class CountdownNotifier extends Notifier<int> {
  @override
  int build() => 3;
  void set(int value) => state = value;
  void decrement() => state--;
}

class CountdownPage extends ConsumerStatefulWidget {
  const CountdownPage({super.key});

  @override
  ConsumerState<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends ConsumerState<CountdownPage> {
  @override
  void initState() {
    super.initState();
    // Defer provider mutation: pushAndRemoveUntil from ResultGamePage
    // mounts this page DURING the ancestor's build, and Riverpod
    // forbids modifying state mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(allowGameFlowPopProvider.notifier).set(false);
      ref.read(learningSessionProvider.notifier).startSession();
      ref.read(countdownProvider.notifier).set(3);
      _startCountdown();
    });
  }

  void _startCountdown() async {
    while (ref.read(countdownProvider) > 0) {
      await Future.delayed(Duration(seconds: 1));
      ref.read(countdownProvider.notifier).decrement();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GamePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(countdownProvider);
    return WillPopScope(
      onWillPop: () async {
        if (ref.read(allowGameFlowPopProvider)) return true;
        showExitConfirmationDialog(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Color(0xFFEEF2F6),
              borderRadius: BorderRadius.circular(75),
            ),
            alignment: Alignment.center,
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 65,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
