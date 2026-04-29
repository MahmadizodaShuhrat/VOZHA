import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' hide AudioContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/utils/audio_helper.dart';

class AudioOption extends ConsumerStatefulWidget {
  final String audioPath;
  final String? categoryName;
  final int? categoryId;
  final bool isActive;
  final bool? isCorrect;
  final bool isLast;
  final VoidCallback onPressed;

  /// Shared player: если передан, все AudioOption используют один плеер
  /// и предыдущее аудио автоматически останавливается при тапе на другой вариант
  final AudioPlayer? sharedPlayer;

  const AudioOption({
    required this.audioPath,
    this.categoryName,
    this.categoryId,
    required this.isActive,
    required this.onPressed,
    this.isCorrect,
    required this.isLast,
    this.sharedPlayer,
    super.key,
  });

  @override
  ConsumerState<AudioOption> createState() => _AudioOptionState();
}

class _AudioOptionState extends ConsumerState<AudioOption> {
  AudioPlayer? _ownPlayer;
  List<bool> _barStates = List.generate(20, (_) => false);
  int _currentBar = 0;
  Timer? _timer;
  bool _isPlaying = false;
  StreamSubscription? _completeSub;

  AudioPlayer get _effectivePlayer {
    if (widget.sharedPlayer != null) return widget.sharedPlayer!;
    _ownPlayer ??= AudioPlayer();
    return _ownPlayer!;
  }

  @override
  void initState() {
    super.initState();
    _setupCompleteListener();
  }

  void _setupCompleteListener() {
    _completeSub?.cancel();
    _completeSub = _effectivePlayer.onPlayerComplete.listen((_) {
      if (mounted && _isPlaying) {
        _isPlaying = false;
        _timer?.cancel();
        setState(() {
          _barStates = List.generate(20, (_) => false);
          _currentBar = 0;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AudioOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Когда parent сбрасывает isActive (пользователь выбрал другой вариант),
    // сбрасываем анимацию этого варианта
    if (oldWidget.isActive && !widget.isActive) {
      _timer?.cancel();
      _isPlaying = false;
      setState(() {
        _barStates = List.generate(20, (_) => false);
        _currentBar = 0;
      });
    }
  }

  Future<void> _playAudio() async {
    // Если этот вариант уже играет — ничего не делаем
    if (_isPlaying) return;

    widget.onPressed();

    // Stop previous playback (если другой вариант играл на shared player)
    await _effectivePlayer.stop();
    _timer?.cancel();

    setState(() {
      _barStates = List.generate(20, (_) => false);
      _currentBar = 0;
    });

    _isPlaying = true;

    try {
      await AudioHelper.playWord(
        _effectivePlayer,
        widget.categoryName ?? '',
        widget.audioPath,
        categoryId: widget.categoryId,
      );
    } catch (e) {
      _isPlaying = false;
      debugPrint("Error playing audio: $e");
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_currentBar >= _barStates.length || !_isPlaying) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _barStates[_currentBar] = true;
          _currentBar++;
        });
      }
    });
  }

  Color _getBackgroundColor() {
    if (widget.isCorrect == true) {
      return Color(0xFFBBF7D0);
    } else if (widget.isCorrect == false) {
      return Colors.red.shade300;
    } else if (widget.isActive) {
      return Color(0xFFE3E8EF);
    } else {
      return Colors.white;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Cancel the onPlayerComplete subscription so setState() can never
    // fire on a disposed widget when the audio finishes after we're
    // already navigated away.
    _completeSub?.cancel();
    _completeSub = null;
    // Only dispose own player, not shared
    _ownPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _playAudio,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: widget.isLast
              ? BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                )
              : BorderRadius.zero,
        ),
        child: Row(
          children: [
            Icon(Icons.volume_up, color: Colors.blue, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    20,
                    (i) => AnimatedBar(
                      isActive: _barStates[i],
                      height: [
                        13,
                        33,
                        13,
                        20,
                        33,
                        33,
                        13,
                        17,
                        20,
                        30,
                        13,
                        20,
                        33,
                        33,
                        26,
                        17,
                        17,
                        33,
                        22,
                        30,
                      ][i].toDouble(),
                      isCorrect: widget.isCorrect,
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

class AnimatedBar extends StatelessWidget {
  final bool isActive;
  final double height;
  final bool? isCorrect;

  const AnimatedBar({
    required this.isActive,
    required this.height,
    required this.isCorrect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Color barColor;

    if (isActive) {
      barColor = Colors.blueAccent;
    } else if (isCorrect == true) {
      barColor = Color(0xFF22C55E);
    } else if (isCorrect == false) {
      barColor = Color(0xFFEF4444);
    } else {
      barColor = Color(0xFFCDD5DF);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 4,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

Widget VoiceWidget(bool isActive, double height, bool isCorrect) {
  return AnimatedBar(isActive: isActive, height: height, isCorrect: isCorrect);
}
