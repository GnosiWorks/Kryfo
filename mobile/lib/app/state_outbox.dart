// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the outbox: queued sends, receipts and the decoy hold

part of '../main.dart';

extension AppStateOutbox on AppState {
  bool claimSend(String uid) => _outboxInflight.add(uid);
  void releaseSend(String uid) => _outboxInflight.remove(uid);
  bool sendInflight(String uid) => _outboxInflight.contains(uid);

  @visibleForTesting
  int outboxTriesForTest(String uid) => _outboxTries[uid] ?? 0;
  @visibleForTesting
  set queuedForTest(int n) => _q = _Queue(n, 0, const {}, const {});
  @visibleForTesting
  int? outboxNextAtForTest(String uid) => _outboxNextAt[uid];
  // counted off the everyday outbox, so a quiet session shows none of it
  int get queued => sessionQuiet ? 0 : _q.n + _vq.n;
  // of those, how many wait on a peer who has not added us back yet
  int get parkedQueued => sessionQuiet ? 0 : _q.parked + _vq.parked;
  int queuedFor(String haloId) =>
      sessionQuiet ? 0 : (_q.perPeer[haloId] ?? 0) + (_vq.perPeer[haloId] ?? 0);

  // a decoy open, here or in the run before that the lock still holds:
  // nothing of the everyday account leaves. what arrives still lands,
  // unseen, and what waits goes once a pin opens the everyday side
  bool get everydayHeld => sessionQuiet || _quietMarked;

  @visibleForTesting
  set quietMarkedForTest(bool v) => _quietMarked = v;

  @visibleForTesting
  bool get ctlOwedForTest => _ctlOwed.isNotEmpty;
  @visibleForTesting
  Future<bool> bundleCtlForTest(String id, {required bool want}) =>
      _sendBundleCtl(id, want: want);
  @visibleForTesting
  set myBundleForTest(Future<String> Function() f) => _myBundle = f;
  @visibleForTesting
  Future<void> replayForTest() => _replayHeld();
  @visibleForTesting
  set bundleGapForTest(Duration d) => _bundleGap = d;
  @visibleForTesting
  int get receiptsOwedForTest => _receiptsOwed.length;

  // the stored mark of a decoy left open, read as a run starts. it holds
  // only where a decoy can be, a phone with a pin table. a read that does
  // not answer in [wait] holds there for now, and its answer, when it
  // comes, decides; one that fails is tried again
  @visibleForTesting
  Future<void> readDecoyMark({
    LockStore? store,
    Duration wait = const Duration(seconds: 10),
    Duration retry = const Duration(seconds: 2),
  }) async {
    final reading = _readMark(store, retry);
    final answered = await reading
        .then((_) => true)
        .timeout(wait, onTimeout: () => false);
    if (answered || _markKnown || _pinOpened) return;
    final table = await pinTableKept(store);
    if (!_markKnown && !_pinOpened) _quietMarked = table;
  }

  Future<void> _readMark(LockStore? store, Duration retry) async {
    for (var tries = 1; ; tries++) {
      final q = await quietRead(store);
      if (q != null) {
        _takeMark(q && await pinTableKept(store));
        return;
      }
      dlog('decoy mark: not read');
      // no pin table, no decoy: nothing to hold
      if (!await pinTableKept(store)) {
        _takeMark(false);
        return;
      }
      // tried for good, a few seconds apart and then a minute at most
      await Future<void>.delayed(retry * min(tries, 30));
      if (_pinOpened) return;
    }
  }

  void _takeMark(bool q) {
    if (_pinOpened) return;
    _markKnown = true;
    final was = _quietMarked;
    _quietMarked = q;
    TransferNote.instance.refresh();
    if (was && !q) _resumeEveryday();
  }

  // what was held goes on: the queues, the asks and what was owed
  void _resumeEveryday() {
    if (everydayHeld || haloWiping) return;
    unawaited(drainOutbox());
    unawaited(askForMissingSlices());
    unawaited(fetchDrops());
    _maybeRepoint();
  }

  // what a hold left owed in memory, a few a pass once the link is up, an
  // entry kept until its send went
  static const _kReplayPerPass = 12;
  Future<void> _replayHeld() async {
    if (_replaying) return;
    _replaying = true;
    try {
      var left = _kReplayPerPass;
      bool stop() => left-- <= 0 || everydayHeld || haloWiping || !linkUp;
      for (final id in [..._ctlOwed.keys]) {
        final want = _ctlOwed[id];
        if (want == null) continue;
        if (stop()) return;
        // an ask back is answered by their card, healed as any other
        if (want) _wantHeal(id);
        if (await _sendBundleCtl(id, want: want) && _ctlOwed[id] == want) {
          _ctlOwed.remove(id);
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      _receiptsOwed.removeWhere(
        (_, at) => now - at > kReceiptKeptFor.inMilliseconds,
      );
      for (final k in [..._receiptsOwed.keys]) {
        if (stop()) return;
        if (await _receiptGoes(k.$1, k.$2)) _receiptsOwed.remove(k);
      }
      for (final mid in [..._resendsOwed.keys]) {
        if (stop()) return;
        if (mediaInflight.contains(mid)) continue;
        final go = _resendsOwed.remove(mid);
        if (go != null) unawaited(go());
      }
    } finally {
      _replaying = false;
    }
  }

  // one receipt, now. true when a route that reaches them took it
  Future<bool> _receiptGoes(String to, String uid) async {
    try {
      final wrapped = await wrapMessage(
        '',
        deliveredUid: uid,
        sender: _mySender(),
      );
      return await _sendOneEnvelope(to, wrapped);
    } catch (e) {
      dlog('receipt: not sent (${e.runtimeType})');
      return false;
    }
  }

  // start the outbox drainer. safe to call more than once.
  void startOutboxDrain() {
    _outboxTimer?.cancel();
    _outboxTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (haloWiping) return;
      unawaited(drainOutbox());
      // files on their way in from the files service, as they come due
      unawaited(fetchDrops());
    });
    _needTimer?.cancel();
    // the catch-up that comes with the start may not have begun yet
    _needRouteUp();
    _needTimer = Timer.periodic(const Duration(milliseconds: kNeedTickMs), (_) {
      if (haloWiping) return;
      unawaited(askForMissingSlices());
    });
  }

