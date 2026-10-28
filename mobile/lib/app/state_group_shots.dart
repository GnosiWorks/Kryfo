// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: a group's screenshot block, set by its admin, and what each
// member's phone understands (group_shots.dart, typing.dart)

part of '../main.dart';

extension AppStateGroupShots on AppState {
  /// the group's switch, its admin's alone. on goes to every member and
  /// blocks on each updated phone at once; the group says it is on for
  /// everyone once every member's app can. off goes at once. in a decoy it
  /// stays on this phone and is on for everyone from the start
  Future<void> setGroupShots(String groupId, bool on) async {
    final d = session.groupDb(groupId);
    final row = await d.getGroup(groupId);
    final members = await d.getGroupMembers(groupId);
    if (!mayTurnGroupShots(row, sessionId, members)) return;
    final quiet = d.container.quiet;
    final all =
        quiet ||
        groupShotsAll(members, sessionId, await d.capsOfPeople(members));
    final was = (await d.groupShotsOf(groupId)).blocking;
    final word = await d.turnGroupShots(groupId, on: on, all: all);
    if (word == null) return;
    // blocking from now: what the shade still shows of the group goes
    if (!was && on) unawaited(_io.unnotify('group:$groupId'));
    _bumpChatRev('group:$groupId');
    await refreshGroups();
    // a quiet session keeps it on this phone: nothing leaves
    if (quiet || sessionQuiet) return;
    await _queueControl(
      groupId,
      GroupControl(type: 'shots', shots: word),
      on: d,
    );
    if (on && !all) await _nudgeGroupShots(d, groupId, members);
  }

