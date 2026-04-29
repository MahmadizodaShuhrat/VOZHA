import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/providers/service_providers.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/category_setting.dart';
import 'package:vozhaomuz/feature/profile/data/model/profile_info_dto.dart';

import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Shows the premium welcome dialog exactly once after premium activation.
/// Call this after re-fetching profile when user returns from payment.
Future<void> checkAndShowPremiumWelcome(
  BuildContext context,
  WidgetRef ref,
  ProfileInfoDto user,
) async {
  debugPrint('[PremiumWelcome] userType=${user.userType}, name=${user.name}');

  if (user.userType != 'pre') {
    debugPrint('[PremiumWelcome] Not premium — skipping dialog');
    return;
  }

  final storage = ref.read(storageServiceProvider);
  final alreadyShown = storage.isPremiumWelcomeShown();
  debugPrint('[PremiumWelcome] alreadyShown=$alreadyShown');

  if (alreadyShown) return;

  // Mark as shown so it never appears again
  await storage.setPremiumWelcomeShown(true);

  if (!context.mounted) return;

  debugPrint('[PremiumWelcome] Showing dialog for ${user.name}');
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PremiumWelcomeDialog(user: user),
  );
}

class _PremiumWelcomeDialog extends StatelessWidget {
  final ProfileInfoDto user;
  const _PremiumWelcomeDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium owl logo
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(1),

                child: Image.asset(
                  'assets/images/Frame_vozha.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // const SizedBox(height: 24),

            // // Checkmark icon
            // Container(
            //   width: 56,
            //   height: 56,
            //   decoration: BoxDecoration(
            //     shape: BoxShape.circle,
            //     color: const Color(0xFFDCFCE7),
            //   ),
            //   child: const Icon(
            //     Icons.check_circle,
            //     color: Color(0xFF22C55E),
            //     size: 40,
            //   ),
            // ),
            const SizedBox(height: 20),

            // Title
            Text(
              'premium_welcome_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'premium_welcome_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            // Go to category settings button
            SizedBox(
              width: double.infinity,
              child: MyButton(
                height: 50,
                borderRadius: 14,
                backButtonColor: const Color(0xFF1D4ED8),
                buttonColor: const Color(0xFF2563EB),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategorySetting(user: user),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'premium_go_to_categories'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
