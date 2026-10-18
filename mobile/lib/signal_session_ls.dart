// SPDX-License-Identifier: GPL-3.0-or-later
// signal sessions over the libsignal shim (native/kryfo_signal), in place
// of libsignal_protocol_dart. the same tables, record bytes and restore
// marks as signal_session.dart, so a store that library wrote goes on
// here. new sessions are pqxdh with the pq ratchet only: a bundle without
// a kyber prekey and a pre-pq opener are refused, and nothing here builds
// a session with the old library.
//
// not wired into the app yet: kUseLibsignalShim stays false until the
// android, ios and f-droid builds carry the library

import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'dlog.dart';
import 'signal_ffi/kryfo_signal.dart';
import 'signal_session.dart'
    show IdentityMarks, KeyHeld, SignalSession, StartingAfresh;
import 'signal_stores.dart' show invitePreKeyId;
import 'signal_stores_ls.dart';
import 'wire_pad.dart';

/// the switch: the app keeps libsignal_protocol_dart while this is false
const kUseLibsignalShim = false;

/// a first contact without the post-quantum prekey, or a session that
/// would not be pqxdh: never built here
class ClassicRefused implements Exception {
  const ClassicRefused(this.why);
  final String why;
  @override
  String toString() => 'ClassicRefused: $why';
}

class SignalSessionLs {
  SignalSessionLs(this.lib);

  final KryfoSignal lib;
  late LsIdentityStore identityStore;
  late LsPreKeyStore preKeyStore;
  late LsSessionStore sessionStore;
  late LsSignedPreKeyStore signedPreKeyStore;
  late LsKyberPreKeyStore kyberPreKeyStore;
  late LsIdentity identity;
  late int registrationId;
  bool _ready = false;
  bool get ready => _ready;
  late Database _db;
  String _prefix = '';
  // as in SignalSession: the base keys of the sessions a restore brought
  // back, when each one's peer was last asked to start afresh, and when the
  // file was made
  Set<String> _restored = const {};
  Map<String, List<int>> _asks = {};
  int? _restoredFrom;

  bool get hasRestored => _restored.isNotEmpty;
  int? get restoredFrom => hasRestored ? _restoredFrom : null;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> bootstrap({
    required Database database,
    required Uint8List xPubBytes,
    required Uint8List xPrivBytes,
    String prefix = '',
    bool restored = false,
    int? restoredFrom,
  }) async {
    if (_ready) return;
    await _open(
      database,
      xPubBytes,
      xPrivBytes,
      prefix,
      restored: restored,
      restoredFrom: restoredFrom,
    );

    // a signed prekey the old library made reads here as it is
    final spk = await signedPreKeyStore.load(1);
    var spkOk = false;
    if (spk != null) {
      try {
        final p = lib.preKeyPublic(kLsSigned, spk);
        spkOk = lib.verify(identity.public, p.public, p.signature);
      } on LsError catch (e) {
        dlog('signal: a signed prekey that does not read ($e)');
      }
      dlog('signal: existing spk self-verify = $spkOk');
      if (!spkOk) await signedPreKeyStore.remove(1);
    }
    if (!spkOk) {
      final fresh = lib.signedPreKey(identity, 1, _now());
      await signedPreKeyStore.store(1, fresh.record);
      dlog('signal: generated signed prekey id=1');
    }

    // prekeys 0-9 topped up by the ids present, and the invite's own
    final have = (await preKeyStore.ids()).toSet();
    for (final id in [for (var i = 0; i < 10; i++) i, invitePreKeyId]) {
      if (have.contains(id)) continue;
      await preKeyStore.store(id, lib.preKey(id).record);
    }

    // the invite's kyber prekey: a last resort key, kept like the invite's
    // ec prekey, and made again when it no longer holds under this identity
    final k = await kyberPreKeyStore.load(kInviteKyberId);
    var kOk = false;
    if (k != null) {
      try {
        final p = lib.preKeyPublic(kLsKyber, k);
        kOk = lib.verify(identity.public, p.public, p.signature);
      } on LsError catch (e) {
        dlog('signal: a kyber prekey that does not read ($e)');
      }
    }
    if (!kOk) await _newInviteKyber();

    _ready = true;
    dlog('signal: bootstrapped on the shim (regId=$registrationId)');
  }

