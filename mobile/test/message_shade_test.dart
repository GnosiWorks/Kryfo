// SPDX-License-Identifier: GPL-3.0-or-later
// a message taken back takes its own notification down, not the rest of its
// chat's. android sees a random tag per chat, never the chat. its side is a
// stand-in that notes what it was asked, and cancels as android does: by id
// and tag together
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  // id, tag and channel of what is up
  final posted = <(int, String?, String?)>[];
  final timeouts = <int?>[];
  final payloads = <String?>[];
  final details = <AndroidNotificationDetails?>[];

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
    timeouts.add(notificationDetails?.timeoutAfter);
    payloads.add(payload);
    details.add(notificationDetails);
  }

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {}

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      posted.removeWhere((p) => p.$1 == id && p.$2 == tag);

  // the shade gives back ids, tags and channels, never payloads
  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [
    for (final (id, tag, channel) in posted)
      ActiveNotification(id: id, tag: tag, channelId: channel),
  ];
}

_Shade _start() {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final shade = _Shade();
  FlutterLocalNotificationsPlatform.instance = shade;
  return shade;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => notifTagsOf = (_) async => const {});

  test('only the one taken back leaves the shade', () async {
    final shade = _start();
    await showMessageNotification(
      title: 'bob',
      body: 'call me',
      chat: 'bob',
      tag: 't-bob',
      msgUid: 'u1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await showMessageNotification(
      title: 'bob',
      body: 'at 6',
      chat: 'bob',
      tag: 't-bob',
      msgUid: 'u2',
    );
    expect(shade.up, hasLength(2));
    final second = shade.up.last;
    await clearMessageNotification('u1');
    expect(shade.up, [second]);
    // asked twice, or for one never shown: nothing more goes
    await clearMessageNotification('u1');
    await clearMessageNotification('nobody');
    expect(shade.up, [second]);
    await clearNotificationsFor('bob');
    expect(shade.up, isEmpty);
  });

  test('a timed message leaves the shade by itself when it burns', () async {
    final shade = _start();
    final burnAt = DateTime.now().millisecondsSinceEpoch + 30000;
    await showMessageNotification(
      title: 'bob',
      body: 'gone soon',
      chat: 'bob',
      tag: 't-bob',
      msgUid: 'b1',
      burnAt: burnAt,
    );
    await showMessageNotification(
      title: 'bob',
      body: 'staying',
      chat: 'bob',
      tag: 't-bob',
      msgUid: 'b2',
    );
    expect(shade.timeouts.first, inInclusiveRange(28000, 30000));
    expect(shade.timeouts.last, isNull);
    await clearNotificationsFor('bob');
  });

  test('android is given the tag, never the chat', () async {
    final shade = _start();
    final tag = newNotifTag();
    await showMessageNotification(
      title: 'Kryfo',
      body: 'new message',
      chat: 'group:grp000000001',
      tag: tag,
    );
    expect(shade.payloads, [tag]);
    expect(shade.details.single!.tag, tag);
    expect(shade.details.single!.groupKey, isNull);
    expect(shade.details.single!.channelId, 'halo_messages_v2');
    await clearNotificationsFor('group:grp000000001');
    expect(shade.up, isEmpty);
  });

  test('a support chat rings under its tag too', () async {
    final shade = _start();
    await showSupportMessage(
      chatId: 'calm-orbit-lantern',
      tag: 't-support',
      title: 'Kryfo',
      body: 'hi',
    );
    expect(shade.payloads, ['t-support']);
    expect(shade.details.single!.tag, 't-support');
    await clearNotificationsFor('calm-orbit-lantern');
    expect(shade.up, isEmpty);
  });

  test('tags are random, one per call', () {
    final tags = {for (var i = 0; i < 50; i++) newNotifTag()};
    expect(tags, hasLength(50));
    for (final t in tags) {
      expect(t, matches(RegExp(r'^[0-9a-f]{32}$')));
    }
  });

  test(
    'what an earlier run showed for a chat leaves the shade by its tag',
    () async {
      final shade = _start();
      shade.posted.addAll([
        (7, 'tag-of-guitar', 'halo_messages_v2'),
        (8, 'tag-of-guitar', 'halo_messages_v2'),
        (9, 'tag-of-amy', 'halo_messages_v2'),
      ]);
      final asked = <String>[];
      notifTagsOf = (chat) async {
        asked.add(chat);
        return chat == 'guitar-present-kid' ? {'tag-of-guitar'} : const {};
      };
      await clearNotificationsFor('guitar-present-kid');
      expect(asked, ['guitar-present-kid']);
      expect(shade.up, [9]);
      // a chat with no tag anywhere takes nothing down
      await clearNotificationsFor('someone-else');
      expect(shade.up, [9]);
    },
  );

  test('a tag lookup that fails still clears what this run showed', () async {
    final shade = _start();
    notifTagsOf = (_) async => throw StateError('shut');
    await showMessageNotification(
      title: 'Kryfo',
      body: 'new message',
      chat: 'bob',
      tag: 't-bob',
    );
    await clearNotificationsFor('bob');
    expect(shade.up, isEmpty);
  });

  test('an older version\'s untagged notifications go at start', () async {
    final shade = _start();
    shade.posted.addAll([
      // an older version's, on the message and support channels
      (11, null, 'halo_messages_v2'),
      (12, null, 'halo_support'),
      // a tagged one, the support summary, the service's own and another
      // channel's stay
      (13, 'abc', 'halo_messages_v2'),
      (0x5e7, null, 'halo_support'),
      (1, null, 'halo_listener_v2'),
      (14, null, 'other'),
    ]);
    await clearUntaggedShade();
    expect(shade.up, [13, 0x5e7, 1, 14]);
    // a second start finds nothing more
    await clearUntaggedShade();
    expect(shade.up, [13, 0x5e7, 1, 14]);
  });

  test('below channels, only the service and the summary stay', () async {
    final shade = _start();
    shade.posted.addAll([
      (21, null, null),
      (1, null, null),
      (0x5e7, null, null),
    ]);
    await clearUntaggedShade();
    expect(shade.up, [1, 0x5e7]);
  });
}
