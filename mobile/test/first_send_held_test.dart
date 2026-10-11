// SPDX-License-Identifier: GPL-3.0-or-later
// a first message holds on its proof of work before it is sealed. a chat
// left while it holds still sends it, and a request's two slots are taken
// the moment a send starts, so a wave and a text side by side cannot pass
// the cap. the chat's own screen, with real signal over rows kept in maps
// and a relay that answers when told
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart' show grindPow, powBits;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'amber-slow-river';

// each nonce waits to be let through, so a send holds where it grinds
class _HeldDb extends SayHiDb {
  _HeldDb(super.mem);
  final held = <Completer<void>>[];

  @override
  Future<void> setPowNonce(String msgUid, int nonce) async {
    final c = Completer<void>();
    held.add(c);
    await c.future;
    await super.setPowNonce(msgUid, nonce);
  }
}

void main() {
  late MemDb mem;
  late _HeldDb db;
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
    relay = SayHiRelay();
    useEngineForTest(relay);
    grindPowForTest = (text) => grindPow(text, powBits);
    docs = Directory.systemTemp.createTempSync('first_send_held');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    // added, and nothing between us yet: a request on our side
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 0,
    });
    db = _HeldDb(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    grindPowForTest = null;
    StickerLibrary.use(null);
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

  Future<void> type(WidgetTester t, String words) async {
    await t.enterText(find.byType(TextField).last, words);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
  }

  testWidgets('left while its proof of work holds, a first message still '
      'goes, and nothing throws', (t) async {
    await open(t);
    await type(t, 'hello from the cafe');
    expect(db.held, hasLength(1));
    expect(relay.ciphers, isEmpty);
    await devClose(t);
    db.held.single.complete();
    await settle(t);
    expect(t.takeException(), isNull);
    expect(relay.ciphers, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
  });

  testWidgets('a wave and a text side by side take both of a request\'s '
      'slots at once, so a third cannot pass', (t) async {
    await open(t);
    await t.tap(find.text(l10n.chatWave));
    await settle(t);
    expect(db.held, hasLength(1));
    await type(t, 'it is me, from the cafe');
    expect(db.held, hasLength(2));
    // the text goes first, the wave still holds
    db.held[1].complete();
    await settle(t);
    expect(relay.ciphers, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    // both slots are spent: the composer is gone, nothing more goes
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.text(l10n.chatWaitingForThemTo), findsOneWidget);
    db.held.first.complete();
    await settle(t);
    expect(relay.ciphers, hasLength(2));
    relay.sends.last.complete('ok');
    await settle(t);
    expect(
      mem.rows('messages').where((r) => r['direction'] == 'out'),
      hasLength(2),
    );
    await devClose(t);
  });
}
