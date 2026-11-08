// SPDX-License-Identifier: GPL-3.0-or-later
// a test app for a phone, never shipped: opens the bundled libsignal shim,
// checks its abi and the sources it was built from, runs a pqxdh first
// contact and a few rounds of the pq ratchet between two identities held in
// memory, and prints the result.
//   HALO_TEST_ID=1 flutter build apk --debug -t tool/shim_selftest.dart
// then read `adb logcat -s flutter` for the line starting "shim self-test"
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';

String runShimSelfTest(KryfoSignal s) {
  final open = Stopwatch()..start();
  final now = DateTime.now().millisecondsSinceEpoch;
  final alice = s.identityGenerate();
  final bob = s.identityGenerate();
  final pk = s.preKey(1);
  final spk = s.signedPreKey(bob, 2, now);
  final kyber = s.kyberPreKey(bob, 3, now);
  final bundle = s.bundleBuild(
    registrationId: 22,
    preKeyId: pk.id,
    preKey: pk.public,
    signedPreKeyId: spk.id,
    signedPreKey: spk.public,
    signedPreKeySignature: spk.signature,
    kyberPreKeyId: kyber.id,
    kyberPreKey: kyber.public,
    kyberPreKeySignature: kyber.signature,
    identityKey: bob.public,
  );
  var (aliceRec, _) = s.sessionFromBundle(alice, 11, null, bundle, now);
  final first = s.encrypt(alice, 11, aliceRec, utf8.encode('first'), now);
  if (first.type != kLsPreKey) throw StateError('opener type ${first.type}');
  aliceRec = first.record;
  final opened = s.decryptPreKey(
    bob,
    22,
    null,
    first.message,
    preKey: pk.record,
    signedPreKey: spk.record,
    kyberPreKey: kyber.record,
  );
  if (utf8.decode(opened.plaintext) != 'first') throw StateError('opener');
  var bobRec = opened.record;
  final pqxdh = open.elapsedMilliseconds;

  final rounds = Stopwatch()..start();
  const n = 10;
  for (var i = 0; i < n; i++) {
    final back = s.encrypt(bob, 22, bobRec, utf8.encode('b$i'), now + i);
    bobRec = back.record;
    final a = s.decryptSignal(alice, 11, aliceRec, back.message);
    if (utf8.decode(a.plaintext) != 'b$i') throw StateError('round $i to a');
    aliceRec = a.record;
    final there = s.encrypt(alice, 11, aliceRec, utf8.encode('a$i'), now + i);
    aliceRec = there.record;
    final b = s.decryptSignal(bob, 22, bobRec, there.message);
    if (utf8.decode(b.plaintext) != 'a$i') throw StateError('round $i to b');
    bobRec = b.record;
  }
  final info = s.sessionInfo(aliceRec);
  if (info.version != 4 || !info.pq) {
    throw StateError('session version ${info.version}, pq ${info.pq}');
  }
  // the library opened only if it names these, so this line says so
  final built = s.buildInfo();
  lsCheckBuild(built);
  return 'shim self-test ok: abi $kLsAbi, version ${info.version}, pq ratchet '
      'on, pqxdh with keys $pqxdh ms, $n rounds both ways '
      '${rounds.elapsedMilliseconds} ms, built from ${built.libsignal} and '
      '${built.spqr}';
}

void main() {
  String line;
  try {
    final open = Stopwatch()..start();
    final s = KryfoSignal.shared;
    final t = open.elapsedMilliseconds;
    line = '${runShimSelfTest(s)}, open $t ms';
  } catch (e) {
    line = 'shim self-test failed: $e';
  }
  // the one line the test reads from logcat
  // ignore: avoid_print
  print(line);
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(line, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    ),
  );
}
