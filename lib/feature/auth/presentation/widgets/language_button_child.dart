import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';

class LanguageButtonChild extends StatelessWidget {
  final String title;
  final Widget leading;
  final bool isActive;

  const LanguageButtonChild({
    super.key,
    required this.title,
    required this.leading,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        Gap(10),
        Text(
          // `title` is already the localized display name ("Тоҷикӣ",
          // "Русский", "English") passed in from the parent — it is NOT
          // a translation key. Calling `.tr()` on it logged
          //   "Localization key [Тоҷикӣ] not found" on every render.
          title,
          style: isActive ? AppTextStyles.whiteTextStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ) : AppTextStyles.whiteTextStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

