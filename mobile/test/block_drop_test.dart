// SPDX-License-Identifier: GPL-3.0-or-later
// what someone blocked sends while the block holds is dropped for good: a
// copy of it after the unblock, sent again or held by the relays, never
// lands in requests or the chat. what they send after the unblock does.
// the block takes what of theirs is in the shade with it. signal and the
// database are the app's stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

// a friend, and a stranger whose request was blocked
const _f = 'plain-friend-here';
const _s = 'guitar-present-kid';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// as signal: a cipher opens once
class _OnceIo extends ArrivalIo {
  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    final r = await super.decrypt(peer, cipher, flagKeyChange: flagKeyChange);
    if (r != null) opens.remove(cipher);
    return r;
  }
}

class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.everyday);

  @override
  Future<void> dropHeld(String peerId) async => heldRows.remove(peerId);

  @override
  Future<Set<String>> blockedIds() async => {
    for (final p in people.values)
      if (p['blocked'] == 1) p['halo_id'] as String,
  };
}

class _World {
  final live = _Rows();
  final io = _OnceIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_f, onion: 'o-$_f', xpub: 'x-$_f');
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.io.sessions = [_f, _s];
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  // one copy of the message [uid] on the wire: each send of it, the first
  // or a retry, is a cipher of its own
  Future<({String peer, String cipher})> copy(String from, String uid) async {
    final cipher = 'cipher-$uid-${_n++}';
    io.opens[cipher] = (
      from,
      await wrapMessage(
        'text $uid',
        msgUid: uid,
        sender: SenderInfo(
          haloId: from,
          edPub: 'ed-$from',
          onion: 'o-$from',
          xPub: 'x-$from',
        ),
      ),
    );
    return (peer: 'x-$from', cipher: cipher);
  }

  List<Object?> kept(String from) => [
    for (final m in live.msgs)
      if (m['peer_id'] == from && m['direction'] == 'in') m['msg_uid'],
  ];
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('block_drop');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => docs.deleteSync(recursive: true));

  for (final who in [_f, _s]) {
    final kind = who == _f ? 'a friend' : 'a stranger';
    test('$kind blocked: what they send then stays out after the unblock, '
        'whichever lane brings it again', () async {
      final w = await _World.make();
      await w.app.block(who);
      await w.app.receiveRelay([await w.copy(who, 'req3b')]);
      await w.app.receiveOnion([(await w.copy(who, 'req3c')).cipher]);
      expect(w.kept(who), isEmpty);
      expect(w.io.rang, isEmpty);
      expect(w.io.ticksFor('req3b'), isEmpty, reason: 'no tick while blocked');

      await w.app.unblock(who);
      // their phone sends each again, as a retry does: a new cipher, the
      // same message
      await w.app.receiveRelay([await w.copy(who, 'req3b')]);
      await w.app.receiveOnion([(await w.copy(who, 'req3c')).cipher]);
      await w.app.receiveRelay([await w.copy(who, 'req3c')]);
      expect(w.kept(who), isEmpty);
      expect(w.io.rang, isEmpty);

      // and what they write now comes in
      await w.app.receiveRelay([await w.copy(who, 'req4')]);
      expect(w.kept(who), ['req4']);
    });

    test('$kind blocked: what the relays held back while the block held '
        'stays out after the unblock', () async {
      final w = await _World.make();
      final before = DateTime.now().millisecondsSinceEpoch - 60000;
      await _tick();
      await w.app.block(who);
      await _tick();
      final during = DateTime.now().millisecondsSinceEpoch;
      await _tick();
      await w.app.unblock(who);
      await _tick();
      final after = DateTime.now().millisecondsSinceEpoch;
      // listening again, the relay hands over what it kept for them: none
      // of it was ever seen here
      await w.app.receiveRelay(
        [
          await w.copy(who, 'old'),
          await w.copy(who, 'req3b'),
          await w.copy(who, 'req4'),
        ],
        written: [before, during, after],
      );
      expect(w.kept(who), ['old', 'req4']);
      // and a copy of the one written during the block, sent again later
      await w.app.receiveOnion([(await w.copy(who, 'req3b')).cipher]);
      expect(w.kept(who), ['old', 'req4']);
    });
  }

  test('a block takes their notifications out of the shade', () async {
    final w = await _World.make();
    await w.app.receiveRelay([await w.copy(_s, 'req1')]);
    expect(w.io.rang, [_s]);
    await w.app.block(_s);
    expect(w.io.unrang, [_s]);
  });

  test(
    'a friend\'s message after a block and an unblock is theirs again',
    () async {
      final w = await _World.make();
      await w.app.receiveRelay([await w.copy(_f, 'u1')]);
      await w.app.block(_f);
      await w.app.unblock(_f);
      // a copy of one that came before the block is the one already here
      await w.app.receiveRelay([await w.copy(_f, 'u1')]);
      await w.app.receiveRelay([await w.copy(_f, 'u2')]);
      expect(w.kept(_f), ['u1', 'u2']);
    },
  );
}
