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
import 'desktop/desktop_mode.dart' show onDesktop;
import 'desktop/desktop_toasts.dart' show windowsToastSettings;
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
  // linux has no channels and no icon resource: the desktop's notification
  // server names the app, and a click opens the window
  final initSettings = InitializationSettings(
    android: androidInit,
    linux: LinuxInitializationSettings(defaultActionName: l10n.desktopLockOpen),
    windows: windowsToastSettings(),
  );
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
  await _makeRequestsChannel();
}

const _messagesChannel = 'halo_messages_v2';

// a message request from someone not added yet: a channel of its own. it
// pops up only when "Pop-ups for message requests" is on, else it waits in
// the shade without a sound
const _requestsChannel = 'kryfo_requests';

// the chats' own notifications: messages and requests
bool _named(String? channel) =>
    channel == _messagesChannel || channel == _requestsChannel;

const _requestPopupsKey = 'kryfo.requests.popups';

/// whether a message request pops up and sounds. a new install starts with
/// it off, a phone updating keeps them ringing as before
/// (settleRequestPopups); a computer has no switch for it and shows
/// requests as it always did
Future<bool> loadRequestPopups() async {
  if (onDesktop) return true;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(HaloContainer.everyday.key(_requestPopupsKey)) ?? true;
}

/// the switch's start, once per install: on for a phone that had an
/// identity before this version, off for a new one
Future<void> settleRequestPopups({required bool existing}) async {
  final prefs = await SharedPreferences.getInstance();
  final k = HaloContainer.everyday.key(_requestPopupsKey);
  if (prefs.containsKey(k)) return;
  await prefs.setBool(k, existing);
}

Future<void> saveRequestPopups(bool on) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(HaloContainer.everyday.key(_requestPopupsKey), on);
}

Future<void> _makeRequestsChannel() async {
  final android = notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(
    AndroidNotificationChannel(
      _requestsChannel,
      l10n.notifRequestsChannel,
      description: l10n.notifRequestsChannelLine,
      importance: Importance.high,
      playSound: true,
    ),
  );
}

/// the channel new messages come on now: plain notifications have their own
Future<String> messageChannelId() async =>
    (_plainKnown ?? await loadNotifPlain()) ? _plainChannel : _messagesChannel;

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
  int? number,
  int? when,
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
  number: number,
  when: when ?? DateTime.now().millisecondsSinceEpoch,
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

// an answered support chat rings like any contact, on the support channel,
// one notification per chat. opening the chat takes it down
Future<void> showSupportMessage({
  required String chatId,
  required String tag,
  required String title,
  required String body,
  String? msgUid,
}) async {
  if (await quietNow()) return;
  await _makeSupportChannel();
  final hidden = await loadHideNotifContent();
  if (hidden) {
    title = 'Kryfo';
    body = l10n.notificationsNewMessage;
  }
  await _ringFold(
    chat: chatId,
    tag: tag,
    support: true,
    line: _Line(uid: msgUid, title: title, body: body, hidden: hidden),
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
  if (v) {
    // words already folded never show again: a later repost says only kryfo
    _maskFolds();
    // the phone's own setting is the one notifications read
    if (c != HaloContainer.everyday) return;
    // a ring already on its way under the old setting lands nothing, and
    // what is up folds into the one shared notification at once
    _clearGen++;
    await _sharedOverNamed();
  }
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
    notificationDetails: notifDetails(details, alert: !silent),
    // the tap opens the chat list: no chat is named anywhere in it
    payload: kListPayload,
  );
  return id;
}

