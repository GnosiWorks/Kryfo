// SPDX-License-Identifier: GPL-3.0-or-later
// a phone on the 0.5.3 release, for the tests that prove this version still
// talks to one. signal_session.dart, signal_stores.dart, dlog.dart and
// wire_pad.dart here are 0.5.3's files byte for byte (test/same_test.dart
// checks them against the v0.5.3 tag); devchat/dev_key.dart stands in for
// the dev chat, which this peer never plays. never part of the app
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'signal_session.dart';
import 'wire_pad.dart';

export 'signal_session.dart' show SignalSession;

/// one 0.5.3 phone: its signal layer on its own file
class Phone053 {
  Phone053(this.ss);
  final SignalSession ss;

  /// a store on [db] for the x25519 pair 0.5.3 keeps
  static Future<Phone053> open(
    Database db, {
    required Uint8List xPub,
    required Uint8List xPriv,
    String prefix = '',
  }) async {
    final ss = SignalSession();
    await ss.bootstrap(
      database: db,
      xPubBytes: xPub,
      xPrivBytes: xPriv,
      prefix: prefix,
    );
    return Phone053(ss);
  }

  Future<String> seal(String peer, String text) => ss.encryptTo(peer, text);

  /// [wire] from [peer] opened as 0.5.3's app/signal.dart _open does: an
  /// opener on a session held tried on that session first, then as an
  /// opener. throws what the library throws
  Future<String> read(String peer, String wire) async {
    final w = base64Decode(wire);
    final body = Uint8List.fromList(w.sublist(1));
    final addr = SignalProtocolAddress(peer, 1);
    final c = SessionCipher(
      ss.sessionStore,
      ss.preKeyStore,
      ss.signedPreKeyStore,
      ss.identityStore,
      addr,
    );
    final plain = await ss.serial<Uint8List>(peer, () async {
      if (w[0] != CiphertextMessage.prekeyType) {
        return c.decryptFromSignal(SignalMessage.fromSerialized(body));
      }
      final pkm = PreKeySignalMessage(body);
      if (await ss.sessionStore.containsSession(addr)) {
        try {
          return await c.decryptFromSignal(pkm.getWhisperMessage());
        } catch (_) {
          return c.decrypt(pkm);
        }
      }
      return c.decrypt(pkm);
    });
    return unpad(utf8.decode(plain));
  }

  /// the version of the session held with [peer]
  Future<int> sessionVersion(String peer) async =>
      (await ss.sessionStore.loadSession(
        SignalProtocolAddress(peer, 1),
      )).sessionState.getSessionVersion();

  /// the card 0.5.3 hands out: no kyber prekey
  Future<String> card() async {
    final spk = await ss.signedPreKeyStore.loadSignedPreKey(1);
    final pk = await ss.preKeyStore.loadPreKey(invitePreKeyId053);
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

  /// a session to [peer] built from [cardB64] as 0.5.3's processPeerBundle
  /// builds one: the fields it knows, a kyber prekey on it skipped
  Future<void> startFrom(String peer, String cardB64) => ss.serial(
    peer,
    () => SessionBuilder(
      ss.sessionStore,
      ss.preKeyStore,
      ss.signedPreKeyStore,
      ss.identityStore,
      SignalProtocolAddress(peer, 1),
    ).processPreKeyBundle(preKeyBundleOf(cardB64)),
  );
}

/// the invite prekey id 0.5.3 keeps
const invitePreKeyId053 = 999999;
