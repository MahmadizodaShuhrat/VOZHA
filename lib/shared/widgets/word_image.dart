import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/core/utils/zip_resource_loader.dart';

class WordImage extends StatelessWidget {
  const WordImage({
    super.key,
    required this.category,
    required this.fileName,
    this.width,
    this.height,
    this.fit,
  });

  final String category;
  final String fileName;
  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ZipResourceLoader.load(
        category: category,
        fileName: fileName,
        type: ZipResourceType.images,
      ),
builder: (_, snap) {
  if (snap.connectionState != ConnectionState.done) {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
  // если null или 0 байт → broken image
  if (snap.data == null || snap.data!.isEmpty) {
    debugPrint("Image yoft nashud");
    return const Icon(Icons.broken_image);
  }

  return Image.memory(
    snap.data!,
    width: width,
    height: height,
    fit: fit,
  );
},

    );
  }
}
