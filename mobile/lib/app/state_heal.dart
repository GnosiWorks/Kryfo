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
    if (again > 0) {
      dlog('resend: $again undelivered to $peer go again');
      _bumpChatRev(peer);
      unawaited(drainOutbox());
    }
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

  // the card a seal starts a session afresh from, when the one held came
  // back with a restore. with none kept they are asked for theirs: their
  // answer leaves it on the row, and the outbox sends again
  Future<LsBundle?> _afreshCard(String peer) async {
    final card = (await _reach(peer))?.bundle;
    if (card != null && card.isNotEmpty) {
      try {
        // a 0.5.x card has no kyber prekey: it starts nothing, and theirs
        // is asked for as if none were kept
        final b = cardBundle(card);
        _waitingCard.remove(peer);
        return b;
      } catch (e) {
        dlog('afresh: their card does not read (${e.runtimeType})');
      }
    }
    _waitingCard.add(peer);
    // asked as the pass asks (SignalSession.askWait): a seal
    // tried again in between asks nothing
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_asking.containsKey(peer) && await signalSession.askDue(peer, now)) {
      unawaited(_askOnce(peer, now));
    }
    return null;
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

  Future<void> _askAfreshRound(int now) async {
    if (everydayHeld) return;
    if (!signalSession.ready || !signalSession.hasRestored) return;
    if (now - _afreshLookedAt < 10 * 60 * 1000) return;
    _afreshLookedAt = now;
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
    // the open vault's people too: one shut now is looked at on a later pass
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> people;
      try {
        people = await d.contacts();
      } catch (_) {
        continue;
      }
      for (final r in people) {
        if (left == 0 || everydayHeld) return;
        final id = r['halo_id'] as String;
        if (isDevId(id) || !await signalSession.askDue(id, now)) continue;
        if (await _askOnce(id, now)) left--;
      }
    }
  }

  @visibleForTesting
  Future<void> askAfreshForTest({int? now}) => _askAfresh(now: now);

  // [peer] asked to start a session with us afresh from our card. their
  // answer carries theirs, and ours starts afresh from it too. true once the
  // relay took the ask
  Future<bool> _askToStartAfresh(String peer, {int? now}) async {
    if (!await _io.hasSession(peer)) return false;
    // someone blocked is asked nothing, and their card would not be taken
    if (await _reach(peer) == null || await blockedAnywhere(peer)) {
      return false;
    }
    _wantHeal(peer);
    // their session came back with a restore: when the backup was made, to
    // the day, so they put out again what never reached us since
    final from = await signalSession.sealsOnRestored(peer)
        ? signalSession.restoredFrom
        : null;
    final ok = await _sendBundleCtl(
      peer,
      want: true,
      since: from == null ? null : utcDayOf(from),
    );
    if (ok) {
      await signalSession.noteAsked(
        peer,
        now ?? DateTime.now().millisecondsSinceEpoch,
      );
    }
    return ok;
  }

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
      final ident = identOf(memberId);
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
