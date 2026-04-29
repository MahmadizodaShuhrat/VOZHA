import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/result_page_provider.dart';

/// Energy indicator shown in the top bar of every game screen.
///
/// The displayed value is derived, not stored: `energy.balance` minus a
/// running count of this session's wrong words × 0.5. That lets us show
/// the energy going down in real time without actually mutating the
/// notifier — the authoritative deduction still happens once at the end
/// of the session via `consume()` on the result page.
///
/// On every new mistake the widget plays a short shake-and-flash-red
/// animation so the cost feels tangible.
class GameEnergyHud extends ConsumerStatefulWidget {
  const GameEnergyHud({super.key});

  @override
  ConsumerState<GameEnergyHud> createState() => _GameEnergyHudState();
}

class _GameEnergyHudState extends ConsumerState<GameEnergyHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;
  int _lastWrongCount = 0;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final energy = ref.watch(energyProvider);
    final results = ref.watch(gameResultProvider);
    // Unique wrong words — matches the backend cost formula
    // (wrongWordIds.length × 0.5) used at game end.
    final wrongCount = results.where((r) => !r.isCorrect).length;

    if (wrongCount > _lastWrongCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _shake
          ..reset()
          ..forward();
      });
    }
    _lastWrongCount = wrongCount;

    final displayBalance = energy.isPremium
        ? energy.max.toDouble()
        : (energy.balance - wrongCount * 0.5).clamp(0.0, energy.max.toDouble());

    final text = energy.isPremium
        ? '∞'
        : displayBalance.toStringAsFixed(displayBalance % 1 == 0 ? 0 : 1);

    // Color flashes from yellow → red → yellow during the shake window so
    // the hit lands visually even if the user wasn't looking at the number.
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) {
        final t = _shake.value; // 0..1
        // Dampened sine-wave shake: four full oscillations, fading out.
        final offsetX = math.sin(t * math.pi * 4) * 5 * (1 - t);
        final flash = (1 - (t * 2 - 1).abs()).clamp(0.0, 1.0); // 0→1→0
        final bgColor = Color.lerp(
          const Color(0xFFFFF7E5),
          const Color(0xFFFECACA),
          flash,
        )!;
        final borderColor = Color.lerp(
          const Color(0xFFFDB022),
          const Color(0xFFEF4444),
          flash,
        )!;
        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(energy.isPremium ? '👑' : '⚡',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1D2939),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
