// SPDX-License-Identifier: GPL-3.0-or-later
// signal sessions over the libsignal shim (native/kryfo_signal). the same
// tables, record bytes and restore marks libsignal_protocol_dart kept up to
// 0.5.x, so a store a 0.5.x phone wrote goes on here. new sessions are
// pqxdh with the pq ratchet only: a bundle without a kyber prekey and a
// pre-pq opener are refused. sessions held from before go on as they are

import 'dart:convert';
import 'dart:math' show Random, min;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'dlog.dart';
import 'identities.dart';
import 'signal_ffi/kryfo_signal.dart';
import 'signal_stores.dart';
import 'wire_pad.dart';

/// a first contact without the post-quantum prekey, or a session that
/// would not be pqxdh: never built here
class ClassicRefused implements Exception {
  const ClassicRefused(this.why);
  final String why;
  @override
  String toString() => 'ClassicRefused: $why';
}

/// where a first contact's opener is opened before it is filed under a name
const kFirstContactSlot = '_pending_back_pair_';

class SignalSession {
  /// the store of identity [ident] (0 the main one) in the database it is
  /// opened on: every row it reads and writes is that identity's
  SignalSession([KryfoSignal? lib, this.ident = kMainIdent]) : _lib = lib;

  final int ident;

  // a meta key of this identity's: the main one's as before
  String _meta(String k) => ident == kMainIdent ? k : 'i$ident:$k';
  String get _kRestored => _meta(_kRestoredMeta);
  String get _kRestoredAsks => _meta(_kRestoredAsksMeta);
  String get _kRestoredFrom => _meta(_kRestoredFromMeta);

  KryfoSignal? _lib;
  // the platform's library, opened when the store is first used
  KryfoSignal get lib => _lib ??= KryfoSignal.shared;
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

  /// the database and table prefix this store writes in: DeviceSessions
  /// keeps its rows in the same tables and transactions
  Database get database => _db;
  String get tablePrefix => _prefix;
  // the base keys of the sessions a restore brought back. the phone the
  // file was made on went on sealing on them after it, so the peer has
  // spent their next message keys already: none is sealed on again (see
  // encryptTo). when each one's peer was last asked to start afresh, and
  // how many times, by the same base key: [at, n]. and when the file was
  // made, by its phone's clock
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

    // the v3 invite's keys went with the first v4 main invite's year: none
    // is made again (identity v4 2.3, R23)
    final legacy = !await _legacyGone();
    // a signed prekey the old library made reads here as it is
    final spk = legacy ? await signedPreKeyStore.load(1) : null;
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
    if (!spkOk && legacy) {
      final fresh = lib.signedPreKey(identity, 1, _now());
      await signedPreKeyStore.store(1, fresh.record);
      dlog('signal: generated signed prekey id=1');
    }

    // prekeys 0-9 topped up by the ids present, and the invite's own
    final have = (await preKeyStore.ids()).toSet();
    for (final id in [
      for (var i = 0; i < 10; i++) i,
      if (legacy) invitePreKeyId,
    ]) {
      if (have.contains(id)) continue;
      await preKeyStore.store(id, lib.preKey(id).record);
    }

    // the invite's kyber prekey: a last resort key, kept like the invite's
    // ec prekey, and made again when it no longer holds under this identity
    final k = legacy ? await kyberPreKeyStore.load(kInviteKyberId) : null;
    var kOk = !legacy;
    if (k != null) {
      try {
        final p = lib.preKeyPublic(kLsKyber, k);
        kOk = lib.verify(identity.public, p.public, p.signature);
      } on LsError catch (e) {
        dlog('signal: a kyber prekey that does not read ($e)');
      }
    }
    if (!kOk) await _newInviteKyber();
    // the identity's session prekeys: the dev chat's made name has none
    if (prefix.isEmpty) await keepSessionPreKeys();

