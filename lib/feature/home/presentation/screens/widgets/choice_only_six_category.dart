import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

void showOnlySixCategory(BuildContext context) {
  showDialog(
    context: context,
    //barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  textAlign: TextAlign.center,
                  'only_six_categories_title'.tr(),
                  style: TextStyle(
                    color: Color(0xFF202939),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  textAlign: TextAlign.center,
                  'only_six_categories_description'.tr(),
                  style: TextStyle(
                    color: Color(0xFF202939),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 20),
                MyButton(
                  depth: 4,
                  backButtonColor: Color(0xFFCDD5DF),
                  buttonColor: Color(0xFFE1E5EF),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  borderRadius: 10,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'understood'.tr(),
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    },
  );
}
