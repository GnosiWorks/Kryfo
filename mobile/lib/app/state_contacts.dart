// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: contacts: blocks, names, archive, inbox and intros

part of '../main.dart';

extension AppStateContacts on AppState {
  // a contact we accepted vouches for someone. the card becomes a request
  // row with a vouch on it, so their first message skips the stranger gate.
  // trust is ours alone: a card from anyone we have not accepted is dropped
  // unread, and so is one that names us or the sender.
  Future<void> _applyIntro(
    String senderHaloId,
    IntroFrame card,
    HaloDb db, {
    int? at,
  }) async {
    if (!await db.isAccepted(senderHaloId)) return;
    if (!await loadAcceptIntros()) {
      dlog('intro: dropped, introductions are off');
      return;
    }
    final h = card.haloId;
    if (h == myId || h == senderHaloId) return;
    if (!wireIdShaped(h, room: false)) {
      dlog('intro: not an id, dropped');
      return;
    }
    // the developer is his pinned card alone, never someone's say-so
    if (devCardClaim(id: h, xPub: card.xPub, fc: card.fc)) {
      dlog('intro: names the developer, dropped');
      return;
    }
    // a key "this isn't them" blocked comes back on no one's card
    if (await _keyBlockedHere(card.xPub)) {
      dlog('intro: a blocked key, dropped');
      return;
    }
    final everyday = identical(db, live);
    // a card for someone the router keeps is not the everyday side's to
    // file: no row, no vouch, nothing in requests
    if (everyday && _routeOf(h, null) != RouteTo.everyday) {
      dlog('intro: dropped');
      return;
    }
    // a card under words held here on another key is someone else, on an
    // id of their own as a group's list seats them: the one holding the
    // words gets no vouch from it
    final who =
        (await _seats(
          [
            {'h': h, 'x': card.xPub},
          ],
          db,
          room: false,
        ))[h] ??
        h;
    final existing = await db.getContact(who);
    if (existing != null && (existing['accepted'] as int? ?? 0) == 1) return;
    // someone blocked stays blocked: no vouch, no card, nothing sent. a
    // block on the everyday side holds for a hidden chat's card too, or a
    // card for them here would undo it
    if (await db.isBlocked(who) || (!everyday && await live.isBlocked(who))) {
      dlog('intro: names someone blocked, dropped');
      return;
    }
    await db.upsertContactStub(who, card.onion, card.xPub);
    // the note is the introducer's one line about them. it lives on the
    // vouch, so two introducers can each say their piece.
    await db.addVouch(who, senderHaloId, card.note, at: at);
    // someone deleted here is parked out of sight: a friend's card brings
    // them back as a request, as their own message would
    await db.unparkIfArchived(who);
    if (card.avatar != null) await db.setContactAvatar(who, card.avatar);
    // a card's first-contact address is second hand and may be one they
    // have reset since. they take our card too and read the pair address,
    // so that is the way to them (pairRead)
    // a card is keys, not a session. listen for them and swap prekey bundles
    // now, so the first message either side types has a session to ride.
    if (everyday) {
      await subscribePeer(who);
    } else if (card.xPub.isNotEmpty) {
      _xPubToHaloId[card.xPub] = who;
      _io.listen(identOf(who), card.xPub);
    }
    _wantHeal(who);
    unawaited(_sendBundleCtl(who, want: true));
    dlog('intro: $senderHaloId introduced $who');
    await refreshContacts();
  }

