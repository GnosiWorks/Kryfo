// SPDX-License-Identifier: GPL-3.0-or-later
// plain notifications: a channel of their own with the phone's sound and
// buzz, no title, one line, no colour, the glyph of the home screen's icon,
// and nothing of the sender or the message in any field. one at a time, so
// the shade never says how many came. a decoy still shows nothing at all
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  final posted = <(int, String?, String?)>[];
  final shown =
      <({String? title, String? body, AndroidNotificationDetails d})>[];
  final channels = <AndroidNotificationChannel>[];
  final payloads = <String?>[];

  List<int> get up => [for (final p in posted) p.$1];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    posted.add((id, notificationDetails?.tag, notificationDetails?.channelId));
    shown.add((title: title, body: body, d: notificationDetails!));
    payloads.add(payload);
  }

  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel c) async =>
      channels.add(c);

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      posted.removeWhere((p) => p.$1 == id && p.$2 == tag);

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [
    for (final (id, tag, channel) in posted)
      ActiveNotification(id: id, tag: tag, channelId: channel),
  ];
}

class _Faces implements AppFaceChannel {
  AppFace face = AppFace.kryfo;
  @override
  Future<AppFace?> read() async => face;
  @override
  Future<bool> switchTo(AppFace f) async => true;
}

final _faces = _Faces();

_Shade _start({Map<String, Object> prefs = const {}, bool quiet = false}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues({
    if (quiet) 'halo.lock.state': '{"q":true}',
  });
  forgetNotifPlain();
  forgetAppFace();
  _faces.face = AppFace.kryfo;
  appFaceChannel = _faces;
  final shade = _Shade();
  FlutterLocalNotificationsPlatform.instance = shade;
  return shade;
}

