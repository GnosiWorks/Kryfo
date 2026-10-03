// SPDX-License-Identifier: GPL-3.0-or-later
// their timed message starts counting when it is shown: the chat on screen,
// the app in front, no lock or decoy over it, and the bubble itself in view.
// until then it shows its whole window, and the flame kindles as the count
// starts. the chat's own screen over rows kept in maps
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/burn_fade.dart';
import 'package:kryfo/widgets/pins.dart' show PinHeaderButton;
import 'package:kryfo/widgets/row_anchor.dart' show RowAnchor;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-long-thread';
const _timed = 'timed01';

// the real clock-starting query over the same rows
class _Real extends HaloDb {
  _Real(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

class _Db extends DevTestDb {
  _Db(super.mem, [super.container]);

  // every clock this screen asked to start
  final asked = <String>[];
  // the rows went from the database before they were read
  bool forget = false;

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
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
  Future<Map<String, int>> lightReadBurns(List<String> msgUids) async {
    asked.addAll(msgUids);
    if (forget) return const {};
    return _Real(mem).lightReadBurns(msgUids);
  }

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
  }) async => [
    for (final r in _thread(peerId!))
      if (r['pinned'] == 1) r,
  ];
  @override
  Future<bool> messageExists(String msgUid) async =>
      _thread(_peer).any((r) => r['msg_uid'] == msgUid);
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: true, delivered: false);
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    docs = Directory.systemTemp.createTempSync('read_burn');
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
    lockState.openForTest();
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  // [before] plain notes, then their timed one, then [after] more
  Future<void> thread({
    int before = 0,
    int after = 0,
    bool timed = true,
    HaloContainer container = HaloContainer.everyday,
  }) async {
    final start = DateTime.now().millisecondsSinceEpoch - 3600000;
    var n = 0;
    Future<void> note(String uid, String text, {int? burnSecs}) =>
        mem.insert('messages', {
          'peer_id': _peer,
          'direction': burnSecs != null || n.isEven ? 'in' : 'out',
          'plaintext': text,
          'sent_at': start + (n++) * 60000,
          'msg_uid': uid,
          'burn_secs': burnSecs,
          'sent': 1,
        });
    for (var i = 0; i < before; i++) {
      await note('b$i', 'before $i');
    }
    if (timed) await note(_timed, 'gone soon', burnSecs: 300);
    for (var i = 0; i < after; i++) {
      await note('a$i', 'after $i');
    }
    db = _Db(mem, container);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  }

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Widget chat() => ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub: 'ab' * 32,
    avatarSeed: _peer,
  );

  int? burnAt() {
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == _timed) return r['burn_at'] as int?;
    }
    return null;
  }

  Finder flame() => find.byType(BurnFlame);
  bool waits(WidgetTester t) => t.widget<BurnFlame>(flame()).waiting;

  // the thread itself: the one list that grows upward
  ScrollableState list(WidgetTester t) => t
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((s) => s.axisDirection == AxisDirection.up);

  testWidgets('shown on screen, it starts counting and the clock is written '
      'at once', (t) async {
    await thread();
    final before = DateTime.now().millisecondsSinceEpoch;
    await devOpen(t, chat());
    await settle(t);
    final at = burnAt();
    expect(at, isNotNull);
    expect(
      at,
      inInclusiveRange(
        before + 300000,
        DateTime.now().millisecondsSinceEpoch + 300000,
      ),
    );
    expect(waits(t), isFalse);
    await devClose(t);
  });

  testWidgets('under the lock it waits, whole, and starts once the lock '
      'lifts, with no jump', (t) async {
    await thread();
    lockState.openForTest(enabled: true);
    lockState.lock();
    await devOpen(t, chat());
    await settle(t);
    expect(burnAt(), isNull);
    expect(db.asked, isEmpty);
    // the whole window, the flame low
    expect(find.text('5m 00s'), findsOneWidget);
    expect(waits(t), isTrue);
    final box = t.getRect(find.text('gone soon', findRichText: true));

    lockState.openForTest(enabled: true);
    // and its listeners hear of it
    lockState.inDecoy = false;
    await settle(t);
    expect(burnAt(), isNotNull);
    expect(waits(t), isFalse);
    expect(
      find.text('5m 00s').evaluate().length +
          find.text('4m 59s').evaluate().length,
      1,
    );
    // the count started in place: the bubble did not move
    expect(t.getRect(find.text('gone soon', findRichText: true)), box);
    await devClose(t);
  });

  // a day after it came its clock starts, read or not: the open chat
  // counts it down from then, as the sweep writes it, and a read after
  // gives it no more time
  testWidgets('a day after it came it counts from then, unread, and a read '
      'keeps that clock', (t) async {
    await thread();
    final came = DateTime.now().millisecondsSinceEpoch - 86400000 - 10000;
    await mem.update(
      'messages',
      {'sent_at': came},
      where: 'msg_uid = ?',
      whereArgs: [_timed],
    );
    lockState.openForTest(enabled: true);
    lockState.lock();
    await devOpen(t, chat());
    // the first frame that shows it shows the clock it started then
    expect(find.text('gone soon', findRichText: true), findsOneWidget);
    expect(find.text('5m 00s'), findsNothing);
    await settle(t);
    expect(burnAt(), isNull);
    expect(find.text('5m 00s'), findsNothing);
    expect(
      find.text('4m 50s').evaluate().length +
          find.text('4m 49s').evaluate().length,
      1,
    );
    expect(waits(t), isFalse);

    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await settle(t);
    expect(burnAt(), came + 86400000 + 300000);
    await devClose(t);
  });

  // the shade pulled down over the chat: the app is not in front, so what
  // lands under it has not been read
  testWidgets('it lands while the app is not in front: it waits until the '
      'app is back', (t) async {
    await thread(before: 2, timed: false);
    await devOpen(t, chat());
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'gone soon',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': _timed,
      'burn_secs': 300,
      'sent': 1,
    });
    appState.chatChanged(_peer);
    await settle(t);
    expect(find.text('gone soon', findRichText: true), findsOneWidget);
    expect(burnAt(), isNull);
    expect(db.asked, isEmpty);

    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(burnAt(), isNotNull);
    await devClose(t);
  });

  testWidgets('above the screen it waits, built or not, until it is '
      'scrolled to', (t) async {
    await thread(after: 40);
    await devOpen(t, chat());
    await settle(t);
    final box = list(t).context.findRenderObject()! as RenderBox;
    final view = box.localToGlobal(Offset.zero) & box.size;
    final text = find.text('gone soon', findRichText: true);
    var builtOff = 0;
    // up a little at a time, the row coming in from above
    for (var i = 0; i < 400; i++) {
      final shown =
          text.evaluate().isNotEmpty &&
          t.getRect(text).bottom > view.top &&
          t.getRect(text).top < view.bottom;
      if (shown && t.getRect(text).top >= view.top) break;
      if (!shown) {
        if (text.evaluate().isNotEmpty) builtOff++;
        expect(burnAt(), isNull, reason: 'step $i');
      }
      final p = list(t).position;
      p.jumpTo((p.pixels + 12).clamp(0, p.maxScrollExtent).toDouble());
      await t.pump();
    }
    // the list builds a little past the edge: that is not on screen
    expect(builtOff, greaterThan(0));
    await settle(t);
    expect(burnAt(), isNotNull);
    await devClose(t);
  });

  // the newest row the list draws: the bottom of the screen
  Future<void> addTimed(String uid, String text, {int? sentAt}) =>
      mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': text,
        'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
        'msg_uid': uid,
        'burn_secs': 300,
        'sent': 1,
      });

  int? burnOf(String uid) {
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == uid) return r['burn_at'] as int?;
    }
    return null;
  }

  Rect viewOf(WidgetTester t) {
    final box = list(t).context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // up a little at a time until the timed bubble just shows at the top
  Future<Rect> peek(WidgetTester t) async {
    final view = viewOf(t);
    final bubble = find.ancestor(
      of: find.text('gone soon', findRichText: true),
      matching: find.byType(LeaveFold),
    );
    for (var i = 0; i < 800; i++) {
      if (bubble.evaluate().isNotEmpty &&
          t.getRect(bubble.first).bottom > view.top + 4) {
        break;
      }
      final p = list(t).position;
      p.jumpTo((p.pixels + 4).clamp(0, p.maxScrollExtent).toDouble());
      await t.pump();
    }
    return t.getRect(bubble.first);
  }

  testWidgets('a sheet, a dialog or a see-through page over the chat: what '
      'lands under it waits until it goes', (t) async {
    await thread(before: 2, timed: false);
    await devOpen(t, chat());
    await settle(t);
    final ctx = t.element(find.byType(ChatScreen));
    final covers = <String, void Function()>{
      'dialog': () => showDialog<void>(
        context: ctx,
        builder: (_) => const Center(child: Text('over')),
      ),
      'sheet': () => showModalBottomSheet<void>(
        context: ctx,
        builder: (_) => const SizedBox(height: 80, child: Text('over')),
      ),
      // as the photo and the video viewer open
      'page': () => Navigator.of(ctx).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => const Center(child: Text('over')),
        ),
      ),
    };
    for (final MapEntry(key: name, value: cover) in covers.entries) {
      cover();
      await settle(t);
      final uid = 'under-$name';
      await addTimed(uid, 'gone soon');
      appState.chatChanged(_peer);
      await settle(t, 10);
      expect(find.text('over'), findsOneWidget, reason: name);
      expect(burnOf(uid), isNull, reason: name);
      expect(db.asked, isEmpty, reason: name);
      Navigator.of(ctx).pop();
      await settle(t);
      expect(burnOf(uid), isNotNull, reason: name);
      db.asked.clear();
    }
    await devClose(t);
  });

  testWidgets('held for its menu, it is read, however little of it shows', (
    t,
  ) async {
    await thread(after: 40);
    await devOpen(t, chat());
    await settle(t);
    final view = viewOf(t);
    final at = await peek(t);
    await settle(t);
    // less than half of it in view: not read by being seen
    expect(burnAt(), isNull);
    await t.longPressAt(Offset(at.left + 24, (view.top + at.bottom) / 2));
    await settle(t);
    expect(burnAt(), isNotNull);
    await devClose(t);
  });

  testWidgets('swiped to answer, it is read, however little of it shows', (
    t,
  ) async {
    await thread(after: 40);
    await devOpen(t, chat());
    await settle(t);
    final view = viewOf(t);
    final at = await peek(t);
    await settle(t);
    expect(burnAt(), isNull);
    await t.dragFrom(
      Offset(at.left + 24, (view.top + at.bottom) / 2),
      const Offset(140, 0),
    );
    await settle(t);
    expect(burnAt(), isNotNull);
    await devClose(t);
  });

  // the date and the new messages line above it are not the message
  testWidgets('its day line in view and the bubble mostly not: it waits', (
    t,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 30; i++) {
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'out',
        'plaintext': 'days ago $i',
        'sent_at': now - 3 * 86400000 + i * 60000,
        'msg_uid': 'old$i',
        'sent': 1,
      });
    }
    await addTimed(_timed, 'gone soon', sentAt: now - 3600000);
    for (var i = 0; i < 40; i++) {
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'out',
        'plaintext': 'after $i',
        'sent_at': now - 3000000 + i * 60000,
        'msg_uid': 'a$i',
        'sent': 1,
      });
    }
    db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    await devOpen(t, chat());
    await settle(t);
    // nothing is read while the app is not in front
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final text = find.text('gone soon', findRichText: true);
    final row = find.byWidgetPredicate((w) => w is RowAnchor && w.id == _timed);
    for (var i = 0; i < 600 && text.evaluate().isEmpty; i++) {
      final p = list(t).position;
      p.jumpTo((p.pixels + 40).clamp(0, p.maxScrollExtent).toDouble());
      await t.pump();
    }
    await t.pump();
    final whole = t.getRect(row.first);
    final bubble = t.getRect(
      find.ancestor(of: text, matching: find.byType(LeaveFold)).first,
    );
    final above = bubble.top - whole.top;
    expect(above, greaterThan(16));
    // more than half the row on screen, less than half the bubble
    final shown = (whole.height / 2 + above + bubble.height / 2) / 2;
    final view = viewOf(t);
    final p = list(t).position;
    p.jumpTo(p.pixels + (view.bottom - shown) - whole.top);
    await t.pump();
    expect(view.bottom - t.getRect(row.first).top, closeTo(shown, 1));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(burnAt(), isNull);
    expect(db.asked, isEmpty);
    // half the bubble up: read
    p.jumpTo(p.pixels - bubble.height);
    await settle(t);
    expect(burnAt(), isNotNull);
    await devClose(t);
  });

  // gone, say unsent, before it was read: it shows what it showed, and is
  // not asked about again
  testWidgets('a row that comes back unlit keeps its whole window', (t) async {
    await thread();
    db.forget = true;
    await devOpen(t, chat());
    await settle(t, 30);
    expect(db.asked, [_timed]);
    expect(find.text('5m 00s'), findsOneWidget);
    expect(waits(t), isTrue);
    await devClose(t);
  });

  // as the unread count clears for all of it
  testWidgets('one read starts the ones above it too, and the screen counts '
      'them down without asking again', (t) async {
    await thread(after: 40);
    await addTimed('newest', 'read now');
    await devOpen(t, chat());
    await settle(t);
    expect(db.asked, ['newest']);
    expect(burnOf('newest'), isNotNull);
    expect(burnAt(), isNotNull);
    await peek(t);
    final p = list(t).position;
    p.jumpTo((p.pixels + 200).clamp(0, p.maxScrollExtent).toDouble());
    await settle(t);
    expect(find.text('gone soon', findRichText: true), findsOneWidget);
    expect(db.asked, ['newest']);
    await devClose(t);
  });

  // a pin shows what it pins: one not read yet shows in the thread alone
  testWidgets('a timed message not read yet is not in the pins until it is', (
    t,
  ) async {
    await thread(after: 40);
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == _timed || r['msg_uid'] == 'a1') {
        await mem.update(
          'messages',
          {'pinned': 1, 'pinned_at': 1},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
    }
    await devOpen(t, chat());
    await settle(t);
    int pins() => t.widget<PinHeaderButton>(find.byType(PinHeaderButton)).count;
    expect(burnAt(), isNull);
    expect(pins(), 1);
    await peek(t);
    final p = list(t).position;
    p.jumpTo((p.pixels + 200).clamp(0, p.maxScrollExtent).toDouble());
    await settle(t);
    expect(burnAt(), isNotNull);
    expect(pins(), 2);
    await devClose(t);
  });

  testWidgets('the chat list names it a timed message until it is read, '
      'then shows its words', (t) async {
    await thread(before: 2);
    String? line() =>
        appState.contacts.firstWhere((c) => c.haloId == _peer).preview;
    expect(line(), 'Timed message');
    await devOpen(t, chat());
    await settle(t);
    expect(burnAt(), isNotNull);
    // the list hears of it with no other change
    expect(line(), 'gone soon');
    await devClose(t);
  });

  testWidgets('a quote of it says only that it is a timed message until it '
      'is read', (t) async {
    await thread();
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'about that',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': 'reply01',
      'reply_to': _timed,
      'sent': 1,
    });
    lockState.openForTest(enabled: true);
    lockState.lock();
    await devOpen(t, chat());
    await settle(t);
    final words = find.text('gone soon', findRichText: true);
    final label = find.text('Timed message', findRichText: true);
    expect(burnAt(), isNull);
    // its own bubble, and the quote names it
    expect(words, findsOneWidget);
    expect(label, findsOneWidget);

    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    await settle(t);
    expect(burnAt(), isNotNull);
    expect(label, findsNothing);
    expect(words, findsNWidgets(2));
    await devClose(t);
  });

  testWidgets('a decoy never starts one', (t) async {
    await thread(container: HaloContainer.decoy);
    await devOpen(t, chat());
    await settle(t);
    expect(find.text('gone soon', findRichText: true), findsOneWidget);
    expect(burnAt(), isNull);
    expect(db.asked, isEmpty);
    await devClose(t);
  });
}
