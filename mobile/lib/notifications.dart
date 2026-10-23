// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' show Random, max;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:flutter/services.dart';
import 'dlog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'l10n/l10n.dart';
import 'app_icon.dart' show AppFace, AppFaceWords, readAppFace;
import 'container.dart';
import 'devchat/support.dart' show kSupportPayload, supportSummaryLine;
import 'lock_guard.dart' show lockGuard;
import 'lock_state.dart' show quietNow;

final FlutterLocalNotificationsPlugin notifPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications({
  void Function(String? payload, int? id)? onTap,
  Future<Set<String>> Function(String chat)? tagsOf,
  Future<void> Function({String? chat, String? msgUid})? forget,
}) async {
  if (tagsOf != null) notifTagsOf = tagsOf;
  if (forget != null) ringsForget = forget;
  const androidInit = AndroidInitializationSettings('ic_halo_notification');
  const initSettings = InitializationSettings(android: androidInit);
  await notifPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (resp) {
      if (onTap != null) onTap(resp.payload, resp.id);
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
  await clearUntaggedShade();
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
      _messagesChannel,
      l10n.notificationsChannelName,
      description: l10n.notificationsNewEncryptedMessagesFrom,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
  );
  if (_plainKnown ?? await loadNotifPlain()) await _makePlainChannel();
}

const _messagesChannel = 'halo_messages_v2';

// plain notifications: a channel of its own, since android fixes a
// channel's vibration when it is made and kryfo's two taps would tell. the
// phone's own sound and buzz, and a name that says nothing
const _plainChannel = 'kryfo_plain';

Future<void> _makePlainChannel() async {
  final android = notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(
    AndroidNotificationChannel(
      _plainChannel,
      l10n.notifPlainChannel,
      importance: Importance.high,
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
  String? tag,
  String? ticker,
  StyleInformation? style,
}) => AndroidNotificationDetails(
  _supportChannel,
  tag: tag,
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
  required String tag,
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
  (_shownFor[chatId] ??= []).add((id, tag));
  await notifPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: _supportDetails(
        alert: true,
        tag: tag,
        ticker: hidden ? l10n.notificationsNewMessage2 : '$title: $body',
        style: BigTextStyleInformation(body, contentTitle: title),
      ),
    ),
    payload: tag,
  );
}

const _hideContentKey = 'notif_hide_content';

Future<bool> loadHideNotifContent([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getBool(c.key(_hideContentKey)) ?? true;
  _hideKnown[c.key(_hideContentKey)] = v;
  return v;
}

// what the last read or write of the setting found, by container: a screen
// shows it at once instead of growing a line once it is read
final Map<String, bool> _hideKnown = {};
bool? hideNotifContentKnown([HaloContainer c = HaloContainer.everyday]) =>
    _hideKnown[c.key(_hideContentKey)];

// moves on every write, so a screen that shows the setting reads it again
// whoever changed it
final hideNotifRevision = ValueNotifier<int>(0);

Future<void> setHideNotifContent(
  bool v, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(_hideContentKey), v);
  _hideKnown[c.key(_hideContentKey)] = v;
  hideNotifRevision.value++;
}

// the phone's: no name, no words, no colour, whoever is unlocked
const _plainKey = 'notif_plain';
bool? _plainKnown;

Future<bool> loadNotifPlain() async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getBool(HaloContainer.everyday.key(_plainKey)) ?? false;
  _plainKnown = v;
  return v;
}

bool? notifPlainKnown() => _plainKnown;

Future<void> setNotifPlain(bool v) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(HaloContainer.everyday.key(_plainKey), v);
  _plainKnown = v;
  hideNotifRevision.value++;
  if (v) {
    await _makePlainChannel();
    await _plainOverNamed();
  }
  // the service's own notification reads the same key and words itself
  // again on a start
  try {
    await const MethodChannel(
      'halo/platform',
    ).invokeMethod<bool>('applyDeliveryMode');
  } catch (e) {
    dlog('plain: service not told (${e.runtimeType})');
  }
}

@visibleForTesting
void forgetNotifPlain() => _plainKnown = null;

// the plain one up now, by id and tag: a new one takes its place
final Set<(int, String?)> _plainUp = {};