  @visibleForTesting
  CatchupHold get needHoldForTest => _needHold;

  // read before the relays are asked again, so their catch-up counts
  void _needRouteUp() => _needHold.routeUp(
    DateTime.now().millisecondsSinceEpoch,
    engine.catchupState().$2,
  );

  // files that stopped arriving part way: ask each sender for what is
  // missing. quiet for a while first, so a catch-up still bringing slices
  // in is not mistaken for a loss. [walked]: the caller waited the catch-up
  // and its drain out itself.
  Future<void> askForMissingSlices({bool walked = false}) async {
    // a tick's pass may have held back for the walk the caller waited out
    while (walked && _askPass != null) {
      try {
        await _askPass;
      } catch (_) {
        // its own caller hears of it
      }
    }
    if (_askPass != null) return;
    final pass = _askPass = _askPassNow(walked);
    try {
      await pass;
    } finally {
      if (identical(_askPass, pass)) _askPass = null;
    }
  }

  Future<void> _askPassNow(bool walked) async {
    // a decoy open: the asks wait, and none is counted
    if (everydayHeld) return;
    // an ask sent with no network still counts toward the cap
    if (!linkUp) {
      _needHold.down(DateTime.now().millisecondsSinceEpoch);
      return;
    }
    // the open vault's files too: while it is shut its wants wait in it
    final wants = <(HaloDb, List<Map<String, Object?>>)>[];
    for (final d in [live, ?_openVault]) {
      try {
        final ws = await d.mediaWants();
        if (ws.isNotEmpty) wants.add((d, ws));
      } catch (e) {
        if (identical(d, live)) rethrow;
      }
    }
    if (wants.isEmpty) return;
    final (active, begun) = engine.catchupState();
    final held = _needHold.look(
      now: DateTime.now().millisecondsSinceEpoch,
      active: active,
      begun: begun,
    );
    if (active > 0) return;
    // a check-in asks itself once its catch-up is in
    if (!walked && (held || _checking)) return;
    final heldAt = walked ? 0 : _needHold.heldAt;
    for (final (d, ws) in wants) {
      try {
        await _askForMissingIn(d, ws, heldAt);
      } catch (e) {
        if (identical(d, live)) rethrow;
      }
    }
  }

