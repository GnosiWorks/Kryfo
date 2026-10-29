// SPDX-License-Identifier: GPL-3.0-or-later
// v4 invites in the app (identity v4 2.3, 3.1): the main invite kept and
// listened on, the link and qr handed out, a first contact made from a
// link's bundle, and an opener at one of my invites checked before it opens

part of '../main.dart';

const _b32 = 'abcdefghijklmnopqrstuvwxyz234567';

/// the 32-byte service key of v3 onion address [onion], null for anything
/// else: base32 of the key, two checksum bytes and version 3, and the
/// engine gives back the same address for the key
Uint8List? onionKeyOf(String onion) {
  final s = onion.endsWith('.onion')
      ? onion.substring(0, onion.length - 6)
      : onion;
  if (s.length != 56) return null;
  final out = <int>[];
  var acc = 0, bits = 0;
  for (final c in s.split('')) {
    final v = _b32.indexOf(c);
    if (v < 0) return null;
    acc = (acc << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((acc >> bits) & 0xff);
    }
  }
  if (out.length != 35 || out[34] != 3) return null;
  final key = Uint8List.fromList(out.sublist(0, 32));
  try {
    if (engine.onionOfKey(_hexOf(key)) != '$s.onion') return null;
  } catch (_) {
    return null;
  }
  return key;
}

String _hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _bytesOfHex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

/// a v4 opener at one of my invites, as its line came: the invite, the
/// identity it is of and the key the wrap's seal was signed with
class InviteArrival {
  const InviteArrival(this.ident, this.invite, this.sealPk);
  final int ident;
  final InviteRow invite;
  final String sealPk;
}

/// [arrival]'s opener checked before anything is decrypted (3.1, 3.4): its
/// seal is the hello seal key of my identity and the key it names, and it
/// is on the invite's own prekeys. false drops it, and spends nothing
bool inviteOpenerHolds(
  KryfoSignal lib,
  InviteArrival arrival,
  Uint8List body, {
  required String Function(int ident, String senderX) helloSealPk,
}) {
  final LsPreKeyMessageInfo info;
  try {
    info = lib.preKeyMessageInfo(body);
  } catch (_) {
    return false;
  }
  if (info.version < 4 || info.identityKey.length != 33) return false;
  final want = helloSealPk(arrival.ident, _hexOf(info.identityKey.sublist(1)));
  if (want.startsWith('error') || want != arrival.sealPk.toLowerCase()) {
    return false;
  }
  final inv = arrival.invite;
  return info.signedPreKeyId == inv.spkId &&
      info.kyberPreKeyId == inv.kyberId &&
      (info.preKeyId == null || info.preKeyId == inv.ecId);
}

/// a v4 opener's envelope checked after it opened (3.1): it carries the
/// pair's seed, and a face signature over its own key and my invite's id
/// whenever it shows a face. the seed, or null to refuse it
Uint8List? inviteOpenerSeed(
  UnwrappedMessage env,
  List<int> sessionKey,
  String inviteId,
) {
  final s = env.addrSeed;
  if (env.protoGen != 4 || s == null || s.length != 64) return null;
  final Uint8List seed;
  try {
    seed = _bytesOfHex(s);
  } catch (_) {
    return null;
  }
  if (seed.length != 32) return null;
  final e = env.senderEdPub;
  if (e != null) {
    final fs = env.faceSig;
    if (fs == null || fs.length != 128 || e.length != 64) return null;
    try {
      final ok = ed.verify(
        ed.PublicKey(_bytesOfHex(e)),
        faceText(sessionKey, _bytesOfHex(inviteId)),
        _bytesOfHex(fs),
      );
      if (!ok) return null;
    } catch (_) {
      return null;
    }
  }
  return seed;
}

/// the pair of my [ident] with identity key [peerKeyHex] made again by a
/// v4 first contact: its addresses mix [seed] in from the first message
Future<void> seedPairAfresh(
  DatabaseExecutor db,
  int ident,
  String peerKeyHex,
  Uint8List seed,
) async {
  await db.delete(
    'pairs',
    where: 'ident = ? AND peer = ? AND their_device = 1 AND my_device = 1',
    whereArgs: [ident, peerKeyHex],
  );
  await putSeededPair(db, ident, peerKeyHex, seed);
}

