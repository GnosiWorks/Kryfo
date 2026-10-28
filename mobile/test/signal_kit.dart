// SPDX-License-Identifier: GPL-3.0-or-later
// what the tests ask of signal around the app's own layer: x25519 pairs as
// the app keeps them, a phone's store opened on the shim, and a wire read
// back. the shim is the host library build-host.sh makes
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show unpad;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'mem_db.dart';

export 'package:kryfo/signal_ffi/kryfo_signal.dart'
    show
        KryfoSignal,
        LsError,
        kLsKyber,
        kLsOneTime,
        kLsPreKey,
        kLsSigned,
        kLsWhisper;

final _rnd = Random.secure();

/// one half of a test pair, read back as libsignal writes it
class TestKey {
  TestKey(this._b);
  final Uint8List _b;
  Uint8List serialize() => Uint8List.fromList(_b);
}

/// an x25519 pair: the public half as signal writes it (0x05 and 32
/// bytes), the private half as the app's identities keep it (32 bytes)
class TestKeyPair {
  TestKeyPair(this.publicKey, this.privateKey);
  final TestKey publicKey;
  final TestKey privateKey;

  /// the 32 bytes the app's x key is
  Uint8List get xPub => publicKey.serialize().sublist(1);
}

/// a fresh pair, its private half clamped as x25519 takes it
TestKeyPair testKeyPair() {
  final priv = Uint8List.fromList([
    for (var i = 0; i < 32; i++) _rnd.nextInt(256),
  ]);
  priv[0] &= 0xf8;
  priv[31] &= 0x7f;
  priv[31] |= 0x40;
  return testKeyPairFromPrivate(priv);
}

/// the pair on [priv]
TestKeyPair testKeyPairFromPrivate(List<int> priv) {
  final id = KryfoSignal.shared.identityFromPrivate(priv);
  return TestKeyPair(TestKey(id.public), TestKey(Uint8List.fromList(priv)));
}

/// a store on [db] (a fresh one when null) for a fresh pair, or [keys]
Future<SignalSession> testStore({
  Database? db,
  TestKeyPair? keys,
  String prefix = '',
}) async {
  final k = keys ?? testKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: db ?? MemDb(),
    xPubBytes: k.xPub,
    xPrivBytes: k.privateKey.serialize(),
    prefix: prefix,
  );
  return ss;
}

/// [wire] from [peer] opened in [ss], its padding off
Future<String> openWire(SignalSession ss, String peer, String wire) async {
  final w = base64Decode(wire);
  final plain = await ss.open(peer, w[0], Uint8List.sublistView(w, 1));
  return unpad(utf8.decode(plain));
}

/// whether [wire] is an opener (a prekey message)
bool isOpener(String wire) => base64Decode(wire)[0] == kLsPreKey;

/// the whisper message inside [opener] (a prekey message, without the
/// wire's type byte), as the wire would carry it on its own
Uint8List openerMessage(List<int> opener) {
  final (at, n) = _messageField(opener);
  return Uint8List.fromList(opener.sublist(at, at + n));
}

/// [opener] with the last byte of the mac of the message inside it
/// flipped: it reads, names the same keys, and fails to open
Uint8List flipOpenerMac(List<int> opener) {
  final out = Uint8List.fromList(opener);
  final (at, n) = _messageField(out);
  out[at + n - 1] ^= 1;
  return out;
}

// where field 4 (the message) of an opener's protobuf starts, and its length
(int, int) _messageField(List<int> out) {
  var at = 1;
  int varint() {
    var v = 0;
    for (var shift = 0; ; shift += 7) {
      final x = out[at++];
      v |= (x & 0x7f) << shift;
      if (x < 0x80) return v;
    }
  }

  while (at < out.length) {
    final tag = varint();
    final kind = tag & 7;
    if (kind == 0) {
      varint();
      continue;
    }
    if (kind != 2) throw StateError('not an opener');
    final n = varint();
    if (tag >> 3 == 4) return (at, n);
    at += n;
  }
  throw StateError('no message in the opener');
}

/// [ss]'s card with its one-time prekey [id] in place of the invite's
Future<String> cardWithOneTime(SignalSession ss, int id) async {
  final pk = ss.lib.preKeyPublic(kLsOneTime, (await ss.preKeyStore.load(id))!);
  final card =
      jsonDecode(utf8.decode(base64Decode(await ss.makeBundleB64())))
          as Map<String, dynamic>;
  card['preKeyId'] = pk.id;
  card['preKeyPublic'] = base64Encode(pk.public);
  return base64Encode(utf8.encode(jsonEncode(card)));
}

final _storedBefore = () {
  return jsonDecode(File('test/signal_stored_before.json').readAsStringSync())
      as Map<String, dynamic>;
}();

/// [who]'s store from the 0.7.4 fixture (alice, bob or carol), as the old
/// library wrote it: alice and bob hold a classic session both have
/// answered on, carol one bob never answered, so her every seal to him is
/// a classic opener
Future<SignalSession> fixtureStore(String who) async {
  final db = MemDb();
  final me = _storedBefore[who] as Map;
  for (final r in me['rows'] as List) {
    await db.insert((r as Map)['t'] as String, {
      for (final e in (r['row'] as Map).entries)
        e.key as String: e.value is Map
            ? base64Decode((e.value as Map)['b64'] as String)
            : e.value,
    });
  }
  final ss = SignalSession();
  await ss.bootstrap(
    database: db,
    xPubBytes: base64Decode(me['pub'] as String),
    xPrivBytes: base64Decode(me['priv'] as String),
  );
  return ss;
}
