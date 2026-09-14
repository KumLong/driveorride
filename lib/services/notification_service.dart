import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Map<int, int> _weekdayIdsFor(String ownerId) {

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

    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> isReminderScheduled(String ownerId) async {
    await _ensureInitialized();
    final ids = _weekdayIdsFor(ownerId).values;
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => ids.contains(n.id));
  }

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
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'goal_milestones',
        'Goal Milestones',
        channelDescription: 'Notifications for savings goal milestones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
  }

  Future<void> cancelGoalNotification(int goalId) async {
    await _ensureInitialized();
    await _plugin.cancel(id: 9000 + goalId);
  }

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