import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/devotional_model.dart';
import 'devotional_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _notificationEnabledKey = 'notifications_enabled';
  static const String _notificationTimeKey = 'notification_time';
  static const String _lastNotificationDateKey = 'last_notification_date';

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  final DevotionalService _devotionalService = DevotionalService();

  // Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Initialize Flutter Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  // Handle notification taps
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Here you could navigate to specific devotional or app screen
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.request();
        return status.isGranted;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationEnabledKey) ?? false;
  }

  // Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, enabled);

    if (enabled) {
      await scheduleDailyNotification();
    } else {
      await cancelAllNotifications();
    }
  }

  // Get notification time
  Future<TimeOfDay> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_notificationTimeKey);

    if (timeString != null) {
      final parts = timeString.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    // Default to 8:00 AM
    return const TimeOfDay(hour: 8, minute: 0);
  }

  // Set notification time
  Future<void> setNotificationTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationTimeKey,
      '${time.hour}:${time.minute}',
    );

    // Reschedule notifications with new time
    final enabled = await areNotificationsEnabled();
    if (enabled) {
      await scheduleDailyNotification();
    }
  }

  // Schedule daily notification
  Future<void> scheduleDailyNotification() async {
    if (!_isInitialized) await initialize();

    try {
      // Cancel existing notifications
      await _flutterLocalNotificationsPlugin.cancelAll();

      final notificationTime = await getNotificationTime();
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(notificationTime);

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'daily_devotional',
        'Daily Devotional',
        channelDescription: 'Daily devotional reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      // Get today's devotional for the notification
      final devotional = await _getTodayDevotional();
      final title = 'Daily Devotional 📖';
      final body = devotional != null
          ? '${devotional.title} - ${devotional.verseReference ?? ''}'
          : 'Your daily devotional is ready!';

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        0, // Notification ID
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_devotional',
      );

      debugPrint('Daily notification scheduled for ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('Error scheduling daily notification: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) await initialize();
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('All notifications cancelled');
  }

  // Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'instant_notification',
        'Instant Notifications',
        channelDescription: 'Instant notifications from the app',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  // Send encouragement notification
  Future<void> sendEncouragementNotification() async {
    final encouragements = [
      'Stay strong in faith! 💪',
      'God has amazing plans for you today! 🌟',
      'You are blessed and loved! ❤️',
      'Trust in the Lord with all your heart! 🙏',
      'Today is a gift from God! 🎁',
      'Walk in faith, not in fear! ✨',
      'God\'s grace is sufficient for you! 🕊️',
      'You are fearfully and wonderfully made! 🌈',
    ];

    final randomEncouragement = encouragements[
        DateTime.now().millisecondsSinceEpoch % encouragements.length];

    await showNotification(
      title: 'Daily Encouragement 💝',
      body: randomEncouragement,
      payload: 'encouragement',
    );
  }

  // Schedule weekly encouragement
  Future<void> scheduleWeeklyEncouragement() async {
    if (!_isInitialized) await initialize();

    try {
      // Schedule for Sunday at 6 PM
      final tz.TZDateTime scheduledDate = _nextInstanceOfWeekday(DateTime.sunday, 18, 0);

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'weekly_encouragement',
        'Weekly Encouragement',
        channelDescription: 'Weekly encouragement messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        1, // Different ID from daily devotional
        'Weekly Encouragement 💝',
        'You\'ve been faithful this week! Keep growing in faith! 🌱',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'weekly_encouragement',
      );

      debugPrint('Weekly encouragement scheduled for ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('Error scheduling weekly encouragement: $e');
    }
  }

  // Helper method to get next instance of a specific time
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // Helper method to get next instance of a specific weekday and time
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local);

    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    scheduledDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  // Get today's devotional for notification
  Future<DevotionalModel?> _getTodayDevotional() async {
    try {
      return await _devotionalService.getTodayDevotional();
    } catch (e) {
      debugPrint('Error getting today\'s devotional for notification: $e');
      return null;
    }
  }

  // Check and update last notification date
  Future<bool> shouldSendNotificationToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastNotificationDate = prefs.getString(_lastNotificationDateKey);
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format

    if (lastNotificationDate != today) {
      await prefs.setString(_lastNotificationDateKey, today);
      return true;
    }

    return false;
  }

  // Get notification status summary
  Future<Map<String, dynamic>> getNotificationStatus() async {
    final enabled = await areNotificationsEnabled();
    final time = await getNotificationTime();
    final hasPermissions = await _hasNotificationPermissions();

    return {
      'enabled': enabled,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'hasPermissions': hasPermissions,
    };
  }

  // Check if app has notification permissions
  Future<bool> _hasNotificationPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await Permission.notification.isGranted;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return granted?.isEnabled == true;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }
}