  Future<void> deleteConversation(String haloId) async {
    // messages + contact row only. the signal session stays: the peer still
    // holds a live session and their next message is a plain whisper, which
    // back-pair (prekey-only) can't rebuild. keeping the session lets it
    // decrypt, find no contact, and land in requests like a new stranger.
    // words a request, an introduction or a group gave hold nothing once
    // the chat is gone (NameHold.free). any other deleted chat's words go
    // only to an add the person makes, and asks (NameHold.ask)
    await dropChatDraft(haloId);
    final hellos = await hellosKeysOf(haloId);
    // linked devices: their devices get nothing more (read before the row)
    await _devForget(haloId);
    await session.deleteConversation(haloId);
    // their photo and the one set for them go; ours is taken back
    try {
      await session.draftsOf(haloId).dropPhotosOf(haloId);
    } catch (e) {
      dlog('photo: not dropped with the chat (${e.runtimeType})');
    }
    unawaited(photoSweep());
    await _forgetPairSeen({haloId});
    // no hello goes to them after it, and none of theirs waits
    await dropHellos(hellos);
    // keep _xPubToHaloId: the row and subscription both survive so they can
    // still reach us, in requests instead of a live chat.
    await refreshContacts();
    notifyListeners();
  }

  // what a link may do about [id] held here on another key. only the
  // everyday side's people are let go: a hidden chat's name, and anything
  // in the decoy, stays as it is
  Future<NameHold> _nameHold(String id, Map<String, Object?>? row) async =>
      sessionQuiet || _router.keeps(id)
      ? NameHold.kept
      : nameHoldOf(row, seated: await _seated(id), asked: true);

  // in a group or a room here: on the everyday side, or in the open vault
  Future<bool> _seated(String id) async {
    for (final d in [live, ?_openVault]) {
      if (await d.inAnyGroup(id)) return true;
    }
    return false;
  }

  // an everyday name whose chat was deleted, as a first contact finds it:
  // the same whichever session is on screen
  Future<bool> _nameFree(String id, Map<String, Object?>? row) async =>
      !_router.keeps(id) &&
      nameHoldOf(row, seated: await _seated(id)) == NameHold.free;

  // a name a request, an introduction or a group gave, let go so the one
  // the person chose can have it: the chat or request goes as a delete or a
  // decline takes it, and the session, the key and the address it was
  // heard on go with it
  Future<void> releaseName(String id) async {
    final row = await live.getContact(id);
    if (row == null) return;
    final xs = {
      ((row['xpub'] as String?) ?? '').trim().toLowerCase(),
      (await peerXPubOf(id)) ?? '',
    }..remove('');
    if ((row['accepted'] as num?)?.toInt() == 1) {
      await deleteConversation(id);
    } else {
      await live.declineRequest(id);
    }
    // the store of the identity they knew
    final ss = await signalOfIdent(identOf(id));
    await ss.serial<void>(id, () async {
      await ss.sessionStore.delete(id);
      await ss.identityStore.removePeerIdentity(id);
    });
    for (final x in xs) {
      if (_xPubToHaloId[x] == id) _xPubToHaloId.remove(x);
      _io.unlisten(identOf(id), x);
    }
    await forgetPeerFc(id);
    await live.forgetName(id);
    dlog('name: let go for the one chosen');
  }

