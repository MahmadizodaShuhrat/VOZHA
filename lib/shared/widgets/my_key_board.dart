import 'package:flutter/material.dart';

class MyKeyBoard extends StatefulWidget {
  final Widget child;
  final void Function()? onPressed;
  final Color? buttonColor;
  final Color? backButtonColor;
  final double? width;
  final double? height;
  final bool isEnabled;
  final double depth;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? borderColor;
  final double? borderWidth;

  const MyKeyBoard({
    super.key,
    required this.child,
    required this.onPressed,
    this.buttonColor,
    this.backButtonColor,
    this.width,
    this.height,
    this.isEnabled = false,
    this.depth = 2,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
  });

  @override
  State<MyKeyBoard> createState() => _MyKeyBoardState();
}

class _MyKeyBoardState extends State<MyKeyBoard> {
  bool _isPressed = false;

  void _handleTap() {
    if (widget.onPressed != null) {
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.isEnabled || widget.onPressed == null;

    return IgnorePointer(
      ignoring: isDisabled,
      child: GestureDetector(
        onTap: widget.onPressed != null ? _handleTap : null,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 100),
          offset: Offset(0, _isPressed ? widget.depth / 60 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.buttonColor ?? Colors.white,
              borderRadius: BorderRadius.circular(widget.borderRadius ?? 0),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, _isPressed ? 0 : widget.depth),
                  color: widget.backButtonColor ?? Colors.grey.shade300,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
