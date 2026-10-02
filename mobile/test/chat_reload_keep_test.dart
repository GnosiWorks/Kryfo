// SPDX-License-Identifier: GPL-3.0-or-later
// a receipt, a reaction or an edit reloads the open chat. someone reading
// back stays where they are, with the pages they scrolled in still there.
// the chat's own screen over rows kept in maps
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-long-thread';
const _rows = 400;

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

  Widget chat() => ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub: 'ab' * 32,
    avatarSeed: _peer,
  );

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
}
