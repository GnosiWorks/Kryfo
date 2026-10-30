// SPDX-License-Identifier: GPL-3.0-or-later
// group member pairs through the hello (identity v4 4.3): a member's roster
// invite goes to the admin inside their 1:1 session, the admin passes the
// members' ones on, and a pair with no session forms by a hello from the
// smaller key to the other's roster invite, on v4 addresses from its first
// frame. hidden groups, rooms and members who sent none (0.5.x) keep the
// old way

part of '../main.dart';

/// how long an admin waits for more roster invites before passing them on
@visibleForTesting
Duration rosterPassWait = const Duration(seconds: 20);

// the admin's passes waiting, per app and group
final _rosterPasses = Expando<Map<String, Timer>>();

/// a hellos row: a roster hello taken from that key, at most one a day
const kHelloTaken = 'taken';

/// how often a roster hello from one key is taken
const kRosterHelloEvery = Duration(days: 1);

/// whether [a] is below [b] as bytes: the smaller key says hello (3.4b)
bool keyBelow(List<int> a, List<int> b) => answerTheirs(b, a);

extension AppStateGroupHellos on AppState {
  Map<String, Timer> get _rosterTimers => _rosterPasses[this] ??= {};

  // a group whose roster invites count: the everyday side's, not a room,
  // not ended. a hidden group's, and anything in a quiet session, keep the
  // old way, so nothing ties the vault or the decoy to an invite
  Future<bool> _rosterGroup(HaloDb db, String groupId) async {
    if (sessionQuiet || !identical(db, live) || db.container.quiet) {
      return false;
    }
    final g = await db.getGroup(groupId);
    return g != null &&
        groupEndOf(g) == null &&
        await _roomOf(groupId, db) == null;
  }

  // [bytes] as a roster invite of the member with x key [x] and words
  // [words]: every reader check, not one-time, no bundle, no device list,
  // its key theirs, answered by that key, and a face, if it shows one, of
  // their words. null for any other
  LsInvite? _rosterInviteFor(
    List<int> bytes, {
    required String x,
    required String words,
  }) {
    final LsInvite inv;
    try {
      inv = readInvite(signalSession.lib, bytes);
    } catch (_) {
      return null;
    }
    if (inv.oneTime || inv.block != null || inv.deviceList != null) {
      return null;
    }
    final key = identityKeyHex(x);
    if (key == null ||
        _hexOf(inv.identity) != key ||
        _hexOf(inv.answering) != key) {
      return null;
    }
    final f = inv.face;
    if (f != null && engine.idFromEdPub(_hexOf(f)) != words) return null;
    return inv;
  }

  /// my roster invite to the admin of [groupId], in our own session: a
  /// group I just joined, or every one when it was made again. none to a
  /// hidden group's admin, or one I know on another identity
  Future<void> _tellRosterInvite(
    HaloDb db,
    String groupId,
    String admin,
  ) async {
    try {
      if (admin == myId || isDevId(admin)) return;
      if (!await _rosterGroup(db, groupId)) return;
      if (identOf(admin) != kMainIdent) return;
      final mine = await currentRosterInvite(await live.open(), kMainIdent);
      // none yet: told once the upkeep makes it
      if (mine == null) return;
      await _queueControl(
        groupId,
        GroupControl(type: 'ri', invite: base64Encode(mine.link)),
        to: [admin],
        on: db,
      );
    } catch (e) {
      dlog('roster invite: not told (${e.runtimeType})');
    }
  }

  /// my roster invite made, first or again at six months: the admin of
  /// each group I am in hears it, and the groups I run pass it on
  Future<void> _tellRosterInviteAll() async {
    if (sessionQuiet) return;
    try {
      for (final g in await live.loadGroups()) {
        final id = g['group_id'] as String;
        final admin = await live.groupAdminId(id);
        if (admin == null) continue;
        if (admin == myId) {
          await _passRosterInvites(id, mine: true);
        } else {
          await _tellRosterInvite(live, id, admin);
        }
      }
    } catch (e) {
      dlog('roster invite: groups not told (${e.runtimeType})');
    }
  }

