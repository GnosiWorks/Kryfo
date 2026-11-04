// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: listening and receiving: onion, relays and opening

part of '../main.dart';

extension AppStateReceive on AppState {
  void chatFirst(String? haloId) {
    // the dev chat's lane is its own, and nothing of it goes before it starts
    if (haloId != null && isDevId(haloId)) haloId = null;
    _firstChat = haloId;
    unawaited(_tellFirst());
  }

  // the key from the contact's row, else from what is listened on. told
  // again when the chat's key comes later (subscribePeer)
  Future<void> _tellFirst() async {
    final id = _firstChat;
    var key = '';
    if (id != null) {
      try {
        key = (await _reach(id))?.xpub ?? '';
      } catch (e) {
        dlog('first: no row (${e.runtimeType})');
      }
      if (key.isEmpty) {
        for (final e in _xPubToHaloId.entries) {
          if (e.value == id) {
            key = e.key;
            break;
          }
        }
      }
    }
    // another chat opened while this read
    if (_firstChat != id || key == _firstKey) return;
    _firstKey = key;
    try {
      engine.nostrFirst(key);
    } catch (e) {
      dlog('first: not told (${e.runtimeType})');
    }
  }

  // a vault that just shut: nothing is opened or filed until the list it
  // leaves names everyone it took in while it was open
  Future<void> _afterClose() async {
    final closing = _closeDone;
    if (closing != null) await closing.future;
  }

  // the ids the router keeps and the people the open vault holds: tried
  // like contacts, never filed as everyday requests
  Set<String> _keptIds() => {
    ..._router.ids,
    ..._moving,
    if (_openVault != null) ..._session.hiddenPeople,
  };

  // a message tried under everyone who may have sent it: everyday contacts,
  // then everyday requests, then the kept ids. never the screen's list,
  // which belongs to whichever session is open
  Future<({String id, String plain})?> _openKnown(
    String cipher, {
    String? skip,
    Map<String, Set<String>> full = const {},
  }) async {
    await _afterClose();
    final tried = <String>{?skip};
    Future<({String id, String plain})?> under(Iterable<String> ids) async {
      for (final id in ids) {
        // never the dev chat: only its own lanes carry the developer
        if (isDevId(id) || !tried.add(id)) continue;
        final p = await _open(id, cipher, full);
        if (p != null) return (id: id, plain: p);
      }
      return null;
    }

    return await under([
          for (final r in await live.contacts()) r['halo_id'] as String,
        ]) ??
        await under([
          for (final r in await live.pendingRequests()) r['halo_id'] as String,
        ]) ??
        await under(_keptIds());
  }

  // a stranger whose shelf is full in [full]: what they send that would want
  // a place on it is turned down before signal spends its key, and waits on
  // the relay (ShelfFull)
  Future<String?> _open(
    String id,
    String cipher,
    Map<String, Set<String>> full, {
    bool flagKeyChange = false,
  }) async {
    final files = full[id];
    if (files == null) {
      return _io.decrypt(id, cipher, flagKeyChange: flagKeyChange);
    }
    UnwrappedMessage? env;
    try {
      return await _io.decryptIf(id, cipher, (p) {
        env = unwrapMessage(p);
        return !AppState.wantsShelfPlace(env!, files);
      }, flagKeyChange: flagKeyChange);
    } on ShelfFull {
      // who sent it, and the file it is of, for the relay to hold it under
      throw ShelfFull(peer: id, group: env?.mediaId ?? '');
    }
  }

  // strangers whose shelf is full, [only] or all, in the container their
  // chat is in now. a shut vault is not read
  Future<Map<String, Set<String>>> _fullShelves({String? only}) async {
    final v = _openVault;
    return {
      for (final e in (await live.fullShelves(only: only)).entries)
        if (_routeOf(e.key, null) == RouteTo.everyday) e.key: e.value,
      if (v != null)
        for (final e in (await v.fullShelves(only: only)).entries)
          if (_routeOf(e.key, null) == RouteTo.vault) e.key: e.value,
    };
  }

