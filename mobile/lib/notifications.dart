import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin notifPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const androidInit = AndroidInitializationSettings('ic_halo_notification');
  const initSettings = InitializationSettings(android: androidInit);
  await notifPlugin.initialize(settings: initSettings);

  const channel = AndroidNotificationChannel(
    'halo_messages',
    'halo messages',
    description: 'new encrypted messages from your contacts',
    importance: Importance.high,
  );
  await notifPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> showMessageNotification({
  required String title,
  required String body,
}) async {
  const details = AndroidNotificationDetails(
    'halo_messages',
    'halo messages',
    channelDescription: 'new encrypted messages from your contacts',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_halo_notification',
    color: Color(0xFFF59E0B),
  );
  await notifPlugin.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(android: details),
  );
}