// plain turned on with named ones up: they go, and one silent plain line
// stands for them, for the newest one's chat. what is up was not opened
// yet: a chat that was read took its own down. a decoy has none up
Future<void> _plainOverNamed() async {
  // ids do not follow time: the folds this process posted know which
  // rang last, the rest fall back on id order
  final order = [for (final f in _folds.values) f.tag];
  final chatOf = {for (final e in _folds.entries) e.value.tag: e.key};
  // named folds go whatever the shade says: nothing reposts their words
  for (final e in [..._folds.entries]) {
    if (_named(e.value.channel)) _dropFold(e.key);
  }
  // the shared one goes with them, below, by its channel
  _sharedReset();
  if (await quietNow()) return;
  final named = <ActiveNotification>[];
  try {
    for (final a in await notifPlugin.getActiveNotifications()) {
      if (a.id != null && _named(a.channelId)) named.add(a);
    }
  } catch (e) {
    dlog('plain: shade not read (${e.runtimeType})');
    return;
  }
  if (named.isEmpty) return;
  int rank(ActiveNotification a) => order.indexOf(a.tag ?? '');
  named.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.id!.compareTo(b.id!);
  });
  for (final a in named) {
    await cancelWithRetry(
      () => notifPlugin.cancel(id: a.id!, tag: a.tag),
      'plain',
    );
  }
  final newest = named.last.tag;
  if (newest == null) return;
  // the chat it was posted for, as this process knows it, else its tag
  var chat = chatOf[newest] ?? newest;
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
Future<void> clearNotificationsFor(String chat, {Set<String>? tags}) {
  // a ring already on its way for this chat lands nothing
  // at once, never queued behind a turn: a turn reads its generation with
  // nothing between that and its post, and a post already sent reaches
  // android before this cancel does
  _chatGen[chat] = (_chatGen[chat] ?? 0) + 1;
  return _clearChatNow(chat, tags: tags);
}

Future<void> _clearChatNow(String chat, {Set<String>? tags}) async {
  unawaited(_forgetRings(chat: chat));
  _shownForMsg.removeWhere((_, v) => v.$1 == chat);
  final fold = _folds.remove(chat);
  final shown = [
    ...?_shownFor.remove(chat),
    if (fold != null) (fold.id, fold.tag),
  ];
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
  await _leaveShared({chat, ...all});
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
      if (ch != null && !_named(ch) && ch != _supportChannel) {
        continue;
      }
      await cancelWithRetry(() => notifPlugin.cancel(id: id), 'old shade');
    }
  } catch (e) {
    dlog('old shade: not read (${e.runtimeType})');
  }
}

Future<void> clearMessageNotification(String msgUid) =>
    _foldTurnOf(() => _clearMessage(msgUid)).then((_) {});

Future<void> _clearMessage(String msgUid) async {
  final gen = _clearGen;
  final gens = {..._chatGen};
  unawaited(_forgetRings(msgUid: msgUid));
  final inShared = _sharedUids.remove(msgUid);
  if (inShared != null) {
    // the words were never in it: only the last of a chat takes it out
    final n = (_sharedChats[inShared] ?? 1) - 1;
    if (n > 0) {
      _sharedChats[inShared] = n;
    } else {
      await _leaveShared({inShared});
    }
    return;
  }
  final shown = _shownForMsg.remove(msgUid);
  // the folds are looked in directly: the map above forgets the oldest
  final at = _folds.entries
      .where((e) => e.value.lines.any((l) => l.uid == msgUid))
      .firstOrNull;
  final chat = at?.key ?? shown?.$1;
  final fold = chat == null ? null : _folds[chat];
  if (fold != null &&
      (at != null || (shown!.$2 == fold.id && shown.$3 == fold.tag))) {
    // the rest of the chat's stay up: its line goes, quietly
    fold.lines.removeWhere((l) => l.uid == msgUid);
    fold.count--;
    // a clear since this began: the repost never lands
    bool stale() => gen != _clearGen || gens[chat] != _chatGen[chat];
    if (fold.count > 0 &&
        fold.lines.isNotEmpty &&
        await _mayRepost(fold) &&
        !await quietNow()) {
      await _postFold(fold, alert: false, stale: stale);
      return;
    }
    if (stale()) return;
    _dropFold(chat!);
    await cancelWithRetry(
      () => notifPlugin.cancel(id: fold.id, tag: fold.tag),
      'shade',
    );
    return;
  }
  if (shown == null) return;
  final (sChat, id, tag) = shown;
  final ids = _shownFor[sChat];
  ids?.remove((id, tag));
  if (ids != null && ids.isEmpty) _shownFor.remove(sChat);
  await cancelWithRetry(() => notifPlugin.cancel(id: id, tag: tag), 'shade');
}