  /// the admin's side: [sender]'s roster invite for [groupId], kept when it
  /// reads as theirs and passed on to the others a little later
  Future<void> _takeMemberRosterInvite(
    String sender,
    String groupId,
    GroupControl gc,
    HaloDb db,
  ) async {
    try {
      if (!await _rosterGroup(db, groupId)) return;
      if (await db.groupAdminId(groupId) != myId) return;
      if (!(await db.getGroupMembers(groupId)).contains(sender)) return;
      final b64 = gc.invite;
      final x = (await db.getContact(sender))?['xpub'] as String?;
      if (b64 == null || x == null) return;
      final bytes = base64Decode(b64);
      final inv = _rosterInviteFor(bytes, x: x, words: sender);
      if (inv == null) {
        dlog('roster invite: not theirs, dropped');
        return;
      }
      final kept = await keepRosterInvite(
        await db.open(),
        groupId,
        sender,
        bytes,
        id: _hexOf(inv.id),
        issued: inv.issued,
        passOn: true,
      );
      if (kept) _passRosterSoon(groupId);
    } catch (e) {
      dlog('roster invite: not taken (${e.runtimeType})');
    }
  }

  // several members joining at once are passed on in one go. a pass
  // waiting already is not put off: more coming cannot starve it
  void _passRosterSoon(String groupId) {
    if (_rosterTimers.containsKey(groupId)) return;
    _rosterTimers[groupId] = Timer(rosterPassWait, () {
      _rosterTimers.remove(groupId);
      unawaited(_passRosterInvites(groupId));
    });
  }

  /// the admin's side, to the members who sent a roster invite: each new
  /// since the last pass gets every one [groupId] holds, mine with them;
  /// the others only the ones new or made again since, and mine when it was
  /// made again ([mine]). a member who sent none (0.5.x) would not use them
  Future<void> _passRosterInvites(String groupId, {bool mine = false}) async {
    try {
      final d = live;
      if (!await _rosterGroup(d, groupId)) return;
      if (await d.groupAdminId(groupId) != myId) return;
      final file = await d.open();
      final held = await rosterInvitesIn(file, groupId);
      final members = await d.getGroupMembers(groupId);
      final fresh = <String>[];
      final had = <String>[];
      for (final m in members) {
        final r = held[m];
        if (m == myId || r == null) continue;
        (r.pushed == kRosterNew ? fresh : had).add(m);
      }
      final changed = {
        for (final r in held.values)
          if (r.pushed != kRosterPassed) r.member,
        if (mine) myId,
      };
      if (fresh.isNotEmpty || (had.isNotEmpty && changed.isNotEmpty)) {
        final parts = [
          for (final p in await _buildParticipants(
            members,
            invites: (db: d, groupId: groupId),
          ))
            if (p['ri'] != null) p,
        ];
        if (fresh.isNotEmpty) {
          await _queueControl(
            groupId,
            GroupControl(type: 'roster', participants: parts),
            to: fresh,
            on: d,
          );
        }
        final delta = [
          for (final p in parts)
            if (changed.contains(p['h'])) p,
        ];
        if (had.isNotEmpty && delta.isNotEmpty) {
          await _queueControl(
            groupId,
            GroupControl(type: 'roster', participants: delta),
            to: had,
            on: d,
          );
        }
      }
      await rosterInvitesPassed(file, groupId, [
        for (final r in held.values)
          if (r.pushed != kRosterPassed) r,
      ]);
    } catch (e) {
      dlog('roster invite: not passed on (${e.runtimeType})');
    }
  }

  /// what a stop left before it was passed on goes now
  Future<void> _passRosterOwed() async {
    if (sessionQuiet) return;
    try {
      for (final g in await rosterInvitesToPass(await live.open())) {
        if (_rosterTimers.containsKey(g)) continue;
        await _passRosterInvites(g);
      }
    } catch (e) {
      dlog('roster invite: owed not passed on (${e.runtimeType})');
    }
  }

  /// a member's side: the roster invites an admin's roster gives the other
  /// members of [groupId], each kept when it reads as that member's, then
  /// the hellos this phone owes them
  Future<void> _takeRosterInvites(
    String groupId,
    List<Map<String, String>>? parts,
    HaloDb db, {
    required Map<String, String> seats,
    required Set<String> out,
  }) async {
    if (parts == null || !await _rosterGroup(db, groupId)) return;
    try {
      final members = await db.getGroupMembers(groupId);
      final file = await db.open();
      for (final p in parts) {
        final h = p['h'];
        final x = p['x'];
        final ri = p['ri'];
        if (h == null || x == null || ri == null) continue;
        if (h == myId || out.contains(h) || devCardClaim(id: h, xPub: x)) {
          continue;
        }
        final id = seats[h] ?? h;
        // one I know on another identity keeps the old way
        if (!members.contains(id) || identOf(id) != kMainIdent) continue;
        final row = await db.getContact(id);
        if ((row?['xpub'] as String?)?.toLowerCase() != x.toLowerCase()) {
          continue;
        }
        final Uint8List bytes;
        try {
          bytes = base64Decode(ri);
        } catch (_) {
          continue;
        }
        final inv = _rosterInviteFor(bytes, x: x, words: h);
        if (inv == null) continue;
        await keepRosterInvite(
          file,
          groupId,
          id,
          bytes,
          id: _hexOf(inv.id),
          issued: inv.issued,
        );
      }
    } catch (e) {
      dlog('roster invite: roster not taken (${e.runtimeType})');
    }
    await _rosterHellos(groupId);
  }

