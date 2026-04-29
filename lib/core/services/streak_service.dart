import 'package:vozhaomuz/core/services/storage_service.dart';

/// Gate for the once-per-day streak celebration popup.
/// Backend returns the streak number (profile-rating.days_active); this service
/// only decides whether to show the popup today based on local device date.
class StreakService {
  static String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  static bool shouldShowToday() {
    final last = StorageService.instance.getLastStreakPopupDate();
    return last != _todayKey();
  }

  static Future<void> markShownToday() async {
    await StorageService.instance.setLastStreakPopupDate(_todayKey());
  }
}