// a fold is posted again only while it is up and nothing got stricter
// since: swiped away, plain on, or previews off, it goes instead
Future<bool> _mayRepost(_Fold fold) async {
  if (!await _foldUp(fold)) return false;
  if (!_isSupport(fold) && await loadNotifPlain()) return false;
  if (!fold.lines.last.hidden && await loadHideNotifContent()) return false;
  return true;
}

// the fold's own notification is in the shade now. a shade that cannot be
// read counts as empty, so nothing old is posted again
Future<bool> _foldUp(_Fold fold) async {
  try {
    for (final a in await notifPlugin.getActiveNotifications()) {
      if (a.id == fold.id && a.tag == fold.tag) return true;
    }
  } catch (e) {
    dlog('shade: not read (${e.runtimeType})');
  }
  return false;
}

void _maskFolds() {
  for (final f in _folds.values) {
    for (var i = 0; i < f.lines.length; i++) {
      final l = f.lines[i];
      if (l.hidden) continue;
      f.lines[i] = _Line(
        uid: l.uid,
        title: 'Kryfo',
        body: l10n.notificationsNewMessage,
        hidden: true,
        burnAt: l.burnAt,
        at: l.at,
      );
    }
  }
}

// one fold change at a time: two arrivals together would each build a fold
// for the same chat. a platform call that hangs gives up, so the next runs
Future<void> _foldTurn = Future.value();

@visibleForTesting
Duration foldPostLimit = const Duration(seconds: 10);

Future<T?> _foldTurnOf<T>(Future<T> Function() job) {
  final done = Completer<T?>();
  _foldTurn = _foldTurn.then((_) async {
    try {
      done.complete(await job().timeout(foldPostLimit));
    } catch (e) {
      dlog('shade: fold not done (${e.runtimeType})');
      done.complete(null);
    }
  });
  return done.future;
}

// one notification per chat, under its tag and an id cut from it, updated
// in place: android keeps no more than about 25 up per app and drops the
// rest without a word
class _Line {
  _Line({
    required this.uid,
    required this.title,
    required this.body,
    required this.hidden,
    this.burnAt,
    int? at,
  }) : at = at ?? DateTime.now().millisecondsSinceEpoch;
  final String? uid;
  final String title;
  final String body;
  // said only kryfo and new message when it came
  final bool hidden;
  final int? burnAt;
  final int at;
}

class _Fold {
  _Fold(this.tag, this.channel) : id = notifIdFor(tag);
  final String tag;
  final String channel;
  final int id;
  // every message folded in, more than the lines kept
  int count = 0;
  // newest last
  final lines = <_Line>[];
}

bool _isSupport(_Fold f) => f.channel == _supportChannel;

// by chat, the one rung last at the end
final Map<String, _Fold> _folds = {};

// lines kept per chat, and lines shown
const _kKeptLines = 10;
const _kShownLines = 6;

// chats with a notification up at once. the shade's own limit is about 25
// per app, with the service, a transfer and android's group summary in it
@visibleForTesting
const kMaxChatNotifs = 20;

