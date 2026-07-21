// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin notifPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications({void Function(String? payload)? onTap}) async {
  const androidInit = AndroidInitializationSettings('ic_halo_notification');
  const initSettings = InitializationSettings(android: androidInit);
  await notifPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (resp) {
      if (onTap != null) onTap(resp.payload);
    },
  );

  const channel = AndroidNotificationChannel(
    'halo_messages',
    'halo messages',
    description: 'new encrypted messages from your contacts',
    importance: Importance.high,
  );
  final android = notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(channel);
  // android 13+ denies notifications until asked. without this the channel
  // exists but nothing is ever delivered, silently.
  await android?.requestNotificationsPermission();
}

const _hideContentKey = 'notif_hide_content';

Future<bool> loadHideNotifContent() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_hideContentKey) ?? true;
}

Future<void> setHideNotifContent(bool v) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_hideContentKey, v);
}

Future<void> showMessageNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  if (await loadHideNotifContent()) {
    title = 'halo';
    body = 'new message';
  }
  final details = AndroidNotificationDetails(
    'halo_messages',
    'halo messages',
    channelDescription: 'new encrypted messages from your contacts',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_halo_notification',
    color: const Color(0xFFF59E0B),
    // bundle all halo notifications visually
    groupKey: 'com.halo.halo_app.messages',
    // show the full message body when expanded instead of truncating
    styleInformation: BigTextStyleInformation(body),
  );
  // stable per-sender id: new messages from the same peer REPLACE the
  // existing notification instead of stacking. positive 31-bit int.
  final id = (payload ?? title).hashCode & 0x7fffffff;
  await notifPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: payload,
  );
}