/// the plain line leaves the shade: kryfo is open and unlocked. what an
/// earlier process posted is found by its channel
Future<void> clearPlainNotification() async {
  final up = {..._plainUp};
  _plainUp.clear();
  try {
    for (final a in await notifPlugin.getActiveNotifications()) {
      final id = a.id;
      if (id != null && a.channelId == _plainChannel) up.add((id, a.tag));
    }
  } catch (e) {
    dlog('plain: shade not read (${e.runtimeType})');
  }
  for (final (id, tag) in up) {
    await cancelWithRetry(() => notifPlugin.cancel(id: id, tag: tag), 'plain');
  }
}

// every plain line goes under this one tag: a chat's own tag would let a
// listener count how many people wrote. the tap still opens the chat, by
// the payload
const _plainTag = 'p';

// one plain post at a time: two arrivals together would each find the
// shade empty and leave two lines. a link that hangs gives up, so the next
// still posts
Future<void> _plainTurn = Future.value();

@visibleForTesting
Duration plainPostLimit = const Duration(seconds: 10);

Future<int?> _showPlain({
  required String chat,
  required String tag,
  String? msgUid,
  bool silent = false,
}) {
  final done = Completer<int?>();
  _plainTurn = _plainTurn.then((_) async {
    try {
      done.complete(
        await _postPlain(
          chat: chat,
          tag: tag,
          msgUid: msgUid,
          silent: silent,
        ).timeout(plainPostLimit),
      );
    } catch (e) {
      // one that hangs or fails shows nothing; the arrival goes on as any
      // that rang nothing
      dlog('plain: not posted (${e.runtimeType})');
      done.complete(null);
    }
  });
  return done.future;
}

Future<int?> _postPlain({
  required String chat,
  required String tag,
  String? msgUid,
  bool silent = false,
}) async {
  // a decoy may have opened while this waited its turn: it shows nothing
  if (await quietNow()) return null;
  await _makePlainChannel();
  // one at a time, posted anew so the phone still alerts: the shade never
  // says how many came
  await clearPlainNotification();
  // the glyph of the icon on the home screen; a plain dot while not known
  final face = await readAppFace();
  final details = AndroidNotificationDetails(
    _plainChannel,
    l10n.notifPlainChannel,
    tag: _plainTag,
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.message,
    icon: face?.glyph ?? AppFace.kryfo.glyph,
    visibility: NotificationVisibility.private,
    autoCancel: true,
    // in place of what was up already: no sound, no buzz, no heads-up
    silent: silent,
    when: DateTime.now().millisecondsSinceEpoch,
  );
  final id = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  _noteShown(chat, _plainTag, msgUid, id);
  _plainUp.add((id, _plainTag));
  await notifPlugin.show(
    id: id,
    body: l10n.notifPlainLine,
    notificationDetails: NotificationDetails(android: details),
    payload: tag,
  );
  return id;
}

// plain turned on with named ones up: they go, and one silent plain line
// stands for them, for the newest one's chat. what is up was not opened
// yet: a chat that was read took its own down. a decoy has none up
Future<void> _plainOverNamed() async {
  if (await quietNow()) return;
  final named = <ActiveNotification>[];
  try {
    for (final a in await notifPlugin.getActiveNotifications()) {
      if (a.id != null && a.channelId == _messagesChannel) named.add(a);
    }
  } catch (e) {
    dlog('plain: shade not read (${e.runtimeType})');
    return;
  }
  if (named.isEmpty) return;
  named.sort((a, b) => a.id!.compareTo(b.id!));
  for (final a in named) {
    await cancelWithRetry(
      () => notifPlugin.cancel(id: a.id!, tag: a.tag),
      'plain',
    );
  }
  final newest = named.last.tag;
  if (newest == null) return;
  // the chat it was posted for, as this process knows it, else its tag
  var chat = newest;
  for (final e in _shownFor.entries) {
    if (e.value.any((x) => x.$2 == newest)) chat = e.key;
  }
  await _showPlain(chat: chat, tag: newest, silent: true);
}

