// SPDX-License-Identifier: GPL-3.0-or-later
// libsignal session bootstrap. derives identity from existing X25519 keys,
// generates signed prekey + one-time prekeys on first run.

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'signal_stores.dart';

class SignalSession {
  late HaloIdentityKeyStore identityStore;
  late HaloPreKeyStore preKeyStore;
  late HaloSessionStore sessionStore;
  late HaloSignedPreKeyStore signedPreKeyStore;
  late IdentityKeyPair identityKeyPair;
  late int registrationId;
  bool _ready = false;
  bool get ready => _ready;

  Future<void> bootstrap({
    required Database database,
    required Uint8List xPubBytes,
    required Uint8List xPrivBytes,
  }) async {
    if (_ready) return;

    // clamp priv per RFC 7748 - libsignal expects already-clamped scalar
    final clamped = Uint8List.fromList(xPrivBytes);
    clamped[0] &= 0xF8;
    clamped[31] &= 0x7F;
    clamped[31] |= 0x40;
    final pub = Curve.decodePoint(Uint8List.fromList([0x05, ...xPubBytes]), 0);
    final priv = Curve.decodePrivatePoint(clamped);
    identityKeyPair = IdentityKeyPair(IdentityKey(pub), priv);

    registrationId = await _loadOrGenRegId(database);

    identityStore = HaloIdentityKeyStore(
      database,
      identityKeyPair,
      registrationId,
    );
    preKeyStore = HaloPreKeyStore(database);
    sessionStore = HaloSessionStore(database);
    signedPreKeyStore = HaloSignedPreKeyStore(database);

    final spkRows = await database.query('signed_prekeys', limit: 1);
    SignedPreKeyRecord? spk;
    if (spkRows.isNotEmpty) {
      spk = SignedPreKeyRecord.fromSerialized(
        spkRows.first['record'] as Uint8List,
      );
      final ok = Curve.verifySignature(
        identityKeyPair.getPublicKey().publicKey,
        spk.getKeyPair().publicKey.serialize(),
        spk.signature,
      );
      debugPrint('signal: existing spk self-verify = $ok');
      if (!ok) {
        await signedPreKeyStore.removeSignedPreKey(spk.id);
        spk = null;
      }
    }
    if (spk == null) {
      final fresh = generateSignedPreKey(identityKeyPair, 1);
      await signedPreKeyStore.storeSignedPreKey(fresh.id, fresh);
      final ok = Curve.verifySignature(
        identityKeyPair.getPublicKey().publicKey,
        fresh.getKeyPair().publicKey.serialize(),
        fresh.signature,
      );
      debugPrint(
        'signal: generated signed prekey id=${fresh.id} self-verify = $ok',
      );
    }

    final pkRows = await database.query('prekeys');
    if (pkRows.length < 10) {
      final start = pkRows.length;
      final keys = generatePreKeys(start, 10 - start);
      for (final k in keys) {
        await preKeyStore.storePreKey(k.id, k);
      }
      debugPrint('signal: generated ${keys.length} one-time prekeys');
    }

    _ready = true;
    debugPrint('signal: bootstrapped (regId=$registrationId)');
  }

  Future<int> _loadOrGenRegId(Database d) async {
    final rows = await d.query(
      'signal_meta',
      where: 'k = ?',
      whereArgs: ['regId'],
      limit: 1,
    );
    if (rows.isNotEmpty) return int.parse(rows.first['v'] as String);
    final id = generateRegistrationId(false);
    await d.insert('signal_meta', {'k': 'regId', 'v': id.toString()});
    return id;
  }

  Future<String?> peerXPubHex(String peerHaloId) async {
    try {
      final addr = SignalProtocolAddress(peerHaloId, 1);
      final identity = await identityStore.getIdentity(addr);
      if (identity == null) return null;
      final raw = identity.publicKey.serialize();
      final pub = raw.length == 33 ? raw.sublist(1) : raw;
      return pub.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      debugPrint('peerXPubHex error: \$e');
      return null;
    }
  }
}

final signalSession = SignalSession();
