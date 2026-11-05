// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: burner rooms

part of '../main.dart';

extension AppStateRooms on AppState {
  // what a group row says about being a room, or null for a plain group
  Future<({String priv, String pub, int expiresAt})?> _roomOf(
    String groupId, [
    HaloDb? on,
  ]) async {
    final g = await (on ?? live).getGroup(groupId);
    final priv = g?['room_priv'] as String?;
    final pub = g?['room_pub'] as String?;
    if (priv == null || pub == null) return null;
    return (priv: priv, pub: pub, expiresAt: (g!['expires_at'] as int?) ?? 0);
  }

  // the one door every group frame leaves through. a plain group goes to
  // the member's signal session. a room frame is rewritten so the only
  // identity on it is the room key (no kryfo id, onion, push endpoint or
  // badge) and sealed with the room key to the member's room key.
  Future<bool> _sendGroupEnvelope(
    String groupId,
    String memberId,
    String wrapped,
  ) async {
    if (everydayHeld) return false;
    final room = await _roomOf(groupId);
    if (room == null) {
      // linked devices: a member a linked device cannot reach is my phone's
      // to send to; one copy of mine per frame goes to my other devices
      if (linkedDevicesOn && linkedRole) {
        final r = await _sendFromDevice(memberId, wrapped);
        _ownGroupCopy(
          groupId,
          memberId,
          wrapped,
          reached: r != _DeviceSend.cannot,
        );
        return r != _DeviceSend.failed;
      }
      final ok = await _sendOneEnvelope(memberId, wrapped, member: true);
      if (ok) _ownGroupCopy(groupId, memberId, wrapped, reached: true);
      return ok;
    }
    if (memberId == room.pub) return false;
    if (room.expiresAt <= DateTime.now().millisecondsSinceEpoch) return false;
    int? number;
    try {
      number = await _roomFrameNumber(groupId, wrapped);
    } catch (e) {
      // unnumbered, it keeps the place it arrives in, as before
      dlog('room frame number: $e');
    }
    final stripped = roomFrame(wrapped, room.pub, number: number);
    if (stripped == null) return false;
    final r = await engine.roomSend(room.priv, memberId, stripped);
    if (r != 'ok') dlog('room send: $r');
    return r == 'ok';
  }

  Future<int> _roomFrameNumber(String groupId, String wrapped) {
    final k = '$groupId ${sha256.convert(utf8.encode(wrapped))}';
    final have = _roomNumbers.remove(k);
    final n = have ?? live.nextRoomSeq(groupId);
    _roomNumbers[k] = n;
    while (_roomNumbers.length > 256) {
      _roomNumbers.remove(_roomNumbers.keys.first);
    }
    return n;
  }

  Future<String> createRoom(
    String name, {
    required Duration expiry,
    int? cap,
  }) async {
    final k = engine.roomKeygen();
    if (k == null) throw StateError('could not make a room key');
    final fc = engine.roomFcPk(k.priv);
    if (fc.startsWith('error')) throw StateError(fc);
    final groupId = newMsgUid();
    await session.createRoom(
      groupId: groupId,
      name: name.trim().isEmpty ? l10n.homeRoom : name.trim(),
      priv: k.priv,
      pub: k.pub,
      expiresAt: DateTime.now().add(expiry).millisecondsSinceEpoch,
      creatorPub: k.pub,
      fcPk: fc,
      cap: cap,
      members: [k.pub],
    );
    // a quiet session keeps the room on this phone: nobody is listened for
    if (!sessionQuiet) {
      engine.roomSubscribeFcBg(k.priv);
      _roomSubs[k.pub] = {};
    }
    _armRoomTimer();
    await refreshGroups();
    return groupId;
  }

  Future<RoomLink?> roomLinkFor(String groupId) async {
    final g = await session.getGroup(groupId);
    if (g == null || g['room_pub'] == null) return null;
    return RoomLink(
      roomId: groupId,
      name: g['name'] as String,
      expiresAt: g['expires_at'] as int,
      creatorPub: g['creator_pub'] as String,
      fcPk: g['fc_pk'] as String,
      cap: g['member_cap'] as int?,
    );
  }

  Future<T> _roomTurn<T>(String groupId, Future<T> Function() run) =>
      _inLine(_roomTurns, groupId, run);

  Future<T> _roomTake<T>(String groupId, Future<T> Function() run) =>
      _inLine(_roomTakes, groupId, run);

