// SPDX-License-Identifier: GPL-3.0-or-later
// libsignal session bootstrap. derives identity from existing X25519 keys,
// generates signed prekey + one-time prekeys on first run.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'signal_stores.dart';
import 'dlog.dart';

class SignalSession {
  late HaloIdentityKeyStore identityStore;
  late HaloPreKeyStore preKeyStore;
  late HaloSessionStore sessionStore;
  late HaloSignedPreKeyStore signedPreKeyStore;
  late IdentityKeyPair identityKeyPair;
  late int registrationId;
  bool _ready = false;
  bool get ready => _ready;
  late Database _db;
  String _prefix = '';
  // the base keys of the sessions a restore brought back. the phone the
  // file was made on went on sealing on them after it, so the peer has
  // spent their next message keys already: a seal on one repeats a number
  // the peer drops as a duplicate. none is sealed on again (see encryptTo)
  Set<String> _restored = const {};

  /// a restore brought sessions back into this store
  bool get hasRestored => _restored.isNotEmpty;

  Future<void> bootstrap({
    required Database database,
    required Uint8List xPubBytes,
    required Uint8List xPrivBytes,
    String prefix = '',
    bool restored = false,
  }) async {
    if (_ready) return;
    await _open(database, xPubBytes, xPrivBytes, prefix, restored: restored);

    final spkRows = await database.query('${prefix}signed_prekeys', limit: 1);
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
      dlog('signal: existing spk self-verify = $ok');
      if (!ok) {
        await signedPreKeyStore.removeSignedPreKey(spk.id);
        spk = null;
      }
    }
    if (spk == null) {
      final freshBytes = await compute(
        _genSignedPreKeyTask,
        identityKeyPair.serialize(),
      );
      final fresh = SignedPreKeyRecord.fromSerialized(freshBytes);
      await signedPreKeyStore.storeSignedPreKey(fresh.id, fresh);
      final ok = Curve.verifySignature(
        identityKeyPair.getPublicKey().publicKey,
        fresh.getKeyPair().publicKey.serialize(),
        fresh.signature,
      );
      dlog('signal: generated signed prekey id=${fresh.id} self-verify = $ok');
    }

    // keep prekeys 0-9 topped up by the ids present, not by count: once one
    // is consumed a count misses the gap, and a first message finds no key
    final pkRows = await database.query('${prefix}prekeys', columns: ['id']);
    final have = pkRows.map((r) => r['id'] as int).toSet();
    final missing = [
      for (var i = 0; i < 10; i++)
        if (!have.contains(i)) i,
    ];
    if (missing.isNotEmpty) {
      final blobs = await compute(_genPreKeysTask, missing);
      for (final blob in blobs) {
        final k = PreKeyRecord.fromBuffer(blob);
        await preKeyStore.storePreKey(k.id, k);
      }
      dlog('signal: filled prekey ids=$missing');
    }
    // the invite's own prekey, made once and kept: see invitePreKeyId
    if (!have.contains(invitePreKeyId)) {
      final blob = (await compute(_genPreKeysTask, [invitePreKeyId])).first;
      final k = PreKeyRecord.fromBuffer(blob);
      await preKeyStore.storePreKey(k.id, k);
      dlog('signal: made the invite prekey');
    }

