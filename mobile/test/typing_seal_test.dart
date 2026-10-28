// SPDX-License-Identifier: GPL-3.0-or-later
// a typing frame is never the opener of a session: it is sealed only on
// one the other side has answered on, and a refused one spends no message
// key. the stores are the real ones over rows kept in maps
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/typing.dart';
import 'signal_kit.dart';

import 'mem_db.dart';

typedef _Phone = ({SignalSession ss, String name});

Future<_Phone> _phone(String name) async {
  final pair = testKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, name: name);
}

Future<void> _start(_Phone from, _Phone to) async {
  await from.ss.processBundle(
    to.name,
    lsBundleOf(from.ss.lib, await to.ss.makeBundleB64()),
  );
}

Future<String> _open(_Phone at, _Phone from, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final plain = await at.ss.open(from.name, wire[0], body);
  return utf8.decode(plain);
}

Future<List<int>?> _counter(_Phone p, String peer) =>
    p.ss.sessionStore.load(peer);

void main() {
  test('no session, nothing sealed', () async {
    final alice = await _phone('alice');
    expect(await alice.ss.settled('bob'), isFalse);
    expect(
      () => alice.ss.encryptTo(
        'bob',
        wrapTyping(writtenAt: 1),
        onlySettled: true,
      ),
      throwsA(isA<NotSettled>()),
    );
  });

  test('a session not answered yet seals nothing, and spends no key', () async {
    final alice = await _phone('alice');
    final bob = await _phone('bob');
    await _start(alice, bob);
    expect(await alice.ss.settled('bob'), isFalse);
    final before = await _counter(alice, 'bob');
    await expectLater(
      alice.ss.encryptTo('bob', wrapTyping(writtenAt: 1), onlySettled: true),
      throwsA(isA<NotSettled>()),
    );
    expect(await _counter(alice, 'bob'), before);
  });

  test(
    'once they answered, a typing frame is a plain message that opens',
    () async {
      final alice = await _phone('alice');
      final bob = await _phone('bob');
      await _start(alice, bob);
      await _open(bob, alice, await alice.ss.encryptTo('bob', 'hi'));
      await _open(alice, bob, await bob.ss.encryptTo('alice', 'hey'));
      expect(await alice.ss.settled('bob'), isTrue);
      final wire = await alice.ss.encryptTo(
        'bob',
        wrapTyping(writtenAt: 7),
        onlySettled: true,
      );
      expect(base64Decode(wire)[0], kLsWhisper);
      expect(await _open(bob, alice, wire), contains('"ty":1'));
    },
  );
}
