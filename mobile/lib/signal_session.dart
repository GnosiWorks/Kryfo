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

    // clamp priv per RFC 7748 — libsignal expects already-clamped scalar
    final clamped = Uint8List.fromList(xPrivBytes);
    clamped[0] &= 0xF8;
    clamped[31] &= 0x7F;
    clamped[31] |= 0x40;
    final pub = Curve.decodePoint(
        Uint8List.fromList([0x05, ...xPubBytes]), 0);
    final priv = Curve.decodePrivatePoint(clamped);
    identityKeyPair = IdentityKeyPair(IdentityKey(pub), priv);

    registrationId = await _loadOrGenRegId(database);

    identityStore = HaloIdentityKeyStore(database, identityKeyPair, registrationId);
    preKeyStore = HaloPreKeyStore(database);
    sessionStore = HaloSessionStore(database);
    signedPreKeyStore = HaloSignedPreKeyStore(database);

    final spkRows = await database.query('signed_prekeys', limit: 1);
    if (spkRows.isEmpty) {
      final spk = generateSignedPreKey(identityKeyPair, 1);
      await signedPreKeyStore.storeSignedPreKey(spk.id, spk);
      debugPrint('signal: generated signed prekey id=${spk.id}');
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
    final rows = await d.query('signal_meta',
        where: 'k = ?', whereArgs: ['regId'], limit: 1);
    if (rows.isNotEmpty) return int.parse(rows.first['v'] as String);
    final id = generateRegistrationId(false);
    await d.insert('signal_meta', {'k': 'regId', 'v': id.toString()});
    return id;
  }
}

final signalSession = SignalSession();
