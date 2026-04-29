import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/app_version_provider.dart';

class AboutVozhaOmuzPage extends ConsumerWidget {
  const AboutVozhaOmuzPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final version = versionAsync.value ?? '...';

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'about_vozhaomuz_title'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, top: 14, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Section(
              title: 'about_description_title'.tr(),
              content: 'about_description_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'about_features_title'.tr(),
              content: 'about_features_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'about_developers_title'.tr(),
              content: 'about_developers_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'about_tech_title'.tr(),
              content: 'about_version'.tr(args: [version]),
            ),
            const Gap(15),
            Section(
              title: 'about_thanks_title'.tr(),
              content: 'about_thanks_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'about_license_title'.tr(),
              content: 'about_license_content'.tr(),
            ),
            const Gap(15),
            Section(
              title: 'about_contacts_title'.tr(),
              content: 'about_contacts_content'.tr(),
            ),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: AppTextStyles.whiteTextStyle.copyWith(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
