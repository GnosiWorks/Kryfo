// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's own marks and looks: unread, wallpaper, voice, screenshots

part of '../main.dart';

mixin _ChatSettingRows {
  // what these rows take from the rest of HaloDb
  HaloContainer get container;
  Future<Database> open();

  // the photo an atmosphere names, null for a preset
  static String? _photoOf(Object? atmosphere) =>
      atmosphere is String && atmosphere.startsWith('image:')
      ? atmosphere.substring(6)
      : null;

  // every photo a chat or group here names, by its name in the folder
  Future<Set<String>> _namedPhotos() async {
    final db = await open();
    return {
      for (final t in const ['contacts', 'groups'])
        for (final r in await db.query(
          t,
          columns: ['atmosphere'],
          where: 'atmosphere IS NOT NULL',
        ))
          if (_photoOf(r['atmosphere']) case final f?) p.basename(f),
    };
  }

  // wallpapers whose rows are written without them. one a row still names
  // stays, and only this container's wallpapers folder is ever touched
  Future<void> _dropPhotos(Iterable<Object?> atmospheres) async {
    final names = {
      for (final a in atmospheres)
        if (_photoOf(a) case final f?) p.basename(f),
    }..removeWhere((n) => n.isEmpty || n == '.' || n == '..');
    if (names.isEmpty) return;
    try {
      final named = await _namedPhotos();
      final dir = await container.folder('wallpapers');
      for (final n in names) {
        if (!named.contains(n)) await shredFile(p.join(dir.path, n));
      }
    } catch (e) {
      // the start sweep takes it
      dlog('wallpaper: not shredded (${e.runtimeType})');
    }
  }

  static final _randomWall = RegExp(r'^wp_[0-9a-f]{32}\.jpg$');

  /// wallpapers an older version named after their chat get a random name:
  /// the row is written first, then the file renamed. a start between the
  /// two finds the row's file missing and the old name beside it, and
  /// finishes the rename. throws when a rename is left undone, so nothing
  /// is swept that a row is about to name
  Future<void> renameNamedWallpapers() async {
    final db = await open();
    final dir = await container.folder('wallpapers');
    for (final r in await db.query(
      'contacts',
      columns: ['halo_id', 'atmosphere'],
      where: 'atmosphere IS NOT NULL',
    )) {
      final id = r['halo_id'] as String;
      final was = r['atmosphere'];
      final f = _photoOf(was);
      if (f == null) continue;
      final leaf = p.basename(f);
      final at = File(p.join(dir.path, leaf));
      final type = await FileSystemEntity.type(at.path, followLinks: false);
      if (_randomWall.hasMatch(leaf)) {
        if (type == FileSystemEntityType.notFound) {
          await (await _namedAfter(dir, id))?.rename(at.path);
        }
        continue;
      }
      // only a file of ours: a link or a folder is left as it is
      if (type != FileSystemEntityType.file) continue;
      final to = p.join(dir.path, _freshWallLeaf());
      final written = await db.transaction((t) async {
        if (await _atmosphereOf(t, id) != was) return false;
        await t.update(
          'contacts',
          {'atmosphere': 'image:$to'},
          where: 'halo_id = ?',
          whereArgs: [id],
        );
        return true;
      });
      if (written) await at.rename(to);
    }
  }

  // a wallpaper an older version named after [id]'s chat, the newest
  static Future<File?> _namedAfter(Directory dir, String id) async {
    final shape = RegExp('^${RegExp.escape(id)}(_[0-9a-f]{16})?\\.jpg\$');
    File? best;
    DateTime? at;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || !shape.hasMatch(p.basename(e.path))) continue;
      final m = await e.lastModified();
      if (at == null || m.isAfter(at)) (best, at) = (e, m);
    }
    return best;
  }

  /// the files in this container's wallpapers folder that no chat or group
  /// names, last written before [before]: what a delete or a crash left
  Future<List<File>> unnamedWallpapers({required DateTime before}) async {
    final named = await _namedPhotos();
    final dir = await container.folder('wallpapers');
    final out = <File>[];
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File || named.contains(p.basename(e.path))) continue;
      if ((await e.lastModified()).isBefore(before)) out.add(e);
    }
    return out;
  }

  Future<void> bumpUnread(String peerId) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE contacts SET unread = unread + 1 WHERE halo_id = ?',
      [peerId],
    );
  }

  Future<void> clearUnread(String peerId) async {
    final db = await open();
    await db.update(
      'contacts',
      {'unread': 0},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  Future<void> bumpGroupUnread(String groupId) async {
    final db = await open();
    await db.rawUpdate(
      'UPDATE groups SET unread = unread + 1 WHERE group_id = ?',
      [groupId],
    );
  }

  Future<void> setGroupMentioned(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'mentioned': 1},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> clearGroupUnread(String groupId) async {
    final db = await open();
    await db.update(
      'groups',
      {'unread': 0, 'mentioned': 0},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // the same as setChatAtmosphere: one way in, so a photo always goes with
  // the choice that replaced it
  Future<void> setGroupAtmosphere(String groupId, String atmosphere) =>
      setChatAtmosphere(groupId, atmosphere, group: true);

  Future<String?> getGroupAtmosphere(String groupId) async {
    final db = await open();
    final rows = await db.query(
      'groups',
      columns: ['atmosphere'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    if (rows.isEmpty) return null;
    return rows.first['atmosphere'] as String?;
  }

  // the photo it had goes once the row is written (setChatAtmosphere)
  Future<void> setAtmosphere(String peerId, String atmosphere) =>
      setChatAtmosphere(peerId, atmosphere);

  // a chat's own voice disguise choice, null until one is made here
  Future<bool?> voiceDisguiseOf(String chatId, {bool group = false}) async {
    final db = await open();
    final rows = await db.query(
      group ? 'groups' : 'contacts',
      columns: ['voice_disguise'],
      where: group ? 'group_id = ?' : 'halo_id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['voice_disguise'];
    return v is int ? v == 1 : null;
  }

  Future<void> setVoiceDisguise(
    String chatId,
    bool on, {
    bool group = false,
  }) async {
    final db = await open();
    await db.update(
      group ? 'groups' : 'contacts',
      {'voice_disguise': on ? 1 : 0},
      where: group ? 'group_id = ?' : 'halo_id = ?',
      whereArgs: [chatId],
    );
  }

  // a chat's screenshot block (chat_shots.dart)
  Future<ChatShots> shotsOf(String peer) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ChatShots.reads,
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    return ChatShots.ofRow(rows.firstOrNull, quiet: container.quiet);
  }

  // a change made here, for [peer]'s phone to take: its stamp, past the
  // one held, read and written in one go. null with no row
  Future<int?> turnShots(String peer, {required bool on}) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'contacts',
        columns: const ['shots_at'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final at = shotsNextStamp((rows.first['shots_at'] as num).toInt(), now);
      await t.update(
        'contacts',
        {
          'shots_on': on ? 1 : 0,
          'shots_at': at,
          'shots_by': kShotsByMe,
          'shots_when': now,
        },
        where: 'halo_id = ?',
        whereArgs: [peer],
      );
      return at;
    });
  }

  // what a 1:1 envelope from [peer] says of the block. [counts]: a message
  // of theirs (shotsCanAfter). true when anything changed
  Future<bool> takeShots(
    String peer,
    ShotsWord? word, {
    required bool counts,
    int? written,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final rows = await t.query(
        'contacts',
        columns: [...ChatShots.columns, 'accepted'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final was = ChatShots.ofRow(rows.first);
      // a request sets nothing on this screen: it could keep its own words
      // from being kept
      final accepted = rows.first['accepted'] == 1;
      final can = shotsCanAfter(
        was.can,
        carried: word != null,
        counts: counts,
        written: written,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final took =
          accepted &&
          word != null &&
          shotsInTime(word, now) &&
          shotsWins(word, on: was.on, at: was.at);
      // a burst of theirs keeps its line where the burst began, saying
      // where it ended
      final burst =
          was.by == kShotsByThem &&
          now - was.when < kShotsLineGap.inMilliseconds;
      final put = <String, Object?>{
        'shots_can': ?can,
        if (took) ...{
          'shots_on': word.on ? 1 : 0,
          'shots_at': word.at,
          if (word.on != was.on) ...{
            'shots_by': kShotsByThem,
            if (!burst) 'shots_when': now,
          },
        },
      };
      if (put.isEmpty) return false;
      await t.update('contacts', put, where: 'halo_id = ?', whereArgs: [peer]);
      return true;
    });
  }

  /// what a 1:1 frame from [peer] says their phone understands, kept
  /// only on an accepted contact's row and written only when it changes
  /// (capsAfter). true when it did
  Future<bool> takeCaps(
    String peer, {
    required List<String>? caps,
    required bool counts,
    int? written,
  }) async {
    final db = await open();
    return db.transaction((t) async {
      final r = await t.query(
        'contacts',
        columns: const ['caps', 'caps_at'],
        where: 'halo_id = ? AND accepted = 1',
        whereArgs: [peer],
        limit: 1,
      );
      if (r.isEmpty) return false;
      final next = capsAfter(
        (r.first['caps'] as String?) ?? '',
        (r.first['caps_at'] as num?)?.toInt() ?? 0,
        carried: caps,
        counts: counts,
        written: written,
      );
      if (next == null) return false;
      await t.update(
        'contacts',
        {'caps': next.caps, 'caps_at': next.at},
        where: 'halo_id = ?',
        whereArgs: [peer],
      );
      return true;
    });
  }

  // accepted chats whose phones know the block and that do not block yet
  Future<List<String>> shotsCanTurnOn() async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: const ['halo_id'],
      where: 'accepted = 1 AND blocked = 0 AND shots_can > ? AND shots_on = 0',
      whereArgs: [0],
    );
    return [
      for (final r in rows)
        if (!isDevChat(r['halo_id'] as String)) r['halo_id'] as String,
    ];
  }

  Future<String?> getAtmosphere(String peerId) async {
    final db = await open();
    final rows = await db.query(
      'contacts',
      columns: ['atmosphere'],
      where: 'halo_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['atmosphere'] as String?;
  }

  // a wallpaper row by its key (wallKey, '' for the default)
  Future<({String atmo, Uint8List? photo})?> wallpaperRow(String key) async {
    final db = await open();
    final rows = await db.query(
      'wallpapers',
      columns: ['atmo', 'photo'],
      where: 'chat = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final photo = rows.first['photo'];
    return (
      atmo: rows.first['atmo'] as String,
      photo: photo is Uint8List
          ? photo
          : photo is List<int>
          ? Uint8List.fromList(photo)
          : null,
    );
  }

  // what a chat's atmosphere says now, as its row has it
  static Future<String?> _wallOf(
    DatabaseExecutor t,
    String chatId,
    bool group,
  ) async {
    final r = await t.query(
      group ? 'groups' : 'contacts',
      columns: ['atmosphere'],
      where: group ? 'group_id = ?' : 'halo_id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['atmosphere'] as String?;
  }

  // a chat's own photo behind it, and its atmosphere saying so. the row is
  // written first and the photo only when it found its chat, so a photo
  // never lands where no chat names it. a file an older version kept for
  // it is shredded once the row is written. whether it was kept
  Future<bool> setChatPhoto(
    String chatId,
    Uint8List photo, {
    bool group = false,
  }) async {
    final db = await open();
    final (kept, was) = await db.transaction((t) async {
      final was = await _wallOf(t, chatId, group);
      final n = await t.update(
        group ? 'groups' : 'contacts',
        {'atmosphere': kPhotoWall},
        where: group ? 'group_id = ?' : 'halo_id = ?',
        whereArgs: [chatId],
      );
      if (n != 1) return (false, null);
      await t.insert('wallpapers', {
        'chat': wallKey(chatId, group: group),
        'atmo': kPhotoWall,
        'photo': photo,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return (true, was);
    });
    await _dropPhotos([was]);
    return kept;
  }

  // a built-in by name, or null to follow the default. a photo it had goes
  Future<void> setChatAtmosphere(
    String chatId,
    String? atmo, {
    bool group = false,
  }) async {
    final db = await open();
    final was = await db.transaction((t) async {
      final was = await _wallOf(t, chatId, group);
      await t.delete(
        'wallpapers',
        where: 'chat = ?',
        whereArgs: [wallKey(chatId, group: group)],
      );
      await t.update(
        group ? 'groups' : 'contacts',
        {'atmosphere': atmo},
        where: group ? 'group_id = ?' : 'halo_id = ?',
        whereArgs: [chatId],
      );
      return was;
    });
    await _dropPhotos([was]);
  }

  // the default: a built-in by name, or kPhotoWall with its photo
  Future<void> setDefaultWallpaper(String atmo, [Uint8List? photo]) async {
    final db = await open();
    await db.insert('wallpapers', {
      'chat': '',
      'atmo': atmo,
      'photo': photo,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // how strongly the dark page lies over this identity's photos, 0 to 1,
  // or null for the automatic veil. kept with the default's row: the same
  // container, gone with the identity, the decoy's its own
  Future<double?> wallDim() async {
    final row = await wallpaperRow(kDimWall);
    final v = row == null ? null : double.tryParse(row.atmo);
    return v == null || !v.isFinite ? null : v.clamp(0.0, 1.0);
  }

  Future<void> setWallDim(double? dim) async {
    final db = await open();
    if (dim == null) {
      await db.delete('wallpapers', where: 'chat = ?', whereArgs: [kDimWall]);
      return;
    }
    await db.insert('wallpapers', {
      'chat': kDimWall,
      'atmo': dim.clamp(0.0, 1.0).toStringAsFixed(3),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

// a chat's own wallpaper photo, and the default every chat without a choice
// of its own shows. chat is a contact's id, 'group:' and a group's id, or
// '' for the default. atmo is kPhotoWall with a photo, or for the default a
// built-in by name. the photo's bytes live here, under the container's own
// key, and nowhere else. a chat's photo lasts while its atmosphere says
// photo: whatever clears that or drops the row (a delete, a wipe of the
// chat's settings) takes the photo with it, by the triggers below
const kPhotoWall = 'photo';

// the dim's row: no chat or group key takes a leading colon
const kDimWall = ':dim';

String wallKey(String chatId, {bool group = false}) =>
    group ? 'group:$chatId' : chatId;
