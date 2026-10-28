// SPDX-License-Identifier: GPL-3.0-or-later
// a stranger's first messages, held, and openers tried again

part of '../main.dart';

mixin _FirstContactRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();
  Future<bool> isVouched(String haloId);
  Future<bool> isBlocked(String haloId);
  Future<bool> isAccepted(String haloId);

  // a stranger past the cap gets a small shelf, not a disk. [mediaId]
  // names the file a slice is of and [chunk] its place in it, of [total]:
  // a file takes one place and each of its slices one row. an [overflow]
  // row is a cipher as it came, kept for its bytes alone
  Future<Shelved> holdCipher(
    String peerId,
    String cipher, {
    String? mediaId,
    int? chunk,
    int? total,
    bool overflow = false,
  }) async {
    final db = await open();
    // a copy of one held already (off a relay's backlog) is held once
    final slice = !overflow && mediaId != null && chunk != null;
    final had = await db.query(
      'held_onion',
      columns: ['id'],
      where: slice
          ? 'peer_id = ? AND media_id = ? AND chunk = ?'
          : 'peer_id = ? AND cipher = ?',
      whereArgs: slice ? [peerId, mediaId, chunk] : [peerId, cipher],
      limit: 1,
    );
    if (had.isNotEmpty) return Shelved.kept;
    final shelf = await shelfOf(peerId);
    final v = shelfVerdict(
      places: shelf.places,
      files: shelf.files,
      bytes: shelf.bytes,
      size: cipher.length,
      mediaId: mediaId,
      chunk: chunk,
      total: total,
      overflow: overflow,
    );
    if (v != Shelved.kept) return v;
    await db.insert('held_onion', {
      'peer_id': peerId,
      'cipher': cipher,
      'at': DateTime.now().millisecondsSinceEpoch,
      'media_id': overflow ? null : mediaId,
      'chunk': overflow ? null : chunk,
    });
    return Shelved.kept;
  }

  // the places their shelf takes, the slices of each file on it and the
  // bytes it holds. a row as it came (overflow) takes no place
  Future<({int places, Map<String, Set<int?>> files, int bytes})> shelfOf(
    String peerId,
  ) async {
    final db = await open();
    final texts =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) n FROM held_onion WHERE peer_id = ? AND media_id IS NULL AND cipher LIKE ?',
            [peerId, 'wire:%'],
          ),
        ) ??
        0;
    final files = <String, Set<int?>>{};
    var bytes = 0;
    for (final r in await db.query(
      'held_onion',
      columns: ['media_id', 'chunk', 'length(cipher) AS n'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
    )) {
      bytes += (r['n'] as num?)?.toInt() ?? 0;
      final m = r['media_id'] as String?;
      if (m != null) (files[m] ??= {}).add((r['chunk'] as num?)?.toInt());
    }
    return (places: texts + files.length, files: files, bytes: bytes);
  }

  // strangers whose shelf is full, [only] or everyone's, with the files on
  // it: what more they send waits on the relay
  Future<Map<String, Set<String>>> fullShelves({String? only}) async {
    final db = await open();
    final out = <String, Set<String>>{};
    final ids = only != null
        ? [only]
        : [
            for (final r in await db.query(
              'held_onion',
              distinct: true,
              columns: ['peer_id'],
            ))
              r['peer_id'] as String,
          ];
    for (final id in ids) {
      final shelf = await shelfOf(id);
      if (shelf.places < kShelfPlaces) continue;
      if (await isAccepted(id) || await isBlocked(id) || await isVouched(id)) {
        continue;
      }
      out[id] = shelf.files.keys.toSet();
    }
    return out;
  }

  // what the shelf holds for them, oldest first. a row goes with
  // forgetHeld once it is in, so one that fails stays
  Future<List<({int id, String cipher, int at})>> heldOf(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'held_onion',
      columns: ['id', 'cipher', 'at'],
      where: 'peer_id = ?',
      whereArgs: [peerId],
      orderBy: 'id ASC',
    );
    return [
      for (final r in rows)
        (
          id: r['id'] as int,
          cipher: r['cipher'] as String,
          at: r['at'] as int? ?? 0,
        ),
    ];
  }

  Future<void> forgetHeld(int id) async {
    final db = await open();
    await db.delete('held_onion', where: 'id = ?', whereArgs: [id]);
  }

  // people accepted already with something still on the shelf: an accept
  // that failed part way, or died before it was through
  Future<List<String>> heldOfAccepted() async {
    final db = await open();
    final rows = await db.rawQuery(kHeldOfAccepted);
    return [for (final r in rows) r['peer_id'] as String];
  }

  Future<void> dropHeld(String peerId) async {
    final db = await open();
    await db.delete('held_onion', where: 'peer_id = ?', whereArgs: [peerId]);
  }

  // a stranger's opener that opened and did not file, kept as it came to be
  // tried again: [peer] is who it opened to, empty for someone the everyday
  // side does not name, and [uid] the message it carries. false when there
  // is no room for it (firstKeepFits)
  Future<bool> keepFirst(
    String hash,
    String cipher, {
    String peer = '',
    String? uid,
    required int now,
    Reached? reached,
  }) async {
    final db = await open();
    final rows = await db.query(
      'first_kept',
      columns: ['hash', 'cipher', 'peer'],
    );
    if (rows.any((r) => r['hash'] == hash)) return true;
    var bytes = 0;
    var mine = 0;
    for (final r in rows) {
      bytes += (r['cipher'] as String).length;
      if (r['peer'] == peer) mine++;
    }
    if (!firstKeepFits(
      rows: rows.length,
      mine: mine,
      bytes: bytes,
      size: cipher.length,
      named: peer.isNotEmpty,
    )) {
      return false;
    }
    await db.insert('first_kept', {
      'hash': hash,
      'cipher': cipher,
      'peer': peer,
      'uid': uid,
      'at': now,
      'tries': 0,
      'next_at': now + firstRetryGap(0).inMilliseconds,
      'reached_from': reached?.from,
      'reached_until': reached?.until,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return true;
  }

  // every kept opener, oldest first
  Future<List<FirstKept>> firstKept() async {
    final db = await open();
    final rows = await db.query('first_kept', orderBy: 'at ASC');
    return [
      for (final r in rows)
        (
          hash: r['hash'] as String,
          cipher: r['cipher'] as String,
          peer: r['peer'] as String? ?? '',
          at: (r['at'] as num).toInt(),
          tries: (r['tries'] as num).toInt(),
          nextAt: (r['next_at'] as num).toInt(),
          reached: switch ((r['reached_from'], r['reached_until'])) {
            (final int f, final int u) => (from: f, until: u),
            _ => null,
          },
        ),
    ];
  }

  Future<void> retryFirstAt(String hash, int tries, int nextAt) async {
    final db = await open();
    await db.update(
      'first_kept',
      {'tries': tries, 'next_at': nextAt},
      where: 'hash = ?',
      whereArgs: [hash],
    );
  }

  Future<void> forgetFirst(String hash) async {
    final db = await open();
    await db.delete('first_kept', where: 'hash = ?', whereArgs: [hash]);
  }

  // what [peer] has kept here: their request went, or they took [uid] back
  Future<void> forgetFirstOf(String peer, {String? uid}) async {
    final db = await open();
    await db.delete(
      'first_kept',
      where: uid == null ? 'peer = ?' : 'peer = ? AND uid = ?',
      whereArgs: [peer, ?uid],
    );
  }

  // every kept opener: none of them opens under a new invite key
  Future<void> forgetAllFirst() async {
    final db = await open();
    await db.delete('first_kept');
  }

  // and those kept before [cut], in a vault that was shut as the key moved
  Future<void> forgetFirstBefore(int cut) async {
    final db = await open();
    await db.delete('first_kept', where: 'at < ?', whereArgs: [cut]);
  }

  // whether an opener of [peer]'s, or of someone unnamed, with [uid] is kept
  Future<bool> firstKeptHas(String peer, String uid) async {
    final db = await open();
    final rows = await db.query(
      'first_kept',
      columns: ['peer'],
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return rows.any((r) => r['peer'] == peer || r['peer'] == '');
  }

  // [uid] taken back by [peer] before it came: known as gone, so a copy
  // that comes later, after a restart too, is never shown
  Future<void> noteTakenBack(String peer, String uid) async {
    final db = await open();
    await db.insert('gone_in', {
      'msg_uid': uid,
      'peer_id': peer,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // our 1:1 texts and files to [peer] that went, oldest first: past their
  // stranger cap, theirs are held rather than shown
  Future<List<String>> sentUidsTo(String peer) async {
    final db = await open();
    final rows = await db.query(
      'messages',
      columns: ['msg_uid'],
      where: "$_kOneToOne AND direction = 'out' AND sent = 1",
      whereArgs: [peer],
      orderBy: 'sent_at ASC',
    );
    return [
      for (final r in rows)
        if (r['msg_uid'] case final String u) u,
    ];
  }

  // our sent texts to [peer] with no receipt yet, the openers among them
  // while they have not added us back
  Future<List<Map<String, Object?>>> sentUnconfirmed(String peer) async {
    final db = await open();
    return db.query(
      'messages',
      where:
          "$_kOneToOne AND direction = 'out' AND sent = 1 AND delivered = 0 "
          'AND msg_uid IS NOT NULL AND media_path IS NULL AND file_path IS NULL',
      whereArgs: [peer],
      orderBy: 'sent_at ASC',
    );
  }

  // people we may have written to who have not added us back, and are
  // neither blocked nor flagged with a new key
  Future<List<String>> notBackPaired() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['halo_id'],
      where: 'back_paired = 0 AND blocked = 0 AND key_changed = 0',
    );
    return [for (final r in rows) r['halo_id'] as String];
  }

  // how often an opener of ours went again, when it last did, the words it
  // first went as and whether its onion and relay copies both went
  Future<({int tries, int lastAt, String? wire, bool both})?> openerAgain(
    String uid,
  ) async {
    final db = await open();
    final rows = await db.query(
      'opener_again',
      where: 'msg_uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      tries: (r['tries'] as num).toInt(),
      lastAt: (r['last_at'] as num).toInt(),
      wire: r['wire'] as String?,
      both: r['both_went'] == 1,
    );
  }

  Future<void> _openerRow(String uid, Map<String, Object?> v) async {
    final db = await open();
    final n = await db.update(
      'opener_again',
      v,
      where: 'msg_uid = ?',
      whereArgs: [uid],
    );
    if (n > 0) return;
    await db.insert('opener_again', {
      'msg_uid': uid,
      'last_at': DateTime.now().millisecondsSinceEpoch,
      ...v,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> noteOpenerAgain(String uid, int tries, int at) =>
      _openerRow(uid, {'tries': tries, 'last_at': at});

  // an opener's words as they first went: what goes again is the same, so
  // a gate that held it holds no second copy
  Future<void> keepOpenerWire(String uid, String wire) =>
      _openerRow(uid, {'wire': wire});

  // its onion took it and its relay copy went too
  Future<void> noteOpenerBoth(String uid) => _openerRow(uid, {'both_went': 1});

  // what went again before [cut] is past the relays' keeping
  Future<void> forgetOpenersBefore(int cut) async {
    final db = await open();
    await db.delete('opener_again', where: 'last_at < ?', whereArgs: [cut]);
  }
}

// an opener kept to be tried again (HaloDb.keepFirst)
typedef FirstKept = ({
  String hash,
  String cipher,
  String peer,
  int at,
  int tries,
  int nextAt,
  // when it reached the relay or this phone, by this clock, where the lane
  // said: null for one kept before that was kept
  Reached? reached,
});

/// the people the shelf may let in without an accept: accepted already and
/// not blocked. a stranger's rows wait for theirs
@visibleForTesting
const kHeldOfAccepted =
    'SELECT DISTINCT h.peer_id FROM held_onion h '
    'JOIN contacts c ON c.halo_id = h.peer_id '
    'WHERE c.accepted = 1 AND IFNULL(c.blocked, 0) = 0';
