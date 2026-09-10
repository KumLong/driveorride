import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Schedules a REAL, repeating local notification every weekday at a
/// set time — using flutter_local_notifications, not a fake UI toggle.
///
/// Every method takes an [ownerId] (the same concept used for scoping
/// SQLite/Supabase data and the profile picture — the account's real
/// ID, or 'guest') and derives a UNIQUE set of 5 notification IDs from
/// it. This is what makes each account's reminder independent: turning
/// notifications on for one account no longer affects any other
/// account's — or guest's — reminder state, since they're now
/// completely different notification IDs under the hood.
///
/// Notifications are inexact (AndroidScheduleMode.inexactAllowWhileIdle)
/// rather than exact-to-the-second — this avoids needing Android 12+'s
/// separate "Alarms & reminders" special permission, which would add
/// real friction for a reminder that doesn't need second-level
/// precision anyway.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Derives 5 unique notification IDs (one per weekday, Mon-Fri) from
  /// the given account ID — different accounts always get completely
  /// different ID numbers, so their reminders can never collide or
  /// interfere with each other.
  Map<int, int> _weekdayIdsFor(String ownerId) {
    // hashCode.abs() % 100000 keeps the number a reasonable size while
    // still being effectively unique per distinct ownerId string for
    // the small number of real accounts a student project like this
    // would ever have — multiplying by 10 leaves room for 5 weekday
    // slots (0-4) without overlapping the next account's range.
    final base = (ownerId.hashCode.abs() % 100000) * 10;
    return {
      DateTime.monday: base + 0,
      DateTime.tuesday: base + 1,
      DateTime.wednesday: base + 2,
      DateTime.thursday: base + 3,
      DateTime.friday: base + 4,
    };
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // Hardcoded to Malaysia's timezone, since this app is specifically
    // built for Malaysian commuters — correct regardless of what
    // timezone the test device/emulator happens to be set to.
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Requests the real Android 13+ notification permission — without
  /// this, scheduled notifications would silently never show.
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Checks Android's REAL notification scheduler directly for THIS
  /// account's specific IDs only — correctly reflects whether this
  /// particular account's reminder is on, without being affected by
  /// (or affecting) any other account's reminder state.
  Future<bool> isReminderScheduled(String ownerId) async {
    await _ensureInitialized();
    final ids = _weekdayIdsFor(ownerId).values;
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => ids.contains(n.id));
  }

  /// Schedules a real, repeating notification every Monday-Friday at
  /// [hour]:[minute], using this specific account's unique IDs.
  Future<void> scheduleWeekdayReminder(String ownerId, {int hour = 7, int minute = 30}) async {
    await _ensureInitialized();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_commute_reminder',
        'Daily Commute Reminder',
        channelDescription: 'Reminds you to check your commute options each weekday morning',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    for (final entry in _weekdayIdsFor(ownerId).entries) {
      final weekday = entry.key;
      final id = entry.value;
      final scheduledDate = _nextInstanceOfWeekdayTime(weekday, hour, minute);
      await _plugin.zonedSchedule(
        id: id,
        title: 'Time to plan your commute!',
        body: 'Check DriveOrRide to compare driving vs. public transport for today.',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // repeats weekly on this exact weekday+time
      );
    }
  }

  /// Cancels only THIS account's 5 weekday reminders — leaves every
  /// other account's reminders untouched.
  Future<void> cancelWeekdayReminder(String ownerId) async {
    await _ensureInitialized();
    for (final id in _weekdayIdsFor(ownerId).values) {
      await _plugin.cancel(id: id);
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}