  // a peer we deleted keeps its session but loses its contact row, so the
  // tries above skip it. their next message is a plain whisper back-pair
  // can't rebuild: try any sessioned address that is not an everyday
  // contact or kept by the router, to re-file it as a fresh request
  Future<({String id, String plain})?> _openParked(String cipher) async {
    await _afterClose();
    final skip = {
      for (final r in await live.contacts()) r['halo_id'] as String,
      ..._keptIds(),
      '_pending_back_pair_',
    };
    for (final addr in await _io.sessionAddresses()) {
      // a deleted dev chat stays deleted, whatever session is left, and one
      // being taken off this phone is not brought back
      if (skip.contains(addr) || isDevId(addr) || _removing.contains(addr)) {
        continue;
      }
      final p = await _io.decrypt(addr, cipher);
      if (p == null) continue;
      // and a peer let go does not come back as the developer
      if (devCardClaim(id: addr, xPub: unwrapMessage(p).senderXPub)) {
        return null;
      }
      return (id: addr, plain: p);
    }
    return null;
  }

  // the key a deleted peer who writes again is filed under: the one their
  // session runs on, never one the frame names. null when the frame claims
  // another, or when someone accepted holds that key
  Future<String?> _parkedKey(String addr, String? claimed) async {
    final x = (await _io.sessionXPub(addr)) ?? '';
    if (x.isEmpty) return null;
    final c = (claimed ?? '').trim();
    if (c.isNotEmpty && c.toLowerCase() != x.toLowerCase()) return null;
    final holder = _xPubToHaloId[x];
    if (holder != null &&
        holder != addr &&
        (_router.keeps(holder) || await live.isAccepted(holder))) {
      return null;
    }
    return x;
  }

  @visibleForTesting
  Future<void> get listenedAtStart => _listened.future;
  @visibleForTesting
  set bootingForTest(bool b) => _booting = b;
  @visibleForTesting
  void signalReadyForTest() {
    if (!_signalReady.isCompleted) _signalReady.complete();
  }

  void listenAtStart() {
    if (_listenArmed) return;
    _listenArmed = true;
    void go() {
      if (_listened.isCompleted) return;
      _listened.complete(_listenNow());
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Timer(const Duration(milliseconds: 300), go),
    );
    Timer(noFrameWait, go);
  }

  // a job's kick asks the relays for what they hold on the keys listened
  // on, so those are all in first
  Future<void> _listenedFirst({
    Duration wait = const Duration(seconds: 30),
  }) async {
    // a boot still under way arms it soon: the job can knock before that
    if (!_listenArmed && !_booting) return;
    await _listened.future.timeout(
      wait,
      onTimeout: () => dlog('listen: not done before the kick'),
    );
  }

  Future<void> _listenNow() async {
    // rooms first, on their own: a hang anywhere in the contact loop
    // below must not leave a live room deaf after a restart.
    try {
      await _subscribeRooms();
    } catch (e) {
      dlog('rooms: boot subscribe failed: $e');
    }
    // the dev chat's lane, only once it has started
    try {
      await subscribeDevLane();
    } catch (e) {
      dlog('dev lane: boot subscribe failed: $e');
    }
    unawaited(sweepCaptures());
    await markHeldAtStart();
    await _signalReady.future.timeout(
      signalWait,
      onTimeout: () => dlog('listen: signal not ready, contacts go on'),
    );
    // my v4 invites kept, and each live one listened on
    try {
      await keepMyInvites();
    } catch (e) {
      dlog('invites: not kept (${e.runtimeType})');
    }
    // the held chats' pq restarts, once the store is ready
    unawaited(pqUpkeepDue());
    var heard = <String>{};
    var short = true;
    try {
      final r = await _listenKnown(cache: true);
      heard = r.keys;
      short = r.short;
    } catch (e) {
      dlog('contacts: boot subscribe failed: $e');
    }
    if (short) _listenAgainLater(heard);
    // openers kept from before this start
    unawaited(retryFirsts(all: true));
  }

  // once, for whoever the start missed. still short after that, the next
  // mode switch listens to everyone again
  void _listenAgainLater(Set<String> heard) {
    Timer(listenRetryGap, () async {
      if (haloWiping) return;
      try {
        final r = await _listenKnown(cache: true, skip: heard);
        if (r.short) _resubscribeDue = true;
        dlog('contacts: listened again${r.short ? ', still short' : ''}');
      } catch (e) {
        _resubscribeDue = true;
        dlog('contacts: listen again failed: $e');
      }
    });
  }

  // listen for everyone who can write: accepted contacts, people a friend
  // introduced and strangers in requests, and the people of the hidden
  // chats. those never go into the cache on disk
  @visibleForTesting
  Future<void> subscribeKnown() async {
    await _listenKnown(cache: true);
  }