  Future<void> _newInviteKyber() async {
    final fresh = lib.kyberPreKey(identity, kInviteKyberId, _now());
    await kyberPreKeyStore.remove(kInviteKyberId);
    await kyberPreKeyStore.store(
      kInviteKyberId,
      fresh.record,
      lastResort: true,
    );
    dlog('signal: made the invite kyber prekey');
  }

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
    await ensureLsTables(database, prefix: prefix);
    await database.delete('${prefix}kyber_prekeys');
    await database.delete('${prefix}kyber_used');
    await bootstrap(
      database: database,
      xPubBytes: xPubBytes,
      xPrivBytes: xPrivBytes,
      prefix: prefix,
    );
  }

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

  Future<void> _open(
    Database database,
    Uint8List xPubBytes,
    Uint8List xPrivBytes,
    String prefix, {
    bool restored = false,
    int? restoredFrom,
  }) async {
    // libsignal clamps the scalar itself, as the old layer did by hand
    identity = lib.identityFromPrivate(xPrivBytes);
    final want = [0x05, ...xPubBytes];
    if (!_eq(identity.public, want)) {
      throw StateError('signal: the x25519 pair does not match');
    }
    await ensureLsTables(database, prefix: prefix);
    registrationId = await _loadOrGenRegId(database, prefix);
    _db = database;
    _prefix = prefix;
    _restored = await _loadRestored();
    _asks = await _loadAsks();
    _restoredFrom = await _loadFrom();
    if (restored) await markRestored(from: restoredFrom);

    identityStore = LsIdentityStore(
      database,
      identity,
      registrationId,
      prefix: prefix,
    );
    preKeyStore = LsPreKeyStore(database, prefix: prefix);
    sessionStore = LsSessionStore(database, prefix: prefix);
    signedPreKeyStore = LsSignedPreKeyStore(database, prefix: prefix);
    kyberPreKeyStore = LsKyberPreKeyStore(database, prefix: prefix);
  }

  final Map<String, Future<void>> _steps = {};

  /// [job] run after every earlier one queued for [peer] has ended
  Future<T> serial<T>(String peer, Future<T> Function() job) {
    final out = (_steps[peer] ?? Future<void>.value()).then((_) => job());
    final tail = out.then<void>((_) {}, onError: (_) {});
    _steps[peer] = tail;
    tail.whenComplete(() {
      if (identical(_steps[peer], tail)) _steps.remove(peer);
    });
    return out;
  }

  /// the card this store hands out, base64 json as before, now with the
  /// kyber prekey. an old app reading it finds what it knows and builds a
  /// classic session that this side refuses: both need the shim
  Future<String> makeBundleB64() async {
    final spk = lib.preKeyPublic(kLsSigned, (await signedPreKeyStore.load(1))!);
    final pk = lib.preKeyPublic(
      kLsOneTime,
      (await preKeyStore.load(invitePreKeyId))!,
    );
    final k = lib.preKeyPublic(
      kLsKyber,
      (await kyberPreKeyStore.load(kInviteKyberId))!,
    );
    return base64Encode(
      utf8.encode(
        jsonEncode({
          'registrationId': registrationId,
          'deviceId': 1,
          'preKeyId': pk.id,
          'preKeyPublic': base64Encode(pk.public),
          'signedPreKeyId': spk.id,
          'signedPreKeyPublic': base64Encode(spk.public),
          'signedPreKeySignature': base64Encode(spk.signature),
          'kyberPreKeyId': k.id,
          'kyberPreKeyPublic': base64Encode(k.public),
          'kyberPreKeySignature': base64Encode(k.signature),
          'identityKey': base64Encode(identity.public),
        }),
      ),
    );
  }

  /// a session with [peer] built from their card, in front of any held.
  /// the guard: only a pqxdh session with the pq ratchet is ever stored
  Future<void> processBundle(String peer, LsBundle bundle) =>
      serial(peer, () => _build(peer, bundle));

  Future<void> _build(String peer, LsBundle bundle) async {
    final (record, their) = lib.sessionFromBundle(
      identity,
      registrationId,
      await sessionStore.load(peer),
      bundle,
      _now(),
      pinned: identityStore.pinnedFor(peer),
    );
    _requirePq(record);
    await identityStore.saw(peer, their);
    await sessionStore.store(peer, record);
  }

  void _requirePq(Uint8List record) {
    final info = lib.sessionInfo(record);
    if (info.version < 4 || !info.pq) {
      throw ClassicRefused('a new session that is not pqxdh with spqr');
    }
  }

  Future<bool> hasSession(String peer) => sessionStore.contains(peer);

  Future<LsSessionInfo?> sessionInfo(String peer) async {
    final r = await sessionStore.load(peer);
    return r == null ? null : lib.sessionInfo(r);
  }

  /// [plain] sealed to [peer], as the wire carries it: the type byte, then
  /// the message, in base64. a session a restore brought back is not
  /// sealed on: one is started afresh from the card [afresh] hands over
  Future<String> encryptTo(
    String peer,
    String plain, {
    Future<LsBundle?> Function()? afresh,
    Future<bool> Function()? held,
    void Function()? keyMoved,
  }) => serial(peer, () async {
    if (held != null && await held()) throw KeyHeld(peer);
    if (await sealsOnRestored(peer)) {
      final card = afresh == null ? null : await afresh();
      if (card == null) throw StartingAfresh(peer);
      final before = await marksOf(peer);
      await _build(peer, card);
      dlog('signal: started afresh after a restore');
      if (before.movedTo(await marksOf(peer))) keyMoved?.call();
      if (held != null && await held()) throw KeyHeld(peer);
    }
    return _seal(peer, plain);
  });

  Future<String> _seal(String peer, String plain) async {
    final record = await sessionStore.load(peer);
    if (record == null) throw const LsError(LsError.noSession);
    final body = Uint8List.fromList(utf8.encode(padSeal(plain)));
    final LsSealed m;
    try {
      m = lib.encrypt(
        identity,
        registrationId,
        record,
        body,
        _now(),
        pinned: identityStore.pinnedFor(peer),
      );
    } finally {
      body.fillRange(0, body.length, 0);
    }
    final their = lib.sessionInfo(m.record).remoteIdentity;
    if (their != null) await identityStore.saw(peer, their);
    await sessionStore.store(peer, m.record);
    return base64Encode([m.type, ...m.message]);
  }

  /// [body] of [type] from [peer] opened. [check] sees the plaintext before
  /// anything is stored; one that throws leaves the store as it was, the
  /// prekeys unspent. nothing about the peer is written until the message
  /// has opened, so there is nothing to put back after one that does not
  Future<Uint8List> open(
    String peer,
    int type,
    Uint8List body, {
    void Function(Uint8List plain)? check,
  }) => serial(peer, () async {
    final held = await sessionStore.load(peer);
    final pinned = identityStore.pinnedFor(peer);
    if (type != kLsPreKey) {
      if (held == null) throw const LsError(LsError.noSession);
      final o = lib.decryptSignal(
        identity,
        registrationId,
        held,
        body,
        pinned: pinned,
      );
      check?.call(o.plaintext);
      await identityStore.saw(peer, o.identityKey);
      await sessionStore.store(peer, o.record);
      return o.plaintext;
    }
    final info = lib.preKeyMessageInfo(body);
    final known =
        held != null && lib.sessionInfo(held).holds(info.version, info.baseKey);
    final kyberId = info.kyberPreKeyId;
    if (!known &&
        kyberId != null &&
        await kyberPreKeyStore.wasUsed(kyberId, info.baseKey)) {
      throw const LsError(LsError.duplicate);
    }
    final pk = info.preKeyId;
    final o = lib.decryptPreKey(
      identity,
      registrationId,
      held,
      body,
      preKey: known || pk == null ? null : await preKeyStore.load(pk),
      signedPreKey: known
          ? null
          : await signedPreKeyStore.load(info.signedPreKeyId),
      kyberPreKey: known || kyberId == null
          ? null
          : await kyberPreKeyStore.load(kyberId),
      pinned: pinned,
    );
    if (!known) _requirePq(o.record);
    check?.call(o.plaintext);
    await identityStore.saw(peer, o.identityKey);
    await sessionStore.store(peer, o.record);
    final usedPk = o.usedPreKey;
    if (usedPk != null) await preKeyStore.remove(usedPk);
    final usedK = o.usedKyberPreKey;
    if (usedK != null) {
      await kyberPreKeyStore.markUsed(usedK, info.signedPreKeyId, info.baseKey);
    }
    return o.plaintext;
  });

  /// an opener's session filed for [peer]: one held already is kept as it
  /// runs; a new one goes in front of it, the states before it kept behind
  Future<void> keepOpenedSession(String peer, Uint8List record) =>
      serial<void>(peer, () async {
        final held = await sessionStore.load(peer);
        if (held == null) {
          await sessionStore.store(peer, record);
          return;
        }
        final cur = lib.sessionInfo(record).current;
        if (cur != null &&
            lib.sessionInfo(held).holds(cur.version, cur.baseKey)) {
          dlog('back-pair: an opener held already, the session kept');
          return;
        }
        await sessionStore.store(peer, lib.sessionPromote(held, record));
      });

  Future<IdentityMarks> marksOf(String peer) async {
    final k = await _db.query(
      '${_prefix}peer_identities',
      columns: ['identity_key'],
      where: 'address = ?',
      whereArgs: [peer],
      limit: 1,
    );
    final c = await _db.query(
      'contacts',
      columns: ['verified', 'key_changed'],
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    return IdentityMarks(
      k.isEmpty ? null : k.first['identity_key'] as List<int>,
      c.isEmpty ? null : c.first['verified'] as int?,
      c.isEmpty ? null : c.first['key_changed'] as int?,
    );
  }

  Future<void> restoreMarks(String peer, IdentityMarks m) async {
    final key = m.key;
    if (key == null) {
      await _db.delete(
        '${_prefix}peer_identities',
        where: 'address = ?',
        whereArgs: [peer],
      );
    } else {
      await _db.insert('${_prefix}peer_identities', {
        'address': peer,
        'identity_key': Uint8List.fromList(key),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (m.verified == null) return;
    await _db.update(
      'contacts',
      {'verified': m.verified, 'key_changed': m.keyChanged ?? 0},
      where: 'halo_id = ?',
      whereArgs: [peer],
    );
  }

  Future<bool> sealsOnRestored(String peer) async =>
      await _restoredBase(peer) != null;

  Future<String?> _restoredBase(String peer) async {
    if (_restored.isEmpty) return null;
    final record = await sessionStore.load(peer);
    if (record == null) return null;
    final base = _baseOf(lib.sessionInfo(record).current);
    return base != null && _restored.contains(base) ? base : null;
  }

  Future<bool> askDue(String peer, int now) async {
    final at = await askDueAt(peer);
    return at != null && now >= at;
  }

  static Duration askWait(int asks) => SignalSession.askWait(asks);

  Future<int?> askDueAt(String peer) async {
    final base = await _restoredBase(peer);
    if (base == null) return null;
    final a = _asks[base];
    if (a == null) return 0;
    return a[0] + askWait(a[1]).inMilliseconds;
  }

  Future<void> noteAsked(String peer, int now) async {
    final base = await _restoredBase(peer);
    if (base == null) return;
    _asks[base] = [now, (_asks[base]?[1] ?? 0) + 1];
    await _db.insert('${_prefix}signal_meta', {
      'k': _kRestoredAsks,
      'v': jsonEncode(_asks),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> dropRestoredWhenDone({
    bool Function(String peer)? leaveOut,
  }) async {
    if (_restored.isEmpty) return true;
    for (final (peer, record) in await sessionStore.all()) {
      if (leaveOut?.call(peer) ?? false) continue;
      try {
        final base = _baseOf(lib.sessionInfo(record).current);
        if (base != null && _restored.contains(base)) return false;
      } on LsError {
        // one that does not read is sealed on by no one
      }
    }
    await _db.delete(
      '${_prefix}signal_meta',
      where: 'k IN (?, ?, ?)',
      whereArgs: [_kRestored, _kRestoredAsks, _kRestoredFrom],
    );
    _restored = const {};
    _asks = {};
    _restoredFrom = null;
    dlog('signal: every restored session started afresh');
    return true;
  }

  Future<void> markRestored({int? from}) async {
    final keys = <String>{};
    for (final (_, record) in await LsSessionStore(
      _db,
      prefix: _prefix,
    ).all()) {
      try {
        final info = lib.sessionInfo(record);
        for (final s in [?info.current, ...info.archived]) {
          final b = _baseOf(s);
          if (b != null) keys.add(b);
        }
      } on LsError catch (e) {
        dlog('signal: a session not read ($e)');
      }
    }
    await _db.insert('${_prefix}signal_meta', {
      'k': _kRestored,
      'v': jsonEncode(keys.toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.delete(
      '${_prefix}signal_meta',
      where: 'k IN (?, ?)',
      whereArgs: [_kRestoredAsks, _kRestoredFrom],
    );
    if (from != null) {
      await _db.insert('${_prefix}signal_meta', {
        'k': _kRestoredFrom,
        'v': '$from',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    _restored = keys;
    _asks = {};
    _restoredFrom = from;
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

  Future<int?> _loadFrom() async {
    final rows = await _db.query(
      '${_prefix}signal_meta',
      where: 'k = ?',
      whereArgs: [_kRestoredFrom],
      limit: 1,
    );
    return rows.isEmpty ? null : int.tryParse('${rows.first['v']}');
  }

  Future<Map<String, List<int>>> _loadAsks() async {
    final rows = await _db.query(
      '${_prefix}signal_meta',
      where: 'k = ?',
      whereArgs: [_kRestoredAsks],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    try {
      final j = jsonDecode(rows.first['v'] as String) as Map;
      return {
        for (final e in j.entries)
          if (e.value case [final int at, final int n]) '${e.key}': [at, n],
      };
    } catch (_) {
      return {};
    }
  }

  /// a new invite prekey under the same id, and a new kyber one: every
  /// card handed out before names keys that are gone
  Future<void> rotateInvitePreKey() async {
    await preKeyStore.replaceInvite(lib.preKey(invitePreKeyId).record);
    await _newInviteKyber();
    dlog('signal: rotated the invite prekeys');
  }

  Future<int> _loadOrGenRegId(Database d, String prefix) async {
    final rows = await d.query(
      '${prefix}signal_meta',
      where: 'k = ?',
      whereArgs: ['regId'],
      limit: 1,
    );
    if (rows.isNotEmpty) return int.parse(rows.first['v'] as String);
    // as libsignal_protocol_dart made them: 1 to 16380
    final id = Random.secure().nextInt(16380) + 1;
    await d.insert('${prefix}signal_meta', {'k': 'regId', 'v': id.toString()});
    return id;
  }

  Future<String?> peerXPubHex(String peer) async {
    final raw = await identityStore.getIdentity(peer);
    if (raw == null) return null;
    final pub = raw.length == 33 ? raw.sublist(1) : raw;
    return pub.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// a card's prekey bundle as the shim takes it. a card without the kyber
/// prekey, as every 0.5.x phone hands out, is refused
LsBundle lsBundleOf(KryfoSignal lib, String bundleB64) {
  final j =
      jsonDecode(utf8.decode(base64Decode(bundleB64))) as Map<String, dynamic>;
  Uint8List? b(String k) {
    final v = j[k];
    return v is String ? base64Decode(v) : null;
  }

  if (b('kyberPreKeyPublic') == null || j['kyberPreKeyId'] is! int) {
    throw const ClassicRefused('a card without a kyber prekey');
  }
  try {
    return lib.bundleBuild(
      registrationId: j['registrationId'] as int,
      deviceId: j['deviceId'] as int,
      preKeyId: j['preKeyId'] as int?,
      preKey: b('preKeyPublic'),
      signedPreKeyId: j['signedPreKeyId'] as int,
      signedPreKey: b('signedPreKeyPublic')!,
      signedPreKeySignature: b('signedPreKeySignature')!,
      kyberPreKeyId: j['kyberPreKeyId'] as int,
      kyberPreKey: b('kyberPreKeyPublic'),
      kyberPreKeySignature: b('kyberPreKeySignature'),
      identityKey: b('identityKey')!,
    );
  } on LsError catch (e) {
    if (e.code == LsError.classic) {
      throw const ClassicRefused('a card without a kyber prekey');
    }
    rethrow;
  }
}

const _kRestored = 'restored_sessions';
const _kRestoredAsks = 'restored_asks';
const _kRestoredFrom = 'restored_from';

// the base key that names a session on both sides, as signal_session.dart
// writes it into the restore marks
String? _baseOf(LsState? s) =>
    s == null || s.baseKey.isEmpty ? null : base64Encode(s.baseKey);

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
