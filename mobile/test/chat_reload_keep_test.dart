// SPDX-License-Identifier: GPL-3.0-or-later
// a receipt, a reaction or an edit reloads the open chat. someone reading
// back stays where they are, with the pages they scrolled in still there.
// a new message from them leaves the place too, and the jump button counts
// only what came in, never the pages scrolled in.
// the chat's own screen over rows kept in maps
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/dates.dart' show hourMinute;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/notifications.dart' show showMessageNotification;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/chat_parts.dart' show JumpDownButton;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-long-thread';
const _rows = 400;
// a one-pixel png
const _dot =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class _Db extends DevTestDb {
  _Db(super.mem);

  // pages fetched above the newest one
  int olderPages = 0;

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  Map<String, Object?>? _row(String uid) {
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == uid) return r;
    }
    return null;
  }

  List<Map<String, Object?>> _thread(String peer) => [
    for (final r in mem.rows('messages'))
      if (r['peer_id'] == peer && r['group_id'] == null)
        {...r, 'rowid': r['id']},
  ];

  bool _flag(String id, String col) => _contact(id)?[col] == 1;

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _contact(haloId);
  @override
  Future<bool> isAccepted(String haloId) async => _flag(haloId, 'accepted');
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _flag(peerId, 'back_paired');
  @override
  Future<bool> isBlocked(String haloId) async => _flag(haloId, 'blocked');
  @override
  Future<bool> isMuted(String haloId) async => _flag(haloId, 'muted');
  @override
  Future<bool> isVerified(String haloId) async => _flag(haloId, 'verified');
  @override
  Future<bool> keyChanged(String haloId) async => false;
  @override
  Future<String?> getAtmosphere(String peerId) async => null;
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      _thread(peerId).where((r) => r['direction'] == 'in').length;
  @override
  Future<int> countMessagesTo(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'out').length;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {}
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int limit = 60,
  }) async {
    if (beforeRowid != null) olderPages++;
    final all = [
      for (final r in _thread(peerId))
        if (beforeRowid == null || (r['id'] as int) < beforeRowid) r,
    ];
    return all.sublist(all.length > limit ? all.length - limit : 0);
  }

  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [
    for (final r in _thread(peerId))
      if ((r['id'] as int) > afterRowid) r,
  ];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<bool> messageExists(String msgUid) async => _row(msgUid) != null;
  @override
  Future<void> setPowNonce(String msgUid, int nonce) async {}
  @override
  Future<int?> powNonceOf(String msgUid) async => null;
  @override
  Future<void> markSent(String msgUid) => mem.update(
    'messages',
    {'sent': 1},
    where: 'msg_uid = ?',
    whereArgs: [msgUid],
  );
  @override
  Future<bool> isSent(String msgUid) async => _row(msgUid)?['sent'] == 1;
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: _row(msgUid)?['sent'] == 1, delivered: false);

  @override
  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    int? sentAt,
  }) async {
    await mem.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'sent': sent,
    });
  }
}

// android's shade, noting what is up
class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  final up = <int>[];
  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async => up.add(id);
  @override
  Future<void> cancel({required int id, String? tag}) async => up.remove(id);
}

