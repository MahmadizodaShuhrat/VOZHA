import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/src/material/slider.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';

final timeSliderProvider = NotifierProvider<TimeSliderNotifier, double>(
  TimeSliderNotifier.new,
);

class TimeSliderNotifier extends Notifier<double> {
  @override
  double build() {
    // Аз storage вақти сохташударо бор кунем
    final savedHour = StorageService.instance.getReminderHour();
    final savedMinute = StorageService.instance.getReminderMinute() ?? 0;
    if (savedHour != null) {
      // Ба slider value табдил: соат аз 06:00 сар мекунад
      int totalMinutes;
      if (savedHour >= 6) {
        totalMinutes = (savedHour - 6) * 60 + savedMinute;
      } else {
        totalMinutes = (savedHour + 18) * 60 + savedMinute;
      }
      return totalMinutes.toDouble().clamp(0, 1079);
    }
    return 0; // Default: 06:00
  }

  void set(double value) => state = value;
}

class TimeSliderWidget extends ConsumerWidget {
  const TimeSliderWidget({super.key});

  String getTimeFromValue(double value) {
    // value = дақиқаҳо аз 06:00 (ҳар қадам 5 дақиқа)
    int totalMinutes = (value * 1).toInt();
    int hour = 6 + totalMinutes ~/ 60;
    int minute = totalMinutes % 60;
    if (hour >= 24) hour -= 24;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(timeSliderProvider);
    final timeString = getTimeFromValue(value);

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            timeString,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 15),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.lightBlue.shade100,
              inactiveTrackColor: Color(0xFFD1E9FF),
              trackHeight: 10.0,
              thumbColor: Colors.blue,
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15.0),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              min: 0,
              max: 1079, // 1079 min = 17h59m => from 6:00 to 23:59
              divisions: 1079,
              value: value,
              onChanged: (newValue) {
                ref.read(timeSliderProvider.notifier).set(newValue);
              },
            ),
          ),
        ],
      ),
    );
  }
}
