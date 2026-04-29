import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        surfaceTintColor: const Color(0xFFF5FAFF),
        backgroundColor: const Color(0xFFF5FAFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_left_rounded,
            size: 30,
            color: Colors.black,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'privacy_title'.tr(),
          style: const TextStyle(
            fontSize: 20,
            color: Colors.black,
            fontWeight: FontWeight.w300,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16, left: 16, top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Section(
              title: 'privacy_general_title'.tr(),
              content: 'privacy_general_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'privacy_collection_title'.tr(),
              content: 'privacy_collection_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'privacy_usage_title'.tr(),
              content: 'privacy_usage_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'privacy_protection_title'.tr(),
              content: 'privacy_protection_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'privacy_device_title'.tr(),
              content: 'privacy_device_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'privacy_changes_title'.tr(),
              content: 'privacy_changes_content'.tr(),
            ),
            const Gap(10),
          ],
        ),
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final String content;

  const Section({Key? key, required this.title, required this.content})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          content,
          style: AppTextStyles.bigTextStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
