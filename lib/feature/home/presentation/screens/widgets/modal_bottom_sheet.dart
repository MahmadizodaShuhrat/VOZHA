import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/crop_circle_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Shows a bottom sheet for selecting a profile photo.
/// Returns the cropped image bytes (Uint8List) or null if cancelled.
Future<Uint8List?> showAvatarPickerSheet(BuildContext context) async {
  return showModalBottomSheet<Uint8List?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: false,
    builder: (sheetContext) {
      return _AvatarPickerContent(parentContext: context);
    },
  );
}

class _AvatarPickerContent extends StatelessWidget {
  final BuildContext parentContext;
  const _AvatarPickerContent({required this.parentContext});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (pickedFile == null) return;

      final Uint8List? croppedBytes = await Navigator.of(parentContext)
          .push<Uint8List>(
            MaterialPageRoute(
              builder: (ctx) =>
                  CropCirclePage(imageFile: File(pickedFile.path)),
            ),
          );
      // Return cropped bytes to caller (edit page)
      Navigator.of(context).pop(croppedBytes);
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // `maxHeight` (not fixed `height`) + `mainAxisSize.min` so the sheet
      // sizes itself to its contents. On iPhone SE (667pt) 38 % = 253pt
      // which was pushing the cancel button off-screen once the photo,
      // gallery, delete and divider rows stacked up under OS font scale.
      // Clamping the ceiling keeps it readable on tall phones too.
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.of(context).size.height * 0.55)
            .clamp(320.0, 480.0),
      ),
      color: const Color.fromARGB(255, 219, 226, 233),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MyButtonWidget(
            icon: const Icon(Icons.photo_camera_outlined),
            text: 'take_photo'.tr(),
            color: Colors.black,
            onTap: () => _pickImage(context, ImageSource.camera),
          ),
          MyButtonWidget(
            icon: const Icon(Icons.image_outlined),
            text: 'choose_from_gallery'.tr(),
            color: Colors.black,
            onTap: () => _pickImage(context, ImageSource.gallery),
          ),
          MyButtonWidget(
            icon: const Icon(Icons.delete_outline_outlined, color: Colors.red),
            text: 'delete'.tr(),
            color: Colors.red,
            onTap: () {
              // Return empty bytes = "delete avatar"
              Navigator.of(context).pop(Uint8List(0));
            },
          ),
          Container(
            width: double.infinity,
            height: 0.2,
            color: Colors.grey.shade400,
          ),
          MyButton(
            padding: EdgeInsets.zero,
            borderRadius: 10,
            height: 45,
            buttonColor: Colors.blue,
            backButtonColor: Colors.blue.shade600,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                'cancel'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class MyButtonWidget extends StatelessWidget {
  final Widget icon;
  final String text;
  final Color color;
  final void Function()? onTap;

  const MyButtonWidget({
    Key? key,
    required this.icon,
    required this.text,
    required this.onTap,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MyButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: 12,
      height: 45,
      buttonColor: Colors.white,
      backButtonColor: Colors.white70,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            Padding(padding: const EdgeInsets.only(right: 10), child: icon),
            Text(text, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
