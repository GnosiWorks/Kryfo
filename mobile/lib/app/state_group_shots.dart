// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: a group's screenshot block, set by its admin, and what each
// member's phone understands (group_shots.dart, typing.dart)

part of '../main.dart';

/// a hidden group's answers to its admin wait this long each, one after
/// another, so a vault's opening is no burst on the wire
@visibleForTesting
Duration Function() groupCapsGap = () =>
    Duration(seconds: 120 + Random.secure().nextInt(28 * 60));

/// the admin's word on a group's block goes at most this often: the
/// newest state once the time is up
@visibleForTesting
Duration groupShotsEvery = const Duration(minutes: 5);

/// the clock and the timer the block's pace reads, for tests
@visibleForTesting
int Function() groupShotsNow = () => DateTime.now().millisecondsSinceEpoch;
@visibleForTesting
Timer Function(Duration, void Function()) groupShotsTimer = Timer.new;

// what the block's sends keep in memory, per app
class _ShotsPace {
  // admins this phone already told what it understands, by a caps control
  // or a 1:1 frame since the start
  final told = <String>{};
  // hidden groups' answers, sent one at a time
  final later = <({HaloDb db, String groupId, String admin, int at})>[];
  Timer? laterRun;
  // per group: when its word last went, what it said, and the wait for
  // the newest
  final sentAt = <String, int>{};
  final sent = <String, GroupShotsWord>{};
  final waiting = <String, Timer>{};
}

final _shotsPaces = Expando<_ShotsPace>();

extension AppStateGroupShots on AppState {
  _ShotsPace get _pace => _shotsPaces[this] ??= _ShotsPace();

  // a 1:1 frame to [peer] carries this phone's list: they know it now
  void _toldCaps(String peer) => _pace.told.add(peer);

  /// the group's switch, its admin's alone. on goes to every member and
  /// blocks on each updated phone at once; the group says it is on for
  /// everyone once every member's app can. off goes at once. in a decoy it
  /// stays on this phone and is on for everyone from the start
  Future<void> setGroupShots(String groupId, bool on) async {
    if (linkedRole) throw const GroupOnPhone();
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
    // the admin's own turn goes at once
    await _broadcastShots(d, groupId, now: true);
    if (on && !all) await _nudgeGroupShots(d, groupId, members);
  }