  static Future<T> _inLine<T>(
    Map<String, Future<void>> line,
    String groupId,
    Future<T> Function() run,
  ) {
    final mine = (line[groupId] ?? Future<void>.value()).then((_) => run());
    final done = mine.then<void>((_) {}, onError: (_) {});
    line[groupId] = done;
    done.then((_) {
      if (identical(line[groupId], done)) line.remove(groupId);
    });
    return mine;
  }

  // whether the room a frame names has a knock or a reset under way
  bool _roomBusy(String content) {
    final g = unwrapMessage(content).groupId;
    return g != null && _roomTurns.containsKey(g);
  }

  void _knockLater(String tag, String content, String h, Reached? reached) {
    if (!_knocks.add(h)) return;
    unawaited(
      _handleRoomFrame(tag, content, reached: reached)
          .then((_) => live.markSeen(h))
          .then((_) => notifyListeners())
          .catchError((Object e) => dlog('room knock: ${e.runtimeType}'))
          .whenComplete(() => _knocks.remove(h)),
    );
  }

  /// a new link for a room this phone made. the old one knocks on a key
  /// nobody listens to any more, so it lets no one in, and a knock on it
  /// goes unanswered as one on a phone that is off. the members stay, and
  /// the roster queued with it gives them the new link. null when it
  /// cannot be done
  Future<RoomLink?> resetRoomLink(String groupId) {
    final running = _resetting[groupId];
    if (running != null) return running;
    final r = _roomTurn(groupId, () => _resetRoomLink(groupId));
    _resetting[groupId] = r;
    return r.whenComplete(() => _resetting.remove(groupId));
  }

  Future<RoomLink?> _resetRoomLink(String groupId) async {
    final g = await session.getGroup(groupId);
    final priv = g?['room_priv'] as String?;
    final pub = g?['room_pub'] as String?;
    if (g == null || priv == null || pub == null) return null;
    if ((g['is_admin'] as int? ?? 0) != 1) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((g['expires_at'] as int? ?? 0) <= now) return null;
    // a quiet session keeps the room on this phone: nothing listens or goes
    final quiet = sessionQuiet;
    // a door the last reset could not forget goes first, or it never would
    if (!quiet && !await _forgetDoor(groupId, g['door_was'] as String?)) {
      return null;
    }
    final k = engine.roomKeygen();
    if (k == null) return null;
    final fc = engine.roomFcPk(k.priv);
    if (!looksLikeRoomKey(fc)) return null;
    final was = (
      priv: (g['door_priv'] as String?) ?? priv,
      pub: (g['door_pub'] as String?) ?? pub,
    );
    // from here a knock on the old door finds no room, and the roster that
    // takes the new link to the members waits in the queue
    final reset = await session.resetRoomDoor(
      groupId,
      priv: k.priv,
      pub: k.pub,
      fcPk: fc,
      was: quiet ? null : was.priv,
      roster: !quiet,
      now: now,
    );
    // gone under it, as an ended room does: no lane is touched
    if (!reset) return null;
    if (!quiet) {
      await _moveRoomDoor(groupId, pub, was, k.priv);
      await _forgetDoor(groupId, was.priv);
      // after the move: the first door's lane is the members' too
      if (!haloWiping) unawaited(_drainGroupCtl());
    }
    _bumpChatRev('group:$groupId');
    await refreshGroups();
    return roomLinkFor(groupId);
  }

  // the files of a door a reset left, gone, and the note of it with them.
  // one not gone stays noted, for the next start or reset
  // true once nothing is left to forget
  Future<bool> _forgetDoor(String groupId, String? priv) async {
    if (priv == null) return true;
    try {
      final r = await engine
          .roomForget(priv, const [])
          .timeout(roomEngineWait, onTimeout: () => 'error: timeout');
      if (r != 'ok') return false;
      await live.clearRoomDoorWas(groupId, priv);
      return true;
    } catch (e) {
      dlog('room door: not forgotten (${e.runtimeType})');
      return false;
    }
  }

  // the old door stops listening, the new one listens.
  // the first door is the room's own key, whose lane its members share:
  // they listen again once it is shut
  Future<void> _moveRoomDoor(
    String groupId,
    String roomPub,
    ({String priv, String pub}) was,
    String doorPriv,
  ) async {
    if (was.pub == roomPub) {
      try {
        await engine
            .roomUnsubscribe(roomPub)
            .timeout(roomEngineWait, onTimeout: () => 'error: timeout');
      } catch (e) {
        dlog('room door: not shut (${e.runtimeType})');
      }
      _roomSubs[roomPub] = {};
      await _subscribeRoomMembers(groupId);
    } else {
      engine.roomUnsubscribeBg(was.pub);
    }
    engine.roomSubscribeFcBg(doorPriv);
  }