  /// the hellos owed to the members of [groupId], or of every group here:
  /// to each with a roster invite, no session and a key above mine
  Future<void> _rosterHellos([String? groupId]) async {
    if (sessionQuiet || !signalSession.ready) return;
    try {
      final file = await live.open();
      final groups = groupId != null
          ? [groupId]
          : [for (final g in await live.loadGroups()) g['group_id'] as String];
      var owed = false;
      for (final g in groups) {
        if (!await _rosterGroup(live, g)) continue;
        for (final r in (await rosterInvitesIn(file, g)).values) {
          if (await _oweRosterHello(file, r)) owed = true;
        }
      }
      if (owed) unawaited(sendHellosOwed());
    } catch (e) {
      dlog('roster invite: hellos not owed (${e.runtimeType})');
    }
  }

  // a hello owed to [r]'s member, true when one is: no session with them,
  // my key the smaller (3.4b), nothing between us waiting already. a
  // roster invite past its life takes none, nor one I know on another
  // identity
  Future<bool> _oweRosterHello(DatabaseExecutor file, RosterInviteRow r) async {
    if (r.member == myId || isDevId(r.member)) return false;
    if (identOf(r.member) != kMainIdent) return false;
    final LsInvite inv;
    try {
      inv = readInvite(signalSession.lib, r.invite);
    } catch (_) {
      return false;
    }
    final key = inv.identity;
    if (!keyBelow(signalSession.identity.public, key)) return false;
    final keyHex = _hexOf(key);
    if (await blockedAnywhere(r.member) ||
        await _keyBlockedHere(keyHex.substring(2)) ||
        await hasSessionWith(r.member)) {
      return false;
    }
    final waiting = await file.query(
      'hellos',
      columns: ['way'],
      where: 'ident = ? AND peer = ?',
      whereArgs: [kMainIdent, keyHex],
      limit: 1,
    );
    if (waiting.isNotEmpty) return false;
    await live.oweHello(keyHex, _hexOf(inv.id), _hexOf(inv.firstContact));
    return true;
  }

  /// [id] has no session and a group gave their roster invite: the hello
  /// makes the pair, no bundle swap does. one owed again if it is due.
  /// the newest past its life makes none: the old way runs
  Future<bool> _rosterPairWaits(String id, HaloDb? on) async {
    if (sessionQuiet || !identical(on, live)) return false;
    try {
      final file = await live.open();
      final rows = [
        for (final r in await file.query(
          'roster_invites',
          where: 'member = ?',
          whereArgs: [id],
        ))
          RosterInviteRow.of(r),
      ]..sort((a, b) => b.issued.compareTo(a.issued));
      if (rows.isEmpty) return false;
      try {
        readInvite(signalSession.lib, rows.first.invite);
      } catch (_) {
        return false;
      }
      if (signalSession.ready && await _oweRosterHello(file, rows.first)) {
        unawaited(sendHellosOwed());
      }
      return true;
    } catch (e) {
      dlog('roster invite: not read (${e.runtimeType})');
      return false;
    }
  }

  /// whether a hello to invite [answers] goes to a group member's roster
  /// invite: taken there without a proof of work (4.3)
  Future<bool> _rosterHelloTo(DatabaseExecutor file, String answers) async =>
      (await rosterInviteHolders(file, answers)).isNotEmpty;

  /// the group here naming [id], on identity key [keyHex], as one of its
  /// members beside me: a hello from them at my roster invite is taken
  /// without a request. null for anyone else, and one I know on another
  /// identity
  Future<String?> _rosterMemberOf(String id, String keyHex) async {
    if (identOf(id) != kMainIdent) return null;
    final row = await live.getContact(id);
    if (row == null ||
        identityKeyHex(row['xpub'] as String?) != keyHex ||
        (row['blocked'] as int? ?? 0) == 1) {
      return null;
    }
    for (final g in await live.loadGroups()) {
      final gid = g['group_id'] as String;
      if (!await _rosterGroup(live, gid)) continue;
      final members = await live.getGroupMembers(gid);
      if (members.contains(id) && members.contains(myId)) return gid;
    }
    return null;
  }