  // "this isn't them": the safety number they read out is not the one on
  // screen. they go from the container that holds them, all of it, and
  // [keyHex], the key that number was made from, is blocked there. their
  // words go to no one who writes first; only an add the person makes takes
  // them again. false when the key moved meanwhile, or it is the developer,
  // who is his pinned keys alone
  Future<bool> notThem(String haloId, String keyHex) async {
    final key = keyHex.trim().toLowerCase();
    if (isDevId(haloId) || key.isEmpty) return false;
    final s = session;
    final quiet = sessionQuiet;
    final hidden = s.isHidden(haloId);
    if (await s.heldKey(haloId) != key) return false;
    final row = await s.getContact(haloId);
    final xs = {
      ((row?['xpub'] as String?) ?? '').trim().toLowerCase(),
      if (!quiet && signalSession.ready) (await peerXPubOf(haloId)) ?? '',
      key,
    }..remove('');
    // read while their rows still say: where the relay keeps what it held
    // for them, and the tags their notifications went under
    String? relayX;
    var tags = const <String>{};
    if (!quiet) {
      try {
        relayX = await _xPubFor(haloId, (await _reach(haloId))?.xpub);
        tags = await s.notifTagsOf(haloId);
      } catch (e) {
        dlog('not them: not read before (${e.runtimeType})');
      }
    }
    _removing.add(haloId);
    try {
      Future<List<String>?> run() async {
        if (await s.heldKey(haloId) != key) return null;
        // linked devices: their devices get nothing more, and their
        // device sessions go with the phone's
        await _devForget(haloId, sessions: true);
        final went = await s.removeAndBlockKey(haloId, key);
        // the everyday store holds every session, a hidden chat's too
        if (!quiet && signalSession.ready) {
          final ss = await signalOfIdent(identOf(haloId));
          await ss.sessionStore.delete(haloId);
          await ss.identityStore.removePeerIdentity(haloId);
        }
        return went;
      }

      final hellos = await hellosKeysOf(haloId, keys: xs);
      final uids = quiet
          ? await run()
          : await signalSession.serial(haloId, run);
      if (uids == null) return false;
      await dropChatDraft(haloId);
      await dropHellos(hellos);
      if (!quiet) {
        // what the relay held is not fetched again, and the shade lets go
        // of their chat and of what they said in groups
        try {
          if (relayX != null) {
            await _io.letHeld(identOf(haloId), relayX, 'drop');
          }
        } catch (e) {
          dlog('not them: the relay not told (${e.runtimeType})');
        }
        await cancelWithRetry(
          () => _io.unnotifyGone(haloId, tags),
          'not them shade',
        );
        for (final u in uids) {
          await cancelWithRetry(() => _io.unnotifyMessage(u), 'not them');
        }
        for (final x in xs) {
          if (_xPubToHaloId[x] == haloId) _xPubToHaloId.remove(x);
          _io.unlisten(identOf(haloId), x);
        }
        await _forgetPeers({haloId});
        // the router lets them go and keeps the vault's block and words
        // while it is shut, and a hidden group's card loses its seat
        final v = _openVault;
        if (hidden && v != null) {
          await _serial(() async {
            await _router.unlist([haloId]);
            await _router.markKey(key, on: true);
            await _router.markTomb(haloId, on: true);
            try {
              await _attached(v, _recard);
            } catch (e) {
              // the cards are read again as the vault next opens
              dlog('not them: cards not read (${e.runtimeType})');
            }
          });
        }
      }
      await _seatsGoElsewhere(s, haloId, key, hidden: hidden);
      final v = s.vault;
      if (hidden && v != null && identical(_session.vault, v)) {
        try {
          final rebuilt = await Session.withVault(s.primary, v);
          if (identical(_session.vault, v)) _session = rebuilt;
        } catch (e) {
          dlog('not them: session not rebuilt (${e.runtimeType})');
        }
      }
      // what the removal owes a vault's file is done now, off the queue: a
      // vault is never tidied as it shuts
      final owes = s.vault;
      if (hidden && owes != null) unawaited(_tidy(owes));
    } finally {
      _removing.remove(haloId);
    }
    _bumpChatRev(haloId);
    await refreshContacts();
    await refreshGroups();
    dlog('not them: removed, their key blocked');
    return true;
  }

  // their seat in the other container's groups goes too: now when it is
  // open, else as the vault next opens. the everyday side is always open
  Future<void> _seatsGoElsewhere(
    Session s,
    String haloId,
    String keyHex, {
    required bool hidden,
  }) async {
    try {
      if (hidden) {
        await s.primary.dropSeats(haloId, keyHex);
        return;
      }
      final v = s.vault;
      if (v != null) {
        await v.dropSeats(haloId, keyHex);
      } else if (!sessionQuiet && _router.hasVault) {
        await _router.queueSeatGone(haloId, keyHex);
      }
    } catch (e) {
      dlog('not them: seats elsewhere not let go (${e.runtimeType})');
    }
  }

  @visibleForTesting
  Future<void> seatsGoneIntoForTest(HaloDb vault) => _seatsGoneInto(vault);