// what a chat's notifications go under on android: its tag, random, made
// once per chat and kept only in the container that holds the chat. android
// keeps tags and payloads in its logs and its history, so nothing there
// names a chat or the container it is in
String newNotifTag() {
  final r = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

// the tags a chat's notifications went under, in the containers open now.
// set as notifications start; only this process's are known before that
Future<Set<String>> Function(String chat) notifTagsOf = (_) async => const {};

// what the containers keep of which message each notification rang for:
// dropped once it leaves the shade, by its chat or its message
Future<void> Function({String? chat, String? msgUid}) ringsForget =
    ({chat, msgUid}) async {};

Future<void> _forgetRings({String? chat, String? msgUid}) async {
  try {
    await ringsForget(chat: chat, msgUid: msgUid);
  } catch (e) {
    dlog('shade: rings not dropped (${e.runtimeType})');
  }
}

// ids and tags by chat, so opening the chat by hand takes its
// notifications down
final Map<String, List<(int, String?)>> _shownFor = {};
// the chat, id and tag each message rang under, so a message taken back or
// burned takes its own one down
final Map<String, (String, int, String?)> _shownForMsg = {};

// [tags]: read before the chat's rows went, when they are gone already
Future<void> clearNotificationsFor(String chat, {Set<String>? tags}) async {
  unawaited(_forgetRings(chat: chat));
  _shownForMsg.removeWhere((_, v) => v.$1 == chat);
  final shown = _shownFor.remove(chat) ?? const <(int, String?)>[];
  for (final (id, tag) in shown) {
    await cancelWithRetry(() => notifPlugin.cancel(id: id, tag: tag), 'shade');
  }
  // what an earlier run or the receiving job showed: the shade gives back
  // tags, never payloads
  final known = tags;
  final all = <String>{for (final (_, tag) in shown) ?tag, ...?known};
  try {
    if (known == null) all.addAll(await notifTagsOf(chat));
  } catch (e) {
    dlog('shade: tags not read (${e.runtimeType})');
  }
  if (all.isEmpty) return;
  try {
    final active = await notifPlugin.getActiveNotifications();
    for (final a in active) {
      final id = a.id;
      final tag = a.tag;
      if (id == null || tag == null || !all.contains(tag)) continue;
      if (shown.contains((id, tag))) continue;
      await cancelWithRetry(
        () => notifPlugin.cancel(id: id, tag: tag),
        'shade',
      );
    }
  } catch (e) {
    dlog('shade: not read (${e.runtimeType})');
  }
}

// the foreground service's own notification (HaloListenerService)
const _kServiceNotifId = 1;

// an older version posted with no tag and named the chat in the payload,
// which the shade never gives back: those go at start, once there are none
Future<void> clearUntaggedShade() async {
  try {
    final active = await notifPlugin.getActiveNotifications();
    for (final a in active) {
      final id = a.id;
      if (id == null || a.tag != null) continue;
      if (id == _supportSummaryId || id == _kServiceNotifId) continue;
      final ch = a.channelId;
      if (ch != null && ch != _messagesChannel && ch != _supportChannel) {
        continue;
      }
      await cancelWithRetry(() => notifPlugin.cancel(id: id), 'old shade');
    }
  } catch (e) {
    dlog('old shade: not read (${e.runtimeType})');
  }
}

Future<void> clearMessageNotification(String msgUid) async {
  unawaited(_forgetRings(msgUid: msgUid));
  final shown = _shownForMsg.remove(msgUid);
  if (shown == null) return;
  final (chat, id, tag) = shown;
  final ids = _shownFor[chat];
  ids?.remove((id, tag));
  if (ids != null && ids.isEmpty) _shownFor.remove(chat);
  await cancelWithRetry(() => notifPlugin.cancel(id: id, tag: tag), 'shade');
}

void _noteShown(String chat, String tag, String? msgUid, int id) {
  (_shownFor[chat] ??= []).add((id, tag));
  if (msgUid == null) return;
  _shownForMsg[msgUid] = (chat, id, tag);
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

// [chat] is what this process knows it by; android sees only [tag]. the
// notification's id, null when none was shown
Future<int?> showMessageNotification({
  required String title,
  required String body,
  required String chat,
  required String tag,
  String? msgUid,
  int? burnAt,
}) async {
  // a decoy session is open: no notification at all
  if (await quietNow()) return null;
  // plain wins over the preview setting: nothing of the message, or of
  // kryfo, in any field
  if (await loadNotifPlain()) {
    return _showPlain(chat: chat, tag: tag, msgUid: msgUid);
  }
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
    _messagesChannel,
    l10n.notificationsChannelName,
    tag: tag,
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
  _noteShown(chat, tag, msgUid, id);
  await notifPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: tag,
  );
  return id;
}
