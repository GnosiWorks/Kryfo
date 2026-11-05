// SPDX-License-Identifier: GPL-3.0-or-later
// people on an older Kryfo (identity v4 11 step 7, 12). 0.6 starts no
// classic session, so a hello to a v3 card waits until its owner runs 0.6:
// their chat says so, what is written there waits, and the hello goes again
// now and then, so an owner who updates hears it. a group says which
// members no session reaches here

part of '../main.dart';

/// a hellos row: the owner of a v3 card a hello went to. once 1: the card
/// has no post-quantum prekey, so it was made on 0.5.x; 0: it may be
/// either. at: the add, went_at: the last hello owed
const kHelloOld = 'old';

/// how long a hello to a card that may be either waits for its answer
/// before the chat says they may need to update
const kOldPeerWait = Duration(minutes: 10);

/// the hello again while they have not answered: twice a day the first
/// week, daily after. the receiver keeps the newest one from a key
const kOldPeerHelloSoon = Duration(hours: 12);
const kOldPeerHelloLater = Duration(days: 1);
const kOldPeerSoonFor = Duration(days: 7);

const _kNoInvite = '00000000000000000000000000000000';

/// a chat with someone added by a hello, while no session is up: [waits],
/// a hello of mine is owed or out; [update], the line saying they may need
/// to update shows; [updateAt], when it will if no answer came
typedef HelloWait = ({bool waits, bool update, int? updateAt});

const HelloWait kNoHelloWait = (waits: false, update: false, updateAt: null);

/// whether a card was made on 0.5.x: no post-quantum prekey
bool classicCard(String? card) =>
    card != null && bundleFault(card) is ClassicRefused;

