// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

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
  final hidden = await loadHideNotifContent();
  if (hidden) {
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
    // locked screen never shows content, unlocked does. the toggle above
    // decides whether it shows even then.
    visibility: NotificationVisibility.private,
    // two short taps reads as a message, not an alarm
    vibrationPattern: Int64List.fromList(<int>[0, 120, 90, 120]),
    enableLights: true,
    ledColor: const Color(0xFFF59E0B),
    ledOnMs: 600,
    ledOffMs: 2000,
    ticker: hidden ? 'new message' : '$title: $body',
    autoCancel: true,
    when: DateTime.now().millisecondsSinceEpoch,
    // sender on top, message underneath, expands for long text
    styleInformation: BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: hidden ? null : 'encrypted',
    ),
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