  Future<void> _askForMissingIn(
    HaloDb d,
    List<Map<String, Object?>> wants,
    int heldAt,
  ) async {
    for (final w in wants) {
      final mid = w['media_id'] as String;
      final peer = w['peer_id'] as String;
      final total = (w['total'] as num).toInt();
      final lastAt = (w['last_at'] as num).toInt();
      final askedAt = (w['asked_at'] as num).toInt();
      final asks = (w['asks'] as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch;
      // the row alone says whether it is due: most ticks read nothing more
      if (!askDue(
        now: now,
        lastSliceAt: lastAt,
        askedAt: askedAt,
        asks: asks,
        heldAt: heldAt,
      )) {
        continue;
      }
      if (await d.messageExists(mid)) {
        await d.dropMediaWant(mid);
        continue;
      }
      // one that went here is asked for no more
      if (await d.goneFrom(peer, mid)) {
        await d.dropMediaWant(mid);
        await d.dropMediaChunks(mid, from: peer);
        continue;
      }
      final have = await d.heldSlices(mid);
      final ask = shouldAskNow(
        now: now,
        lastSliceAt: lastAt,
        askedAt: askedAt,
        asks: asks,
        canResend: (w['can_resend'] as num).toInt() == 1,
        have: have.length,
        total: total,
        heldAt: heldAt,
      );
      if (!ask) continue;
      if (await d.isBlocked(peer)) continue;
      // a chat declined or deleted is asked nothing: the ask says this phone
      // is here, and the file it brings would put the chat back
      final c = await d.getContact(peer);
      if (c != null && c['archived'] == 1 && c['accepted'] == 0) {
        await d.dropMediaChunks(mid, from: peer);
        await d.dropMediaWant(mid);
        incomingMediaDone(d.container.chatKey(peer));
        continue;
      }
      final missing = missingSlices(have, total);
      if (missing.isEmpty) continue;
      // an ask sealed for no one uses none of the asks
      if (await keyHeld(peer)) continue;
      if (everydayHeld) return;
      dlog('need $mid: asking for ${missing.length} of $total');
      // stamped before it goes, with the time it was decided on: a send
      // takes seconds, and the tick its backoff ends on would miss it
      await d.markMediaAsked(mid, now);
      try {
        final wrapped = await wrapMessage(
          '',
          need: NeedFrame(mid, missing),
          sender: _mySender(),
        );
        await _sendOneEnvelope(peer, wrapped);
      } catch (e) {
        dlog('need $mid: ask failed: $e');
      }
    }
  }

  // the other side of it. the frame comes from outside and names a file to
  // read off this phone, so it is answered only for a row we sent, to the
  // one person it was sent to, a bounded number of times.
  Future<void> _answerNeed(String from, NeedFrame need, HaloDb db) async {
    // a decoy open: answered once it is left, no round used till then
    if (everydayHeld) {
      _resendsOwed[need.mediaId] = () => _answerNeed(from, need, db);
      return;
    }
    final row = await db.sentMediaRow(need.mediaId);
    final now = DateTime.now().millisecondsSinceEpoch;
    // a file a block kept from going is not finished off on their word
    final ok =
        row != null &&
        row['sent'] != kNotSent &&
        resendAllowed(
          rowPeer: row['peer_id'] as String?,
          rowGroup: row['group_id'] as String?,
          rowDirection: row['direction'] as String?,
          requester: from,
          now: now,
          lastAnsweredAt: _needAnsweredAt[need.mediaId] ?? 0,
          rounds: _needRounds[need.mediaId] ?? 0,
        );
    if (!ok) {
      dlog('need ${need.mediaId}: not answered');
      return;
    }
    final filePath = row['file_path'] as String?;
    final mediaPath = row['media_path'] as String?;
    final isFile = filePath != null && filePath.isNotEmpty;
    final path = isFile ? filePath : mediaPath;
    if (path == null || path.isEmpty || !await File(path).exists()) return;
    final total = await mediaSliceCount(path);
    final only = answerable(need.indices, total);
    if (only.isEmpty) return;
    _needAnsweredAt[need.mediaId] = now;
    _needRounds[need.mediaId] = (_needRounds[need.mediaId] ?? 0) + 1;
    if (_needAnsweredAt.length > 200) {
      _needAnsweredAt.removeWhere((_, t) => now - t > 86400000);
    }
    dlog('need ${need.mediaId}: resending ${only.length} of $total');
    unawaited(
      _drainMedia(
        row,
        from,
        need.mediaId,
        path,
        isFile: isFile,
        only: only,
        on: db,
      ),
    );
  }

  // re-send anything the wire never confirmed. cheap when there's nothing to
  // do (one indexed query). skipped entirely while tor can't carry traffic.
  // what waits, here and in the open vault, read and shown
  Future<
    ({
      Set<String> held,
      List<Map<String, Object?>> rows,
      List<Map<String, Object?>> vRows,
      _Queue q,
      _Queue vq,
      HaloDb? v,
    })
  >
  _countOutbox() async {
    var held = await _heldOf(live);
    final rows = await live.unsentOutbox(skip: held);
    final q = await _queueOf(rows, live);
    // the open vault's rows go while it is open. shut, they wait in it for
    // the next open
    final v = _openVault;
    var vRows = const <Map<String, Object?>>[];
    var vq = _Queue.none;
    if (v != null) {
      try {
        final vHeld = await _heldOf(v);
        held = {...held, ...vHeld};
        vRows = await v.unsentOutbox(skip: vHeld);
        vq = await _queueOf(vRows, v);
      } catch (e) {
        vRows = const [];
      }
    }
    if (!identical(_openVault, v)) {
      vRows = const [];
      vq = _Queue.none;
    }
    if (!q.same(_q) || !vq.same(_vq)) {
      _q = q;
      _vq = vq;
      notifyListeners();
    }
    return (held: held, rows: rows, vRows: vRows, q: q, vq: vq, v: v);
  }

  // [wait]: back once the sends this pass starts are done, or have had a
  // while, rather than as they start
  Future<void> drainOutbox({bool wait = false}) async {
    // count first, wire or no wire: the strip and the rows say what is
    // waiting whether or not anything can move yet
    final (:held, :rows, :vRows, :q, :vq, :v) = await _countOutbox();
    // torReady already knows the mode: outside onion there is nothing to
    // wait for and a queued message should just go. with no network a try
    // only uses up the cap
    final ready = linkUp;
    if (!ready) {
      _outboxWasReady = false;
      return;
    }
    _outboxWasReady = true;
    // a decoy open: all of it waits for the session that wrote it
    if (everydayHeld) return;
    unawaited(_replayHeld());
    unawaited(_drainEdits());
    unawaited(_drainPins());
    unawaited(_drainFrames());
    unawaited(_drainGroupCtl());
    unawaited(_drainGroupOwed());
    unawaited(_drainAcks());
    unawaited(_askAfresh());
    if (rows.isEmpty && vRows.isEmpty) {
      if (_outboxTries.isNotEmpty) {
        _outboxTries.clear();
        _outboxNextAt.clear();
        _outboxPeer.clear();
      }
      return;
    }
    // anything that landed since the last sweep stops costing us bookkeeping.
    final waiting = {
      for (final r in [...rows, ...vRows]) r['msg_uid'] as String?,
    };
    _outboxTries.removeWhere((k, _) => !waiting.contains(k));
    _outboxNextAt.removeWhere((k, _) => !waiting.contains(k));
    _outboxPeer.removeWhere((k, _) => !waiting.contains(k));
    final blocked = _blockedInPass();
    // the sends this pass starts, and the 1:1 chats they are in
    final going = <Future<void>>[];
    final chats = <String>{};
    for (final (r, d, paired) in [
      for (final r in rows) (r, live, q.paired),
      if (v != null)
        for (final r in vRows) (r, v, vq.paired),
    ]) {
      final uid = r['msg_uid'] as String?;
      if (uid == null || _outboxInflight.contains(uid)) continue;
      // a file another send still holds: a try now would only come back
      // busy and spend one of the row's tries
      if (mediaInflight.contains(uid)) continue;
      // a decoy opened while this pass read: the rest waits, its tries kept
      if (everydayHeld) break;
      // to someone blocked in the row's own container: not sent, and it
      // waits for a tap, never for the unblock. a block in the other one
      // only holds it back, and it goes once that block is lifted
      final to = r['peer_id'] as String?;
      final g = r['group_id'] as String?;
      if (to != null && (g == null || g.isEmpty) && await blocked(to)) {
        try {
          if (await d.isBlocked(to)) {
            await d.holdBack(uid);
            _bumpChatRev(to);
          }
        } catch (e) {
          dlog('outbox: blocked row not held back (${e.runtimeType})');
        }
        continue;
      }
      // held rows stay out of the window; one that came in anyway waits too
      if (held.contains(r['peer_id'])) continue;
      // a send fired seconds ago still has its own future running; leave it be.
      final age = DateTime.now().millisecondsSinceEpoch - (r['sent_at'] as int);
      if (age < 45000) continue;
      final tries = _outboxTries[uid] ?? 0;
      // the cap is for a route that exists and fails. a peer who has not
      // added us back yet keeps their rows going at the ten-minute gap.
      if (tries >= 8) {
        final peer = r['peer_id'] as String?;
        if (peer == null || (paired[peer] ?? true)) continue;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextAt = _outboxNextAt[uid];
      if (nextAt != null && now < nextAt) continue;
      // the chat may have taken it while this pass read
      if (!_outboxInflight.add(uid)) continue;
      _outboxNextAt[uid] = now + queueGap(tries);
      _outboxTries[uid] = tries + 1;
      final peer = r['peer_id'] as String?;
      if (peer != null) _outboxPeer[uid] = peer;
      if (peer != null && (g == null || g.isEmpty)) chats.add(peer);
      going.add(
        _drainOne(r, d).whenComplete(() async {
          // waiting on their card is no failed try: it goes the moment the
          // card is here, and until then it tries as they are asked again
          // (SignalSession.askWait)
          if (peer != null && _waitingCard.contains(peer)) {
            var due = 0;
            try {
              await _asking[peer];
              due = await signalSession.askDueAt(peer) ?? 0;
            } catch (e) {
              dlog('outbox: ask time not read (${e.runtimeType})');
            }
            if (_waitingCard.contains(peer)) {
              _outboxTries[uid] = tries;
              _outboxNextAt[uid] = max(due, now + 600000);
            }
          }
          _outboxInflight.remove(uid);
        }),
      );
    }
    // an open chat that kept its pills while they ran reads them again,
    // once the pass is done
    if (going.isEmpty) return;
    final all = Future.wait(going)
        .then((_) {}, onError: (Object e) => dlog('outbox: ${e.runtimeType}'))
        .whenComplete(() {
          if (chats.isEmpty) return;
          for (final p in chats) {
            _bumpChatRev(p);
          }
          notifyListeners();
        });
    if (!wait) {
      unawaited(all);
      return;
    }
    try {
      await all.timeout(AppState.flushWait);
    } on TimeoutException {
      dlog('outbox: still sending after the wait');
    }
  }

  bool waitsForCard(String peer) => _waitingCard.contains(peer);

  // a contact verified under another key than they hold now: nothing goes
  // to them until the new number is checked or the new key accepted. the
  // queues pass them by without using a try. a read that fails says nothing
  // about their key: the queues go on, and the seal ([strict]) waits. the
  // seal is the everyday identity's, so its rows judge whichever session
  // is open: the everyday one, the open vault's, else a shut vault's card
  Future<bool> keyHeld(String peer, {bool strict = false}) async {
    if (isDevId(peer)) return false;
    try {
      if (await live.keyHeld(peer)) return true;
      final v = _openVault;
      if (v != null) return await v.keyHeld(peer);
      return await _cardHeld(peer);
    } catch (e) {
      dlog('key hold: not read (${e.runtimeType})');
      return strict;
    }
  }

  // someone a shut vault holds, by the mark its card keeps. only theirs
  // waits for a vault shutting now to write its cards
  Future<bool> _cardHeld(String peer) async {
    if (_router.cardOf(peer) == null) return false;
    if (_closeDone != null) {
      await _afterClose().timeout(const Duration(seconds: 30));
    }
    final card = _router.cardOf(peer);
    if (card == null) return false;
    final held = await heldKeyHex(await live.open(), peer, xpub: card.xpub);
    if (held == null) return false;
    if (card.markRead) {
      final mark = card.verifiedKey;
      return mark != null && held != mark;
    }
    // a card from before marks were kept: any key but the one it was made
    // with holds, until the vault opens and writes them
    final paired = card.xpub.trim().toLowerCase();
    return paired.isNotEmpty && held != paired;
  }

  // a vault shutting, for the tests
  @visibleForTesting
  set closingForTest(Completer<void>? c) => _closeDone = c;

  // a mark set or taken off, or a new key accepted. one in the open vault
  // reaches its card now, not only at the close
  Future<bool> setVerified(String peer, bool verified, {String? key}) async {
    final ok = await session.setVerified(peer, verified, key: key);
    _recardFor(peer);
    return ok;
  }

  Future<void> acceptNewKey(String peer) async {
    await session.acceptNewKey(peer);
    _recardFor(peer);
    _ackDueNow(peer);
  }

  // a block in the open vault on someone its cards name: the cards say so
  // while it is shut, and since when
  Future<void> _recardBlock(String haloId) async {
    if (_openVault == null || !_router.keeps(haloId)) return;
    try {
      await refreshHiddenCards();
    } catch (e) {
      dlog('vault: cards not read (${e.runtimeType})');
    }
  }

  void _recardFor(String peer) {
    if (_openVault == null || !_session.isHidden(peer)) return;
    unawaited(
      refreshHiddenCards().catchError(
        (Object e) => dlog('vault: cards not read (${e.runtimeType})'),
      ),
    );
  }

  Future<void> flagKeyChanged(String peer) async {
    if (isDevId(peer)) return;
    try {
      await live.setKeyChanged(peer, true);
      final v = _openVault;
      if (v != null) {
        await v.setKeyChanged(peer, true);
      } else if (_router.cardOf(peer) != null &&
          !_router.blocks(peer) &&
          _keyChangeSealed.add(peer)) {
        final kept = await _router.seal(
          Unsealed(
            peer,
            '',
            false,
            DateTime.now().millisecondsSinceEpoch,
            keyChanged: true,
          ),
        );
        if (!kept) _keyChangeSealed.remove(peer);
      }
    } catch (e) {
      dlog('key change: not kept (${e.runtimeType})');
    }
    keyChanged();
  }

  // every held contact of one database, read once per pass: their queued
  // rows stay out of the windows the queues read, so they never fill them
  Future<Set<String>> _heldOf(HaloDb d) async {
    try {
      return await d.heldPeers();
    } catch (e) {
      dlog('key hold: none read (${e.runtimeType})');
      return const {};
    }
  }

  // their card is here: what of theirs waited goes now, from the first try
  void _cardCame(String peer) {
    final was = _waitingCard.remove(peer);
    final uids = [
      for (final e in _outboxPeer.entries)
        if (e.value == peer) e.key,
    ];
    for (final uid in uids) {
      _outboxTries.remove(uid);
      _outboxNextAt.remove(uid);
    }
    if (was || uids.isNotEmpty) {
      _bumpChatRev(peer);
      unawaited(drainOutbox());
    }
    _ackDueNow(peer);
  }

  // what an accept owes them waited on their card or a key check: it goes
  // now, not at the end of its wait
  void _ackDueNow(String peer) {
    final before = _ackNextAt.length;
    _ackNextAt.removeWhere((k, _) => k.endsWith('|$peer'));
    if (_ackNextAt.length != before) unawaited(_drainAcks());
  }

  // what one container's unsent rows come to
  Future<_Queue> _queueOf(List<Map<String, Object?>> rows, HaloDb d) async {
    final perPeer = <String, int>{};
    final paired = <String, bool>{};
    var parked = 0;
    for (final r in rows) {
      final to = r['peer_id'] as String?;
      if (to != null) perPeer[to] = (perPeer[to] ?? 0) + 1;
      // a row for someone who has not added us back is waiting on them,
      // not on the wire. the strip says which.
      final g = r['group_id'] as String?;
      if (to != null && (g == null || g.isEmpty)) {
        paired[to] ??= await d.isBackPaired(to);
        if (!paired[to]!) parked++;
      }
    }
    return _Queue(rows.length, parked, perPeer, paired);
  }

  // d is the container the row is in
  Future<void> _drainOne(Map<String, Object?> r, HaloDb d) async {
    final uid = r['msg_uid'] as String;
    final peer = r['peer_id'] as String;
    final groupId = r['group_id'] as String?;
    // a photo or file that never finished goes through the shared chunked
    // sender, which remembers the slices that landed
    final mediaPath = r['media_path'] as String?;
    final filePath = r['file_path'] as String?;
    if (mediaPath != null || filePath != null) {
      if (groupId == null) {
        await _drainMedia(
          r,
          peer,
          uid,
          mediaPath ?? filePath!,
          isFile: mediaPath == null,
          on: d,
        );
      } else {
        await _drainGroupMedia(
          r,
          groupId,
          uid,
          mediaPath ?? filePath!,
          isFile: mediaPath == null,
          on: d,
        );
      }
      return;
    }
    try {
      // a stranger's opener rides its nonce again. a row with none is ground
      // now, or the far side drops the retry.
      var row = r;
      if (groupId == null &&
          redeliveryNeedsPow(r, backPaired: await d.isBackPaired(peer))) {
        final nonce = await compute(_outboxGrind, r['plaintext'] as String);
        await d.setPowNonce(uid, nonce);
        row = {...r, 'pow_nonce': nonce};
      }
      final wrapped = await wrapRedelivery(
        row,
        sender: _mySender(),
        badge: await sharedBadge(),
      );
      if (groupId != null) {
        final to = await _othersIn(d, groupId);
        final missed = await _fanOut(d, groupId, to, wrapped);
        if (missed.length < to.length) {
          await d.markSent(uid);
          await _lightBurn(r, uid, d);
          await _oweText(d, uid, groupId, to: to, missed: missed, first: true);
          _bumpChatRev('group:$groupId');
          notifyListeners();
        }
        return;
      }
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) {
        dlog('outbox: redelivered $uid');
        await d.markSent(uid);
        await _lightBurn(r, uid, d);
        // an open chat reloads and drops the waiting line
        _bumpChatRev(peer);
        notifyListeners();
      }
    } catch (e) {
      dlog('outbox: $uid still stuck ($e)');
    }
  }

  @visibleForTesting
  Future<void> sendOpenersAgain() =>
      _againPass ??= _openersAgain().whenComplete(() => _againPass = null);

  Future<void> _openersAgain() async {
    if (haloWiping || everydayHeld || !linkUp) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in [live, ?_openVault]) {
      try {
        await d.forgetOpenersBefore(now - kOpenerAgainFor.inMilliseconds);
        for (final peer in await d.notBackPaired()) {
          if (isDevId(peer)) continue;
          if (await blockedAnywhere(peer) || await keyHeld(peer)) continue;
          List<String>? order;
          for (final r in await d.sentUnconfirmed(peer)) {
            final uid = r['msg_uid'] as String;
            final sentAt = (r['sent_at'] as num).toInt();
            if (now - sentAt >= kOpenerAgainFor.inMilliseconds) continue;
            if (_outboxInflight.contains(uid)) continue;
            final was = await d.openerAgain(uid);
            // past their two its copies went to be held, by their onion
            // and on the relay: no receipt comes until they accept
            if (was != null && was.both) {
              order ??= await d.sentUidsTo(peer);
              if (order.indexOf(uid) >= 2) continue;
            }
            final tries = was?.tries ?? 0;
            // a row made as it first went counts from when it was written
            final due = openerAgainAt(
              sentAt: sentAt,
              lastAt: tries == 0 ? null : was?.lastAt,
              tries: tries,
            );
            if (due == null || due > now) continue;
            // a decoy opened while this pass read: no try is noted
            if (everydayHeld) return;
            if (!_outboxInflight.add(uid)) continue;
            try {
              // noted before it goes: a death half way is a try, not a loop
              await d.noteOpenerAgain(uid, tries + 1, now);
              // the last goes to the pair address alone, a day after the
              // one before: their first-contact address may be one they
              // have reset, and once they add us back they read this one
              await _openerAgain(
                r,
                peer,
                d,
                wire: was?.wire,
                pairOnly: tries + 1 == kOpenerAgain.length,
              );
            } finally {
              _outboxInflight.remove(uid);
            }
          }
        }
      } catch (e) {
        dlog('openers: not put out again (${e.runtimeType})');
      }
    }
  }