  /// whether a live group of mine names a member on identity key [keyHex]
  /// beside me, by their row's key alone: a hello at my roster invite from
  /// anyone else costs one parse
  Future<bool> _rosterKeyIsMember(String keyHex) async {
    final file = await live.open();
    final ids = <String>{};
    // xpub as written (lowercase), ikey for any row claimed
    for (final (col, v) in [
      ('xpub', keyHex.substring(2).toLowerCase()),
      ('ikey', keyHex),
    ]) {
      for (final r in await file.query(
        'contacts',
        columns: ['halo_id'],
        where: '$col = ? AND blocked = ?',
        whereArgs: [v, 0],
      )) {
        ids.add(r['halo_id'] as String);
      }
    }
    if (ids.isEmpty) return false;
    for (final g in await live.loadGroups()) {
      final gid = g['group_id'] as String;
      if (!await _rosterGroup(live, gid)) continue;
      final members = await live.getGroupMembers(gid);
      if (members.contains(myId) && ids.any(members.contains)) return true;
    }
    return false;
  }

  /// whether a roster hello from [keyHex] was taken in the last day: one a
  /// day is, so no member makes me remake our session without end. one
  /// taken ahead of now is from a clock set back since: stale
  Future<bool> _rosterHelloAgain(DatabaseExecutor file, String keyHex) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (op, at) in [
      ('<', now - kRosterHelloEvery.inMilliseconds),
      ('>', now),
    ]) {
      await file.delete(
        'hellos',
        where: 'way = ? AND at $op ?',
        whereArgs: [kHelloTaken, at],
      );
    }
    return (await file.query(
      'hellos',
      columns: ['at'],
      where: 'ident = ? AND way = ? AND peer = ?',
      whereArgs: [kMainIdent, kHelloTaken, keyHex],
      limit: 1,
    )).isNotEmpty;
  }

  Future<void> _rosterHelloTaken(DatabaseExecutor file, String keyHex) =>
      file.insert('hellos', {
        'ident': kMainIdent,
        'way': kHelloTaken,
        'peer': keyHex,
        'invite_id': '0' * 32,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// a member's hello at my roster invite, answered as an accept answers
  /// one: the session from their one-time invite, the pair seeded, and a
  /// first frame to their one-time address. they stay out of my contacts
  Future<void> _answerRosterHello(
    String id,
    String groupId,
    String keyHex,
  ) async {
    try {
      await answerHello(id);
    } catch (e) {
      dlog('roster hello: not answered (${e.runtimeType})');
      // no request is left of it: a hello of theirs a day on tries again
      try {
        await (await live.open()).delete(
          'hellos',
          where: 'ident = ? AND way = ? AND peer = ?',
          whereArgs: [kMainIdent, kHelloIn, keyHex],
        );
      } catch (_) {}
      return;
    }
    if (!await hasSessionWith(id)) return;
    unawaited(subscribePeer(id, fresh: true));
    await _queueControl(
      groupId,
      const GroupControl(type: 'pair'),
      to: [id],
      on: live,
    );
  }

  /// a member pair's first frame, come as an opener at my hello's one-time
  /// invite: one frame back, so they hear me on the pair's own addresses
  Future<void> _answerPair(
    String sender,
    String groupId,
    HaloDb db, {
    required bool opener,
  }) async {
    if (!opener || !await _rosterGroup(db, groupId)) return;
    final members = await db.getGroupMembers(groupId);
    if (!members.contains(sender) || !members.contains(myId)) return;
    await _queueControl(
      groupId,
      const GroupControl(type: 'pair'),
      to: [sender],
      on: db,
    );
  }

  @visibleForTesting
  Future<void> groupControlForTest(
    String sender,
    UnwrappedMessage env,
    HaloDb db, {
    bool opener = false,
  }) => _applyGroupControl(sender, env, db, opener: opener);

  @visibleForTesting
  Future<void> passRosterForTest(String groupId) => _passRosterInvites(groupId);

  @visibleForTesting
  Future<void> rosterHellosForTest() => _rosterHellos();

  @visibleForTesting
  Future<bool> rosterPairWaitsForTest(String id) => _rosterPairWaits(id, live);
}
