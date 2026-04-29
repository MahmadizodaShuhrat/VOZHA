import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

enum ButtonChoice { repeat, skip }

final isShowProvider = NotifierProvider<IsShowNotifier, ButtonChoice>(IsShowNotifier.new);
class IsShowNotifier extends Notifier<ButtonChoice> {
  @override
  ButtonChoice build() => ButtonChoice.repeat;
  void set(ButtonChoice value) => state = value;
}
void showListenAgainBottomSheet(BuildContext context, ref) {
  final selected = ref.watch(isShowProvider);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Color(0xFFF5FAFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ничего не слышно',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 20),
            MyButton(
              width: double.infinity,
              buttonColor:
                  selected == ButtonChoice.repeat
                      ? Color(0xFF2E90FA)
                      : Colors.white,
              backButtonColor:
                  selected == ButtonChoice.repeat
                      ? Color(0xFF1570EF)
                      : Color(0xFFCDD5DF),
              child: Center(
                child: Text(
                  "Повторить ещё раз",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color:
                        selected == ButtonChoice.repeat
                            ? Colors.white
                            : Colors.black,
                  ),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(isShowProvider.notifier).set(ButtonChoice.repeat);
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 20),
            MyButton(
              width: double.infinity,
              buttonColor:
                  selected == ButtonChoice.skip
                      ? Color(0xFF2E90FA)
                      : Colors.white,
              backButtonColor:
                  selected == ButtonChoice.skip
                      ? Color(0xFF1570EF)
                      : Color(0xFFCDD5DF),
              child: Center(
                child: Text(
                  "Пропустить слово",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color:
                        selected == ButtonChoice.skip
                            ? Colors.white
                            : Colors.black,
                  ),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(isShowProvider.notifier).set(ButtonChoice.skip);
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}