    _ready = true;
    dlog('signal: bootstrapped on the shim (regId=$registrationId)');
  }

  /// how long a session prekey pair is used before the next use replaces
  /// it, and how long a replaced pair or a heal's kyber key still opens
  /// what was sealed to it: a wrap's life and a day
  static const kSessionKeyLife = Duration(days: 30);
  static const kSessionKeyGrace = Duration(days: 16);

  /// how long a linked device's bundle waits in its phone's pool at most
  /// (the engine's PoolMaxAge): its one-time kyber key lives that and the
  /// grace, so a bundle handed out on its last pool day still opens for 16
  static const kPoolMaxAge = Duration(days: 7);
  static const kPoolKyberLife = Duration(
    days: 7 + 16, // kPoolMaxAge + kSessionKeyGrace
  );

  /// the session prekeys were made or replaced: a linked device sends its
  /// phone the next last resort bundle (DeviceSessions.lastResortBundle)
  void Function()? onSessionPreKeys;

  // a prekey id of this identity's that is not taken: random, never 1 (the
  // main invite's) or 0
  Future<int> _freeId(Future<bool> Function(int id) taken) async {
    final r = Random.secure();
    for (;;) {
      final id = r.nextInt(0x7ffffffd) + 2;
      if (!await taken(id)) return id;
    }
  }

  Future<List<Map<String, Object?>>> _keyRows(String table, String use) =>
      _db.query(
        '$_prefix$table',
        columns: ['id', 'created_at', 'retired_at'],
        where: 'ident = ? AND use = ?',
        whereArgs: [ident, use],
      );

  /// the session prekeys this identity keeps: one session spk and one last
  /// resort session kyber, made with it when there are none; replaced pairs
  /// and heal kybers past their grace go, with every opener they took
  Future<void> keepSessionPreKeys({int? now}) async {
    final at = now ?? _now();
    final grace = kSessionKeyGrace.inMilliseconds;
    var live = false;
    for (final r in await _keyRows('signed_prekeys', kUseSession)) {
      final gone = r['retired_at'] as int?;
      if (gone == null) {
        live = true;
      } else if (at - gone >= grace) {
        await signedPreKeyStore.remove(r['id'] as int);
      }
    }
    var liveK = false;
    for (final r in await _keyRows('kyber_prekeys', kUseSession)) {
      final gone = r['retired_at'] as int?;
      if (gone == null) {
        liveK = true;
      } else if (at - gone >= grace) {
        await kyberPreKeyStore.remove(r['id'] as int);
      }
    }
    for (final r in await _keyRows('kyber_prekeys', kUseHeal)) {
      if (at - (r['created_at'] as int) >= grace) {
        await kyberPreKeyStore.remove(r['id'] as int);
      }
    }
    final poolLife = kPoolKyberLife.inMilliseconds;
    for (final r in await _keyRows('kyber_prekeys', kUsePool)) {
      if (at - (r['created_at'] as int) >= poolLife) {
        await kyberPreKeyStore.remove(r['id'] as int);
      }
    }
    if (!live || !liveK) await _newSessionPreKeys(at);
  }

  /// after a restore or a move: the session prekeys the file brought may
  /// have gone out from the old phone since, so a new pair is made now.
  /// the one it replaces still opens for its grace (identity v4 8)
  Future<void> replaceSessionPreKeys({int? now}) =>
      _newSessionPreKeys(now ?? _now());

  Future<void> _newSessionPreKeys(int at) async {
    final spkId = await _freeId(signedPreKeyStore.contains);
    final kId = await _freeId(kyberPreKeyStore.contains);
    final spk = lib.signedPreKey(identity, spkId, at);
    final k = lib.kyberPreKey(identity, kId, at);
    await _db.transaction((t) async {
      for (final table in const ['signed_prekeys', 'kyber_prekeys']) {
        await t.update(
          '$_prefix$table',
          {'retired_at': at},
          where: 'ident = ? AND use = ? AND retired_at IS NULL',
          whereArgs: [ident, kUseSession],
        );
      }
      await LsSignedPreKeyStore(
        t,
        prefix: _prefix,
        ident: ident,
      ).store(spkId, spk.record, use: kUseSession, createdAt: at);
      await LsKyberPreKeyStore(
        t,
        prefix: _prefix,
        ident: ident,
      ).store(kId, k.record, lastResort: true, use: kUseSession, createdAt: at);
    });
    dlog('signal: made session prekeys');
    onSessionPreKeys?.call();
  }

  /// the session prekeys a heal or a device bundle names now. a pair 30
  /// days old is replaced on this use; the one it replaces still opens
  /// for 16 days. rotation shows nowhere on the wire
  Future<({int signedId, int kyberId})> sessionPreKeysForUse({int? now}) async {
    final at = now ?? _now();
    await keepSessionPreKeys(now: at);
    Map<String, Object?>? cur(List<Map<String, Object?>> rows) {
      for (final r in rows) {
        if (r['retired_at'] == null) return r;
      }
      return null;
    }

    var s = cur(await _keyRows('signed_prekeys', kUseSession))!;
    var k = cur(await _keyRows('kyber_prekeys', kUseSession))!;
    final life = kSessionKeyLife.inMilliseconds;
    if (at - (s['created_at'] as int) >= life ||
        at - (k['created_at'] as int) >= life) {
      await _newSessionPreKeys(at);
      s = cur(await _keyRows('signed_prekeys', kUseSession))!;
      k = cur(await _keyRows('kyber_prekeys', kUseSession))!;
    }
    return (signedId: s['id'] as int, kyberId: k['id'] as int);
  }

  /// a one-time kyber prekey for one heal: gone when the opener built on
  /// it opens, or 16 days after it was made
  Future<int> makeHealKyber({int? now}) => _oneTimeKyber(kUseHeal, now);

  /// a one-time kyber prekey for a device bundle in the phone's pool: gone
  /// when the opener built on it opens, or kPoolKyberLife after it was made
  Future<int> makePoolKyber({int? now}) => _oneTimeKyber(kUsePool, now);

  Future<int> _oneTimeKyber(String use, int? now) async {
    final at = now ?? _now();
    final id = await _freeId(kyberPreKeyStore.contains);
    await kyberPreKeyStore.store(
      id,
      lib.kyberPreKey(identity, id, at).record,
      use: use,
      createdAt: at,
    );
    return id;
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
    final mine = [ident];
    await database.delete(
      '${prefix}signed_prekeys',
      where: 'ident = ?',
      whereArgs: mine,
    );
    await database.delete(
      '${prefix}prekeys',
      where: 'ident = ? AND id = ?',
      whereArgs: [ident, invitePreKeyId],
    );
    for (final t in const ['kyber_prekeys', 'kyber_used', 'opener_reads']) {
      await database.delete('$prefix$t', where: 'ident = ?', whereArgs: mine);
    }
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
    registrationId = prefix.isEmpty
        ? await _identityRegId(database, xPrivBytes)
        : await _loadOrGenRegId(database, prefix);
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
      ident: ident,
    );
    preKeyStore = LsPreKeyStore(database, prefix: prefix, ident: ident);
    sessionStore = LsSessionStore(database, prefix: prefix, ident: ident);
    signedPreKeyStore = LsSignedPreKeyStore(
      database,
      prefix: prefix,
      ident: ident,
    );
    kyberPreKeyStore = LsKyberPreKeyStore(
      database,
      prefix: prefix,
      ident: ident,
    );
  }

  final Map<String, Future<void>> _steps = {};

  // openers read again in the first-contact slot, not marked read until
  // filed: each read's fingerprint (and its kyber id) by the record it put
  // in the slot, so two at once never stand for each other
  final Map<String, (int, Uint8List)> _slotReads = {};

  static String _recordKey(Uint8List record) =>
      base64Encode(sha256.convert(record).bytes);

  // peers a frame waits on: too big for an opener, it goes once they answer
  final Set<String> _awaiting = {};

  // the session each peer had a post-quantum opener sealed on, by base key
  final Map<String, String> _openerOut = {};

  /// told when a frame waits for [peer]'s answer on a session nothing has
  /// gone out on yet: a small opener has to go first
  void Function(String peer)? onStarterNeeded;

  /// told when an opener from [peer] built a new session here under their
  /// own name: a rebuilt or restarted one, which an answer settles for them
  void Function(String peer)? onNewSession;

  /// told when [peer]'s first message opened on a session a frame was
  /// waiting on: what waited goes now
  void Function(String peer)? onAnswered;

  /// told when a message from [peer] opened on a post-quantum state of a
  /// record that still holds classic ones: their side of a pq restart is
  /// done (identity v4 11 step 6). told on each, until the drop
  void Function(String peer)? onPqOver;

  /// asked before a seal that would be an opener: true when one went
  /// already to an address that hears only the first (a one-time invite),
  /// so this one waits for their answer
  Future<bool> Function(String peer)? holdOpener;

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
  /// the guard: only a pqxdh session with the pq ratchet is ever stored.
  /// [also] is written in the session's own transaction (a pair's seed):
  /// both are kept or neither
  Future<void> processBundle(
    String peer,
    LsBundle bundle, {
    Future<void> Function(Transaction t)? also,
  }) => serial(peer, () => _build(peer, bundle, also: also));

  // [record] kept for [peer], and [also] with it in one transaction
  Future<void> _storeWith(
    String peer,
    Uint8List record,
    Future<void> Function(Transaction t)? also,
  ) => also == null
      ? sessionStore.store(peer, record)
      : _db.transaction((t) async {
          await LsSessionStore(
            t,
            prefix: _prefix,
            ident: ident,
          ).store(peer, record);
          await also(t);
        });

  Future<void> _build(
    String peer,
    LsBundle bundle, {
    Future<void> Function(Transaction t)? also,
  }) async {
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
    await _storeWith(peer, record, also);
  }

  void _requirePq(Uint8List record) {
    final info = lib.sessionInfo(record);
    if (info.version < 4 || !info.pq) {
      throw ClassicRefused('a new session that is not pqxdh with spqr');
    }
  }

  Future<bool> hasSession(String peer) => sessionStore.contains(peer);

  /// a session with [peer] that they have answered on: a seal on it is a
  /// plain whisper message, never an opener. a trial seal, kept nowhere
  Future<bool> settled(String peer) async {
    final record = await sessionStore.load(peer);
    if (record == null) return false;
    try {
      final m = lib.encrypt(
        identity,
        registrationId,
        record,
        const [0],
        _now(),
        pinned: identityStore.pinnedFor(peer),
      );
      return m.type == kLsWhisper;
    } on LsError {
      return false;
    }
  }

  /// the identity [peer]'s current session runs on, null with none
  Future<Uint8List?> sessionIdentity(String peer) async {
    final r = await sessionStore.load(peer);
    if (r == null) return null;
    try {
      return lib.sessionInfo(r).remoteIdentity;
    } on LsError {
      return null;
    }
  }

  /// a session with [peer] built from [bundle] alone, in place of whatever
  /// is held: a held one goes only once the new one is built
  Future<void> rebuild(String peer, LsBundle bundle) => serial(peer, () async {
    final (record, their) = lib.sessionFromBundle(
      identity,
      registrationId,
      null,
      bundle,
      _now(),
      pinned: identityStore.pinnedFor(peer),
    );
    _requirePq(record);
    await identityStore.saw(peer, their);
    await sessionStore.store(peer, record);
  });

  Future<LsSessionInfo?> sessionInfo(String peer) async {
    final r = await sessionStore.load(peer);
    return r == null ? null : lib.sessionInfo(r);
  }

  /// the seal size [plain] takes to [peer] now, so a burst of copies of
  /// one message can be filled to one size: a plain message's own, the
  /// second size for a post-quantum opener (a restored session starts one),
  /// null when nothing is held or the frame is too big for an opener
  Future<int?> sealSize(String peer, String plain) => serial(peer, () async {
    final record = await sessionStore.load(peer);
    if (record == null) return null;
    final afresh = await sealsOnRestored(peer);
    final opener =
        afresh ||
        lib
                .encrypt(
                  identity,
                  registrationId,
                  record,
                  const [0],
                  _now(),
                  pinned: identityStore.pinnedFor(peer),
                )
                .type ==
            kLsPreKey;
    if (opener && (afresh || lib.sessionInfo(record).version >= 4)) {
      return padSealOpener(plain) == null ? null : kSealSizes[1];
    }
    return utf8Length(padSeal(plain));
  });

  /// [plain] sealed to [peer], as the wire carries it: the type byte, then
  /// the message, in base64. a session a restore brought back is not
  /// sealed on: one is started afresh from the card [afresh] hands over.
  /// [size], a burst's (sealSize and DeviceSessions.burstSize), fills a
  /// plain message to it; a post-quantum opener goes only when it is the
  /// second size and waits for the answer otherwise
  Future<String> encryptTo(
    String peer,
    String plain, {
    Future<LsBundle?> Function()? afresh,
    Future<bool> Function()? held,
    void Function()? keyMoved,
    // only on a session that is past its opener: never one to start one
    bool onlySettled = false,
    int? size,
  }) => serial(peer, () async {
    // asked in the lane, right before the seal: a key that came in a frame
    // opened ahead of this one is the key this one would go to
    if (held != null && await held()) throw KeyHeld(peer);
    if (onlySettled && await sealsOnRestored(peer)) throw NotSettled(peer);
    if (await sealsOnRestored(peer)) {
      final card = afresh == null ? null : await afresh();
      if (card == null) throw StartingAfresh(peer);
      final before = await marksOf(peer);
      await _build(peer, card);
      dlog('signal: started afresh after a restore');
      if (before.movedTo(await marksOf(peer))) keyMoved?.call();
      // the card may name another key than the one checked above
      if (held != null && await held()) throw KeyHeld(peer);
    }
    return _seal(peer, plain, onlySettled: onlySettled, size: size);
  });

  // [onlySettled]: a seal that comes out as an opener is thrown away, and
  // nothing of it is stored. [size]: the burst's, null for the frame's own
  Future<String> _seal(
    String peer,
    String plain, {
    bool onlySettled = false,
    int? size,
  }) async {
    final record = await sessionStore.load(peer);
    if (record == null) {
      if (onlySettled) throw NotSettled(peer);
      throw const LsError(LsError.noSession);
    }
    final pinned = identityStore.pinnedFor(peer);
    // a trial seal first, kept nowhere: whether this one goes out as an
    // opener, which is filled to its own size
    final opener =
        lib
            .encrypt(
              identity,
              registrationId,
              record,
              const [0],
              _now(),
              pinned: pinned,
            )
            .type ==
        kLsPreKey;
    if (onlySettled && opener) throw NotSettled(peer);
    // the opener went to an address that is gone now: the rest waits for
    // their answer, which opens the session for plain messages
    if (opener && holdOpener != null && await holdOpener!(peer)) {
      _awaiting.add(peer);
      throw WaitsForAnswer(peer);
    }
    final String padded;
    if (opener && lib.sessionInfo(record).version >= 4) {
      // a post-quantum opener carries the kyber ciphertext: filled smaller,
      // so it lands where a plain message does. one too big for that waits
      // for their first answer, then goes plain
      // in a burst only at the second size, where an opener lands
      final o = size == null || size == kSealSizes[1]
          ? padSealOpener(plain)
          : null;
      final base = _baseOf(lib.sessionInfo(record).current);
      if (o == null) {
        _awaiting.add(peer);
        // nothing has gone on this session yet: a small opener goes first,
        // or nobody hears of it and no answer can come
        if (base != null && _openerOut[peer] != base) {
          onStarterNeeded?.call(peer);
        }
        throw WaitsForAnswer(peer);
      }
      if (base != null) _openerOut[peer] = base;
      padded = o;
    } else {
      padded = size == null ? padSeal(plain) : padSealTo(plain, size);
    }
    final body = Uint8List.fromList(utf8.encode(padded));
    final LsSealed m;
    try {
      m = lib.encrypt(
        identity,
        registrationId,
        record,
        body,
        _now(),
        pinned: pinned,
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
  /// [moved] is told when the key it opened under replaced another held
  /// for [peer]. [opened] is told, once it opened and was stored, the
  /// remote identity libsignal's decrypt returned and the record it left
  Future<Uint8List> open(
    String peer,
    int type,
    Uint8List body, {
    void Function(Uint8List plain)? check,
    void Function()? moved,
    void Function(Uint8List remote, Uint8List record)? opened,
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
      if (await identityStore.saw(peer, o.identityKey)) moved?.call();
      await sessionStore.store(peer, _pqFloor(peer, held, o.record));
      _answered(peer);
      opened?.call(o.identityKey, o.record);
      return o.plaintext;
    }
    final info = lib.preKeyMessageInfo(body);
    final known =
        held != null && lib.sessionInfo(held).holds(info.version, info.baseKey);
    final kyberId = info.kyberPreKeyId;
    // one opener opens once, on whichever path it comes back
    // every opener read strictly first, the classic ones too
    final whole = _fingerprint(info, body);
    final print = kyberId == null ? null : whole;
    if (print != null && await kyberPreKeyStore.wasRead(kyberId!, print)) {
      throw const LsError(LsError.duplicate);
    }
    if (!known &&
        kyberId != null &&
        await kyberPreKeyStore.wasUsed(kyberId, info.baseKey)) {
      // another opener of a session this store built: read only for the
      // name holding it, or in the first-contact slot (filed there and
      // then only under that name, see keepOpenedSession)
      final holder = await _holder(info.version, info.baseKey);
      if (holder == null || (peer != holder.$1 && peer != kFirstContactSlot)) {
        throw const LsError(LsError.duplicate);
      }
      return _openerAgain(
        peer,
        info,
        print!,
        body,
        pinned,
        check,
        holder.$2,
        keep: peer == kFirstContactSlot,
        opened: opened,
      );
    }
    final pk = info.preKeyId;
    final LsOpened o;
    try {
      o = lib.decryptPreKey(
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
    } on LsError catch (e) {
      if (!known || print == null || e.code != LsError.message) rethrow;
      // the state it names is held here, the chain it was sealed on gone
      // from the record (libsignal keeps five). never read before: the
      // fingerprint says so
      return _openerAgain(
        peer,
        info,
        print,
        body,
        pinned,
        check,
        await identityStore.getIdentity(peer) ??
            lib.sessionInfo(held).remoteIdentity,
        opened: opened,
      );
    }
    if (!known) _requirePq(o.record);
    check?.call(o.plaintext);
    final kept = peer == kFirstContactSlot
        ? o.record
        : _pqFloor(peer, held, o.record);
    var changed = false;
    // the record, the key it runs on and every key it spent, in one write
    await _db.transaction((txn) async {
      final ids = LsIdentityStore(
        txn,
        identity,
        registrationId,
        prefix: _prefix,
        ident: ident,
      );
      final kyber = LsKyberPreKeyStore(txn, prefix: _prefix, ident: ident);
      changed = await ids.saw(peer, o.identityKey);
      await LsSessionStore(
        txn,
        prefix: _prefix,
        ident: ident,
      ).store(peer, kept);
      final usedPk = o.usedPreKey;
      if (usedPk != null) {
        await LsPreKeyStore(txn, prefix: _prefix, ident: ident).remove(usedPk);
      }
      final usedK = o.usedKyberPreKey;
      if (usedK != null) {
        await kyber.markUsed(usedK, info.signedPreKeyId, info.baseKey);
      }
      if (print != null) await kyber.markRead(kyberId!, print);
    });
    if (changed) moved?.call();
    _answered(peer);
    if (!known && held != null && peer != kFirstContactSlot) {
      onNewSession?.call(peer);
    }
    opened?.call(o.identityKey, o.record);
    return o.plaintext;
  });

  void _answered(String peer) {
    if (_awaiting.remove(peer)) onAnswered?.call(peer);
  }

  // [opened], the record a message from [peer] just opened on, kept on
  // its post-quantum state. libsignal puts an archived state in front when
  // a message opens on it, and archives the one it moves without its
  // unanswered opener: a classic message still on its way after a pq
  // restart would make every later seal classic, or plain on a pq state
  // the peer never heard of. the state [held] had in front goes back, as
  // it was, the classic one behind it. a record with no pq state (every
  // chat with a 0.5.x phone) is kept as it opened
  Uint8List _pqFloor(String peer, Uint8List? held, Uint8List opened) {
    final now = lib.sessionInfo(opened);
    final cur = now.current;
    if (cur == null) return opened;
    if (cur.version >= 4) {
      if (now.archived.any((s) => s.version < 4)) onPqOver?.call(peer);
      return opened;
    }
    if (held == null) return opened;
    final was = lib.sessionInfo(held).current;
    if (was == null || was.version < 4) return opened;
    dlog('signal: a classic message after the pq restart, pq kept in front');
    return lib.sessionPromote(opened, held);
  }

  /// [peer]'s held classic session started again on [bundle], the KDB1
  /// their phone sent inside it (identity v4 11 step 5): a pqxdh session
  /// on the identity the held one runs on, in front of it, the classic
  /// state archived so what was sealed on it still opens. the next seal is
  /// its opener. false when nothing is held, or the held one runs on
  /// another key
  Future<bool> restartFrom(String peer, LsBundle bundle) =>
      serial(peer, () async {
        final held = await sessionStore.load(peer);
        if (held == null) return false;
        final their = lib.sessionInfo(held).remoteIdentity;
        if (their == null || !_eq(their, bundle.identityKey)) return false;
        final (record, key) = lib.sessionFromBundle(
          identity,
          registrationId,
          held,
          bundle,
          _now(),
          pinned: their,
        );
        _requirePq(record);
        if (!_eq(key, their)) throw const LsError(LsError.untrusted);
        await sessionStore.store(peer, record);
        dlog('signal: a classic session started again on pq');
        return true;
      });

  /// [peer]'s record without its classic states, once their side of the pq
  /// restart is 15 days done (identity v4 11 step 6): what was sealed on
  /// them has left every relay. how many went, or null when the record is
  /// kept as it is (none held, a pq state not in front, or an opener of it
  /// not answered yet: the shim refuses those, and the next try asks again)
  Future<int?> dropClassic(String peer) => serial(peer, () async {
    final held = await sessionStore.load(peer);
    if (held == null) return null;
    try {
      final (record, n) = lib.sessionDropBelow(held, 4);
      if (n > 0) await sessionStore.store(peer, record);
      return n;
    } on LsError catch (e) {
      dlog('signal: classic states kept for now (${e.code})');
      return null;
    }
  });

  // what an opener is, by what its mac and its keys cover: the base key and
  // the message inside it. the fields around them (registration id, prekey
  // ids) are not authenticated, so a copy with them changed is the same one
  Uint8List _fingerprint(LsPreKeyMessageInfo info, Uint8List body) {
    final outer = strictOpener(body);
    // the same keys libsignal read, or the two reads differ
    if (!_eq(outer.baseKey, info.baseKey) ||
        !_eq(outer.identity, info.identityKey)) {
      throw const LsError(LsError.message);
    }
    return Uint8List.fromList(
      sha256.convert([...outer.baseKey, ...outer.message]).bytes,
    );
  }

  // an opener never read before, of a session held here, read on its own
  // from the keys it names: nothing of its state is kept outside the
  // first-contact slot, and no key is spent. its fingerprint is marked, so
  // it opens once. [owner] is the identity the session holding it runs on:
  // the opener must be on the same one
  Future<Uint8List> _openerAgain(
    String peer,
    LsPreKeyMessageInfo info,
    Uint8List print,
    Uint8List body,
    Uint8List? pinned,
    void Function(Uint8List plain)? check,
    Uint8List? owner, {
    bool keep = false,
    void Function(Uint8List remote, Uint8List record)? opened,
  }) async {
    final pk = info.preKeyId;
    final kyberId = info.kyberPreKeyId!;
    final spk = await signedPreKeyStore.load(info.signedPreKeyId);
    final kyber = await kyberPreKeyStore.load(kyberId);
    if (spk == null || kyber == null) throw const LsError(LsError.noPreKey);
    final o = lib.decryptPreKey(
      identity,
      registrationId,
      null,
      body,
      preKey: pk == null ? null : await preKeyStore.load(pk),
      signedPreKey: spk,
      kyberPreKey: kyber,
      pinned: pinned,
    );
    _requirePq(o.record);
    if (owner == null || !_eq(owner, o.identityKey)) {
      throw const LsError(LsError.untrusted);
    }
    check?.call(o.plaintext);
    await _db.transaction((txn) async {
      if (keep) {
        await LsIdentityStore(
          txn,
          identity,
          registrationId,
          prefix: _prefix,
          ident: ident,
        ).saw(peer, o.identityKey);
        await LsSessionStore(
          txn,
          prefix: _prefix,
          ident: ident,
        ).store(peer, o.record);
        // marked read once it is filed under the name holding it
        // (keepOpenedSession): one turned away there can come again
        _slotReads[_recordKey(o.record)] = (kyberId, print);
        while (_slotReads.length > 64) {
          _slotReads.remove(_slotReads.keys.first);
        }
      } else {
        await LsKyberPreKeyStore(
          txn,
          prefix: _prefix,
          ident: ident,
        ).markRead(kyberId, print);
      }
    });
    dlog('signal: an opener of a held session read on its own');
    opened?.call(o.identityKey, o.record);
    return o.plaintext;
  }

  // the name holding a state of [version] on [baseKey], and the identity
  // its session runs on. the first-contact slot holds nothing for this
  Future<(String, Uint8List?)?> _holder(int version, List<int> baseKey) async {
    for (final (name, r) in await sessionStore.all()) {
      if (name == kFirstContactSlot) continue;
      try {
        final info = lib.sessionInfo(r);
        if (!info.holds(version, baseKey)) continue;
        return (
          name,
          await identityStore.getIdentity(name) ?? info.remoteIdentity,
        );
      } on LsError {
        // a record that does not read holds nothing
      }
    }
    return null;
  }

  /// an opener's session filed for [peer]: one held already is kept as it
  /// runs; a new one goes in front of it, the states before it kept behind
  /// a state another name holds is never filed under [peer] as well: that
  /// throws StateError, and nothing is written
  Future<void> keepOpenedSession(
    String peer,
    Uint8List record, {
    Future<void> Function(Transaction t)? also,
  }) => serial<void>(peer, () async {
    final cur0 = lib.sessionInfo(record).current;
    if (cur0 != null) {
      final h = await _holder(cur0.version, cur0.baseKey);
      if (h != null && h.$1 != peer) {
        throw StateError('signal: that session is held under another name');
      }
    }
    final held = await sessionStore.load(peer);
    if (held == null) {
      await _storeWith(peer, record, also);
      return;
    }
    final cur = lib.sessionInfo(record).current;
    if (cur != null && lib.sessionInfo(held).holds(cur.version, cur.baseKey)) {
      // a slot re-read filed where its session is: read now, for good
      final r = _slotReads.remove(_recordKey(record));
      if (r != null) await kyberPreKeyStore.markRead(r.$1, r.$2);
      if (also != null) await _db.transaction(also);
      dlog('back-pair: an opener held already, the session kept');
      return;
    }
    await _storeWith(peer, lib.sessionPromote(held, record), also);
  });

  Future<IdentityMarks> marksOf(String peer) async {
    final k = await _db.query(
      '${_prefix}peer_identities',
      columns: ['identity_key'],
      where: 'ident = ? AND address = ?',
      whereArgs: [ident, peer],
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
        where: 'ident = ? AND address = ?',
        whereArgs: [ident, peer],
      );
    } else {
      await _db.insert('${_prefix}peer_identities', {
        'ident': ident,
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

  /// how long after the [asks]th ask the next is due: soon at first, as
  /// someone restoring in the same hour may not have their card out yet
  /// when the first goes, then an hour doubling to a week
  static Duration askWait(int asks) => switch (asks) {
    <= 1 => const Duration(minutes: 10),
    2 => const Duration(minutes: 30),
    _ => Duration(
      milliseconds: min(
        const Duration(hours: 1).inMilliseconds << min(asks - 3, 8),
        const Duration(days: 7).inMilliseconds,
      ),
    ),
  };

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
      ident: ident,
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

  /// the keys of v4 invite [inviteId] (identity v4 2.1): a signed prekey
  /// and a last resort kyber prekey with random ids, named by the invite,
  /// and with [ec] a one-time ec prekey (a one-time invite's). they live
  /// and go with the invite, never with the session prekeys
  Future<({LsPreKey spk, LsPreKey kyber, LsPreKey? ec})> makeInviteKeys(
    String inviteId, {
    bool ec = false,
    int? now,
  }) async {
    final at = now ?? _now();
    final spkId = await _freeId(signedPreKeyStore.contains);
    final kId = await _freeId(kyberPreKeyStore.contains);
    final spk = lib.signedPreKey(identity, spkId, at);
    final k = lib.kyberPreKey(identity, kId, at);
    LsPreKey? e;
    if (ec) {
      // never one of the old ids: 0-9 and the v3 invite's
      final id = await _freeId(
        (id) async =>
            id < 10 || id == invitePreKeyId || await preKeyStore.contains(id),
      );
      e = lib.preKey(id);
    }
    await _db.transaction((t) async {
      await LsSignedPreKeyStore(
        t,
        prefix: _prefix,
        ident: ident,
      ).store(spkId, spk.record, inviteId: inviteId, createdAt: at);
      await LsKyberPreKeyStore(t, prefix: _prefix, ident: ident).store(
        kId,
        k.record,
        lastResort: true,
        inviteId: inviteId,
        createdAt: at,
      );
      if (e != null) {
        await LsPreKeyStore(
          t,
          prefix: _prefix,
          ident: ident,
        ).store(e.id, e.record);
      }
    });
    return (spk: spk, kyber: k, ec: e);
  }

  /// the keys an invite named, gone with every opener read on its kyber
  /// key: nothing sealed to them opens here again (R23)
  Future<void> dropInviteKeys({
    required int? spkId,
    required int? kyberId,
    required int? ecId,
  }) => _db.transaction((t) async {
    if (spkId != null) {
      await LsSignedPreKeyStore(t, prefix: _prefix, ident: ident).remove(spkId);
    }
    if (kyberId != null) {
      await LsKyberPreKeyStore(
        t,
        prefix: _prefix,
        ident: ident,
      ).remove(kyberId);
    }
    if (ecId != null) {
      await LsPreKeyStore(t, prefix: _prefix, ident: ident).remove(ecId);
    }
  });

  static const _kLegacyGone = 'v3_invite_gone';

  Future<bool> _legacyGone() async => (await _db.query(
    '${_prefix}signal_meta',
    where: 'k = ?',
    whereArgs: [_meta(_kLegacyGone)],
    limit: 1,
  )).isNotEmpty;

  /// the v3 invite's keys (signed prekey 1, kyber 1, ec 999999) gone with
  /// every opener read on them, and never made again. true when they went
  /// now
  Future<bool> dropLegacyInviteKeys() async {
    if (await _legacyGone()) return false;
    await _db.transaction((t) async {
      await LsSignedPreKeyStore(t, prefix: _prefix, ident: ident).remove(1);
      await LsKyberPreKeyStore(
        t,
        prefix: _prefix,
        ident: ident,
      ).remove(kInviteKyberId);
      await LsPreKeyStore(t, prefix: _prefix, ident: ident).dropInvite();
      await t.insert('${_prefix}signal_meta', {
        'k': _meta(_kLegacyGone),
        'v': '${_now()}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    dlog('signal: the v3 invite keys went');
    return true;
  }

  /// a new invite prekey under the same id, and a new kyber one: every
  /// card handed out before names keys that are gone. none once the v3
  /// invite's keys went: they never come back. true when they were made
  Future<bool> rotateInvitePreKey() async {
    if (await _legacyGone()) return false;
    await preKeyStore.replaceInvite(lib.preKey(invitePreKeyId).record);
    await _newInviteKyber();
    dlog('signal: rotated the invite prekeys');
    return true;
  }

  // the registration id of this store's identity row. the main one's row
  // is made from the key and the id the store gave out so far when it has
  // none, or another key; any other identity must have its row
  Future<int> _identityRegId(Database d, Uint8List xPriv) async {
    final row = await identityRow(d, ident);
    if (ident != kMainIdent) {
      if (row == null || !_eq(row.xPriv, xPriv)) {
        throw StateError('signal: no row for identity $ident');
      }
      return row.regId;
    }
    if (row != null && _eq(row.xPriv, xPriv)) {
      // the old layer's reads find the same id
      await d.insert('signal_meta', {
        'k': 'regId',
        'v': '${row.regId}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return row.regId;
    }
    final id = await _loadOrGenRegId(d, '');
    await putMainIdentity(d, xPriv, regId: id);
    return id;
  }

  /// opens the store of [ident] from its row: its own key and registration
  /// id, its own prekeys
  Future<void> bootstrapIdentity(Database database) async {
    final row = await identityRow(database, ident);
    if (row == null) throw StateError('signal: no row for identity $ident');
    await bootstrap(
      database: database,
      xPubBytes: lib.identityFromPrivate(row.xPriv).public.sublist(1),
      xPrivBytes: row.xPriv,
    );
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

  /// the x key held for [peer], null with none, or before the store is
  /// open
  Future<String?> peerXPubHex(String peer) async {
    if (!_ready) return null;
    try {
      final raw = await identityStore.getIdentity(peer);
      if (raw == null) return null;
      final pub = raw.length == 33 ? raw.sublist(1) : raw;
      return pub.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      dlog('peerXPubHex: ${e.runtimeType}');
      return null;
    }
  }
}

/// an opener's protobuf (a prekey message without the wire's type byte),
/// read the one way libsignal could read it too: after the version byte,
/// each field at most once, only the eight fields an opener has, each with
/// its wire type, every varint in its shortest form and the ids under 2^32,
/// nothing left over. libsignal keeps the last copy of a field, so a second
/// one would make the opener mean another thing to a reader of the first:
/// any of that is refused (KS_ERR_MESSAGE) before anything is decrypted
({Uint8List message, Uint8List baseKey, Uint8List identity}) strictOpener(
  Uint8List opener,
) {
  Never bad() => throw const LsError(LsError.message);
  if (opener.length < 2) bad();
  var at = 1;
  int varint() {
    var v = 0;
    for (var shift = 0; shift < 64; shift += 7) {
      if (at >= opener.length) bad();
      final x = opener[at++];
      v |= (x & 0x7f) << shift;
      if (x < 0x80) {
        // the shortest form: no last byte of zero after the first
        if (x == 0 && shift > 0) bad();
        return v;
      }
    }
    bad();
  }

  const ids = {1, 5, 6, 7};
  const bytes = {2, 3, 4, 8};
  final seen = <int>{};
  final got = <int, Uint8List>{};
  while (at < opener.length) {
    final tag = varint();
    final field = tag >> 3;
    final kind = tag & 7;
    if (!seen.add(field)) bad();
    if (ids.contains(field)) {
      if (kind != 0) bad();
      // past 2^63 a varint reads negative here
      final v = varint();
      if (v < 0 || v > 0xffffffff) bad();
    } else if (bytes.contains(field)) {
      if (kind != 2) bad();
      final n = varint();
      if (n < 0 || n > opener.length - at) bad();
      got[field] = Uint8List.sublistView(opener, at, at + n);
      at += n;
    } else {
      bad();
    }
  }
  final message = got[4], baseKey = got[2], identity = got[3];
  if (message == null || baseKey == null || identity == null) bad();
  return (message: message, baseKey: baseKey, identity: identity);
}

/// the x25519 public key of [private32], as the app's identities derive it
Uint8List xPublicOf(List<int> private32) =>
    KryfoSignal.shared.identityFromPrivate(private32).public.sublist(1);

/// [bundleB64] as the shim takes it, from the platform's library
LsBundle cardBundle(String bundleB64) =>
    lsBundleOf(KryfoSignal.shared, bundleB64);

/// libsignal's prekey signature by [identityKey] over [public]
bool preKeySigned(List<int> identityKey, List<int> public, List<int> sig) =>
    KryfoSignal.shared.verify(identityKey, public, sig);

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

const _kRestoredMeta = 'restored_sessions';
const _kRestoredAsksMeta = 'restored_asks';
const _kRestoredFromMeta = 'restored_from';

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

/// the pref a restore leaves for the next start, which then marks the
/// sessions it brought back as the store opens (bootstrap, restored)
const kSessionsRestoredPref = 'signal.restored';

/// and when the backup was made, which an ask to start afresh carries
const kRestoredFromPref = 'signal.restored_from';

// a peer's key and their contact's marks as they were before a step
class IdentityMarks {
  const IdentityMarks(this.key, this.verified, this.keyChanged);
  final List<int>? key;
  final int? verified;
  final int? keyChanged;

  // another key than this one is held now
  bool movedTo(IdentityMarks now) {
    final a = key;
    final b = now.key;
    if (a == null || b == null) return false;
    return !_eq(a, b);
  }
}

// someone verified under one key who holds another now: nothing is sealed
// for them until the new number is checked or the new key accepted
class KeyHeld implements Exception {
  KeyHeld(this.peer);
  final String peer;
  @override
  String toString() => 'KeyHeld: their key moved since it was verified';
}

/// a seal asked only on a settled session found none: no session, one
/// their side has not answered on yet, or one a restore brought back
class NotSettled implements Exception {
  NotSettled(this.peer);
  final String peer;
  @override
  String toString() => 'NotSettled: no answered session';
}

/// a frame too big for a post-quantum opener: it waits in the outbox for
/// [peer]'s first answer on the session, then goes as a plain message. the
/// outbox holds it as it holds one waiting for a card
class WaitsForAnswer extends StartingAfresh {
  WaitsForAnswer(super.peer);
  @override
  String toString() => 'WaitsForAnswer: too big for an opener';
}

/// a seal to [peer] waits for a session started afresh: the one held came
/// back with a restore, and no card of theirs is kept to start one from
class StartingAfresh implements Exception {
  StartingAfresh(this.peer);
  final String peer;
  @override
  String toString() => 'StartingAfresh: waiting for their card';
}

final signalSession = SignalSession();
