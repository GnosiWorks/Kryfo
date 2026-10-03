// SPDX-License-Identifier: GPL-3.0-or-later
// ten texts a contact sent while this phone was off come back from a
// catch-up in the relays' order. each is kept once, in the order it was
// sent, and each sends its own receipt, so the sender sees every one
// delivered. real signal messages, the databases and the engine stand-ins
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _v = 'plain-friend-here';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<SignalSession> _phone() async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return ss;
}

// the sender's session to the receiver, from the receiver's invite keys
Future<void> _start(SignalSession from, SignalSession to) async {
  final spk = await to.signedPreKeyStore.loadSignedPreKey(1);
  final pk = await to.preKeyStore.loadPreKey(invitePreKeyId);
  await SessionBuilder(
    from.sessionStore,
    from.preKeyStore,
    from.signedPreKeyStore,
    from.identityStore,
    const SignalProtocolAddress('me', 1),
  ).processPreKeyBundle(
    PreKeyBundle(
      to.registrationId,
      1,
      pk.id,
      pk.getKeyPair().publicKey,
      spk.id,
      spk.getKeyPair().publicKey,
      spk.signature,
      to.identityKeyPair.getPublicKey(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('catchup_burst');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => docs.deleteSync(recursive: true));

  test('a burst sent to a stopped phone lands whole, in order, '
      'each with its receipt', () async {
    final live = ArrivalRows(HaloContainer.everyday)
      ..person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    final io = ArrivalIo()..sessions = [_v];
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));

    final sender = await _phone();
    await _start(sender, await _phone());
    final batch = <({String peer, String cipher})>[];
    for (var i = 1; i <= 10; i++) {
      final cipher = await sender.encryptTo('me', 'wire $i');
      io.opens[cipher] = (
        _v,
        await wrapMessage(
          'Cu $i',
          msgUid: 'u$i',
          sender: SenderInfo(
            haloId: _v,
            edPub: 'ed-$_v',
            onion: 'o-$_v',
            xPub: 'x-$_v',
          ),
        ),
      );
      batch.add((peer: 'x-$_v', cipher: cipher));
    }
    batch.shuffle(Random(5));
    await app.receiveRelay(batch);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final kept = [
      for (final m in live.msgs)
        if (m['direction'] == 'in') m['msg_uid'],
    ];
    expect(kept, [for (var i = 1; i <= 10; i++) 'u$i']);
    for (var i = 1; i <= 10; i++) {
      expect(io.ticksFor('u$i'), ['relay x-$_v'], reason: 'receipt for u$i');
    }
  });
}
