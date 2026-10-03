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
  Future<Map<String, int>> lightReadBurns(List<String> msgUids) {
    asked.addAll(msgUids);
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
  Future<void> purgeExpiredBurns() async {}
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
  }) async => [];
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
