// SPDX-License-Identifier: GPL-3.0-or-later
// one notification per chat, updated in place: android keeps about 25 up
// per app and drops the rest without a word. a folded one never shows more
// than each message would have shown alone
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:flutter/services.dart';
import 'package:kryfo/chat_shots.dart' show ChatShots;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show AppIo, HaloDb;
import 'package:kryfo/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'source_body.dart';

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  // id, tag and channel of what is up
  final posted = <(int, String?, String?)>[];
  final shown =
      <({int id, String? title, String? body, AndroidNotificationDetails d})>[];

  List<int> get up => [for (final p in posted) p.$1];
  // the next shade read waits for this
  Completer<void>? holdRead;

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
    payloads.add(payload);
  }

  final payloads = <String?>[];

  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel c) async {}

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      posted.removeWhere((p) => p.$1 == id && p.$2 == tag);

  @override
  Future<void> cancelAll() async => posted.clear();

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    // read now, answered later: what was up when asked
    final up = [
      for (final (id, tag, channel) in posted)
        ActiveNotification(id: id, tag: tag, channelId: channel),
    ];
    final hold = holdRead;
    if (hold != null) {
      holdRead = null;
      await hold.future;
    }
    return up;
  }
}

_Shade _start({bool hide = false, bool? popups}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  SharedPreferences.setMockInitialValues({
    HaloContainer.everyday.key('notif_hide_content'): hide,
    if (popups != null)
      HaloContainer.everyday.key('kryfo.requests.popups'): popups,
  });
  FlutterSecureStorage.setMockInitialValues({});
  forgetNotifPlain();
  forgetFolds();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('halo/platform'),
        (_) async => true,
      );
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
  bool request = false,
}) => showMessageNotification(
  title: title,
  body: body,
  chat: chat,
  tag: 't-$chat',
  msgUid: uid,
  burnAt: burnAt,
  hidden: hidden,
  request: request,
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

// the rows a ring asks for its tag and keeps its first ring in
class _Rows implements HaloDb {
  final rings = <(int, String, String)>[];
  @override
  Future<String> notifTag(String chat) async => 't-$chat';
  @override
  Future<void> noteRing(int id, String chat, String msgUid) async =>
      rings.add((id, chat, msgUid));
  @override
  Future<ChatShots> shotsOf(String peer) async => const ChatShots();
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// what the shade showed last under a chat's tag
({int id, String? title, String? body, AndroidNotificationDetails d}) _lastOf(
  _Shade shade,
  String chat,
) => shade.shown.lastWhere((s) => s.d.tag == 't-$chat');

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

  group('message requests', () {
    test('off: on their own channel, no sound, no pop-up', () async {
      final shade = _start(popups: false);
      expect(await loadRequestPopups(), isFalse);
      await _ring('stranger', 'New request', uid: 'r1', request: true);
      final s = _lastOf(shade, 'stranger');
      expect(s.d.channelId, 'kryfo_requests');
      expect(s.d.silent, isTrue);
      // a chat's message still rings as before
      await _ring('bob', 'hi', uid: 'm1');
      final m = _lastOf(shade, 'bob');
      expect(m.d.channelId, 'halo_messages_v2');
      expect(m.d.silent, isFalse);
    });

    test('with the switch on a request pops up and sounds', () async {
      final shade = _start(popups: true);
      await _ring('stranger', 'New request', uid: 'r1', request: true);
      final s = _lastOf(shade, 'stranger');
      expect(s.d.channelId, 'kryfo_requests');
      expect(s.d.silent, isFalse);
      expect(s.d.importance, Importance.high);
    });

    test(
      'a new install starts off, a phone updating keeps them ringing',
      () async {
        _start();
        // not settled yet: as before
        expect(await loadRequestPopups(), isTrue);
        await settleRequestPopups(existing: false);
        expect(await loadRequestPopups(), isFalse);
        // once settled, a later start leaves it
        await settleRequestPopups(existing: true);
        expect(await loadRequestPopups(), isFalse);
        _start();
        await settleRequestPopups(existing: true);
        expect(await loadRequestPopups(), isTrue);
      },
    );

    test('the switch is kept', () async {
      _start();
      await saveRequestPopups(true);
      expect(await loadRequestPopups(), isTrue);
      await saveRequestPopups(false);
      expect(await loadRequestPopups(), isFalse);
    });

    test('previews off: the shared one takes it in quietly', () async {
      final shade = _start(hide: true, popups: false);
      await _ring('stranger', 'New request', uid: 'r1', request: true);
      expect(shade.shown.last.d.silent, isTrue);
      expect(shade.shown.last.title, 'Kryfo');
    });

    test('accepted, the chat starts over on the messages channel', () async {
      final shade = _start(popups: false);
      await _ring('stranger', 'New request', uid: 'r1', request: true);
      await _ring('stranger', 'hello', uid: 'r2');
      expect(_lastOf(shade, 'stranger').d.channelId, 'halo_messages_v2');
      expect(shade.posted.where((p) => p.$2 == 't-stranger'), hasLength(1));
    });
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
    // no count anywhere
    expect(last.d.number, isNull);
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

  test('swiped away, a line taken back posts nothing again', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    shade.posted.clear();
    final before = shade.shown.length;
    await clearMessageNotification('a');
    expect(shade.shown, hasLength(before));
    expect(shade.up, isEmpty);
    // a burn of the other finds nothing to post either
    await clearMessageNotification('b');
    expect(shade.shown, hasLength(before));
  });

  test('swiped away, plain on, a line taken back posts no name', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    shade.posted.clear();
    await setNotifPlain(true);
    final before = shade.shown.length;
    await clearMessageNotification('a');
    expect(shade.shown, hasLength(before));
    expect(ringIsFirst('bob'), isTrue);
  });

  test('plain on with folds up: nothing named is posted after', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    await setNotifPlain(true);
    await clearMessageNotification('a');
    for (final s in shade.shown.skipWhile((s) => s.d.tag == 't-bob')) {
      expect(_words(s), isNot(contains('Bob')));
      expect(_words(s), isNot(contains('see you')));
    }
  });

  test('previews off while up: a repost says only kryfo', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    await setHideNotifContent(true);
    await clearMessageNotification('a');
    final last = shade.shown.last;
    expect(_words(last), isNot(contains('Bob')));
    expect(_words(last), isNot(contains('see you')));
    expect(shade.up, hasLength(1));
  });

  test('previews off after a swipe: nothing is posted again', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    shade.posted.clear();
    await setHideNotifContent(true);
    final before = shade.shown.length;
    await clearMessageNotification('a');
    expect(shade.shown, hasLength(before));
    await _ring('bob', 'later', uid: 'c', hidden: true);
    expect(_words(shade.shown.last), isNot(contains('see you')));
  });

  test('swiped away, a new message starts over', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    shade.posted.clear();
    await _ring('bob', 'hello again', uid: 'c');
    expect(_lines(shade.shown.last.d), ['hello again']);
    expect(shade.shown.last.d.number, 1);
    expect(ringIsFirst('bob'), isTrue);
  });

  test('a tapped one, the chat never opened, starts over too', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    // autoCancel: the tap takes it down, the chat stays closed
    shade.posted.clear();
    await _ring('bob', 'hi', uid: 'b');
    expect(_words(shade.shown.last), isNot(contains('six')));
  });

  test('a line past the 500 kept by message still leaves its fold', () async {
    final shade = _start();
    await _ring('bob', 'secret plan', uid: 'x0');
    await _ring('bob', 'fine', uid: 'x1');
    for (var i = 0; i < 505; i++) {
      await _ring('amy', 'm$i', title: 'Amy', uid: 'y$i');
    }
    await clearMessageNotification('x0');
    final last = _lastOf(shade, 'bob');
    expect(_words(last), isNot(contains('secret')));
    expect(last.d.number, 1);
    expect(shade.posted.map((p) => p.$2), contains('t-bob'));
  });

  test('two first arrivals at once in one chat make one fold', () async {
    final shade = _start();
    await Future.wait([
      _ring('bob', 'one', uid: 'a'),
      _ring('bob', 'two', uid: 'b'),
      _ring('amy', 'three', title: 'Amy', uid: 'c'),
    ]);
    expect(shade.up, hasLength(2));
    expect(_lastOf(shade, 'bob').d.number, 2);
    await clearMessageNotification('a');
    expect(shade.up, hasLength(2));
  });

  test('a fold keeps the ring of its first message only', () async {
    final shade = _start();
    final rows = _Rows();
    const io = AppIo();
    Future<void> say(String uid) => io.notify(
      title: 'Bob',
      body: 'hi $uid',
      payload: 'bob',
      on: rows,
      msgUid: uid,
    );
    await say('a');
    await say('b');
    expect(rows.rings.map((r) => r.$3), ['a']);
    // swiped, then plain on: the next plain ring is kept, no stale fold
    shade.posted.clear();
    await setNotifPlain(true);
    await say('c');
    expect(rows.rings.map((r) => r.$3), ['a', 'c']);
    await say('d');
    expect(rows.rings.map((r) => r.$3), ['a', 'c', 'd']);
  });

  test('a take-back of a swiped fold leaves the next one up', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    shade.posted.clear();
    await _ring('bob', 'see you', uid: 'b');
    await clearMessageNotification('a');
    expect(shade.posted.map((p) => p.$2), ['t-bob']);
    expect(_lastOf(shade, 'bob').body, 'see you');
  });

  test('a decoy clear during a ring posts nothing and keeps no fold', () async {
    final shade = _start();
    final hold = Completer<void>();
    shade.holdRead = hold;
    final ring = _ring('bob', 'meet at six', uid: 'a');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // the decoy opens and clears while the shade read waits
    FlutterSecureStorage.setMockInitialValues({
      'halo.lock.state': '{"q":true}',
    });
    final cleared = clearAllNotifications('decoy shade');
    hold.complete();
    expect(await ring, isNull);
    await cleared;
    expect(shade.shown, isEmpty);
    expect(shade.up, isEmpty);
    // back in the real app, nothing of it comes back
    FlutterSecureStorage.setMockInitialValues({});
    await _ring('bob', 'later', uid: 'b');
    expect(_words(shade.shown.last), isNot(contains('six')));
    expect(shade.shown.last.d.number, 1);
  });

  test('a chat cleared during its ring keeps no fold', () async {
    final shade = _start();
    final hold = Completer<void>();
    shade.holdRead = hold;
    final ring = _ring('bob', 'meet at six', uid: 'a');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final cleared = clearNotificationsFor('bob');
    hold.complete();
    expect(await ring, isNull);
    await cleared;
    expect(shade.up, isEmpty);
    await _ring('bob', 'later', uid: 'b');
    expect(_words(shade.shown.last), isNot(contains('six')));
  });

  test('plain on then off, an old take-back leaves the new fold up', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await setNotifPlain(true);
    await setNotifPlain(false);
    shade.posted.clear();
    await _ring('bob', 'see you', uid: 'b');
    await clearMessageNotification('a');
    expect(shade.posted.map((p) => p.$2), ['t-bob']);
    expect(_lastOf(shade, 'bob').body, 'see you');
  });

  test('a chat cleared during a take-back gets no repost', () async {
    final shade = _start();
    await _ring('bob', 'meet at six', uid: 'a');
    await _ring('bob', 'see you', uid: 'b');
    final before = shade.shown.length;
    final hold = Completer<void>();
    shade.holdRead = hold;
    final back = clearMessageNotification('a');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await clearNotificationsFor('bob');
    hold.complete();
    await back;
    expect(shade.shown, hasLength(before));
    expect(shade.up, isEmpty);
  });

  test(
    'previews off, three chats: one notification, its tap the list',
    () async {
      final shade = _start(hide: true);
      await _ring('bob', 'meet at six', uid: 'a');
      await _ring('amy', 'the address', title: 'Amy', uid: 'b');
      await _ring('cy', 'call me', title: 'Cy', uid: 'c');
      await _ring('cy', 'now', title: 'Cy', uid: 'd');
      expect(shade.up, hasLength(1));
      expect(shade.up.single, sharedNotifId);
      expect(shade.payloads.toSet(), {kListPayload});
      // the same words, tag and id whoever wrote and however many
      final words = {for (final s in shade.shown) _words(s)};
      expect(words, hasLength(1));
      for (final s in shade.shown) {
        for (final w in ['Bob', 'Amy', 'Cy', 'six', 'address', '2', '3', '4']) {
          expect(_words(s), isNot(contains(w)));
        }
        expect(s.d.number, isNull);
        expect(s.d.tag, isNot(anyOf('t-bob', 't-amy', 't-cy')));
        expect(s.d.visibility, NotificationVisibility.private);
      }
    },
  );

  test(
    'previews off: the last chat opened takes the shared one down',
    () async {
      final shade = _start(hide: true);
      await _ring('bob', 'one', uid: 'a');
      await _ring('amy', 'two', title: 'Amy', uid: 'b');
      await clearNotificationsFor('bob');
      expect(shade.up, [sharedNotifId]);
      await clearMessageNotification('b');
      expect(shade.up, isEmpty);
    },
  );

  test(
    'previews turned off folds every named one into the shared one',
    () async {
      final shade = _start();
      await _ring('bob', 'meet at six', uid: 'a');
      await _ring('amy', 'the address', title: 'Amy', uid: 'b');
      // one an earlier process left goes in too
      shade.posted.add((9, 't-old', 'halo_messages_v2'));
      expect(shade.up, hasLength(3));
      await setHideNotifContent(true);
      expect(shade.up, [sharedNotifId]);
      final last = shade.shown.last;
      expect(last.d.silent, isTrue);
      expect(_words(last), isNot(contains('Bob')));
      expect(_words(last), isNot(contains('six')));
      expect(shade.payloads.last, kListPayload);
      // opening every chat it stands for takes it down
      await clearNotificationsFor('bob');
      await clearNotificationsFor('amy');
      expect(shade.up, [sharedNotifId]);
      await clearNotificationsFor('old', tags: {'t-old'});
      expect(shade.up, isEmpty);
    },
  );

  test('previews turned on: per chat from the next message', () async {
    final shade = _start(hide: true);
    await _ring('bob', 'one', uid: 'a');
    await setHideNotifContent(false);
    await _ring('amy', 'the address', title: 'Amy', uid: 'b');
    expect(shade.up, hasLength(2));
    expect(shade.up, contains(sharedNotifId));
    expect(_lastOf(shade, 'amy').body, 'the address');
    // and back off: the named one folds in again
    await setHideNotifContent(true);
    expect(shade.up, [sharedNotifId]);
  });

  test('previews off, a decoy open: nothing, shared or not', () async {
    final shade = _start(hide: true);
    FlutterSecureStorage.setMockInitialValues({
      'halo.lock.state': '{"q":true}',
    });
    expect(await _ring('bob', 'hi'), isNull);
    expect(shade.shown, isEmpty);
  });

  test('a shared ring keeps no ring row', () async {
    _start(hide: true);
    final rows = _Rows();
    await const AppIo().notify(
      title: 'Bob',
      body: 'hi',
      payload: 'bob',
      on: rows,
      msgUid: 'a',
    );
    expect(rows.rings, isEmpty);
  });

  test(
    'the shared one goes with the last burn, when all of it is timed',
    () async {
      final shade = _start(hide: true);
      final now = DateTime.now().millisecondsSinceEpoch;
      await _ring('bob', 'a', uid: 'a', burnAt: now + 30000);
      expect(shade.shown.last.d.timeoutAfter, inInclusiveRange(28000, 30000));
      await _ring('amy', 'b', title: 'Amy', uid: 'b', burnAt: now + 60000);
      expect(shade.shown.last.d.timeoutAfter, inInclusiveRange(58000, 60000));
      // an earlier burn does not shorten it
      await _ring('cy', 'c', title: 'Cy', uid: 'c', burnAt: now + 10000);
      expect(shade.shown.last.d.timeoutAfter, inInclusiveRange(58000, 60000));
      // one untimed: it stays
      await _ring('bob', 'd', uid: 'd');
      expect(shade.shown.last.d.timeoutAfter, isNull);
      await _ring('amy', 'e', title: 'Amy', uid: 'e', burnAt: now + 90000);
      expect(shade.shown.last.d.timeoutAfter, isNull);
    },
  );

  test('a timed fold folded in keeps its burn, an untimed one none', () async {
    final shade = _start();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _ring('bob', 'a', uid: 'a', burnAt: now + 30000);
    await setHideNotifContent(true);
    expect(shade.shown.last.d.timeoutAfter, inInclusiveRange(28000, 30000));
    await setHideNotifContent(false);
    await _ring('amy', 'b', title: 'Amy', uid: 'b');
    await setHideNotifContent(true);
    expect(shade.shown.last.d.timeoutAfter, isNull);
  });
}