  @visibleForTesting
  Future<void> remarkForTest(HaloDb vault) => _marksAtOpen(vault);

  // a vault opening: what the everyday side let go and took back while it
  // was shut goes from it first, then its marks are read from its rows
  Future<void> _marksAtOpen(HaloDb vault) async {
    await _seatsGoneInto(vault);
    await _tombsGoneInto(vault);
    await _remarkFrom(vault);
  }

  Future<void> _remarkFrom(HaloDb vault) async {
    try {
      await _router.remark(
        keys: [for (final k in await vault.blockedKeys()) k.x],
        tombs: [for (final t in await vault.tombs()) t.name],
      );
    } catch (e) {
      dlog('vault: marks not read (${e.runtimeType})');
    }
  }

  // what the everyday side let go while the vault was shut, out of it now
  Future<void> _seatsGoneInto(HaloDb vault) async {
    try {
      final gone = await _router.seatsGone();
      for (final (id, key) in gone) {
        await vault.dropSeats(id, key);
      }
      if (gone.isNotEmpty) await _router.clearSeatsGone();
    } catch (e) {
      dlog('vault: seats not let go (${e.runtimeType})');
    }
  }

  @visibleForTesting
  Future<void> tidyForTest(HaloDb d, {int? now}) => _tidy(d, now: now);

  Future<void> _tidy(HaloDb d, {int? now}) async {
    if (haloWiping) return;
    final k = d.container.dbFile;
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final was = _tidyWait[k];
    if (was != null && at < was.at + was.wait) return;
    try {
      await tidyIfOwed(await d.open());
      _tidyWait.remove(k);
    } catch (e) {
      final wait = was == null
          ? const Duration(minutes: 10).inMilliseconds
          : min(was.wait * 2, const Duration(days: 1).inMilliseconds);
      _tidyWait[k] = (at: at, wait: wait);
      dlog('tidy: not done (${e.runtimeType})');
    }
  }

  // a key "this isn't them" blocked, in any container open here
  Future<List<({String x, int at})>> blockedKeys() => session.blockedKeys();

  Future<void> unblockKey(String keyHex) async {
    await session.unblockKey(keyHex);
    if (!sessionQuiet && _openVault != null) {
      await _router.markKey(keyHex, on: false);
    }
    notifyListeners();
  }

  // an arrival's key blocked on the everyday side or in the vault, open or
  // shut (its marks on the router)
  Future<bool> _keyBlockedHere(String keyHex) async {
    if (keyHex.trim().isEmpty) return false;
    if (_router.keyBlocked(keyHex)) return true;
    for (final d in [live, ?_openVault]) {
      if (await d.keyBlocked(keyHex)) return true;
    }
    return false;
  }

  // words "this isn't them" let go, for an add the person makes: what the
  // session on screen holds. a shut vault's marks are never shown to it
  Future<bool> _tombed(String id) async => sessionQuiet
      ? _tombedIn([session.primary, ?session.vault], id)
      : _openVault != null
      ? _router.tombedLive(id) || await _tombedIn([live, ?_openVault], id)
      : _tombedIn([live], id);

  // an everyday add took words the shut vault let go: its mark comes off,
  // and the vault's own tomb as it next opens
  Future<void> _untombShut(String id) async {
    if (sessionQuiet || _openVault != null || !_router.tombedLive(id)) return;
    await _router.markTomb(id, on: false);
    await _router.queueTombGone(id);
  }

  // what the everyday side took back while the vault was shut
  Future<void> _tombsGoneInto(HaloDb vault) async {
    try {
      final ids = await _router.tombsGone();
      for (final id in ids) {
        await vault.clearTomb(id);
      }
      if (ids.isNotEmpty) await _router.clearTombsGone();
    } catch (e) {
      dlog('vault: let-go words not taken back (${e.runtimeType})');
    }
  }