Future<void> _ring(String chat, String text, {String? uid, int? burnAt}) =>
    showMessageNotification(
      title: 'Bob Marsh',
      body: text,
      chat: chat,
      tag: 't-$chat',
      msgUid: uid,
      burnAt: burnAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // the service's words are asked for again; there is no android here
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('halo/platform'),
          (_) async => true,
        );
  });

  test('plain is the phone\'s setting, off until it is turned on', () async {
    _start();
    expect(await loadNotifPlain(), isFalse);
    expect(deviceKeys, contains('notif_plain'));
    // a decoy reads the same one
    expect(HaloContainer.decoy.key('notif_plain'), 'notif_plain');
    await setNotifPlain(true);
    expect(await loadNotifPlain(), isTrue);
    expect(notifPlainKnown(), isTrue);
  });

  test('a plain one says one line and nothing of anyone', () async {
    final shade = _start(prefs: {'notif_plain': true});
    final burnAt = DateTime.now().millisecondsSinceEpoch + 30000;
    await _ring('bob', 'meet at the bridge at six', uid: 'u1', burnAt: burnAt);
    final n = shade.shown.single;
    expect(n.title, isNull);
    expect(n.body, l10n.notifPlainLine);
    expect(n.d.channelId, 'kryfo_plain');
    expect(n.d.channelName, l10n.notifPlainChannel);
    expect(n.d.color, isNull);
    expect(n.d.ledColor, isNull);
    expect(n.d.enableLights, isFalse);
    expect(n.d.ticker, isNull);
    expect(n.d.styleInformation, isNull);
    expect(n.d.largeIcon, isNull);
    expect(n.d.vibrationPattern, isNull);
    expect(n.d.icon, 'ic_plain_dot');
    expect(n.d.visibility, NotificationVisibility.private);
    // a timed one says nothing of its time either
    expect(n.d.timeoutAfter, isNull);
    // nowhere in any field
    // (the tag is random in the app, the chat's name only here)
    final all =
        '${n.title} ${n.body} ${n.d.ticker} ${n.d.subText} '
        '${n.d.groupKey} ${n.d.channelDescription}';
    for (final w in ['Bob', 'Marsh', 'bridge', 'six', 'Kryfo']) {
      expect(all.contains(w), isFalse, reason: w);
    }
    // the channel: the phone's own buzz, not kryfo's two taps
    final ch = shade.channels.firstWhere((c) => c.id == 'kryfo_plain');
    expect(ch.vibrationPattern, isNull);
    expect(ch.name, l10n.notifPlainChannel);
    expect(ch.importance, Importance.high);
  });

  test('it wears the glyph of the icon on the home screen', () async {
    final shade = _start(prefs: {'notif_plain': true});
    _faces.face = AppFace.weather;
    await _ring('bob', 'hi');
    expect(shade.shown.single.d.icon, 'ic_plain_weather');
  });

  test('one at a time: a second leaves one up', () async {
    final shade = _start(prefs: {'notif_plain': true});
    await _ring('bob', 'one', uid: 'a');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await _ring('amy', 'two', uid: 'b');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await _ring('bob', 'three', uid: 'c');
    expect(shade.shown, hasLength(3));
    expect(shade.up, hasLength(1));
    // posted anew each time, so the phone still alerts
    expect(shade.shown.map((s) => s.d.channelId).toSet(), {'kryfo_plain'});
  });

  test('one an earlier process left goes too, by its channel', () async {
    final shade = _start(prefs: {'notif_plain': true});
    shade.posted.add((77, 't-old', 'kryfo_plain'));
    shade.posted.add((5, 't-x', 'halo_messages_v2'));
    await _ring('bob', 'hi');
    expect(shade.up, hasLength(2));
    expect(shade.up, isNot(contains(77)));
    expect(shade.up, contains(5));
  });

  test('plain wins over a preview shown', () async {
    final shade = _start(
      prefs: {'notif_plain': true, 'notif_hide_content': false},
    );
    await _ring('bob', 'the words');
    expect(shade.shown.single.body, l10n.notifPlainLine);
    expect(shade.shown.single.title, isNull);
  });

  test('off, the preview setting decides as before', () async {
    final shade = _start(prefs: {'notif_hide_content': false});
    await _ring('bob', 'the words');
    expect(shade.shown.single.body, 'the words');
    expect(shade.shown.single.d.channelId, 'halo_messages_v2');
    // no plain channel on a phone that never turned it on
    expect(shade.channels.where((c) => c.id == 'kryfo_plain'), isEmpty);
  });

  test('a decoy session shows nothing, plain or not', () async {
    final shade = _start(prefs: {'notif_plain': true}, quiet: true);
    expect(await _ringId('bob'), isNull);
    expect(shade.shown, isEmpty);
  });

  test('opening kryfo takes the plain one down, and only it', () async {
    final shade = _start(prefs: {'notif_plain': true});
    await _ring('bob', 'hi');
    shade.posted.add((1, null, 'halo_listener_v2'));
    await clearPlainNotification();
    expect(shade.up, [1]);
  });

  test('opening the chat it rang for takes it down', () async {
    final shade = _start(prefs: {'notif_plain': true});
    await _ring('bob', 'hi', uid: 'm1');
    await clearNotificationsFor('bob');
    expect(shade.up, isEmpty);
  });

  test('every plain line goes under one tag, whoever wrote', () async {
    final shade = _start(prefs: {'notif_plain': true});
    await _ring('bob', 'one');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await _ring('amy', 'two');
    final tags = {for (final s in shade.shown) s.d.tag};
    expect(tags, hasLength(1));
    expect(tags.single, isNot(anyOf('t-bob', 't-amy')));
    // the tap still opens the newest one's chat
    expect(shade.payloads.last, 't-amy');
  });

  test('two arriving together still leave one line', () async {
    final shade = _start(prefs: {'notif_plain': true});
    final a = _ring('bob', 'one');
    final b = _ring('amy', 'two');
    final c = _ring('cy', 'three');
    await Future.wait([a, b, c]);
    expect(shade.shown, hasLength(3));
    expect(shade.up, hasLength(1));
  });

  test('turning plain on puts one plain line in place of named ones', () async {
    final shade = _start(prefs: {'notif_hide_content': false});
    await _ring('bob', 'meet at six');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await _ring('amy', 'the address');
    expect(shade.up, hasLength(2));
    await setNotifPlain(true);
    expect(shade.posted, hasLength(1));
    final last = shade.shown.last;
    expect(last.d.channelId, 'kryfo_plain');
    expect(last.body, l10n.notifPlainLine);
    expect(last.title, isNull);
    // for the newest one's chat
    expect(shade.payloads.last, 't-amy');
    // opening that chat takes it down
    await clearNotificationsFor('amy');
    expect(shade.up, isEmpty);
  });

  test('turning plain on with nothing up posts nothing', () async {
    final shade = _start();
    await setNotifPlain(true);
    expect(shade.shown, isEmpty);
  });

  test('a decoy turning plain on posts nothing', () async {
    final shade = _start(quiet: true);
    shade.posted.add((9, 't-x', 'halo_messages_v2'));
    await setNotifPlain(true);
    expect(shade.shown, isEmpty);
  });
}

Future<int?> _ringId(String chat) => showMessageNotification(
  title: 'Bob',
  body: 'x',
  chat: chat,
  tag: 't-$chat',
);
