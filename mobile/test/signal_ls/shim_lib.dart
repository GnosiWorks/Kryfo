// SPDX-License-Identifier: GPL-3.0-or-later
// the shim library for the host tests, and what they share. the library is
// built by native/kryfo_signal/build-host.sh; without it every test that
// needs it skips and says so
import 'dart:convert';
import 'dart:typed_data';

import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show unpad;

import '../mem_db.dart';
import '../signal_kit.dart' show testKeyPair;

final KryfoSignal? shim = KryfoSignal.forHostTests();

/// the skip reason for a test that needs the shim, false when it is there
final Object needsShim = shim == null
    ? 'libkryfo_signal not built: run native/kryfo_signal/build-host.sh, or '
          'point ${KryfoSignal.envVar} at the library'
    : false;

/// an x25519 pair as the app keeps one: 32 bytes each
({Uint8List pub, Uint8List priv}) xPair() {
  final kp = testKeyPair();
  return (pub: kp.xPub, priv: kp.privateKey.serialize());
}

/// one phone: its keys, its database, and its store once open
class Phone {
  Phone() : keys = xPair(), db = MemDb();
  Phone.of(this.keys, this.db);
  final ({Uint8List pub, Uint8List priv}) keys;
  final MemDb db;
  SignalSession? ls;

  Future<SignalSession> openLs() async {
    final s = SignalSession(shim);
    await s.bootstrap(database: db, xPubBytes: keys.pub, xPrivBytes: keys.priv);
    return ls = s;
  }

  /// the card this phone hands out with its kyber part taken off: a 0.5.x
  /// phone's card has the same fields
  Future<String> classicCard() async {
    final j =
        jsonDecode(utf8.decode(base64Decode(await ls!.makeBundleB64())))
            as Map<String, dynamic>
          ..remove('kyberPreKeyId')
          ..remove('kyberPreKeyPublic')
          ..remove('kyberPreKeySignature');
    return base64Encode(utf8.encode(jsonEncode(j)));
  }

  /// [wire] from [peer] opened
  Future<String> read(String peer, String wire) async {
    final w = base64Decode(wire);
    final plain = await ls!.open(peer, w[0], Uint8List.fromList(w.sublist(1)));
    return unpadText(plain);
  }

  Future<String> seal(String peer, String text) => ls!.encryptTo(peer, text);
}

String unpadText(List<int> plain) => unpad(utf8.decode(plain));
