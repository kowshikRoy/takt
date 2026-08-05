import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'app_logger.dart';

/// Daily "don't lose your streak" reminder — opt-in only (default off).
///
/// This schedules a fixed-time daily notification; it does not check
/// whether today's goal is already done before firing. Doing that would
/// need background execution (WorkManager/BackgroundFetch-style plugins)
/// well beyond what this scaffolding covers, so the copy is deliberately
/// generic rather than pretending to know the user's state.
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal() {
    _init();
  }

  static const String _keyEnabled = 'streak_reminders_enabled_v1';
  static const int _reminderId = 1001;
  static const int _reminderHour =
      20; // 8 PM, best-effort local time (see _bestEffortLocalLocation)

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _enabled = false;
  bool _initialized = false;

  bool get enabled => _enabled;

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_bestEffortLocalLocation());

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          macOS: iosSettings,
        ),
      );
      _initialized = true;

      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? false;
      if (_enabled) {
        await _schedule();
      }
      notifyListeners();
    } catch (e) {
      AppLogger.error(
        "Error initializing",
        error: e,
        tag: 'NotificationService',
      );
    }
  }

  /// The `timezone` package has no way to read the device's IANA zone
  /// without a platform channel or an extra plugin, so this approximates
  /// it from the current UTC offset via the fixed-offset `Etc/GMT` zones.
  /// It ignores DST transitions — good enough for "roughly 8pm local",
  /// not exact scheduling. A real timezone plugin would fix this properly.
  tz.Location _bestEffortLocalLocation() {
    final hours = DateTime.now().timeZoneOffset.inHours;
    // Etc/GMT sign convention is inverted from normal UTC-offset notation.
    final name = hours >= 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Returns false (and leaves the setting untouched) if the user denies
  /// the OS notification permission prompt.
  Future<bool> setEnabled(bool value) async {
    if (!_initialized) return false;

    if (value) {
      final granted = await _requestPermission();
      if (!granted) return false;
      await _schedule();
    } else {
      await _plugin.cancel(_reminderId);
    }

    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, value);
    } catch (e) {
      AppLogger.error(
        "Error saving setting",
        error: e,
        tag: 'NotificationService',
      );
    }
    return true;
  }

  Future<bool> _requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      if (granted == false) return false;
    }
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted == false) return false;
    }
    return true;
  }

  Future<void> _schedule() async {
    await _plugin.zonedSchedule(
      _reminderId,
      'Keep your streak alive! 🔥',
      "You haven't practiced today — a quick review keeps your streak going.",
      _nextInstanceOfHour(_reminderHour),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminders',
          'Streak Reminders',
          channelDescription:
              'Daily reminder to keep your learning streak going',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
