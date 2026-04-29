import 'dart:convert';
import 'package:flutter/foundation.dart';

/// DTO for categories from GET /api/v1/dict/categories-flutter/list
/// Mirrors Unity's CategoryItem model from UIHomePage.cs
class CategoryFlutterDto {
  final int id;
  final String version;
  final String icon;
  final bool isPremium;
  final bool isSpecial;
  final DateTime? createdAt;
  final Map<String, String> name;
  final List<ResourceItemDto> resources;
  final String languageType;
  final String subcategories;
  final String info;
  final bool isCourseCategory;

  CategoryFlutterDto({
    required this.id,
    required this.version,
    required this.icon,
    required this.isPremium,
    required this.isSpecial,
    this.createdAt,
    required this.name,
    required this.resources,
    required this.languageType,
    required this.subcategories,
    required this.info,
    required this.isCourseCategory,
  });

  factory CategoryFlutterDto.fromJson(Map<String, dynamic> json) {
    return CategoryFlutterDto(
      id: json['id'] as int,
      version: json['version']?.toString() ?? '1.0',
      icon: json['icon']?.toString() ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
      isSpecial: json['is_special'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      name:
          (json['name'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v?.toString() ?? ''),
          ) ??
          {},
      resources:
          (json['resources'] as List<dynamic>?)
              ?.map((r) => ResourceItemDto.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      languageType: json['language_type']?.toString() ?? '',
      subcategories: json['subcategories']?.toString() ?? '',
      info: json['info']?.toString() ?? '',
      isCourseCategory: json['is_course_category'] as bool? ?? false,
    );
  }

  /// Get localized name by lang code (en, ru, tg/tj)
  String getLocalizedName(String langCode) {
    // API uses 'tj' for Tajik, but app uses 'tg' — handle both
    final result = name[langCode] ??
        (langCode == 'tg' ? name['tj'] : null) ??
        (langCode == 'tj' ? name['tg'] : null) ??
        name['en'] ??
        name['ru'] ??
        name.values.firstWhere(
          (v) => v.isNotEmpty,
          orElse: () => 'Category $id',
        );
    return result;
  }

  /// Parse the info JSON string into CategoryInfoDto
  CategoryInfoDto? get parsedInfo {
    if (info.isEmpty) return null;
    try {
      String raw = info.trim();

      // Handle double-encoded JSON: if the string starts and ends with
      // escaped quotes or is itself a quoted JSON string, decode it once first.
      if (raw.startsWith('"') && raw.endsWith('"')) {
        try {
          raw = jsonDecode(raw) as String;
        } catch (_) {
          // Not double-encoded, continue with original
        }
      }

      // API returns JSON with trailing commas (e.g. "117,}") which
      // Dart's jsonDecode does not accept. Strip them first.
      // Note: use replaceAllMapped — String.replaceAll doesn't expand capture groups.
      final cleaned = raw.replaceAllMapped(
        RegExp(r',\s*([}\]])'),
        (m) => m.group(1)!,
      );
      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      return CategoryInfoDto.fromJson(map);
    } catch (e) {
      debugPrint('⚠️ Category #$id info parse error: $e');
      return null;
    }
  }
}

class ResourceItemDto {
  final String name;
  final int size;

  ResourceItemDto({required this.name, required this.size});

  factory ResourceItemDto.fromJson(Map<String, dynamic> json) {
    return ResourceItemDto(
      name: json['name']?.toString() ?? '',
      size: json['size'] as int? ?? 0,
    );
  }
}

/// Parsed from CategoryFlutterDto.info JSON string.
/// Mirrors Unity's CategoryInfo class from UIHomePage.cs.
class CategoryInfoDto {
  final int countWords;
  final Map<int, int> countWordsLevels; // level (1,2,3) → word count
  final List<int> organizations;
  final String iconSponsors;
  final String sponsorsText;

  CategoryInfoDto({
    required this.countWords,
    required this.countWordsLevels,
    required this.organizations,
    required this.iconSponsors,
    required this.sponsorsText,
  });

  factory CategoryInfoDto.fromJson(Map<String, dynamic> json) {
    // Parse count_words_levels: can be {"1": 100, "2": 200, "3": 300}
    final levelsRaw = json['count_words_levels'];
    final Map<int, int> levels = {};
    if (levelsRaw is Map) {
      for (final entry in levelsRaw.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value is int
            ? entry.value as int
            : int.tryParse(entry.value.toString()) ?? 0;
        if (key != null) {
          levels[key] = value;
        }
      }
    }

    // Parse organization_id list
    final orgsRaw = json['organization_id'];
    final List<int> orgs = [];
    if (orgsRaw is List) {
      for (final o in orgsRaw) {
        final v = o is int ? o : int.tryParse(o.toString());
        if (v != null) orgs.add(v);
      }
    }

    return CategoryInfoDto(
      countWords: json['count_words'] as int? ?? 0,
      countWordsLevels: levels,
      organizations: orgs,
      iconSponsors: json['icon_sponsors']?.toString() ?? '',
      sponsorsText: json['sponsors_text']?.toString() ?? '',
    );
  }

  /// Word count for a specific level, falls back to total
  int wordsForLevel(int level) {
    return countWordsLevels[level] ?? countWords;
  }
}
