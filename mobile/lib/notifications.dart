// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dlog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'l10n/l10n.dart';
import 'container.dart';
import 'lock_guard.dart' show lockGuard;
import 'lock_state.dart' show quietNow;

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
  // android freezes a channel's importance at creation, so the old
  // 'halo_messages' channel, below heads-up level, makes way for a v2 at max
  await android?.deleteNotificationChannel(channelId: 'halo_messages');
  await nameNotificationChannel();
  // android 13+ denies notifications until asked. without this the channel
  // exists but nothing is ever delivered, silently. the ask is android's own
  // dialog, so it waits for the app lock to lift: never over the pin pad.
  // the activity asks at most once (askForNotificationsOnce), and with no
  // activity, as in a process the service brought back, there is no channel
  // and nothing is asked.
  unawaited(
    lockGuard
        .anyUnlock()
        .then(
          (_) => const MethodChannel(
            'halo/platform',
          ).invokeMethod<void>('askNotifications'),
        )
        .catchError((Object e) {
          dlog('notifications: permission ask skipped: $e');
        }),
  );
}

// made again with the same id, a channel keeps its settings and takes the
// new name: how it follows a language switch
Future<void> nameNotificationChannel() async {
  final android = notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(
    AndroidNotificationChannel(
      'halo_messages_v2',
      l10n.notificationsChannelName,
      description: l10n.notificationsNewEncryptedMessagesFrom,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
  );
}

const _hideContentKey = 'notif_hide_content';

Future<bool> loadHideNotifContent([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_hideContentKey)) ?? true;
}

Future<void> setHideNotifContent(
  bool v, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_hideContentKey), v);
}

// ids by chat, so opening the chat by hand takes its notifications down
final Map<String, List<int>> _shownFor = {};

Future<void> clearNotificationsFor(String payload) async {
  final ids = _shownFor.remove(payload);
  if (ids == null) return;
  for (final id in ids) {
    try {
      await notifPlugin.cancel(id: id);
    } catch (_) {}
  }
}

Future<void> showMessageNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  // a decoy session is open: no notification at all
  if (await quietNow()) return;
  final hidden = await loadHideNotifContent();
  if (hidden) {
    title = 'Kryfo';
    body = l10n.notificationsNewMessage;
  }
  final details = AndroidNotificationDetails(
    'halo_messages_v2',
    l10n.notificationsChannelName,
    channelDescription: l10n.notificationsNewEncryptedMessagesFromYourContacts,
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
    ticker: hidden ? l10n.notificationsNewMessage2 : '$title: $body',
    autoCancel: true,
    when: DateTime.now().millisecondsSinceEpoch,
    // sender on top, message underneath, expands for long text
    styleInformation: BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: hidden ? null : l10n.notificationsEncrypted,
    ),
  );
  // unique per message: android never re-alerts when a notification is
  // updated in place
  final id = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  if (payload != null) (_shownFor[payload] ??= []).add(id);
  await notifPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: payload,
  );
}
