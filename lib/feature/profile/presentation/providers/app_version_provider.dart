import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

/// Full version info from server: version, description, update_required.
class VersionInfo {
  final String version;
  final Map<String, String> description;
  final bool updateRequired;

  VersionInfo({
    required this.version,
    this.description = const {},
    this.updateRequired = false,
  });
}

/// Provider that fetches full version info from API.
final appVersionInfoProvider = FutureProvider<VersionInfo>((ref) async {
  try {
    String platform = 'android';
    if (!kIsWeb) {
      if (Platform.isIOS) platform = 'ios';
    }

    final token = await StorageService.instance.getAccessToken();
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.apiVersion}/dict/version/$platform',
      ),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final version = data['version']?.toString() ?? '1.0.0';
      final updateRequired = data['update_required'] == true;

      // Description is a JSON string like {"ru":"...","tg":"...","en":"..."}
      Map<String, String> desc = {};
      if (data['description'] is String) {
        try {
          final parsed = json.decode(data['description'] as String);
          if (parsed is Map) {
            desc = parsed.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        } catch (_) {
          desc = {'tg': data['description'].toString()};
        }
      } else if (data['description'] is Map) {
        desc = (data['description'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      }

      return VersionInfo(
        version: version,
        description: desc,
        updateRequired: updateRequired,
      );
    }
    return VersionInfo(version: '1.0.0');
  } catch (e) {
    return VersionInfo(version: '1.0.0');
  }
});

/// Backward-compatible: returns just the version string.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await ref.watch(appVersionInfoProvider.future);
  return info.version;
});
