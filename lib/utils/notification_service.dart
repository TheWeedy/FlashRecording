import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      );
      await _plugin.initialize(settings: initializationSettings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (error, stackTrace) {
      debugPrint('Notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> showTodoReminder({
    required String title,
    required String body,
    required int id,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_reminder_channel',
        '待办提醒',
        channelDescription: '手动发送的待办提醒通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