  // one opener again: the very words it first went as when they were kept,
  // so a gate that holds it holds one copy, or as the outbox puts a text
  // out, its nonce, uid and time written. sealed on the session as it is
  Future<void> _openerAgain(
    Map<String, Object?> r,
    String peer,
    HaloDb d, {
    String? wire,
    bool pairOnly = false,
  }) async {
    final uid = r['msg_uid'] as String;
    try {
      var row = r;
      if (wire == null && redeliveryNeedsPow(r, backPaired: false)) {
        final nonce = await compute(_outboxGrind, r['plaintext'] as String);
        await d.setPowNonce(uid, nonce);
        row = {...r, 'pow_nonce': nonce};
      }
      final wrapped =
          wire ??
          await wrapRedelivery(
            row,
            sender: _mySender(),
            badge: await sharedBadge(),
          );
      final ok = await _sendOneEnvelope(peer, wrapped, pairOnly: pairOnly);
      dlog('openers: $uid ${ok ? "went again" : "did not go again"}');
    } catch (e) {
      dlog('openers: $uid did not go again ($e)');
    }
  }

  // a timed message's clock starts when it is actually sent, and the
  // outbox is sometimes the one that sends it
  Future<void> _lightBurn(Map<String, Object?> r, String uid, HaloDb d) async {
    final secs = (r['burn_secs'] as num?)?.toInt();
    if (secs == null || r['burn_at'] != null) return;
    await d.setMsgBurnAt(
      uid,
      DateTime.now().millisecondsSinceEpoch + secs * 1000,
    );
  }

