// SPDX-License-Identifier: GPL-3.0-or-later
// the dev chat's way through signal: which store its messages go through,
// and the seal every frame for him passes. a chat started with three words
// uses the everyday store; an anonymous one a store of its own under the
// name made for it, in the same database under the dev_ tables. read off
// the everyday container's row at every use, so a delete or a restore
// counts at once. nothing ever falls back to the everyday store for an
// anonymous chat

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../dlog.dart';
import '../signal_session.dart';
import '../signal_stores.dart' show kDevSignalPrefix;
import 'dev_chat.dart';
import 'dev_frame.dart';
import 'dev_key.dart';

// a frame as it may go to him, or null
typedef DevFrameRule = String? Function(String wrapped, {DevSelf? anon});

// why the seal made nothing: the chat has no store (not started, deleted,
// restored without its made name), his key is not the pinned one where it
// is kept, or the frame may not go to him
enum DevRefusal { noStore, keyCheck, frame }

class DevSealRefused extends StateError {
  DevSealRefused(this.why) : super('dev chat: ${why.name}, nothing sealed');

  final DevRefusal why;
}

// the dev chat as its seal finds it: the key it talks to, the store its
// messages go through, and the name made for it when anonymous
class DevSeat {
  const DevSeat(this.key, this.store, this.anon);

  final DevKey key;
  final SignalSession store;
  final DevSelf? anon;
}

class DevLane {
  DevLane({
    this.chat,
    this.open,
    SignalSession Function()? everyday,
    DevTokens? tokens,
    this.frame = devOutFrame,
  }) : _everyday = everyday ?? _signal,
       tokens = tokens ?? DevTokens();

  // the everyday container's dev chat row, as the gate reads it
  Future<DevChatRow?> Function()? chat;
  // the everyday container's database, where the anonymous store lives
  Future<Database> Function()? open;
  final SignalSession Function() _everyday;
  // what the seal made, for the gate
  final DevTokens tokens;
  final DevFrameRule frame;
  // a message from him opened on the pq state of a record that still holds
  // classic ones, on a seat of its own (the everyday store says so itself)
  void Function(String peer)? onPqOver;

  static SignalSession _signal() => signalSession;

  Future<SignalSession>? _anon;
  // the name and the database the store above was opened for
  String? _anonXPub;
  Database? _anonIn;

  Future<DevChatRow?> _row() async {
    final read = chat;
    if (read == null) return null;
    try {
      return await read();
    } catch (e) {
      dlog('dev lane: the chat did not read ($e)');
      return null;
    }
  }

  /// the chat [peer] names, when it was started, talks to a key that still
  /// works, and has its store here. null otherwise: fresh, gone, a restored
  /// anonymous chat without its name, or any id that is not the chat's own
  Future<DevSeat?> seat(String peer) async {
    final r = await _row();
    if (r == null || !r.started) return null;
    final k = r.key;
    if (k == null || k.status == DevKeyStatus.retired || k.chatId != peer) {
      return null;
    }
    if (r.state == DevState.everyday) {
      final ss = _everyday();
      return ss.ready ? DevSeat(k, ss, null) : null;
    }
    final self = DevSelf.ofKeys(r.anonId, r.anonEdPriv, r.anonXPriv);
    if (self == null) return null;
    final ss = await _anonStore(self, r.anonXPriv!);
    return ss == null ? null : DevSeat(k, ss, self);
  }

  Future<SignalSession?> _anonStore(DevSelf self, String xPriv) async {
    final o = open;
    if (o == null) return null;
    try {
      final db = await o();
      var made = _anon;
      if (made == null || _anonXPub != self.xPub || !identical(_anonIn, db)) {
        _anonXPub = self.xPub;
        _anonIn = db;
        made = _anon = _boot(db, self.xPub, xPriv);
      }
      final ss = await made;
      ss.onPqOver = (p) => onPqOver?.call(p);
      return ss;
    } catch (e) {
      dlog('dev lane: the anonymous store did not open ($e)');
      _anon = null;
      return null;
    }
  }

  static Future<SignalSession> _boot(
    Database db,
    String xPub,
    String xPriv,
  ) async {
    final ss = SignalSession();
    final priv = _bytes(xPriv);
    try {
      await ss.bootstrapInitiator(
        database: db,
        xPubBytes: _bytes(xPub),
        xPrivBytes: priv,
        prefix: kDevSignalPrefix,
      );
    } finally {
      // the store keeps a copy of its own
      priv.fillRange(0, priv.length, 0);
    }
    return ss;
  }

