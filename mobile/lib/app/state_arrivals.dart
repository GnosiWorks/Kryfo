// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: what an arriving message does once it is open

part of '../main.dart';

extension AppStateArrivals on AppState {
  static const _kTakenBackFor = Duration(days: 2);

  void _noteTakenBack(String sender, String uid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _takenBack.remove('$sender $uid');
    _takenBack['$sender $uid'] = now;
    final cut = now - _kTakenBackFor.inMilliseconds;
    _takenBack.removeWhere((_, at) => at < cut);
    if (_takenBack.length > 1000) _takenBack.remove(_takenBack.keys.first);
  }

  bool _wasTakenBack(String sender, String uid) {
    final at = _takenBack['$sender $uid'];
    return at != null &&
        DateTime.now().millisecondsSinceEpoch - at <
            _kTakenBackFor.inMilliseconds;
  }

  @visibleForTesting
  List<String> get earlyWiresForTest => [for (final e in _early) e.wire];
  static const _kEarlyChars = 1 << 20;
  static const _kEarlyPerUid = 32;
  static const _kEarlyPerSender = 64;

  void _unparkWhere(bool Function(_Early e) test) {
    _early.removeWhere((e) {
      if (!test(e)) return false;
      _earlyChars -= e.wire.length;
      return true;
    });
  }

  // all but the last [keep] of those [of] picks
  void _trimEarly(bool Function(_Early e) of, int keep) {
    var over = _early.where(of).length - keep;
    if (over > 0) _unparkWhere((e) => over > 0 && of(e) && over-- > 0);
  }

  void _parkEarly(_Early e) {
    final cut = e.at - _kTakenBackFor.inMilliseconds;
    _unparkWhere((x) => x.at < cut);
    _early.add(e);
    _earlyChars += e.wire.length;
    _trimEarly((x) => x.uid == e.uid, _kEarlyPerUid);
    _trimEarly((x) => x.sender == e.sender, _kEarlyPerSender);
    while (_earlyChars > _kEarlyChars && _early.isNotEmpty) {
      _earlyChars -= _early.removeAt(0).wire.length;
    }
  }

  // an edit or a reaction older, by its sender's clock, than the last one
  // taken from them for that message is a late copy (an onion copy may
  // beat the relay's): left out. one with no time goes in as it always did
  Future<bool> _inOrder(
    HaloDb db,
    String uid,
    String sender,
    String kind,
    UnwrappedMessage env,
  ) async {
    final w = env.writtenAt;
    if (w == null) return true;
    try {
      if (await db.takeFrameOrder(uid, sender, kind, w)) return true;
      dlog('$kind: an older one, left out');
      return false;
    } catch (e) {
      dlog('$kind: order not read (${e.runtimeType})');
      return true;
    }
  }

  void _dropEarly() {
    _early.clear();
    _earlyChars = 0;
  }

  // what came early for a message just filed by [author]. the text of the
  // last edit of theirs that went in, if any
  Future<String?> _applyEarly(
    String uid,
    String author,
    HaloDb db,
    Set<String>? marks,
  ) async {
    if (_early.isEmpty) return null;
    bool mine(_Early e) => e.uid == uid && identical(e.db, db);
    final due = _early.where(mine).toList();
    if (due.isEmpty) return null;
    _unparkWhere(mine);
    final cut =
        DateTime.now().millisecondsSinceEpoch - _kTakenBackFor.inMilliseconds;
    String? edited;
    var editedAt = -1;
    for (final e in due) {
      if (e.at < cut) continue;
      try {
        final env = unwrapMessage(e.wire);
        await _fileArrival(
          e.sender,
          env,
          wire: e.wire,
          into: e.into,
          arrivedAt: e.arrivedAt,
          marks: marks,
          wrappedAt: e.wrappedAt,
          reached: e.reached,
        );
        // the newest by their clock, whichever came last
        final w = env.writtenAt ?? editedAt;
        if (e.sender == author && env.edit != null && w >= editedAt) {
          edited = env.edit!.newText;
          editedAt = w;
        }
      } catch (err) {
        dlog('early: one did not go in ($err)');
      }
    }
    return edited;
  }

  /// a linked device's history copy landed: what came early for the
  /// messages it brought (an edit, a reaction, a pin) goes in now, as it
  /// would have had each come live
  Future<void> applyEarlyCopied() async {
    if (_early.isEmpty) return;
    final db = live;
    final due = <String, String>{
      for (final e in _early)
        if (identical(e.db, db)) e.uid: e.sender,
    };
    var any = false;
    for (final u in due.entries) {
      if (!await db.messageExists(u.key)) continue;
      await _applyEarly(u.key, u.value, db, null);
      any = true;
    }
    if (any) {
      await refreshContacts();
      notifyListeners();
    }
  }

  String? _arrivingPoll(Object? raw) {
    final p = PollSpec.parse(raw);
    return p == null
        ? null
        : PollSpec(options: p.options, multi: p.multi).toRow();
  }

  // the packs an arriving sticker is read against. null if none loads: the
  // sticker is then read as one this version does not have
  Future<StickerLibrary?> _stickers() async {
    try {
      return await StickerLibrary.load();
    } catch (e) {
      dlog('stickers: $e');
      return null;
    }
  }

  // the open vault, when it is the everyday identity's: the decoy's own
  // never takes an arrival
  HaloDb? get _openVault {
    final s = _session;
    return identical(s.primary, live) ? s.vault : null;
  }

  // where a chat's rows are for receiving and sending: the open vault's own
  // chats there, every other one in the everyday container
  HaloDb _ownerOf(String chatId) {
    final v = _openVault;
    return v != null && _session.isHidden(chatId) ? v : live;
  }

  // where an arrival for this chat goes. while the vault is open, a chat it
  // holds goes there even before the list names it
  RouteTo _routeOf(String sender, String? groupId) {
    final open = _openVault != null;
    return _router.route(
      sender,
      groupId,
      open: open,
      held: open ? _session.isHidden : null,
    );
  }

