// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: group files, owed sends and controls, member by member

part of '../main.dart';

extension AppStateGroupLanes on AppState {
  Future<void> _drainGroupMedia(
    Map<String, Object?> r,
    String groupId,
    String uid,
    String path, {
    required bool isFile,
    required HaloDb on,
  }) async {
    final f = File(path);
    if (!await f.exists()) return;
    // a whole resend of an opus note to a group that no longer all plays
    // it goes as wav
    final (sendPath, fileName, scratch) = await voiceAgain(
      path,
      isFile ? r['file_name'] as String? : null,
      opus: await opusForGroup(groupId),
      scratch: '${(await getTemporaryDirectory()).path}/vn_${uid}_r.wav',
    );
    String res;
    try {
      res = await sendMediaToGroup(
        groupId,
        sendPath,
        msgUid: uid,
        caption: (r['plaintext'] as String?) ?? '',
        fileName: fileName,
        voice: isVoiceName(fileName),
        voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
        replyTo: r['reply_to'] as String?,
        burnSeconds: (r['burn_secs'] as num?)?.toInt(),
        writtenAt: (r['sent_at'] as num?)?.toInt(),
        album: AlbumTag.ofRow(r),
      );
    } catch (e) {
      res = 'error: $e';
    } finally {
      if (scratch != null) await shredFile(scratch);
    }
    if (res == 'ok') {
      dlog('outbox: group media redelivered $uid');
      await on.markSent(uid);
      await _lightBurn(r, uid, on);
      // an open group re-reads the row, as the 1:1 drainer has it
      _bumpChatRev('group:$groupId');
      notifyListeners();
    } else if (res != 'busy') {
      dlog('outbox: group media $uid still stuck ($res)');
      // a bubble a busy retry left spinning settles into failed
      _bumpChatRev('group:$groupId');
    }
  }

  Future<void> _drainGroupOwed() =>
      _owedPass ??= _owedRound().whenComplete(() => _owedPass = null);

  @visibleForTesting
  Future<void> get owedPassForTest => _owedPass ?? Future<void>.value();

  @visibleForTesting
  Future<void> owedRoundForTest() => _owedRound();

  Future<void> _owedRound() async {
    for (final d in [live, ?_openVault]) {
      // a quiet session sends nothing, and a wipe takes the rows with it
      if (haloWiping || everydayHeld) return;
      try {
        await resendGroupOwed(
          d,
          now: DateTime.now().millisecondsSinceEpoch,
          send: (uid, groupId, have, total) =>
              _sendOwed(d, uid, groupId, have, total),
          // a read that fails holds: it uses no try
          held: (m) => keyHeld(m, strict: true),
          hold: () => everydayHeld,
        );
      } catch (e) {
        dlog('grp media owed: ${e.runtimeType}');
      }
    }
  }

  // one file again, to the members owed it. 'later' when the chat is not
  // where this pass found it, or the row is still the outbox's
  Future<String> _sendOwed(
    HaloDb d,
    String uid,
    String groupId,
    Map<String, Set<int>> have,
    int total,
  ) async {
    // a wipe or a quiet session that began during the pass starts nothing
    if (haloWiping || everydayHeld) return 'error: quiet';
    if (!identical(_ownerOf(groupId), d)) return 'later';
    final r = await d.sentMediaRow(uid);
    if (r == null || r['direction'] != 'out' || r['group_id'] != groupId) {
      return 'gone';
    }
    if ((r['sent'] as int? ?? 1) == 0) return 'later';
    final mediaPath = r['media_path'] as String?;
    final path = mediaPath ?? r['file_path'] as String?;
    if (path == null) return _sendOwedText(d, r, uid, groupId, have.keys);
    if (path.isEmpty || !await File(path).exists()) return 'gone';
    final members = await d.getGroupMembers(groupId);
    await d.keepGroupOwedTo(groupId, members);
    final to = [
      for (final m in have.keys)
        if (members.contains(m)) m,
    ];
    if (to.isEmpty) return 'gone';
    // the file is not the one their slices were of: all of it again
    final fresh = await mediaSliceCount(path) != total;
    final fileName = mediaPath == null ? r['file_name'] as String? : null;
    return sendMediaToGroup(
      groupId,
      path,
      msgUid: uid,
      caption: (r['plaintext'] as String?) ?? '',
      fileName: fileName,
      voice: isVoiceName(fileName),
      voiceDisguised: ((r['voice_disguised'] as int?) ?? 0) == 1,
      replyTo: r['reply_to'] as String?,
      burnSeconds: (r['burn_secs'] as num?)?.toInt(),
      writtenAt: (r['sent_at'] as num?)?.toInt(),
      owed: {for (final m in to) m: fresh ? <int>{} : have[m]!},
      album: AlbumTag.ofRow(r),
    );
  }

