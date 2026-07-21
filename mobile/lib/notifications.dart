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

  final android = notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  // android freezes a channel's importance at creation. the old
  // 'halo_messages' channel was stuck below heads-up level, so bumping
  // importance in code did nothing. drop it and make a fresh v2 channel that
  // registers at max - that's the only way to get the banner back.
  await android?.deleteNotificationChannel(channelId: 'halo_messages');
  const channel = AndroidNotificationChannel(
    'halo_messages_v2',
    'messages',
    description: 'new encrypted messages from your contacts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
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
    'halo_messages_v2',
    'messages',
    channelDescription: 'new encrypted messages from your contacts',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: false,
    category: AndroidNotificationCategory.message,
    icon: 'ic_halo_notification',
    color: const Color(0xFFF59E0B),
    // show the full message body when expanded instead of truncating
    styleInformation: BigTextStyleInformation(body),
  );
  // unique per message. a stable per-sender id meant the second message
  // only UPDATED the first notification, and android never re-alerts for an
  // update - so the badge moved but no banner ever appeared.
  final id = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  await notifPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: payload,
  );
}
