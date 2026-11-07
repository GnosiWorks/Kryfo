// SPDX-License-Identifier: GPL-3.0-or-later
// one notification per chat, updated in place: android keeps about 25 up
// per app and drops the rest without a word. a folded one never shows more
// than each message would have shown alone
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'source_body.dart';

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  // id, tag and channel of what is up
  final posted = <(int, String?, String?)>[];
  final shown =
      <({int id, String? title, String? body, AndroidNotificationDetails d})>[];

  List<int> get up => [for (final p in posted) p.$1];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    final tag = notificationDetails?.tag;
    posted.removeWhere((p) => p.$1 == id && p.$2 == tag);
    posted.add((id, tag, notificationDetails?.channelId));
    shown.add((id: id, title: title, body: body, d: notificationDetails!));
  }

  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel c) async {}

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      posted.removeWhere((p) => p.$1 == id && p.$2 == tag);

  @override
  Future<void> cancelAll() async => posted.clear();

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [
    for (final (id, tag, channel) in posted)
      ActiveNotification(id: id, tag: tag, channelId: channel),
  ];
}

_Shade _start({bool hide = false}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  SharedPreferences.setMockInitialValues({
    HaloContainer.everyday.key('notif_hide_content'): hide,
  });
  FlutterSecureStorage.setMockInitialValues({});
  forgetNotifPlain();
  forgetFolds();
  final shade = _Shade();
  FlutterLocalNotificationsPlatform.instance = shade;
  return shade;
}

Future<int?> _ring(
  String chat,
  String body, {
  String title = 'Bob',
  String? uid,
  int? burnAt,
  bool hidden = false,
}) => showMessageNotification(
  title: title,
  body: body,
  chat: chat,
  tag: 't-$chat',
  msgUid: uid,
  burnAt: burnAt,
  hidden: hidden,
);

List<String> _lines(AndroidNotificationDetails d) {
  final s = d.styleInformation;
  if (s is InboxStyleInformation) return s.lines;
  if (s is BigTextStyleInformation) return [s.bigText];
  return const [];
}