  // the same for what arrives: it is filed on the everyday side or in its
  // vault, open or shut, whatever is on screen
  Future<bool> _tombedArriving(String id) async =>
      _router.tombed(id) || await _tombedIn([live, ?_openVault], id);

  static Future<bool> _tombedIn(List<HaloDb> dbs, String id) async {
    for (final d in dbs) {
      if (await d.tombed(id)) return true;
    }
    return false;
  }

  // an add the person made takes the words back wherever they were let go
  Future<void> _untomb(String id) async {
    if (sessionQuiet) {
      for (final d in [session.primary, ?session.vault]) {
        await d.clearTomb(id);
      }
      return;
    }
    for (final d in [live, ?_openVault]) {
      await d.clearTomb(id);
    }
    // a shut vault's own tomb goes as it next opens, its mark now
    if (_openVault == null) {
      await _untombShut(id);
    } else if (_router.tombedLive(id)) {
      await _router.markTomb(id, on: false);
    }
  }

  Future<void> archive(String haloId) async {
    await session.setArchived(haloId, true);
    await refreshContacts();
  }

  Future<void> unarchive(String haloId) async {
    await session.setArchived(haloId, false);
    await refreshContacts();
  }

  Future<void> mute(String haloId) async {
    await session.setMuted(haloId, true);
    await refreshContacts();
  }

  Future<void> unmute(String haloId) async {
    await session.setMuted(haloId, false);
    await refreshContacts();
  }

  // a link any app or page can send: once the lock is open, the person is
  // asked before it adds or joins anything (takeOutsideLink). of those that
  // came under the lock only the latest is asked about
  Future<void> _outsideLink(Uri uri, String how) =>
      lockGuard.afterUnlock(key: 'link:$uri', slot: 'outside-link', () async {
        await _signalReady.future;
        var ctx = rootNavKey.currentContext;
        for (var i = 0; i < 50 && ctx == null; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          ctx = rootNavKey.currentContext;
        }
        if (ctx == null || !ctx.mounted) {
          dlog('$how: no screen to ask on, dropped');
          return;
        }
        final result = await takeOutsideLink(
          ctx,
          uri.toString(),
          selfId: sessionId,
        );
        dlog('$how: ${result ?? 'not taken'}');
        if (result == null) return;
        _sayLinkResult(result);
        await refreshContacts();
        notifyListeners();
      });

  // a block keeps listening on their relay address: what they send while
  // it holds comes in and is dropped, or the relay would keep it and hand
  // it over after an unblock. what of theirs is in the shade goes, in the
  // session that showed it: a decoy shows nothing, and the same words there
  // may name someone the everyday app has in the shade
  Future<void> block(String haloId) async {
    await session.setBlocked(haloId, true);
    await dropHellos(await hellosKeysOf(haloId));
    // what was typed for them stays, under the blocked bar, for an unblock
    await _recardBlock(haloId);
    // an open chat reads its rows again: what waited is not sent now
    _bumpChatRev(haloId);
    await session.dropHeld(haloId);
    await _relayLeft(haloId, 'drop');
    if (!sessionQuiet) {
      await cancelWithRetry(() => _io.unnotify(haloId), 'block shade');
    }
    await refreshContacts();
    // our photo is taken back from them
    unawaited(photoSweep());
  }

  // a support chat is taken on by its first reply, and stays in support.
  // true when this reply accepted it
  Future<bool> answerSupport(String haloId) async {
    if (!devMode ||
        await session.isAccepted(haloId) ||
        !await session.support.has(haloId)) {
      return false;
    }
    await session.acceptRequest(haloId);
    await afterAccept(haloId);
    return true;
  }

  // a contact whose chat sits in the inbox: added by link, he is asked
  // where the chat goes
  Future<bool> inboxChatOf(String haloId) async =>
      devMode && await session.support.has(haloId);

