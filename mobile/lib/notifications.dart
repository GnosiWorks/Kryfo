// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';
import 'dlog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'l10n/l10n.dart';
import 'container.dart';
import 'devchat/support.dart' show kSupportPayload, supportSummaryLine;
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
  // android 13+ denies notifications until asked, and nothing is delivered.
  // the ask is android's own dialog, so it waits for the lock to lift. the
  // activity asks at most once (askForNotificationsOnce)
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

// the developer's own phone: people writing from the Marios row, on a
// channel of their own. made the first time it is needed, so no other
// phone has it. a sound, no heads-up
const _supportChannel = 'halo_support';
bool _supportMade = false;

Future<void> _makeSupportChannel() async {
  if (_supportMade) return;
  final android = notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(
    AndroidNotificationChannel(
      _supportChannel,
      l10n.supportChannelName,
      description: l10n.supportChannelLine,
      importance: Importance.defaultImportance,
      playSound: true,
    ),
  );
  _supportMade = true;
}

AndroidNotificationDetails _supportDetails({
  required bool alert,
  String? ticker,
  StyleInformation? style,
}) => AndroidNotificationDetails(
  _supportChannel,
  l10n.supportChannelName,
  channelDescription: l10n.supportChannelLine,
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  category: AndroidNotificationCategory.message,
  icon: 'ic_halo_notification',
  color: const Color(0xFFF59E0B),
  visibility: NotificationVisibility.private,
  // an update says the new count without a sound; a ring is its own post
  onlyAlertOnce: !alert,
  silent: !alert,
  autoCancel: true,
  ticker: ticker,
  styleInformation: style,
  when: DateTime.now().millisecondsSinceEpoch,
);

// the one support summary, always under this id so it updates in place
const _supportSummaryId = 0x5e7;

// counts only: a stranger's words never reach the shade or the lock screen
Future<void> showSupportSummary({
  required int chats,
  required int messages,
  required bool alert,
}) async {
  if (await quietNow()) return;
  await _makeSupportChannel();
  await notifPlugin.show(
    id: _supportSummaryId,
    title: l10n.supportTitle,
    body: supportSummaryLine(chats, messages),
    notificationDetails: NotificationDetails(
      android: _supportDetails(alert: alert),
    ),
    payload: kSupportPayload,
  );
}

Future<void> clearSupportSummary() async {
  try {
    await notifPlugin.cancel(id: _supportSummaryId);
  } catch (_) {
    // one left up is replaced by the next summary, or swiped away
  }
}

// an answered support chat rings per message, like any contact, on the
// support channel. opening the chat takes it down
Future<void> showSupportMessage({
  required String chatId,
  required String title,
  required String body,
}) async {
  if (await quietNow()) return;
  await _makeSupportChannel();
  final hidden = await loadHideNotifContent();
  if (hidden) {
    title = 'Kryfo';
    body = l10n.notificationsNewMessage;
  }
  final id = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  (_shownFor[chatId] ??= []).add(id);
  await notifPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: _supportDetails(
        alert: true,
        ticker: hidden ? l10n.notificationsNewMessage2 : '$title: $body',
        style: BigTextStyleInformation(body, contentTitle: title),
      ),
    ),
    payload: '$kSupportPayload$chatId',
  );
}

const _hideContentKey = 'notif_hide_content';

Future<bool> loadHideNotifContent([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(_hideContentKey)) ?? true;
}

// moves on every write, so a screen that shows the setting reads it again
// whoever changed it
final hideNotifRevision = ValueNotifier<int>(0);

Future<void> setHideNotifContent(
  bool v, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_hideContentKey), v);
  hideNotifRevision.value++;
}

// ids by chat, so opening the chat by hand takes its notifications down
final Map<String, List<int>> _shownFor = {};
// the chat and id each message rang under, so a message taken back or
// burned takes its own one down
final Map<String, (String, int)> _shownForMsg = {};

Future<void> clearNotificationsFor(String payload) async {
  _shownForMsg.removeWhere((_, v) => v.$1 == payload);
  final ids = _shownFor.remove(payload);
  if (ids == null) return;
  for (final id in ids) {
    await cancelWithRetry(() => notifPlugin.cancel(id: id), 'shade');
  }
}

Future<void> clearMessageNotification(String msgUid) async {
  final shown = _shownForMsg.remove(msgUid);
  if (shown == null) return;
  final (payload, id) = shown;
  final ids = _shownFor[payload];
  ids?.remove(id);
  if (ids != null && ids.isEmpty) _shownFor.remove(payload);
  await cancelWithRetry(() => notifPlugin.cancel(id: id), 'shade');
}

void _noteShown(String? payload, String? msgUid, int id) {
  if (payload == null) return;
  (_shownFor[payload] ??= []).add(id);
  if (msgUid == null) return;
  _shownForMsg[msgUid] = (payload, id);
  // the oldest go first: a shade that full has been cleared long since
  if (_shownForMsg.length > 500) _shownForMsg.remove(_shownForMsg.keys.first);
}

// how long a cancel that failed waits for its one more try
const kCancelRetryAfter = Duration(milliseconds: 300);

// a cancel that failed gets one more try a beat later, and a second failure
// is only logged. nothing on screen changes either way
Future<void> cancelWithRetry(
  Future<void> Function() cancel,
  String where,
) async {
  try {
    await cancel();
  } catch (_) {
    await Future<void>.delayed(kCancelRetryAfter);
    try {
      await cancel();
    } catch (e) {
      dlog('$where: not cancelled (${e.runtimeType})');
    }
  }
}

Future<void> showMessageNotification({
  required String title,
  required String body,
  String? payload,
  String? msgUid,
  int? burnAt,
}) async {
  // a decoy session is open: no notification at all
  if (await quietNow()) return;
  final hidden = await loadHideNotifContent();
  if (hidden) {
    title = 'Kryfo';
    body = l10n.notificationsNewMessage;
  }
  // a timed message leaves the shade its window after it came, read or
  // not, whatever is running then: android takes it down itself. the
  // message waits in the chat to be read
  final left = burnAt == null
      ? null
      : max(1, burnAt - DateTime.now().millisecondsSinceEpoch);
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
    timeoutAfter: left,
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
  _noteShown(payload, msgUid, id);
  await notifPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: payload,
  );
}