// whether [cipher] is an opener on one of my v4 invites' signed prekeys:
// those open only at the invite's own address, after its checks
Future<bool> _onInviteKeys(String cipher) async {
  final Uint8List w;
  try {
    w = base64Decode(cipher);
  } catch (_) {
    return false;
  }
  if (w.isEmpty || w[0] != kLsPreKey) return false;
  final int spk;
  try {
    spk = signalSession.lib
        .preKeyMessageInfo(Uint8List.sublistView(w, 1))
        .signedPreKeyId;
  } catch (_) {
    return false;
  }
  // rows that do not read: the store the opener would open in is the same
  // file, so nothing opens on an invite's keys then either
  try {
    final db = await live.open();
    return (await db.query(
      'invites',
      columns: ['id'],
      where: 'ident = ? AND spk_id = ?',
      whereArgs: [signalSession.ident, spk],
      limit: 1,
    )).isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// the identity and invite id an invite address's lines are tagged with
/// (`f<ident>:<invite>`), null for any other tag
(int, String)? inviteTagOf(String tag) {
  final m = RegExp(r'^f(\d{1,4}):([0-9a-f]{32})$').firstMatch(tag);
  if (m == null) return null;
  return (int.parse(m.group(1)!), m.group(2)!);
}

extension AppStateInvites on AppState {
  /// a line from one of my invites' first-contact addresses: the seal's
  /// key, a bar and what came. an opener is opened only when its seal and
  /// its keys are the invite's (3.1); one that fails a check is dropped and
  /// spends nothing; a one-time invite goes with its first opener
  Future<void> _receiveAtInvite(
    int ident,
    String inviteId,
    String line,
    String h,
    void Function() arrived, {
    Reached? reached,
  }) async {
    final bar = line.indexOf('|');
    final sealPk = bar == 64 ? line.substring(0, 64) : '';
    final cipher = bar == 64 ? line.substring(65) : '';
    final db = await live.open();
    final row = ident == signalSession.ident
        ? await inviteOf(db, ident, inviteId)
        : null;
    // a hello: "KHL1" and its proof of work
    if (row != null && cipher.startsWith(kHelloWireStart)) {
      final hw = helloOfWire(cipher);
      if (hw == null) {
        await live.markSeenLong(h);
        arrived();
        return;
      }
      await _receiveHello(ident, row, sealPk, hw.hello, hw.nonce, h, arrived);
      return;
    }
    final Uint8List w;
    try {
      w = base64Decode(cipher);
    } catch (_) {
      await live.markSeenLong(h);
      arrived();
      return;
    }
    if (row == null ||
        !row.openAt(unixHours()) ||
        w.isEmpty ||
        w[0] != kLsPreKey) {
      dlog('invite: a line dropped');
      await live.markSeenLong(h);
      arrived();
      return;
    }
    final arrival = InviteArrival(ident, row, sealPk);
    if (!inviteOpenerHolds(
      signalSession.lib,
      arrival,
      Uint8List.sublistView(w, 1),
      helloSealPk: engine.helloSealPk,
    )) {
      firstFails.note('seal');
      await live.markSeenLong(h);
      arrived();
      return;
    }
    // my one-time invite inside a hello: only the owner it went to opens
    // on it, anyone else is dropped before decrypt and spends nothing
    final out = await db.query(
      'hellos',
      columns: ['peer'],
      where: 'ident = ? AND way = ? AND invite_id = ?',
      whereArgs: [ident, kHelloOut, inviteId],
      limit: 1,
    );
    if (out.isNotEmpty) {
      final info = signalSession.lib.preKeyMessageInfo(
        Uint8List.sublistView(w, 1),
      );
      if (_hexOf(info.identityKey) != out.first['peer']) {
        firstFails.note('owner');
        await live.markSeenLong(h);
        arrived();
        return;
      }
    }
    final (String, RouteTo)? paired;
    try {
      paired = await backPairFromCipher(cipher, reached: reached, v4: arrival);
    } on FirstRefused catch (e) {
      firstFails.note(e.why);
      await live.markSeenLong(h);
      arrived();
      return;
    }
    if (paired == null) {
      // opened and not filed, or not opened yet: it comes again
      throw StateError('invite: an opener not filed');
    }
    if (row.oneTime) {
      await spendOneTime(db, signalSession, row);
      await engine.unsubscribeFcKey(ident, inviteId);
      await db.delete(
        'hellos',
        where: 'ident = ? AND way = ? AND invite_id = ?',
        whereArgs: [ident, kHelloOut, inviteId],
      );
    }
    await live.markSeen(h);
    if (AppState._shown(paired.$2)) arrived();
  }

  // my face on the main invite: the onion key, F and F's signature
  InviteFace? _mainInviteFace() {
    final onion = onionKeyOf(myOnion);
    final f = engine.myEdPubkey();
    if (onion == null || f.length != 64) return null;
    return InviteFace(
      onionKey: onion,
      face: _bytesOfHex(f),
      sign: (m) {
        final s = engine.faceSign(_hexOf(m));
        if (s.length != 128) throw StateError('no face signature');
        return _bytesOfHex(s);
      },
    );
  }

  String _fcPkOfKey(Uint8List sk) {
    try {
      return engine.fcKeyPk(_hexOf(sk));
    } catch (e) {
      return 'error: $e';
    }
  }

  /// the main identity's invites kept (made, made again at six months,
  /// dropped a day after expiry, the developer's never) and each live one
  /// listened on. the everyday side only: a quiet session has none
  Future<void> keepMyInvites({int? nowMs}) async {
    if (sessionQuiet || !signalSession.ready) return;
    final face = _mainInviteFace();
    if (face == null) {
      dlog('invites: no face yet, kept next start');
      return;
    }
    final db = await live.open();
    final up = await keepInvites(
      db,
      signalSession,
      fcPkOf: _fcPkOfKey,
      face: face,
      dev: devModeOf(myXPub),
      nowMs: nowMs,
    );
    if (up.made != null) dlog('invites: a main invite made');
    for (final id in up.dropped) {
      await engine.unsubscribeFcKey(kMainIdent, id);
      // a hello of mine whose one-time invite went waits for nothing more
      await db.delete(
        'hellos',
        where: 'ident = ? AND way = ? AND invite_id = ?',
        whereArgs: [kMainIdent, kHelloOut, id],
      );
    }
    // a hello waiting for an accept past its invite's life and a day
    // builds on keys its sender let go
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.delete(
      'hellos',
      where: 'way = ? AND at < ?',
      whereArgs: [kHelloIn, now - (kOneTimeHours + kSkewHours) * 3600 * 1000],
    );
    await _listenMyInvites(db, nowMs: nowMs);
    unawaited(sendHellosOwed(nowMs: nowMs));
  }

  Future<void> _listenMyInvites(DatabaseExecutor db, {int? nowMs}) async {
    final h = unixHours(nowMs);
    final keys = await fcKeysOf(db, kMainIdent);
    for (final r in await invitesOf(db, kMainIdent)) {
      final sk = keys[r.id];
      if (sk == null || !r.openAt(h)) continue;
      final res = await engine.subscribeFcKey(kMainIdent, r.id, _hexOf(sk));
      if (res != 'ok') dlog('invites: not listened on ($res)');
    }
  }

  /// my v4 link (with the bundle) or, with [qr], its qr form; null before
  /// the main invite is made
  Future<String?> myV4Invite({bool qr = false}) async {
    final r = await currentMainInvite(await live.open(), kMainIdent);
    if (r == null) return null;
    final b = qr ? r.qr : r.link;
    return b == null ? null : inviteLink(b);
  }

  /// a v4 first contact to [peer] waits for its answer: every frame to them
  /// until then carries the pair's seed and my face signature for their
  /// invite (3.1). the frame as it goes
  Future<String> v4OpenerFields(String peer, String frame) async {
    if (!frame.startsWith(kEnvelopePrefix)) return frame;
    // rows that do not read add nothing: the far side refuses an opener
    // without its seed, so nothing goes on the wrong addresses
    final ({int ident, String key, String invite, Uint8List seed})? o;
    try {
      o = await _openHello(peer);
    } catch (e) {
      dlog('v4 opener: rows not read (${e.runtimeType})');
      return frame;
    }
    if (o == null) return frame;
    final j =
        jsonDecode(frame.substring(kEnvelopePrefix.length))
            as Map<String, dynamic>;
    j['pg'] = 4;
    j['as'] = _hexOf(o.seed);
    // the face signature only with the face: a frame with no words shows
    // none
    if (o.ident == kMainIdent && j['e'] != null) {
      final fs = engine.faceSign(
        _hexOf(faceText(signalSession.identity.public, _bytesOfHex(o.invite))),
      );
      if (fs.length != 128) throw const OtherIdentity('no face signature');
      j['fs'] = fs;
    }
    return '$kEnvelopePrefix${jsonEncode(j)}';
  }

  // the v4 first contact to [peer] that waits for its answer: my identity,
  // their key, their invite's id and the pair's seed. null with none, and
  // its row goes once they answered
  Future<({int ident, String key, String invite, Uint8List seed})?> _openHello(
    String peer,
  ) async {
    final db = await live.open();
    final c = await db.query(
      'contacts',
      columns: ['xpub', 'back_paired', 'ident'],
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    if (c.isEmpty) return null;
    final key = identityKeyHex(c.first['xpub'] as String?);
    if (key == null) return null;
    final ident = c.first['ident'] as int? ?? kMainIdent;
    final o = await db.query(
      'hellos',
      columns: ['invite_id'],
      where: 'ident = ? AND way = ? AND peer = ?',
      whereArgs: [ident, kHelloOpen, key],
      limit: 1,
    );
    if (o.isEmpty) return null;
    if ((c.first['back_paired'] as int? ?? 0) == 1) {
      await db.delete(
        'hellos',
        where: 'ident = ? AND way = ? AND peer = ?',
        whereArgs: [ident, kHelloOpen, key],
      );
      return null;
    }
    final p = await pairOf(db, ident, key);
    final seed = p.seed;
    if (p.conv != kConvSeeded || seed == null) return null;
    return (
      ident: ident,
      key: key,
      invite: o.first['invite_id'] as String,
      seed: seed,
    );
  }

  /// a hello to [owner], answering their invite [answers] (all zero: a v3
  /// link) at its first-contact key [fc] (3.3, 11 step 7): kept until it
  /// went, and sent now when it can be
  Future<void> wantHello({
    required List<int> owner,
    required List<int> answers,
    required String fc,
  }) async {
    await live.oweHello(_hexOf(owner), _hexOf(answers), fc);
    unawaited(sendHellosOwed());
  }

  /// every hello owed sent, one pass at a time: at each start, after an
  /// add and, with [due], as the outbox drains, once in kHelloRetry. one
  /// that does not go is made again on the next pass
  Future<void> sendHellosOwed({int? nowMs, bool due = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (due && now - _helloPassAt < kHelloRetry.inMilliseconds) {
      return Future.value();
    }
    _helloPassAt = now;
    return _helloPass ??= _sendHellos(nowMs: nowMs).whenComplete(() {
      _helloPass = null;
    });
  }

  Future<void> _sendHellos({int? nowMs}) async {
    try {
      if (sessionQuiet || everydayHeld || !signalSession.ready) return;
      final db = await live.open();
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      await db.delete(
        'hellos',
        where: 'way = ? AND at < ?',
        whereArgs: [kHelloWant, now - kHelloWantDays * 24 * 3600 * 1000],
      );
      final rows = await db.query(
        'hellos',
        where: 'ident = ? AND way = ?',
        whereArgs: [kMainIdent, kHelloWant],
      );
      for (final r in rows) {
        if (everydayHeld) return;
        if (!await _sendOneHello(db, r, nowMs: nowMs)) return;
      }
    } catch (e) {
      dlog('hello: not sent (${e.runtimeType})');
    }
  }

  // [r]'s hello made and sent: a fresh one-time invite of mine in a KHL1,
  // sealed with the hello seal key to the invite's first-contact address,
  // and that one-time invite listened on for their opener. one that did
  // not go takes its one-time invite with it. false stops the pass
  Future<bool> _sendOneHello(
    Database db,
    Map<String, Object?> r, {
    int? nowMs,
  }) async {
    final peer = r['peer'] as String;
    final answers = r['invite_id'] as String;
    final fc = r['fc'] as String? ?? '';
    Future<void> done() => db.delete(
      'hellos',
      where: 'ident = ? AND way = ? AND peer = ? AND invite_id = ?',
      whereArgs: [kMainIdent, kHelloWant, peer, answers],
    );
    // answered already: a session on their key needs no hello
    final c = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'ikey = ?',
      whereArgs: [peer],
      limit: 1,
    );
    if (c.isNotEmpty && await hasSessionWith(c.first['halo_id'] as String)) {
      await done();
      return true;
    }
    final face = _mainInviteFace();
    if (face == null) {
      dlog('hello: no face yet, sent on a later pass');
      return false;
    }
    final (hello, once) = await makeHello(
      db,
      signalSession,
      answers: _bytesOfHex(answers),
      owner: _bytesOfHex(peer),
      fcPkOf: _fcPkOfKey,
      face: face,
      nowMs: nowMs,
    );
    await db.insert('hellos', {
      'ident': kMainIdent,
      'way': kHelloOut,
      'peer': peer,
      'invite_id': once.id,
      'fc': fc,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final sk = (await fcKeysOf(db, kMainIdent))[once.id];
    if (sk != null) {
      await engine.subscribeFcKey(kMainIdent, once.id, _hexOf(sk));
    }
    final res = await engine.sendHello(
      kMainIdent,
      peer.substring(2),
      fc,
      await helloWire(hello),
    );
    if (res == 'ok') {
      await done();
      return true;
    }
    dlog('hello: not sent ($res)');
    await spendOneTime(db, signalSession, once);
    await engine.unsubscribeFcKey(kMainIdent, once.id);
    await db.delete(
      'hellos',
      where: 'ident = ? AND way = ? AND invite_id = ?',
      whereArgs: [kMainIdent, kHelloOut, once.id],
    );
    return false;
  }

  // an add from a v4 invite without a bundle (a qr): their row, and a
  // hello that waits for their accept
  Future<(String, bool)> _addByHello(
    LsInvite inv, {
    required bool scanned,
  }) async {
    final p = v4Parsed(inv, bundle: false);
    if (p == null) return (l10n.appInvalidUri, false);
    final id = p['id']!;
    if (id == sessionId) return (l10n.appYourOwnInvite, false);
    if (await session.keyBlocked(_keyHex(inv.identity))) {
      return (l10n.appKeyBlocked, false);
    }
    // a name held here on another key is not taken by a hello
    final row = await session.getContact(id);
    if (row != null &&
        (row['xpub'] as String? ?? '').toLowerCase() != p['xpub']) {
      return (l10n.appLinkWordsTaken(id), false);
    }
    if (await session.isBlocked(id)) return (l10n.appTheyAreBlocked(id), false);
    final already = await session.isAccepted(id);
    await session.upsertContact(id, row?['onion'] as String? ?? '', p['xpub']!);
    await _noteHowAdded(id, scanned: scanned, already: already, taken: false);
    if (!await hasSessionWith(id)) {
      await signalSession.identityStore.saw(id, inv.identity);
      await wantHello(
        owner: inv.identity,
        answers: inv.id,
        fc: _hexOf(inv.firstContact),
      );
    }
    await refreshContacts();
    openAddedChatLater(id);
    return (already ? l10n.appAlreadySaved(id) : l10n.helloSent, true);
  }

  /// a hello at invite [at] of mine (null: my v3 first-contact address),
  /// sealed with [sealPk], with [nonce] its proof of work: taken on the
  /// five rules of 3.3 and kept as a
  /// request until the person accepts it; dropped quietly otherwise, and a
  /// copy is taken once
  Future<void> _receiveHello(
    int ident,
    InviteRow? at,
    String sealPk,
    Uint8List bytes,
    int nonce,
    String h,
    void Function() arrived,
  ) async {
    // the proof of work first: one hash, before the shim reads anything
    if (!helloPowHolds(bytes, nonce)) {
      firstFails.note('pow');
      await live.markSeenLong(h);
      arrived();
      return;
    }
    final db = await live.open();
    final hash = helloHash(bytes);
    final r = checkHello(
      signalSession.lib,
      bytes,
      at: at,
      mine: signalSession.identity.public,
      sealPk: sealPk,
      sealOf: (x) => engine.helloSealPk(ident, x),
      seen: await helloSeen(db, ident, hash),
    );
    final hl = r.hello;
    final fields = hl == null ? null : v4Parsed(hl.invite);
    var drop = hl == null || fields == null;
    final senderKey = hl == null ? '' : _hexOf(hl.invite.identity);
    if (!drop) {
      // crossed hellos: theirs is answered only when their key is the
      // smaller; mine then waits for their opener
      final out = await db.query(
        'hellos',
        where: 'ident = ? AND way IN (?, ?) AND peer = ?',
        whereArgs: [ident, kHelloOut, kHelloWant, senderKey],
        limit: 1,
      );
      drop =
          out.isNotEmpty &&
          !answerTheirs(signalSession.identity.public, hl.invite.identity);
    }
    if (drop) {
      if (r.fault != HelloFault.seen) firstFails.note('hello');
      await live.markSeenLong(h);
      arrived();
      return;
    }
    await noteHelloSeen(db, ident, hash);
    // the words of their face, unless someone here holds them on another
    // key: then an id of its own, as a first contact gets
    var id = fields!['id']!;
    final row = await live.getContact(id);
    if (row != null &&
        (row['xpub'] as String? ?? '').toLowerCase() != fields['xpub']) {
      id = unboundIdOf(hl!.invite.identity);
    }
    // someone blocked here, by words or by key, asks nothing
    if (await live.keyBlocked(_keyHex(hl!.invite.identity)) ||
        await blockedAnywhere(id)) {
      firstFails.note('hello');
      await live.markSeenLong(h);
      arrived();
      return;
    }
    await db.insert('hellos', {
      'ident': ident,
      'way': kHelloIn,
      'peer': senderKey,
      'invite_id': at?.id ?? '0' * 32,
      'hello': bytes,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final have = await live.getContact(id);
    if (have == null) {
      await live.upsertContact(id, '', fields['xpub']!, accepted: 0);
    }
    await live.markSeen(h);
    // someone here already, on this key (a reinstall that kept it): no
    // request, their hello is answered as an accept would
    final known =
        have != null &&
        (have['accepted'] as int? ?? 0) == 1 &&
        (have['blocked'] as int? ?? 0) == 0 &&
        have['ikey'] == senderKey;
    if (known) unawaited(afterAccept(id));
    await refreshContacts();
    notifyListeners();
    arrived();
  }

  /// the person accepted [haloId]: a hello of theirs waiting here is
  /// answered, the session started from the one-time invite inside it and
  /// the first message sent to its first-contact address (3.3)
  Future<void> answerHello(String haloId) async {
    final db = await live.open();
    final c = await db.query(
      'contacts',
      columns: ['ikey', 'ident'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
      limit: 1,
    );
    final key = c.isEmpty ? null : c.first['ikey'] as String?;
    if (key == null) return;
    final ident = c.first['ident'] as int? ?? kMainIdent;
    final rows = await db.query(
      'hellos',
      where: 'ident = ? AND way = ? AND peer = ?',
      whereArgs: [ident, kHelloIn, key],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final hl = signalSession.lib.parseHello(rows.first['hello'] as List<int>);
    await startFromInvite(haloId, hl.invite);
    await rememberPeerFc(haloId, _hexOf(hl.invite.firstContact));
    // theirs answered: one of mine still owed to them goes nowhere
    await db.delete(
      'hellos',
      where: 'ident = ? AND way IN (?, ?) AND peer = ?',
      whereArgs: [ident, kHelloIn, kHelloWant, key],
    );
  }

  /// a contact added from a v4 invite [inv]: the session from its bundle
  /// and the pair seeded afresh, so the first message goes to the invite's
  /// first-contact address sealed with the hello seal key and carries the
  /// seed (the caller keeps the address once the contact is written)
  Future<void> startFromInvite(String id, LsInvite inv) async {
    final bundle = inv.block!.bundle;
    final key = _hexOf(inv.identity);
    final x = key.substring(2);
    final db = await live.open();
    final r = Random.secure();
    final seed = Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
    await signalSession.processBundle(id, bundle);
    await seedPairAfresh(db, kMainIdent, key, seed);
    // a pair made again: its frames carry the seed until they answer
    await db.update(
      'contacts',
      {'back_paired': 0},
      where: 'halo_id = ?',
      whereArgs: [id],
    );
    await db.insert('hellos', {
      'ident': kMainIdent,
      'way': kHelloOpen,
      'peer': key,
      'invite_id': _hexOf(inv.id),
      'fc': _hexOf(inv.firstContact),
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    dlog('pair: v4 invite, seeded pair');
    // the engine takes the seed with every call from now on
    final res = await engine.pairSeed(kMainIdent, x, _hexOf(seed));
    if (res != 'ok') dlog('pair: seed not taken ($res)');
  }
}

/// a hellos row: a v4 first contact I sent, waiting for its answer; a
/// hello of mine out, waiting for the opener to my one-time invite in it;
/// a hello in, waiting for the person's accept
const kHelloOpen = 'open';
const kHelloOut = 'out';
const kHelloIn = 'in';

/// a hellos row: a hello owed, made and sent once it can be
const kHelloWant = 'want';

/// how long a hello owed is tried before it is let go
const kHelloWantDays = 7;

// the one pass sending hellos owed, and when the last began
Future<void>? _helloPass;
var _helloPassAt = 0;

/// how often the outbox's drain tries the hellos owed again
const kHelloRetry = Duration(minutes: 5);

int _helloGrind(String seed) => grindPow(seed, powBits);

/// [hello] as it goes on the wire, with its proof of work (3.3): ground
/// off the ui's isolate
Future<String> helloWire(Uint8List hello) async =>
    helloWireOf(hello, await compute(_helloGrind, helloPowSeed(hello)));