// every word a notification carries to android
String _words(
  ({int id, String? title, String? body, AndroidNotificationDetails d}) s,
) {
  final st = s.d.styleInformation;
  return [
    s.title,
    s.body,
    s.d.ticker,
    ..._lines(s.d),
    if (st is InboxStyleInformation) ...[st.contentTitle, st.summaryText],
    if (st is BigTextStyleInformation) ...[st.contentTitle, st.summaryText],
  ].whereType<String>().join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repeated messages in one chat reuse one id', () async {
    final shade = _start();
    final ids = <int?>[];
    for (var i = 0; i < 30; i++) {
      ids.add(await _ring('bob', 'm$i', uid: 'u$i'));
    }
    expect(ids.toSet(), hasLength(1));
    expect(ids.toSet().single, notifIdFor('t-bob'));
    expect(shade.up, hasLength(1));
    final last = shade.shown.last;
    expect(last.d.number, 30);
    expect(last.body, 'm29');
    // the newest lines, oldest first, and every post alerts
    expect(_lines(last.d), ['m24', 'm25', 'm26', 'm27', 'm28', 'm29']);
    expect(shade.shown.every((s) => !s.d.silent && !s.d.onlyAlertOnce), isTrue);
  });

  test('one message alone shows as it always did', () async {
    final shade = _start();
    await _ring('bob', 'hi');
    final s = shade.shown.single;
    final st = s.d.styleInformation! as BigTextStyleInformation;
    expect(st.bigText, 'hi');
    expect(st.contentTitle, 'Bob');
    expect(st.summaryText, l10n.notificationsEncrypted);
    expect(s.d.visibility, NotificationVisibility.private);
    expect(s.d.groupKey, isNull);
  });

  test('two chats get two ids', () async {
    final shade = _start();
    final a = await _ring('bob', 'one');
    final b = await _ring('amy', 'two', title: 'Amy');
    expect(a, isNot(b));
    expect(shade.up, hasLength(2));
    expect(shade.posted.map((p) => p.$2).toSet(), {'t-bob', 't-amy'});
  });

  test('the id is cut from the tag alone, clear of the fixed ones', () {
    expect(notifIdFor('t-bob'), notifIdFor('t-bob'));
    for (var i = 0; i < 200; i++) {
      final id = notifIdFor(newNotifTag());
      expect(id, inInclusiveRange(0x10000, 0x7fffffff));
    }
  });

  test(
    'opening a chat cancels its notification, and the next starts over',
    () async {
      final shade = _start();
      await _ring('bob', 'one', uid: 'a');
      await _ring('bob', 'two', uid: 'b');
      await _ring('amy', 'hey', title: 'Amy');
      await clearNotificationsFor('bob');
      expect(shade.posted.map((p) => p.$2), ['t-amy']);
      await _ring('bob', 'three', uid: 'c');
      expect(shade.shown.last.d.number, 1);
      expect(_lines(shade.shown.last.d), ['three']);
      expect(ringIsFirst('bob'), isTrue);
      await _ring('bob', 'four', uid: 'd');
      expect(ringIsFirst('bob'), isFalse);
    },
  );

  test('the chat screens take their chat down on open', () {
    expect(
      sourceOf('lib/screens/chat_screen.dart'),
      contains('clearNotificationsFor(widget.peerHaloId)'),
    );
    expect(
      sourceOf('lib/screens/group_chat_screen.dart'),
      contains("clearNotificationsFor('group:\${widget.groupId}')"),
    );
  });

  test('many chats stay under the shade limit, the oldest goes', () async {
    final shade = _start();
    // what an earlier process left counts too
    shade.posted.add((5, 't-old', 'halo_messages_v2'));
    for (var i = 0; i < kMaxChatNotifs + 10; i++) {
      await _ring('c$i', 'hi $i', uid: 'u$i');
    }
    expect(shade.up, hasLength(kMaxChatNotifs));
    final tags = shade.posted.map((p) => p.$2).toSet();
    expect(tags, isNot(contains('t-old')));
    expect(tags, isNot(contains('t-c0')));
    expect(tags, contains('t-c${kMaxChatNotifs + 9}'));
    // a chat updated in place takes no more room
    await _ring('c${kMaxChatNotifs + 9}', 'again');
    expect(shade.up, hasLength(kMaxChatNotifs));
  });

  test('previews off: a fold says only kryfo and new message', () async {
    final shade = _start(hide: true);
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'the address is 4 elm', uid: 'b');
    for (final s in shade.shown) {
      expect(_words(s), isNot(contains('six')));
      expect(_words(s), isNot(contains('elm')));
      expect(_words(s), isNot(contains('Bob')));
    }
    final last = shade.shown.last;
    expect(last.title, 'Kryfo');
    expect(last.body, l10n.notificationsNewMessage);
    expect(_lines(last.d), [l10n.notificationsNewMessage]);
    expect(last.d.number, 2);
  });

  test('a hidden chat folds without its earlier words', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'secret', uid: 'b', hidden: true);
    final last = shade.shown.last;
    expect(_words(last), isNot(contains('six')));
    expect(_words(last), isNot(contains('Bob')));
    expect(last.title, 'Kryfo');
    expect(_lines(last.d), [l10n.notificationsNewMessage]);
  });

  test('a stricter title drops the lines shown under the old one', () async {
    final shade = _start();
    // a chat that turned screenshot blocking on rings as kryfo
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', l10n.notificationsNewMessage, title: 'Kryfo', uid: 'b');
    expect(_words(shade.shown.last), isNot(contains('six')));
    expect(_words(shade.shown.last), isNot(contains('Bob')));
  });

  test('a timed message never outlives its window in a fold', () async {
    final shade = _start();
    final burnAt = DateTime.now().millisecondsSinceEpoch + 30000;
    await _ring('bob', 'gone soon', uid: 'a', burnAt: burnAt);
    expect(shade.shown.last.d.timeoutAfter, inInclusiveRange(28000, 30000));
    // a later one without a timer drops its words, and has no timeout
    await _ring('bob', 'staying', uid: 'b');
    expect(_words(shade.shown.last), isNot(contains('gone soon')));
    expect(shade.shown.last.d.timeoutAfter, isNull);
    // a timed one newest takes the fold down with it
    await _ring('bob', 'brief', uid: 'c', burnAt: burnAt);
    expect(shade.shown.last.d.timeoutAfter, inInclusiveRange(28000, 30000));
  });

  test('one taken back loses its words from the fold, quietly', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    await clearMessageNotification('a');
    final last = shade.shown.last;
    expect(_words(last), isNot(contains('six')));
    expect(last.d.silent, isTrue);
    expect(last.d.number, 1);
    expect(shade.up, hasLength(1));
  });

  test('clearing the whole shade forgets the folds', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await clearAllNotifications('test');
    expect(shade.up, isEmpty);
    await _ring('bob', 'later', uid: 'b');
    expect(_words(shade.shown.last), isNot(contains('six')));
    expect(shade.shown.last.d.number, 1);
  });

  test('a support chat folds under its tag too', () async {
    final shade = _start();
    for (var i = 0; i < 5; i++) {
      await showSupportMessage(
        chatId: 'calm-orbit-lantern',
        tag: 't-support',
        title: 'Kryfo',
        body: 'hi $i',
      );
    }
    expect(shade.up, hasLength(1));
    expect(shade.shown.map((s) => s.id).toSet(), {notifIdFor('t-support')});
    expect(shade.shown.last.d.number, 5);
    await clearNotificationsFor('calm-orbit-lantern');
    expect(shade.up, isEmpty);
  });

  test('a decoy session still shows nothing', () async {
    final shade = _start();
    FlutterSecureStorage.setMockInitialValues({
      'halo.lock.state': '{"q":true}',
    });
    expect(await _ring('bob', 'hi'), isNull);
    expect(shade.shown, isEmpty);
  });
}