  // a contact's chat in Chats that came through the developer chat, by a
  // tagged message or a filing before. never by name or words
  Future<bool> movableToInbox(String haloId) async {
    if (!devMode || isDevChat(haloId) || session.isHidden(haloId)) {
      return false;
    }
    final s = session.primary;
    if (await s.support.has(haloId) || !await s.isAccepted(haloId)) {
      return false;
    }
    return await s.hasViaDev(haloId) || await s.support.wasFiled(haloId);
  }

  // filed as an answered inbox chat: it leaves Chats
  Future<void> moveToInbox(String haloId) async {
    if (!await movableToInbox(haloId)) return;
    await session.support.file(haloId);
    // what rang for it as a chat would open it as one
    unawaited(clearNotificationsFor(haloId));
    await refreshContacts();
  }

  // the inbox chat shows in Chats instead. only someone accepted has a
  // place there
  Future<void> moveToChats(String haloId) async {
    if (!devMode || !await session.isAccepted(haloId)) return;
    await session.support.moveOut(haloId);
    // what rang for it in the inbox would open nothing now
    unawaited(clearNotificationsFor('$kSupportPayload$haloId'));
    await refreshContacts();
  }

  // the support inbox is on screen: its summary has nothing left to say
  Future<void> supportSeen() => _bell.clear();

  // what every accept does, from the chat or the requests list: listen for
  // them, tell them they are in, and open what the onion lane held back
  Future<void> afterAccept(String haloId) async {
    // a quiet session has no one waiting and answers no one. what it owes
    // stays on its row, as what is typed in it stays queued
    if (sessionQuiet) {
      await _oweAck(haloId);
      await refreshContacts();
      return;
    }
    // a hello waiting here: its session first, so the ack is its opener
    try {
      await answerHello(haloId);
    } catch (e) {
      dlog('hello: not answered (${e.runtimeType})');
    }
    unawaited(subscribePeer(haloId, fresh: true));
    unawaited(_ackOnAccept(haloId));
    final s = session;
    // let go of on the relay's side before the shelf goes: a death in
    // between would leave what waits there for two weeks
    await _relayLeft(haloId, 'mark');
    await _letHeldIn(
      haloId,
      () => s.heldOf(haloId),
      (id) => s.forgetHeld(haloId, id),
    );
    // what came past the shelf waited on the relay, and comes after it
    await _relayLeft(haloId, 'free');
    _bumpChatRev(haloId);
    await refreshContacts();
    notifyListeners();
    unawaited(photoSweep());
  }

  // what a full shelf left on the relay for them: let go of for the next
  // start ("mark"), fetched again now ("free"), or taken as kept ("drop").
  // a quiet session asks nothing of the engine
  Future<void> _relayLeft(String haloId, String how) async {
    if (sessionQuiet) return;
    try {
      final x = await _xPubFor(haloId, (await _reach(haloId))?.xpub);
      if (x != null) await _io.letHeld(identOf(haloId), x, how);
    } catch (e) {
      dlog('held: the relay not told (${e.runtimeType})');
    }
  }

  // the key someone is heard on: the row's, else signal's, as _listenKnown
  // takes it
  Future<String?> _xPubFor(String haloId, String? row) async {
    if (row != null && row.isNotEmpty) return row;
    if (!signalSession.ready) return null;
    final x = await peerXPubOf(haloId);
    return x == null || x.isEmpty ? null : x;
  }

  // on a start or an unlock: what the relay still holds back for someone
  // accepted since, an accept that died before its fetch, is asked for on
  // their runner's next connection or probe. one call, marks on the
  // addresses that hold something and nothing else: nothing reconnects
  Future<void> _markHeldOf(HaloDb db) async {
    if (sessionQuiet) return;
    final xs = <(int, String)>{};
    for (final r in await db.contacts()) {
      if (r['accepted'] != 1) continue;
      final id = r['halo_id'] as String;
      final x = await _xPubFor(id, r['xpub'] as String?);
      if (x != null) xs.add((identOf(id), x));
    }
    if (xs.isNotEmpty) await _io.markHeld(xs.toList());
  }

