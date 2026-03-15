import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _todoChannel =
      AndroidNotificationChannel(
    'todo_reminder_channel',
    '待办提醒',
    description: '手动发送的待办提醒通知',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );
      await _plugin.initialize(settings: initializationSettings);
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_todoChannel);
      await androidPlugin?.requestNotificationsPermission();
    } catch (error, stackTrace) {
      debugPrint('Notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> ensurePermissionGranted() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) {
        return true;
      }
      final granted = await androidPlugin.areNotificationsEnabled();
      if (granted ?? false) {
        return true;
      }
      final requested = await androidPlugin.requestNotificationsPermission();
      return requested ?? false;
    } catch (error, stackTrace) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> showTodoReminder({
    required String title,
    required String body,
    required int id,
  }) async {
    final permissionGranted = await ensurePermissionGranted();
    if (!permissionGranted) {
      return false;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_reminder_channel',
        '待办提醒',
        channelDescription: '手动发送的待办提醒通知',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
    return true;
  }
}
