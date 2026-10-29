// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: first contact, pair routes and the accept word

part of '../main.dart';

extension AppStatePairing on AppState {
  // a stranger's opener that signal opened and that did not file, onto disk
  // as it came, to be tried again. one that never opened is struck as any
  // other. the sender counts it in their share, or in the unnamed ones'
  // when a vault hides them. false when it was not kept
  Future<bool> _keepFirst(String h, String cipher, Reached? reached) async {
    final o = _firstOpened[h];
    if (o == null) return false;
    final peer = _routeOf(o.haloId, null) == RouteTo.everyday ? o.haloId : '';
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!await live.keepFirst(
        h,
        cipher,
        peer: peer,
        uid: o.env.msgUid,
        now: now,
        reached: reached,
        opened: (id: o.haloId, plain: o.plain),
      )) {
        firstFails.note('full');
        return false;
      }
      _firstDueAt(now + firstRetryGap(0).inMilliseconds);
      return true;
    } catch (e) {
      dlog('first contact: not kept (${e.runtimeType})');
      firstFails.note('unkept');
      return false;
    }
  }

  // the kept openers tried again: those due, or every one after an add, an
  // accept, a session change or a start. one pass at a time
  @visibleForTesting
  Future<void> retryFirsts({bool all = false}) async {
    if (all) _firstAll = true;
    final running = _firstPass;
    if (running != null) return running;
    final run = _firstRounds();
    _firstPass = run;
    try {
      await run;
    } finally {
      _firstPass = null;
    }
  }

  Future<void> _firstRounds() async {
    do {
      final all = _firstAll;
      _firstAll = false;
      await _firstRound(all: all);
    } while (_firstAll);
  }

  // the next pass at [at], unless one comes sooner already
  void _firstDueAt(int at) {
    if (_firstTimer != null && _firstTimerAt <= at) return;
    _firstTimer?.cancel();
    _firstTimerAt = at;
    _firstTimer = Timer(
      Duration(
        milliseconds: max(0, at - DateTime.now().millisecondsSinceEpoch),
      ),
      () {
        _firstTimer = null;
        unawaited(retryFirsts());
      },
    );
  }

  Future<void> _firstRound({required bool all}) async {
    // a quiet session runs nothing of the everyday side's
    if (sessionQuiet) return;
    int? soonest;
    // a chat hidden while its opener waited took it into the vault
    for (final d in [live, ?_openVault]) {
      final next = await _firstRoundIn(d, all: all);
      if (next != null && (soonest == null || next < soonest)) soonest = next;
    }
    if (soonest != null) _firstDueAt(soonest);
  }

  // one database's kept openers. when the soonest left falls due
  Future<int?> _firstRoundIn(HaloDb d, {required bool all}) async {
    if (haloWiping) return null;
    final List<FirstKept> rows;
    try {
      rows = await d.firstKept();
    } catch (e) {
      dlog('first contact: kept ones not read (${e.runtimeType})');
      return null;
    }
    int? soonest;
    for (final r in rows) {
      if (haloWiping) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      try {
        if (await live.alreadySeen(r.hash)) {
          await _forgetFirst(d, r.hash);
          continue;
        }
        // the relays let go of it by now, and so does this phone, for good
        if (now - r.at >= kFirstKeptFor.inMilliseconds) {
          firstFails.note('expired');
          await live.markSeenLong(r.hash);
          await _forgetFirst(d, r.hash);
          continue;
        }
        if (!all && r.nextAt > now) {
          if (soonest == null || r.nextAt < soonest) soonest = r.nextAt;
          continue;
        }
        // opened in an earlier process: what it opened to, not signal again
        final was = r.opened;
        if (was != null && _firstOpened[r.hash] == null) {
          _firstOpened.put(
            r.hash,
            _FirstOpen(was.id, was.plain, unwrapMessage(was.plain)),
          );
        }
        await _receiveRelayOne(
          (peer: 'firstcontact', cipher: r.cipher),
          () {},
          reached: r.reached,
          again: true,
        );
        // filed, or turned away for good: seen either way
        await _forgetFirst(d, r.hash);
        dlog('first contact: a kept opener went in');
      } catch (e) {
        // a full shelf waits for an accept, and one asked for ahead of its
        // time by an add or a start: neither uses a try
        final tries = e is ShelfFull || r.nextAt > now ? r.tries : r.tries + 1;
        if (tries >= kFirstKeptTries) {
          firstFails.note('gave up');
          await live.markSeenLong(r.hash);
          await _forgetFirst(d, r.hash);
          continue;
        }
        final next = now + firstRetryGap(tries).inMilliseconds;
        try {
          await d.retryFirstAt(r.hash, tries, next);
        } catch (_) {
          // read again as it was on the next pass
        }
        if (soonest == null || next < soonest) soonest = next;
      }
    }
    return soonest;
  }

  Future<void> _forgetAllFirst() async {
    try {
      await live.forgetAllFirst();
      await _openVault?.forgetAllFirst();
      // a shut vault lets go of its own as it next opens (trimFirstIn)
      await secureStore.write(
        key: _kFirstCut,
        value: '${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      dlog('first contact: kept ones not let go (${e.runtimeType})');
    }
  }

  static const _kFirstCut = 'first_kept_cut';

  // a vault opening: what it kept from before the invite key last moved
  // opens no more
  @visibleForTesting
  Future<void> trimFirstIn(HaloDb v) async {
    try {
      final cut = int.tryParse(await secureStore.read(key: _kFirstCut) ?? '');
      if (cut != null) await v.forgetFirstBefore(cut);
    } catch (e) {
      dlog('first contact: vault kept ones not read (${e.runtimeType})');
    }
  }

  Future<void> _forgetFirst(HaloDb d, String h) async {
    try {
      await d.forgetFirst(h);
    } catch (e) {
      dlog('first contact: kept one not let go (${e.runtimeType})');
    }
  }

  // relay backlog replays any cipher we can't land on every reconnect. give
  // it 3 lifetime chances (a session may still be forming), then mark it
  // seen so it stops bad-mac spamming every contact on every poll.
  void _strikeUndecryptable(String h, String lane) {
    final tries = (_decryptFails[h] ?? 0) + 1;
    _decryptFails[h] = tries;
    if (tries >= 3) {
      _decryptFails.remove(h);
      unawaited(live.markSeenLong(h));
      dlog('$lane: buried undecryptable after $tries tries');
    } else if (_decryptFails.length > 512) {
      _decryptFails.clear();
    }
  }

  // when an unknown sender's PreKey message arrives via
  // direct onion, decrypt under a placeholder peerId, then verify the
  // sender's claimed identity (via envelope) and move the libsignal
  // session to the real HaloID. someone the router keeps is filed by the
  // router, never as an everyday request. the id and where it went
  //
  // signal spends the prekey on the open, so one that fails after it is
  // kept as opened and throws: it goes on from there when it comes again
  Future<(String, RouteTo)?> backPairFromCipher(
    String cipher, {
    Reached? reached,
    InviteArrival? v4,
  }) async {
    final epoch = _openedEpoch;
    final k = sha256.convert(utf8.encode(cipher)).toString();
    // one copy at a time: another is not kept now and comes again
    if (!_firstInHand.add(k)) throw StateError('back-pair: a copy in hand');
    _FirstOpen? o;
    try {
      o = _firstOpened.take(k);
      if (o == null) {
        _receiver = this;
        final opened = v4 == null
            ? await _io.openFirstContact(cipher)
            : await _openFirst(cipher, v4: v4);
        if (opened == null) return null;
        o = _FirstOpen(opened.haloId, opened.plain, opened.env);
      }
      return await _backPairOpened(o, reached);
    } catch (e) {
      if (o != null && epoch == _openedEpoch) {
        _firstOpened.put(k, o);
        dlog('back-pair: kept as opened, not filed ($e)');
      }
      rethrow;
    } finally {
      _firstInHand.remove(k);
    }
  }

  Future<(String, RouteTo)?> _backPairOpened(
    _FirstOpen opened,
    Reached? reached,
  ) async {
    var h = opened.haloId;
    final env = opened.env;
    // the developer never starts a chat this way, and no one else may
    // claim to be him
    if (devCardClaim(id: h, xPub: env.senderXPub)) return null;
    await _afterClose();
    if (_moveDone != null) await _afterMove(h, null);
    // a hidden chat's name stays with its key as well
    if (!opened.refiled &&
        h == env.senderHaloId &&
        await _hiddenKeyDiffers(h, env)) {
      final at = await _refileFirstContact(h);
      if (at == null) return null;
      h = opened.haloId = at;
      opened.refiled = true;
    }
    final to = _routeOf(h, null);
    // a copy of one here or one that went (off a relay's backlog, say):
    // the row stays as it is, a request turned away stays turned away,
    // and only someone accepted hears again that it came
    final uid = env.msgUid;
    if (uid != null && (to == RouteTo.everyday || to == RouteTo.vault)) {
      final db = to == RouteTo.vault ? _openVault! : live;
      final have = await db.messageExists(uid);
      if (have || await db.goneFrom(h, uid)) {
        if (have && await db.isAccepted(h)) {
          unawaited(_sendDeliveryReceipt(h, uid));
        }
        return (h, RouteTo.dropped);
      }
    }
    // persist contact + nostr sub. a stranger who back-paired to us lands
    // unaccepted: their message waits in requests until we accept. while
    // the vault is shut its people are filed when it opens
    HaloDb? filed;
    var fresh = false;
    if (to == RouteTo.everyday || to == RouteTo.vault) {
      final db = to == RouteTo.vault ? _openVault! : live;
      // a removal under way, or a block that came meanwhile: nothing filed
      if (_removing.contains(h) ||
          await _keyBlockedHere(env.senderXPub ?? '')) {
        return (h, RouteTo.dropped);
      }
      filed = db;
      // as the first try found it: a row it made is still its own
      fresh = opened.fresh ??= await db.getContact(h) == null;
      await db.upsertContact(
        h,
        env.senderOnion ?? '',
        env.senderXPub ?? '',
        accepted: 0,
      );
      // filed on its own: the request says the name it gave
      final said = env.senderHaloId;
      if (said != null && said != h && await _saidHeldHere(said, db)) {
        await _noteOtherKey(db, h, said);
      }
    }
    final x = env.senderXPub;
    if (!opened.heard) {
      opened.heardAs = x == null ? null : _xPubToHaloId[x];
      opened.heard = true;
    }
    final heardAs = opened.heardAs;
    if (to != RouteTo.dropped && x != null && x.isNotEmpty) {
      _xPubToHaloId[x] = h;
      _io.listen(identOf(h), x);
    }
    var went = to;
    try {
      went = await _applyIncomingPayload(
        h,
        env,
        wire: opened.plain,
        fromBackPair: true,
        reached: reached,
      );
    } on CapHeld catch (e) {
      // the row exists now. kept as opened, let in on accept
      final into = e is _HeldIn ? e.into : filed;
      if (into != null) await _hold(into, h, opened.plain, env);
    } on _NoProof {
      // the session it opened goes, so nothing later from it opens
      // without the proof, and a row it made goes with it
      await _io.dropSession(h);
      if (fresh) {
        await filed?.forgetRequest(h);
        // the address it was heard on goes too, unless someone here has it
        if (x != null && x.isNotEmpty && _xPubToHaloId[x] == h) {
          if (heardAs == null) {
            _xPubToHaloId.remove(x);
            _io.unlisten(identOf(h), x);
          } else {
            _xPubToHaloId[x] = heardAs;
          }
        }
      }
      return (h, RouteTo.dropped);
    }
    if (AppState._shown(went)) {
      await refreshContacts();
      notifyListeners();
      await forgetPeerFc(h);
    }
    dlog('back-pair: done for $h');
    return (h, went);
  }

  // whether a hidden chat holds [id] with a key other than the one this
  // first contact gives
  Future<bool> _hiddenKeyDiffers(String id, UnwrappedMessage env) async {
    final card = _router.cardOf(id);
    final held = card != null
        ? _rowIdentity({'xpub': card.xpub})
        : _rowIdentity(await _openVault?.getContact(id));
    if (held == null) return false;
    final given = _rowIdentity({'xpub': env.senderXPub ?? ''});
    return given == null || !_eqBytes(held, given);
  }

  // the name a first contact gave is someone's here: a row, or words let
  // go, on the everyday side or in the vault it is filed in. an everyday
  // request outlasts the vault being open, so it never learns of the
  // vault's people. what only the router knows, a shut vault's people and
  // its marks, files the sender apart and says nothing
  Future<bool> _saidHeldHere(String said, HaloDb into) async {
    for (final d in [live, if (!identical(into, live)) into]) {
      if (await d.getContact(said) != null || await d.tombed(said)) {
        return true;
      }
    }
    return false;
  }

  // a request filed on its own id says which name it gave, once
  Future<void> _noteOtherKey(HaloDb db, String id, String said) async {
    final hit = ShieldHit('other_key', said).toJson();
    await db.setShield(id, jsonEncode(hit), [hit]);
  }

  /// [id] came on a friend's card and no first-contact address of theirs is
  /// known: copies go to the pair address, which they read if they took our
  /// card too. an ok there counts only once they showed it (pairRead)
  Future<bool> pairRoute(String id, {required bool backPaired}) async {
    if (backPaired || _hasFc(id)) return false;
    try {
      return await _ownerOf(id).isVouched(id);
    } catch (e) {
      dlog('send: vouch not read (${e.runtimeType})');
      return false;
    }
  }

  bool _hasFc(String id) {
    final fc = peerFcFor(id);
    return fc != null && fc.isNotEmpty;
  }

  Future<void> _loadPairSeen() async {
    if (_pairSeenRead) return;
    final load = _pairSeenLoad ??= _readPairSeen();
    try {
      await load;
    } finally {
      // a read that failed is tried again by the next caller
      if (!_pairSeenRead && identical(_pairSeenLoad, load)) {
        _pairSeenLoad = null;
      }
    }
  }

  Future<void> _readPairSeen() async {
    final List<String> stored;
    try {
      final raw = await secureStore.read(key: 'pair_read');
      stored = raw == null || raw.isEmpty
          ? const []
          : (jsonDecode(raw) as List).cast<String>();
    } catch (e) {
      dlog('pair read: unreadable, kept as it is (${e.runtimeType})');
      return;
    }
    // what the list should never hold, whatever an earlier process missed:
    // someone the vault keeps, or who added us back. the read stays undone
    // meanwhile, so every other caller waits on this one
    final drop = <String>{...stored.where(_router.keeps)};
    for (final id in stored) {
      if (drop.contains(id)) continue;
      try {
        if (await live.isBackPaired(id)) drop.add(id);
      } catch (e) {
        dlog('pair read: not checked (${e.runtimeType})');
      }
    }
    // and what was let go of before the read could be made
    drop.addAll(_pairForgot);
    _pairForgot.clear();
    _pairSeen.addAll(stored.where((id) => !drop.contains(id)));
    if (stored.any(drop.contains)) await _keepPairSeen();
    _pairSeenRead = true;
  }

  Future<void> _notePairSeen(String id) async {
    await _loadPairSeen();
    if (!_pairSeenRead || !_pairSeen.add(id)) return;
    await _keepPairSeen();
  }

  // added us back, deleted, or moved into the vault
  Future<void> _forgetPairSeen(Set<String> ids) async {
    await _loadPairSeen();
    if (!_pairSeenRead) {
      _pairForgot.addAll(ids);
      return;
    }
    final before = _pairSeen.length;
    _pairSeen.removeAll(ids);
    if (_pairSeen.length == before) return;
    await _keepPairSeen();
  }

  Future<void> _keepPairSeen() async {
    try {
      await secureStore.write(
        key: 'pair_read',
        value: jsonEncode(_pairSeen.toList()),
      );
    } catch (e) {
      dlog('pair read: not kept (${e.runtimeType})');
    }
  }

  // tells a just-accepted stranger they're in. the empty frame flips their
  // back_paired on arrival, which melts their request lock without waiting
  // for our first reply. true when a send of it was taken
  Future<bool> sendAcceptAck(String haloId) async {
    try {
      return await _ackWire(haloId);
    } catch (e) {
      dlog('accept ack failed: $e');
      return false;
    }
  }

  // as sendAcceptAck, but a seal that waits on a key check or on their
  // card throws
  Future<bool> _ackWire(String haloId) async {
    final wrapped = await wrapMessage('', sender: _mySender());
    return _sendOneEnvelope(haloId, wrapped, holdThrows: true);
  }

  // on their row in the container that holds them, before the first try.
  // false when it was not kept
  Future<bool> _oweAck(String haloId) async {
    try {
      await session.setAckOwed(haloId, true);
      return true;
    } catch (e) {
      dlog('accept ack: not kept (${e.runtimeType})');
      return false;
    }
  }

  Future<void> _ackOnAccept(String haloId) async {
    if (await _oweAck(haloId)) {
      await _sendAckOf(_ownerOf(haloId), haloId);
    } else {
      // one try all the same
      await sendAcceptAck(haloId);
    }
  }

  // one send of what [d] owes them, one at a time. the mark goes only once
  // a send was taken, and a send that finds it gone already sends nothing.
  // null when the seal waits on a key check or on their card
  Future<bool?> _sendAckOf(HaloDb d, String haloId) async {
    final key = d.container.chatKey(haloId);
    if (!_acksGoing.add(key)) return false;
    try {
      if (!await d.isAckOwed(haloId)) return true;
      try {
        if (!await _ackWire(haloId)) return false;
      } on KeyHeld {
        return null;
      } on StartingAfresh {
        return null;
      }
      await d.setAckOwed(haloId, false);
      _ackTries.remove(key);
      _ackNextAt.remove(key);
      return true;
    } catch (e) {
      dlog('accept ack: ${e.runtimeType}');
      return false;
    } finally {
      _acksGoing.remove(key);
    }
  }

  Future<void> _drainAcks() =>
      _ackPass ??= _ackRound().whenComplete(() => _ackPass = null);

  @visibleForTesting
  Future<void> drainAcksForTest() => _drainAcks();

  @visibleForTesting
  void ackTriesForTest(HaloDb d, String haloId, int n) =>
      _ackTries[d.container.chatKey(haloId)] = n;

  // tried as long as a queued reaction is: their chat says they may not
  // know, and offers to try again
  Future<bool> _letAckGo(HaloDb d, String haloId, String key) async {
    try {
      await d.loseAck(haloId);
      dlog('accept ack: let go after $kFrameTries tries');
    } catch (e) {
      dlog('accept ack: not let go (${e.runtimeType})');
    }
    _ackTries.remove(key);
    _ackNextAt.remove(key);
    if (identical(_ownerOf(haloId), d)) {
      _bumpChatRev(haloId);
      notifyListeners();
    }
    return false;
  }

  // the line's button: owed again, from a fresh count. a quiet session
  // shows no line and sends nothing
  Future<void> retryAck(String haloId) async {
    if (sessionQuiet) return;
    final d = _ownerOf(haloId);
    try {
      if (!await d.retryAck(haloId)) return;
    } catch (e) {
      dlog('accept ack: not owed again (${e.runtimeType})');
      return;
    }
    final key = d.container.chatKey(haloId);
    _ackTries.remove(key);
    _ackNextAt.remove(key);
    _bumpChatRev(haloId);
    notifyListeners();
    unawaited(_drainAcks());
  }

  Future<void> _ackRound() async {
    final going = <Future<bool?>>[];
    for (final d in [live, ?_openVault]) {
      if (!linkUp || haloWiping || everydayHeld) break;
      final List<String> owed;
      try {
        owed = await d.ackOwed();
      } catch (e) {
        dlog('accept ack: none read (${e.runtimeType})');
        continue;
      }
      for (final id in owed) {
        if (everydayHeld) break;
        // moved since, or another container's
        if (!identical(_ownerOf(id), d)) continue;
        final key = d.container.chatKey(id);
        if (_acksGoing.contains(key)) continue;
        final now = DateTime.now().millisecondsSinceEpoch;
        final next = _ackNextAt[key];
        if (next != null && now < next) continue;
        final tries = _ackTries[key] ?? 0;
        // tried as long as a queued reaction is, then let go
        if (tries >= kFrameTries) {
          going.add(_letAckGo(d, id, key));
          continue;
        }
        _ackTries[key] = tries + 1;
        _ackNextAt[key] = now + queueGap(tries);
        going.add(
          _sendAckOf(d, id).then((r) {
            // waiting on a key check or their card is no failed try
            if (r == null) {
              _ackTries[key] = tries;
              _ackNextAt[key] = now + 600000;
            }
            return r;
          }),
        );
      }
    }
    await Future.wait(going);
  }
}