  Future<void> _drainMedia(
    Map<String, Object?> r,
    String peer,
    String uid,
    String path, {
    required bool isFile,
    Set<int>? only,
    HaloDb? on,
  }) async {
    final f = File(path);
    if (!await f.exists()) return;
    // the container the row is in: the vault's rows reach its people
    final d = on ?? live;
    final contact = await d.getContact(peer);
    if (contact == null) return;
    final backPaired = await d.isBackPaired(peer);
    final fileName = isFile ? r['file_name'] as String? : null;
    final res = await sendChunkedMediaTo(
      peerId: peer,
      peerOnion: (contact['onion'] as String?) ?? '',
      peerXPub: contact['xpub'] as String?,
      backPaired: backPaired,
      needPow: !backPaired,
      path: path,
      msgUid: uid,
      caption: (r['plaintext'] as String?) ?? '',
      fileName: fileName,
      voice: isVoiceName(fileName),
      voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
      burnSeconds: (r['burn_secs'] as num?)?.toInt(),
      secure: ((r['secure'] as int?) ?? 0) == 1,
      replyTo: r['reply_to'] as String?,
      album: AlbumTag.ofRow(r),
      writtenAt: (r['sent_at'] as num?)?.toInt(),
      sender: _mySender(),
      only: only,
      progressKey: d.container.chatKey(peer),
      blockedHere: () => d.isBlocked(peer),
    );
    if (only != null) {
      dlog('need $uid: resend ended $res');
      // a hold stopped it: the rest goes once the decoy is left
      if (res == 'parked' && everydayHeld) {
        _resendsOwed[uid] = () =>
            _drainMedia(r, peer, uid, path, isFile: isFile, only: only, on: on);
      }
      return;
    }
    if (res == 'ok') {
      dlog('outbox: media redelivered $uid');
      await d.markSent(uid);
      await _lightBurn(r, uid, d);
      _bumpChatRev(peer);
      notifyListeners();
    } else if (res == kSendBlocked) {
      // blocked part way: not sent, and it waits for a tap
      await d.holdBack(uid);
      _bumpChatRev(peer);
      notifyListeners();
    } else if (res != 'busy') {
      dlog('outbox: media $uid still stuck ($res)');
      // an open chat re-reads the row, so a bubble left spinning by a
      // busy tap-to-retry settles into failed or waiting
      _bumpChatRev(peer);
    }
  }

