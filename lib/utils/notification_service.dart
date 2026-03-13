import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
    );
    await _plugin.initialize(settings: initializationSettings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
