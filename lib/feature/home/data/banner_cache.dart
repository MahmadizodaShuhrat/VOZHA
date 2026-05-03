import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';

/// Disk-backed cache for the banner list (TZ §11).
///
/// Snapshot lives in SharedPreferences under [_key] as a JSON blob:
///
/// ```json
/// { "fetched_at": "2026-05-02T10:30:00Z", "banners": [ ... ] }
/// ```
///
/// Read on cold start so the carousel renders instantly from the last
/// known list while the network refresh happens in parallel. Capped at
/// 30 minutes — older snapshots are ignored so an admin's "disable this
/// banner" change can never linger more than half an hour even if the
/// device is offline (TZ §11: "На диск кэшировать не больше 30 минут").
class BannerCache {
  static const _key = 'home.banners.cache.v1';
  static const _maxAge = Duration(minutes: 30);

  /// Snapshot read from disk, or `null` if missing/corrupt/expired.
  static Future<BannerCacheSnapshot?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final fetchedAtRaw = decoded['fetched_at'] as String?;
      if (fetchedAtRaw == null) return null;
      final fetchedAt = DateTime.tryParse(fetchedAtRaw);
      if (fetchedAt == null) return null;

      // Drop snapshots older than _maxAge — admin changes shouldn't
      // linger forever just because a phone was offline.
      if (DateTime.now().difference(fetchedAt) > _maxAge) {
        debugPrint('🗂️ Banner cache expired (age > 30 min) — discarding');
        await prefs.remove(_key);
        return null;
      }

      final list = decoded['banners'];
      if (list is! List) return null;

      final banners = list
          .whereType<Map<String, dynamic>>()
          .map(BannerDto.fromJson)
          .toList();

      debugPrint(
        '🗂️ Banner cache hit: ${banners.length} banners, age '
        '${DateTime.now().difference(fetchedAt).inMinutes} min',
      );
      return BannerCacheSnapshot(banners: banners, fetchedAt: fetchedAt);
    } catch (e) {
      debugPrint('🗂️ Banner cache read failed: $e');
      return null;
    }
  }

  /// Persist [banners] alongside `now` so the next cold start can
  /// hydrate immediately. Best-effort: failures are logged, not thrown.
  static Future<void> write(List<BannerDto> banners) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'fetched_at': DateTime.now().toIso8601String(),
        'banners': banners.map((b) => b.toJson()).toList(),
      });
      await prefs.setString(_key, payload);
      debugPrint('🗂️ Banner cache wrote ${banners.length} banners to disk');
    } catch (e) {
      debugPrint('🗂️ Banner cache write failed: $e');
    }
  }

  /// Wipe the cache (used on logout — see profile_page.dart).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('🗂️ Banner cache clear failed: $e');
    }
  }
}

class BannerCacheSnapshot {
  final List<BannerDto> banners;
  final DateTime fetchedAt;
  const BannerCacheSnapshot({required this.banners, required this.fetchedAt});
}
