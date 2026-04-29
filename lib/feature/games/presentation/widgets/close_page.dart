import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

void showExitConfirmationDialog(BuildContext context, {VoidCallback? onExit}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'profile_logout_confirm'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              MyButton(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14),
                backButtonColor: Color(0xFFD3D3D3),
                buttonColor: Color(0xFFF1F1F1),
                borderRadius: 12,
                child: Text(
                  'profile_stay'.tr(),
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(height: 20),
              MyButton(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14),
                borderRadius: 12,
                backButtonColor: Color(0xFFFF6F77),
                buttonColor: Color(0xFFFF4B55),
                child: Text(
                  'profile_logout'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onExit?.call();
                  // Pop only imperative (non-Page) routes — Page-based
                  // GoRouter pages stay put. This is the safe
                  // substitute for `popUntil(isFirst)`, which tripped
                  // GoRouter 14+'s `currentConfiguration.isNotEmpty`
                  // assertion.
                  Navigator.of(context).popUntil(
                    (route) => route.settings is Page,
                  );
                  if (context.mounted) {
                    context.go('/home');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
