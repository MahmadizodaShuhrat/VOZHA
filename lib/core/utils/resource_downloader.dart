import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/app_logger.dart';
import 'zip_resource_loader.dart';

class ResourceDownloader {
  static const _base = '${ApiConstants.baseUrl}/files/bundles/get-bundle/';
  static const _secret = ApiConstants.resourceSecret;
  static String _bundleName(int id, String type) {
    return '${id}_$type.zip';
  }

  static Stream<double> downloadBundle(int categoryId, String type) async* {
    final dir = await _localDir();
    final name = _bundleName(categoryId, type); // ❶
    final file = File(p.join(dir.path, name));
    if (await file.exists()) {
      yield 1.0;
      return;
    }

    final tmp = File('${file.path}.part');
    final url = '$_base$name$_secret';
    debugPrint('⏩ GET $url');

    final dio = Dio();

    try {
      await dio.download(
        url,
        tmp.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Progress tracking available if needed
          }
        },
        deleteOnError: true,
      );

      // Агар муваффақ шуд, файлро rename кун
      if (await tmp.exists()) {
        await tmp.rename(file.path);
        ZipResourceLoader.registerExternal(file);
        yield 1.0;
      } else {
        yield -1;
      }
    } catch (e, st) {
      AppLogger.error('ResourceDownloader', e, st);
      if (await tmp.exists()) await tmp.delete();
      yield -1;
    }
  }

  static Future<Directory> _localDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'archives'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
