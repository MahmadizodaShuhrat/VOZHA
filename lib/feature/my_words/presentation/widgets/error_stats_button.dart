import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vozhaomuz/feature/my_words/presentation/widgets/error_categories_dialog.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class MybuttonWidget extends StatefulWidget {
  final Icon? icon;
  final String? minText;
  final String? bigText;
  final Color? color;
  final Color? backButtonColor;
  final Color? textColor;
  const MybuttonWidget({
    super.key,
    this.icon,
    this.minText,
    this.bigText,
    this.color,
    this.textColor,
    this.backButtonColor,
  });

  @override
  State<MybuttonWidget> createState() => _MybuttonWidgetState();
}

class _MybuttonWidgetState extends State<MybuttonWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.44,
      height: 110,
      child: MyButton(
        buttonColor: widget.color,
        backButtonColor: widget.backButtonColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(child: widget.icon),
                Text(
                  "${widget.minText}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: widget.textColor,
                  ),
                ),
              ],
            ),
            Container(
              child: Text(
                '${widget.bigText}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.textColor,
                ),
              ),
            ),
          ],
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          alertDialogWidget(context);
        },
      ),
    );
  }
}