    _ready = true;
    dlog('signal: bootstrapped (regId=$registrationId)');
  }

  // a new identity in place of the one this store was opened with. the
  // signed prekey is signed with the old key and the invite's prekey went
  // out with it, so both are made again for the new one
  Future<void> rekey({
    required Database database,
    required Uint8List xPubBytes,
    required Uint8List xPrivBytes,
    String prefix = '',
  }) async {
    _ready = false;
    await database.delete('${prefix}signed_prekeys');
    await database.delete(
      '${prefix}prekeys',
      where: 'id = ?',
      whereArgs: [invitePreKeyId],
    );
    await bootstrap(
      database: database,
      xPubBytes: xPubBytes,
      xPrivBytes: xPrivBytes,
      prefix: prefix,
    );
  }

  // an identity that only ever opens sessions: its key pair and a
  // registration id of its own. nobody starts one with it, so it hands out
  // no prekeys and makes none
  Future<void> bootstrapInitiator({
    required Database database,
    required Uint8List xPubBytes,
    required Uint8List xPrivBytes,
    required String prefix,
  }) async {
    if (_ready) return;
    await _open(database, xPubBytes, xPrivBytes, prefix);
    _ready = true;
  }

  // [restored]: the first start after a restore. its sessions are marked
  // before any store is up, so nothing can seal on one before that
  Future<void> _open(
    Database database,
    Uint8List xPubBytes,
    Uint8List xPrivBytes,
    String prefix, {
    bool restored = false,
  }) async {
    // clamp priv per RFC 7748: libsignal expects an already-clamped scalar
    final clamped = Uint8List.fromList(xPrivBytes);
    clamped[0] &= 0xF8;
    clamped[31] &= 0x7F;
    clamped[31] |= 0x40;
    final pub = Curve.decodePoint(Uint8List.fromList([0x05, ...xPubBytes]), 0);
    final priv = Curve.decodePrivatePoint(clamped);
    // do NOT zero `clamped` here: decodePrivatePoint keeps a reference to this
    // buffer, and wiping it corrupts every signature this identity makes
    identityKeyPair = IdentityKeyPair(IdentityKey(pub), priv);

    registrationId = await _loadOrGenRegId(database, prefix);
    _db = database;
    _prefix = prefix;
    _restored = await _loadRestored();
    if (restored) await markRestored();

    identityStore = HaloIdentityKeyStore(
      database,
      identityKeyPair,
      registrationId,
      prefix: prefix,
    );
    preKeyStore = HaloPreKeyStore(database, prefix: prefix);
    sessionStore = HaloSessionStore(database, prefix: prefix);
    signedPreKeyStore = HaloSignedPreKeyStore(database, prefix: prefix);
  }

  // one session step at a time per peer, seals and opens alike. each loads
  // the record, awaits the identity store, then writes it back, so two
  // that overlap lose one of the steps and the next seal repeats a number
  final Map<String, Future<void>> _steps = {};

  /// [job] run after every earlier one queued for [peer] has ended
  Future<T> serial<T>(String peer, Future<T> Function() job) {
    final out = (_steps[peer] ?? Future<void>.value()).then((_) => job());
    // the caller gets any error from out; the chain only keeps the order
    final tail = out.then<void>((_) {}, onError: (_) {});
    _steps[peer] = tail;
    tail.whenComplete(() {
      if (identical(_steps[peer], tail)) _steps.remove(peer);
    });
    return out;
  }

  // [plain] sealed to [peer] in this store, as the wire carries it: the
  // message type byte, then the message, in base64. a session a restore
  // brought back is not sealed on: one is started afresh from the card
  // [afresh] hands over, the old one archived so what the peer sealed on it
  // still opens. with no card the seal fails with StartingAfresh
  Future<String> encryptTo(
    String peer,
    String plain, {
    Future<PreKeyBundle?> Function()? afresh,
  }) => serial(peer, () async {
    if (await sealsOnRestored(peer)) {
      final card = afresh == null ? null : await afresh();
      if (card == null) throw StartingAfresh(peer);
      await SessionBuilder(
        sessionStore,
        preKeyStore,
        signedPreKeyStore,
        identityStore,
        SignalProtocolAddress(peer, 1),
      ).processPreKeyBundle(card);
      dlog('signal: started afresh after a restore');
    }
    return _seal(peer, plain);
  });

  /// whether the session a seal to [peer] would use came back with a restore
  Future<bool> sealsOnRestored(String peer) async {
    if (_restored.isEmpty) return false;
    final addr = SignalProtocolAddress(peer, 1);
    if (!await sessionStore.containsSession(addr)) return false;
    final record = await sessionStore.loadSession(addr);
    return _restored.contains(_baseOf(record.sessionState));
  }

  /// every session held now came back with a restore: written down with
  /// the sessions, so it holds across starts. an earlier restore's list
  /// goes, its sessions are in this one's
  Future<void> markRestored() async {
    final keys = <String>{};
    for (final r in await _db.query(
      '${_prefix}sessions',
      columns: ['record'],
    )) {
      try {
        final record = SessionRecord.fromSerialized(r['record'] as Uint8List);
        keys.add(_baseOf(record.sessionState));
        for (final s in record.previousSessionStates) {
          keys.add(_baseOf(s));
        }
      } catch (e) {
        dlog('signal: a session not read (${e.runtimeType})');
      }
    }
    await _db.insert('${_prefix}signal_meta', {
      'k': _kRestored,
      'v': jsonEncode(keys.toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _restored = keys;
    dlog('signal: ${keys.length} sessions came back with a restore');
  }

  Future<Set<String>> _loadRestored() async {
    final rows = await _db.query(
      '${_prefix}signal_meta',
      where: 'k = ?',
      whereArgs: [_kRestored],
      limit: 1,
    );
    if (rows.isEmpty) return const {};
    try {
      return {for (final k in jsonDecode(rows.first['v'] as String)) '$k'};
    } catch (_) {
      return const {};
    }
  }

  Future<String> _seal(String peer, String plain) async {
    final cipher = SessionCipher(
      sessionStore,
      preKeyStore,
      signedPreKeyStore,
      identityStore,
      SignalProtocolAddress(peer, 1),
    );
    final msg = await cipher.encrypt(Uint8List.fromList(utf8.encode(plain)));
    return base64Encode([msg.getType(), ...msg.serialize()]);
  }

  // a new invite prekey under the same id. every bundle handed out before
  // this names a key that no longer exists, so the openers built on them
  // fail at the door: that is what "reset my invite link" has to mean.
  Future<void> rotateInvitePreKey() async {
    final blob = (await compute(_genPreKeysTask, [invitePreKeyId])).first;
    final k = PreKeyRecord.fromBuffer(blob);
    await preKeyStore.storePreKey(k.id, k);
    dlog('signal: rotated the invite prekey');
  }

  Future<int> _loadOrGenRegId(Database d, String prefix) async {
    final rows = await d.query(
      '${prefix}signal_meta',
      where: 'k = ?',
      whereArgs: ['regId'],
      limit: 1,
    );
    if (rows.isNotEmpty) return int.parse(rows.first['v'] as String);
    final id = generateRegistrationId(false);
    await d.insert('${prefix}signal_meta', {'k': 'regId', 'v': id.toString()});
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
      dlog('peerXPubHex: ${e.runtimeType}');
      return null;
    }
  }
}

const _kRestored = 'restored_sessions';

// what names a session on both sides of it: the base key its opener made
String _baseOf(SessionState s) => base64Encode(s.aliceBaseKey);

/// the pref a restore leaves for the next start, which then marks the
/// sessions it brought back as the store opens (bootstrap, restored)
const kSessionsRestoredPref = 'signal.restored';

/// a seal to [peer] waits for a session started afresh: the one held came
/// back with a restore, and no card of theirs is kept to start one from
class StartingAfresh implements Exception {
  StartingAfresh(this.peer);
  final String peer;
  @override
  String toString() => 'StartingAfresh: waiting for their card';
}

// prekey generation is heavy curve math, slow enough on weak phones for
// android to call the app dead, so it runs off the ui thread
Uint8List _genSignedPreKeyTask(Uint8List idPairBytes) {
  final pair = IdentityKeyPair.fromSerialized(idPairBytes);
  return generateSignedPreKey(pair, 1).serialize();
}

List<Uint8List> _genPreKeysTask(List<int> ids) {
  return [for (final id in ids) generatePreKeys(id, 1).first.serialize()];
}

final signalSession = SignalSession();