  /// [wrapped] for [peer] through the seal: rewritten from the allowlist,
  /// sealed in the chat's own store, and its cipher noted for the gate.
  /// throws [DevSealRefused] when the chat has no store, his key is not the
  /// pinned one, or the frame may not go
  Future<String> encrypt(String peer, String wrapped) async {
    final s = await seat(peer);
    if (s == null) throw DevSealRefused(DevRefusal.noStore);
    if (!await _pinnedStill(s, peer)) {
      throw DevSealRefused(DevRefusal.keyCheck);
    }
    final out = frame(wrapped, anon: s.anon);
    if (out == null) throw DevSealRefused(DevRefusal.frame);
    if (kDevPqRestart) await _pqFromCard(s, peer);
    // a session a restore brought back starts afresh from his pinned card
    final cipher = await s.store.encryptTo(
      peer,
      out,
      afresh: () async => lsBundleOf(s.store.lib, s.key.bundle),
    );
    tokens.mint(cipher);
    return cipher;
  }

  // before every seal: the key his store holds and the key on his chat's
  // row are the pinned one, byte for byte
  Future<bool> _pinnedStill(DevSeat s, String peer) async {
    try {
      final held = await s.store.identityStore.getIdentity(peer);
      if (held == null || !_same(held, pinnedIdentity(s.key))) {
        return false;
      }
      final o = open;
      if (o == null) return false;
      final row = await (await o()).query(
        'contacts',
        columns: ['xpub'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      return row.isNotEmpty && row.first['xpub'] == s.key.xPub;
    } catch (e) {
      dlog('dev lane: the key check did not read ($e)');
      return false;
    }
  }

  // a chat started on a classic card goes over to pq on the pinned card
  // once it carries a kyber prekey: a session on the card in front of the
  // held one, whose next seal is the opener. his main invite never expires,
  // so the card's keys are there to open it, and the
  // classic states go 16 days after his first pq message (pqUpkeep)
  Future<void> _pqFromCard(DevSeat s, String peer) async {
    if (!devCardStarts(s.key)) return;
    try {
      final info = await s.store.sessionInfo(peer);
      if (info == null || info.version >= 4) return;
      final card = lsBundleOf(s.store.lib, s.key.bundle);
      if (await s.store.restartFrom(peer, card, classicOnly: true)) {
        dlog('dev lane: the chat goes over to pq');
      }
    } catch (e) {
      dlog('dev lane: no pq restart on the card (${e.runtimeType})');
    }
  }

  /// a delete: the store and the ciphers go with the chat
  void forget() {
    _anon = null;
    _anonXPub = null;
    _anonIn = null;
    tokens.clear();
  }
}

/// his card as it is pinned: its identity is his pinned key, and that key
/// signs the card's signed prekey, and its kyber prekey where it carries
/// one. checked before a first send keeps anything, in every container
bool devCardChecks(DevKey k) {
  try {
    final j = jsonDecode(utf8.decode(base64Decode(k.bundle)));
    if (j is! Map) return false;
    final id = base64Decode(j['identityKey'] as String);
    if (!_same(id, pinnedIdentity(k))) return false;
    if (!preKeySigned(
      id,
      base64Decode(j['signedPreKeyPublic'] as String),
      base64Decode(j['signedPreKeySignature'] as String),
    )) {
      return false;
    }
    if (!j.containsKey('kyberPreKeyPublic')) return true;
    return preKeySigned(
      id,
      base64Decode(j['kyberPreKeyPublic'] as String),
      base64Decode(j['kyberPreKeySignature'] as String),
    );
  } catch (_) {
    return false;
  }
}

/// [k]'s card is from before 0.6: it carries no post-quantum prekey, so no
/// chat starts on it here (a later app pins a new one)
bool devCardOld(DevKey k) {
  try {
    cardBundle(k.bundle);
    return false;
  } on ClassicRefused {
    return true;
  } catch (_) {
    return false;
  }
}

/// a new dev chat can start on [k]'s card: it carries the post-quantum
/// prekey and every check on it holds
bool devCardStarts(DevKey k) {
  if (!devCardChecks(k)) return false;
  try {
    cardBundle(k.bundle);
    return true;
  } catch (_) {
    return false;
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// whether a dev chat started on a classic card goes over to pq on the
/// pinned card. nothing runs
/// until a card with a kyber prekey is pinned (docs/RELEASING.md)
const kDevPqRestart = true;

// the one lane. the app points it at the everyday container
final devLane = DevLane(tokens: devTokens);
