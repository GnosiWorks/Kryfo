// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: groups: sending, polls, members and the controls that arrive

part of '../main.dart';

extension AppStateGroups on AppState {
  // a member list from the wire, less any id that would stand for the
  // developer. this phone's own stays: on his phone it is his words
  List<String> _noDev(List<String> ids) => [
    for (final h in ids)
      if (h == myId || !devIdClaim(h)) h,
  ];

  // a member list from the wire, only of ids with the shape of a member:
  // a person's in a group, a key in a room
  List<String> _members(List<String> ids, {required bool room}) => [
    for (final h in _noDev(ids))
      if (h == myId || wireIdShaped(h, room: room)) h,
  ];

  // where a member list seats each of its people. one whose words are held
  // here on another key than the list gives them is someone else, on an id
  // of their own as a first contact under those words would be: whoever
  // holds the words keeps their row and gets no seat from the list. a room
  // seats keys, not words
  Future<Map<String, String>> _seats(
    List<Map<String, String>>? people,
    HaloDb db, {
    required bool room,
  }) async {
    final out = <String, String>{};
    if (room || people == null) return out;
    for (final p in people) {
      final h = p['h'];
      final key = _xIdentity((p['x'] ?? '').trim().toLowerCase());
      if (h == null || key == null || h == myId) continue;
      // the everyday side or the vault, whichever session is on screen
      final held = await _boundIdentity(
        h,
        ss: signalSession,
        row: db.getContact,
      );
      if ((held != null && !_eqBytes(held, key)) ||
          (held == null && await _tombedArriving(h))) {
        out[h] = unboundIdOf(key);
      }
    }
    return out;
  }

  // the people a member list names on a key "this isn't them" blocked
  // here: no seat and no row from it. a room seats keys, not people
  Future<Set<String>> _keyBlockedSeats(
    List<Map<String, String>>? people, {
    required bool room,
  }) async {
    final out = <String>{};
    if (room || people == null) return out;
    for (final p in people) {
      final h = p['h'];
      final x = (p['x'] ?? '').trim().toLowerCase();
      if (h != null && x.isNotEmpty && await _keyBlockedHere(x)) out.add(h);
    }
    return out;
  }

  // whether a group or room of [n] people fits its cap
  Future<bool> _fitsCap(String groupId, int n, HaloDb db) async {
    if (n > AppState.kGroupMemberCap) return false;
    final cap = (await db.getGroup(groupId))?['member_cap'] as int?;
    return cap == null || n <= cap;
  }

  // an ended group takes nothing in again, written before its end or
  // after: what it held is gone. a member still writing into it is told
  // again, by the admin who ended it
  Future<bool> _endRefuses(
    String sender,
    String? groupId,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    if (groupId == null) return false;
    final end = groupEndOf(await db.getGroup(groupId));
    if (end == null) return false;
    dlog('group: ended, dropped');
    final gc = env.groupControl;
    if (gc == null) {
      await _endAgain(db, groupId, sender, end);
    } else if (gc.type == 'end' && sender == end.by) {
      // its end again: a wipe cut short here finishes now
      await _wipeAgain(groupId, db);
    }
    return true;
  }

  // an ended group's wipe, run again: whatever a stop left goes, its
  // notifications by the tag read before the wipe took it
  Future<void> _wipeAgain(String groupId, HaloDb db) async {
    final tags = {?await db.notifTagOf('group:$groupId')};
    await db.wipeEnded(groupId);
    await _io.unnotifyGone('group:$groupId', tags);
    _bumpChatRev('group:$groupId');
  }

  // an end, from its admin or this phone's own: what the group held goes
  // from here as a leave takes it, its notifications from the shade, and
  // its line stays
  Future<bool> _endHere(
    String groupId,
    HaloDb db, {
    required String by,
    required int at,
  }) async {
    if (groupEndOf(await db.getGroup(groupId)) != null) return false;
    await dropGroupDraft(groupId);
    // the wipe takes its tag: read first, for the shade
    final tags = {?await db.notifTagOf('group:$groupId')};
    if (!await db.endGroup(groupId, by: by, at: at)) return false;
    // after the wipe: a notification of one filed as it ran goes too
    await _io.unnotifyGone('group:$groupId', tags);
    _bumpChatRev('group:$groupId');
    await refreshContacts();
    await refreshGroups();
    return true;
  }

  // a member writing into a group this phone ended never took its end: a
  // version that cannot read it, maybe updated since. it goes to them once
  // more, at most every kEndAgainGap
  Future<void> _endAgain(
    HaloDb d,
    String groupId,
    String member,
    GroupEnd end,
  ) async {
    if (end.by != myId || member == myId || d.container.quiet) return;
    if (!(await d.getGroupMembers(groupId)).contains(member)) return;
    final key = '${d.container.id}|$groupId|$member';
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _endToldAt[key];
    if (last != null && now - last < kEndAgainGap) return;
    _endToldAt[key] = now;
    // one still waiting in their lane goes now, past its tries too: they
    // are there to hear it
    final waits = [
      for (final r in await d.groupCtlFor(groupId, member))
        if (GroupControl.fromWire(AppState._jsonOf(r['ctl']))?.type == 'end') r,
    ];
    if (waits.isEmpty) {
      await d.queueGroupCtl(
        groupId,
        [member],
        const GroupControl(type: 'end'),
        now: now,
      );
    }
    if (haloWiping || everydayHeld) return;
    unawaited(_ctlLane(d, groupId, member, force: true));
  }

