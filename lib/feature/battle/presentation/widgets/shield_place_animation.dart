import 'dart:math' as math;
import 'package:flutter/material.dart';

class ShieldPlaceAnimation extends StatefulWidget {
  final int place;
  final double size;

  const ShieldPlaceAnimation({super.key, required this.place, this.size = 120});

  @override
  State<ShieldPlaceAnimation> createState() => _ShieldPlaceAnimationState();
}

class _ShieldPlaceAnimationState extends State<ShieldPlaceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Shield
  late Animation<double> _shieldScale, _shieldFade;

  // Number
  late Animation<double> _placeScale, _placeFade;
  late Animation<double> _placeX;

  // Wings
  late Animation<double> _wingLeftX, _wingLeftY, _wingLeftRot;
  late Animation<double> _wingRightX, _wingRightY, _wingRightRot;
  late Animation<double> _wingScale, _wingFade;

  // Glow pulse
  late Animation<double> _glowPulse;

  // Shimmer on shield
  late Animation<double> _shimmer;

  // Top sword
  late Animation<double> _topSwordY;

  @override
  void initState() {
    super.initState();
    switch (widget.place) {
      case 1:
        _initPlace1Animation();
        break;
      case 2:
        _initPlace2Animation();
        break;
      case 3:
        _initPlace3Animation();
        break;
      default:
        _initPlace4PlusAnimation();
        break;
    }
    // Play animation once (Unity uses SetTrigger("Play") which fires once)
    _ctrl.forward();
  }

  // ═══════════════════════════════════════════════════════════════════
  // ██  ҶОЙИ 1-УМ  ██
  // ═══════════════════════════════════════════════════════════════════
  void _initPlace1Animation() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // Shield: burst in with elastic bounce
    _shieldScale = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.15, curve: Curves.elasticOut),
      ),
    );
    _shieldFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.07, curve: Curves.easeIn),
      ),
    );

    // Number: pops in with overshoot
    _placeScale = Tween<double>(begin: 3.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.elasticOut),
      ),
    );
    _placeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.27, curve: Curves.easeIn),
      ),
    );
    _placeX = Tween<double>(begin: 1.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.easeOutBack),
      ),
    );

    // Wings: unfurl from behind shield outward
    _wingLeftX = Tween<double>(begin: 0.0, end: -0.85).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingLeftY = Tween<double>(begin: 0.0, end: -0.25).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _wingLeftRot = Tween<double>(begin: 25.0, end: -15.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingRightX = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingRightY = Tween<double>(begin: 0.0, end: -0.25).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _wingRightRot = Tween<double>(begin: -25.0, end: 25.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingScale = Tween<double>(begin: 0.2, end: 1.05).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.74, 0.87, curve: Curves.easeIn),
      ),
    );

    // Glow pulse: breathes in after fully assembled
    _glowPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.0), weight: 74),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 13,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.6,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
    ]).animate(_ctrl);

    // Shimmer: light sweep across shield
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 0.78, curve: Curves.easeInOut),
      ),
    );

    // Top sword drops from above
    _topSwordY = Tween<double>(begin: -3.0, end: -0.65).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.38, curve: Curves.easeOutBack),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ██  ҶОЙИ 2-ЮМ  ██
  // ═══════════════════════════════════════════════════════════════════
  void _initPlace2Animation() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // Shield: burst in with elastic bounce
    _shieldScale = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.15, curve: Curves.elasticOut),
      ),
    );
    _shieldFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.07, curve: Curves.easeIn),
      ),
    );

    // Number: pops in with overshoot
    _placeScale = Tween<double>(begin: 3.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.elasticOut),
      ),
    );
    _placeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.27, curve: Curves.easeIn),
      ),
    );
    _placeX = Tween<double>(begin: 1.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.easeOutBack),
      ),
    );

    // Wings: unfurl from behind shield outward
    _wingLeftX = Tween<double>(begin: 0.0, end: -0.85).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingLeftY = Tween<double>(begin: 0.0, end: -0.25).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _wingLeftRot = Tween<double>(begin: 25.0, end: -15.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingRightX = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingRightY = Tween<double>(begin: 0.0, end: -0.25).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _wingRightRot = Tween<double>(begin: -25.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingScale = Tween<double>(begin: 0.2, end: 1.05).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.76, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _wingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.74, 0.87, curve: Curves.easeIn),
      ),
    );

    // Glow pulse
    _glowPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.0), weight: 74),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 13,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.6,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
    ]).animate(_ctrl);

    // Shimmer
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 0.78, curve: Curves.easeInOut),
      ),
    );

    // Top sword drops from above (straight, no rotation)
    _topSwordY = Tween<double>(begin: -3.0, end: -0.65).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.38, curve: Curves.easeOutBack),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ██  ҶОЙИ 3-ЮМ  ██
  // ═══════════════════════════════════════════════════════════════════
  void _initPlace3Animation() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // Shield: burst in with elastic bounce
    _shieldScale = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.15, curve: Curves.elasticOut),
      ),
    );
    _shieldFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.07, curve: Curves.easeIn),
      ),
    );

    // Number: pops in with overshoot
    _placeScale = Tween<double>(begin: 3.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.elasticOut),
      ),
    );
    _placeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.27, curve: Curves.easeIn),
      ),
    );
    _placeX = Tween<double>(begin: 1.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.easeOutBack),
      ),
    );

    // Ҷои 3 — бидуни болу (wings)
    _wingLeftX = const AlwaysStoppedAnimation(0.0);
    _wingLeftY = const AlwaysStoppedAnimation(0.0);
    _wingLeftRot = const AlwaysStoppedAnimation(0.0);
    _wingRightX = const AlwaysStoppedAnimation(0.0);
    _wingRightY = const AlwaysStoppedAnimation(0.0);
    _wingRightRot = const AlwaysStoppedAnimation(0.0);
    _wingScale = const AlwaysStoppedAnimation(0.0);
    _wingFade = const AlwaysStoppedAnimation(0.0);

    // Ҷои 3 — бидуни glow
    _glowPulse = Tween<double>(begin: 0.0, end: 0.0).animate(_ctrl);

    // Shimmer
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 0.78, curve: Curves.easeInOut),
      ),
    );

    // Top sword drops from above (straight, no rotation)
    _topSwordY = Tween<double>(begin: -3.0, end: -0.65).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.38, curve: Curves.easeOutBack),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ██  ҶОЙИ 4+  ██
  // ═══════════════════════════════════════════════════════════════════
  void _initPlace4PlusAnimation() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // Shield: burst in with elastic bounce
    _shieldScale = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.15, curve: Curves.elasticOut),
      ),
    );
    _shieldFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.07, curve: Curves.easeIn),
      ),
    );

    // Number: pops in with overshoot
    _placeScale = Tween<double>(begin: 3.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.elasticOut),
      ),
    );
    _placeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.27, curve: Curves.easeIn),
      ),
    );
    _placeX = Tween<double>(begin: 1.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.34, curve: Curves.easeOutBack),
      ),
    );

    // Бидуни болу (wings)
    _wingLeftX = const AlwaysStoppedAnimation(0.0);
    _wingLeftY = const AlwaysStoppedAnimation(0.0);
    _wingLeftRot = const AlwaysStoppedAnimation(0.0);
    _wingRightX = const AlwaysStoppedAnimation(0.0);
    _wingRightY = const AlwaysStoppedAnimation(0.0);
    _wingRightRot = const AlwaysStoppedAnimation(0.0);
    _wingScale = const AlwaysStoppedAnimation(0.0);
    _wingFade = const AlwaysStoppedAnimation(0.0);

    // Бидуни glow
    _glowPulse = Tween<double>(begin: 0.0, end: 0.0).animate(_ctrl);

    // Shimmer
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 0.78, curve: Curves.easeInOut),
      ),
    );

    // Top sword drops from above (straight, no rotation)
    _topSwordY = Tween<double>(begin: -3.0, end: -0.65).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.38, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _basePath {
    switch (widget.place) {
      case 1:
        return 'assets/images/battle/1st';
      case 2:
        return 'assets/images/battle/2nd';
      case 3:
        return 'assets/images/battle/3rd';
      default:
        return 'assets/images/battle/3rd';
    }
  }

  String get _swordAsset => widget.place == 1 ? 'sword_left.png' : 'sword.png';
  bool get _hasWings => widget.place <= 2;
  bool get _hasNumber => widget.place <= 3;
  bool get _hasGlow => widget.place <= 2;
  bool get _hasShimmer => widget.place <= 3;

  Offset _numberOffset(double s) {
    switch (widget.place) {
      case 1:
        return Offset(-s * 0.05, -s * 0.10);
      case 2:
        return Offset(-s * 0.02, -s * 0.15);
      case 3:
        return Offset(-s * 0.02, -s * 0.15);
      default:
        return Offset(-s * 0.02, -s * 0.15);
    }
  }

  double _numberWidth(double s) {
    switch (widget.place) {
      case 1:
        return s * 0.25;
      case 2:
        return s * 0.35;
      case 3:
        return s * 0.35;
      default:
        return s * 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: s * 2.6,
          height: s * 1.6,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // ── Ambient glow behind everything ──
              if (_hasGlow)
                Center(
                  child: Opacity(
                    opacity: (_glowPulse.value * 0.55).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1.0 + _glowPulse.value * 0.12,
                      child: Image.asset(
                        '$_basePath/glow.png',
                        width: s * 1.8,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

              // ── Left wing (behind shield) ──
              if (_hasWings)
                Center(
                  child: FractionalTranslation(
                    translation: Offset(_wingLeftX.value, _wingLeftY.value),
                    child: Opacity(
                      opacity: _wingFade.value.clamp(0.0, 2.0),
                      child: Transform.scale(
                        scale: _wingScale.value,
                        child: Transform.rotate(
                          angle: _wingLeftRot.value * math.pi / 180,
                          alignment: Alignment.centerRight,
                          child: Image.asset(
                            '$_basePath/wing_left.png',
                            width: s * 1.1,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Right wing (behind shield) ──
              if (_hasWings)
                Center(
                  child: FractionalTranslation(
                    translation: Offset(_wingRightX.value, _wingRightY.value),
                    child: Opacity(
                      opacity: _wingFade.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _wingScale.value,
                        child: Transform.rotate(
                          angle: _wingRightRot.value * math.pi / 180,
                          alignment: Alignment.centerLeft,
                          child: Image.asset(
                            '$_basePath/wing_right.png',
                            width: s * 1.1,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Top sword (drops from above, behind shield) ──
              Center(
                child: Transform.translate(
                  offset: Offset(-s * 0.04, s * _topSwordY.value),
                  child: Transform.rotate(
                    angle: widget.place == 1 ? 9 * math.pi / 100 : 0,
                    child: Image.asset(
                      '$_basePath/$_swordAsset',
                      width: s * 1.3,
                      height: s * 2.6,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // ── Shield (in front of sword) ──
              Center(
                child: Opacity(
                  opacity: _shieldFade.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _shieldScale.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          '$_basePath/shield.png',
                          width: s * 2.6,
                          height: s * 2.9,
                          fit: BoxFit.contain,
                        ),
                        // Shimmer sweep
                        if (_hasShimmer)
                          ClipRect(
                            child: Opacity(
                              opacity:
                                  (math.sin(_shimmer.value * math.pi).abs() *
                                          0.40)
                                      .clamp(0.0, 0.40),
                              child: Transform.translate(
                                offset: Offset(s * _shimmer.value, 0),
                                child: Container(
                                  width: s * 0.4,
                                  height: s * 2.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.9),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Place number (slides in from side) ──
              if (_hasNumber)
                Center(
                  child: FractionalTranslation(
                    translation: Offset(_placeX.value, 0),
                    child: Transform.translate(
                      offset: _numberOffset(s),
                      child: Opacity(
                        opacity: _placeFade.value.clamp(0.0, 2.0),
                        child: Transform.scale(
                          scale: _placeScale.value,
                          child: Image.asset(
                            '$_basePath/number.png',
                            width: _numberWidth(s),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Bottom glow (ground bloom) ──
              if (_hasGlow)
                Positioned(
                  bottom: s * 0.05,
                  child: Opacity(
                    opacity:
                        (_shieldFade.value * (0.5 + _glowPulse.value * 0.35))
                            .clamp(0.0, 1.0),
                    child: Image.asset(
                      '$_basePath/glow.png',
                      width: s * 0.7,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
