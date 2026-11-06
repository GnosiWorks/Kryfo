// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: broken sessions: resends, fresh starts and bundle swaps

part of '../main.dart';

extension AppStateHeal on AppState {
  static const _healTtl = 60 * 60 * 1000;
  // how far back an ask to start afresh puts undelivered texts out again,
  // and how far an ask that says when its backup was made takes it
  static const _kResendWindow = Duration(days: 7);
  static const _kResendMost = Duration(days: 30);
  // and how often, per person: each ask is a fresh wrap, and a phone that
  // cannot open what we send asks again on every text, a minute apart at
  // most. short, so a text written just after the first ask goes with the
  // next one rather than ten minutes on
  static const _kResendGap = Duration(minutes: 2);

  // what we sent [peer] lately and never came back delivered, put out again
  // from [on], the container their chat is in: since their backup was made
  // ([since]) when the ask says, never less than the window. not while
  // their key is flagged as changed: that one is checked first
  Future<void> _resendTo(
    HaloDb on,
    String peer, {
    int? since,
    // from here exactly, past the window
    int? floor,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_resentAt[peer] ?? 0) < _kResendGap.inMilliseconds) return;
    // someone blocked is sent nothing again, asked or owed, whichever
    // container blocked them
    if (await on.isBlocked(peer) || await blockedAnywhere(peer)) return;
    if (await on.keyChanged(peer)) {
      dlog('resend: their key changed, nothing again');
      return;
    }
    _resentAt[peer] = now;
    final again = await on.resendUndelivered(
      peer,
      since:
          floor ??
          resendFrom(now, since, window: _kResendWindow, most: _kResendMost),
    );
    // after their restore: what we took back or edited since their backup
    // goes again, or their file brings it back for good
    final undone = since == null || since > now
        ? 0
        : await on.requeueTakenSince(peer, since: since);
    if (undone > 0) dlog('resend: $undone unsends and edits go again');
    if (again > 0) {
      dlog('resend: $again undelivered to $peer go again');
      _bumpChatRev(peer);
    }
    if (again > 0 || undone > 0) unawaited(drainOutbox());
  }

  // asked while their vault is shut: the resend is owed, sealed to the
  // vault with what came for it, and runs as it opens (drainSealed)
  Future<void> _oweResend(String peer, {int? since}) async {
    // someone blocked: nothing is sealed for them, as on arrival
    if (await blockedAnywhere(peer)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_owedSealedAt[peer] ?? 0) < _kResendGap.inMilliseconds) return;
    final kept = await _router.seal(
      Unsealed(peer, '', false, now, resend: true, resendSince: since),
    );
    if (kept) _owedSealedAt[peer] = now;
  }

  // our group texts since their backup, owed again to a member who
  // restored one, from [d], the container the groups are in. the marks in
  // [d] keep it to once per restore
  Future<void> _resendGroupTextsTo(
    HaloDb d,
    String member, {
    required int since,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // a backup from the future is no restore
    if (since > now || d.container.quiet) return;
    final gap = '${d.container.dbFile}|$member';
    if (now - (_groupResentAt[gap] ?? 0) < _kResendGap.inMilliseconds) return;
    if (await d.isBlocked(member) || await blockedAnywhere(member)) return;
    if (await d.keyChanged(member)) return;
    _groupResentAt[gap] = now;
    // our unsends and edits since their backup, which their file undid
    final undone = await d.requeueGroupTakenSince(
      member,
      since: since,
      now: now,
    );
    if (undone > 0) {
      dlog('resend: $undone group unsends and edits go again');
      if (!haloWiping && !everydayHeld) unawaited(_drainGroupCtl());
    }
    // no further back than gone texts are known, by the day: an older
    // backup is the same restore all day long
    final from = max(since, now - HaloDb.kGoneFor.inMilliseconds);
    final n = await d.oweGroupTextsAfterRestore(
      member,
      me: myId,
      from: from,
      restore: utcDayOf(from),
      now: now,
    );
    if (n == 0) return;
    dlog('resend: $n group texts owed again');
    groupOwedTick.value++;
    if (torReady) unawaited(_drainGroupOwed());
  }

  // a restore's ask, for the groups: each container open now, and a shut
  // vault that knows them gets it sealed, to run as it opens. [sealed]: the
  // one to one ask already was
  Future<void> _resendGroupsAfterRestore(
    String member, {
    required int since,
    required bool sealed,
  }) async {
    for (final d in [live, ?_openVault]) {
      try {
        await _resendGroupTextsTo(d, member, since: since);
      } catch (e) {
        dlog('resend: group texts not owed (${e.runtimeType})');
      }
    }
    if (!sealed && hiddenWhileShut(member)) {
      await _oweResend(member, since: since);
    }
  }

  void _pruneHeal() {
    final cut = DateTime.now().millisecondsSinceEpoch - _healTtl;
    _healPending.removeWhere((_, t) => t < cut);
    _bundleCtlSentAt.removeWhere((_, t) => t < cut);
  }

  void _wantHeal(String peer) {
    _pruneHeal();
    _healPending[peer] = DateTime.now().millisecondsSinceEpoch;
  }

  // a seal on a session a restore brought back: nothing is built here.
  // they are sent a heal (KHB1) as it falls due, build from it and answer,
  // and what waits goes once their answer opens (3.8: one side builds, the
  // other opens, so no second session races the first)
  Future<LsBundle?> _afreshCard(String peer) async {
    _waitingCard.add(peer);
    // only marked: the next pass sends it first, inside its budget of
    // eight, so a busy start does not put out a heal to everyone it
    // touches at once
    _healWanted.add(peer);
    return null;
  }

  /// [peer]'s messages stop reading: a session a restore brought back is
  /// healed by the next pass, any other at once (a repair)
  Future<void> _healSoon(String peer) async {
    final ss = await signalFor(peer);
    if (ss != null && await ss.sealsOnRestored(peer)) {
      _healWanted.add(peer);
      return;
    }
    await _askToStartAfresh(peer);
  }

  Future<bool> _askOnce(String peer, int now) =>
      _asking[peer] ??= _askToStartAfresh(peer, now: now)
          .catchError((Object e) {
            dlog('afresh: ask failed (${e.runtimeType})');
            return false;
          })
          // a block body: the removed entry is this future, and waiting
          // on it here would never end
          .whenComplete(() {
            _asking.remove(peer);
          });
  // asks a pass sends at most: a phone of many people asks a few at a time
  static const _kAsksPerPass = 8;

  Future<void> _askAfresh({int? now}) => _afreshPass ??= _askAfreshRound(
    now ?? DateTime.now().millisecondsSinceEpoch,
  ).whenComplete(() => _afreshPass = null);

  // the gap between two passes: 10 to 30 minutes at random, so the heals
  // of one restore go out over hours and two contacts comparing when
  // theirs came learn little
  static int _afreshGap(Random r) =>
      const Duration(minutes: 10).inMilliseconds +
      r.nextInt(const Duration(minutes: 20).inMilliseconds);

  Future<void> _askAfreshRound(int now) async {
    if (everydayHeld) return;
    if (!signalSession.ready || !signalSession.hasRestored) return;
    if (now < _afreshLookedAt) return;
    final rnd = Random.secure();
    _afreshLookedAt = now + _afreshGap(rnd);
    // someone blocked or never taken in is never asked, and their session
    // would hold the marks for good
    final unasked = <String>{};
    for (final d in [live, ?_openVault]) {
      try {
        unasked.addAll(await d.unaskedIds());
      } catch (e) {
        dlog('afresh: unasked not read (${e.runtimeType})');
      }
    }
    if (await signalSession.dropRestoredWhenDone(
      leaveOut: (id) => unasked.contains(id) || _router.blocks(id),
    )) {
      return;
    }
    var left = _kAsksPerPass;
    // the open vault's people too: one shut now is looked at on a later
    // pass. in random order, whatever identity each is on
    final people = <String>[];
    for (final d in [live, ?_openVault]) {
      try {
        for (final r in await d.contacts()) {
          people.add(r['halo_id'] as String);
        }
      } catch (_) {
        continue;
      }
    }
    people.shuffle(rnd);
    // those a seal waits on first, then everyone else, each once
    final wanted = [..._healWanted]..shuffle(rnd);
    final order = {...wanted, ...people};
    for (final id in order) {
      if (left == 0 || everydayHeld) return;
      if (isDevId(id)) continue;
      final ss = await signalFor(id);
      if (ss == null || !await ss.sealsOnRestored(id)) {
        _healWanted.remove(id);
        continue;
      }
      if (!await ss.askDue(id, now)) continue;
      if (await _askOnce(id, now)) {
        _healWanted.remove(id);
        left--;
      }
    }
  }

  @visibleForTesting
  Future<void> askAfreshForTest({int? now}) => _askAfresh(now: now);

  // [peer] is sent a heal (KHB1): our phone's bundle with a one-time
  // kyber made for it, so they build a session to us and answer on it.
  // after a restore it says so (bit 0) and since when: the day of their
  // last message here, so what of theirs never reached this file comes
  // again. true once the relay took it
  Future<bool> _askToStartAfresh(String peer, {int? now}) async {
    if (isDevId(peer) || !await _io.hasSession(peer)) return false;
    // someone blocked is sent nothing, not even keys
    final to = await _reach(peer);
    if (to == null || await blockedAnywhere(peer)) return false;
    final ss = await signalFor(peer);
    if (ss == null) return false;
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final restored = await ss.sealsOnRestored(peer);
    final on = to.on;
    // a chat deleted here (parked) gets no restore's heal: it would tell
    // them, and they reach us as a request, as anyone new does. one a shut
    // vault holds waits for it to open, where that can be read (a later
    // pass, or their next text, which opens only then)
    if (restored && (on == null || !await on.isAccepted(peer))) return false;
    int? since;
    if (restored) {
      final from = ss.restoredFrom ?? at;
      try {
        since = on == null
            ? healDayOf(from)
            : await healSinceFor(await on.open(), peer, fallbackMs: from);
      } catch (e) {
        dlog('heal: since not read (${e.runtimeType})');
        since = healDayOf(from);
      }
    } else if (await _olderKryfo(peer, to.on)) {
      // a repair a 0.5.x phone cannot take: nothing goes, nothing waits
      return false;
    }
    final ok = await _sendHeal(peer, ss, since: since, now: at);
    if (ok) {
      _wantHeal(peer);
      // a repair holds our sends until their answer opens: one sealed on
      // the old session meanwhile would put it in front again over there
      if (!restored) _waitingCard.add(peer);
      await ss.noteAsked(peer, at);
    }
    return ok;
  }

  // their row says they never sent a capability list: a 0.5.x phone
  Future<bool> _olderKryfo(String peer, HaloDb? on) async {
    if (on == null) return false;
    try {
      return olderKryfo((await on.getContact(peer))?['caps'] as String?);
    } catch (_) {
      return false;
    }
  }

  /// [peer] holds an older Kryfo and their session came back with a
  /// restore: their chat waits until they update (Q20)
  Future<bool> pausedForUpdate(String peer) async {
    if (isDevId(peer)) return false;
    try {
      final ss = await signalFor(peer);
      if (ss == null || !await ss.sealsOnRestored(peer)) return false;
      final to = await _reach(peer);
      return to != null && await _olderKryfo(peer, to.on);
    } catch (e) {
      dlog('heal: pause not read (${e.runtimeType})');
      return false;
    }
  }

  // the KHB1 itself, outside the session on the pair's address. at most
  // one a minute per person
  Future<bool> _sendHeal(
    String peer,
    SignalSession ss, {
    int? since,
    required int now,
  }) async {
    if (everydayHeld) return false;
    final key = '$peer:heal';
    if (now - (_bundleCtlSentAt[key] ?? 0) < _bundleGap.inMilliseconds) {
      return false;
    }
    _pruneHeal();
    _bundleCtlSentAt[key] = now;
    try {
      final to = await _reach(peer);
      if (to == null || to.xpub.isEmpty) return false;
      // never to someone whose identity is not held: a first contact goes
      // through the invite and the hello
      final theirs = await _storedIdentity(ss, peer);
      if (theirs == null) return false;
      final khb1 = await makeHeal(ss, peer: theirs, since: since, nowMs: now);
      final (on, framed) = await doorFor(peer, healWire(khb1), outside: true);
      if (on != ss.ident) return false;
      final r = await Future(() => _io.relaySend(on, to.xpub, framed));
      dlog('heal to $peer (restored=${since != null}): $r');
      return r == 'ok';
    } catch (e) {
      dlog('heal to $peer failed (${e.runtimeType})');
      return false;
    }
  }

  // [a] sorts before [b] as bytes: the smaller identity key's heal wins
  // when two cross
  static bool _keyBefore(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] < b[i];
    }
    return a.length < b.length;
  }

  // a heal (KHB1) came off the relay from [peerXPub], the key the wrap's
  // seal names. taken only when 3.8's checks hold: theirs and mine, signed
  // by their identity, fresh, never seen, a pq bundle. then their session
  // is built from it, the empty answer goes at once inside it, and what
  // never came back delivered goes again
  Future<void> _takeHeal(String peerXPub, Uint8List khb1, String h) async {
    try {
      final x = peerXPub.toLowerCase();
      final peer = _xPubToHaloId[peerXPub] ?? _xPubToHaloId[x];
      if (peer == null || isDevId(peer) || devIdClaim(peer)) {
        dlog('heal: from no one held here, dropped');
        return;
      }
      final to = await _reach(peer);
      if (to == null || to.xpub.toLowerCase() != x) return;
      if (await blockedAnywhere(peer)) return;
      final on = to.on;
      if (on == null) {
        // a shut vault holds them: their next try lands once it is open
        dlog('heal: for a chat a shut vault holds, not taken now');
        return;
      }
      if (!await on.isAccepted(peer)) return;
      final ss = await signalFor(peer);
      if (ss == null) return;
      final LsHeal heal;
      try {
        heal = ss.lib.parseHeal(khb1);
      } on LsError catch (e) {
        dlog('heal: refused by the parser ($e)');
        return;
      }
      // never a first session: a heal is for an identity held here
      final held = await _storedIdentity(ss, peer);
      if (held == null) {
        dlog('heal: no identity held for them, dropped');
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final why = checkHeal(
        heal,
        held: held,
        mine: ss.identity.public,
        nowMs: now,
        restoredAt: await restoredAt(),
        lastIssued: await lastHealOf(await on.open(), peer),
      );
      if (why != null) {
        dlog('heal: refused (${why.name})');
        return;
      }
      // both sent one at once: the smaller identity key's is the one built
      _pruneHeal();
      if (_healPending.containsKey(peer) &&
          _keyBefore(ss.identity.public, heal.identity)) {
        dlog('heal: crossed, ours stands');
        return;
      }
      final built = _healBuiltAt[peer];
      if (built != null && now - built < kHealRebuildGap.inMilliseconds) {
        dlog('heal: rebuilt lately, taken on their next try');
        return;
      }
      // kept where they are: an open vault's contact in the vault
      if (!await noteHealNonce(
        await on.open(),
        ss.ident,
        heal.nonce,
        nowMs: now,
        peer: peer,
      )) {
        dlog('heal: a nonce seen already');
        return;
      }
      try {
        await ss.processBundle(peer, heal.block.bundle);
      } on ClassicRefused {
        return;
      } on LsError {
        // only a held record that does not read goes: one that reads keeps
        // its archived states, so what was sealed before still opens
        if (!await _heldUnreadable(ss, peer)) rethrow;
        await ss.rebuild(peer, heal.block.bundle);
      }
      _healBuiltAt[peer] = now;
      _healPending.remove(peer);
      await keepLastHeal(await on.open(), peer, heal.issued);
      // a classic chat a heal moved to pq: the restart is done, and its 15
      // days begin, so the upkeep sends no KDB1 for it
      final info = await ss.sessionInfo(peer);
      if (info != null && info.archived.any((s) => s.version < 4)) {
        await notePqOver(peer, nowMs: now);
      }
      dlog('heal: session rebuilt for $peer (restored=${heal.restored})');
      await _noteHealed(on, peer, restored: heal.restored, at: now);
      // the answer first: the opener their heal kyber opens
      await _answerHeal(peer);
      // what waited on our side goes on the new session
      _cardCame(peer);
      final since = healSinceMs(heal);
      await _resendTo(on, peer, since: since);
      if (since != null) {
        await _resendGroupsAfterRestore(peer, since: since, sealed: false);
      }
    } catch (e) {
      dlog('heal: not taken (${e.runtimeType})');
    } finally {
      await live.markSeen(h);
    }
  }

  Future<bool> _heldUnreadable(SignalSession ss, String peer) async {
    final r = await ss.sessionStore.load(peer);
    if (r == null) return false;
    try {
      ss.lib.sessionInfo(r);
      return false;
    } on LsError {
      return true;
    }
  }

  // the line in their chat, and a hold on a verified contact until the
  // person looks. the flag only picks the words: a key holder could clear
  // it, so the hold never depends on it (Q22)
  Future<void> _noteHealed(
    HaloDb on,
    String peer, {
    required bool restored,
    required int at,
  }) async {
    try {
      final row = await on.getContact(peer);
      final verified = (row?['verified_key'] as String?)?.isNotEmpty ?? false;
      await addHealLine(
        await on.open(),
        peer,
        at: at,
        kind: restored ? kHealLineRestored : kHealLineRepair,
        held: kHealHold && verified,
      );
      _bumpChatRev(peer);
      keyChanged();
    } catch (e) {
      dlog('heal: line not kept (${e.runtimeType})');
    }
  }

  // the empty frame that answers a heal, inside the session it built: not
  // held for a key check, since it carries nothing
  Future<void> _answerHeal(String peer) async {
    try {
      final to = await _reach(peer);
      if (to == null || to.xpub.isEmpty) return;
      final s = await signalSeal(
        peer,
        await wrapMessage('', sender: _mySender()),
        unheld: true,
      );
      final r = await Future(() => _io.relaySend(s.ident, to.xpub, s.cipher));
      dlog('heal: answered $peer: $r');
    } catch (e) {
      dlog('heal: not answered (${e.runtimeType})');
    }
  }

  /// the person looked at a heal's hold on [peer]: what waited goes
  Future<void> releaseHealHold(String peer) async {
    try {
      await session.releaseHealHold(peer);
    } catch (e) {
      dlog('heal: hold not cleared (${e.runtimeType})');
    }
    _recardFor(peer);
    keyChanged();
    unawaited(drainOutbox());
  }

  /// before the everyday store opens after a restore: every other
  /// identity's sessions are marked as the main one's are as it opens, so
  /// none is sealed on before a heal. true when each was
  Future<bool> markRestoredIdentities(Database db, {int? from}) async {
    var ok = true;
    for (final r in await identityRows(db)) {
      if (r.retiredAt != null || r.id == kMainIdent || r.kind == kIdentPool) {
        continue;
      }
      try {
        await (await signalOfIdent(r.id)).markRestored(from: from);
      } catch (e) {
        ok = false;
        dlog('restore: identity ${r.id} not marked (${e.runtimeType})');
      }
    }
    return ok;
  }

  /// what follows a restore or a move, once, on the first start after it,
  /// with every store open: each identity's unused one-time invites
  /// go (one may have been answered since the file was made) and its
  /// session prekeys are made again, and pool identities retire. the main
  /// invites stay: links and the handle keep working. true when every
  /// identity was done; otherwise the next start runs it again
  Future<bool> afterRestore(Database db, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    var ok = true;
    for (final r in await identityRows(db)) {
      if (r.retiredAt != null) continue;
      if (r.kind == kIdentPool) {
        await db.update(
          'identities',
          {'retired_at': now},
          where: 'id = ?',
          whereArgs: [r.id],
        );
        continue;
      }
      try {
        final ss = await signalOfIdent(r.id);
        for (final i in await invitesOf(db, r.id, kind: kInviteOneTime)) {
          if (i.usedAt == null) await dropInvite(db, ss, i);
        }
        await ss.replaceSessionPreKeys(now: now);
      } catch (e) {
        ok = false;
        dlog('restore: identity ${r.id} not settled (${e.runtimeType})');
      }
    }
    dlog('restore: invites and session prekeys made again (ok=$ok)');
    return ok;
  }

  @visibleForTesting
  Future<bool> healForTest(String peer, {int? now}) =>
      _askToStartAfresh(peer, now: now);

  @visibleForTesting
  Future<void> takeHealForTest(String peerXPub, Uint8List khb1) =>
      _takeHeal(peerXPub, khb1, 'heal-${khb1.hashCode}');

  // wipe a corrupt outbound session and rebuild it from the peer's stored
  // prekey bundle. false if we never kept a bundle: the caller then surfaces
  // the original failure.
  Future<bool> _healSession(String memberId) async {
    // the dev chat heals from the pinned card alone, in its own store
    final bundle = isDevId(memberId)
        ? (await devLane.seat(memberId))?.key.bundle
        : (await _reach(memberId))?.bundle;
    if (bundle == null || bundle.isEmpty) return false;
    final ss = await signalFor(memberId);
    if (ss == null) return false;
    try {
      // the session it replaces goes only once the new one is built: a
      // card that builds none (a 0.5.x one) leaves it as it was
      await ss.rebuild(memberId, lsBundleOf(ss.lib, bundle));
      dlog('healed session for $memberId');
      return true;
    } catch (e) {
      dlog('heal session failed for $memberId: $e');
      return false;
    }
  }

  // ship our prekey bundle to a peer over the gift-wrap transport: no
  // signal session needed, which is the point, since ours to them is broken.
  // want=true asks them to reset their session with us and send theirs back.
  // true once the relay took it
  Future<bool> _sendBundleCtl(
    String memberId, {
    required bool want,
    int? since,
  }) async {
    // the dev chat's bundle is pinned: nothing goes to him in the clear
    if (isDevId(memberId)) return false;
    // a decoy open: owed, and sent once the everyday side may send again
    if (everydayHeld) {
      if (since == null) {
        _ctlOwed[memberId] = want || (_ctlOwed[memberId] ?? false);
      }
      return false;
    }
    final key = '$memberId:$want';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_bundleCtlSentAt[key] ?? 0) < _bundleGap.inMilliseconds) {
      return false; // 1/min, not 1/chunk
    }
    _pruneHeal();
    _bundleCtlSentAt[key] = now;
    try {
      final to = await _reach(memberId);
      // nothing goes to someone blocked, not even keys
      if (to == null || await blockedAnywhere(memberId)) return false;
      final xpub = to.xpub;
      if (xpub.isEmpty) return false;
      // outside the session, so through the door as it is: the card of
      // the identity they know, and words only for the main one's
      // read from the rows, as the door reads it, and checked again there
      final ident = await identForSeal(memberId);
      final main = ident == kMainIdent;
      final payload = jsonEncode({
        'halo_ctl': 'bundle',
        if (main) 'from': myId,
        'bundle': main
            ? await _myBundle()
            : await makePreKeyBundleB64(await signalOfIdent(ident)),
        'want': want,
        'since': ?since,
      });
      final (on, framed) = await doorFor(memberId, payload, outside: true);
      // the card is the identity's it was made for, or nothing goes
      if (on != ident) return false;
      final r = await Future(() => _io.relaySend(on, xpub, framed));
      dlog('bundle ctl (want=$want) to $memberId: $r');
      return r == 'ok';
    } catch (e) {
      dlog('bundle ctl to $memberId failed: $e');
      return false;
    }
  }

  // a bundle ctl frame arrived off the relay. peerXPub is transport-
  // authenticated by the nip17 seal, so it must match the claimed sender's
  // stored xpub, and the bundle's identity key must match the pinned signal
  // identity. a valid frame backfills peer_bundle (pre-v30 pairings) and
  // rebuilds the corrupt session, so both sides converge without re-pairing.
  Future<void> _handleBundleCtl(String peerXPub, String raw, String h) async {
    final heal = healOfWire(raw);
    if (heal != null) return _takeHeal(peerXPub, heal, h);
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['halo_ctl'] != 'bundle') return;
      final from = j['from'] as String?;
      final bundle = j['bundle'] as String?;
      final want = j['want'] == true;
      final since = j['since'] is int ? j['since'] as int : null;
      if (from == null || bundle == null) return;
      // the pinned bundle is the dev chat's only one, and no one else may
      // speak for the developer
      if (devIdClaim(from)) {
        dlog('bundle ctl: claims the developer, dropped');
        return;
      }
      final to = await _reach(from);
      if (to == null) return;
      // someone blocked gets nothing back: no card, no session, no resend
      if (await blockedAnywhere(from)) return;
      if (to.xpub != peerXPub) {
        dlog('bundle ctl: xpub mismatch for $from, dropped');
        return;
      }
      final bj =
          jsonDecode(utf8.decode(base64Decode(bundle))) as Map<String, dynamic>;
      final claimed = base64Decode(bj['identityKey'] as String);
      // the store of the identity they know
      final ss = await signalOfIdent(identOf(from));
      final known = await ss.identityStore.getIdentity(from);
      // with none pinned yet, the key is the one their x key makes: the
      // relay vouched for that one
      final ok = known != null
          ? _eqBytes(known, claimed)
          : _eqBytes(_xIdentity(peerXPub.toLowerCase()) ?? const [], claimed);
      if (!ok) {
        dlog('bundle ctl: identity mismatch for $from, dropped');
        return;
      }
      // a card builds a first session only (an introduction). with one held
      // the heal is a KHB1, which shows and holds: a json card would
      // rebuild quietly whatever the sender chose
      if (await ss.hasSession(from)) {
        dlog('bundle ctl: a session is held with $from, refused');
        return;
      }
      // their frame came over the pair address: they read ours too
      // only the everyday side's: the list is kept for the phone, and goes
      // into everyday backups
      if (!to.backPaired && identical(to.on, live)) {
        unawaited(_notePairSeen(from));
      }
      // kept on the row, where there is one: a hidden chat's card holds no
      // bundle while the vault is shut
      await to.on?.setPeerBundle(from, bundle);
      var rebuilt = false;
      if (want || _healPending.remove(from) != null) {
        // the session it replaces is archived, so what they sealed on it
        // before still opens. one that does not read goes
        final LsBundle card;
        try {
          card = cardBundle(bundle);
        } on ClassicRefused {
          // a 0.5.x phone's card builds no session: theirs stays as it is
          dlog('bundle ctl: a card without a kyber prekey from $from');
          return;
        }
        try {
          await ss.processBundle(from, card);
        } on ClassicRefused {
          rethrow;
        } catch (e) {
          // one that does not read goes
          await ss.rebuild(from, card);
        }
        rebuilt = true;
        dlog('healed session for $from (bundle exchange)');
        unawaited(_owedDueFor(from));
      }
      // what waited on their card goes now
      _cardCame(from);
      if (want) {
        unawaited(_sendBundleCtl(from, want: false));
        // they asked because ours did not open there: what we sent them
        // lately that never came back delivered goes again, on the new
        // session. the same uid lands once. a hidden chat's waits sealed
        // for its vault to open
        final on = to.on;
        if (!rebuilt) return;
        if (on != null) {
          await _resendTo(on, from, since: since);
        } else {
          await _oweResend(from, since: since);
        }
        // and our group texts since their backup, which no receipt says
        // reached them. an ask with no backup date is no restore
        if (since != null) {
          await _resendGroupsAfterRestore(
            from,
            since: since,
            sealed: on == null,
          );
        }
      }
    } catch (e) {
      dlog('bundle ctl handle failed: $e');
    } finally {
      await live.markSeen(h);
    }
  }

  /// [id] is someone a shut vault holds: nothing here may show they are
  /// known
  // a key no screen here may name as blocked: the shut vault's, or one a
  // vault that went blocked, as the marks on the router say
  bool keyBlockedWhileShut(String keyHex) =>
      !sessionQuiet &&
      _router.keyBlockedUnseen(keyHex, vaultOpen: _openVault != null);
}