  Future<void> _applyGroupControl(
    String senderHaloId,
    UnwrappedMessage env,
    HaloDb db, {
    int? at,
    // it came as a first contact's opener
    bool opener = false,
  }) async {
    final gc = env.groupControl!;
    final groupId = env.groupId;
    if (groupId == null) return;
    // a group here already takes its controls from its admin alone; a
    // room's admin is its creator's key. leave speaks only for its sender
    final exists = await db.groupExists(groupId);
    final fromAdmin = exists && senderHaloId == await db.groupAdminId(groupId);
    // an admin who left speaks for the group no more
    Future<bool> adminHere() async =>
        (await db.getGroupMembers(groupId)).contains(senderHaloId);
    switch (gc.type) {
      case 'join':
        // only ever valid off a room drop box, handled there
        return;
      case 'full':
        // the creator found no seat for this phone's join: the wait says
        // so instead of not answering. nothing else changes
        if (!fromAdmin) return;
        final since = (await db.getGroup(groupId))?['joining_at'] as int?;
        if (since == null) return;
        // an answer to a knock before this one, a minute's clocks allowed
        final w = env.writtenAt;
        if (w != null && w < since - 60000) return;
        if (!_roomsFull.add(AppState._fullKey(db.container, groupId))) return;
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        return;
      case 'create':
        // someone added us to a new group. they are the admin; we are
        // a regular member. group.is_admin stays 0.
        if (gc.members == null || gc.name == null) return;
        if (exists && !fromAdmin) return;
        final isRoom = await _roomOf(groupId, db) != null;
        // a group from someone we never let in is a stranger's message
        // with a roster attached. rooms are ours: we opened the link.
        if (!isRoom &&
            !await db.isAccepted(senderHaloId) &&
            !await db.isVouched(senderHaloId)) {
          return;
        }
        var members = _members(gc.members!, room: isRoom);
        // a room key that left does not come back on a roster made before
        if (isRoom && exists) {
          final gone = await db.rosterGone(groupId);
          members = [
            for (final m in members)
              if (!gone.contains(m)) m,
          ];
        }
        if (!await _fitsCap(groupId, members.toSet().length, db)) return;
        final seats = await _seats(gc.participants, db, room: isRoom);
        final out = await _keyBlockedSeats(gc.participants, room: isRoom);
        members = [
          for (final h in members)
            if (!out.contains(h)) seats[h] ?? h,
        ];
        // rosters can land out of order, a catch-up's most of all: one
        // older than the last taken changes nothing
        final stamp = gc.stamp;
        if (stamp != null && !await db.takeRosterStamp(groupId, stamp)) {
          dlog('group: an older roster, not taken');
          return;
        }
        if (!exists) {
          await db.createGroup(
            groupId,
            gc.name!,
            members,
            isAdmin: false,
            adminId: senderHaloId,
          );
        } else {
          // already in the group: reconcile the member list so a re-add or
          // membership change syncs instead of leaving a stale count.
          await db.syncGroupMembers(groupId, members);
          await db.renameGroup(groupId, gc.name!);
        }
        if (isRoom) {
          // the link a member shares is the one its maker last reset to
          final fc = gc.fc;
          if (exists && fc != null && looksLikeRoomKey(fc)) {
            await db.setRoomFc(groupId, fc);
          }
          await _roomLetIn(groupId, members, db);
        }
        // auto-create contact stubs for unknown participants so we can
        // immediately send to them.
        if (gc.participants != null) {
          for (final p in gc.participants!) {
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
        }
        // the members' roster invites, and mine to the admin in our own
        // session
        if (!isRoom) {
          await _takeRosterInvites(
            groupId,
            gc.participants,
            db,
            seats: seats,
            out: out,
          );
          await _tellRosterInvite(db, groupId, senderHaloId);
        }
        // an open info page reads the roster again
        _bumpChatRev('group:$groupId');
        await refreshContacts();
        await refreshGroups();
        // the block as the admin holds it, and this app's bits back to them
        if (!isRoom) {
          final w = gc.shots;
          if (w != null) await _takeGroupShots(groupId, senderHaloId, w, db);
          await _capsOnJoin(groupId, senderHaloId, db);
        }
        break;
      case 'add':
        if (gc.members == null || !fromAdmin) return;
        final isRoom = await _roomOf(groupId, db) != null;
        final have = await db.getGroupMembers(groupId);
        final seats = await _seats(gc.participants, db, room: isRoom);
        final out = await _keyBlockedSeats(gc.participants, room: isRoom);
        final adds = {
          for (final h in _members(gc.members!, room: isRoom))
            if (!out.contains(h) && !have.contains(seats[h] ?? h))
              seats[h] ?? h,
        };
        if (!await _fitsCap(groupId, have.length + adds.length, db)) return;
        for (final h in adds) {
          await db.addGroupMember(groupId, h);
        }
        if (gc.participants != null) {
          for (final p in gc.participants!) {
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
        }
        if (!isRoom) {
          await _takeRosterInvites(
            groupId,
            gc.participants,
            db,
            seats: seats,
            out: out,
          );
        }
        // an open info page reads the roster again
        _bumpChatRev('group:$groupId');
        await refreshContacts();
        await refreshGroups();
        break;
      case 'ri':
        await _takeMemberRosterInvite(senderHaloId, groupId, gc, db);
        break;
      case 'roster':
        if (!fromAdmin || !await adminHere()) return;
        await _takeRosterInvites(
          groupId,
          gc.participants,
          db,
          seats: await _seats(gc.participants, db, room: false),
          out: await _keyBlockedSeats(gc.participants, room: false),
        );
        break;
      case 'pair':
        await _answerPair(senderHaloId, groupId, db, opener: opener);
        break;
      case 'remove':
        if (gc.members == null || !fromAdmin) return;
        if (!await adminHere()) return;
        // in a room this phone is its room key, never the kryfo id
        final room = await _roomOf(groupId, db);
        final me = room?.pub ?? myId;
        for (final h in gc.members!) {
          if (h != me) await db.removeGroupMember(groupId, h);
        }
        if (room != null) {
          final out = [
            for (final h in gc.members!)
              if (h != me) h,
          ];
          await db.noteRosterGone(groupId, out);
          // the messages the admin had from each before the remove still
          // land here, those not here yet, and no others
          final late = gc.lateUids ?? const <String, List<String>>{};
          final owed = {
            for (final h in out)
              h: await db.noteRoomKeyOut(
                groupId,
                h,
                listed: late[h] ?? const [],
              ),
          };
          if (!gc.members!.contains(me)) await _unlistenGone(groupId, owed, db);
        }
        // taken out: the group goes from here with everything in it, as a
        // leave does, and an open screen says why it closed
        if (gc.members!.contains(me)) {
          final name = (await db.getGroup(groupId))?['name'] as String?;
          if (room != null) {
            await _destroyRoom(groupId, on: db);
          } else {
            await _dropGroup(groupId, db);
          }
          if (name != null) _removedFrom[groupId] = name;
        }
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        break;
      case 'rename':
        if (gc.name == null || !fromAdmin) return;
        if (!await adminHere()) return;
        await db.renameGroup(groupId, gc.name!);
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        break;
      case 'end':
        // a room ends its own way, when its maker leaves
        if (!fromAdmin || await _roomOf(groupId, db) != null) return;
        if (!await adminHere()) return;
        await _endHere(
          groupId,
          db,
          by: senderHaloId,
          at: at ?? DateTime.now().millisecondsSinceEpoch,
        );
        break;
      case 'leave':
        await db.removeGroupMember(groupId, senderHaloId);
        // a room key never comes back once it left, nor is listened for
        if (await _roomOf(groupId, db) != null) {
          await db.noteRosterGone(groupId, [senderHaloId]);
          await db.noteRoomKeyOut(groupId, senderHaloId);
          await _unlistenGone(groupId, {senderHaloId: const {}}, db);
        }
        _bumpChatRev('group:$groupId');
        await refreshGroups();
        // the one it waited for may be gone
        await _shotsRecount(db, groupId: groupId);
        break;
      case 'shots':
        final w = gc.shots;
        if (w == null || !fromAdmin) return;
        await _takeGroupShots(groupId, senderHaloId, w, db);
        break;
      case 'caps':
        // a member's app said what it can, on the envelope: the groups this
        // phone runs take it as it came. this one counts again here too
        await _shotsRecount(db, groupId: groupId);
        break;
    }
  }

  // joined off a link and not let in yet
  static Future<bool> _roomWaiting(Future<Map<String, Object?>?> row) async {
    final g = await row;
    return g != null && g['room_pub'] != null && g['joining_at'] != null;
  }

  // send a normal text message into a group. saves the local row, then
  // multicasts pairwise to every other member. returns true if at least
  // one recipient acknowledged.
  Future<bool> sendToGroup(
    String groupId,
    String plain, {
    String? msgUid,
    String? replyTo,
    int? burnSeconds,
    Map<String, String>? preview,
    PollSpec? poll,
    String? sticker,
    // a retry passes when its row was written
    int? writtenAt,
  }) async {
    // a group that ended, or was left or taken out of: nothing is kept
    if (!await session.groupExists(groupId)) return false;
    if (groupEndOf(await session.getGroup(groupId)) != null) return false;
    // a room not let in yet: nobody reads this phone's key, nothing is kept
    if (await _roomWaiting(session.getGroup(groupId))) return false;
    // a retry of a poll passes only its uid: the options come off the row
    if (poll == null && msgUid != null) {
      poll = (await session.pollRow(msgUid))?.spec;
    }
    // and so does a retry of a sticker, or it goes out as its emoji
    if (sticker == null && msgUid != null) {
      sticker = await session.stickerOf(msgUid);
    }
    msgUid ??= newMsgUid();
    final written = writtenAt ?? DateTime.now().millisecondsSinceEpoch;
    // a timed one's clock starts once a member has it, as in a 1:1 chat:
    // one that waits for a route must not burn before it ever went
    final burnSecs = (burnSeconds != null && burnSeconds > 0)
        ? burnSeconds
        : null;
    // save the local row up front so the chat list shows it at once.
    // peer_id = self so we render it as outgoing. a retry passes the same
    // uid, and a second row breaks every uid-keyed widget key.
    // kept only with the group still here, in the same go
    if (!await session.messageExists(msgUid) &&
        !await session.saveInGroup(
          sessionId,
          plain,
          groupId: groupId,
          msgUid: msgUid,
          replyTo: replyTo,
          // a retry after a reload reads the timer back from the row
          burnSecs: burnSecs,
          // born unsent, or a dead send reloads as a ticked message nobody
          // ever received
          sent: 0,
          preview: preview == null ? null : jsonEncode(preview),
          poll: poll?.toRow(),
          sticker: sticker,
        )) {
      return false;
    }
    // a quiet session keeps the row here, unsent: nothing leaves. one held
    // by a decoy goes from the outbox once it is left
    if (everydayHeld) {
      notifyListeners();
      return false;
    }
    final members = await session.getGroupMembers(groupId);
    // if we are the group admin, ride the full roster on the message so any
    // member whose list drifted self-heals the moment they receive it.
    final adminId = await session.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // ride the member keys too, not just ids: a self-healed member the
    // receiver has no contact for would otherwise throw InvalidKeyException
    // on encrypt. participants let the receiver upsert a stub.
    final rosterParts = amAdmin ? await _buildParticipants(members) : null;
    final shots = amAdmin
        ? await _groupShotsOnWire(_ownerOf(groupId), groupId)
        : null;
    final wrapped = await wrapMessage(
      plain,
      msgUid: msgUid,
      replyTo: replyTo,
      burnSeconds: burnSeconds,
      preview: preview,
      groupId: groupId,
      roster: amAdmin ? members : null,
      rosterParticipants: rosterParts,
      groupShots: shots,
      supporterBadge: await sharedBadge(),
      sender: _mySender(),
      poll: poll?.toWire(),
      sticker: sticker,
      writtenAt: written,
    );
    dlog('grpsend group=$groupId members=$members me=$myId admin=$amAdmin');
    final d = _ownerOf(groupId);
    final to = await _othersIn(d, groupId, members);
    final missed = await _fanOut(d, groupId, to, wrapped);
    final anyOk = missed.length < to.length;
    // the tick is earned, not assumed: only a delivery to at least one
    // member flips the row to sent. the members it missed are owed it
    if (anyOk) {
      await session.markSent(msgUid);
      await session.lightBurn(msgUid);
      await _oweText(d, msgUid, groupId, to: to, missed: missed, first: true);
    }
    notifyListeners();
    return anyOk;
  }

  // chunked media multicast for groups: every 16k slice to each member, see
  // group_media_send. the local row is saved by the caller; this only puts
  // bytes on the wire. returns 'ok', 'busy', 'cancelled' or an error string.
  Future<String> sendMediaToGroup(
    String groupId,
    String path, {
    required String msgUid,
    String caption = '',
    String? fileName,
    bool voice = false,
    bool voiceDisguised = false,
    // the message it answers, on every slice
    String? replyTo,
    int? burnSeconds,
    // when its row was written, on every slice. now when not given
    int? writtenAt,
    // only these members, owed it by a send that went, with what each has
    Map<String, Set<int>>? owed,
    // its place in an album, on every slice
    AlbumTag? album,
    // a spoiler photo, on every slice
    bool spoiler = false,
  }) async {
    final written = writtenAt ?? DateTime.now().millisecondsSinceEpoch;
    // a gif or a voice note shows no share on either side: it just appears
    final gif = quietMedia(path, fileName: fileName, voice: voice);
    // one send per media at a time, the same set the 1:1 path holds. the
    // drainer picks up any row older than 45 s, and a video to a group is
    // still leaving long after that: both would send the whole file.
    if (mediaInflight.contains(msgUid)) return 'busy';
    // a quiet session keeps the row here, unsent: nothing leaves, and one
    // a decoy holds goes from the outbox once it is left
    if (everydayHeld) return 'error: quiet';
    final d = _ownerOf(groupId);
    // a room not let in yet: nobody reads this phone's key
    if (await _roomWaiting(d.getGroup(groupId))) return 'error: waiting';
    if (groupEndOf(await d.getGroup(groupId)) != null) return 'error: ended';
    final members = await d.getGroupMembers(groupId);
    final adminId = await d.groupAdminId(groupId);
    final amAdmin = adminId == myId;
    // the roster is read again for each slice: a long file still going out
    // after a remove or a leave must not carry the old list back to the
    // other phones. once this phone has left or is no longer the admin, the
    // slices carry none. ids and cards are one pair, so wraps running side
    // by side never mix two lists
    var held = (
      ids: members,
      parts: amAdmin ? await _buildParticipants(members) : null,
    );
    Future<(List<String>?, List<Map<String, String>>?)> roster() async {
      if (!amAdmin) return (null, null);
      final now = await d.getGroupMembers(groupId);
      if (!now.contains(myId) || await d.groupAdminId(groupId) != myId) {
        return (null, null);
      }
      var pair = held;
      if (!listEquals(now, pair.ids)) {
        pair = (ids: now, parts: await _buildParticipants(now));
        held = pair;
      }
      return (pair.ids, pair.parts);
    }

    // in a room this phone is its room key, which never takes a frame
    final room = await _roomOf(groupId, d);
    final to = [
      for (final m in members)
        if (m != myId && m != room?.pub && (owed?.containsKey(m) ?? true)) m,
    ];
    // the owed have all left the group
    if (owed != null && to.isEmpty) return 'gone';
    // a member still to get a control of the group gets that first. one
    // that cannot yet is owed the whole file
    final waiting = await d.groupCtlWaiting(groupId);
    final behind = <String>{};
    await Future.wait([
      for (final m in to)
        if (waiting.contains(m))
          _ctlLane(d, groupId, m, force: true).then((ok) {
            if (!ok) behind.add(m);
          }),
    ]);
    final go = [
      for (final m in to)
        if (!behind.contains(m)) m,
    ];
    if (go.isEmpty) return owed == null ? 'error: held' : 'later';

    // more than a slice to a group whose phones all fetch from the files
    // service: up once for everyone it goes to, and one frame to each with
    // a token of its own put in as it goes. a room's files stay in slices
    DropSent? drop;
    var marker = '';
    if (room == null && await _dropSize(path) && await dropsForGroup(groupId)) {
      if (fileName == null && !voice && await cleanSavedPhoto(path) == null) {
        return 'error: not clean';
      }
      if (owed == null) {
        mediaProgressStart(
          msgUid,
          chatKey: d.container.chatKey(groupId),
          bytes: await File(path).length(),
          quiet: gif,
        );
      }
      final (sent, r) = await sendDrop(
        path: path,
        uid: msgUid,
        members: to,
        progress: owed == null,
      );
      if (mediaCancelled.contains(msgUid) || r == 'error: cancelled') {
        mediaProgressEnd(msgUid);
        return 'cancelled';
      }
      if (sent != null) {
        drop = sent;
        marker = 'tok${newMsgUid()}';
      } else if (!dropFallsBack(r) ||
          await File(path).length() > kOldFileBytes) {
        mediaProgressEnd(msgUid);
        return 'error: drop ${r.replaceFirst('error: ', '')}';
      } else {
        dlog('grp media $msgUid: the files service said $r, going as slices');
      }
    }
    // a phone that takes slices only takes so many of a file
    if (drop == null &&
        fileName != null &&
        !voice &&
        await mediaSliceCount(path) > kMaxFileSlices) {
      return 'error: big';
    }

    // 16k slices. bigger sizes trip nip-44's 65535 plaintext ceiling once
    // base64'd + double-wrapped (envelope + signal + gift wrap ~= x2.4), and
    // public relays reject the event. 16k lands ~38-51k, safe on every relay.
    // receivers reassemble by index/total, so slice size is free to change.
    final r = await sendGroupSlices(
      path: path,
      msgUid: msgUid,
      members: go,
      // a send to the owed is behind a row that already reads sent
      progressKey: owed == null ? d.container.chatKey(groupId) : null,
      owed: owed,
      hold: () => everydayHeld,
      quiet: gif,
      // a member left short is sent the rest later, from the outbox
      onShort: (short, total) async {
        // the send went either way: a row not written costs that member
        // the file, not the others their sent tick
        try {
          await d.settleGroupOwed(
            msgUid,
            groupId,
            total: total,
            tried: go,
            short: {
              ...short,
              if (owed == null)
                for (final m in behind) m: <int>{},
            },
            sentTo: to.length,
            first: owed == null,
            now: DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          dlog('grp media $msgUid: owed not kept (${e.runtimeType})');
        }
        groupOwedTick.value++;
      },
      photo: drop == null && fileName == null && !voice,
      single: drop != null,
      wrap: (slice, i, total) async {
        final (ids, parts) = await roster();
        return wrapMessage(
          caption,
          msgUid: msgUid,
          imageB64: drop == null && fileName == null && !voice ? slice : null,
          fileB64: drop == null && (fileName != null || voice) ? slice : null,
          drop: drop?.frame.withToken(marker),
          fileName: fileName,
          voice: voice,
          voiceDisguised: voiceDisguised,
          mediaId: total > 1 ? msgUid : null,
          chunkIndex: total > 1 ? i : null,
          chunkTotal: total > 1 ? total : null,
          burnSeconds: burnSeconds,
          replyTo: replyTo,
          album: album,
          spoiler: spoiler,
          gif: gif,
          groupId: groupId,
          roster: ids,
          rosterParticipants: parts,
          groupShots: ids == null ? null : await _groupShotsOnWire(d, groupId),
          supporterBadge: await sharedBadge(),
          sender: _mySender(),
          writtenAt: written,
        );
      },
      deliver: (m, wrapped) => _sendGroupEnvelope(
        groupId,
        m,
        drop == null
            ? wrapped
            : withMemberToken(wrapped, marker, drop.tokens[m]),
      ),
    );
    // the outbox has the row now, and goes on from what landed
    if (r == kMediaStalled) unawaited(drainOutbox());
    return r;
  }

  // worth the files service: more than one slice, not past its size
  Future<bool> _dropSize(String path) async {
    try {
      return dropFits(await File(path).length());
    } catch (_) {
      return false;
    }
  }

  // shared pin: everyone in the group sees the same pins
  Future<void> pinInGroup(
    String groupId,
    String targetMsgUid,
    bool pinned,
  ) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    await session.setPinned(targetMsgUid, pinned);
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pin: PinFrame(targetUid: targetMsgUid, pinned: pinned),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    await _toMembers(groupId, [
      for (final memberId in members)
        if (memberId != myId) memberId,
    ], wrapped);
  }

  // one frame to each of [to]. one a decoy kept from going waits in their
  // lane, never dropped
  Future<void> _toMembers(
    String groupId,
    List<String> to,
    String wrapped,
  ) async {
    final held = <String>[];
    await Future.wait([
      for (final m in to)
        _sendGroupEnvelope(groupId, m, wrapped).then((ok) {
          if (!ok && everydayHeld) held.add(m);
        }),
    ]);
    if (held.isEmpty) return;
    try {
      await _ownerOf(groupId).queueGroupWrapped(
        groupId,
        held,
        wrapped,
        now: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dlog('group frame: not kept (${e.runtimeType})');
    }
  }

  // pairwise reaction multicast for group messages.
  Future<void> reactInGroup(
    String groupId,
    String targetMsgUid,
    String emoji,
  ) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    if (emoji.isEmpty) {
      await session.removeReaction(targetMsgUid, '');
    } else {
      await session.addReaction(targetMsgUid, '', emoji);
    }
    // show it now, not after the tor multicast
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) return;
    await _queueGroupFrame(groupId, groupReactRow(targetMsgUid, emoji));
  }

  // an edit or a reaction of ours in a group: each member's lane keeps it
  // until they have it, behind what they are still to get of the group
  Future<void> _queueGroupFrame(String groupId, Map<String, String> row) async {
    final d = _ownerOf(groupId);
    final to = await _othersIn(d, groupId);
    await d.queueGroupFrame(
      groupId,
      to,
      row,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    // due now, behind what each lane still waits out: a lane backing off
    // keeps its gap
    if (haloWiping || everydayHeld) return;
    unawaited(_drainGroupCtl());
  }

  // ---- polls ----

  // who this phone is in a chat. in a room it is the room key, never the
  // kryfo id: a vote, or the final count a close carries, would otherwise
  // put the real id in front of the room.
  Future<String> meIn(String groupId) async =>
      (await _roomOf(groupId, session.primary))?.pub ?? sessionId;

  // a vote goes out like a reaction: shown here at once, then to every
  // member. choosing nothing takes the vote back.
  Future<void> votePoll(
    String groupId,
    String pollUid,
    List<int> choices,
  ) async {
    final row = await session.pollRow(pollUid);
    if (row == null || row.spec.closed || row.groupId != groupId) return;
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    final me = await meIn(groupId);
    final picks = cleanChoices(choices, row.spec);
    final seq = nextVoteSeq(
      await session.pollVoteSeq(pollUid, me),
      DateTime.now().millisecondsSinceEpoch,
    );
    await session.putPollVote(pollUid, me, groupId, picks, seq);
    _bumpChatRev('group:$groupId');
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      vote: VoteFrame(pollUid: pollUid, choices: picks, seq: seq),
      sender: _mySender(),
    );
    final members = await session.getGroupMembers(groupId);
    unawaited(
      _toMembers(groupId, [
        for (final m in members)
          if (m != myId && m != me) m,
      ], wrapped),
    );
  }

  // only the poll's creator closes it. the close carries the votes as this
  // phone holds them, and every member takes those as the final result.
  Future<void> closePoll(String groupId, String pollUid) async {
    final row = await session.pollRow(pollUid);
    if (row == null || !row.mine || row.spec.closed || row.groupId != groupId) {
      return;
    }
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    final held = (await session.pollVotesFor([pollUid]))[pollUid] ?? const {};
    final finals = <String, List<int>>{};
    for (final e in held.entries) {
      final picks = cleanChoices(e.value.choices, row.spec);
      if (picks.isNotEmpty) finals[e.key] = picks;
    }
    await session.closePollRow(pollUid, row.spec, finals, groupId);
    _bumpChatRev('group:$groupId');
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    final wrapped = await wrapMessage(
      '',
      groupId: groupId,
      pollClose: PollCloseFrame(pollUid: pollUid, finalVotes: finals),
      sender: _mySender(),
    );
    final me = await meIn(groupId);
    final members = await session.getGroupMembers(groupId);
    await _toMembers(groupId, [
      for (final m in members)
        if (m != myId && m != me) m,
    ], wrapped);
  }

  // a vote from a member. members write to us separately, so a vote can
  // overtake the poll it names; it waits then, an hour at most, and counts
  // once the poll is here. a vote for a poll that already went is dropped.
  Future<void> _applyVote(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final v = env.vote!;
    final gid = env.groupId;
    if (gid == null || !await db.groupExists(gid)) return;
    final row = await db.pollRow(v.pollUid);
    final fate = voteFate(
      member: (await db.getGroupMembers(gid)).contains(sender),
      pollHere: row != null,
      pollGone: row == null && await db.pollGone(v.pollUid),
      sameChat: row?.groupId == gid,
      closed: row?.spec.closed ?? false,
    );
    switch (fate) {
      case VoteFate.drop:
        dlog('vote: dropped');
      case VoteFate.hold:
        final raw = <int>{
          for (final c in v.choices)
            if (c is int && c >= 0 && c < kPollMaxOptions) c,
        }.toList()..sort();
        await db.putPollVote(v.pollUid, sender, gid, raw, v.seq);
      case VoteFate.count:
        final picks = cleanChoices(v.choices, row!.spec);
        if (await db.putPollVote(v.pollUid, sender, gid, picks, v.seq)) {
          notifyListeners();
        }
    }
  }

  Future<void> _applyPollClose(
    String sender,
    UnwrappedMessage env,
    HaloDb db,
  ) async {
    final c = env.pollClose!;
    final row = await db.pollRow(c.pollUid);
    if (!closeAccepted(
      pollHere: row != null,
      fromCreator: row != null && await db.isTheirs(c.pollUid, sender),
      sameChat: row?.groupId == env.groupId,
      closed: row?.spec.closed ?? false,
    )) {
      dlog('poll close: dropped');
      return;
    }
    await db.closePollRow(
      c.pollUid,
      row!.spec,
      cleanFinal(c.finalVotes, row.spec),
      row.groupId,
    );
    notifyListeners();
  }

  // recall a group message everywhere: delete locally, tell every member.
  // receiver handles 'un' group-agnostically (deletes by uid).
  Future<void> unsendInGroup(String groupId, String targetMsgUid) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    // a file still going, to everyone or to the members it missed, stops
    // before its row and its file go, and what they were owed goes too
    if (mediaInflight.contains(targetMsgUid)) cancelMediaSend(targetMsgUid);
    // up on the files service already: it comes down with the row
    await takeDropBackOf(targetMsgUid);
    await session.deleteMessage(targetMsgUid);
    groupOwedTick.value++;
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      notifyListeners();
      return;
    }
    // each member's lane keeps it until they have it, behind what that
    // member is still to get of the group, after a restart too
    final d = _ownerOf(groupId);
    final to = await _othersIn(d, groupId);
    await d.queueGroupUnsend(
      groupId,
      to,
      targetMsgUid,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    // the first try goes now, as a message would, and costs none of its
    // tries
    if (haloWiping || sessionQuiet) return;
    for (final m in to) {
      unawaited(_ctlLane(d, groupId, m, force: true));
    }
  }

