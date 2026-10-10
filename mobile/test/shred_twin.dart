// SPDX-License-Identifier: GPL-3.0-or-later
// a hard link to a file shares its blocks, so once the file's name is gone
// it still shows what was left in them. zeros alone do not prove much: a
// file truncated and written again reads as zeros too, from new blocks,
// with the old ones freed and unread. so the link also notes where on the
// disk the file sat (filefrag), and a shred must leave it there
import 'dart:io';

final _where = <String, String>{};

/// the physical extents of [path], once its bytes are on the disk. null
/// where the file system cannot say
String? extentsOf(String path) {
  final s = Process.runSync('sync', [path]);
  if (s.exitCode != 0) return null;
  final r = Process.runSync('filefrag', ['-v', path]);
  if (r.exitCode != 0) return null;
  final rows = [
    for (final l in (r.stdout as String).split('\n'))
      if (RegExp(r'^\s*\d+:').hasMatch(l))
        l.trim().split(RegExp(r'\s+')).take(5).join(' '),
  ];
  if (rows.isEmpty || rows.any((l) => l.contains('unknown'))) return null;
  return rows.join('\n');
}

/// a hard link to [path] in [into], a folder no sweep under test touches
File twinOf(String path, Directory into) {
  final twin = File('${into.path}/${into.listSync().length}.twin');
  final r = Process.runSync('ln', [path, twin.path]);
  if (r.exitCode != 0) throw StateError('ln: ${r.stderr}');
  final at = extentsOf(twin.path);
  if (at != null) _where[twin.path] = at;
  return twin;
}

/// the blocks hold something, all of it zeros, and they are the blocks the
/// file had: overwritten where they were, not freed for new ones
bool zeroed(File twin) {
  final b = twin.readAsBytesSync();
  if (b.isEmpty || b.any((x) => x != 0)) return false;
  final before = _where[twin.path];
  return before == null || extentsOf(twin.path) == before;
}
