// SPDX-License-Identifier: GPL-3.0-or-later
// the shim library for the host tests, and what they share. the library is
// built by native/kryfo_signal/build-host.sh; without it every test that
// needs it skips and says so
import 'dart:convert';
import 'dart:typed_data';

import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_session_ls.dart';
import 'package:kryfo/signal_stores.dart' show invitePreKeyId;
import 'package:kryfo/wire_pad.dart' show unpad;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../mem_db.dart';

final KryfoSignal? shim = KryfoSignal.forHostTests();

/// the skip reason for a test that needs the shim, false when it is there
final Object needsShim = shim == null
    ? 'libkryfo_signal not built: run native/kryfo_signal/build-host.sh, or '
          'point ${KryfoSignal.envVar} at the library'
    : false;

/// an x25519 pair as the app keeps one: 32 bytes each
({Uint8List pub, Uint8List priv}) xPair() {
  final kp = Curve.generateKeyPair();
  return (
    pub: kp.publicKey.serialize().sublist(1),
    priv: kp.privateKey.serialize(),
  );
}

/// one phone: its keys, its database, and whichever layer has it open
class Phone {
  Phone() : keys = xPair(), db = MemDb();
  Phone.of(this.keys, this.db);
  final ({Uint8List pub, Uint8List priv}) keys;
  final MemDb db;
  SignalSession? old;
  SignalSessionLs? ls;

  Future<SignalSession> openOld() async {
    ls = null;
    final s = SignalSession();
    await s.bootstrap(database: db, xPubBytes: keys.pub, xPrivBytes: keys.priv);
    return old = s;
  }

  Future<SignalSessionLs> openLs() async {
    old = null;
    final s = SignalSessionLs(shim!);
    await s.bootstrap(database: db, xPubBytes: keys.pub, xPrivBytes: keys.priv);
    return ls = s;
  }

  /// a classic card from the old layer's store, as 0.5.x hands it out
  Future<String> oldCard() async {
    final ss = old!;
    final spk = await ss.signedPreKeyStore.loadSignedPreKey(1);
    final pk = await ss.preKeyStore.loadPreKey(invitePreKeyId);
    return base64Encode(
      utf8.encode(
        jsonEncode({
          'registrationId': ss.registrationId,
          'deviceId': 1,
          'preKeyId': pk.id,
          'preKeyPublic': base64Encode(pk.getKeyPair().publicKey.serialize()),
          'signedPreKeyId': spk.id,
          'signedPreKeyPublic': base64Encode(
            spk.getKeyPair().publicKey.serialize(),
          ),
          'signedPreKeySignature': base64Encode(spk.signature),
          'identityKey': base64Encode(
            ss.identityKeyPair.getPublicKey().serialize(),
          ),
        }),
      ),
    );
  }

  /// [wire] from [peer] opened by whichever layer is open
  Future<String> read(String peer, String wire) async {
    final w = base64Decode(wire);
    final body = Uint8List.fromList(w.sublist(1));
    final Uint8List plain;
    if (ls != null) {
      plain = await ls!.open(peer, w[0], body);
    } else {
      final ss = old!;
      final c = SessionCipher(
        ss.sessionStore,
        ss.preKeyStore,
        ss.signedPreKeyStore,
        ss.identityStore,
        SignalProtocolAddress(peer, 1),
      );
      plain = w[0] == CiphertextMessage.prekeyType
          ? await c.decrypt(PreKeySignalMessage(body))
          : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
    }
    return unpadText(plain);
  }

  Future<String> seal(String peer, String text) =>
      ls != null ? ls!.encryptTo(peer, text) : old!.encryptTo(peer, text);
}

String unpadText(List<int> plain) => unpad(utf8.decode(plain));