  // listens on [xPub]. a hidden chat's address keeps a relay socket and a
  // circuit of its own; [hidden] null asks the vault's cards. a key once
  // told hidden stays hidden until an unhide moves it out, so a chat
  // deleted inside the vault never joins the everyday sockets
  void _listen(int ident, String xPub, {bool fresh = false, bool? hidden}) {
    if (hidden ?? (_router.hidesKey(xPub) || _toldHidden.contains(xPub))) {
      _toldHidden.add(xPub);
      _io.listenHidden(ident, xPub, fresh: fresh);
    } else {
      _toldHidden.remove(xPub);
      _io.listen(ident, xPub, fresh: fresh);
    }
  }

  // after chats went into the vault or came out: each key listened on the
  // other way is listened on again, so its address leaves the everyday
  // sockets or joins them. only the keys an unhide moved out ([out]) go
  // back: one whose chat was deleted inside the vault stays apart
  void _relistenMoved({Set<String> out = const {}}) {
    try {
      for (final e in _router.listenFor.entries) {
        if (!_toldHidden.contains(e.key)) _listen(identOf(e.value), e.key);
      }
      for (final x in _toldHidden.toList()) {
        if (_router.hidesKey(x) || !out.contains(x)) continue;
        final who = _xPubToHaloId[x];
        if (who == null) {
          _toldHidden.remove(x);
          continue;
        }
        _listen(identOf(who), x, hidden: false);
      }
    } catch (e) {
      // the runners keep their sockets until the next start listens again
      dlog('listen: moved chats not listened again (${e.runtimeType})');
    }
  }

  // the keys it listened on, and whether anyone was missed. [skip]: keys
  // already listened on, their runners left as they are
  Future<({Set<String> keys, bool short})> _listenKnown({
    bool cache = false,
    Set<String> skip = const {},
  }) async {
    // who is on an identity of their own, and those identities in the
    // engine before anything listens on them
    await loadIdents();
    // every seeded pair's seed in the engine before the first listen: a
    // call that comes without it is refused there as well
    await pushPairSeeds();
    // subscribe off the xpub stored on the contact row, the same key the
    // send path uses. the signal store has none until a session exists, so
    // the scanned side could never receive the first message.
    // people we have not accepted yet listen too: someone a friend
    // introduced, and any stranger already sitting in requests. their
    // second message rides the pair address, or it waits on the relay
    // until we accept them.
    final rows = bootSubscribeRows(
      accepted: await live.contacts(),
      vouchedPending: await live.vouchedPending(),
      pendingRequests: [
        ...await live.pendingRequests(),
        ...await live.parkedRequests(),
      ],
      blocked: [
        for (final r in await live.blockedRows(
          now: DateTime.now().millisecondsSinceEpoch,
        ))
          if (r['listen'] == 1) r,
      ],
    );
    // the pinned chats go first on the public relays, told before any
    // runner starts. the everyday rows only: a hidden chat ranks like any
    // other whether the vault is open or shut
    await _pinFirst(rows);
    final fresh = <String, String>{};
    final ours = <String, String>{};
    var short = false;
    // each on its own: one that throws leaves the rest listened on
    for (final r in rows) {
      final haloId = r['halo_id'] as String?;
      if (haloId == null) continue;
      try {
        var xPub = r['xpub'] as String?;
        // v2 bundle pairing stores an empty xpub on the row: the key only
        // lands in the signal store, which processPeerBundle fills at pair
        // time. v1 stores it on the row and has no session yet. take
        // whichever exists, then backfill the row so the next boot is cheap.
        if (xPub == null || xPub.isEmpty) {
          // with no signal yet the store says nothing: tried again later
          if (!signalSession.ready) short = true;
          xPub = await peerXPubOf(haloId);
          if (xPub != null && xPub.isNotEmpty) {
            try {
              await live.setContactXPub(haloId, xPub);
            } catch (e) {
              // a saving only: the key is listened on all the same
              dlog('listen: key not kept on the row (${e.runtimeType})');
            }
          }
        }
        if (xPub == null || xPub.isEmpty) continue;
        // a key someone else is heard on stays theirs
        if (r['blocked'] == 1 && _heardAsOther(xPub, haloId)) continue;
        // and a request never takes the key of a chat accepted here
        final holder = ours[xPub];
        if (holder != null && holder != haloId) continue;
        if (r['accepted'] == 1) ours[xPub] = haloId;
        _xPubToHaloId[xPub] = haloId;
        if (!skip.contains(xPub)) _listen(identOf(haloId), xPub);
        fresh[xPub] = haloId;
      } catch (e) {
        short = true;
        dlog('listen: one not listened for (${e.runtimeType})');
      }
    }
    final hidden = {
      for (final e in _router.listenFor.entries)
        if (!_router.blocks(e.value) || !_heardAsOther(e.key, e.value))
          e.key: e.value,
    };
    final heard = <String>{};
    for (final h in hidden.entries) {
      try {
        _xPubToHaloId[h.key] = h.value;
        if (!skip.contains(h.key)) {
          _listen(identOf(h.value), h.key, hidden: true);
        }
        heard.add(h.key);
      } catch (e) {
        short = true;
        dlog('listen: a hidden one not listened for (${e.runtimeType})');
      }
    }
    if (cache) {
      try {
        await _saveXPubCache(fresh);
      } catch (e) {
        dlog('listen: cache not saved (${e.runtimeType})');
      }
    }
    return (keys: {...fresh.keys, ...heard}, short: short);
  }

