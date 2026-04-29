import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/screens/navigation_bar.dart';
import 'package:vozhaomuz/feature/profile/business/profile_repository.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/modal_bottom_sheet.dart';
import 'package:vozhaomuz/feature/profile/data/model/profile_info_dto.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';

class EditPage extends HookConsumerWidget {
  const EditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ignore: body_might_complete_normally_nullable
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(getProfileInfoProvider.notifier).getProfile();
      });
    }, []);

    final profileInfo = ref.watch(getProfileInfoProvider);

    // Store selected avatar bytes locally until Save is pressed
    final selectedAvatarBytes = useState<Uint8List?>(null);
    final isUploading = useState(false);

    final textController = TextEditingController(
      text: profileInfo.when(
        data: (data) => data?.name ?? '',
        error: (e, st) => 'error'.tr(),
        loading: () => 'loading'.tr(),
      ),
    );

    final profileRepository = ProfileRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5FAFF),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.keyboard_arrow_left_rounded, size: 30),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.20,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueGrey, width: 0.2),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Show selected local image OR server avatar + loading overlay
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildAvatar(profileInfo, selectedAvatarBytes.value),
                        if (isUploading.value)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    MyButton(
                      padding: EdgeInsets.zero,
                      height: 30,
                      width: MediaQuery.of(context).size.width * 0.30,
                      depth: 0,
                      buttonColor: const Color.fromARGB(255, 237, 246, 255),
                      child: Text(
                        'edit_choose_photo'.tr(),
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: isUploading.value
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              final bytes =
                                  await showAvatarPickerSheet(context);
                              if (bytes != null) {
                                selectedAvatarBytes.value = bytes;
                              }
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'edit_whats_your_name'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: textController,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  hintStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.blueGrey,
                      width: 0.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF448AFF),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              MyButton(
                width: double.infinity,
                height: 40,
                backButtonColor: Colors.blue.shade600,
                padding: EdgeInsets.zero,
                buttonColor: Colors.blue,
                child: isUploading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'save'.tr(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                onPressed: isUploading.value
                    ? null
                    : () async {
                        HapticFeedback.lightImpact();
                        String name = textController.text;

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('edit_name_empty'.tr())),
                          );
                          return;
                        }

                        isUploading.value = true;

                        // Send avatar bytes (selected or empty) + name to server
                        // Like Unity: ChangeProfile(Name, Avatar) → POST update-profile
                        final avatarBytes =
                            selectedAvatarBytes.value ?? Uint8List(0);
                        bool result = await profileRepository
                            .uploadAvatarWithName(avatarBytes, name);

                        isUploading.value = false;

                        if (result) {
                          // Clear avatar cache so new image shows
                          final avatarUrl = ref
                              .read(getProfileInfoProvider)
                              .value
                              ?.avatarUrl;
                          if (avatarUrl != null && avatarUrl.isNotEmpty) {
                            await CachedNetworkImage.evictFromCache(
                              buildAvatarUrl(avatarUrl),
                            );
                          }
                          // Refresh profile from server
                          ref
                              .read(getProfileInfoProvider.notifier)
                              .getProfile();

                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const NavigationPage(initialIndex: 0),
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('edit_update_error'.tr())),
                            );
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    AsyncValue<ProfileInfoDto?> profileInfo,
    Uint8List? selectedBytes,
  ) {
    // If user picked a new image, show it directly
    if (selectedBytes != null && selectedBytes.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: MemoryImage(selectedBytes),
      );
    }

    // Otherwise show server avatar
    return profileInfo.when(
      data: (data) {
        final url = data?.avatarUrl;
        return CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: (url != null && url.isNotEmpty)
              ? CachedNetworkImageProvider(buildAvatarUrl(url))
              : null,
          child: (url == null || url.isEmpty)
              ? Image.asset(
                  'assets/images/UIHome/usercircle.png',
                  width: 40,
                  height: 40,
                )
              : null,
        );
      },
      loading: () => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: CircleAvatar(radius: 40, backgroundColor: Colors.white),
      ),
      error: (error, _) => const CircleAvatar(
        radius: 40,
        backgroundColor: Colors.white,
        child: Icon(Icons.error, color: Colors.red, size: 40),
      ),
    );
  }
}