extension AppStateOldPeers on AppState {
  /// a hello went to the owner of a v3 card, identity key [ownerHex], at
  /// [fc]. [classic]: the card says 0.5.x, and keeps saying it on a re-add
  Future<void> noteOldPeer(
    String ownerHex,
    String fc, {
    required bool classic,
    int? nowMs,
  }) async {
    if (sessionQuiet) return;
    try {
      final db = await live.open();
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      final was = await db.query(
        'hellos',
        columns: ['once'],
        where: 'ident = ? AND way = ? AND peer = ?',
        whereArgs: [kMainIdent, kHelloOld, ownerHex],
        limit: 1,
      );
      final sure =
          classic || (was.isNotEmpty && (was.first['once'] as int? ?? 0) == 1);
      await db.insert('hellos', {
        'ident': kMainIdent,
        'way': kHelloOld,
        'peer': ownerHex,
        'invite_id': _kNoInvite,
        'fc': fc,
        'at': now,
        'went_at': now,
        'once': sure ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      dlog('old peer: not noted (${e.runtimeType})');
    }
  }

  /// where [peer]'s chat stands while a hello of mine waits for them
  Future<HelloWait> helloWaitOf(String peer, {int? nowMs}) async {
    if (sessionQuiet || isDevId(peer) || !signalSession.ready) {
      return kNoHelloWait;
    }
    try {
      final row = await live.getContact(peer);
      if (row == null || (row['blocked'] as int? ?? 0) == 1) {
        return kNoHelloWait;
      }
      final key =
          row['ikey'] as String? ?? identityKeyHex(row['xpub'] as String?);
      if (key == null) return kNoHelloWait;
      final db = await live.open();
      if (await hasSessionWith(peer)) {
        await db.delete(
          'hellos',
          where: 'ident = ? AND way = ? AND peer = ?',
          whereArgs: [kMainIdent, kHelloOld, key],
        );
        return kNoHelloWait;
      }
      final rows = await db.query(
        'hellos',
        columns: ['way', 'at', 'once'],
        where: 'ident = ? AND peer = ? AND way IN (?, ?, ?)',
        whereArgs: [kMainIdent, key, kHelloWant, kHelloOut, kHelloOld],
      );
      if (rows.isEmpty) return kNoHelloWait;
      final old = rows.where((r) => r['way'] == kHelloOld).firstOrNull;
      if (old == null) return (waits: true, update: false, updateAt: null);
      if ((old['once'] as int? ?? 0) == 1) {
        return (waits: true, update: true, updateAt: null);
      }
      final due = (old['at'] as int) + kOldPeerWait.inMilliseconds;
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      return now >= due
          ? (waits: true, update: true, updateAt: null)
          : (waits: true, update: false, updateAt: due);
    } catch (e) {
      dlog('old peer: not read (${e.runtimeType})');
      return kNoHelloWait;
    }
  }

  /// a hello owed again to each v3 card's owner who has not answered, as
  /// it falls due. the newest one-time invite out to them stays for an
  /// answer on its way, older ones go
  Future<void> _oweOldPeerHellos(Database db, int now) async {
    final olds = await db.query(
      'hellos',
      where: 'ident = ? AND way = ?',
      whereArgs: [kMainIdent, kHelloOld],
    );
    for (final o in olds) {
      final peer = o['peer'] as String;
      final c = await db.query(
        'contacts',
        columns: ['halo_id', 'blocked'],
        where: 'ikey = ?',
        whereArgs: [peer],
        limit: 1,
      );
      if (c.isEmpty ||
          (c.first['blocked'] as int? ?? 0) == 1 ||
          await hasSessionWith(c.first['halo_id'] as String)) {
        await db.delete(
          'hellos',
          where: 'ident = ? AND way = ? AND peer = ?',
          whereArgs: [kMainIdent, kHelloOld, peer],
        );
        continue;
      }
      final at = o['at'] as int;
      final went = o['went_at'] as int? ?? at;
      final every = now - at < kOldPeerSoonFor.inMilliseconds
          ? kOldPeerHelloSoon
          : kOldPeerHelloLater;
      if (now - went < every.inMilliseconds) continue;
      final owed = await db.query(
        'hellos',
        columns: ['peer'],
        where: 'ident = ? AND way = ? AND peer = ?',
        whereArgs: [kMainIdent, kHelloWant, peer],
        limit: 1,
      );
      if (owed.isEmpty) {
        await _dropOlderHellosOut(db, peer);
        await db.insert('hellos', {
          'ident': kMainIdent,
          'way': kHelloWant,
          'peer': peer,
          'invite_id': _kNoInvite,
          'fc': o['fc'],
          'at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await db.update(
        'hellos',
        {'went_at': now},
        where: 'ident = ? AND way = ? AND peer = ?',
        whereArgs: [kMainIdent, kHelloOld, peer],
      );
    }
  }

  // every hello of mine out to [peer] but the newest: its one-time invite,
  // its keys and its address go
  Future<void> _dropOlderHellosOut(Database db, String peer) async {
    final out = await db.query(
      'hellos',
      columns: ['invite_id'],
      where: 'ident = ? AND way = ? AND peer = ?',
      whereArgs: [kMainIdent, kHelloOut, peer],
      orderBy: 'at DESC',
    );
    for (final r in out.skip(1)) {
      final id = r['invite_id'] as String;
      final inv = await inviteOf(db, kMainIdent, id);
      if (inv != null) await spendOneTime(db, signalSession, inv);
      await engine.unsubscribeFcKey(kMainIdent, id);
      await db.delete(
        'hellos',
        where: 'ident = ? AND way = ? AND invite_id = ?',
        whereArgs: [kMainIdent, kHelloOut, id],
      );
    }
  }

  // they answered a hello of mine: their chat starts, and what waited for
  // them goes now rather than at the outbox's next gap
  Future<void> _helloAnswered(String peer) async {
    try {
      final row = await live.getContact(peer);
      final key =
          row?['ikey'] as String? ?? identityKeyHex(row?['xpub'] as String?);
      if (key != null) {
        final db = await live.open();
        await db.delete(
          'hellos',
          where: 'ident = ? AND way = ? AND peer = ?',
          whereArgs: [kMainIdent, kHelloOld, key],
        );
      }
      _outboxNextAt.removeWhere((uid, _) => _outboxPeer[uid] == peer);
      _outboxTries.removeWhere((uid, _) => _outboxPeer[uid] == peer);
      _bumpChatRev(peer);
      notifyListeners();
      await drainOutbox();
    } catch (e) {
      dlog('old peer: answer not taken (${e.runtimeType})');
    }
  }

  /// the members of [groupId] no session of mine reaches and none can form
  /// with: no roster invite, nothing that says they run 0.6, in the group a
  /// while. an older Kryfo, until they update
  Future<List<String>> groupWaitsForUpdate(String groupId, {int? nowMs}) async {
    if (sessionQuiet || !signalSession.ready) return const [];
    try {
      final d = session.groupDb(groupId);
      if (!await _rosterGroup(d, groupId)) return const [];
      final file = await d.open();
      final me = await meIn(groupId);
      final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      // a member's own join where it is kept, else the group's here
      final since = await d.groupJoinedAt(groupId) ?? now;
      final joinedOf = {
        for (final r in await file.query(
          'group_members',
          columns: ['halo_id', 'joined_at'],
          where: 'group_id = ?',
          whereArgs: [groupId],
        ))
          r['halo_id'] as String: (r['joined_at'] as num?)?.toInt(),
      };
      final out = <String>[];
      for (final id in await d.getGroupMembers(groupId)) {
        if (id == me || id == sessionId || isDevId(id)) continue;
        final joined = joinedOf[id] ?? since;
        if (now - joined < kOldPeerWait.inMilliseconds) continue;
        if (await hasSessionWith(id)) continue;
        final invites = await file.query(
          'roster_invites',
          columns: ['member'],
          where: 'member = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (invites.isNotEmpty) continue;
        final row = await d.getContact(id);
        if (row != null && (row['blocked'] as int? ?? 0) == 1) continue;
        if (!olderKryfo(row?['caps'] as String?)) continue;
        out.add(id);
      }
      return out;
    } catch (e) {
      dlog('old peer: group not read (${e.runtimeType})');
      return const [];
    }
  }
}
