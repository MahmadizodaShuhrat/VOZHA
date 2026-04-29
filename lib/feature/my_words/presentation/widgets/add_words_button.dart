import 'package:flutter/material.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class AddWordsButtonWidget extends StatefulWidget {
  final Icon? icon;
  final String? text;
  final Color? color;
  final Color? backButtonColor;
  final Color? textColor;
  final void Function()? onPressed;
  const AddWordsButtonWidget({
    super.key,
    this.icon,
    this.text,
    this.color,
    this.textColor,
    this.backButtonColor,
    this.onPressed,
  });

  @override
  State<AddWordsButtonWidget> createState() => _AddWordsButtonWidgetState();
}

class _AddWordsButtonWidgetState extends State<AddWordsButtonWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: MyButton(
        depth: 4,
        padding: EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        backButtonColor: widget.backButtonColor,
        buttonColor: widget.color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(child: widget.icon),

            Text(
              "${widget.text}",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: widget.textColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}
