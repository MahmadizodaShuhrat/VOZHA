import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class MyButton extends StatefulWidget {
  final void Function()? onPressed;
  final Widget child;
  final Color? buttonColor;
  final Color? backButtonColor;
  final double? width;
  final double? height;
  final bool isEnabled;
  final double depth;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? borderColor;
  final Gradient? gradient;
  final double? borderWidth;
  final double? border;
  const MyButton({
    super.key,
    this.borderRadius = 12.0,
    this.width,
    this.height,
    this.isEnabled = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    this.depth = 5,
    required this.onPressed,
    required this.child,
    this.buttonColor,
    this.backButtonColor,
    this.borderWidth,
    this.borderColor,
    this.gradient,
    this.border,
  });

  @override
  State<MyButton> createState() => _MyButtonState();
}

class _MyButtonState extends State<MyButton> {
  bool _isPressed = false;
  static final AudioPlayer _clickPlayer = AudioPlayer();

  void _playClickSound() {
    _clickPlayer.play(AssetSource('sounds/click.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: IgnorePointer(
        ignoring: widget.isEnabled,
        child: GestureDetector(
          onTap: () {
            _playClickSound();
            widget.onPressed?.call();
          },
          onTapDown: (_) {
            setState(() {
              _isPressed = true;
            });
          },
          onTapUp: (_) {
            setState(() {
              _isPressed = false;
            });
          },
          onTapCancel: () {
            setState(() {
              _isPressed = false;
            });
          },
          child: AnimatedSlide(
            duration: Duration(milliseconds: 100),
            offset: Offset(0, _isPressed ? widget.depth / 60 : 0),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 100),
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                border: widget.border != null
                    ? Border.all(
                        color: widget.borderColor ?? Color(0x0ffe8de4),
                        width: widget.border!,
                      )
                    : null,
                gradient: widget.gradient,
                color: widget.buttonColor ?? Colors.white,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                // border: Border(bottom: BorderSide(color: widget.borderColor?? Colors.grey.shade200, width: 3)),
                boxShadow: [
                  BoxShadow(
                    offset: Offset(0, _isPressed ? 0 : widget.depth),
                    color: widget.backButtonColor ?? Colors.grey,
                  ),
                ],
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
