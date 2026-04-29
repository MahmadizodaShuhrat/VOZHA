import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class CropCirclePage extends HookConsumerWidget {
  final File imageFile;

  const CropCirclePage({Key? key, required this.imageFile}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _imageData = useState<Uint8List?>(null);
    final _controller = useMemoized(() => CropController(), []);
    final _isImageReady = useState(false);
    useEffect(() {
      imageFile.readAsBytes().then((bytes) {
        _imageData.value = bytes;
      });
      return null;
    }, [imageFile]);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'crop_photo'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _imageData.value == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: Crop(
                    image: _imageData.value!,
                    controller: _controller,
                    withCircleUi: true,
                    cornerDotBuilder: (size, edgeAlignment) =>
                        const DotControl(color: Colors.white),
                    maskColor: Colors.black.withOpacity(0.5),
                    baseColor: Colors.transparent,
                    onStatusChanged: (status) {
                      if (status == CropStatus.ready) {
                        _isImageReady.value = true;
                      } else {
                        _isImageReady.value = false;
                      }
                    },
                    onCropped: (croppedData) {
                      if (croppedData is CropSuccess) {
                        final Uint8List croppedBytes = croppedData.croppedImage;
                        Navigator.of(context).pop<Uint8List>(croppedBytes);
                      } else {
                        debugPrint("Error: Failed to crop image.");
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 15,
                    left: 15,
                    right: 15,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MyButton(
                        width: MediaQuery.of(context).size.width * 0.42,
                        buttonColor: Colors.white,
                        backButtonColor: Colors.blueGrey.shade100,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Text('cancel'.tr()),
                      ),
                      MyButton(
                        width: MediaQuery.of(context).size.width * 0.42,
                        borderColor: Colors.white,
                        backButtonColor: Colors.blueGrey.shade100,
                        onPressed: _isImageReady.value
                            ? () {
                                HapticFeedback.lightImpact();
                                _controller.crop();
                              }
                            : null,
                        child: _isImageReady.value
                            ? Text(
                                'done'.tr(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              )
                            : const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black54,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