/// the id a chat's notification goes under: from its random tag, so it says
/// nothing the tag does not, and clear of the fixed ids below 0x10000
int notifIdFor(String tag) {
  var h = 0x811c9dc5;
  for (final c in tag.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  h &= 0x7fffffff;
  return h < 0x10000 ? h + 0x10000 : h;
}

/// true while [chat]'s notification holds one message: the tap opens on it
bool ringIsFirst(String chat) => (_folds[chat]?.count ?? 0) <= 1;

/// the shade is cleared as a whole: what the folds hold goes with it
Future<void> clearAllNotifications(String where) async {
  // a ring already on its way lands nothing
  // at once, as clearNotificationsFor: a decoy's shade never waits on a turn
  _clearGen++;
  forgetFolds();
  await cancelWithRetry(notifPlugin.cancelAll, where);
}

// moved by every clear, as a whole and by chat: a ring that began before
// one posts nothing and keeps no fold
int _clearGen = 0;
final Map<String, int> _chatGen = {};

// a fold that goes takes what is kept by message with it, so a later
// take-back cannot match a new fold under the same id and tag
void _dropFold(String chat) {
  _folds.remove(chat);
  _shownForMsg.removeWhere((_, v) => v.$1 == chat);
}

@visibleForTesting
void forgetFolds() {
  _folds.clear();
  _shownFor.clear();
  _shownForMsg.clear();
  _sharedReset();
}

/// what a tap on the shared or the plain notification opens: the chat list
const kListPayload = 'l';

// previews off: one notification for every chat, under a fixed tag. it
// never says whose, how many chats or how many messages
const _sharedTag = 's';
final int _sharedId = notifIdFor(_sharedTag);

/// the id the shared notification goes under
int get sharedNotifId => _sharedId;

// what it stands for, by chat (or by tag, for one an earlier process
// left): messages in it. memory only
final Map<String, int> _sharedChats = {};
final Map<String, String> _sharedUids = {};
// the latest burn of what it stands for, while every one of them is timed
int? _sharedBurn;
bool _sharedUntimed = false;

void _sharedReset() {
  _sharedChats.clear();
  _sharedUids.clear();
  _sharedBurn = null;
  _sharedUntimed = false;
}

void _sharedTimes(int? burnAt) {
  if (burnAt == null) {
    _sharedUntimed = true;
  } else if (_sharedBurn == null || burnAt > _sharedBurn!) {
    _sharedBurn = burnAt;
  }
}

Future<int?> _ringShared({
  required String chat,
  String? msgUid,
  int? burnAt,
  bool alert = true,
}) => _foldTurnOf<int?>(() async {
  if (await quietNow()) return null;
  final gen = _clearGen;
  final chatGen = _chatGen[chat];
  bool stale() => gen != _clearGen || chatGen != _chatGen[chat];
  // per chat ones still up go into it first
  await _sharedOverNamed(post: false);
  // swiped away or tapped: it starts over
  if (!await _isUp(_sharedId, _sharedTag)) {
    _sharedReset();
  }
  if (stale()) return null;
  _sharedChats[chat] = (_sharedChats[chat] ?? 0) + 1;
  _sharedTimes(burnAt);
  if (msgUid != null) {
    _sharedUids[msgUid] = chat;
    if (_sharedUids.length > 500) {
      _sharedUids.remove(_sharedUids.keys.first);
    }
  }
  if (await quietNow() || stale()) {
    _sharedChats.remove(chat);
    return null;
  }
  await _postShared(alert: alert);
  return _sharedId;
});

// previews just went off, or a shared one is about to post: every chat's
// own notification goes, and the shared one stands for them, quietly
Future<void> _sharedOverNamed({bool post = true}) async {
  final named = <ActiveNotification>[];
  try {
    for (final a in await notifPlugin.getActiveNotifications()) {
      if (a.id != null &&
          a.tag != null &&
          a.tag != _sharedTag &&
          _named(a.channelId)) {
        named.add(a);
      }
    }
  } catch (e) {
    dlog('shared: shade not read (${e.runtimeType})');
  }
  final chatOf = <String, String>{};
  final burns = <String, List<int?>>{};
  for (final e in [..._folds.entries]) {
    if (!_named(e.value.channel)) continue;
    chatOf[e.value.tag] = e.key;
    burns[e.value.tag] = [for (final l in e.value.lines) l.burnAt];
    _dropFold(e.key);
  }
  if (named.isEmpty) return;
  if (!await _isUp(_sharedId, _sharedTag)) {
    _sharedReset();
  }
  for (final a in named) {
    await cancelWithRetry(
      () => notifPlugin.cancel(id: a.id!, tag: a.tag),
      'shared',
    );
    final key = chatOf[a.tag] ?? a.tag!;
    _sharedChats[key] = (_sharedChats[key] ?? 0) + 1;
    // one whose messages are not known counts as untimed
    final b = burns[a.tag];
    if (b == null || b.isEmpty) {
      _sharedTimes(null);
    } else {
      b.forEach(_sharedTimes);
    }
  }
  if (post && !await quietNow()) await _postShared(alert: false);
}

// a chat opened or cleared leaves it; the last one out takes it down. it
// says the same for one chat as for many, so it is not posted again
Future<void> _leaveShared(Set<String> keys) async {
  if (_sharedChats.isEmpty) return;
  var left = false;
  for (final k in keys) {
    left = _sharedChats.remove(k) != null || left;
  }
  _sharedUids.removeWhere((_, c) => keys.contains(c));
  if (left && _sharedChats.isEmpty) {
    _sharedReset();
    await cancelWithRetry(
      () => notifPlugin.cancel(id: _sharedId, tag: _sharedTag),
      'shared',
    );
  }
}

Future<bool> _isUp(int id, String tag) async {
  try {
    for (final a in await notifPlugin.getActiveNotifications()) {
      if (a.id == id && a.tag == tag) return true;
    }
  } catch (e) {
    dlog('shade: not read (${e.runtimeType})');
  }
  return false;
}

Future<void> _postShared({required bool alert}) async {
  final title = 'Kryfo';
  final body = l10n.notificationsNewMessage;
  final details = AndroidNotificationDetails(
    _messagesChannel,
    l10n.notificationsChannelName,
    tag: _sharedTag,
    channelDescription: l10n.notificationsNewEncryptedMessagesFromYourContacts,
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: false,
    category: AndroidNotificationCategory.message,
    icon: 'ic_halo_notification',
    color: const Color(0xFFF59E0B),
    visibility: NotificationVisibility.private,
    vibrationPattern: Int64List.fromList(<int>[0, 120, 90, 120]),
    enableLights: true,
    ledColor: const Color(0xFFF59E0B),
    ledOnMs: 600,
    ledOffMs: 2000,
    ticker: l10n.notificationsNewMessage2,
    autoCancel: true,
    // all of it timed: it goes with the last to burn
    timeoutAfter: _sharedUntimed || _sharedBurn == null
        ? null
        : max(1, _sharedBurn! - DateTime.now().millisecondsSinceEpoch),
    when: DateTime.now().millisecondsSinceEpoch,
    // no number: a badge would count what the words do not
    onlyAlertOnce: !alert,
    silent: !alert,
    styleInformation: BigTextStyleInformation(body, contentTitle: title),
  );
  await notifPlugin.show(
    id: _sharedId,
    title: title,
    body: body,
    notificationDetails: notifDetails(details, alert: alert),
    payload: kListPayload,
  );
}

Future<int?> _ringFold({
  required String chat,
  required String tag,
  required _Line line,
  bool support = false,
  bool silent = false,
  bool request = false,
}) => _foldTurnOf<int?>(() async {
  // a decoy may have opened while this waited its turn
  if (await quietNow()) return null;
  return _ringFoldNow(
    chat: chat,
    tag: tag,
    line: line,
    support: support,
    silent: silent,
    request: request,
  );
});

Future<int?> _ringFoldNow({
  required String chat,
  required String tag,
  required _Line line,
  required bool support,
  bool silent = false,
  bool request = false,
}) async {
  final gen = _clearGen;
  final chatGen = _chatGen[chat];
  bool stale() => gen != _clearGen || chatGen != _chatGen[chat];
  var fold = _folds[chat];
  // a chat whose tag changed starts over, and one that was a request and is
  // a chat now
  final channel = support
      ? _supportChannel
      : request
      ? _requestsChannel
      : _messagesChannel;
  if (fold != null && (fold.tag != tag || fold.channel != channel)) {
    _dropFold(chat);
    await cancelWithRetry(
      () => notifPlugin.cancel(id: fold!.id, tag: fold.tag),
      'shade',
    );
    fold = null;
  }
  // swiped away, or tapped with the chat never opened: what it held is not
  // posted again
  if (fold != null && !await _foldUp(fold)) {
    _dropFold(chat);
    fold = null;
  }
  if (fold == null) {
    await _makeRoom();
    if (request) await _makeRequestsChannel();
    fold = _Fold(tag, channel);
  }
  if (stale()) return null;
  // the one rung last at the end
  _folds.remove(chat);
  _folds[chat] = fold;
  fold.count++;
  fold.lines.add(line);
  if (fold.lines.length > _kKeptLines) fold.lines.removeAt(0);
  if (line.uid != null) {
    _shownForMsg[line.uid!] = (chat, fold.id, tag);
    // the oldest go first: a shade that full has been cleared long since
    if (_shownForMsg.length > 500) {
      _shownForMsg.remove(_shownForMsg.keys.first);
    }
  }
  return await _postFold(fold, alert: !silent, stale: stale) ? fold.id : null;
}

// a new chat's notification: the oldest chat's goes first when the shade
// holds the most it may. what an earlier process left counts too
Future<void> _makeRoom() async {
  var up = <ActiveNotification>[];
  try {
    up = [
      for (final a in await notifPlugin.getActiveNotifications())
        if (a.id != null &&
            a.tag != null &&
            (_named(a.channelId) || a.channelId == _supportChannel))
          a,
    ];
  } catch (e) {
    dlog('shade: not read (${e.runtimeType})');
  }
  final ours = {for (final f in _folds.values) (f.id, f.tag)};
  final older = [
    for (final a in up)
      if (!ours.contains((a.id, a.tag))) a,
  ];
  var total = _folds.length + older.length;
  for (final a in older) {
    if (total < kMaxChatNotifs) return;
    await cancelWithRetry(
      () => notifPlugin.cancel(id: a.id!, tag: a.tag),
      'shade',
    );
    total--;
  }
  while (_folds.length >= kMaxChatNotifs) {
    final chat = _folds.keys.first;
    await _clearChatNow(chat, tags: const {});
  }
}

// what a chat's notification says: the newest message as it would have
// shown alone, and above it the earlier ones that came under the same rules.
// a hidden one shows no earlier lines, and a timed one only while newest,
// so no words outlive their message or a stricter setting
Future<bool> _postFold(
  _Fold fold, {
  required bool alert,
  bool Function()? stale,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  fold.lines.removeWhere((l) => l.burnAt != null && l.burnAt! <= now);
  if (fold.lines.isEmpty) {
    _dropFoldOf(fold);
    await cancelWithRetry(
      () => notifPlugin.cancel(id: fold.id, tag: fold.tag),
      'shade',
    );
    return false;
  }
  final last = fold.lines.last;
  final shown = <_Line>[
    if (!last.hidden)
      for (final l in fold.lines.sublist(0, fold.lines.length - 1))
        if (!l.hidden && l.burnAt == null && l.title == last.title) l,
    last,
  ];
  final lines = shown.length > _kShownLines
      ? shown.sublist(shown.length - _kShownLines)
      : shown;
  final title = last.title;
  final body = last.body;
  final hidden = last.hidden;
  final StyleInformation style;
  if (_isSupport(fold)) {
    style = lines.length == 1
        ? BigTextStyleInformation(body, contentTitle: title)
        : InboxStyleInformation([
            for (final l in lines) l.body,
          ], contentTitle: title);
  } else {
    final summary = hidden ? null : l10n.notificationsEncrypted;
    style = lines.length == 1
        ? BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: summary,
          )
        : InboxStyleInformation(
            [for (final l in lines) l.body],
            contentTitle: title,
            summaryText: summary,
          );
  }
  final ticker = hidden ? l10n.notificationsNewMessage2 : '$title: $body';
  final AndroidNotificationDetails details;
  if (_isSupport(fold)) {
    details = _supportDetails(
      alert: alert,
      tag: fold.tag,
      ticker: ticker,
      style: style,
      number: fold.count,
      when: last.at,
    );
  } else {
    // a timed message leaves the shade its window after it came, read or
    // not, whatever is running then: android takes it down itself. the
    // message waits in the chat to be read
    // a timed one newest takes the whole fold down with it, the untimed
    // lines above it too: they wait in the chat, unread
    final left = last.burnAt == null ? null : max(1, last.burnAt! - now);
    final request = fold.channel == _requestsChannel;
    // a request sounds and pops up only with its switch on
    if (request && alert && !await loadRequestPopups()) alert = false;
    details = AndroidNotificationDetails(
      request ? _requestsChannel : _messagesChannel,
      request ? l10n.notifRequestsChannel : l10n.notificationsChannelName,
      tag: fold.tag,
      channelDescription: request
          ? l10n.notifRequestsChannelLine
          : l10n.notificationsNewEncryptedMessagesFromYourContacts,
      importance: request ? Importance.high : Importance.max,
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
      ticker: ticker,
      autoCancel: true,
      timeoutAfter: left,
      when: last.at,
      number: fold.count,
      // an update in place alerts again for a new message, never for a
      // line taken back
      onlyAlertOnce: !alert,
      silent: !alert,
      styleInformation: style,
    );
  }
  // a clear or a decoy since this began: nothing posted, nothing kept
  // stale is read after the await, so nothing comes between it and the post
  if (await quietNow() || (stale?.call() ?? false)) {
    _dropFoldOf(fold);
    return false;
  }
  await notifPlugin.show(
    id: fold.id,
    title: title,
    body: body,
    notificationDetails: notifDetails(details, alert: alert),
    payload: fold.tag,
  );
  return true;
}

void _dropFoldOf(_Fold fold) {
  for (final e in _folds.entries) {
    if (identical(e.value, fold)) {
      _dropFold(e.key);
      return;
    }
  }
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

// one that must not sound says so to a computer's toast too: android's own
// silent flag sits in [android]
@visibleForTesting
NotificationDetails notifDetails(
  AndroidNotificationDetails android, {
  required bool alert,
}) => NotificationDetails(
  android: android,
  windows: alert
      ? null
      : WindowsNotificationDetails(audio: WindowsNotificationAudio.silent()),
  linux: alert ? null : const LinuxNotificationDetails(suppressSound: true),
);

// [chat] is what this process knows it by; android sees only [tag]. the
// notification's id, null when none was shown
Future<int?> showMessageNotification({
  required String title,
  required String body,
  required String chat,
  required String tag,
  String? msgUid,
  int? burnAt,
  bool hidden = false,
  // sent without sound, or shown in the app already: posted with no sound,
  // no buzz and no heads-up, still in the shade
  bool silent = false,
  // from someone not added yet: rings only with its switch on
  bool request = false,
}) async {
  // a decoy session is open: no notification at all
  if (await quietNow()) return null;
  final ring = !silent && (!request || await loadRequestPopups());
  // plain wins over the preview setting: nothing of the message, or of
  // kryfo, in any field
  if (await loadNotifPlain()) {
    return _showPlain(chat: chat, tag: tag, msgUid: msgUid, silent: !ring);
  }
  // previews off: the one shared notification, for every chat
  if (await loadHideNotifContent()) {
    return _ringShared(chat: chat, msgUid: msgUid, burnAt: burnAt, alert: ring);
  }
  // a hidden chat's never says whose or what, whatever the preview setting:
  // android's history and watches keep what a notification said
  if (hidden) {
    title = 'Kryfo';
    body = l10n.notificationsNewMessage;
  }
  return _ringFold(
    chat: chat,
    tag: tag,
    silent: silent,
    line: _Line(
      uid: msgUid,
      title: title,
      body: body,
      hidden: hidden,
      burnAt: burnAt,
    ),
    request: request,
  );
}