  // the count after it is what still waits once the sends are done: the
  // pass counts before it sends
  Future<void> flushOutboxNow() async {
    // one at a time: a second tap while it waits would only stack passes
    if (_flushing) return;
    _flushing = true;
    notifyListeners();
    try {
      _outboxNextAt.clear();
      _outboxTries.clear();
      _ackNextAt.clear();
      await drainOutbox(wait: true);
      await _countOutbox();
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  bool get flushing => _flushing;

  // tiny ack: tells the original sender their message landed. reuses the
  // gift-wrap transport; carries only the uid, no body, no sender bundle.
  @visibleForTesting
  Future<void> receiptForTest(String to, String uid) =>
      _sendDeliveryReceipt(to, uid);

  Future<void> _sendDeliveryReceipt(String toHaloId, String uid) async {
    // a relay replaying its backlog hands us the same message many times
    // over. re-acking still matters (the first receipt may have died), so
    // this throttles rather than blocks.
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _ackedAt[uid];
    if (last != null && now - last < 30000) return;
    _ackedAt[uid] = now;
    if (_ackedAt.length > 500) {
      _ackedAt.removeWhere((_, t) => now - t > 300000);
    }
    try {
      // a decoy open: it waits with their chat's rows, as below, and goes
      // once the everyday side may send again. held past kReceiptKeptFor it
      // goes unsent, as any queued receipt or reaction does
      final held = everydayHeld;
      if (!held) {
        final wrapped = await wrapMessage(
          '',
          deliveredUid: uid,
          sender: _mySender(),
        );
        if (await _sendOneEnvelope(toHaloId, wrapped)) return;
      }
      // the seal waits on their card: the receipt waits with it, where
      // their chat's rows are, and goes once the session is fresh
      if (held || _waitingCard.contains(toHaloId) || await keyHeld(toHaloId)) {
        final on = (await _reach(toHaloId))?.on;
        if (on != null) {
          await on.queueFrame(uid, kFrameReceipt, toHaloId, '');
        } else if (_openVault == null && _router.cardOf(toHaloId) != null) {
          // a shut vault's chat: the receipt is sealed to it, and waits in
          // it from its open as an everyday one waits here
          // one row per receipt, however often a relay replays it
          final rc = 'rc:$uid';
          if (!await _router.sealedHas(rc, null)) {
            await _router.seal(
              Unsealed(toHaloId, '', false, now, receipt: uid),
              uid: rc,
            );
          }
          // held by a decoy, it goes with the everyday ones as it is left,
          // not only once the vault opens. a second tick changes nothing
          if (held && _receiptsOwed.length < 500) {
            _receiptsOwed[(toHaloId, uid)] ??= now;
          }
        }
      }
    } catch (e) {
      dlog('receipt for $uid failed: $e');
    }
  }

  SenderInfo _mySender() => SenderInfo(
    haloId: myId,
    edPub: _io.edPub(),
    onion: myOnion,
    xPub: _io.xPub(),
    avatar: _myAvatar,
  );

  // the small opener a waiting frame needs: the empty envelope, with the
  // proof of work a first contact asks for. one at a time per peer
  Future<void> _sendStarter(String peer) async {
    if (!_startersGoing.add(peer)) return;
    try {
      final to = await _reach(peer);
      if (to == null) return;
      final pow = to.backPaired ? null : await compute(_outboxGrind, '');
      final wrapped = await wrapMessage(
        '',
        sender: _mySender(),
        powNonce: pow,
        powBitsUsed: pow == null ? null : powBits,
      );
      await _sendOneEnvelope(peer, wrapped);
      dlog('send: a small opener went ahead of a waiting frame');
    } catch (e) {
      dlog('send: the small opener did not go ($e)');
    } finally {
      _startersGoing.remove(peer);
    }
  }

  // an accepted contact started their session again: the empty envelope
  // answers it, so what they hold for the answer goes
  Future<void> _answerNewSession(String peer) async {
    if (isDevId(peer)) return;
    // as a receipt is: one in 30 s per contact, so one who starts sessions
    // over and over gets no frame back for each
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _answeredNewAt[peer];
    if (last != null && now - last < 30000) return;
    _answeredNewAt[peer] = now;
    if (_answeredNewAt.length > 500) {
      _answeredNewAt.removeWhere((_, t) => now - t > 300000);
    }
    try {
      final to = await _reach(peer);
      if (to == null || !to.backPaired) return;
      if (!await (to.on ?? live).isAccepted(peer)) return;
      await _sendOneEnvelope(peer, await wrapMessage('', sender: _mySender()));
    } catch (e) {
      dlog('send: a new session not answered ($e)');
    }
  }

  // [member]: a group's frame, which the group's own rules send.
  // [takeBack]: an unsend, which only withdraws and goes to anyone
  // [pairOnly]: the onion and the pair address, as an opener's last try
  // goes, and true when a copy went rather than when it was delivered
  Future<bool> _sendOneEnvelope(
    String memberId,
    String wrapped, {
    bool member = false,
    bool takeBack = false,
    bool pairOnly = false,
    // a seal that waits on a key check or on their card throws, rather
    // than reading as a failed send
    bool holdThrows = false,
  }) async {
    // one attempt. the engine calls carry their own timeouts (onion 15s,
    // relay 60s), so retrying here only stacks them. a failed send is marked
    // failed and the user gets tap-to-retry.
    // nothing of the everyday account leaves while a decoy is open
    if (everydayHeld) return false;
    try {
      final to = await _reach(memberId);
      if (to == null) {
        dlog('send: no contact for $memberId');
        return false;
      }
      if (!member && !takeBack && await blockedAnywhere(memberId)) {
        dlog('send: $memberId is blocked');
        return false;
      }
      String cipher;
      // a member with no session and no stored bundle can't be reached
      // (e.g. a dead identity still in the roster). don't burn a relay
      // timeout on it every send: skip fast so live members deliver now.
      if (!await _io.hasSession(memberId) && to.bundle == null) {
        // an introduced peer whose bundle swap never landed: ask again, the
        // user's tap-to-retry goes through once it does.
        if (await to.on?.isVouched(memberId) ?? false) {
          _wantHeal(memberId);
          unawaited(_sendBundleCtl(memberId, want: true));
        }
        dlog('send: $memberId unreachable (no session/bundle), skipping');
        return false;
      }
      try {
        cipher = await _io.encrypt(memberId, wrapped);
      } on StartingAfresh {
        // waits on their card, asked for as it falls due (_afreshCard)
        rethrow;
      } on KeyHeld {
        // waits on a check of their new number: their session is fine
        rethrow;
      } on FrameTooLarge {
        // too big for any route: their session is fine
        rethrow;
      } catch (e) {
        // a corrupt session (InvalidKeyException or bad state) can't encrypt.
        // if we kept the peer's bundle at pairing, wipe the broken session and
        // rebuild it, then try once more.
        final healed = await _healSession(memberId);
        if (!healed) {
          // no stored bundle (paired before v30 kept them). ask the peer
          // for a fresh one over the gift-wrap transport: the reply heals
          // the session and the user's tap-to-retry then goes through.
          _wantHeal(memberId);
          unawaited(_sendBundleCtl(memberId, want: true));
          rethrow;
        }
        cipher = await _io.encrypt(memberId, wrapped);
      }
      final backPaired = to.backPaired;
      final xpub = to.xpub;
      final onion = to.onion;
      // the identity the door sealed it on goes with it to the relay
      final ident = identOf(memberId);
      final pairWay = await pairRead(memberId, backPaired: backPaired);

      // the onion and a fresh pair copy at its own time, never the
      // first-contact address beside it. true when either took it: the one
      // caller only says whether it went
      if (pairOnly) {
        final rs = await Future.wait([
          if (!backPaired && onion.isNotEmpty)
            Future(
              () => _io.onionSend(onion, cipher),
            ).catchError((Object _) => 'err'),
          Future(
            () => _io.relaySend(ident, xpub, cipher),
          ).catchError((Object _) => 'err'),
        ]);
        if (!rs.contains('ok')) dlog('send: no copy went ($rs)');
        return rs.contains('ok');
      }

      // back-paired: the pair address only
      if (backPaired || onion.isEmpty) {
        // no onion and not added back yet: their first-contact address is
        // the one relay route that reaches them, as the chat's own send has.
        // the pair address is not written beside it, so no relay sees the
        // two together. a failed one goes again from the outbox
        final fc = backPaired ? null : peerFcFor(memberId);
        if (fc != null && fc.isNotEmpty) {
          final f = await Future(
            () => _io.firstContactSend(ident, xpub, fc, cipher),
          );
          if (f == 'ok') return true;
          dlog('send: first-contact failed ($f)');
          return false;
        }
        final n = await Future(() => _io.relaySend(ident, xpub, cipher));
        // the pair address is a drop box they read only once they add us
        // back, or once they took our card. stored there is parked, not
        // delivered, until one of those
        if (n == 'ok') return backPaired || pairWay;
        dlog('send: nostr failed ($n)');
        return false;
      }

      // not back-paired: race onion and one relay copy, so a slow or dead
      // onion does not cost the full 15s. the relay copy goes to their
      // first-contact address, or to the pair address when there is none,
      // never to both
      final fc = _peerFc[memberId] ?? '';
      final viaFirst = fc.isNotEmpty;
      final done = Completer<bool>();
      var pending = 2;
      void settle(String tag, String r) {
        // a relay taking it for the pair address is not delivery here:
        // they read that address only after adding us back, or taking our
        // card
        if (r == 'ok' && (tag != 'nostr' || pairWay)) {
          if (!done.isCompleted) done.complete(true);
        } else {
          if (r != 'ok') dlog('send: $tag failed ($r)');
          if (--pending == 0 && !done.isCompleted) done.complete(false);
        }
      }

      unawaited(
        Future(() => _io.onionSend(onion, cipher))
            .then((r) => settle('onion', r))
            .catchError((_) => settle('onion', 'err')),
      );
      dlog(
        viaFirst
            ? 'send: racing onion + first-contact for $memberId'
            : 'send: no first-contact addr for $memberId (v2 invite?)',
      );
      if (viaFirst) {
        unawaited(
          _io
              .firstContactSend(ident, xpub, fc, cipher)
              .then((r) => settle('firstcontact', r))
              .catchError((_) => settle('firstcontact', 'err')),
        );
      } else {
        unawaited(
          Future(() => _io.relaySend(ident, xpub, cipher))
              .then((r) => settle('nostr', r))
              .catchError((_) => settle('nostr', 'err')),
        );
      }
      return done.future;
    } catch (e) {
      if (holdThrows && (e is KeyHeld || e is StartingAfresh)) rethrow;
      dlog('send to $memberId failed: $e');
      return false;
    }
  }

  /// [id] has not added us back but reads our pair address already: we came
  /// to them on a friend's card, as they came to us, and no first-contact
  /// address of theirs is known. that address is the way to them then
  Future<bool> pairRead(String id, {required bool backPaired}) async =>
      !backPaired && !_hasFc(id) && _pairSeen.contains(id);
}
