// SPDX-License-Identifier: GPL-3.0-or-later
// eight digit pair codes in the app (identity v4 6, 3.4b): each side seals
// a fresh one-time invite of its own into the run; once the code matched,
// the joiner adds the sharer as from a v4 link (it starts the session) and
// the sharer adds the joiner and waits for that opener on the invite it
// sealed, where nothing else opens

part of '../main.dart';

/// a hellos row: a pairing's one-time invite, held from its making until
/// the person's add (peer empty until the code matched). nothing listens on
/// it and nothing opens there meanwhile
const kHelloPair = 'pair';

/// how long a matched pairing waits for the person's add before its
/// invite goes
const kPairHoldFor = Duration(minutes: 30);

/// the hooks a pairing runs on. a quiet session makes no invite, puts
/// nothing up and answers nothing: its share shows a fresh code nobody can
/// use and waits, its join looks at the box on the decoy's own lane and
/// says what a code with nothing there says, each round as long as a real
/// one (kDecoyLooksUp)
PairHooks pairHooks() => sessionQuiet ? _quietPairHooks() : _pairHooks();

PairHooks _quietPairHooks() {
  var box = '';
  var sharing = false;
  return PairHooks(
    invite: () async => PairMine(Uint8List(0)),
    share: (_) async {
      final r = Random.secure();
      final code = List.generate(8, (_) => r.nextInt(10)).join();
      box = code.substring(0, 2);
      sharing = true;
      final res = await engine.decoyPairLook(box);
      return res == 'look' ? 'ok 0 ${pairCodeShown(code)}' : pairUnreached;
    },
    join: (code, _) async {
      box = code.substring(0, 2);
      return 'ok 0';
    },
    step: (_) async {
      final res = await engine.decoyPairLook(box);
      return sharing && res == 'look' ? 'wait 0' : res;
    },
    close: (_) async {},
    read: (_) async => null,
    hold: (_, _) async {},
    add: (_, _, {required sharer}) async => ('', false),
    drop: (_) async {},
  );
}

PairHooks _pairHooks() => PairHooks(
  invite: () => appState.pairInvite(),
  share: engine.pairShare,
  join: (code, invite) async => engine.pairJoin(code, invite),
  step: engine.pairStep,
  close: engine.pairClose,
  read: (kin4) async => pairPeerOf(kin4),
  hold: (mine, peer) => appState.pairHold(mine, peer),
  add: (peer, mine, {required sharer}) async {
    final r = await handleHaloUriAdded(
      peer.link,
      pairOut: sharer ? mine.row as InviteRow? : null,
    );
    await appState.refreshContacts();
    return r;
  },
  drop: (mine) => appState.pairDrop(mine),
);

/// the other side's KIN4 out of a run, read as a link is read: every
/// reader check, one-time with a bundle and a face. null for any other
PairPeer? pairPeerOf(Uint8List kin4) {
  final link = inviteLink(kin4);
  final got = v4OfLink(link);
  if (got is! LsInvite || !got.oneTime || got.block == null) return null;
  final p = v4Parsed(got);
  if (p == null) return null;
  return PairPeer(link: link, id: p['id']!, invite: got);
}

extension AppStatePairCodes on AppState {
  /// a fresh one-time invite of the main identity for one pairing: face,
  /// onion and bundle, as a hello carries. null before one can be made
  Future<PairMine?> pairInvite() async {
    if (sessionQuiet || !signalSession.ready) return null;
    final face = _mainInviteFace();
    if (face == null) return null;
    final db = await live.open();
    final row = await makeInvite(
      db,
      signalSession,
      kind: kInviteOneTime,
      fcPkOf: _fcPkOfKey,
      face: face,
    );
    // held from the start, on both sides: no upkeep listens on it and no
    // opener opens there before the person's add
    await db.insert('hellos', {
      'ident': row.ident,
      'way': kHelloPair,
      'peer': '',
      'invite_id': row.id,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return PairMine(row.link, row);
  }

  /// the sharer's invite of a pairing that matched, held for [peer] until
  /// the person adds them: not listened on, so no opener opens there before
  Future<void> pairHold(PairMine mine, PairPeer peer) async {
    final row = mine.row, inv = peer.invite;
    if (row is! InviteRow || inv is! LsInvite) return;
    final db = await live.open();
    final was = await db.query(
      'hellos',
      columns: ['at'],
      where: 'ident = ? AND way = ? AND invite_id = ?',
      whereArgs: [row.ident, kHelloPair, row.id],
      limit: 1,
    );
    await db.delete(
      'hellos',
      where: 'ident = ? AND way = ? AND invite_id = ?',
      whereArgs: [row.ident, kHelloPair, row.id],
    );
    await db.insert('hellos', {
      'ident': row.ident,
      'way': kHelloPair,
      'peer': _hexOf(inv.identity),
      'invite_id': row.id,
      'fc': _hexOf(inv.firstContact),
      'at': was.isEmpty
          ? DateTime.now().millisecondsSinceEpoch
          : was.first['at'] as int,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    // one listened on anyway (an older build's upkeep) is let go
    await engine.unsubscribeFcKey(row.ident, row.id);
  }

  /// the sharer added them: the held invite waits for their opener, from
  /// their key alone (as a hello's one-time invite does), and is listened on
  Future<void> pairOpen(InviteRow row, List<int> key) async {
    final db = await live.open();
    await db.delete(
      'hellos',
      where: 'ident = ? AND way IN (?, ?) AND invite_id = ?',
      whereArgs: [row.ident, kHelloPair, kHelloOut, row.id],
    );
    await db.insert('hellos', {
      'ident': row.ident,
      'way': kHelloOut,
      'peer': _hexOf(key),
      'invite_id': row.id,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final sk = (await fcKeysOf(db, row.ident))[row.id];
    if (sk != null) {
      final res = await engine.subscribeFcKey(row.ident, row.id, _hexOf(sk));
      if (res != 'ok') dlog('pair: invite not listened on ($res)');
    }
  }

  /// a pairing's invite let go: no one opens on it
  Future<void> pairDrop(PairMine mine) async {
    final row = mine.row;
    if (row is! InviteRow) return;
    try {
      final db = await live.open();
      await spendOneTime(db, signalSession, row);
      await db.delete(
        'hellos',
        where: 'ident = ? AND way IN (?, ?) AND invite_id = ?',
        whereArgs: [row.ident, kHelloPair, kHelloOut, row.id],
      );
      await engine.unsubscribeFcKey(row.ident, row.id);
    } catch (e) {
      dlog('pair: invite not let go (${e.runtimeType})');
    }
  }

  /// held invites of pairings nobody added in time (the app closed on the
  /// card, or it waited past kPairHoldFor) go
  Future<void> _dropPairsHeld(Database db, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'hellos',
      columns: ['ident', 'invite_id'],
      where: 'way = ? AND at < ?',
      whereArgs: [kHelloPair, now - kPairHoldFor.inMilliseconds],
    );
    for (final r in rows) {
      final inv = await inviteOf(
        db,
        r['ident'] as int,
        r['invite_id'] as String,
      );
      if (inv != null) await pairDrop(PairMine(inv.link, inv));
      await db.delete(
        'hellos',
        where: 'ident = ? AND way = ? AND invite_id = ?',
        whereArgs: [r['ident'], kHelloPair, r['invite_id']],
      );
    }
  }
}
