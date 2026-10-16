// SPDX-License-Identifier: GPL-3.0-or-later
// the app's own notification wiring, with only android's side a stand-in:
// a ring turns its chat into the tag its container keeps, a start clears
// what an older version left untagged, and a tap, warm or cold, opens what
// its tag names and nothing a bare chat id would
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        AppIo,
        openChatForNotif,
        openFromNotifForTest,
        openNotifChat,
        session,
        useDatabasesForTest;
import 'package:kryfo/notifications.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  final posted = <(int, String?, String?)>[];
  final payloads = <String?>[];
  DidReceiveNotificationResponseCallback? onTap;
  NotificationAppLaunchDetails? launch;

  List<int> get up => [for (final p in posted) p.$1];

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    onTap = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launch;

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {}

  @override
  Future<void> deleteNotificationChannel({required String channelId}) async {}

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    posted.add((id, notificationDetails?.tag, notificationDetails?.channelId));
    payloads.add(payload);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      posted.removeWhere((p) => p.$1 == id && p.$2 == tag);

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [
    for (final (id, tag, channel) in posted)
      ActiveNotification(id: id, tag: tag, channelId: channel),
  ];
}

NotificationResponse _tap(String? payload) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotification,
  payload: payload,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Shade shade;
  late ArrivalRows live;
  late List<String> opened;
  late List<String?> openedOn;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    shade = _Shade();
    FlutterLocalNotificationsPlatform.instance = shade;
    live = ArrivalRows(HaloContainer.everyday)..person('calm-orbit-lantern');
    useDatabasesForTest(live, Session(live));
    lockState.openForTest();
    opened = [];
    openedOn = [];
    openNotifChat = (chat, uid) async {
      opened.add(chat);
      openedOn.add(uid);
    };
  });

  tearDown(() {
    lockState.openForTest();
    debugDefaultTargetPlatformOverride = null;
    notifTagsOf = (_) async => const {};
  });

  test(
    'a ring gives android the tag its container keeps, never the chat',
    () async {
      await const AppIo().notify(
        title: 'Kryfo',
        body: 'new message',
        payload: 'calm-orbit-lantern',
        on: live,
      );
      await const AppIo().notify(
        title: 'Kryfo',
        body: 'another',
        payload: 'calm-orbit-lantern',
        on: live,
      );
      final tag = live.notifTags['calm-orbit-lantern']!;
      expect(shade.payloads, [tag, tag]);
      expect([for (final p in shade.posted) p.$2], [tag, tag]);
      for (final p in [...shade.payloads, ...shade.posted.map((p) => p.$2)]) {
        expect(p, isNot(contains('calm-orbit-lantern')));
      }
      // opening the chat takes both down by it
      await clearNotificationsFor('calm-orbit-lantern');
      expect(shade.up, isEmpty);
    },
  );

  test('a start clears what an older version left with no tag, and wires '
      'the lookup and the tap', () async {
    shade.posted.addAll([
      (11, null, 'halo_messages_v2'),
      (12, 'kept-tag', 'halo_messages_v2'),
    ]);
    final taps = <String?>[];
    await initNotifications(
      onTap: (p, _) => taps.add(p),
      tagsOf: (chat) async => chat == 'x' ? {'kept-tag'} : const {},
    );
    expect(shade.up, [12]);
    await clearNotificationsFor('x');
    expect(shade.up, isEmpty);
    shade.onTap!(_tap('some-tag'));
    expect(taps, ['some-tag']);
  });

  test(
    'a tap opens the chat its tag names, and a bare chat id opens nothing',
    () async {
      final tag = await live.notifTag('calm-orbit-lantern');
      await openChatForNotif(tag);
      expect(opened, ['calm-orbit-lantern']);
      await openChatForNotif('calm-orbit-lantern');
      await openChatForNotif('group:grp000000001');
      await openChatForNotif(null);
      expect(opened, ['calm-orbit-lantern']);
    },
  );

  test(
    'a tap waits for the lock, and is read in the session it opened to',
    () async {
      final tag = await live.notifTag('calm-orbit-lantern');
      lockState.openForTest(enabled: true);
      lockState.lock();
      expect(lockGuard.isLocked(), isTrue);
      await openChatForNotif(tag);
      expect(opened, isEmpty);
      // the decoy's pin opened it: an everyday tag names nothing there
      useDatabasesForTest(live, Session(ArrivalRows(HaloContainer.decoy)));
      lockState.openForTest();
      lockGuard.lifted();
      await Future<void>.delayed(Duration.zero);
      expect(opened, isEmpty);
      // the everyday pin
      final again = await live.notifTag('group:grp000000001');
      lockState.openForTest(enabled: true);
      lockState.lock();
      await openChatForNotif(again);
      useDatabasesForTest(live, Session(live));
      lockState.openForTest();
      lockGuard.lifted();
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['group:grp000000001']);
    },
  );

  test('a cold start from a notification opens what its tag names', () async {
    final tag = await live.notifTag('calm-orbit-lantern');
    shade.launch = NotificationAppLaunchDetails(
      true,
      notificationResponse: _tap(tag),
    );
    await openFromNotifForTest();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(opened, ['calm-orbit-lantern']);
    // a payload of an older version names a chat: it opens nothing
    shade.launch = NotificationAppLaunchDetails(
      true,
      notificationResponse: _tap('group:grp000000001'),
    );
    await openFromNotifForTest();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(opened, ['calm-orbit-lantern']);
  });

  test('the app starts notifications with the tap that reads tags', () {
    final src = File('lib/app/state.dart').readAsStringSync();
    expect(src, contains('onTap: openChatForNotif,'));
    expect(src, contains('tagsOf: (chat) => session.notifTagsOf(chat),'));
    expect(src, isNot(contains('initNotifications(onTap: openChatForHalo')));
  });

  test('a ring gives android the bare tag, keeps here which message it '
      'rang for, and its tap opens the chat on it', () async {
    live.msgs.add({'peer_id': 'calm-orbit-lantern', 'msg_uid': 'Ab3_x-9'});
    await const AppIo().notify(
      title: 'Kryfo',
      body: 'new message',
      payload: 'calm-orbit-lantern',
      on: live,
      msgUid: 'Ab3_x-9',
    );
    final tag = live.notifTags['calm-orbit-lantern']!;
    expect(shade.payloads, [tag]);
    final id = live.rings.keys.single;
    await openChatForNotif(tag, id);
    expect(opened, ['calm-orbit-lantern']);
    expect(openedOn, ['Ab3_x-9']);
    // once it left the shade nothing is kept of it: a tap then opens the
    // chat at its newest
    ringsForget = ({chat, msgUid}) =>
        live.forgetRings(chat: chat, msgUid: msgUid);
    addTearDown(() => ringsForget = ({chat, msgUid}) async {});
    await clearNotificationsFor('calm-orbit-lantern');
    await Future<void>.delayed(Duration.zero);
    expect(live.rings, isEmpty);
    expect(await session.ringOf(id, 'calm-orbit-lantern'), isNull);
  });
}