  // edit a group message everywhere: swap text locally, tell every member.
  Future<void> editInGroup(
    String groupId,
    String targetMsgUid,
    String newText,
  ) async {
    if (groupEndOf(await session.getGroup(groupId)) != null) return;
    await session.editMessage(targetMsgUid, newText);
    notifyListeners();
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) return;
    await _queueGroupFrame(groupId, groupEditRow(targetMsgUid, newText));
  }

  // build participant info {h,o,x} for each halo_id we have as a contact
  // (or for our own kryfo). used to give group invites enough info that
  // recipients can fan-out to members they don't yet know.
  // [invites]: a control's roster, which carries each member's roster
  // invite the group holds, and mine, beside their keys. an older
  // version reads the keys and leaves the rest
  Future<List<Map<String, String>>> _buildParticipants(
    List<String> haloIds, {
    ({HaloDb db, String groupId})? invites,
  }) async {
    Map<String, RosterInviteRow> held = const {};
    String? mine;
    // rows that do not read leave them out: the keys go as before
    try {
      if (invites != null && await _rosterGroup(invites.db, invites.groupId)) {
        held = await rosterInvitesIn(await invites.db.open(), invites.groupId);
        final r = await currentRosterInvite(await live.open(), kMainIdent);
        if (r != null) mine = base64Encode(r.link);
      }
    } catch (e) {
      dlog('roster invite: not read for the roster (${e.runtimeType})');
    }
    final out = <Map<String, String>>[];
    for (final h in haloIds) {
      if (h == myId) {
        out.add({
          'h': myId,
          'o': myOnion,
          'x': engine.myXPubkey(),
          'ri': ?mine,
        });
      } else {
        final c = await session.getContact(h);
        if (c != null) {
          final ri = held[h];
          out.add({
            'h': h,
            'o': c['onion'] as String,
            'x': c['xpub'] as String,
            if (ri != null) 'ri': base64Encode(ri.invite),
          });
        }
      }
    }
    return out;
  }

  Future<String> createGroupAndAnnounce(
    String name,
    List<String> memberHaloIds,
  ) async {
    // groups are made on the phone: a phone takes no group from a device
    if (linkedRole) throw const GroupOnPhone();
    // a group of only yourself is never made, whatever the screen let by
    if (!memberHaloIds.any((m) => m != sessionId)) {
      throw StateError('a group needs someone besides you');
    }
    final groupId = newMsgUid();
    final full = [sessionId, ...memberHaloIds];
    if (full.length > AppState.kGroupMemberCap) throw const GroupFull();
    await session.createGroup(
      groupId,
      name,
      full,
      isAdmin: true,
      adminId: sessionId,
    );
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return groupId;
    }
    final d = _ownerOf(groupId);
    final participants = await _buildParticipants(
      full,
      invites: (db: d, groupId: groupId),
    );
    final gc = GroupControl(
      type: 'create',
      name: name,
      members: full,
      participants: participants,
      stamp: await d.nextRosterStamp(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _queueControl(groupId, gc, on: d);
    await refreshGroups();
    return groupId;
  }

  // admin-only. adds members locally, sends 'add' to existing members
  // (with participants for the new ones), and sends a full 'create' to
  // each new member so they bootstrap the group.
  Future<void> addMembersToGroup(
    String groupId,
    List<String> newHaloIds,
  ) async {
    if (linkedRole) throw const GroupOnPhone();
    final group = await session.getGroup(groupId);
    if (group == null || groupEndOf(group) != null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final existingMembers = await session.getGroupMembers(groupId);
    if (existingMembers.length + newHaloIds.length > AppState.kGroupMemberCap) {
      throw const GroupFull();
    }
    for (final h in newHaloIds) {
      await session.addGroupMember(groupId, h);
    }
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return;
    }
    final d = _ownerOf(groupId);
    final newParticipants = await _buildParticipants(
      newHaloIds,
      invites: (db: d, groupId: groupId),
    );
    final addGc = GroupControl(
      type: 'add',
      members: newHaloIds,
      participants: newParticipants,
    );
    await _queueControl(groupId, addGc, to: existingMembers, on: d);
    final allMembers = await session.getGroupMembers(groupId);
    final allParticipants = await _buildParticipants(
      allMembers,
      invites: (db: d, groupId: groupId),
    );
    final createGc = GroupControl(
      type: 'create',
      name: group['name'] as String,
      members: allMembers,
      participants: allParticipants,
      stamp: await d.nextRosterStamp(
        groupId,
        DateTime.now().millisecondsSinceEpoch,
      ),
      shots: await _groupShotsOnWire(d, groupId),
    );
    await _queueControl(groupId, createGc, to: newHaloIds, on: d);
    // someone whose app cannot block pauses it, for everyone
    await _shotsRecount(d, groupId: groupId);
    await refreshGroups();
  }

  // admin-only. removes locally and tells everyone (including removed) so
  // both sides converge on the new member list.
  Future<void> removeMembersFromGroup(
    String groupId,
    List<String> removedHaloIds,
  ) async {
    if (linkedRole) throw const GroupOnPhone();
    final group = await session.getGroup(groupId);
    if (group == null || groupEndOf(group) != null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    final d = _ownerOf(groupId);
    final room = await _roomOf(groupId, d) != null;
    // in a room, in line with each message taken and noted as it is taken:
    // the remove names every one this phone shows
    Future<(List<String>, GroupControl)> take() async {
      final allMembers = await session.getGroupMembers(groupId);
      for (final h in removedHaloIds) {
        await session.removeGroupMember(groupId, h);
      }
      if (!room) {
        return (
          allMembers,
          GroupControl(type: 'remove', members: removedHaloIds),
        );
      }
      // a room key taken out does not join again. the last messages taken
      // from each go with the remove: the members still take those
      await d.noteRosterGone(groupId, removedHaloIds);
      final late = <String, List<String>>{};
      for (final h in removedHaloIds) {
        final recent = await d.roomRecent(groupId, h);
        await d.noteRoomKeyOut(groupId, h);
        if (recent.isNotEmpty) late[h] = recent;
      }
      return (
        allMembers,
        GroupControl(
          type: 'remove',
          members: removedHaloIds,
          lateUids: late.isEmpty ? null : late,
        ),
      );
    }

    final (allMembers, gc) = room
        ? await _roomTake(groupId, take)
        : await take();
    // nothing is owed here: this phone had all it shows
    if (room) {
      await _unlistenGone(groupId, {
        for (final h in removedHaloIds) h: const <String>{},
      }, d);
    }
    // a quiet session keeps it on this phone: nothing leaves
    if (sessionQuiet) {
      await refreshGroups();
      return;
    }
    // the ones taken out hear it too, so they drop the group
    await _queueControl(groupId, gc, to: allMembers);
    // the one it waited for may be gone
    if (!room) await _shotsRecount(d, groupId: groupId);
    await refreshGroups();
  }

  Future<void> renameGroupAndAnnounce(String groupId, String newName) async {
    if (linkedRole) throw const GroupOnPhone();
    final group = await session.getGroup(groupId);
    if (group == null || groupEndOf(group) != null) return;
    if ((group['is_admin'] as int? ?? 0) != 1) return;
    await session.renameGroup(groupId, newName);
    final gc = GroupControl(type: 'rename', name: newName);
    // a quiet session keeps it on this phone: nothing leaves
    if (!sessionQuiet) await _queueControl(groupId, gc);
    await refreshGroups();
  }

  // admin-only, and for good. what the group held goes from this phone and
  // from every member's that can read the end, as a leave takes it, and
  // each keeps its line. a version that cannot read the end gets one plain
  // message saying so, which this one never keeps
  Future<bool> endGroupAndAnnounce(String groupId) async {
    if (linkedRole) throw const GroupOnPhone();
    if (!mayEndGroup(await session.getGroup(groupId), sessionId)) return false;
    // the session's own: a decoy's group is the decoy's
    final d = session.groupDb(groupId);
    final now = DateTime.now().millisecondsSinceEpoch;
    // queued before anything here goes, the end first and its words after
    // it, in one go: a stop on the way loses neither, nor the wipe
    // (_dropGroupLeftovers). a quiet session keeps it on this phone
    if (!sessionQuiet) {
      final notice = await wrapMessage(
        l10n.groupEndedOldNotice,
        msgUid: newMsgUid(),
        groupId: groupId,
        sender: _mySender(),
        endNotice: true,
        writtenAt: now,
      );
      await d.queueGroupEnd(
        groupId,
        await _othersIn(d, groupId),
        notice,
        now: now,
      );
    }
    if (!await _endHere(groupId, d, by: sessionId, at: now)) return false;
    if (!sessionQuiet && !haloWiping && !everydayHeld) {
      unawaited(_drainGroupCtl());
    }
    return true;
  }

  // anyone can leave. the group goes from here with all it held, then the
  // rest are told, so they drop us from their copies. the leave is queued:
  // it goes once the route is there, and leaving waits for nobody. an
  // ended group only goes from here: nobody there takes word of it
  Future<void> leaveGroupAndAnnounce(String groupId) async {
    if (await _roomOf(groupId, session.primary) != null) {
      return leaveRoom(groupId);
    }
    final d = _ownerOf(groupId);
    final ended = groupEndOf(await session.getGroup(groupId)) != null;
    // an ended group only goes from here, on a linked device too; one that
    // runs is left on the phone
    if (linkedRole && !ended) throw const GroupOnPhone();
    final members = sessionQuiet || ended
        ? const <String>[]
        : await d.getGroupMembers(groupId);
    await _io.unnotify('group:$groupId');
    await dropGroupDraft(groupId);
    await session.clearGroupConversation(groupId, noteGone: false);
    await session.deleteGroup(groupId);
    // a quiet session keeps it on this phone: nothing leaves
    if (!sessionQuiet && !ended) {
      await _queueControl(
        groupId,
        const GroupControl(type: 'leave'),
        to: members,
        on: d,
      );
    }
    _bumpChatRev('group:$groupId');
    await refreshGroups();
  }

  // a group this phone was taken out of: its messages, files and row, and
  // what it left in the shade
  Future<void> _dropGroup(String groupId, HaloDb db) async {
    await _io.unnotify('group:$groupId');
    await dropGroupDraft(groupId);
    await db.clearGroupConversation(groupId, noteGone: false);
    await db.deleteGroup(groupId);
  }

  String? takeRemovedFrom(String groupId) => _removedFrom.remove(groupId);
}