  // the members not heard from get the admin's words once each, as a
  // message their older app shows, never again on a later turn. this
  // version drops it
  Future<void> _nudgeGroupShots(
    HaloDb d,
    String groupId,
    List<String> members,
  ) async {
    try {
      final caps = await d.capsOfPeople(members);
      final nudged = await d.shotsNudged(groupId);
      final to = [
        for (final m in await _othersIn(d, groupId, members))
          if (!groupShotsCan(caps, m) && !nudged.contains(m)) m,
      ];
      if (to.isEmpty) return;
      await d.noteShotsNudged(groupId, to);
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
        // one sealed while the vault was shut waits its turn, as the
        // opening's own answers do
        if (_unsealing && !identical(db, live)) {
          await _capsLater(db, groupId, sender, at: s.at);
        } else {
          await _answerCaps(db, groupId, sender, at: s.at);
        }
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
    _pace.told.add(admin);
    await _queueControl(
      groupId,
      const GroupControl(type: 'caps'),
      to: [admin],
      on: db,
    );
  }

  // a hidden group's answer: none when its admin already knows this
  // phone's list from elsewhere, else one at a time after a random wait,
  // so nothing on the wire ties the vault's opening to the group
  Future<void> _capsLater(
    HaloDb db,
    String groupId,
    String admin, {
    required int at,
  }) async {
    if (db.container.quiet || admin == myId) return;
    if (_pace.told.contains(admin) || await live.capsToldVia(admin)) {
      await db.shotsTold(groupId, at);
      return;
    }
    final p = _pace;
    p.later.removeWhere((x) => identical(x.db, db) && x.groupId == groupId);
    p.later.add((db: db, groupId: groupId, admin: admin, at: at));
    _runLater();
  }

  void _runLater() {
    final p = _pace;
    if (p.laterRun != null || p.later.isEmpty) return;
    p.laterRun = Timer(groupCapsGap(), () async {
      if (p.later.isEmpty) {
        p.laterRun = null;
        return;
      }
      final x = p.later.removeAt(0);
      // the vault shut meanwhile: its answers wait for the next opening
      if (!identical(_openVault, x.db)) {
        p.later.removeWhere((y) => identical(y.db, x.db));
      } else {
        try {
          final s = await x.db.groupShotsOf(x.groupId);
          final told =
              p.told.contains(x.admin) || await live.capsToldVia(x.admin);
          if (told) {
            await x.db.shotsTold(x.groupId, x.at);
          } else if (s.known && !s.ended && s.told < x.at) {
            await _answerCaps(x.db, x.groupId, x.admin, at: x.at);
          }
        } catch (e) {
          dlog('caps: a later answer not sent (${e.runtimeType})');
        }
      }
      p.laterRun = null;
      _runLater();
    });
  }

  @visibleForTesting
  int get capsLaterForTest => _pace.later.length;

  @visibleForTesting
  bool get capsLaterRunningForTest => _pace.laterRun != null;

  // a group of someone else's that this phone just joined, or joined
  // again: its admin hears what this app can
  Future<void> _capsOnJoin(String groupId, String admin, HaloDb db) async {
    try {
      final s = await db.groupShotsOf(groupId);
      if (s.room || s.ended) return;
      if (_unsealing && !identical(db, live)) {
        await _capsLater(db, groupId, admin, at: max(s.at, 1));
      } else {
        await _answerCaps(db, groupId, admin, at: max(s.at, 1));
      }
    } catch (e) {
      dlog('group shots: no caps on a join (${e.runtimeType})');
    }
  }

  // what a group frame says of its sender's phone, kept on their row,
  // a member stub's too. a 1:1 frame's is the typing side's to keep
  // (_takeCaps); either may change who the groups this phone runs wait
  // for. a room key's says nothing: room frames carry no list
  Future<void> _memberCaps(
    String sender,
    UnwrappedMessage env,
    HaloDb db, {
    required bool oneToOneMoved,
  }) async {
    if (isDevId(sender) || looksLikeRoomKey(sender)) return;
    final counts = AppState._dataFrame(env) && env.msgUid != null;
    if (env.caps == null && !counts) return;
    try {
      // a 1:1 frame counts again only when it changed their list
      final moved = env.groupId == null
          ? oneToOneMoved
          : await db.takeMemberCaps(
              sender,
              caps: env.caps,
              counts: counts,
              written: env.writtenAt,
            );
      if (!moved) return;
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
    // the phone runs its groups' block: a linked device sends no word of it
    if (d.container.quiet || linkedRole) return;
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
        await _broadcastShots(d, g);
      }
      if (moved) await refreshGroups();
    } catch (e) {
      dlog('group shots: not counted again (${e.runtimeType})');
    }
  }

  // the group's word to every other member. one that moves again soon
  // after waits for the end of [groupShotsEvery] and goes as the newest
  // state, and one that moved back to what last went sends nothing: a
  // member flipping their list cannot make the admin's phone flood the
  // group. [now]: the admin's own tap
  Future<void> _broadcastShots(
    HaloDb d,
    String groupId, {
    bool now = false,
  }) async {
    final p = _pace;
    final key = '${d.container.id}|$groupId';
    final t = groupShotsNow();
    final last = p.sentAt[key];
    final every = groupShotsEvery.inMilliseconds;
    if (!now && last != null && t - last < every) {
      p.waiting[key] ??= groupShotsTimer(
        Duration(milliseconds: last + every - t),
        () {
          p.waiting.remove(key);
          unawaited(_broadcastShots(d, groupId));
        },
      );
      return;
    }
    p.waiting.remove(key)?.cancel();
    try {
      final s = await d.groupShotsOf(groupId);
      if (!s.known || s.room) return;
      final was = p.sent[key];
      if (!now && was != null && was.on == s.on && was.all == s.all) return;
      p.sentAt[key] = t;
      p.sent[key] = s.word;
      await _queueControl(
        groupId,
        GroupControl(type: 'shots', shots: s.word),
        on: d,
      );
    } catch (e) {
      dlog('group shots: word not sent (${e.runtimeType})');
    }
  }

  // once after the update, each group this phone is in tells its admin
  // what this app can, and a state that waits on it is answered. a
  // decoy's never; a hidden group's once the vault opens, never while it
  // is shut, and then only as _capsLater lets it
  Future<void> _announceCaps(HaloDb d) async {
    if (d.container.quiet) return;
    try {
      for (final g in await d.capsUntold()) {
        if (!(await d.getGroupMembers(g.groupId)).contains(g.admin)) {
          // an admin who left hears nothing more
          await d.shotsTold(g.groupId, 1);
          continue;
        }
        // a hidden group's waits, or goes not at all when its admin knows
        if (identical(d, live)) {
          await _answerCaps(d, g.groupId, g.admin, at: g.at);
        } else {
          await _capsLater(d, g.groupId, g.admin, at: g.at);
        }
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