  // the members not heard from get the admin's words once, as a message
  // their older app shows. this version drops it
  Future<void> _nudgeGroupShots(
    HaloDb d,
    String groupId,
    List<String> members,
  ) async {
    try {
      final caps = await d.capsOfPeople(members);
      final to = [
        for (final m in await _othersIn(d, groupId, members))
          if (!groupShotsCan(caps, m)) m,
      ];
      if (to.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final words = await wrapMessage(
        l10n.groupShotsOldNotice,
        msgUid: newMsgUid(),
        groupId: groupId,
        sender: _mySender(),
        shotsNudge: true,
        writtenAt: now,
      );
      await d.queueGroupWrapped(groupId, to, words, now: now);
      if (!haloWiping && !everydayHeld) unawaited(_drainGroupCtl());
    } catch (e) {
      dlog('group shots: no nudge (${e.runtimeType})');
    }
  }

  /// the state the admin's group frames carry: no room's, none of a group
  /// this phone does not run
  Future<GroupShotsWord?> _groupShotsOnWire(HaloDb d, String groupId) async {
    try {
      final s = await d.groupShotsOf(groupId);
      return s.room ? null : s.word;
    } catch (e) {
      dlog('group shots: not read for the wire (${e.runtimeType})');
      return null;
    }
  }

  // a word from [sender] on the group's block: taken from its admin on
  // record who is still in it, newest stamp first. a state still waiting
  // on someone is answered with this app's bits, once per stamp
  Future<void> _takeGroupShots(
    String groupId,
    String sender,
    GroupShotsWord w,
    HaloDb db,
  ) async {
    try {
      final row = await db.getGroup(groupId);
      final members = await db.getGroupMembers(groupId);
      if (!groupShotsFrom(sender, row, members)) return;
      final was = (await db.groupShotsOf(groupId)).blocking;
      if (!await db.takeGroupShots(groupId, w)) return;
      final s = await db.groupShotsOf(groupId);
      // blocking from now: what the shade still shows of the group goes
      if (!was && s.blocking) unawaited(_io.unnotify('group:$groupId'));
      _bumpChatRev('group:$groupId');
      notifyListeners();
      await refreshGroups();
      if (groupShotsOwesCaps(s)) {
        await _answerCaps(db, groupId, sender, at: s.at);
      }
    } catch (e) {
      dlog('group shots: not taken (${e.runtimeType})');
    }
  }

  // this app's bits to the group's admin, through its lane. the envelope
  // carries them; the control says nothing more
  Future<void> _answerCaps(
    HaloDb db,
    String groupId,
    String admin, {
    required int at,
  }) async {
    if (db.container.quiet || admin == myId) return;
    await db.shotsTold(groupId, at);
    await _queueControl(
      groupId,
      const GroupControl(type: 'caps'),
      to: [admin],
      on: db,
    );
  }

  // a group of someone else's that this phone just joined, or joined
  // again: its admin hears what this app can
  Future<void> _capsOnJoin(String groupId, String admin, HaloDb db) async {
    try {
      final s = await db.groupShotsOf(groupId);
      if (s.room || s.ended) return;
      await _answerCaps(db, groupId, admin, at: max(s.at, 1));
    } catch (e) {
      dlog('group shots: no caps on a join (${e.runtimeType})');
    }
  }

  // what a group frame says of its sender's phone, kept on their row,
  // a member stub's too. a 1:1 frame's is the typing side's to keep
  // (_takeCaps); either may change who the groups this phone runs wait
  // for. a room key's says nothing: room frames carry no list
  Future<void> _memberCaps(String sender, UnwrappedMessage env, HaloDb db) async {
    if (isDevId(sender) || looksLikeRoomKey(sender)) return;
    final counts = AppState._dataFrame(env) && env.msgUid != null;
    if (env.caps == null && !counts) return;
    try {
      if (env.groupId != null &&
          !await db.takeMemberCaps(
            sender,
            caps: env.caps,
            counts: counts,
            written: env.writtenAt,
          )) {
        return;
      }
      await _shotsRecount(db, member: sender);
    } catch (e) {
      dlog('caps: not taken (${e.runtimeType})');
    }
  }

  // who can, worked out again for the groups this phone runs whose block
  // is on: [groupId] alone, those [member] is in, or every one. a change
  // goes to everyone in the group. a decoy's groups are on for everyone
  // from the start
  Future<void> _shotsRecount(
    HaloDb d, {
    String? groupId,
    String? member,
  }) async {
    if (d.container.quiet) return;
    try {
      final ids = groupId != null
          ? [groupId]
          : await d.shotsRunHere(myId, member: member);
      var moved = false;
      for (final g in ids) {
        final members = await d.getGroupMembers(g);
        if (!mayTurnGroupShots(await d.getGroup(g), myId, members)) continue;
        final all = groupShotsAll(members, myId, await d.capsOfPeople(members));
        final word = await d.moveGroupShotsAll(g, all: all);
        if (word == null) continue;
        moved = true;
        _bumpChatRev('group:$g');
        await _queueControl(
          g,
          GroupControl(type: 'shots', shots: word),
          on: d,
        );
      }
      if (moved) await refreshGroups();
    } catch (e) {
      dlog('group shots: not counted again (${e.runtimeType})');
    }
  }

  // once after the update, each group this phone is in tells its admin
  // what this app can. a decoy's never; a hidden group's once the vault
  // opens, never while it is shut
  Future<void> _announceCaps(HaloDb d) async {
    if (d.container.quiet) return;
    try {
      for (final g in await d.capsUntold()) {
        if (!(await d.getGroupMembers(g.groupId)).contains(g.admin)) {
          // an admin who left hears nothing more
          await d.shotsTold(g.groupId, 1);
          continue;
        }
        await _answerCaps(d, g.groupId, g.admin, at: 1);
      }
    } catch (e) {
      dlog('caps: not announced (${e.runtimeType})');
    }
  }

  // a vault just opened: what came for its groups while it was shut is in,
  // so its admin's groups count again, and its groups tell their admins
  Future<void> _groupShotsAtOpen(HaloDb v) async {
    await _announceCaps(v);
    await _shotsRecount(v);
  }

  @visibleForTesting
  Future<void> announceCapsForTest(HaloDb d) => _announceCaps(d);

  @visibleForTesting
  Future<void> groupShotsAtOpenForTest(HaloDb v) => _groupShotsAtOpen(v);
}
