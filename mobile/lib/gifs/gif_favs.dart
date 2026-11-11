// SPDX-License-Identifier: GPL-3.0-or-later
// favourite gifs, kept on this phone per identity. each one is the gif
// itself, a file in its container's media folder (sealed at rest as a
// chat's photos are, carried by backups), and a row in that container's
// database for its place. nothing says where a gif came from: no link, no
// id, no service. the decoy keeps its own, the hidden chats theirs in the
// vault. not sent to linked computers: the own sync carries small state,
// not files
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' show DatabaseExecutor;

import '../dlog.dart';
import '../image_strip.dart' show PictureKind, pictureKind;
import '../shred.dart' show shredFile;

/// the folder inside the media folder; the media sweeps leave folders alone
const kFavFolder = 'favs';

/// the most kept; past it the one at the end goes
const kGifFavMost = 200;

class GifFav {
  const GifFav({required this.id, required this.path, this.w = 0, this.h = 0});
  final int id;
  final String path;
  final int w, h;

  /// height over width, as the grid lays tiles out
  double get ratio => w > 0 && h > 0 ? (h / w).clamp(0.4, 2.0) : 1.0;

  @override
  bool operator ==(Object other) =>
      other is GifFav && other.id == id && other.path == path;
  @override
  int get hashCode => Object.hash(id, path);
}

/// a gif's size from its header, (0, 0) when it does not say
(int, int) gifSize(Uint8List b) {
  if (b.length < 10) return (0, 0);
  return (b[6] | (b[7] << 8), b[8] | (b[9] << 8));
}

class GifFavStore {
  GifFavStore({required this.db, required this.folder});

  /// the container's database, open
  final Future<DatabaseExecutor> Function() db;

  /// the container's media folder
  final Future<Directory> Function() folder;

  static Future<void> table(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS gif_favs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      leaf TEXT NOT NULL,
      sum TEXT NOT NULL UNIQUE,
      w INTEGER NOT NULL DEFAULT 0,
      h INTEGER NOT NULL DEFAULT 0,
      place INTEGER NOT NULL
    )
  ''');

  // made on first use: a file from before it has none
  Future<DatabaseExecutor> _open() async {
    final d = await db();
    await table(d);
    return d;
  }

  Future<String> _dir() async => p.join((await folder()).path, kFavFolder);

  /// in their order, the first first. a row whose file went is let go
  Future<List<GifFav>> load() async {
    final d = await _open();
    final dir = await _dir();
    final rows = await d.query('gif_favs', orderBy: 'place ASC, id DESC');
    final out = <GifFav>[];
    final lost = <int>[];
    for (final r in rows) {
      final path = p.join(dir, r['leaf'] as String);
      final id = (r['id'] as num).toInt();
      if (!await File(path).exists()) {
        lost.add(id);
        continue;
      }
      out.add(
        GifFav(
          id: id,
          path: path,
          w: (r['w'] as num?)?.toInt() ?? 0,
          h: (r['h'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    for (final id in lost) {
      await d.delete('gif_favs', where: 'id = ?', whereArgs: [id]);
    }
    return out;
  }

  /// to the front. one kept already moves there instead of twice. false
  /// when [bytes] is not a gif
  Future<bool> add(Uint8List bytes) async {
    if (pictureKind(bytes) != PictureKind.gif) return false;
    final sum = sha256.convert(bytes).toString();
    final d = await _open();
    final first = await d.rawQuery('SELECT MIN(place) AS m FROM gif_favs');
    final front = ((first.first['m'] as num?)?.toInt() ?? 1) - 1;
    final had = await d.query(
      'gif_favs',
      columns: ['id', 'leaf'],
      where: 'sum = ?',
      whereArgs: [sum],
    );
    final dir = await _dir();
    if (had.isNotEmpty &&
        await File(p.join(dir, had.first['leaf'] as String)).exists()) {
      await d.update(
        'gif_favs',
        {'place': front},
        where: 'id = ?',
        whereArgs: [had.first['id']],
      );
      return true;
    }
    if (had.isNotEmpty) {
      await d.delete('gif_favs', where: 'sum = ?', whereArgs: [sum]);
    }
    await Directory(dir).create(recursive: true);
    final leaf = '${_name()}.gif';
    final path = p.join(dir, leaf);
    await File(path).writeAsBytes(bytes, flush: true);
    final (w, h) = gifSize(bytes);
    try {
      await d.insert('gif_favs', {
        'leaf': leaf,
        'sum': sum,
        'w': w,
        'h': h,
        'place': front,
      });
    } catch (e) {
      await shredFile(path);
      rethrow;
    }
    await _trim(d, dir);
    return true;
  }

  Future<void> _trim(DatabaseExecutor d, String dir) async {
    final over = await d.query(
      'gif_favs',
      columns: ['id', 'leaf'],
      orderBy: 'place ASC, id DESC',
      limit: -1,
      offset: kGifFavMost,
    );
    for (final r in over) {
      await d.delete('gif_favs', where: 'id = ?', whereArgs: [r['id']]);
      await shredFile(p.join(dir, r['leaf'] as String));
    }
  }

  /// gone from the list, its file zeroed
  Future<void> remove(GifFav f) async {
    final d = await _open();
    await d.delete('gif_favs', where: 'id = ?', whereArgs: [f.id]);
    try {
      await shredFile(f.path);
    } catch (e) {
      dlog('gif fav: file not shredded (${e.runtimeType})');
    }
  }

  /// the order as shown
  Future<void> reorder(List<GifFav> order) async {
    final d = await _open();
    for (final (i, f) in order.indexed) {
      await d.update(
        'gif_favs',
        {'place': i},
        where: 'id = ?',
        whereArgs: [f.id],
      );
    }
  }

  static final _rnd = Random.secure();
  static String _name() => [
    for (var i = 0; i < 12; i++)
      _rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