// nothing is sent here
class _Engine implements HaloEngine {
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(String peerXPubHex) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

void main() {
  late MemDb mem;
  late _Db db;
  late Directory docs;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = Curve.generateKeyPair();
    final amber = SignalSession();
    await amber.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await processPeerBundle(_peer, await makePreKeyBundleB64(amber));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    docs = Directory.systemTemp.createTempSync('reload_keep');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
    });
    final start = DateTime.now().millisecondsSinceEpoch - _rows * 60000;
    for (var i = 0; i < _rows; i++) {
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': i.isEven ? 'in' : 'out',
        'plaintext': 'note $i',
        'sent_at': start + i * 60000,
        'msg_uid': 'uid$i',
        'sent': 1,
      });
    }
    db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  // the thread itself: the one list that grows upward
  ScrollPosition thread(WidgetTester t) => t
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((s) => s.axisDirection == AxisDirection.up)
      .position;

  List<int> shown() => [
    for (var i = 0; i < _rows; i++)
      if (find
          .text('note $i', findRichText: true)
          .hitTestable()
          .evaluate()
          .isNotEmpty)
        i,
  ];

  Widget chat({String? jumpTo}) => ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub: 'ab' * 32,
    avatarSeed: _peer,
    jumpToUid: jumpTo,
  );

  // what the jump button says came in
  int badge(WidgetTester t) =>
      t.widget<JumpDownButton>(find.byType(JumpDownButton)).count;
  bool button(WidgetTester t) =>
      t.widget<JumpDownButton>(find.byType(JumpDownButton)).shown;

  // a message from them lands, as the receiver writes it
  Future<void> arrive(WidgetTester t, int n) async {
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'new $n',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': 'new$n',
      'sent': 1,
    });
    appState.chatChanged(_peer);
    await settle(t);
  }

  bool seen(String text) =>
      find.text(text, findRichText: true).hitTestable().evaluate().isNotEmpty;

  testWidgets('back in front, it shows what came while it was away and '
      'takes down what rang', (t) async {
    lockState.openForTest();
    final shade = _Shade();
    FlutterLocalNotificationsPlatform.instance = shade;
    await devOpen(t, chat());
    await settle(t);
    // the chat is up to date with every note so far
    await arrive(t, 1);
    expect(seen('new 1'), isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // written, and rung, with no note to the open chat
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'while away',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': 'away1',
      'sent': 1,
    });
    await t.runAsync(
      () => showMessageNotification(
        title: _peer,
        body: 'while away',
        payload: _peer,
        msgUid: 'away1',
      ),
    );
    expect(shade.up, hasLength(1));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(seen('while away'), isTrue);
    expect(shade.up, isEmpty);
    await devClose(t);
  });

  testWidgets('with the keyboard up, the message menu opens once it has '
      'gone, above where it was', (t) async {
    lockState.openForTest();
    await devOpen(t, chat());
    await settle(t);
    await t.tap(find.byType(TextField));
    await t.pump();
    // the keyboard: up while the composer has focus
    t.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(t.view.resetViewInsets);
    void follow() {
      if (FocusManager.instance.primaryFocus?.context?.widget
          is! EditableText) {
        t.view.resetViewInsets();
      }
    }

    FocusManager.instance.addListener(follow);
    addTearDown(() => FocusManager.instance.removeListener(follow));
    await t.pump();
    await t.longPress(find.text('note 399', findRichText: true));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final edit = find.text(l10n.commonEdit);
    expect(edit, findsOneWidget);
    // the menu sits wholly above whatever keyboard is up by then
    final keyTop =
        (t.view.physicalSize.height - t.view.viewInsets.bottom) /
        t.view.devicePixelRatio;
    expect(t.getRect(edit).bottom, lessThanOrEqualTo(keyTop));
    expect(t.view.viewInsets.bottom, 0);
    await t.tapAt(const Offset(5, 5));
    await settle(t);
    await devClose(t);
  });

  testWidgets('a photo and a file that came in say when, and the photo '
      'says what it is', (t) async {
    final sem = t.ensureSemantics();
    final png = File('${docs.path}/in_photo.png')
      ..writeAsBytesSync(base64Decode(_dot));
    final doc = File('${docs.path}/notes.pdf')..writeAsBytesSync([1, 2, 3]);
    // hours from the thread's own minutes, so no other row shares them
    final at = DateTime.now().millisecondsSinceEpoch + 3 * 3600000;
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': '',
      'sent_at': at - 120000,
      'msg_uid': 'photo1',
      'media_path': png.path,
      'sent': 1,
    });
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': '',
      'sent_at': at - 60000,
      'msg_uid': 'file1',
      'file_path': doc.path,
      'file_name': 'notes.pdf',
      'sent': 1,
    });
    await devOpen(t, chat());
    await settle(t);
    String hm(int ms) => hourMinute(DateTime.fromMillisecondsSinceEpoch(ms));
    expect(find.text(hm(at - 120000)), findsOneWidget);
    expect(find.text(hm(at - 60000)), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(l10n.appPhoto)), findsOneWidget);
    await devClose(t);
    sem.dispose();
  });

  testWidgets('a reload with nothing new keeps the place and the pages', (
    t,
  ) async {
    await devOpen(t, chat());
    await settle(t);
    expect(shown(), contains(_rows - 1));
    // up to the top of the first page: the next one comes in
    for (var i = 0; i < 2; i++) {
      thread(t).jumpTo(thread(t).maxScrollExtent);
      await settle(t);
    }
    final reading = shown();
    // reading what only the second page brought
    expect(reading, isNotEmpty);
    expect(reading.first, lessThan(_rows - 60));
    final at = thread(t).pixels;
    expect(at, greaterThan(0));
    final paged = db.olderPages;
    expect(paged, greaterThan(0));

    // a receipt for one of ours lands: the rev moves, no row is new
    await mem.update(
      'messages',
      {'delivered': 1},
      where: 'msg_uid = ?',
      whereArgs: ['uid${_rows - 1}'],
    );
    appState.chatChanged(_peer);
    await settle(t);
    expect(thread(t).pixels, at);
    expect(shown(), reading);
    // the page scrolled in was kept, not dropped and fetched again
    expect(db.olderPages, paged);
    await devClose(t);
  });

  testWidgets('a reload at the newest message stays at the newest', (t) async {
    await devOpen(t, chat());
    await settle(t);
    expect(thread(t).pixels, 0);
    appState.chatChanged(_peer);
    await settle(t);
    expect(thread(t).pixels, 0);
    expect(shown(), contains(_rows - 1));
    await devClose(t);
  });

  testWidgets('a new message while reading back leaves the place, and the '
      'jump button counts it', (t) async {
    await devOpen(t, chat());
    await settle(t);
    for (var i = 0; i < 2; i++) {
      thread(t).jumpTo(thread(t).maxScrollExtent);
      await settle(t);
    }
    expect(db.olderPages, greaterThan(0));
    final reading = shown();
    expect(reading.first, lessThan(_rows - 60));
    // the pages scrolled in are not new
    expect(badge(t), 0);

    await arrive(t, 1);
    await arrive(t, 2);
    expect(thread(t).pixels, greaterThan(240));
    expect(shown(), reading);
    expect(seen('new 2'), isFalse);
    expect(badge(t), 2);
    expect(button(t), isTrue);

    // the button takes them down, and the count goes
    await t.tap(find.byType(JumpDownButton));
    await settle(t, 12);
    expect(thread(t).pixels, 0);
    expect(seen('new 2'), isTrue);
    expect(badge(t), 0);
    await devClose(t);
  });

  testWidgets('a new message at the newest is followed', (t) async {
    await devOpen(t, chat());
    await settle(t);
    expect(thread(t).pixels, 0);
    await arrive(t, 1);
    expect(thread(t).pixels, 0);
    expect(seen('new 1'), isTrue);
    expect(badge(t), 0);
    await devClose(t);
  });

  testWidgets('a new message just above the newest, where no jump button '
      'shows, is followed', (t) async {
    await devOpen(t, chat());
    await settle(t);
    thread(t).jumpTo(150);
    await settle(t);
    expect(button(t), isFalse);
    for (var n = 1; n <= 3; n++) {
      await arrive(t, n);
      expect(thread(t).pixels, 0);
      expect(seen('new $n'), isTrue);
      expect(button(t), isFalse);
      expect(badge(t), 0);
    }
    await devClose(t);
  });

  testWidgets('a new message in the middle of a fling leaves the rows where '
      'they were going', (t) async {
    await devOpen(t, chat());
    await settle(t);
    // the same fling twice, the second with a message landing on the way
    Future<(List<int>, double)> fling({bool withNew = false}) async {
      thread(t).jumpTo(1500);
      await settle(t);
      (thread(t) as ScrollPositionWithSingleContext).goBallistic(1200);
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));
      expect(thread(t).isScrollingNotifier.value, isTrue);
      if (withNew) {
        await mem.insert('messages', {
          'peer_id': _peer,
          'direction': 'in',
          'plaintext': 'new 1',
          'sent_at': DateTime.now().millisecondsSinceEpoch,
          'msg_uid': 'new1',
          'sent': 1,
        });
        appState.chatChanged(_peer);
        // the row lands while the fling runs
        for (var i = 0; i < 6; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(thread(t).isScrollingNotifier.value, isTrue);
      }
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(thread(t).isScrollingNotifier.value, isFalse);
      final rows = shown();
      final at = find.text('note ${rows.first}', findRichText: true).first;
      return (rows, t.getTopLeft(at).dy);
    }

    final (going, top) = await fling();
    final (went, topAfter) = await fling(withNew: true);
    expect(went, going);
    expect(topAfter, moreOrLessEquals(top, epsilon: 1));
    expect(badge(t), 1);
    await devClose(t);
  });

  testWidgets('opened at an old message, the jump button counts nothing yet', (
    t,
  ) async {
    await devOpen(t, chat(jumpTo: 'uid40'));
    await settle(t, 12);
    expect(thread(t).pixels, greaterThan(240));
    expect(badge(t), 0);
    await arrive(t, 1);
    expect(badge(t), 1);
    await devClose(t);
  });
}
