// SPDX-License-Identifier: GPL-3.0-or-later
// an accept's word that was tried as long as it is and never got through
// leaves a plain line in their chat, with a way to send it again. a tap on
// it sends the word and the line goes. someone blocked, and a decoy, show
// none. the chat's own screen, with real signal over rows kept in maps
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
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
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'calm-grey-heron';

// the ack's mark on the row, as the real database keeps it
class _Db extends SayHiDb {
  _Db(super.mem, [super.container]);

  Map<String, Object?> get _row =>
      mem.rows('contacts').firstWhere((r) => r['halo_id'] == _peer);
  bool get _open => _row['accepted'] == 1 && _row['blocked'] != 1;
  Future<void> _set(int v) => mem.update(
    'contacts',
    {'ack_owed': v},
    where: 'halo_id = ?',
    whereArgs: [_peer],
  );

  @override
  Future<bool> ackLost(String haloId) async => _open && _row['ack_owed'] == 2;
  @override
  Future<bool> retryAck(String haloId) async {
    if (!_open || _row['ack_owed'] != 2) return false;
    await _set(1);
    return true;
  }

  @override
  Future<bool> isAckOwed(String haloId) async => _open && _row['ack_owed'] == 1;
  @override
  Future<List<String>> ackOwed() async => [
    if (_open && _row['ack_owed'] == 1) _peer,
  ];
  @override
  Future<void> setAckOwed(String haloId, bool owed) async {
    if (!owed || _open) await _set(owed ? 1 : 0);
  }
}

void main() {
  late MemDb mem;
  late _Db db;
  late SayHiRelay relay;
  late Directory docs;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = Curve.generateKeyPair();
    final them = SignalSession();
    await them.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await processPeerBundle(_peer, await makePreKeyBundleB64(them));
  });

  Future<_Db> rows(HaloContainer c, {int blocked = 0}) async {
    final m = MemDb();
    await devChatTables(m, now: 1);
    // they asked, were accepted, and the word never got through
    await m.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': blocked,
      'ack_owed': 2,
    });
    await m.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'hello, may I write',
      'sent_at': 1,
    });
    return _Db(m, c);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    relay = SayHiRelay();
    useEngineForTest(relay);
    docs = Directory.systemTemp.createTempSync('ack_lost_line');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    db = await rows(HaloContainer.everyday);
    mem = db.mem;
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
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

  Future<void> open(WidgetTester t) async {
    await devOpen(
      t,
      ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'ab' * 32,
        avatarSeed: _peer,
      ),
    );
    await settle(t);
  }

  int? owed() {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == _peer) return r['ack_owed'] as int?;
    }
    return null;
  }

  testWidgets('the line shows once the word was let go, and its button '
      'sends it again', (t) async {
    await open(t);
    expect(find.text(l10n.chatTheyMayNotKnow), findsOneWidget);
    await t.tap(find.text(l10n.commonTryAgain));
    await settle(t);
    expect(find.text(l10n.chatTheyMayNotKnow), findsNothing);
    expect(relay.ciphers, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    expect(owed(), 0);
    expect(find.text(l10n.chatTheyMayNotKnow), findsNothing);
    await devClose(t);
  });

  testWidgets('reduced motion: no animation', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(t);
    expect(find.text(l10n.chatTheyMayNotKnow), findsOneWidget);
    expect(t.takeException(), isNull);
    await devClose(t);
  });

  testWidgets('someone blocked shows no line', (t) async {
    db = await rows(HaloContainer.everyday, blocked: 1);
    mem = db.mem;
    useDatabasesForTest(db, Session(db));
    await open(t);
    expect(find.text(l10n.chatTheyMayNotKnow), findsNothing);
    await devClose(t);
  });

  testWidgets('a decoy shows no line', (t) async {
    final decoy = await rows(HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    await open(t);
    expect(find.text(l10n.chatTheyMayNotKnow), findsNothing);
    await devClose(t);
  });
}
