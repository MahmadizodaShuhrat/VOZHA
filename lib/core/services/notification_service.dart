import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vozhaomuz/core/services/storage_service.dart';

/// Хизматрасонии notification-ҳои маҳаллӣ.
/// Ёдоварии ҳаррӯзаро дар соати интихобшуда schedule мекунад.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  // Cached schedule mode. MIUI (Xiaomi/Redmi) and some OEM skins silently
  // revoke SCHEDULE_EXACT_ALARM after it was granted, which would make
  // `exactAllowWhileIdle` throw `exact_alarms_not_permitted` at runtime
  // and the daily/streak pushes would silently stop firing. We probe
  // once with `canScheduleExactNotifications()`, then catch any
  // late-revocation `PlatformException` in `_scheduleSafely`.
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

  /// Base ID for the 10 inactivity pushes (range 200..209). Kept far from the
  /// daily-reminder id (0) and the test id (99).
  static const int _inactivityBaseId = 200;
  static const int _inactivityDays = 10;
  /// Hour-of-day (Dushanbe local) for inactivity pushes. 18:00 = 6 PM.
  static const int _inactivityHour = 18;
  static const int _inactivityMinute = 0;

  /// Single notification id for the "keep-going" streak push that fires the
  /// morning after an active day. Only one is scheduled at a time — on the
  /// next successful activity we cancel and re-schedule with the new streak.
  static const int _activeStreakId = 300;
  /// 09:00 local time — morning nudge to come back and extend the streak.
  static const int _activeStreakHour = 9;
  static const int _activeStreakMinute = 0;

  /// Per-day inactivity push bodies per locale. Titles are shared.
  static const _inactivityStrings = {
    'tg': {
      'title': 'ВожаОмӯз',
      'day_1':
          'Ошно 👋 имрӯза English-ро фаромӯш накардӣ? 5 дақиқа ҷудо карда, биё омӯз.',
      'day_2':
          '2 рӯз шуд англисӣ наомӯхтаи 😏 чӣ гуна донишомӯзӣ аст ин? 5 дақиқа ҳам нест?',
      'day_3':
          'Хайр, ту чӣ? Англисиро ёд мегирӣ ё танҳо нигоҳ мекунӣ? 🔥 Даро охир!',
      'day_4':
          'То ҳол хомӯшӣ 😄 англисӣ худ аз худ аз ёд намешава. Ҳадди ақал 5 дақиқа кор кун.',
      'day_5':
          'Росташро гӯй — ту забонро ёд гирифтани ҳастӣ? 5 рӯз шуд надаромади ба барнома 😏 Даро имрӯз.',
      'day_6':
          'Англисихонӣ 6 рӯз пеш даромада будӣ 👀 Инстаграм чӣ? 6 дақиқа пеш! Даро охир.',
      'day_7':
          'Ҳафт рӯз… 😬 Гап байни ҳардуямон, АЙБ ШУД! Биё имрӯз оғоз кун.',
      'day_8':
          'Эй ошно, росташро гӯям ту барин англисихонро нав дидам. Ту худат медонӣ.',
      'day_9':
          'Ҳоло вожаҳои омӯхтаат фаромӯш шуда истодаанд 😕 биё 5 дақиқа такрор кун онҳоро.',
      'day_10':
          'Рост гап — бо ин роҳ АНГЛИСӢ ёд намегирӣ 😏\nАз 24 соат 5 дақиқаашро ба англисӣ сарф кун, дунё чаппа намешавад. Худат фоида мекунӣ.',
    },
    'ru': {
      'title': 'ВожаОмӯз',
      'day_1':
          'Братан 👋 сегодня English не забыл? Выдели 5 минут, заходи — учись.',
      'day_2':
          '2 дня без английского 😏 это ты так учишься? 5 минут — неужели нет?',
      'day_3':
          'Ну и что ты? Учишь английский или просто смотришь? 🔥 Заходи уже!',
      'day_4':
          'До сих пор тишина 😄 английский сам собой не выучится. Хоть 5 минут поработай.',
      'day_5':
          'Скажи честно — ты язык учишь? 5 дней не заходил 😏 Заходи сегодня.',
      'day_6':
          'В Англ. прилу 6 дней назад заходил 👀 А в Инсту? 6 минут назад! Заходи уже.',
      'day_7':
          'Семь дней… 😬 Между нами — СТЫДНО СТАЛО! Давай сегодня начни.',
      'day_8':
          'Брат, честно скажу — такого как ты ученика только что увидел. Сам знаешь.',
      'day_9':
          'Уже выученные слова забываются 😕 зайди 5 минут, повтори их.',
      'day_10':
          'Правду говорю — так ты АНГЛИЙСКИЙ не выучишь 😏\nИз 24 часов удели 5 минут, мир не перевернётся. Сам же в плюсе.',
    },
    'en': {
      'title': 'VozhaOmuz',
      'day_1':
          'Hey 👋 didn\'t forget English today, right? Spare 5 minutes and come learn.',
      'day_2':
          '2 days no English 😏 is this how you learn? Not even 5 minutes?',
      'day_3':
          'Well, what\'s up? Are you learning English or just watching? 🔥 Come in already!',
      'day_4':
          'Still silence 😄 English won\'t learn itself. At least do 5 minutes.',
      'day_5':
          'Honestly — are you learning the language? 5 days you haven\'t come in 😏 Come today.',
      'day_6':
          'You last opened English app 6 days ago 👀 Instagram? 6 minutes ago! Come in already.',
      'day_7':
          'Seven days… 😬 Just between us — SHAME ON YOU! Come start today.',
      'day_8':
          'Dude, truth is — I just saw a learner like you. You know yourself.',
      'day_9':
          'Your learned words are being forgotten 😕 come for 5 minutes, review them.',
      'day_10':
          'Real talk — you won\'t learn ENGLISH this way 😏\nOut of 24 hours spend 5 on English, the world won\'t flip. You benefit.',
    },
  };

  /// Per-day active-streak push bodies per locale. Fires the morning after
  /// the user completed an activity, keyed by their current streak count.
  static const _activeStrings = {
    'tg': {
      'day_1':
          '🌱 Хуш омади! Сафари шумо имрӯз оғоз шуд — калимаҳои аввалатон мунтазиранд!',
      'day_2': '🔥 Дируз фаъол буди — офарин! Биё имрӯз ҳам чанд калимаи нав ёд гирем!',
      'day_3': '⚡ Се рӯз пай дар пай! Калимаҳои имрӯз мунтазиратанд, зуд биё!',
      'day_4': '🎯 Чор рӯз — одат ташаккул меёбад! Имрӯз ҳам панҷ дақиқа вақт гузор.',
      'day_5': '🏆 Нисфи ҳафта — офарин, қаҳрамон! Калимаҳои нав мунтазири туанд.',
      'day_6': '😎 Шаш рӯз — ту ҷиддӣ ҳастӣ! Биё имрӯзро ҳам босарфарозӣ тамом кунем!',
      'day_7': '🎉 Як ҳафтаи пурра — ВОЙ! Ин муваффақият аст, биё идома диҳем!',
      'day_8': '🚀 Ҳашт рӯз — АҲСАН! Имрӯз ҳам як даври зуд бизанем!',
      'day_9': '😄 Рӯзи нӯҳум — туҳфаҳо наздиканд! Як қадами охир монд, биё!',
      'day_10':
          '🥳 ДАҲ РӮЗ — туба гап нест ҷӯра! Даромада туҳфаатро гир! Премиум барои 1 рӯз!',
    },
    'ru': {
      'day_1':
          '🌱 Добро пожаловать! Твой путь начался сегодня — первые слова уже ждут тебя!',
      'day_2': '🔥 Вчера был активен — молодец! Давай и сегодня возьмём пару новых слов!',
      'day_3': '⚡ Три дня подряд! Слова на сегодня уже ждут, заходи быстрее!',
      'day_4': '🎯 Четыре дня — привычка формируется! Удели и сегодня пять минут.',
      'day_5': '🏆 Полнедели — молодец, чемпион! Новые слова уже ждут тебя.',
      'day_6': '😎 Шесть дней — ты серьёзен! Давай закончим и сегодня достойно!',
      'day_7': '🎉 Целая неделя — УХ ТЫ! Это успех, давай продолжать!',
      'day_8': '🚀 Восемь дней — МОЛОДЕЦ! Давай и сегодня сделаем быстрый круг!',
      'day_9': '😄 Девятый день — подарки близко! Остался один шаг, заходи!',
      'day_10':
          '🥳 ДЕСЯТЬ ДНЕЙ — без вопросов, брат! Заходи за подарком! Премиум на 1 день!',
    },
    'en': {
      'day_1':
          '🌱 Welcome! Your journey started today — your first words are waiting!',
      'day_2':
          '🔥 You were active yesterday — nice! Let\'s learn a few new words today too!',
      'day_3': '⚡ Three days in a row! Today\'s words are waiting, come quick!',
      'day_4': '🎯 Four days — the habit is forming! Spare five minutes today too.',
      'day_5': '🏆 Half a week — nice job, champ! New words are waiting for you.',
      'day_6': '😎 Six days — you\'re serious! Let\'s finish today strong too!',
      'day_7': '🎉 A full week — WOW! This is success, let\'s keep going!',
      'day_8': '🚀 Eight days — WELL DONE! Let\'s do a quick round today too!',
      'day_9': '😄 Day nine — rewards are close! One step left, come in!',
      'day_10':
          '🥳 TEN DAYS — no words, bro! Come grab your reward! Premium for 1 day!',
    },
  };

  /// Локализатсияи notification-ҳо бе easy_localization context.
  /// Ин зарур аст чунки вақте notification аз background schedule мешавад,
  /// easy_localization ҳанӯз инитсиализатсия нашудааст ва .tr() кор намекунад.
  static const _notifStrings = {
    'tg': {
      'title': '📚 Вақти омӯзиш расид!',
      'body': 'Ҳар рӯз як қадам ба пеш! Биёед калимаҳои нав омӯзем 🚀',
      'channel': 'Ёдоварии ҳаррӯза',
      'channel_desc': 'Notification-ҳои ёдоварии омӯзиш',
      'content_title': '📚 ВожаОмӯз',
      'summary_text': 'Ёдоварии ҳаррӯза',
    },
    'ru': {
      'title': '📚 Время учиться!',
      'body': 'Каждый день — шаг вперёд! Давайте учить новые слова 🚀',
      'channel': 'Ежедневное напоминание',
      'channel_desc': 'Уведомления с напоминанием об учёбе',
      'content_title': '📚 ВожаОмӯз',
      'summary_text': 'Ежедневное напоминание',
    },
    'en': {
      'title': '📚 Time to learn!',
      'body': 'Every day a step forward! Let\'s learn new words 🚀',
      'channel': 'Daily Reminder',
      'channel_desc': 'Learning reminder notifications',
      'content_title': '📚 VozhaOmuz',
      'summary_text': 'Daily Reminder',
    },
  };

  /// Забони ҷорӣ аз SharedPreferences гирифтан (бе context).
  Future<String> _getSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // easy_localization stores locale under different keys depending on version
      for (final key in ['locale', 'ea_locale', 'codeCa', 'flutter.locale']) {
        final saved = prefs.getString(key);
        if (saved != null && saved.isNotEmpty) {
          // Format could be "tg", "ru", "en" or "tg_TJ" etc
          return saved.split('_').first.toLowerCase();
        }
      }
    } catch (_) {}
    return 'tg'; // default
  }

  /// Матни локализатсияшуда барои notification.
  Future<Map<String, String>> _getLocalizedStrings() async {
    final lang = await _getSavedLocale();
    return _notifStrings[lang] ?? _notifStrings['tg']!;
  }

  /// Инициализатсия — як маротиба дар main() зану занед.
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dushanbe'));
    debugPrint('📢 Timezone set to: Asia/Dushanbe (UTC+5)');

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;

    // Probe exact-alarm capability once so we don't crash later on MIUI
    // when the permission has been silently revoked.
    await _refreshScheduleMode();

    debugPrint('📢 NotificationService initialized (mode=$_scheduleMode)');
  }

  /// Check whether this device currently allows exact alarms. On MIUI the
  /// answer may flip to `false` after the user toggles the "Battery saver"
  /// off-screen setting. Call this before a batch of schedule operations.
  Future<void> _refreshScheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return; // iOS — exact mode ignored
    try {
      final canExact = await android.canScheduleExactNotifications() ?? false;
      _scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (e) {
      // Older Android (<12) or plugin path that doesn't support the check —
      // exact alarms are implicitly granted there, so the default is fine.
      debugPrint('📢 canScheduleExactNotifications failed: $e');
    }
  }

  /// Schedule a notification with a runtime fallback if exact alarms were
  /// revoked between `init()` and now. This is the only path MIUI leaves
  /// us to keep the reminder firing at *approximately* the right time
  /// instead of not at all.
  Future<void> _scheduleSafely({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: _scheduleMode,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        debugPrint(
          '📢 Exact alarm revoked at runtime (id=$id) — retrying with inexact',
        );
        _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Иҷозат барои notification гирифтан (Android 13+).
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Build notification details. When [body] is provided we use
  /// `BigTextStyleInformation` so the full multi-line message stays
  /// readable when the user expands the notification. The previous
  /// `BigPictureStyleInformation` replaced the body with the app icon,
  /// which hid the actual text from the user.
  Future<NotificationDetails> _buildNotificationDetails({String? body}) async {
    final strings = await _getLocalizedStrings();
    final contentTitle = strings['content_title'] ?? '📚 ВожаОмӯз';
    final summaryText = strings['summary_text'] ?? strings['channel']!;
    final androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      strings['channel']!,
      channelDescription: strings['channel_desc']!,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // 🎨 Ранги LED
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
      // 📳 Вибратсия (кӯтоҳ-дароз-кӯтоҳ)
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      // 🔊 Садои стандартӣ
      playSound: true,
      // 📄 Full message stays visible when expanded
      styleInformation: BigTextStyleInformation(
        body ?? '',
        contentTitle: '<b>$contentTitle</b>',
        htmlFormatContentTitle: true,
        summaryText: '<i>$summaryText</i>',
        htmlFormatSummaryText: true,
        htmlFormatBigText: false,
      ),
      // Иконкаи калон дар навори notification
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      // Категория ва намоиш
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      enableLights: true,
      color: const Color(0xFF2196F3),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Schedule daily notification at given hour and minute (LOCAL time).
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await init();

    // Request notification & exact alarm permissions
    final granted = await requestPermission();
    debugPrint('📢 Notification permission granted: $granted');

    // Save to storage
    await StorageService.instance.setReminderTime(hour, minute);

    // Cancel previous
    await _plugin.cancelAll();

    // Матни локализатсияшуда (аз map, на аз .tr())
    final strings = await _getLocalizedStrings();
    final title = strings['title']!;
    final body = strings['body']!;

    // Build notification details (body → BigTextStyleInformation)
    final details = await _buildNotificationDetails(body: body);

    // Schedule with correct local timezone (set via flutter_native_timezone)
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('📢 Now (local): $now');
    debugPrint('📢 Scheduled for: $scheduledDate');

    await _refreshScheduleMode();
    await _scheduleSafely(
      id: 0,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );

    debugPrint(
      '📢 Daily reminder scheduled at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} local time',
    );
  }

  /// Reschedule from saved settings (call on app start).
  Future<void> rescheduleFromStorage() async {
    final storage = StorageService.instance;
    final hour = storage.getReminderHour();
    final minute = storage.getReminderMinute();
    if (hour != null) {
      await scheduleDailyReminder(hour: hour, minute: minute ?? 0);
    }
  }

  /// Schedule 10 inactivity pushes: one for each of days 1..10 after "now",
  /// fired at 18:00 Dushanbe local time with a day-specific motivational
  /// message. Every app open should call this AFTER `cancelInactivityReminders()`
  /// so the counter restarts from the latest session.
  Future<void> scheduleInactivityReminders() async {
    if (!_initialized) await init();

    final strings = await _getInactivityStrings();
    final title = strings['title'] ?? 'VozhaOmuz';

    final now = tz.TZDateTime.now(tz.local);

    for (int day = 1; day <= _inactivityDays; day++) {
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        _inactivityHour,
        _inactivityMinute,
      ).add(Duration(days: day));

      // If somehow the target is in the past (clock skew), push it forward
      // so zonedSchedule doesn't reject it.
      if (scheduledDate.isBefore(now)) {
        scheduledDate = now.add(Duration(days: day));
      }

      final body = strings['day_$day'] ?? '';
      if (body.isEmpty) continue;

      // Per-day details so BigTextStyleInformation carries THIS day's body.
      final details = await _buildNotificationDetails(body: body);

      await _scheduleSafely(
        id: _inactivityBaseId + day,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
      );
    }

    debugPrint(
      '📢 Scheduled $_inactivityDays inactivity pushes (day 1..$_inactivityDays) '
      'at $_inactivityHour:${_inactivityMinute.toString().padLeft(2, '0')} local',
    );
  }

  /// Cancel the 10 inactivity pushes. Call on every app open *before*
  /// `scheduleInactivityReminders()` so tomorrow's "day 1" push is re-armed
  /// from the new baseline instead of firing from a stale schedule.
  Future<void> cancelInactivityReminders() async {
    for (int day = 1; day <= _inactivityDays; day++) {
      await _plugin.cancel(id: _inactivityBaseId + day);
    }
    debugPrint('📢 Cancelled $_inactivityDays inactivity pushes');
  }

  /// Convenience: cancel old + schedule fresh 10-day queue. Call on every
  /// app foreground event.
  Future<void> refreshInactivityReminders() async {
    await cancelInactivityReminders();
    await scheduleInactivityReminders();
  }

  Future<Map<String, String>> _getInactivityStrings() async {
    final lang = await _getSavedLocale();
    return _inactivityStrings[lang] ?? _inactivityStrings['tg']!;
  }

  Future<Map<String, String>> _getActiveStrings() async {
    final lang = await _getSavedLocale();
    return _activeStrings[lang] ?? _activeStrings['tg']!;
  }

  /// Schedule the morning-after "keep-going" push for a user who just
  /// finished an activity and is now on `currentStreak` consecutive days.
  /// [currentStreak] is the value reported by backend AFTER the session.
  /// Fires at 09:00 local the next day with the day-specific message.
  ///
  /// Only streaks 1..10 have a message; for streak > 10 we skip
  /// (the 30-day in-app streak popup already covers deep streaks).
  Future<void> scheduleActiveStreakPush(int currentStreak) async {
    if (!_initialized) await init();
    if (currentStreak < 1 || currentStreak > 10) {
      // Still cancel any previous push so it doesn't fire with stale text.
      await cancelActiveStreakPush();
      return;
    }

    // Always cancel before scheduling — one push at a time for this slot.
    await cancelActiveStreakPush();

    final strings = await _getActiveStrings();
    final titleStrings = await _getInactivityStrings();
    final title = titleStrings['title'] ?? 'VozhaOmuz';
    final body = strings['day_$currentStreak'];
    if (body == null || body.isEmpty) return;

    final details = await _buildNotificationDetails(body: body);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _activeStreakHour,
      _activeStreakMinute,
    ).add(const Duration(days: 1));

    if (scheduledDate.isBefore(now)) {
      scheduledDate = now.add(const Duration(days: 1));
    }

    await _scheduleSafely(
      id: _activeStreakId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
    );

    debugPrint(
      '📢 Active-streak push scheduled for day $currentStreak at $scheduledDate',
    );
  }

  Future<void> cancelActiveStreakPush() async {
    await _plugin.cancel(id: _activeStreakId);
  }

  /// Debug helper: fires a notification IMMEDIATELY (no scheduling)
  /// using the plugin's `show()` API, then ALSO schedules a 5-second
  /// one. This separates two failure modes:
  ///
  ///   • If neither fires → permission denied, channel disabled, or
  ///     the entire notification system is blocked at OS level (MIUI
  ///     auto-start / "Display pop-up windows while running in
  ///     background", etc).
  ///   • If only the immediate fires (scheduled doesn't) → exact-alarm
  ///     permission has been silently revoked by MIUI battery saver.
  ///     User must whitelist the app under Settings → Battery →
  ///     Background activity / Auto-start.
  ///
  /// Returns whether the immediate `show()` succeeded and the channel
  /// reports as enabled (best-effort via `areNotificationsEnabled()`).
  Future<NotificationDebugStatus> sendTestNotification() async {
    if (!_initialized) await init();
    final strings = await _getInactivityStrings();
    final title = strings['title'] ?? 'VozhaOmuz';
    final body = 'Test push 🚀 if you see this, notifications work!';
    final details = await _buildNotificationDetails(body: body);

    // ── Probe: is the system permission still on? ──
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    bool? enabled;
    if (android != null) {
      try {
        enabled = await android.areNotificationsEnabled();
      } catch (_) {}
    }

    // 1) Show immediately (no alarm — straight to the system tray).
    bool immediateOk = false;
    try {
      await _plugin.show(
        id: 98,
        title: title,
        body: body,
        notificationDetails: details,
      );
      immediateOk = true;
      debugPrint('📢 Immediate test notification shown (id=98)');
    } catch (e) {
      debugPrint('📢 Immediate notification FAILED: $e');
    }

    // 2) Also schedule one 5 seconds out so we exercise the alarm path.
    final now = tz.TZDateTime.now(tz.local);
    final fireAt = now.add(const Duration(seconds: 5));
    try {
      await _scheduleSafely(
        id: 99,
        title: title,
        body: '$body (scheduled)',
        scheduledDate: fireAt,
        notificationDetails: details,
      );
      debugPrint('📢 Scheduled test notification at $fireAt');
    } catch (e) {
      debugPrint('📢 Scheduled notification FAILED: $e');
    }

    return NotificationDebugStatus(
      immediateOk: immediateOk,
      scheduledFor: fireAt.toLocal(),
      systemEnabled: enabled,
      scheduleMode: _scheduleMode.toString(),
    );
  }

  /// Debug helper: fire the REAL inactivity message for the given day
  /// (1..10) immediately. Lets QA verify the localized strings render
  /// correctly without waiting until 18:00.
  Future<bool> sendInactivityTestPush(int day) async {
    if (!_initialized) await init();
    if (day < 1 || day > _inactivityDays) return false;
    final strings = await _getInactivityStrings();
    final title = strings['title'] ?? 'VozhaOmuz';
    final body = strings['day_$day'] ?? '';
    if (body.isEmpty) return false;
    final details = await _buildNotificationDetails(body: body);
    try {
      await _plugin.show(
        id: _inactivityBaseId + day + 100, // offset to not clash with real
        title: title,
        body: body,
        notificationDetails: details,
      );
      debugPrint('📢 Inactivity test push (day $day) shown');
      return true;
    } catch (e) {
      debugPrint('📢 Inactivity test push FAILED: $e');
      return false;
    }
  }

  /// Debug helper: fire the REAL active-streak message for the given
  /// streak day immediately. Lets QA verify the localized strings
  /// without waiting until 09:00 the next day.
  Future<bool> sendActiveStreakTestPush(int streakDay) async {
    if (!_initialized) await init();
    if (streakDay < 1 || streakDay > 10) return false;
    final strings = await _getActiveStrings();
    final titleStrings = await _getInactivityStrings();
    final title = titleStrings['title'] ?? 'VozhaOmuz';
    final body = strings['day_$streakDay'] ?? '';
    if (body.isEmpty) return false;
    final details = await _buildNotificationDetails(body: body);
    try {
      await _plugin.show(
        id: _activeStreakId + 100, // offset to not clash with real
        title: title,
        body: body,
        notificationDetails: details,
      );
      debugPrint('📢 Active-streak test push (day $streakDay) shown');
      return true;
    } catch (e) {
      debugPrint('📢 Active-streak test push FAILED: $e');
      return false;
    }
  }

  /// Returns the list of all currently scheduled notifications. Useful
  /// for debugging — call from a settings page or DevTools to confirm
  /// what's queued without waiting for the trigger.
  Future<List<PendingNotificationRequest>> debugListPending() async {
    if (!_initialized) await init();
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('📢 Pending notifications (${pending.length}):');
    for (final p in pending) {
      debugPrint('   • id=${p.id} title="${p.title}" body="${p.body}"');
    }
    return pending;
  }
}

/// Snapshot returned by `sendTestNotification()` so the calling UI can
/// render an actionable diagnostics summary without re-querying the
/// plugin.
class NotificationDebugStatus {
  /// `_plugin.show()` succeeded — at the OS level this is the strongest
  /// signal that the channel is live and permission is granted.
  final bool immediateOk;

  /// When the scheduled (alarm-based) test notification is set to fire.
  /// If this time elapses with no notification appearing while the
  /// immediate one DID appear, the OEM has revoked exact alarms.
  final DateTime scheduledFor;

  /// `areNotificationsEnabled()` result. `null` on iOS / older Android
  /// where the API isn't available.
  final bool? systemEnabled;

  /// Active schedule mode — `exactAllowWhileIdle` or
  /// `inexactAllowWhileIdle` after a fallback.
  final String scheduleMode;

  const NotificationDebugStatus({
    required this.immediateOk,
    required this.scheduledFor,
    required this.systemEnabled,
    required this.scheduleMode,
  });
}
