// SPDX-License-Identifier: GPL-3.0-or-later
// profile photos: your own, the one you set for a contact, theirs, the
// slices of one on its way in, and what each contact holds of yours
// (profile_photo.dart)

part of '../main.dart';

/// a contact's side of our photo: the version they hold (0 for none), the
/// version on its way to them, and when it goes
typedef PhotoPeer = ({
  String id,
  int held,
  int? want,
  int stamp,
  int nextAt,
  int tries,
});

mixin _PhotoRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();
  HaloContainer get container;

  // ---- your own ----

  /// your photo and when it was set. a removed one keeps its time, with
  /// no bytes. null when there never was one, or the table is not there
  Future<({int ver, Uint8List? photo})?> myPhoto() async {
    try {
      final db = await open();
      final r = await db.query('my_photo', where: 'id = 1', limit: 1);
      if (r.isEmpty) return null;
      return (ver: r.first['ver'] as int, photo: _blob(r.first['photo']));
    } catch (e) {
      dlog('photo: own not read (${e.runtimeType})');
      return null;
    }
  }

  /// [photo] as yours from [ver], or none from then
  Future<void> putMyPhoto(int ver, Uint8List? photo) async {
    final db = await open();
    await db.insert('my_photo', {
      'id': 1,
      'ver': ver,
      'photo': photo,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- a contact's ----

  /// every photo this container shows, by contact: yours over theirs. a
  /// chat that blocks screenshots shows the face, on every screen
  Future<Map<String, Uint8List>> contactPhotos() async {
    try {
      final db = await open();
      final cols = {
        for (final c in await db.rawQuery('PRAGMA table_info(contacts)'))
          c['name'],
      };
      final shots = [
        for (final c in ChatShots.reads)
          if (cols.contains(c)) 'c.$c',
      ];
      final rows = await db.rawQuery('''
        SELECT p.halo_id, p.mine, p.theirs${[for (final c in shots) ', $c'].join()}
        FROM contact_photos p LEFT JOIN contacts c ON c.halo_id = p.halo_id
        WHERE p.mine IS NOT NULL OR p.theirs IS NOT NULL
      ''');
      return {
        for (final r in rows)
          if (!ChatShots.ofRow(r, quiet: container.quiet).blocking)
            r['halo_id'] as String: ?(_blob(r['mine']) ?? _blob(r['theirs'])),
      };
    } catch (e) {
      dlog('photo: contacts not read (${e.runtimeType})');
      return const {};
    }
  }

  /// what is kept for [id]: the one you set, and the one they shared
  Future<({Uint8List? mine, Uint8List? theirs, int theirVer})> photosOf(
    String id,
  ) async {
    final db = await open();
    final r = await db.query(
      'contact_photos',
      where: 'halo_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (r.isEmpty) return (mine: null, theirs: null, theirVer: 0);
    return (
      mine: _blob(r.first['mine']),
      theirs: _blob(r.first['theirs']),
      theirVer: r.first['their_ver'] as int? ?? 0,
    );
  }

  /// the photo you set for [id], or none. only for a row this container
  /// holds: true when it was kept
  Future<bool> setMinePhoto(String id, Uint8List? photo) async {
    final db = await open();
    return db.transaction((t) async {
      final c = await t.query(
        'contacts',
        columns: ['halo_id'],
        where: 'halo_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (c.isEmpty) return false;
      final n = await t.update(
        'contact_photos',
        {'mine': photo},
        where: 'halo_id = ?',
        whereArgs: [id],
      );
      if (n == 0 && photo != null) {
        await t.insert('contact_photos', {'halo_id': id, 'mine': photo});
      }
      return true;
    });
  }

  /// a slice of [from]'s photo. true when what this phone shows of them
  /// changed: the last slice made the photo whole
  Future<bool> takePhotoSlice(String from, PhotoFrame f, {int? now}) async {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final db = await open();
    return db.transaction((t) async {
      final held = await _theirVer(t, from);
      if (!photoVersionTakes(f.version, held, now: at)) return false;
      // a newer one already on its way in wins
      final ahead = await t.query(
        'photo_parts',
        columns: ['ver'],
        where: 'halo_id = ? AND ver > ?',
        whereArgs: [from, f.version],
        limit: 1,
      );
      if (ahead.isNotEmpty) return false;
      await t.delete(
        'photo_parts',
        where: 'halo_id = ? AND (ver < ? OR total <> ?)',
        whereArgs: [from, f.version, f.total],
      );
      await t.insert('photo_parts', {
        'halo_id': from,
        'idx': f.index,
        'ver': f.version,
        'total': f.total,
        'part': f.bytes,
        'at': at,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final rows = await t.query(
        'photo_parts',
        columns: ['idx', 'part'],
        where: 'halo_id = ? AND ver = ?',
        whereArgs: [from, f.version],
      );
      final whole = joinPhotoSlices({
        for (final r in rows) r['idx'] as int: _blob(r['part'])!,
      }, f.total);
      if (whole == null) return false;
      await t.delete('photo_parts', where: 'halo_id = ?', whereArgs: [from]);
      // only what our phones send is kept: anything else is let go, and
      // their face stays
      final fit = photoTakeIn(whole);
      if (fit == null) {
        dlog('photo: one from a contact did not read clean');
        return false;
      }
      await _putTheirs(t, from, fit, f.version);
      return true;
    });
  }

  /// [from] took their photo back. true when one was shown
  Future<bool> takePhotoDrop(String from, int ver, {int? now}) async {
    final db = await open();
    return db.transaction((t) async {
      final r = await t.query(
        'contact_photos',
        columns: ['theirs', 'their_ver'],
        where: 'halo_id = ?',
        whereArgs: [from],
        limit: 1,
      );
      final held = r.isEmpty ? 0 : r.first['their_ver'] as int? ?? 0;
      if (!photoVersionTakes(ver, held, now: now)) return false;
      await t.delete('photo_parts', where: 'halo_id = ?', whereArgs: [from]);
      await _putTheirs(t, from, null, ver);
      return r.isNotEmpty && r.first['theirs'] != null;
    });
  }

  static Future<int> _theirVer(DatabaseExecutor t, String id) async {
    final r = await t.query(
      'contact_photos',
      columns: ['their_ver'],
      where: 'halo_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return r.isEmpty ? 0 : r.first['their_ver'] as int? ?? 0;
  }

  static Future<void> _putTheirs(
    DatabaseExecutor t,
    String id,
    Uint8List? photo,
    int ver,
  ) async {
    final n = await t.update(
      'contact_photos',
      {'theirs': photo, 'their_ver': ver},
      where: 'halo_id = ?',
      whereArgs: [id],
    );
    if (n > 0) return;
    await t.insert('contact_photos', {
      'halo_id': id,
      'theirs': photo,
      'their_ver': ver,
    });
  }

  /// slices that never made a photo, kept past [kPhotoPartsKeep]
  Future<void> dropStalePhotoParts({int? now}) async {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final db = await open();
      await db.delete(
        'photo_parts',
        where: 'at < ?',
        whereArgs: [at - kPhotoPartsKeep.inMilliseconds],
      );
    } catch (e) {
      dlog('photo: parts not swept (${e.runtimeType})');
    }
  }

  // ---- what each contact holds of ours ----

  /// every contact here as the photo sees them, with what they hold
  Future<List<({PhotoSendFacts facts, PhotoPeer peer})>> photoPeople() async {
    final db = await open();
    final (:ident, :support) = await _photoCols(db);
    final rows = await db.rawQuery('''
      SELECT c.halo_id AS id, c.accepted, c.back_paired, c.blocked, c.caps,
        $ident AS ident, $support AS support,
        p.held, p.want, p.stamp, p.next_at, p.tries
      FROM contacts c LEFT JOIN photo_peers p ON p.halo_id = c.halo_id
    ''');
    return [
      for (final r in rows)
        (
          facts: PhotoSendFacts(
            quiet: false,
            held: false,
            dev: isDevId(r['id'] as String),
            accepted: (r['accepted'] as int? ?? 0) == 1,
            backPaired: (r['back_paired'] as int? ?? 0) == 1,
            blocked: (r['blocked'] as int? ?? 0) == 1,
            peerCan: capsOfText(r['caps'] as String?).contains(kCapPhotos),
            mainIdentity: r['ident'] == 0,
            support: r['support'] != 0,
          ),
          peer: _peerOf(r),
        ),
    ];
  }

  // as sql over contacts c: the identity a contact knows, from the column
  // where identities have one, else the main one; and whether they wrote
  // in through the developer's chat, on his phone
  static Future<({String ident, String support})> _photoCols(
    DatabaseExecutor db,
  ) async {
    final cols = await db.rawQuery('PRAGMA table_info(contacts)');
    final inbox = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'support_chats'",
    );
    return (
      ident: cols.any((c) => c['name'] == 'ident') ? 'c.ident' : '0',
      support: inbox.isEmpty
          ? '0'
          : 'EXISTS (SELECT 1 FROM support_chats s '
                'WHERE s.halo_id = c.halo_id)',
    );
  }

  static PhotoPeer _peerOf(Map<String, Object?> r) => (
    id: r['id'] as String,
    held: r['held'] as int? ?? 0,
    want: r['want'] as int?,
    stamp: r['stamp'] as int? ?? 0,
    nextAt: r['next_at'] as int? ?? 0,
    tries: r['tries'] as int? ?? 0,
  );

  /// [id] is owed [want] (a version of ours, or 0 for a take-back) from
  /// [at], under a stamp above every one before; null: owed nothing
  Future<void> owePhoto(String id, int? want, {required int at}) async {
    final db = await open();
    await db.transaction((t) async {
      final r = await t.query(
        'photo_peers',
        where: 'halo_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final was = r.isEmpty ? 0 : r.first['stamp'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      await t.insert('photo_peers', {
        'halo_id': id,
        'held': r.isEmpty ? 0 : r.first['held'] as int? ?? 0,
        'want': want,
        'stamp': want == null ? was : max(now, was + 1),
        'next_at': at,
        'tries': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// the contacts whose turn it is. a photo waits for anyone not known to
  /// know the main identity; a take-back goes
  Future<List<PhotoPeer>> duePhotoPeers(int now) async {
    final db = await open();
    final (:ident, :support) = await _photoCols(db);
    final rows = await db.rawQuery(
      '''
      SELECT p.halo_id AS id, p.held, p.want, p.stamp, p.next_at, p.tries
      FROM photo_peers p LEFT JOIN contacts c ON c.halo_id = p.halo_id
      WHERE p.want IS NOT NULL AND p.next_at <= ?
        AND (p.want = 0 OR ($ident IS 0 AND NOT $support))
      ORDER BY p.next_at
    ''',
      [now],
    );
    return [for (final r in rows) _peerOf(r)];
  }

  /// the next time one is due, or null
  Future<int?> nextPhotoDue() async {
    final db = await open();
    final (:ident, :support) = await _photoCols(db);
    final r = await db.rawQuery('''
      SELECT MIN(p.next_at) AS at
      FROM photo_peers p LEFT JOIN contacts c ON c.halo_id = p.halo_id
      WHERE p.want IS NOT NULL
        AND (p.want = 0 OR ($ident IS 0 AND NOT $support))
    ''');
    return r.isEmpty ? null : r.first['at'] as int?;
  }

  /// [id] holds [want] now, if that is still what they were owed under
  /// [stamp]
  Future<void> photoSent(String id, int want, int stamp) async {
    final db = await open();
    await db.update(
      'photo_peers',
      {'held': want, 'want': null, 'tries': 0},
      where: 'halo_id = ? AND want = ? AND stamp = ?',
      whereArgs: [id, want, stamp],
    );
  }

  /// a send to [id] failed: it goes again at [at]
  Future<void> photoLater(String id, int stamp, int at) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE photo_peers SET tries = tries + 1, next_at = ? '
      'WHERE halo_id = ? AND stamp = ?',
      [at, id, stamp],
    );
  }

  /// a chat deleted here: what you set for them and what they shared go,
  /// so they come back as someone new. what they hold of ours stays known,
  /// so the take-back goes
  Future<void> dropPhotosOf(String id) async {
    try {
      final db = await open();
      await db.delete('contact_photos', where: 'halo_id = ?', whereArgs: [id]);
      await db.delete('photo_parts', where: 'halo_id = ?', whereArgs: [id]);
    } catch (e) {
      dlog('photo: not dropped (${e.runtimeType})');
    }
  }
}

Uint8List? _blob(Object? v) => v is Uint8List
    ? v
    : v is List<int>
    ? Uint8List.fromList(v)
    : null;

// the upgrade to 93: profile photos (profile_photo.dart). a table that will
// not make costs only the photos: their reads give up quietly, and a vault
// move goes on without them
Future<void> photoTables(DatabaseExecutor db) async {
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS my_photo (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        ver INTEGER NOT NULL,
        photo BLOB
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contact_photos (
        halo_id TEXT PRIMARY KEY,
        mine BLOB,
        theirs BLOB,
        their_ver INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photo_parts (
        halo_id TEXT NOT NULL,
        idx INTEGER NOT NULL,
        ver INTEGER NOT NULL,
        total INTEGER NOT NULL,
        part BLOB NOT NULL,
        at INTEGER NOT NULL,
        PRIMARY KEY (halo_id, idx)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photo_peers (
        halo_id TEXT PRIMARY KEY,
        held INTEGER NOT NULL DEFAULT 0,
        want INTEGER,
        stamp INTEGER NOT NULL DEFAULT 0,
        next_at INTEGER NOT NULL DEFAULT 0,
        tries INTEGER NOT NULL DEFAULT 0
      )
    ''');
    for (final t in const ['contact_photos', 'photo_parts', 'photo_peers']) {
      await db.execute(
        'CREATE TRIGGER IF NOT EXISTS ${t}_contacts_gone AFTER DELETE ON '
        'contacts BEGIN DELETE FROM $t WHERE halo_id = old.halo_id; END',
      );
    }
  } catch (e) {
    dlog('photo: no tables (${e.runtimeType})');
  }
}