  // a text, a poll or a sticker again, to the members it missed
  Future<String> _sendOwedText(
    HaloDb d,
    Map<String, Object?> r,
    String uid,
    String groupId,
    Iterable<String> owed,
  ) async {
    // its time ran out here: it is never sent again
    final burn = (r['burn_at'] as num?)?.toInt();
    if (burn != null && burn <= DateTime.now().millisecondsSinceEpoch) {
      return 'gone';
    }
    final members = await d.getGroupMembers(groupId);
    await d.keepGroupOwedTo(groupId, members);
    final to = [
      for (final m in owed)
        if (members.contains(m)) m,
    ];
    if (to.isEmpty) return 'gone';
    final wrapped = await wrapRedelivery(
      r,
      sender: _mySender(),
      badge: await sharedBadge(),
    );
    final missed = await _fanOut(d, groupId, to, wrapped);
    await _oweText(d, uid, groupId, to: to, missed: missed, first: false);
    return missed.isEmpty ? 'ok' : 'error: ${missed.length} short';
  }

  // a group text, poll or sticker reads sent once a member has it. the
  // members it missed are owed it, as a file's are, and get it from the
  // outbox's tick
  Future<void> _oweText(
    HaloDb d,
    String uid,
    String groupId, {
    required List<String> to,
    required List<String> missed,
    required bool first,
  }) async {
    if (first && missed.isEmpty) return;
    try {
      await d.settleGroupOwed(
        uid,
        groupId,
        total: 1,
        tried: to,
        short: {for (final m in missed) m: <int>{}},
        sentTo: to.length,
        first: first,
        now: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dlog('grp $uid: owed not kept (${e.runtimeType})');
    }
    groupOwedTick.value++;
  }

  // a member's session just came up: the controls and messages they are
  // owed go now, not at the end of their wait
  Future<void> _owedDueFor(String member) async {
    var due = 0;
    var ctl = 0;
    for (final d in [live, ?_openVault]) {
      try {
        ctl += await d.groupCtlDueNow(member);
        due += await d.groupOwedDueNow(member);
      } catch (e) {
        dlog('grp media owed: ${e.runtimeType}');
      }
    }
    if (ctl > 0) await _drainGroupCtl();
    // one past its tries is tried again: its line counts again, sent or not
    if (due > 0) groupOwedTick.value++;
    if (due > 0 && torReady) await _drainGroupOwed();
  }

  @visibleForTesting
  Future<void> owedDueForTest(String member) => _owedDueFor(member);

  @visibleForTesting
  Future<void> get ctlPassForTest async {
    await _ctlRound;
    while (_ctlLanes.isNotEmpty) {
      await Future.wait(_ctlLanes.values.toList());
    }
  }

  // every lane whose next control is due. a send that fails waits its turn
  // again, on the outbox's tick or when the member's session comes up
  Future<void> _drainGroupCtl() => _ctlRound = _ctlLanesDue();

  Future<void> _ctlLanesDue() async {
    for (final d in [live, ?_openVault]) {
      if (haloWiping || everydayHeld) return;
      final List<Map<String, Object?>> rows;
      try {
        rows = await d.groupCtlOut();
      } catch (e) {
        continue;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final heads = <String, Map<String, Object?>>{};
      for (final r in rows) {
        heads.putIfAbsent('${r['group_id']} ${r['member']}', () => r);
      }
      final held = await _heldOf(d);
      for (final r in heads.values) {
        if ((r['next_at'] as int? ?? 0) > now) continue;
        if (held.contains(r['member'])) continue;
        unawaited(_ctlLane(d, r['group_id'] as String, r['member'] as String));
      }
    }
  }

  // true once [member] has every control of [groupId] queued for it.
  // [force] tries each one even while it waits, and costs none a try
  Future<bool> _ctlLane(
    HaloDb d,
    String groupId,
    String member, {
    bool force = false,
  }) {
    final key = '$groupId $member';
    final running = _ctlLanes[key];
    if (running != null) {
      _ctlLaneAgain.add(key);
      return running;
    }
    final run = _runCtlLane(d, groupId, member, force).whenComplete(() {
      _ctlLanes.remove(key);
      if (_ctlLaneAgain.remove(key)) unawaited(_ctlLane(d, groupId, member));
    });
    return _ctlLanes[key] = run;
  }

  Future<bool> _runCtlLane(
    HaloDb d,
    String groupId,
    String member,
    bool force,
  ) async {
    var sent = false;
    try {
      while (true) {
        // a wipe or a quiet session sends nothing more
        if (haloWiping || everydayHeld) return false;
        final rows = await d.groupCtlFor(groupId, member);
        if (rows.isEmpty) break;
        final r = rows.first;
        final id = r['id'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (!force && (r['next_at'] as int? ?? 0) > now) return false;
        final un = groupUnsendOf(r['ctl']);
        final fr = un != null ? null : groupFrameOf(r['ctl']);
        final wr = un != null || fr != null ? null : groupWrappedOf(r['ctl']);
        final gc = un != null || fr != null || wr != null
            ? null
            : GroupControl.fromWire(AppState._jsonOf(r['ctl']));
        // no longer theirs to get: the next one goes. a take-back is kept
        // only where it can still go: members who left, were taken out, or
        // saw us leave or be taken out may hold the message yet, and act
        // on it without the group. an edit or reaction only to a member
        // still in it, of a message still here
        final owed =
            un != null ||
            fr != null && await _frameStillOwed(d, groupId, member, fr.uid) ||
            wr != null && await _wrappedStillOwed(d, groupId, member, wr) ||
            gc != null && await _ctlStillOwed(d, groupId, member, gc);
        if (!owed) {
          await d.dropGroupCtl(id);
          continue;
        }
        if ((r['tries'] as int? ?? 0) >= kGroupOwedTries) {
          // past its tries a create stays: the group is not there without
          // it, and what goes after would be dropped. so does an end: the
          // group would stay open there for good. a take-back stays too:
          // the message is theirs to keep without it. each goes on a send
          // of ours to them, or when their session comes up
          // an end outlives its group here only while it may still go
          final kept =
              gc?.type == 'create' ||
              gc?.type == 'end' && await d.groupExists(groupId);
          if (un == null && !kept) {
            await d.dropGroupCtl(id);
            continue;
          }
          if (!force) return false;
        }
        if (un != null && mediaInflight.contains(un)) {
          // a slice of the file it takes back may still be on its way: the
          // take-back goes once the stopped send let go, so it lands last
          await whenMediaFree(un);
          if (haloWiping || everydayHeld) return false;
          continue;
        }
        // only a pass on the lane's own schedule costs a try. one a send
        // forces is free, or a busy group would spend them in hours.
        // stamped before it goes, so a send cut short is not a free retry
        if (!force && await keyHeld(member)) return sent;
        if (!force) await d.triedGroupCtl(id, now);
        final edit = fr?.edit;
        final emoji = fr?.emoji;
        final wrapped =
            wr ??
            await wrapMessage(
              '',
              groupId: groupId,
              groupControl: gc,
              unsend: un,
              edit: edit == null
                  ? null
                  : EditFrame(targetUid: fr!.uid, newText: edit),
              reaction: emoji == null
                  ? null
                  : ReactionFrame(targetUid: fr!.uid, emoji: emoji),
              sender: _mySender(),
              // when it was queued
              writtenAt: (r['since'] as num?)?.toInt(),
            );
        if (!await _sendGroupEnvelope(groupId, member, wrapped)) {
          final what =
              gc?.type ??
              (un != null
                  ? 'unsend'
                  : wr != null
                  ? 'frame'
                  : (edit != null ? 'edit' : 'reaction'));
          dlog('group ctl $what to $member: waits');
          return false;
        }
        await d.dropGroupCtl(id);
        sent = true;
      }
    } catch (e) {
      dlog('group ctl: ${e.runtimeType}');
      return false;
    }
    // what was held back behind the controls goes now
    if (sent) {
      try {
        if (await d.groupOwedDueNow(member) > 0) unawaited(_drainGroupOwed());
      } catch (e) {
        dlog('grp owed: ${e.runtimeType}');
      }
    }
    return true;
  }

  Future<bool> _frameStillOwed(
    HaloDb d,
    String groupId,
    String member,
    String uid,
  ) async {
    if (!await d.groupExists(groupId)) return false;
    if (!(await d.getGroupMembers(groupId)).contains(member)) return false;
    return d.messageExists(uid);
  }

  // an ended group's words for older versions go once it went from here
  // too, as its end does
  Future<bool> _wrappedStillOwed(
    HaloDb d,
    String groupId,
    String member,
    String wrapped,
  ) async {
    if (!await d.groupExists(groupId)) return unwrapMessage(wrapped).endNotice;
    return (await d.getGroupMembers(groupId)).contains(member);
  }

  // a leave goes once the group went from here; a remove to the member it
  // takes out too; anything else only to a member of a group still here
  Future<bool> _ctlStillOwed(
    HaloDb d,
    String groupId,
    String member,
    GroupControl gc,
  ) async {
    final here = await d.groupExists(groupId);
    if (gc.type == 'leave') return !here;
    // an end goes to the members it was queued for, the group deleted here
    // after it or not
    if (!here) return gc.type == 'end';
    if ((await d.getGroupMembers(groupId)).contains(member)) return true;
    return gc.type == 'remove' && (gc.members?.contains(member) ?? false);
  }

  // everyone a group frame of ours goes to. in a room this phone is its
  // room key, which takes none
  Future<List<String>> _othersIn(
    HaloDb d,
    String groupId, [
    List<String>? members,
  ]) async {
    final room = await _roomOf(groupId, d);
    return [
      for (final m in members ?? await d.getGroupMembers(groupId))
        if (m != myId && m != room?.pub) m,
    ];
  }

  // one group message to [to], the members it missed back. a member still
  // to get a control of the group gets that first, and is missed while it
  // cannot
  Future<List<String>> _fanOut(
    HaloDb d,
    String groupId,
    List<String> to,
    String wrapped,
  ) async {
    final waiting = await d.groupCtlWaiting(groupId);
    Future<bool> one(String m) async {
      if (waiting.contains(m) && !await _ctlLane(d, groupId, m, force: true)) {
        return false;
      }
      return _sendGroupEnvelope(groupId, m, wrapped);
    }

    final ok = await Future.wait([for (final m in to) one(m)]);
    return [
      for (final (i, m) in to.indexed)
        if (!ok[i]) m,
    ];
  }

  // [gc] to each of [to], or everyone else in the group, through the lanes.
  // kept until it goes: the route can be down, or tor still starting
  Future<void> _queueControl(
    String groupId,
    GroupControl gc, {
    List<String>? to,
    HaloDb? on,
  }) async {
    final d = on ?? _ownerOf(groupId);
    await d.queueGroupCtl(
      groupId,
      await _othersIn(d, groupId, to),
      gc,
      now: DateTime.now().millisecondsSinceEpoch,
    );
    // the first try goes now, whatever the route says
    if (!haloWiping && !everydayHeld) unawaited(_drainGroupCtl());
  }
}