  // the everyday side's marks, before its runners start and read them
  @visibleForTesting
  Future<void> markHeldAtStart() async {
    try {
      await _markHeldOf(live);
    } catch (e) {
      dlog('held: not marked (${e.runtimeType})');
    }
  }

  // what the shelf holds for someone accepted, oldest first. a row goes
  // only once it is in, so one that fails stays for the next run
  Future<void> _letHeldIn(
    String haloId,
    Future<List<({int id, String cipher, int at})>> Function() rows,
    Future<void> Function(int id) forget, {
    bool Function()? still,
  }) {
    final before = _lettingIn[haloId];
    final run = () async {
      if (before != null) {
        try {
          await before;
        } catch (_) {
          // its own caller hears of it
        }
      }
      for (final held in await rows()) {
        if (still != null && !still()) return;
        try {
          final cipher = held.cipher;
          final wire = heldWireOf(cipher);
          final plain = wire ?? await _io.decrypt(haloId, cipher);
          if (plain != null) {
            // judged as it came: a block drops the shelf, so it came
            // after any that ended
            await _applyIncomingPayload(
              haloId,
              unwrapMessage(plain),
              wire: plain,
              reached: (from: held.at, until: held.at),
            );
            // one kept as it came: its relay copy is the same cipher
            if (wire == null) {
              await live.markSeen(
                sha256.convert(utf8.encode(cipher)).toString(),
              );
            }
          }
          await forget(held.id);
        } catch (e) {
          dlog('held: could not open one for $haloId ($e)');
        }
      }
    }();
    _lettingIn[haloId] = run;
    return run.whenComplete(() {
      if (identical(_lettingIn[haloId], run)) _lettingIn.remove(haloId);
    });
  }

  // what the shelf still holds for people accepted already, once a start
  // or an unlock: an accept that failed part way or died before it was
  // through has no other way in. only the everyday container and its open
  // vault take anything in, each from its own rows
  @visibleForTesting
  Future<void> letHeldIn(HaloDb db) async {
    bool still() =>
        !haloWiping && (identical(db, live) || identical(db, _openVault));
    if (!still()) return;
    final vault = !identical(db, live);
    var any = false;
    try {
      for (final id in await db.heldOfAccepted()) {
        if (!still()) break;
        // the vault's rows go where its chats go, never the everyday side
        final to = _routeOf(id, null);
        if (vault && to != RouteTo.vault && to != RouteTo.sealed) continue;
        any = true;
        // what waits on the relay is asked for on their runner's next
        // connection or probe: a start or an unlock makes nothing reconnect
        await _relayLeft(id, 'mark');
        await _letHeldIn(id, () => db.heldOf(id), db.forgetHeld, still: still);
        _bumpChatRev(id);
      }
      if (any) await refreshContacts();
      // the everyday side's are marked before its runners start
      if (vault && still()) await _markHeldOf(db);
    } catch (e) {
      dlog('held: left for the next time ($e)');
    }
    if (any) notifyListeners();
  }

  // an unblock listens for them, if nothing did yet
  Future<void> unblock(String haloId) async {
    await session.setBlocked(haloId, false);
    // the card says so before the vault can shut: one still saying blocked
    // would turn them away, and note what they send as sent while it held
    await _recardBlock(haloId);
    if (!sessionQuiet) await subscribePeer(haloId);
    await refreshContacts();
    unawaited(photoSweep());
  }

  // everyone blocked, contacts or not: a request, a group member or a
  // support chat blocked before it was ever accepted is here too, or the
  // block could never be undone
  Future<List<({String haloId, String? nickname})>> blockedContacts() async {
    final s = session;
    final ids = await s.blockedIds();
    final out = <({String haloId, String? nickname})>[];
    for (final r in await s.contacts()) {
      final id = r['halo_id'] as String;
      if (ids.remove(id)) {
        out.add((haloId: id, nickname: r['nickname'] as String?));
      }
    }
    for (final id in ids.toList()..sort()) {
      final r = await s.getContact(id);
      out.add((haloId: id, nickname: r?['nickname'] as String?));
    }
    return out;
  }

