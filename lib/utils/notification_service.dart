import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _platformChannel = MethodChannel(
    'com.pyynb.edu.recordmytime/notification_settings',
  );

  static const String _todoChannelId = 'task_reminders_high_priority_v2';
  static const String _todoChannelName = 'Task reminders';
  static const String _todoChannelDescription =
      'Manual reminders for tracked tasks';

  static const AndroidNotificationChannel _todoChannel =
      AndroidNotificationChannel(
        _todoChannelId,
        _todoChannelName,
        description: _todoChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  Future<void> initialize() async {
    try {
      final settings = InitializationSettings(
        android: Platform.isAndroid
            ? const AndroidInitializationSettings('ic_notification')
            : null,
        macOS: Platform.isMacOS
            ? const DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              )
            : null,
      );
      await _plugin.initialize(settings: settings);

      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.createNotificationChannel(_todoChannel);
      }
    } catch (error, stackTrace) {
      debugPrint('Notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> ensurePermissionGranted() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin == null) {
          return true;
        }
        final granted = await androidPlugin.areNotificationsEnabled();
        if (granted ?? false) {
          return true;
        }
        final requested =
            await androidPlugin.requestNotificationsPermission();
        return requested ?? false;
      }

      if (Platform.isMacOS) {
        final macPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        if (macPlugin == null) {
          return true;
        }
        final granted = await macPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (error, stackTrace) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [
          'x-apple.systempreferences:com.apple.preference.notifications?Notification',
        ]);
        return;
      }
      await _platformChannel.invokeMethod<void>('openNotificationSettings');
    } catch (error, stackTrace) {
      debugPrint('Opening notification settings failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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

    final details = NotificationDetails(
      android: Platform.isAndroid
          ? const AndroidNotificationDetails(
              _todoChannelId,
              _todoChannelName,
              channelDescription: _todoChannelDescription,
              icon: 'ic_notification',
              importance: Importance.max,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
              visibility: NotificationVisibility.public,
              playSound: true,
              enableVibration: true,
              ticker: 'Task reminder',
            )
          : null,
      macOS: Platform.isMacOS
          ? const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            )
          : null,
    );
    await _plugin.show(
      id: id & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
    );
    return true;
  }
}