  // routing for group controls, reactions and data messages, shared by all
  // three receive paths (back-pair, tor drain, nostr poll). where it goes is
  // decided first: nothing on screen or on disk moves for an arrival that is
  // sealed. into is set when a sealed one is opened, with the time it came
  Future<RouteTo> _applyIncomingPayload(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    bool fromBackPair = false,
    // a contact's device's copy (linked devices): it never moves their caps
    bool fromDevice = false,
    HaloDb? into,
    int? arrivedAt,
    // when the sender wrapped it by their clock, where the lane says. each
    // send wraps anew, so a retry carries its own. when it was written
    // rides in the envelope (heldBySpans)
    int? wrappedAt,
    // a room message from a key taken out, owed from before that (roomOwes)
    bool late = false,
    // when it reached the relay or this phone, by this clock, where the
    // lane says (heldBySpans)
    Reached? reached,
  }) async {
    // typing rides the onion door alone (receiveOnion): on any other lane,
    // or sealed for later, it is dropped unseen
    if (env.typing) return RouteTo.dropped;
    // the dev chat takes a frame only while it runs, and only what his
    // chat may carry, said by his pinned key. the rest is dropped unseen
    if (isDevId(senderHaloId)) {
      final seat = await devLane.seat(senderHaloId);
      final kept = seat == null ? null : devInFrame(senderHaloId, wire);
      if (kept == null) {
        dlog('dev chat: a frame not taken');
        return RouteTo.dropped;
      }
      wire = kept;
      env = unwrapMessage(kept);
    }
    if (into != null) {
      return _fileArrival(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
        fromDevice: fromDevice,
        into: into,
        arrivedAt: arrivedAt,
        wrappedAt: wrappedAt,
        reached: reached,
      );
    }
    await _afterClose();
    // a chat being moved: what arrives for it waits for the list
    if (_moveDone != null) await _afterMove(senderHaloId, env.groupId);
    final keys = [senderHaloId, ?env.groupId];
    for (final k in keys) {
      _arriving[k] = (_arriving[k] ?? 0) + 1;
    }
    final marks = <String>{};
    try {
      final to = await _fileArrival(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
        fromDevice: fromDevice,
        marks: marks,
        wrappedAt: wrappedAt,
        late: late,
        reached: reached,
      );
      if (AppState._shown(to)) _typingAnswered(senderHaloId, env);
      // linked devices: what reached this phone alone goes on to my devices
      if (linkedDevicesOn && !fromDevice && !fromBackPair) {
        await _ownPassOn(senderHaloId, env, wire, to);
      }
      // a v4 first contact keeps no onion until they answer: their first
      // frame on the session gives it, and a held one is never replaced
      if (to == RouteTo.everyday && !fromBackPair && env.groupId == null) {
        await _fillOnion(senderHaloId, env.senderOnion);
      }
      return to;
    } finally {
      for (final k in keys) {
        final n = (_arriving[k] ?? 1) - 1;
        n > 0 ? _arriving[k] = n : _arriving.remove(k);
      }
      // all of it is written now: a chat it changed reads it once more,
      // even if a notify on the way already took the first mark
      for (final k in marks) {
        _bumpChatRev(k);
      }
      if (marks.isNotEmpty) notifyListeners();
    }
  }

  Future<void> _fillOnion(String id, String? onion) async {
    if (onion == null || !RegExp(r'^[a-z2-7]{56}\.onion$').hasMatch(onion)) {
      return;
    }
    try {
      await live.fillOnion(id, onion);
    } catch (e) {
      dlog('onion: not kept (${e.runtimeType})');
    }
  }

  Future<RouteTo> _fileArrival(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    bool fromBackPair = false,
    bool fromDevice = false,
    HaloDb? into,
    int? arrivedAt,
    // the chats to mark once the caller is done, on the live path
    Set<String>? marks,
    int? wrappedAt,
    bool late = false,
    Reached? reached,
  }) async {
    // a uid claimed and never saved is let go, or a copy that comes again
    // is taken for one already in and dropped
    final claims = <String>[];
    try {
      return await _fileArrivalClaiming(
        senderHaloId,
        env,
        wire: wire,
        fromBackPair: fromBackPair,
        fromDevice: fromDevice,
        into: into,
        arrivedAt: arrivedAt,
        marks: marks,
        claims: claims,
        wrappedAt: wrappedAt,
        late: late,
        reached: reached,
      );
    } catch (_) {
      _inflightUids.removeAll(claims);
      rethrow;
    }
  }

  // a take-back from someone blocked: a row of theirs goes, and the slices
  // they sent of it, and a copy of it after an unblock stays out. true when
  // a row went
  Future<bool> _takenBackWhileBlocked(
    String sender,
    String uid,
    HaloDb db,
  ) async {
    await db.noteBlockedDrop(sender, uid);
    await db.dropMediaChunks(uid, from: sender);
    if (!await db.messageExists(uid) || !await db.isTheirs(uid, sender)) {
      return false;
    }
    await db.deleteMessage(uid, from: sender);
    return true;
  }

  Future<RouteTo> _fileArrivalClaiming(
    String senderHaloId,
    UnwrappedMessage env, {
    required String wire,
    required bool fromBackPair,
    required bool fromDevice,
    required HaloDb? into,
    required int? arrivedAt,
    required Set<String>? marks,
    required List<String> claims,
    required int? wrappedAt,
    required bool late,
    required Reached? reached,
  }) async {
    // linked devices: a phone's device words are taken where their device
    // state is (below): the everyday side, or the open vault for a hidden
    // chat. sealed for a shut vault the frame is kept whole and they are
    // taken as it opens. on any other route a frame of nothing else is
    // dropped and the words come out of what is filed
    final words = linkedDevicesOn && !fromDevice && hasDeviceWords(wire);
    final own = words && env.groupId == null && !fromBackPair;
    final at = own
        ? (into != null ? RouteTo.vault : _routeOf(senderHaloId, null))
        : null;
    final takes = at == RouteTo.everyday || at == RouteTo.vault;
    final sealsWhole = at == RouteTo.sealed;
    if (words && !takes && !sealsWhole) {
      if (deviceWordsOnly(wire)) return RouteTo.dropped;
      wire = withoutDeviceWords(wire);
      env = unwrapMessage(wire);
    }
    // what is opened goes with the session it began in
    final epoch = _openedEpoch;
    final RouteTo to;
    final HaloDb db;
    if (into != null) {
      to = RouteTo.vault;
      db = into;
    } else {
      to = _routeOf(senderHaloId, env.groupId);
      if (to == RouteTo.dropped) return to;
      if (to == RouteTo.sealed) {
        // its rows are shut away: what it says of the block is kept in
        // memory, as its row would take it, for the next envelope to it
        final heard = env.shots;
        if (heard != null &&
            env.groupId == null &&
            shotsInTime(heard, DateTime.now().millisecondsSinceEpoch)) {
          _shotsHeard(senderHaloId, heard);
        }
        await _sealArrival(
          senderHaloId,
          env,
          wire,
          fromBackPair,
          wrappedAt: wrappedAt,
          reached: reached,
          fromDevice: fromDevice,
        );
        return to;
      }
      final v = _openVault;
      if (to == RouteTo.vault && v == null) return RouteTo.dropped;
      db = to == RouteTo.vault ? v! : live;
    }
    // opened from the seal: its tick already went, the lists are read again
    // once the batch is in, and what it writes carries the time it came.
    // the clocks that wait on it (a vote's hour, a slice's week) start now
    final unsealing = arrivedAt != null;
    // the live path marks a chat it wrote to once all is written, in
    // _applyIncomingPayload
    void changed() => marks?.addAll([
      senderHaloId,
      if (env.groupId != null) 'group:${env.groupId}',
    ]);
    if (into != null) {
      _bumpChatRev(senderHaloId);
      if (env.groupId != null) _bumpChatRev('group:${env.groupId}');
    }
    dlog(
      'incoming len=${env.message.length} hasPreview=${env.preview != null} uid=${env.msgUid}',
    );
    // nothing from someone blocked is kept or answered, a receipt or a proof
    // neither. their address is listened on while the block holds, so what
    // they send then comes in now, judged by this clock alone. what they
    // wrote is noted by its uid, and a copy of it stays out after an
    // unblock (droppedWhileBlocked)
    if (await db.isBlocked(senderHaloId)) {
      final key = AppState._dataFrame(env) ? env.msgUid ?? env.mediaId : null;
      if (key != null) await db.noteBlockedDrop(senderHaloId, key);
      // two words still count, and neither is answered: a receipt for what
      // went to them before the block, and their own take-back
      final got = env.deliveredUid;
      final since = got == null ? null : await db.blockedSince(senderHaloId);
      if (got != null && since != null) {
        await db.markDelivered(got, from: senderHaloId, before: since);
        _bumpChatRev(senderHaloId);
        notifyListeners();
      }
      final back = env.unsend;
      if (back != null &&
          await _takenBackWhileBlocked(senderHaloId, back, db)) {
        changed();
        await refreshContacts();
        if (env.groupId != null) await refreshGroups();
        notifyListeners();
      }
      return to;
    }
    // linked devices: a contact's phone's lists, bundles and asks, on the
    // everyday side only. a frame of nothing else is never shown
    if (takes) {
      final home = identical(db, live)
          ? live
          : identical(db, _vaultDevOf)
          ? db
          : null;
      if (home != null) {
        if (await _devPhoneFrames(
          senderHaloId,
          wire,
          home: home,
          unsealed: into != null,
        )) {
          return RouteTo.dropped;
        }
      } else if (deviceWordsOnly(wire)) {
        return RouteTo.dropped;
      }
      wire = withoutDeviceWords(wire);
      env = unwrapMessage(wire);
    }
    await _takeShots(senderHaloId, env, db);
    // a device's copy carries no caps of the phone's: they stay as they are
    final capsMoved = !fromDevice && await _takeCaps(senderHaloId, env, db);
    if (!fromDevice) {
      await _memberCaps(senderHaloId, env, db, oneToOneMoved: capsMoved);
    }
    // their phone takes a pq restart now: their held chat is looked at
    if (capsMoved &&
        (to == RouteTo.everyday || to == RouteTo.vault) &&
        env.groupId == null &&
        (env.caps?.contains(kCapPqRestart) ?? false)) {
      unawaited(pqUpkeep(only: senderHaloId));
    }
    // a pq restart's KDB1: taken only inside a held 1:1 session, of the
    // everyday side or the open vault (as a sealed one opens too), and
    // never shown
    final rq = env.pqRestart;
    if (rq != null) {
      if (!fromBackPair &&
          (to == RouteTo.everyday || to == RouteTo.vault) &&
          env.groupId == null) {
        await takePqRestart(senderHaloId, rq, writtenAt: env.writtenAt, on: db);
      } else {
        dlog('pq restart: a bundle off a held chat, dropped');
      }
      return to;
    }
    // delivery receipt, handled before the stranger gate and dedup so an ack
    // is never treated as a message or counted toward the cap. it leaves
    // back-paired alone: that flag lifts the sender-side cap, and a stranger
    // could then write past the two the other side will keep.
    if (env.deliveredUid != null) {
      await db.markDelivered(env.deliveredUid!, from: senderHaloId);
      _bumpChatRev(senderHaloId);
      notifyListeners();
      return to;
    }
    if (proofOfEngagement(env)) {
      final was = await db.isBackPaired(senderHaloId);
      await db.markBackPaired(senderHaloId);
      if (!was) {
        // their first-contact address is spent, and a card must never hand
        // on one they may reset
        unawaited(forgetPeerFc(senderHaloId));
        // added back: our photo may go to them now
        unawaited(photoSweep());
        // the door just opened: rows parked for them go now, not when the
        // backoff runs out
        _outboxTries.clear();
        _outboxNextAt.clear();
        unawaited(drainOutbox());
        // and what went to them as a stranger with no receipt back goes
        // again, once, on the lane they read now (resendUndelivered)
        if (!db.container.quiet && env.groupId == null) {
          // no further back than a copy is known as gone there
          final floor =
              DateTime.now().millisecondsSinceEpoch -
              HaloDb.kGoneFor.inMilliseconds;
          unawaited(
            _resendTo(db, senderHaloId, floor: floor).catchError((Object e) {
              dlog('resend: not on their add (${e.runtimeType})');
            }),
          );
        }
      }
    }
    // what comes from someone once blocked is judged by when it reached
    // the relay or this phone, by this clock, and by how long before it
    // went it was written, by theirs (heldBySpans). nothing is noted by it
    final ended = [
      for (final (f, t) in await db.blockSpansOf(senderHaloId))
        if (t != null) (f, t),
    ];
    if (ended.isNotEmpty &&
        heldBySpans(
          ended,
          reached: reached,
          came: arrivedAt ?? DateTime.now().millisecondsSinceEpoch,
          now: DateTime.now().millisecondsSinceEpoch,
          written: env.writtenAt,
          wrapped: wrappedAt,
        )) {
      dlog('recv: may be from a block that ended, dropped');
      return to;
    }
    // the developer's own phone: a chat started from the Marios row goes to
    // support by its marker, and is never a way into his groups or contacts
    final support = await _supportOf(senderHaloId, env, db);
    if (support.on && supportRefuses(env)) {
      dlog('support: a group or an introduction, dropped');
      return to;
    }
    // the words an ended group's admin left for older versions: those
    // show them, this one shows the end itself
    if (env.endNotice) {
      dlog('group: an end notice, dropped');
      return to;
    }
    // and so are its words on a block this version reads for itself
    if (env.shotsNudge) {
      dlog('group: a shots notice, dropped');
      return to;
    }
    if (await _endRefuses(senderHaloId, env.groupId, env, db)) return to;
    // a group control
    if (env.groupControl != null) {
      await _applyGroupControl(
        senderHaloId,
        env,
        db,
        at: arrivedAt,
        opener: fromBackPair,
      );
      changed();
      return to;
    }
    // 1.5) introduction: a friend hands us someone's card
    if (env.intro != null) {
      await _applyIntro(senderHaloId, env.intro!, db, at: arrivedAt);
      changed();
      return to;
    }
    // they are missing slices of something we sent them
    if (env.need != null) {
      await _answerNeed(senderHaloId, env.need!, db);
      return to;
    }
    // a slice of their profile photo, or its take-back
    if (env.photo != null) {
      await _takePhoto(senderHaloId, env, db);
      return to;
    }
    // a frame for a message not here yet waits for it, from a contact or a
    // member of the group it names, and only in the session it came in
    Future<void> early(String uid) async {
      final ok = env.groupId == null
          ? await db.isAccepted(senderHaloId)
          : (await db.getGroupMembers(env.groupId!)).contains(senderHaloId);
      if (!ok || epoch != _openedEpoch) return;
      // nothing waits for one that went on a device of mine
      if (await _ownGoneFrom(db, senderHaloId, env.groupId, uid)) return;
      _parkEarly((
        uid: uid,
        db: db,
        into: into,
        sender: senderHaloId,
        wire: wire,
        arrivedAt: arrivedAt,
        wrappedAt: wrappedAt,
        reached: reached,
        at: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    // shared pin: every member mirrors it. only from someone in the chat
    // the row lives in: the frame names a uid and nothing else, and it rides
    // in above the stranger gate like an edit does.
    if (env.pin != null) {
      final where = await db.chatOf(env.pin!.targetUid);
      if (where == null) {
        await early(env.pin!.targetUid);
        return to;
      }
      final ok = pinAllowed(
        rowPeer: where.$1,
        rowGroup: where.$2,
        sender: senderHaloId,
        frameGroup: env.groupId,
        members: where.$2 == null
            ? const []
            : await db.getGroupMembers(where.$2!),
      );
      if (!ok) {
        dlog('pin: dropped, sender is not in that chat');
        return to;
      }
      if (env.groupId == null &&
          await _endRefuses(senderHaloId, where.$2, env, db)) {
        return to;
      }
      // the sender counts before it pins, but that is their word. held
      // here too, or a member could fill the list from afar.
      if (env.pin!.pinned) {
        final held = await db.pinnedIn(peerId: where.$1, groupId: where.$2);
        if (held.length >= kMaxPins &&
            !held.any((r) => r['msg_uid'] == env.pin!.targetUid)) {
          dlog('pin: dropped, that chat is full');
          return to;
        }
      }
      await db.setPinned(env.pin!.targetUid, env.pin!.pinned, at: arrivedAt);
      changed();
      notifyListeners();
      return to;
    }
    // polls: a vote, or the creator closing one
    if (env.vote != null) {
      await _applyVote(senderHaloId, env, db);
      changed();
      return to;
    }
    if (env.pollClose != null) {
      await _applyPollClose(senderHaloId, env, db);
      changed();
      return to;
    }
    // a reaction
    if (env.reaction != null) {
      final r = env.reaction!;
      // the frame names a uid and nothing else, so only someone in the chat
      // that row lives in gets to react to it
      final where = await db.chatOf(r.targetUid);
      if (where == null) {
        await early(r.targetUid);
        return to;
      }
      final ok = pinAllowed(
        rowPeer: where.$1,
        rowGroup: where.$2,
        sender: senderHaloId,
        frameGroup: env.groupId,
        members: where.$2 == null
            ? const []
            : await db.getGroupMembers(where.$2!),
      );
      if (!ok || r.emoji.length > 32) {
        dlog('reaction: dropped');
        return to;
      }
      if (env.groupId == null &&
          await _endRefuses(senderHaloId, where.$2, env, db)) {
        return to;
      }
      if (!await _inOrder(db, r.targetUid, senderHaloId, 'reaction', env)) {
        return to;
      }
      if (r.emoji.isEmpty) {
        await db.removeReaction(r.targetUid, senderHaloId);
      } else {
        await db.addReaction(r.targetUid, senderHaloId, r.emoji, at: arrivedAt);
      }
      changed();
      return to;
    }
    // 2.5) edit: swap the text of an existing message
    if (env.edit != null) {
      // only the author. these frames ride in above the stranger gate, so
      // anyone who can reach us could rewrite any row by uid otherwise.
      if (await db.isTheirs(env.edit!.targetUid, senderHaloId)) {
        if (env.groupId == null &&
            await _endRefuses(
              senderHaloId,
              (await db.chatOf(env.edit!.targetUid))?.$2,
              env,
              db,
            )) {
          return to;
        }
        if (!await _inOrder(
          db,
          env.edit!.targetUid,
          senderHaloId,
          'edit',
          env,
        )) {
          return to;
        }
        await db.editMessage(
          env.edit!.targetUid,
          env.edit!.newText,
          from: senderHaloId,
        );
        changed();
        // home's row shows the last line, and only a refresh rereads it
        await refreshContacts();
        notifyListeners();
      } else if (!await db.messageExists(env.edit!.targetUid)) {
        await early(env.edit!.targetUid);
      }
      return to;
    }
    // 2.6) unsend: sender recalled a message; delete our copy
    if (env.unsend != null) {
      // a row that exists must be theirs. a half-file with no row yet has
      // nothing to protect, and its sender stopping it is the point.
      if (await db.messageExists(env.unsend!) &&
          !await db.isTheirs(env.unsend!, senderHaloId)) {
        return to;
      }
      if (env.groupId == null &&
          await _endRefuses(
            senderHaloId,
            (await db.chatOf(env.unsend!))?.$2,
            env,
            db,
          )) {
        return to;
      }
      _noteTakenBack(senderHaloId, env.unsend!);
      // one not here yet stays away after a restart too, when it is kept
      // to be tried again or they are someone accepted. a stranger's word
      // on any other uid is noted in memory only, so it fills no disk
      if (env.groupId == null &&
          !await db.messageExists(env.unsend!) &&
          (await db.isAccepted(senderHaloId) ||
              await db.firstKeptHas(senderHaloId, env.unsend!))) {
        await db.noteTakenBack(senderHaloId, env.unsend!);
        await db.forgetFirstOf(senderHaloId, uid: env.unsend!);
      }
      // a member's word in a group or a room: its copy the relays still
      // hold stays away after a restart or a restore. anyone else's, or a
      // group this phone is not in, is held in memory only, as a stranger's
      if (env.groupId != null &&
          goneKept(env.groupId) &&
          !await db.messageExists(env.unsend!) &&
          await db.getGroup(env.groupId!) != null &&
          (await db.getGroupMembers(env.groupId!)).contains(senderHaloId)) {
        await db.noteTakenBack(
          goneKey(senderHaloId, group: env.groupId),
          env.unsend!,
        );
      }
      await db.deleteMessage(env.unsend!, from: senderHaloId);
      changed();
      // the delete took its unread mark; its notification goes too
      unawaited(_io.unnotifyMessage(env.unsend!));
      // a recall mid-transfer would otherwise leave a half-filled buffer and
      // a progress bar that never completes. drop both: the slices its
      // sender sent, never another sender's
      if (await db.dropMediaChunks(env.unsend!, from: senderHaloId) > 0) {
        incomingMediaDone(db.container.chatKey(env.groupId ?? senderHaloId));
      }
      // and a file still coming from the files service stops coming
      await _dropFetchTakenBack(senderHaloId, env.unsend!, db);
      // refresh so it vanishes live if the peer's looking at the chat now,
      // not only after they leave and come back. home shows the count too
      await refreshContacts();
      if (env.groupId != null) await refreshGroups();
      notifyListeners();
      return to;
    }
    // a data message, 1:1 or group
    final blockedKey = env.msgUid ?? env.mediaId;
    if (blockedKey != null &&
        await db.droppedWhileBlocked(senderHaloId, blockedKey)) {
      dlog('recv: written while they were blocked, dropped');
      return to;
    }
    final isGroup = env.groupId != null;
    if (isGroup && !await db.groupExists(env.groupId!)) {
      // unknown group: drop, so random senders cannot inject rows into
      // groups we never joined
      dlog('dropping group msg for unknown group ${env.groupId}');
      return to;
    }
    // a group's messages, polls and slices come from its members, here and
    // when a sealed one is opened. a room key taken out still has what it
    // sent before that let in, checked where the frame came in
    if (isGroup &&
        !late &&
        !(await db.getGroupMembers(env.groupId!)).contains(senderHaloId)) {
      dlog('group msg: dropped, the sender is not a member');
      return to;
    }
    // badge rides real chat rows only. present = set, absent = clear so
    // turning it off propagates. control frames and preview patches never
    // get here with a fresh row, so they can't wipe it.
    if (env.preview == null && env.msgUid != null && !isDevId(senderHaloId)) {
      await db.setContactBadge(senderHaloId, env.supporterBadge);
    }
    // roster self-heal: if the admin rode their full member list on this
    // message and our copy drifted, reconcile. only trust it from the real
    // admin so a member can't rewrite membership by spoofing a roster.
    // an ended group's members stay as they were at its end
    if (isGroup &&
        env.roster != null &&
        !support.on &&
        groupEndOf(await db.getGroup(env.groupId!)) == null) {
      final adminId = await db.groupAdminId(env.groupId!);
      final isRoom = await _roomOf(env.groupId!, db) != null;
      final roster = _members(env.roster!, room: isRoom);
      // the admin is always on their own list: one without them is from a
      // phone that already left, and would empty the group here
      final fromAdmin =
          adminId != null &&
          senderHaloId == adminId &&
          roster.contains(adminId);
      // the admin's own list without this phone: taken out, as a remove
      // naming it says, and that remove may never come
      if (fromAdmin && !isRoom && !roster.contains(myId)) {
        final name = (await db.getGroup(env.groupId!))?['name'] as String?;
        await _dropGroup(env.groupId!, db);
        if (name != null) _removedFrom[env.groupId!] = name;
        _bumpChatRev('group:${env.groupId}');
        await refreshGroups();
        return to;
      }
      if (fromAdmin &&
          await _fitsCap(env.groupId!, roster.toSet().length, db)) {
        final seats = await _seats(env.rosterParticipants, db, room: isRoom);
        final out = await _keyBlockedSeats(
          env.rosterParticipants,
          room: isRoom,
        );
        await db.syncGroupMembers(env.groupId!, [
          for (final h in roster)
            if (!out.contains(h)) seats[h] ?? h,
        ]);
        await _subscribeRoomMembers(env.groupId!);
        if (isRoom) await _roomLetIn(env.groupId!, roster, db);
        // contact stubs for self-healed members so we can encrypt to them:
        // ids alone are not enough, we need their keys
        if (env.rosterParticipants != null) {
          for (final p in env.rosterParticipants!) {
            final h = p['h'];
            final o = p['o'];
            final x = p['x'];
            if (h != null &&
                o != null &&
                x != null &&
                h != myId &&
                !out.contains(h) &&
                wireIdShaped(h, room: isRoom) &&
                !devCardClaim(id: h, xPub: x)) {
              await db.upsertContactStub(seats[h] ?? h, o, x);
            }
          }
          await refreshContacts();
        }
      }
    }
    // the admin's word on the group's screenshot block heals as the
    // roster does, from the admin alone
    final heard = env.groupShots;
    if (isGroup && heard != null && !support.on) {
      await _takeGroupShots(env.groupId!, senderHaloId, heard, db);
    }
    // stranger lock + proof-of-work gate (1:1 only, unaccepted senders).
    // a sender a friend introduced is not a stranger: no pow, no cap. they
    // still land in requests and still need an accept to get a reply.
    if (!isGroup && !await db.isAccepted(senderHaloId)) {
      final vouched = await db.isVouched(senderHaloId);
      // pow: only the back-pair message (true first contact) must carry a
      // valid nonce, the one lane a cold stranger can arrive on. a whisper
      // through an existing session already paid once. dropped silently so
      // the spammer learns nothing.
      if (!vouched && fromBackPair && !firstPowHolds(env)) {
        dlog(
          'pow: dropping first-contact from $senderHaloId (nonce=${env.powNonce} bits=${env.powBitsUsed})',
        );
        firstFails.note('pow');
        throw const _NoProof();
      }
      // a stranger's photos and files wait on the shelf until the accept,
      // from any version. none of them counts toward the two
      if (strangerMediaWaits(
        env,
        accepted: false,
        vouched: vouched,
        support: support.on,
        dev: isDevChat(senderHaloId),
      )) {
        dlog('stranger: a file held until accepted');
        throw _HeldIn(db);
      }
      // 2-message cap: a stranger gets 2 into requests, then the chat is locked
      // until we accept them. past the cap there is no receipt. a file still
      // in slices counts as one of the two, and its own slices come in
      final have = vouched
          ? 0
          : await db.countMessagesFrom(senderHaloId) +
                await db.filesInFlightFrom(
                  senderHaloId,
                  // a file from the files service is its message's own
                  except: AppState._sliced(env) ? env.mediaId : env.msgUid,
                );
      if (strangerCapHolds(
        accepted: false,
        vouched: vouched,
        have: have,
        cap: support.on ? kSupportCap : 2,
      )) {
        dlog('stranger lock: holding from $senderHaloId (cap hit)');
        throw _HeldIn(db);
      }
    }
    // chunked media: a big image/file arrives as several envelopes sharing one
    // mediaId. buffer the slices until all chunkTotal are in, then rebuild the
    // full base64. single-chunk (or unchunked) media skips this entirely.
    String? imgB64 = env.imageB64;
    String? fileB64v = env.fileB64;
    // burn seconds can ride on any slice (older senders only put it on the
    // first). hold onto whichever one carried it so the rebuilt message keeps
    // its timer instead of landing permanent on the receiver.
    int? chunkBurn = env.burnSeconds;
    // a sealed arrival counts from a day after it came at the latest, read
    // or not (kBurnWaitMost): one whose clock ran out while the vault was
    // shut goes unread, as it would have on time. one with no uid counts
    // from when it came. never a stranger's, whose timers do not count
    Future<bool> burnedWhileSealed() async {
      final at = arrivedAt;
      final secs = chunkBurn;
      if (at == null || secs == null || secs <= 0) return false;
      final now = DateTime.now().millisecondsSinceEpoch;
      final from = env.msgUid == null ? at : burnStartBy(at, now);
      if (from + secs * 1000 > now) return false;
      return isGroup || await db.isAccepted(senderHaloId);
    }

    // a save can fail, a full phone say. the message still lands, with a
    // line saying what is missing, rather than an empty bubble
    String? mediaPath;
    String? filePath;
    var unsaved = false;
    final fileName = env.fileName;
    // dedup comes before anything is written, so a uid this phone holds or
    // is filing right now never touches a file. the db check alone races
    // when two copies arrive at once, so an in-memory set of uids in flight
    // backs it: the first in claims the uid, a twin takes the known path
    final uid = env.msgUid;
    final taken = AppState._sliced(env) ? env.mediaId : uid;
    if (taken != null && _wasTakenBack(senderHaloId, taken)) {
      dlog('recv: taken back before it came, dropped');
      return to;
    }
    String? sliced;
    if (AppState._sliced(env)) {
      final mid = env.mediaId!;
      final total = env.chunkTotal!;
      final index = env.chunkIndex ?? 0;
      // the container's own: the same chat id can be another container's
      final progressKey = db.container.chatKey(
        isGroup ? env.groupId! : senderHaloId,
      );
      final slice = (env.imageB64 ?? env.fileB64) ?? '';
      // a sliced file is filed under its own id
      if (uid != null && uid != mid) {
        dlog('recv: slice of another message id, dropped');
        return to;
      }
      // a slice has a place in its file, and a file has a bounded number
      // of them
      if (total > kMaxSlices || index < 0 || index >= total) {
        dlog('recv: slice out of range, dropped');
        return to;
      }
      // a file, a photo or a voice note is no bigger than any kryfo sends.
      // only a voice note's own slices get the longer cap
      final voiceSlices =
          env.voice && env.fileB64 != null && env.imageB64 == null;
      if (total > (voiceSlices ? kMaxVoiceSlices : kMaxFileSlices)) {
        dlog('recv: a file over the size any kryfo sends, dropped');
        return to;
      }
      // a file's slices come from one sender
      final owner = await db.mediaChunkSender(mid);
      if (owner != null && owner != senderHaloId) {
        dlog('recv: slice of a file another sender is sending, dropped');
        return to;
      }
      if (_inflightUids.contains(mid)) return to;
      // a slice of a file already put together: the sender went round
      // again. buffering it would start a copy that never finishes. one
      // receipt per pass, on the first slice, so the sender can stop. one
      // that went here, deleted or burned, stays gone the same way
      final gone =
          await db.goneFrom(goneKey(senderHaloId, group: env.groupId), mid) ||
          await _ownGoneFrom(db, senderHaloId, env.groupId, mid);
      if (gone || await db.messageFrom(mid, senderHaloId, env.groupId)) {
        if (!isGroup &&
            !unsealing &&
            (env.chunkIndex ?? 0) == 0 &&
            senderHaloId != myId) {
          unawaited(_sendDeliveryReceipt(senderHaloId, mid));
        }
        unawaited(db.dropMediaWant(mid));
        // slices a filed one left, if its drop did not get as far
        await db.dropMediaChunks(mid, from: senderHaloId);
        return to;
      }
      // slices land on disk as they arrive and the count is over rows, so a
      // restart resumes instead of starting over
      final have = await db.putMediaChunk(
        mid,
        index,
        slice,
        total,
        (env.burnSeconds != null && env.burnSeconds! > 0)
            ? env.burnSeconds
            : null,
        from: senderHaloId,
        group: env.groupId,
      );
      chunkBurn = await db.mediaChunkBurn(mid) ?? chunkBurn;
      if (have < total && !isGroup && senderHaloId != myId) {
        await db.noteMediaWant(mid, senderHaloId, total, env.canResend);
      }
      if (have < total) {
        // what waits unfinished has a ceiling: past it the file whose last
        // slice came longest ago goes, this one too if it alone is past it
        final gone = await db.trimUnfinishedMedia(keep: _inflightUids);
        if (gone.contains(mid)) {
          incomingMediaDone(progressKey);
          return to;
        }
        // still waiting on more pieces: surface how far along we are. a
        // voice note is seconds of audio; the banner is for the long ones.
        // a gif shows none either: it just appears
        if (!env.voice && !env.gif) {
          incomingMediaUpdate(progressKey, have, total);
        }
        return to;
      }
      desk_trace.trace('media slices whole ($total)');
      if (await burnedWhileSealed()) {
        await db.dropMediaChunks(mid);
        unawaited(db.dropMediaWant(mid));
        incomingMediaDone(progressKey);
        return to;
      }
      // a room's file is told by its bytes once whole: one the remove of
      // its sender did not name goes, slices and all
      if (isGroup && !await _roomFileTaken(senderHaloId, env, db, late: late)) {
        dlog('room: a file not named, dropped');
        await db.dropMediaChunks(mid);
        incomingMediaDone(progressKey);
        return to;
      }
      // all pieces in. each goes from the database to the file on its own,
      // so the whole file is never in memory at once. a preview thumbnail
      // from an older client is never drawn, never kept.
      if (!_inflightUids.add(mid)) return to;
      claims.add(mid);
      if (!env.pvImg) {
        try {
          final out = fileName != null
              ? await receivedFileFor(fileName, db.container)
              : await receivedImageFor(db.container);
          final path = await saveSlices(
            out,
            total,
            (i) => db.mediaChunkSlice(mid, i),
          );
          if (fileName != null) {
            filePath = path;
          } else {
            mediaPath = path;
          }
        } catch (e) {
          dlog('recv: chunked media not saved: $e');
          unsaved = true;
        }
      }
      unawaited(db.dropMediaWant(mid));
      incomingMediaDone(progressKey);
      if (env.pvImg) {
        await db.dropMediaChunks(mid);
        _inflightUids.remove(mid);
        return to;
      }
      // the slices stay until the row is filed, so one that fails before
      // that is put together again when it comes again
      sliced = mid;
      // the slice in this envelope is on disk now; nothing below should
      // save it again
      imgB64 = null;
      fileB64v = null;
    } else if (await burnedWhileSealed()) {
      return to;
    } else if (uid != null) {
      // one that came and went here is known too, so a resend of it never
      // shows again. known is per sender and chat: a group's uid reaches
      // every member, and one who sends it first must not hide the real one
      final known =
          _inflightUids.contains(uid) ||
          await db.messageFrom(uid, senderHaloId, env.groupId) ||
          await db.goneFrom(goneKey(senderHaloId, group: env.groupId), uid) ||
          await _ownGoneFrom(db, senderHaloId, env.groupId, uid);
      // a preview-only frame from an older client carries nothing we draw:
      // a sender never gets to put a title or an image on this screen
      final previewOnly =
          env.preview != null &&
          env.message.isEmpty &&
          env.imageB64 == null &&
          env.fileB64 == null &&
          env.drop == null;
      if (previewOnly) return to;
      if (known) {
        // already have it, but a re-send means our receipt never landed. ack
        // again so the sender's tick flips and the outbox stops redelivering.
        if (!isGroup &&
            !unsealing &&
            env.deliveredUid == null &&
            env.reaction == null &&
            env.edit == null &&
            senderHaloId != myId) {
          unawaited(_sendDeliveryReceipt(senderHaloId, uid));
        }
        notifyListeners();
        return to;
      }
      _inflightUids.add(uid);
      claims.add(uid);
      if (env.drop != null) {
        // a room's files go in slices, told by their bytes: a frame there
        // carries none
        if (isGroup && await _roomOf(env.groupId!, db) != null) {
          dlog('room: a files service frame, dropped');
          _inflightUids.remove(uid);
          return to;
        }
        // one filed before its file keeps its place in its album, which
        // draws it waiting
        final (got, waits: _) = await _dropArrived(
          senderHaloId,
          env,
          db,
          wire: wire,
          fromBackPair: fromBackPair,
        );
        if (got == null) {
          // here, its file still on the way: the sender can stop sending
          // the frame, and the chat shows it once the file is in
          _inflightUids.remove(uid);
          claims.remove(uid);
          if (!isGroup && !unsealing && senderHaloId != myId) {
            unawaited(_sendDeliveryReceipt(senderHaloId, uid));
          }
          return to;
        }
        if (got.isEmpty) {
          unsaved = true;
        } else if (fileName != null) {
          filePath = got;
        } else {
          mediaPath = got;
        }
      }
    }
    if (imgB64 != null && imgB64.isNotEmpty) {
      try {
        mediaPath = await saveMediaBytes(base64Decode(imgB64), db.container);
      } catch (e) {
        dlog('recv: image not saved: $e');
        unsaved = true;
      }
    }
    if (fileB64v != null && fileB64v.isNotEmpty) {
      try {
        filePath = await saveFileBytes(
          base64Decode(fileB64v),
          fileName ?? 'file',
          db.container,
        );
      } catch (e) {
        dlog('recv: file not saved: $e');
        unsaved = true;
      }
    }
    // the blur its bubble shows first, made now while unlocked
    for (final made in [mediaPath, filePath]) {
      if (made != null && made.isNotEmpty) makeBlurSoon(made);
    }
    final bodyText = unsaved
        ? [
            env.message,
            l10n.appAnAttachmentCouldNotShown,
          ].where((s) => s.trim().isNotEmpty).join('\n')
        : env.message;
    // a sticker is a message of its own: a frame with media, a file or a
    // poll on it is read without it
    final bare =
        env.imageB64 == null &&
        env.fileB64 == null &&
        env.drop == null &&
        env.fileName == null &&
        env.mediaId == null &&
        env.poll == null;
    final sticker = bare ? StickerWire.parse(env.sticker) : null;
    // a known sticker's text is our own emoji for it, never the sender's
    final text = sticker == null
        ? bodyText
        : stickerText(sticker, env.message, await _stickers());
    // what the sender said, as far as this phone shows it
    final said = sticker == null ? env.message : text;
    // a stranger doesn't get to set disappearing rules in the inbox: burned
    // rows refund the 2-message cap and can vanish before the request is even
    // seen. burn only counts once they're accepted.
    // no uid and nothing to draw: a signal, an accept's ack say, never a
    // message. kept, it is a blank row and an unread
    if (env.msgUid == null &&
        said.trim().isEmpty &&
        sticker == null &&
        mediaPath == null &&
        filePath == null &&
        env.poll == null &&
        env.preview == null &&
        !unsaved) {
      // the face they picked rides on it all the same
      if (env.senderAvatar != null) {
        await db.setContactAvatar(senderHaloId, env.senderAvatar);
      }
      return to;
    }
    // a deleted (parked) peer writing again surfaces as a fresh request.
    if (!isGroup) await db.unparkIfArchived(senderHaloId);
    final senderAccepted = await db.isAccepted(senderHaloId);
    // its clock starts when it is first read (lightReadBurns), not here
    final burnOk = isGroup || senderAccepted;
    final burnSecs = burnOk && chunkBurn != null && chunkBurn > 0
        ? chunkBurn
        : null;
    final now = DateTime.now().millisecondsSinceEpoch;
    // placed by when they wrote it (writtenAtOf). a group's from when this
    // phone joined it
    final writtenAt = writtenAtOf(
      env.writtenAt,
      wrapped: wrappedAt,
      reached: reached,
      came: arrivedAt ?? now,
      since: env.groupId == null ? null : await db.groupJoinedAt(env.groupId!),
    );
    // after a restore, a copy from before it counts from when it was first
    // there to read, never from now: one long due lands burned
    final came = burnSecs == null
        ? arrivedAt ?? now
        : burnCameAt(
            arrivedAt ?? now,
            reached: reached,
            written: writtenAt,
            restoredAt: restoreLandedAt,
          );
    // its window from when it came: the most its text stays in the shade
    final burnFromArrival = burnSecs == null ? null : came + burnSecs * 1000;
    // one with no uid can never be named as read: it counts from arrival
    final waits = env.msgUid != null;
    // opened from the seal a day or more after it came: its clock started
    // then, unread
    final startBy = burnStartBy(came, now);
    final burnAt = burnSecs == null
        ? null
        : !waits
        ? burnFromArrival
        : startBy <= now
        ? startBy + burnSecs * 1000
        : null;
    // burned before it came: kept to be swept, and it rings for no one
    final burned = burnAt != null && burnAt <= now;
    // an album rings once, for the first of it to land. only a photo or a
    // video takes a place in one, and only a place that is free, of the
    // count the album has, written near its first row: any other stands
    // alone and rings for itself. one of an album that burned already
    // joins nothing and burns as it lands
    var album =
        (env.imageB64 != null ||
            env.fileB64 != null ||
            env.drop != null ||
            AppState._sliced(env))
        ? env.album
        : null;
    var albumSeen = false;
    var albumGone = false;
    if (album != null) {
      final held = await db.albumHeld(album.id, senderHaloId, env.groupId);
      if (held == null &&
          await db.goneFrom(
            goneKey(senderHaloId, group: env.groupId),
            albumGoneUid(album.id),
          )) {
        albumGone = true;
        album = null;
      } else if (held != null) {
        // near the first by when it was written and by when it came: a time
        // set back never slips a late one in
        final fits =
            held.n == album.n &&
            !held.taken.contains(album.i) &&
            albumInWindow(held.first, writtenAt) &&
            albumInWindow(held.came, arrivedAt ?? now);
        albumSeen = fits;
        if (!fits) album = null;
      }
    }
    // past the gates: what it says of their phone is kept on their own row
    await _takeOpus(senderHaloId, env, db);
    await db.saveMessage(
      senderHaloId,
      'in',
      text,
      album: album,
      burnSecs: albumGone || !waits ? null : burnSecs,
      burnAt: albumGone ? DateTime.now().millisecondsSinceEpoch : burnAt,
      msgUid: env.msgUid,
      replyTo: env.replyTo,
      groupId: env.groupId,
      voiceDisguised: env.voiceDisguised,
      mediaPath: mediaPath,
      filePath: filePath,
      fileName: fileName,
      // a preview the sender fetched over tor, title and url only. kept from
      // someone accepted or a member of a group you chose to be in; a
      // stranger's title is text they control and stays plain. a room's
      // frames never reach this path.
      preview: shippedPreview(env.preview, accepted: isGroup || senderAccepted),
      secure: env.secure,
      // a poll lives in a group or a room; in a 1:1 it is just its question.
      // never closed on arrival, whatever the frame says: only a close from
      // its creator does that
      poll: isGroup ? _arrivingPoll(env.poll) : null,
      sticker: sticker?.value,
      // a timed copy from before a restore keeps its earlier start, which
      // its wait to be read counts from
      sentAt: came < (arrivedAt ?? now) ? came : arrivedAt,
      writtenAt: writtenAt,
      // his phone: a contact who wrote through the developer chat keeps
      // their chat, and the message says how it came
      viaDev:
          _devIdentity &&
          to == RouteTo.everyday &&
          viaDevChat(
            env,
            sender: senderHaloId,
            filed: support.on,
            accepted: senderAccepted,
          ),
    );
    changed();
    if (sliced != null) await db.dropMediaChunks(sliced);
    // an end filed while this one was: it goes with the rest
    if (isGroup && groupEndOf(await db.getGroup(env.groupId!)) != null) {
      await _wipeAgain(env.groupId!, db);
      return to;
    }
    // remember the face they picked. cheap, and it arrives with every
    // message so it stays current if they change it.
    if (env.senderAvatar != null) {
      await db.setContactAvatar(senderHaloId, env.senderAvatar);
    }
    // scam shield: a stranger's request, on this phone only. never a
    // contact, a group or the developer's pinned key
    if (!senderAccepted &&
        !isGroup &&
        senderHaloId != myId &&
        !isDevId(senderHaloId)) {
      unawaited(_runShield(senderHaloId, said, db));
    }
    // saved now, messageExists covers dedup from here
    _inflightUids.removeAll(claims);
    claims.clear();
    if (!isGroup && !unsealing && senderHaloId != myId) benchGot(env.writtenAt);
    // an edit that came first is the text it shows
    final edited = env.msgUid == null
        ? null
        : await _applyEarly(env.msgUid!, senderHaloId, db, marks);
    // send a delivery receipt back for 1:1 messages we just stored, so the
    // sender's tick means "on your phone" not "a relay took it". groups skip
    // this (N acks per message is noise); receipts themselves carry no uid of
    // their own and are handled before any gate on the far side.
    if (!isGroup && !unsealing && uid != null && senderHaloId != myId) {
      unawaited(_sendDeliveryReceipt(senderHaloId, uid));
    }
    // notification context: for groups, title = group name and body
    // prefixes the sender. payload uses "group:<id>" so tap-to-open can
    // route to the right screen.
    // the chat is being read only where its rows are shown: the same id
    // open in another container is another chat
    final reading = readingIn(
      isGroup ? 'group:${env.groupId}' : senderHaloId,
      db.container,
    );
    if (!isGroup && !reading) {
      await db.bumpUnread(senderHaloId);
    } else if (!isGroup) {
      // already reading this chat: clear any stale badge
      await db.clearUnread(senderHaloId);
    } else if (env.groupId != null) {
      if (!reading) {
        await db.bumpGroupUnread(env.groupId!);
        if (mentionsMe(said, myId)) {
          await db.setGroupMentioned(env.groupId!);
        }
      } else {
        await db.clearGroupUnread(env.groupId!);
      }
    }
    // a batch opened from the seal is shown once it is all in, and what
    // came while the vault was shut does not ring now
    if (unsealing) return to;
    // a message landed: rebuild the contact list so the home shows the
    // new preview, time and unread dot without needing the chat opened.
    await refreshContacts();
    if (isGroup) await refreshGroups();
    if (albumSeen || albumGone || burned) return to;
    final String notifTitle;
    final String notifBody;
    final String notifPayload;
    final bool suppress;
    final shownText = edited ?? env.message;
    // the name given to them here. android keeps titles in its history, so
    // with none given it says someone, never their id
    final nickname =
        (await db.getContact(senderHaloId))?['nickname'] as String?;
    final named = nickname == null || nickname.isEmpty
        ? l10n.notificationsSomeone
        : nickname;
    if (isGroup) {
      final g = await db.getGroup(env.groupId!);
      // ended as this one was filed: it goes, and nothing rings
      if (groupEndOf(g) != null) {
        await _wipeAgain(env.groupId!, db);
        return to;
      }
      // a room always blocks, a group may: not even its name in the shade
      final hush = GroupShots.ofRow(g).blocking;
      notifTitle = hush ? 'Kryfo' : (g?['name'] as String?) ?? l10n.appGroup2;
      final gBody = sticker != null
          ? l10n.stickerLabel
          : env.poll != null && PollSpec.parse(env.poll) != null
          ? l10n.pollPreview(env.message)
          : shownText.isNotEmpty
          ? shownText
          : album != null
          ? l10n.albumLabel(whole(album.n))
          : notifMediaLine(fileName, mediaPath);
      // a room member's tag is cut from their key: someone too
      final who = looksLikeRoomKey(senderHaloId)
          ? l10n.notificationsSomeone
          : named;
      // none of it in the shade either
      notifBody = hush ? l10n.notificationsNewMessage : '$who: $gBody';
      notifPayload = 'group:${env.groupId}';
      suppress = reading;
    } else if (!senderAccepted) {
      // a stranger chose these words; they do not go on a lock screen
      // where anyone nearby reads them. that a request arrived is enough.
      notifTitle = l10n.appNewRequest;
      notifBody = l10n.appSomeoneYouHaveNot;
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    } else if (await _shotsBlock(db, senderHaloId)) {
      // a chat that blocks screenshots puts none of itself in the shade
      notifTitle = 'Kryfo';
      notifBody = l10n.notificationsNewMessage;
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    } else {
      // his chat rings under his name, never its id
      notifTitle = isDevChat(senderHaloId) ? l10n.devName : named;
      notifBody = sticker != null
          ? l10n.stickerLabel
          : shownText.isNotEmpty
          ? shownText
          : album != null
          ? l10n.albumLabel(whole(album.n))
          : notifMediaLine(fileName, mediaPath);
      notifPayload = senderHaloId;
      suppress = reading || await db.isMuted(senderHaloId);
    }
    // support rings on its own channel: a waiting chat only as a count, an
    // answered one per message
    if (support.on && !isGroup) {
      if (!suppress) {
        await _ringSupport(
          senderHaloId,
          db,
          support.fresh,
          answered: senderAccepted,
          title: notifTitle,
          body: notifBody,
        );
      }
      return to;
    }
    if (!suppress) {
      // a hidden chat rings only while its vault is open, and what it shows
      // goes from the shade when the vault closes
      if (to == RouteTo.vault) {
        if (!identical(_openVault, db)) return to;
        _vaultShade.add(notifPayload);
      }
      await _io.notify(
        title: notifTitle,
        body: notifBody,
        payload: notifPayload,
        on: db,
        msgUid: env.msgUid,
        burnAt: burnFromArrival,
      );
    }
    return to;
  }

  // his own phone, everyday container only: what the support marker files.
  // a failure leaves the chat where any stranger's goes, in requests
  Future<({bool on, bool fresh})> _supportOf(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    if (!_devIdentity || !identical(db, live)) return (on: false, fresh: false);
    try {
      return await fileSupport(
        db.support,
        sender,
        env,
        accepted: () => db.isAccepted(sender),
      );
    } catch (e) {
      dlog('support: not filed (${e.runtimeType})');
      return (on: false, fresh: false);
    }
  }

  Future<void> _ringSupport(
    String id,
    HaloDb db,
    bool fresh, {
    required bool answered,
    required String title,
    required String body,
  }) async {
    try {
      if (answered) {
        await _bell.chat(
          chatId: id,
          tag: await db.notifTag('$kSupportPayload$id'),
          title: title,
          body: body,
        );
      } else if (!readingIn(kSupportPayload, db.container)) {
        // the inbox on screen says it already. a chat is new with its
        // first message kept, whatever came before it and was not
        final first = fresh || await db.countMessagesFrom(id) == 1;
        await ringSupport(db.support, _bell, chat: id, fresh: first);
      }
    } catch (e) {
      dlog('support: not rung (${e.runtimeType})');
    }
  }

  // each message of a request, until one flags. the switch is the one of
  // the session the message is filed in. a clean check leaves nothing
  Future<void> _runShield(String senderHaloId, String text, HaloDb db) async {
    try {
      if (!await loadScamShieldOn(db.container)) return;
      final had = await db.shieldFor(senderHaloId);
      if (had != null && !shieldRowOpen(had)) return;
      final rows = await db.contacts();
      final r = shieldCheck(
        strangerId: senderHaloId,
        text: text,
        contacts: [
          for (final c in rows)
            ShieldContact(
              c['halo_id'] as String,
              nickname: c['nickname'] as String?,
            ),
        ],
      );
      if (!r.flagged) return;
      await db.setShield(senderHaloId, jsonEncode(r.lead!.toJson()), [
        for (final h in r.hits) h.toJson(),
      ]);
      dlog('shield: flagged ${r.hits.map((h) => h.code).join(',')}');
      notifyListeners();
    } catch (e) {
      dlog('shield: $e');
    }
  }
}