  Future<void> _pinFirst(List<Map<String, Object?>> rows) async {
    final pins = <(int, String)>[];
    for (final r in rows) {
      if (r['pinned'] != 1) continue;
      final ident = identOf(r['halo_id'] as String? ?? '');
      var xPub = r['xpub'] as String?;
      if (xPub == null || xPub.isEmpty) {
        final haloId = r['halo_id'] as String?;
        if (haloId == null) continue;
        try {
          xPub = await peerXPubOf(haloId);
        } catch (_) {
          continue;
        }
      }
      if (xPub != null && xPub.isNotEmpty) pins.add((ident, xPub));
    }
    // the engine starts with none and keeps what it was told
    final told = ([for (final (i, x) in pins) '$i:$x']..sort()).join(',');
    if (told == _pinsTold) return;
    try {
      await _io.pinFirst(pins);
      _pinsTold = told;
    } catch (e) {
      // the order only: everyone is listened on all the same
      dlog('listen: pins not told (${e.runtimeType})');
    }
  }

  bool _heardAsOther(String xPub, String haloId) {
    final heard = _xPubToHaloId[xPub];
    return heard != null && heard != haloId;
  }

  // a block older than kBlockListenFor is listened on no more: the relays
  // hold nothing from its time now. a key someone else is heard on stays.
  // the vault's blocked go by their cards, on the same sweep whether it is
  // open or shut
  @visibleForTesting
  Future<void> unlistenOldBlocks() async {
    if (sessionQuiet) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final old = {
        for (final r in await live.blockedRows(now: now))
          if (r['listen'] != 1) r['halo_id'] as String,
      };
      final hidden = _router.listenFor;
      for (final e in _xPubToHaloId.entries.toList()) {
        final kept = _router.keeps(e.value);
        final gone = kept
            ? _router.blocks(e.value) && hidden[e.key] != e.value
            : old.contains(e.value);
        if (!gone) continue;
        _xPubToHaloId.remove(e.key);
        _io.unlisten(identOf(e.value), e.key);
      }
    } catch (e) {
      dlog('old blocks: still listened on ($e)');
    }
  }

  // what the onion inbox held. an arrival for a hidden chat while its vault
  // is shut changes nothing here: no refresh, and the transport screen does
  // not count it
  @visibleForTesting
  Future<void> receiveOnion(List<String> ciphers) async {
    // each drain takes all the inbox holds: what this one brings came here
    // after the one before it
    final since = _onionDrainedAt;
    _onionDrainedAt = DateTime.now().millisecondsSinceEpoch;
    Reached came() =>
        (from: since, until: DateTime.now().millisecondsSinceEpoch);
    var noted = false;
    void arrived() {
      if (noted) return;
      noted = true;
      // the onion lane counts as an arrival too, or the night's record
      // would call a phone that only heard direct messages deaf
      _noteDrain();
    }

    for (final cipher in ciphers) {
      // dedup: same msg can arrive twice (tor late + nostr, or a retry).
      // the first copy consumes the one-time prekey; a duplicate would
      // crash on it, so skip anything we've already handled.
      final h = sha256.convert(utf8.encode(cipher)).toString();
      if (await live.alreadySeen(h)) {
        arrived();
        continue;
      }
      if (cipher.startsWith('{')) {
        // ctl frames only ride the authenticated relay lane. raw json
        // in the onion inbox is junk: bury it without trial decrypts.
        arrived();
        _strikeUndecryptable(h, 'drain');
        continue;
      }
      var handled = false;
      var shown = true;
      final ({String id, String plain})? known;
      try {
        known = await _openKnown(cipher, full: await _fullShelves());
      } on ShelfFull catch (e) {
        // nothing waits on this lane: the copy is kept as it came, unopened
        // and neither seen nor struck. its relay copy waits there
        await _overflow(e.peer, cipher);
        arrived();
        continue;
      }
      if (known != null) {
        final env = unwrapMessage(known.plain);
        // a typing frame shows or goes: no row, no seen hash, no ring
        if (env.typing) {
          // never one that opened a session: its one-time key is spent, so
          // it is marked as seen and goes unshown
          if (_isPreKeyWire(cipher)) {
            await live.markSeen(h);
          } else {
            await _typingCame(known.id, env);
          }
          continue;
        }
        try {
          shown = AppState._shown(
            await _applyIncomingPayload(
              known.id,
              env,
              wire: known.plain,
              reached: came(),
            ),
          );
        } on CapHeld catch (e) {
          // no relay to replay from: kept here, let in on accept
          await _hold(e is _HeldIn ? e.into : live, known.id, known.plain, env);
        }
        if (shown) notifyListeners();
        handled = true;
      }
      if (!handled) {
        final parked = await _openParked(cipher);
        // nobody is filed again on a typing frame
        if (parked != null && unwrapMessage(parked.plain).typing) continue;
        final parkedX = parked == null
            ? null
            : await _parkedKey(
                parked.id,
                unwrapMessage(parked.plain).senderXPub,
              );
        if (parked != null && parkedX == null) {
          // its key was spent opening it: buried, never filed
          dlog('drain: a deleted peer\'s frame on another key, dropped');
          handled = true;
        } else if (parked != null) {
          final addr = parked.id;
          final env = unwrapMessage(parked.plain);
          await live.upsertContact(
            addr,
            env.senderOnion ?? '',
            parkedX!,
            accepted: 0,
          );
          _xPubToHaloId[parkedX] = addr;
          try {
            // someone we let go who writes on in the old chat: their session
            // proves them, and their client grinds nothing for it. a request
            // again, under the cap and the shelf as any other, as the relay
            // lane has it. only a block keeps them out
            await _applyIncomingPayload(
              addr,
              env,
              wire: parked.plain,
              reached: came(),
            );
          } on CapHeld catch (e) {
            await _hold(e is _HeldIn ? e.into : live, addr, parked.plain, env);
          }
          await refreshContacts();
          notifyListeners();
          handled = true;
          dlog('drain: recovered deleted peer $addr into requests');
        }
      }
      var kept = false;
      if (!handled && _isPreKeyWire(cipher)) {
        (String, RouteTo)? paired;
        try {
          paired = await backPairFromCipher(cipher, reached: came());
        } on FirstRefused catch (e) {
          // it never opens here: buried at once
          firstFails.note(e.why);
          await live.markSeenLong(h);
          if (shown) arrived();
          continue;
        } catch (e) {
          dlog('drain: back-pair threw ($e)');
          firstFails.note('file');
        }
        handled = paired != null;
        if (paired != null) shown = AppState._shown(paired.$2);
        dlog('drain: back-pair ${paired != null ? "ok" : "failed"}');
        // the door acked it already and nothing brings it again: kept on
        // disk as it came, and tried again
        if (!handled) kept = await _keepFirst(h, cipher, came());
      }
      // only now is it safe to burn the dedup hash: the prekey is spent
      // and the message is filed. an unhandled cipher stays un-seen so a
      // later pass (or the relay replay) can still land it.
      if (handled) {
        await live.markSeen(h);
      } else if (!kept) {
        _strikeUndecryptable(h, 'drain');
      }
      if (shown) arrived();
    }
  }

  // what the relays held, as the onion inbox above. the places in msgs of
  // those it could not keep, which the engine offers again
  @visibleForTesting
  Future<Set<int>> receiveRelay(
    List<({String peer, String cipher})> msgs, {
    // when each was wrapped, by the sender's clock, where the lane says
    List<int?> written = const [],
    // when each reached the relay, by this clock, where the engine says
    List<Reached?> reached = const [],
    // filled with the places of those a full shelf leaves on the relay,
    // each with the file it is a slice of, or empty
    Map<int, String>? held,
  }) async {
    var noted = false;
    void arrived() {
      if (noted) return;
      noted = true;
      _noteDrain();
    }

    // one sender's messages in the order they were sent, strangers' openers
    // and room members included
    final ordered = roomsInSendOrder(
      inSendOrder(
        [
          for (var i = 0; i < msgs.length; i++)
            (at: i, peer: msgs[i].peer, cipher: msgs[i].cipher),
        ],
        peer: (m) => m.peer,
        cipher: (m) => m.cipher,
        lane: keepsArrivalOrder,
      ),
      peer: (m) => m.peer,
      place: (m) => roomFramePlace(m.cipher),
    );
    final failed = <int>{};
    final left = <int, ShelfFull>{};
    for (final m in ordered) {
      // each on its own: one that throws comes again, the rest stay kept
      try {
        await _receiveRelayOne(
          (peer: m.peer, cipher: m.cipher),
          arrived,
          wrappedAt: m.at < written.length ? written[m.at] : null,
          reached: m.at < reached.length ? reached[m.at] : null,
        );
      } on _KnockWaits {
        failed.add(m.at);
      } on _FirstWaits {
        // offered again, never acked: its kept copy is tried meanwhile
        failed.add(m.at);
      } on ShelfFull catch (e) {
        dlog('relay: a full shelf leaves one on the relay');
        left[m.at] = e;
      } catch (e, st) {
        dlog('relay: one not kept, it comes again ($e)\n$st');
        failed.add(m.at);
      }
    }
    // an accept, a block or a cleared shelf while the batch ran: those come
    // again now rather than wait on the relay
    final still = <String, bool>{};
    for (final e in left.entries) {
      final p = e.value.peer;
      final full =
          p != null &&
          (still[p] ??= (await _fullShelves(only: p)).containsKey(p));
      if (full && held != null) {
        held[e.key] = e.value.group;
      } else {
        failed.add(e.key);
      }
    }
    return failed;
  }

  // what was opened goes with the session it was opened under, and with a
  // wipe. whatever comes again after this is opened again or not at all
  void _dropOpened() {
    _relayOpened.clear();
    _firstOpened.clear();
    // and why the last first contacts failed: a report from the next one
    // says nothing of this one
    firstFails.clear();
    _dropEarly();
    _openedEpoch++;
    // and who was typing, in a session that is no longer the one on screen
    _typingClear();
  }

  void _keepOpened(
    String h,
    String id,
    String plain,
    int epoch, {
    bool parked = false,
  }) {
    if (epoch != _openedEpoch) return;
    _relayOpened.put(h, (id: id, plain: plain, parked: parked));
  }

  Future<void> _receiveRelayOne(
    ({String peer, String cipher}) m,
    void Function() arrived, {
    int? wrappedAt,
    Reached? reached,
    // a kept opener tried again (retryFirsts): one that fails is not kept
    // a second time
    bool again = false,
  }) async {
    // what it opens to is kept only under the session it began in
    final epoch = _openedEpoch;
    // dedup: skip a message we've already handled (see direct-onion note).
    final h = sha256.convert(utf8.encode(m.cipher)).toString();
    if (await live.alreadySeen(h)) {
      arrived();
      return;
    }
    // his lanes are the dev chat's alone, and only while it runs on them
    if (devKeyOfTag(m.peer) != null) {
      if (await _receiveDev(m.peer, m.cipher, h, epoch, reached)) {
        notifyListeners();
      }
      arrived();
      return;
    }
    // a device pair's line (linked devices): opened on that device's
    // session and admitted before anything shows, never tried as a phone's
    if (linkedDevicesOn && deviceTagOf(m.peer) != null) {
      await _receiveDeviceCopy(
        m,
        h,
        epoch,
        arrived,
        wrappedAt: wrappedAt,
        reached: reached,
      );
      return;
    }
    // a room frame: opened by the room key already, never signal. one that
    // throws is not kept and comes again
    if (m.peer.startsWith('room:') || m.peer.startsWith('roomfc:')) {
      // seen by the bytes that came, kept without the filler
      final content = unpad(m.cipher);
      // a knock on a room busy with a reset waits on its own, and the
      // inbox goes on. it is offered again until it is seen
      if (m.peer.startsWith('roomfc:') && _roomBusy(content)) {
        _knockLater(m.peer, content, h, reached);
        throw const _KnockWaits();
      }
      await _handleRoomFrame(m.peer, content, reached: reached);
      await live.markSeen(h);
      notifyListeners();
      arrived();
      return;
    }
    // a hello on my v3 first-contact address: zero answers only (11 step 7)
    if (m.peer == 'firstcontact' && m.cipher.startsWith('khl:')) {
      final bar = m.cipher.indexOf('|');
      final hw = bar == 68 ? helloOfWire(m.cipher.substring(69)) : null;
      if (hw == null) {
        await live.markSeenLong(h);
        arrived();
        return;
      }
      await _receiveHello(
        kMainIdent,
        null,
        m.cipher.substring(4, 68),
        hw.hello,
        hw.nonce,
        h,
        arrived,
      );
      return;
    }
    // a line from one of my invites' first-contact addresses
    if (inviteTagOf(m.peer) case (final ident, final invite)) {
      await _receiveAtInvite(
        ident,
        invite,
        m.cipher,
        h,
        arrived,
        reached: reached,
      );
      return;
    }
    if (m.cipher.startsWith('{')) {
      // control frame riding the transport outside signal (bundle
      // exchange). signal wire is base64, never starts with '{'.
      await _handleBundleCtl(m.peer, unpad(m.cipher), h);
      arrived();
      return;
    }
    // 'firstcontact' is a lane, not a peer. every stranger's opening
    // message arrives under that one tag, so it can neither name who
    // sent this nor be remembered as anyone.
    final fcLane = m.peer == 'firstcontact';
    // opened on a try before that did not get as far as kept
    final before = _relayOpened[h];
    var haloId = before?.id ?? (fcLane ? null : _xPubToHaloId[m.peer]);
    var wrapped = before?.plain;
    var parkedAt = before != null && before.parked ? before.id : null;
    // flagKeyChange means "this cipher really is from this peer", which
    // skips the identity check and spends the one-time prekey. only a
    // real xpub mapping earns that.
    if (wrapped == null && haloId != null) {
      wrapped = await _open(
        haloId,
        m.cipher,
        await _fullShelves(only: haloId),
        flagKeyChange: true,
      );
      if (wrapped != null) _keepOpened(h, haloId, wrapped, epoch);
    }
    // fallback: xpub not mapped yet (or it decrypted wrong). trial
    // against everyone known like the direct path, then remember it.
    if (wrapped == null) {
      final known = await _openKnown(
        m.cipher,
        skip: haloId,
        full: await _fullShelves(),
      );
      if (known != null) {
        _keepOpened(h, known.id, known.plain, epoch);
        wrapped = known.plain;
        haloId = known.id;
        if (!fcLane) _xPubToHaloId[m.peer] = known.id;
      }
    }
    if (wrapped == null) {
      // a peer we deleted keeps its session but loses its contact row.
      // their next message is a plain whisper, so back-pair can't help:
      // re-file them as a fresh request.
      final parked = await _openParked(m.cipher);
      if (parked != null) {
        _keepOpened(h, parked.id, parked.plain, epoch, parked: true);
        wrapped = parked.plain;
        haloId = parkedAt = parked.id;
      }
    }
    if (parkedAt != null) {
      final env0 = unwrapMessage(wrapped!);
      final x = await _parkedKey(parkedAt, env0.senderXPub);
      if (x == null) {
        dlog('relay: a deleted peer\'s frame on another key, dropped');
        await live.markSeen(h);
        _relayOpened.take(h);
        arrived();
        return;
      }
      // a lane someone accepted is heard on stays theirs
      final lane = fcLane ? null : _xPubToHaloId[m.peer];
      if (!fcLane &&
          (lane == null ||
              lane == parkedAt ||
              !(_router.keeps(lane) || await live.isAccepted(lane)))) {
        _xPubToHaloId[m.peer] = parkedAt;
      }
      await live.upsertContact(
        parkedAt,
        env0.senderOnion ?? '',
        x,
        accepted: 0,
      );
      await refreshContacts();
      dlog('relay: recovered deleted peer $parkedAt into requests');
    }
    if (wrapped == null) {
      // only a prekey can bootstrap a new session. a whisper nothing
      // could decrypt is undeliverable: drop it without the noise.
      var landed = false;
      var shown = true;
      final opener = _isPreKeyWire(m.cipher);
      if (opener) {
        final (String, RouteTo)? paired;
        try {
          paired = await backPairFromCipher(m.cipher, reached: reached);
        } on FirstRefused catch (e) {
          // it never opens here: buried at once, and acked
          firstFails.note(e.why);
          await live.markSeenLong(h);
          return;
        } catch (e) {
          if (!fcLane) rethrow;
          // opened and not filed: kept, and not acked. a copy in hand, or
          // one that threw before it opened, comes again as any failed line
          dlog('nostr: back-pair threw ($e)');
          firstFails.note('file');
          if (again || await _keepFirst(h, m.cipher, reached)) {
            throw const _FirstWaits();
          }
          rethrow;
        }
        dlog('nostr: back-pair ${paired != null ? "ok" : "failed"}');
        if (paired != null) {
          if (!fcLane) _xPubToHaloId[m.peer] = paired.$1;
          await live.markSeen(h);
          landed = true;
          shown = AppState._shown(paired.$2);
        }
      }
      if (!landed && fcLane && opener) {
        // one that opened and did not file is kept and not acked; one that
        // never opened is struck below as any other
        if (again || await _keepFirst(h, m.cipher, reached)) {
          throw const _FirstWaits();
        }
      }
      if (!landed) {
        _strikeUndecryptable(h, 'nostr');
        // on the lane of someone we hold a session with: theirs and ours
        // have gone apart, a restore on one side say. they are asked to
        // start afresh, and they put again what never came back delivered.
        // a copy of one opened before is mostly a relay's backlog, so it
        // asks at most every half hour: a phone from before the ask (0.4.2)
        // that restored still heals, and a backlog does not ask on each
        if (haloId != null && !fcLane) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final copy = _takeOpenedBefore(m.cipher);
          if (!copy || now - (_copyAskedAt[haloId] ?? 0) >= _kCopyAskGap) {
            if (copy) _copyAskedAt[haloId] = now;
            unawaited(_healSoon(haloId));
          }
        }
      }
      if (shown) arrived();
      return;
    }
    final env = unwrapMessage(wrapped);
    final RouteTo went;
    try {
      went = await _applyIncomingPayload(
        haloId!,
        env,
        wire: wrapped,
        wrappedAt: wrappedAt,
        reached: reached,
      );
    } on CapHeld catch (e) {
      // kept as opened: signal has spent its keys, so accept lets it in
      await _hold(e is _HeldIn ? e.into : live, haloId!, wrapped, env);
      await live.markSeen(h);
      _relayOpened.take(h);
      arrived();
      return;
    }
    await live.markSeen(h);
    _relayOpened.take(h);
    if (AppState._shown(went)) {
      notifyListeners();
      arrived();
    }
  }

  // onto the shelf as it opened, its file named so a file takes one place.
  // one past a full shelf had its key spent already and is not kept
  // an onion copy past a full shelf, onto it as it came: its key unspent,
  // its bytes counted, opened once they are accepted
  Future<void> _overflow(String? from, String cipher) async {
    if (from == null) return;
    final to = _routeOf(from, null);
    final db = to == RouteTo.vault ? _openVault : live;
    if (db == null || (to != RouteTo.everyday && to != RouteTo.vault)) return;
    try {
      final v = await db.holdCipher(from, cipher, overflow: true);
      if (v != Shelved.kept) dlog('held: an onion copy not kept (${v.name})');
    } catch (e) {
      dlog('held: an onion copy not kept (${e.runtimeType})');
    }
  }

  Future<Shelved> _hold(
    HaloDb into,
    String from,
    String plain,
    UnwrappedMessage env,
  ) async {
    final v = await into.holdCipher(
      from,
      heldWire(plain),
      mediaId: env.mediaId,
      chunk: env.mediaId == null ? null : env.chunkIndex,
      total: env.chunkTotal,
    );
    if (v != Shelved.kept) dlog('held: not on the shelf (${v.name})');
    return v;
  }

  Future<void> _saveXPubCache(Map<String, String> cache) async {
    try {
      await secureStore.write(key: 'xpub_cache', value: jsonEncode(cache));
    } catch (e) {
      dlog('xpub cache write: $e');
    }
  }

  static const _kCopyAskGap = 30 * 60 * 1000;
}