  // join off a link: make a key for this room only, tell the creator's drop
  // box about it, and listen for the creator. the room waits until the
  // creator's roster names the key, since nobody reads a key before that.
  // the waiting room opening is the answer, so there is nothing to say
  Future<String> joinRoom(RoomLink link) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (link.expiresAt <= now) return l10n.appThisRoomHasAlready;
    // the same link twice at once: the first one is opening the room
    if (!_joiningRooms.add(link.roomId)) return '';
    try {
      return await _joinRoom(link, now);
    } finally {
      _joiningRooms.remove(link.roomId);
    }
  }

  /// whether [link] may move a waiting join here to the door it names: the
  /// same room from the same maker, its own door gone unanswered or full.
  /// even then only on the join sheet
  Future<bool> roomDoorMovable(RoomLink link) async {
    final g = await session.getGroup(link.roomId);
    return g != null && _doorMovable(g, link);
  }

  bool _doorMovable(Map<String, Object?> g, RoomLink link) {
    if (g['room_pub'] == null || g['joining_at'] == null) return false;
    if (g['creator_pub'] != link.creatorPub || g['fc_pk'] == link.fcPk) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return roomJoinState(g['joining_at'] as int?, now) == RoomJoin.silent ||
        roomFull(link.roomId);
  }

  Future<String> _joinRoom(RoomLink link, int now) async {
    final had = await session.getGroup(link.roomId);
    if (had != null) {
      // not let in yet: the link knocks again
      if (had['room_pub'] != null && had['joining_at'] != null) {
        final yes = takenDoors.taken(link);
        if (had['fc_pk'] != link.fcPk) {
          // anyone can write a link with another door in it: one is taken
          // only once this one went unanswered or said full, and only on
          // the sheet's join. else the room opens and nothing is sent
          if (!yes || !_doorMovable(had, link)) return '';
          await session.setRoomFc(link.roomId, link.fcPk);
        }
        await retryRoomJoin(link.roomId);
        return '';
      }
      return l10n.appYouAreAlreadyIn;
    }
    final k = engine.roomKeygen();
    if (k == null) return l10n.appCouldNotMakeA;
    _roomsFull.remove(
      AppState._fullKey(session.primary.container, link.roomId),
    );
    await session.createRoom(
      groupId: link.roomId,
      name: link.name,
      priv: k.priv,
      pub: k.pub,
      expiresAt: link.expiresAt,
      creatorPub: link.creatorPub,
      fcPk: link.fcPk,
      cap: link.cap,
      members: [link.creatorPub, k.pub],
      joiningAt: now,
    );
    _armRoomTimer();
    // a quiet session keeps the room on this phone: the hello never leaves
    if (!sessionQuiet) {
      _roomSubs[k.pub] = {};
      await _subscribeRoomMembers(link.roomId);
      // the room opens at once and waits; the relays take their time
      unawaited(_knockRoom(link.roomId, now));
    }
    await refreshGroups();
    return '';
  }

  // the join, in the background. one that did not go leaves the room not
  // answering at once, so try again is there without the wait
  Future<void> _knockRoom(String groupId, int at) async {
    var sent = false;
    try {
      sent = await _sendRoomJoin(groupId);
    } catch (e) {
      dlog('room join not sent: ${e.runtimeType}');
    }
    if (sent) return;
    try {
      if (!await live.failRoomJoining(groupId, at)) return;
      _bumpChatRev('group:$groupId');
      await refreshGroups();
    } catch (e) {
      dlog('room join not marked: ${e.runtimeType}');
    }
  }

  // the join, to the creator's drop box, the same way every time
  Future<bool> _sendRoomJoin(String groupId) async {
    final g = await live.getGroup(groupId);
    final priv = g?['room_priv'] as String?;
    final pub = g?['room_pub'] as String?;
    final creator = g?['creator_pub'] as String?;
    final fc = g?['fc_pk'] as String?;
    if (priv == null || pub == null || creator == null || fc == null) {
      return false;
    }
    // numbered like every room frame: a knock again is not the same bytes
    // as the last, which the creator would drop as one it already saw
    int? number;
    try {
      number = await live.nextRoomSeq(groupId);
    } catch (e) {
      dlog('room join number: $e');
    }
    final wrapped = roomFrame(
      await wrapMessage(
        '',
        groupId: groupId,
        groupControl: const GroupControl(type: 'join'),
        sender: _mySender(),
      ),
      pub,
      number: number,
    );
    if (wrapped == null) return false;
    // left while it was made: a join now would give the creator a seat for
    // a key nobody holds any more
    if (_leavingRooms.contains(groupId) || !await live.groupExists(groupId)) {
      dlog('room join: the room went, not sent');
      return false;
    }
    final r = await engine.roomSendFirstContact(priv, creator, fc, wrapped);
    dlog('room join: $r');
    return r == 'ok';
  }

  /// a room not let in yet knocks again, as the first time, and its wait
  /// starts over. the join goes in the background
  Future<void> retryRoomJoin(String groupId) async {
    final g = await session.getGroup(groupId);
    if (g == null || g['room_pub'] == null || g['joining_at'] == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((g['expires_at'] as int? ?? 0) <= now) return;
    // let in since the read above: it stays let in, and nothing is sent
    if (!await session.restartRoomJoining(groupId, now)) return;
    _roomsFull.remove(AppState._fullKey(session.primary.container, groupId));
    _bumpChatRev('group:$groupId');
    await refreshGroups();
    if (sessionQuiet) return;
    await _subscribeRoomMembers(groupId);
    unawaited(_knockRoom(groupId, now));
  }

  // the creator's roster names this phone's key: the room is joined. one
  // without it lets no one in
  Future<void> _roomLetIn(
    String groupId,
    List<String> roster,
    HaloDb db,
  ) async {
    // on its way out: no "joined" for a room just left
    if (_leavingRooms.contains(groupId)) return;
    final g = await db.getGroup(groupId);
    if (g == null || g['joining_at'] == null) return;
    final pub = g['room_pub'] as String?;
    if (pub == null || !roster.contains(pub)) return;
    await db.setRoomJoining(groupId, null);
    _roomsFull.remove(AppState._fullKey(db.container, groupId));
    _bumpChatRev('group:$groupId');
    await refreshGroups();
    if (identical(db, session.primary)) {
      sayRoomJoined(l10n.appJoined(g['name'] as String));
    }
  }

  // open a subscription for every member key we do not listen to yet
  Future<void> _subscribeRoomMembers(String groupId) async {
    final room = await _roomOf(groupId);
    if (room == null) return;
    final have = _roomSubs.putIfAbsent(room.pub, () => {});
    final fresh = [
      for (final m in await live.getGroupMembers(groupId))
        if (m != room.pub && !have.contains(m)) m,
    ];
    if (fresh.isEmpty) return;
    // noted first: the room's end forgets every address it listened on
    if (!await live.noteRoomKeys(groupId, fresh)) return;
    // ended or listened to anew meanwhile
    if (!identical(_roomSubs[room.pub], have)) return;
    for (final m in fresh) {
      if (!have.add(m)) continue;
      engine.roomSubscribeBg(room.priv, m);
    }
  }

  // a join turned away for want of space hears so, and only that: no
  // number, so the frames this room sent stay uncounted. a phone from
  // before the word waits on as it did
  Future<void> _sayRoomFull(String groupId, String who) async {
    // nothing of the everyday account leaves while a decoy is open
    if (haloWiping || everydayHeld) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final said = (_fullSaid[groupId] ?? const <int>[])
        .where((at) => now - at < 60000)
        .toList();
    if (said.length >= 10) return;
    final k = '$groupId $who';
    final at = _toldFull[k];
    if (at != null && now - at < 5000) return;
    _fullSaid[groupId] = [...said, now];
    _toldFull.remove(k);
    _toldFull[k] = now;
    while (_toldFull.length > 256) {
      _toldFull.remove(_toldFull.keys.first);
    }
    while (_fullSaid.length > 64) {
      _fullSaid.remove(_fullSaid.keys.first);
    }
    try {
      final room = await _roomOf(groupId);
      if (room == null || room.expiresAt <= now || who == room.pub) return;
      final frame = roomFrame(
        await wrapMessage(
          '',
          groupId: groupId,
          groupControl: const GroupControl(type: 'full'),
          sender: _mySender(),
        ),
        room.pub,
      );
      if (frame == null) return;
      final r = await engine.roomSend(room.priv, who, frame);
      if (r != 'ok') dlog('room full: $r');
    } catch (e) {
      dlog('room full: not said (${e.runtimeType})');
    }
  }

  bool roomFull(String groupId) => _roomsFull.contains(
    AppState._fullKey(session.primary.container, groupId),
  );

  // someone came in off the link. only the creator takes these, only for a
  // live room, only under the cap. then everyone gets the new roster and
  // subscribes to the newcomer off it.
  // [door] is the key the knock came to. a reset takes its turn before or
  // after, never in between
  Future<void> _roomJoin(String roomPub, String door, UnwrappedMessage env) {
    final groupId = env.groupId;
    if (groupId == null) return Future.value();
    return _roomTurn(groupId, () => _roomJoinTurn(roomPub, door, env));
  }

  Future<void> _roomJoinTurn(
    String roomPub,
    String door,
    UnwrappedMessage env,
  ) async {
    final g = await live.roomByPub(roomPub);
    if (g == null || env.groupId != g['group_id']) return;
    if ((g['is_admin'] as int? ?? 0) != 1) return;
    if ((g['expires_at'] as int) <= DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    final who = env.senderHaloId;
    if (who == null || !looksLikeRoomKey(who) || who == roomPub) return;
    // a room key that is a pinned key is no one's to join with
    if (devIdClaim(who)) return;
    final groupId = g['group_id'] as String;
    // a key that left or was taken out stays out: its join can come in
    // after its leave, off a lane of its own
    if ((await live.rosterGone(groupId)).contains(who)) return;
    final members = await live.getGroupMembers(groupId);
    // the door it came to is still the room's: a reset shut it meanwhile
    if ((await live.roomByDoor(door))?['group_id'] != groupId) return;
    // no room is bigger than a group: a longer roster is one no member
    // would take
    final cap = min(
      (g['member_cap'] as int?) ?? AppState.kGroupMemberCap,
      AppState.kGroupMemberCap,
    );
    if (!members.contains(who)) {
      if (members.length >= cap) {
        dlog('room: full, said so');
        // in the background: the inbox this runs in waits for no relay
        unawaited(_sayRoomFull(groupId, who));
        return;
      }
      await live.addGroupMember(groupId, who);
    }
    await _subscribeRoomMembers(groupId);
    final all = await live.getGroupMembers(groupId);
    final stamp = await live.nextRosterStamp(
      groupId,
      DateTime.now().millisecondsSinceEpoch,
    );
    // the link as it is now, not as it was when the knock came
    final fc = (await live.getGroup(groupId))?['fc_pk'] as String?;
    await _queueControl(
      groupId,
      GroupControl(
        type: 'create',
        name: g['name'] as String,
        members: all,
        stamp: stamp,
        fc: fc,
      ),
      on: live,
    );
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // a frame off a room subscription. the tag says which room key took it
  // and which member key sent it; the content is the plain envelope, the
  // relay layer already opened the seal.
  Future<void> _handleRoomFrame(
    String tag,
    String content, {
    Reached? reached,
  }) async {
    final parts = tag.split(':');
    if (parts.length < 2) return;
    // a knock comes to the room's door: one on a door a reset closed finds
    // no room, as a knock on no room at all
    final g = parts[0] == 'roomfc'
        ? await live.roomByDoor(parts[1])
        : await live.roomByPub(parts[1]);
    if (g == null) return;
    final roomPub = g['room_pub'] as String;
    final groupId = g['group_id'] as String;
    if ((g['expires_at'] as int) <= DateTime.now().millisecondsSinceEpoch) {
      await _destroyRoom(groupId, expired: true);
      return;
    }
    final env = unwrapMessage(content);
    if (env.groupId != groupId) return;
    if (parts[0] == 'roomfc') {
      if (env.groupControl?.type == 'join') {
        await _roomJoin(roomPub, parts[1], env);
      }
      return;
    }
    if (parts.length < 3) return;
    final from = parts[2];
    if (env.senderHaloId != from) return;
    final uid = env.msgUid ?? (AppState._sliced(env) ? env.mediaId : null);
    final data = AppState._dataFrame(env) && uid != null;
    // a message whole in this frame is named by its uid and what it says.
    // a file's slices only once the file is whole (_roomFileTaken)
    final entry = !data || AppState._sliced(env)
        ? null
        : roomEntry(groupId, uid, _roomTextBodyOf(env));
    // the take and its note in one go: a remove reads the notes in the
    // same line, so what this phone shows the others are told of
    final late = await _roomTake(groupId, () async {
      if ((await live.getGroupMembers(groupId)).contains(from)) {
        if (entry != null) await live.noteRoomEntry(groupId, from, entry);
        return false;
      }
      // taken out: a message the admin had from them before that still
      // lands, once, as it was, and nothing else
      if (data && !await live.messageExists(uid)) {
        final owed = entry != null
            ? await live.roomOwes(groupId, from, entry)
            : await live.roomOwesUid(groupId, from, uid);
        if (owed) return true;
      }
      return null;
    });
    if (late == null) {
      dlog('room: frame from a key not in the roster, dropped');
      return;
    }
    try {
      await _applyIncomingPayload(
        from,
        env,
        wire: content,
        late: late,
        reached: reached,
      );
    } on CapHeld {
      // rooms are never strangers; here for completeness
    }
    // the last one owed is in: nothing more of theirs is listened for
    if (late &&
        await live.messageExists(uid!) &&
        await live.roomOwedIn(groupId, from, uid) == 0) {
      await _unlistenNow(groupId, [from]);
    }
    if (env.groupControl != null) await _subscribeRoomMembers(groupId);
  }

  static String _roomTextBodyOf(UnwrappedMessage env) => roomTextBody(
    message: env.message,
    sticker: env.sticker,
    poll: env.poll,
    fileName: env.fileName,
    image: env.imageB64,
    file: env.fileB64,
    replyTo: env.replyTo,
  );

  // a room's file, all its slices in: named by its uid and its bytes, and
  // noted as taken in line with the remove that reads the notes. one from
  // a key taken out goes in only as its remove named it. true for a file
  // of no room
  Future<bool> _roomFileTaken(
    String from,
    UnwrappedMessage env,
    HaloDb db, {
    required bool late,
  }) async {
    final groupId = env.groupId!;
    if (await _roomOf(groupId, db) == null) return true;
    final mid = env.mediaId!;
    final total = env.chunkTotal!;
    final entry = roomEntry(
      groupId,
      mid,
      roomFileBody(
        total: total,
        slices: await roomSliceDigest(total, (i) => db.mediaChunkSlice(mid, i)),
        fileName: env.fileName,
        caption: env.message,
      ),
    );
    return _roomTake(groupId, () async {
      if ((await db.getGroupMembers(groupId)).contains(from)) {
        await db.noteRoomEntry(groupId, from, entry);
        return true;
      }
      return late && await db.roomOwes(groupId, from, entry);
    });
  }

  // keys gone from a room stop being listened to, and what their addresses
  // kept goes. one taken out with messages still owed is heard a while
  // longer, or until the last of them is in
  Future<void> _unlistenGone(
    String groupId,
    Map<String, Set<String>> owed,
    HaloDb d,
  ) async {
    if (d.container.quiet) return;
    final now = <String>[];
    for (final e in owed.entries) {
      if (e.value.isEmpty) {
        now.add(e.key);
        continue;
      }
      Timer(roomLateWait, () => unawaited(_unlistenNow(groupId, [e.key])));
    }
    if (now.isNotEmpty) await _unlistenNow(groupId, now);
  }

  // in the room's turn, off the room's database and row as they are then:
  // the room may have been hidden or ended meanwhile
  Future<void> _unlistenNow(String groupId, List<String> keys) =>
      _roomTurn(groupId, () async {
        for (final d in {_ownerOf(groupId), ..._roomHomes}) {
          if (!identical(d, live) && !d.isOpen) continue;
          final g = await d.getGroup(groupId);
          if (g == null) continue;
          await _unlistenIn(d, groupId, g, keys);
          return;
        }
      });

  // [keys] off room [g]'s roster stop being listened to, and their
  // addresses' files go. a key back on the roster meanwhile keeps its lane.
  // in the room's turn
  Future<void> _unlistenIn(
    HaloDb d,
    String groupId,
    Map<String, Object?> g,
    Iterable<String> keys,
  ) async {
    if (d.container.quiet) return;
    final priv = g['room_priv'] as String?;
    final pub = g['room_pub'] as String?;
    if (priv == null || pub == null) return;
    final members = await d.getGroupMembers(groupId);
    for (final k in keys) {
      if (k == pub || members.contains(k)) continue;
      _roomSubs[pub]?.remove(k);
      engine.roomUnlistenBg(priv, k);
      await d.roomKeyStopped(groupId, k);
    }
  }

  // the room is over: every message, every file, the row, the key, the
  // subscriptions. the wipe goes through the same shred the burn timer
  // uses. a gone room is not a notification, just a line in the list for
  // a moment if someone is looking.
  // in the room's turn: a reset under way finishes first, and nothing of
  // it is left listening after
  Future<void> _destroyRoom(
    String groupId, {
    bool expired = false,
    HaloDb? on,
  }) => _roomTurn(
    groupId,
    () => _destroyRoomTurn(groupId, expired: expired, on: on),
  );

  Future<void> _destroyRoomTurn(
    String groupId, {
    bool expired = false,
    HaloDb? on,
  }) async {
    final d = on ?? live;
    _roomsFull.remove(AppState._fullKey(d.container, groupId));
    final g = await d.getGroup(groupId);
    if (g == null) return;
    final pub = g['room_pub'] as String?;
    final priv = g['room_priv'] as String?;
    if (pub != null && !d.container.quiet) {
      engine.roomUnsubscribeBg(pub);
      final subs = _roomSubs.remove(pub) ?? const <String>{};
      // every key it listened to, those that left or were taken out too
      if (priv != null) {
        engine.roomForgetBg(priv, [
          ...{
            ...await d.getGroupMembers(groupId),
            ...subs,
            ...await d.roomKeysOf(groupId),
          },
        ]);
      }
      final doorPriv = g['door_priv'] as String?;
      final doorPub = g['door_pub'] as String?;
      if (doorPriv != null && doorPub != null) {
        engine.roomUnsubscribeBg(doorPub);
        engine.roomForgetBg(doorPriv, const []);
      }
      final was = g['door_was'] as String?;
      if (was != null) engine.roomForgetBg(was, const []);
    }
    for (final path in await d.groupFilePaths(groupId)) {
      await shredFile(path);
    }
    // what it put in the shade goes with it, while its tag is still here
    await _io.unnotify('group:$groupId');
    await dropGroupDraft(groupId);
    await d.deleteGroupMessages(groupId);
    await d.deleteGroup(groupId);
    // the line in the list is only for a room of the session on screen: an
    // everyday room ending while the decoy is open says nothing there
    if (expired && identical(d, session.primary)) {
      expiredRoomName = g['name'] as String?;
      Timer(const Duration(seconds: 6), () {
        expiredRoomName = null;
        notifyListeners();
      });
    }
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // a room this phone made ends as it leaves: its link reads closed here
  // until its own end
  Future<void> _noteEnded(HaloDb d, String groupId) async {
    try {
      final g = await d.getGroup(groupId);
      final until = (g?['expires_at'] as num?)?.toInt();
      if (g?['room_pub'] == null || g?['is_admin'] != 1 || until == null) {
        return;
      }
      endedRooms.note(d.container.id, groupId, until);
    } catch (e) {
      dlog('room end not noted (${e.runtimeType})');
    }
  }

  Future<void> leaveRoom(String groupId) async {
    await _noteEnded(sessionQuiet ? session.primary : live, groupId);
    if (sessionQuiet) return _destroyRoom(groupId, on: session.primary);
    _leavingRooms.add(groupId);
    await refreshGroups();
    // one try, now: the room's keys go with it, and nothing could send later
    try {
      final wrapped = await wrapMessage(
        '',
        groupId: groupId,
        groupControl: const GroupControl(type: 'leave'),
        sender: _mySender(),
      );
      await Future.wait([
        for (final m in await _othersIn(live, groupId))
          _sendGroupEnvelope(groupId, m, wrapped),
      ]);
    } catch (e) {
      dlog('leave control not sent: $e');
    }
    try {
      await _destroyRoom(groupId);
    } finally {
      _leavingRooms.remove(groupId);
    }
  }

  // everyone blocked on the everyday side: in its container and in the
  // open vault, so a block in one starts the other's waiting clocks. the
  // decoy's list never counts here, nor this one there
  Future<Set<String>> _realBlocked() async {
    final out = {...await live.blockedIds()};
    final v = _openVault;
    if (v != null) {
      try {
        out.addAll(await v.blockedIds());
      } catch (e) {
        // the next sweep reads it, or its own when it opens again
        dlog('burn sweep: vault blocks not read (${e.runtimeType})');
      }
    }
    return out;
  }

  // one pass of the burn sweep: the everyday container, the open vault
  // and a decoy session's own. gives how many went. [stray]: old votes too
  @visibleForTesting
  Future<int> sweepBurns({bool stray = false}) async {
    void unring(String uid) => unawaited(_io.unnotifyMessage(uid));
    var gone = await live.purgeExpired(
      gone: unring,
      blocked: _realBlocked,
      draftOnScreen: draftTypedIn,
      draftGone: emptyComposerOf,
    );
    if (stray) await live.purgeStrayVotes();
    // the open vault's too. shut, its timers wait for the next open
    final v = _openVault;
    if (v != null) {
      try {
        gone += await v.purgeExpired(
          gone: unring,
          blocked: _realBlocked,
          draftOnScreen: draftTypedIn,
          draftGone: emptyComposerOf,
        );
        if (stray) await v.purgeStrayVotes();
      } catch (e) {
        if (identical(_openVault, v)) rethrow;
      }
    }
    // a decoy session's own, while it is the one open. one shut is having
    // its files swapped or wiped, and is never opened from here
    final d = session.primary;
    if (!identical(d, live)) {
      try {
        gone += await d.purgeExpired(
          gone: unring,
          ifOpen: true,
          draftOnScreen: draftTypedIn,
          draftGone: emptyComposerOf,
        );
      } catch (e) {
        if (identical(session.primary, d) && d.isOpen) rethrow;
      }
    }
    return gone;
  }

  // every container a room can be made in: the everyday one, and the
  // decoy's, whose rooms end on time too
  List<HaloDb> get _roomHomes {
    final out = <HaloDb>[live];
    for (final d in [_decoyDb, session.primary]) {
      if (d != null && !out.any((o) => identical(o, d))) out.add(d);
    }
    return out;
  }

  @visibleForTesting
  Future<void> sweepRooms() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in _roomHomes) {
      // a decoy shut while its files are swapped or wiped stays shut
      if (!identical(d, live) && !d.isOpen) continue;
      for (final g in await d.expiredRooms(now)) {
        await _destroyRoom(g['group_id'] as String, expired: true, on: d);
      }
    }
  }

  // one sweep every half minute is plenty: the header counts down on its
  // own, this only has to notice the end.
  void _armRoomTimer() {
    _roomTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!haloWiping) unawaited(sweepRooms());
    });
  }

  // on boot: drop what ended while we were away, then listen to what lives
  Future<void> _subscribeRooms() async {
    await sweepRooms();
    final rooms = await _listenToRooms();
    if (rooms > 0) _armRoomTimer();
    dlog('rooms: listening to $rooms');
    unawaited(_armForOtherRooms());
  }

  // the decoy opens on its own at boot, maybe only after the line above:
  // its rooms are counted once it has, so they end on time too
  Future<void> _armForOtherRooms() async {
    await containersReady;
    try {
      for (final d in _roomHomes.skip(1)) {
        if ((await d.rooms()).isNotEmpty) {
          _armRoomTimer();
          return;
        }
      }
    } catch (e) {
      dlog('rooms: other containers not counted ($e)');
    }
  }

  @visibleForTesting
  Future<void> subscribeRoomsAtBoot() => _subscribeRooms();

  @visibleForTesting
  bool get roomTimerArmed => _roomTimer != null;

  // every everyday room's lanes, each runner started again, so all of
  // them dial the relays of the mode now in use
  Future<int> _listenToRooms() async {
    final rooms = await live.rooms();
    for (final r in rooms) {
      final gid = r['group_id'] as String;
      // in the room's turn, off the row as it is then: a reset or an end
      // under way never leaves an old door listening
      await _roomTurn(gid, () async {
        final g = await live.getGroup(gid);
        final priv = g?['room_priv'] as String?;
        final pub = g?['room_pub'] as String?;
        if (g == null || priv == null || pub == null) return;
        _roomSubs[pub] = {};
        // a reset link knocks on its door key, the first one on the room's
        if ((g['is_admin'] as int? ?? 0) == 1) {
          engine.roomSubscribeFcBg((g['door_priv'] as String?) ?? priv);
          // a reset cut short: the door before it is forgotten now
          await _forgetDoor(gid, g['door_was'] as String?);
        }
        await _subscribeRoomMembers(gid);
        // keys gone before the last stop whose lanes were still open: their
        // files go now, and what they still owed is not waited for
        await _unlistenIn(live, gid, g, await live.roomKeysGoing(gid));
      });
    }
    return rooms.length;
  }
}

/// a composer on the page in front, in an app in front and unlocked: being
/// typed in, so the sweep leaves its timed draft until it is left
bool draftTypedIn(String id, bool group) =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
    !lockGuard.isLocked() &&
    (group ? groupOnScreen(id) : chatOnScreen(id));

/// a timed draft gone empties a composer of it left open, as its timed
/// messages leave an open chat
void emptyComposerOf(HaloContainer c, String id, bool group) =>
    group ? emptyGroupComposer(c, id) : emptyChatComposer(c, id);