  bool hiddenWhileShut(String id) =>
      _openVault == null && _router.cardOf(id) != null;

  // how to reach someone: their everyday row, the open vault's, else the
  // card the router keeps for a hidden chat while the vault is shut
  Future<_Reach?> _reach(String id) async {
    for (final d in [live, ?_openVault]) {
      final c = await d.getContact(id);
      if (c == null) continue;
      return (
        onion: (c['onion'] as String?) ?? '',
        xpub: (c['xpub'] as String?) ?? '',
        bundle: c['peer_bundle'] as String?,
        backPaired: await d.isBackPaired(id),
        on: d,
      );
    }
    final card = _router.cardOf(id);
    if (card == null) return null;
    return (
      onion: card.onion,
      xpub: card.xpub,
      bundle: null,
      backPaired: card.backPaired,
      on: null,
    );
  }

  /// [id] is blocked in a container open now, or on the card a shut vault
  /// keeps: nothing goes to them one to one. a read that fails says
  /// blocked, and the next try reads again
  Future<bool> blockedAnywhere(String id) async {
    for (final d in [live, ?_openVault]) {
      try {
        if (await d.isBlocked(id)) return true;
      } catch (e) {
        dlog('block: not read (${e.runtimeType})');
        return true;
      }
    }
    return _router.blocks(id);
  }

  // one contact's card, ready to hand to another. the row is the source:
  // v2 pairings keep the xpub in the signal store, so fall back to that.
  Future<IntroFrame?> _introCardFor(String haloId, String note) async {
    // the dev chat is never handed on
    if (isDevId(haloId)) return null;
    // nor a key this phone has not taken yet
    if (await keyHeld(haloId)) return null;
    // a hidden chat's row is in the open vault
    final c = await _ownerOf(haloId).getContact(haloId);
    if (c == null || (c['accepted'] as int? ?? 0) != 1) return null;
    var x = (c['xpub'] as String?) ?? '';
    if (x.isEmpty) x = await peerXPubOf(haloId) ?? '';
    if (x.isEmpty) return null;
    return IntroFrame(
      haloId: haloId,
      onion: (c['onion'] as String?) ?? '',
      xPub: x,
      avatar: (c['avatar'] as num?)?.toInt(),
      fc: await _ownerOf(haloId).isBackPaired(haloId)
          ? null
          : peerFcFor(haloId),
      note: note.isEmpty ? null : note,
    );
  }

  // introduce two accepted contacts to each other. each gets the other's
  // card over the session we already hold with them. returns whether each
  // side took it; the caller owns the budget and the wording.
  Future<({bool toFirst, bool toSecond})> introduce(
    String first,
    String second, {
    String note = '',
  }) async {
    // a quiet session sends nothing, and knows no one to introduce. nor is
    // anyone blocked introduced, or introduced to
    if (sessionQuiet ||
        await blockedAnywhere(first) ||
        await blockedAnywhere(second)) {
      return (toFirst: false, toSecond: false);
    }
    final n = note.trim();
    final cardOfFirst = await _introCardFor(first, n);
    final cardOfSecond = await _introCardFor(second, n);
    if (cardOfFirst == null || cardOfSecond == null) {
      return (toFirst: false, toSecond: false);
    }
    Future<bool> send(String to, IntroFrame card) async {
      try {
        final wrapped = await wrapMessage('', intro: card, sender: _mySender());
        return await _sendOneEnvelope(to, wrapped);
      } catch (e) {
        dlog('intro to $to failed: $e');
        return false;
      }
    }

    final r = await Future.wait([
      send(first, cardOfSecond),
      send(second, cardOfFirst),
    ]);
    dlog('intro: $first<->$second first=${r[0]} second=${r[1]}');
    return (toFirst: r[0], toSecond: r[1]);
  }
}
