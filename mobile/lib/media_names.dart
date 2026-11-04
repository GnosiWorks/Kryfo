// SPDX-License-Identifier: GPL-3.0-or-later
// names on disk that say nothing: a container's folders go by number, and
// no file is named after what its sender called it. what an older version
// wrote is renamed as a container opens, files first and rows after, so a
// stop at any step leaves every file where the next open finds it
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'container.dart';
import 'desktop/desktop_mode.dart' show rawFiles;

/// [c]'s folders under their numbers and its files under neutral names,
/// rows and files together. every open: it finds nothing once done
Future<void> mediaNamesAtOpen(Database db, HaloContainer c, String docs) async {
  await _foldersByNumber(db, c, docs);
  await _neutralLeaves(db);
}

// the path columns that can name a file of the folders
const _pathCols = [
  ('messages', 'media_path'),
  ('messages', 'file_path'),
  ('file_fetches', 'path'),
  ('contacts', 'atmosphere'),
  ('groups', 'atmosphere'),
  ('wallpapers', 'atmo'),
];

Future<void> _foldersByNumber(Database db, HaloContainer c, String docs) async {
  final old = c.oldFolderSuffix;
  if (old.isEmpty) return;
  final moves = [
    for (final name in ['media', 'wallpapers'])
      ('$name$old', '$name${c.folderSuffix}'),
  ];
  for (final (from, to) in moves) {
    rawFiles(() => _merge(p.join(docs, from), p.join(docs, to)));
  }
  final have = await _columns(db);
  // the rows that still name a folder by its old name: none once done, and
  // then nothing is written
  final owed = <(String, String, String, String)>[];
  for (final (from, to) in moves) {
    for (final (table, col) in _pathCols) {
      if (!(have[table]?.contains(col) ?? false)) continue;
      final r = await db.rawQuery(
        'SELECT 1 FROM $table WHERE instr($col, ?) > 0 LIMIT 1',
        ['/$from/'],
      );
      if (r.isNotEmpty) owed.add((table, col, '/$from/', '/$to/'));
    }
  }
  if (owed.isEmpty) return;
  await db.transaction((t) async {
    for (final (table, col, from, to) in owed) {
      await t.execute(
        'UPDATE $table SET $col = replace($col, ?, ?) '
        'WHERE instr($col, ?) > 0',
        [from, to, from],
      );
    }
  });
}

// everything of [from] moved into [to], the folder renamed whole when it
// can be. a run cut short goes on from where it stopped
void _merge(String from, String to) {
  final src = Directory(from);
  if (!src.existsSync()) return;
  final dst = Directory(to);
  if (dst.existsSync() && dst.listSync().isEmpty) dst.deleteSync();
  if (!dst.existsSync()) {
    src.renameSync(to);
    return;
  }
  for (final e in src.listSync(followLinks: false)) {
    final at = p.join(to, p.basename(e.path));
    if (e is Directory) {
      _merge(e.path, at);
    } else if (FileSystemEntity.typeSync(at, followLinks: false) ==
        FileSystemEntityType.notFound) {
      e.renameSync(at);
    }
  }
  // one of the same name in both stays where it was, for a look by hand
  if (src.listSync().isEmpty) src.deleteSync();
}

Future<Map<String, Set<String>>> _columns(Database db) async {
  final out = <String, Set<String>>{};
  for (final table in {for (final (t, _) in _pathCols) t}) {
    final r = await db.rawQuery('PRAGMA table_info($table)');
    if (r.isNotEmpty) out[table] = {for (final c in r) c['name'] as String};
  }
  return out;
}

// a received file, or one sent as a file, under the name it came with
final _named = RegExp(r'^((?:in_[0-9a-f]{32})|(?:f_[0-9a-z]+))_(.+)$');

/// the name [leaf] goes by on disk, or null when it says nothing already
String? neutralLeaf(String leaf) {
  final m = _named.firstMatch(leaf);
  if (m == null) return null;
  return '${m.group(1)}${_typeOf(m.group(2)!)}';
}

String _typeOf(String name) {
  final m = RegExp(r'\.([A-Za-z0-9]{1,8})$').firstMatch(name);
  return m == null ? '' : '.${m.group(1)!.toLowerCase()}';
}

Future<void> _neutralLeaves(Database db) async {
  final rows = await db.rawQuery(
    'SELECT media_path, file_path FROM messages '
    "WHERE media_path GLOB '*/[if]*_*_*' OR file_path GLOB '*/[if]*_*_*'",
  );
  final paths = <String>{
    for (final r in rows)
      for (final v in [r['media_path'], r['file_path']])
        if (v is String && neutralLeaf(p.basename(v)) != null) v,
  };
  if (paths.isEmpty) return;
  final list = paths.toList();
  for (var i = 0; i < list.length; i += 100) {
    final part = list.sublist(i, i + 100 > list.length ? list.length : i + 100);
    await db.transaction((t) async {
      for (final old in part) {
        final now = p.join(p.dirname(old), neutralLeaf(p.basename(old))!);
        if (!_moveFile(old, now)) continue;
        for (final col in const ['media_path', 'file_path']) {
          await t.update(
            'messages',
            {col: now},
            where: '$col = ?',
            whereArgs: [old],
          );
        }
      }
    });
  }
}

// the file at [now], moved there or there already from a run cut short.
// false when it is in neither place, or in both
bool _moveFile(String old, String now) => rawFiles(() {
  final had = File(old).existsSync();
  final has = File(now).existsSync();
  if (had && !has) {
    File(old).renameSync(now);
    return true;
  }
  return !had && has;
});
