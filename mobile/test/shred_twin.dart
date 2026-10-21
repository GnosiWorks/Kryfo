// SPDX-License-Identifier: GPL-3.0-or-later
// a hard link to a file shares its blocks, so once the file's name is gone
// it still shows what was left in them. zeros alone do not prove much: a
// file truncated and written again reads as zeros too, from new blocks,
// with the old ones freed and unread. so the link also notes where on the
// disk the file sat (filefrag), and a shred must leave it there
import 'dart:io';

final _where = <String, String>{};

// why the last read of the extents came back empty
String _miss = '';

/// the disk's answer for [path], a stand-in in the twin's own test
String? Function(String path) readExtents = extentsOf;

/// the physical extents of [path], once its bytes are on the disk. null
/// where the file system cannot say
String? extentsOf(String path) {
  final s = Process.runSync('sync', [path]);
  if (s.exitCode != 0) {
    _miss = 'sync ${s.exitCode}: ${s.stderr}'.trim();
    return null;
  }
  final r = Process.runSync('filefrag', ['-v', path]);
  if (r.exitCode != 0) {
    _miss = 'filefrag ${r.exitCode}: ${r.stderr}'.trim();
    return null;
  }
  final rows = [
    for (final l in (r.stdout as String).split('\n'))
      if (RegExp(r'^\s*\d+:').hasMatch(l))
        l.trim().split(RegExp(r'\s+')).take(5).join(' '),
  ];
  if (rows.isEmpty || rows.any((l) => l.contains('unknown'))) {
    _miss = 'no extents';
    return null;
  }
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

/// what the blocks under [twin] show instead of a shred, or null when they
/// hold something, all of it zeros, in the blocks the file had: overwritten
/// where they were, not freed for new ones. a read of the extents that
/// fails is asked again: a tool that cannot say has not seen a move
String? unshredded(File twin) {
  final b = twin.readAsBytesSync();
  if (b.isEmpty) return 'no bytes';
  final left = b.where((x) => x != 0).length;
  if (left > 0) return '$left of ${b.length} bytes not zero';
  final before = _where[twin.path];
  if (before == null) return null;
  for (var i = 0; i < 3; i++) {
    if (i > 0) sleep(const Duration(milliseconds: 200));
    final now = readExtents(twin.path);
    if (now == before) return null;
    if (now != null) return 'moved from [$before] to [$now]';
  }
  return 'extents unreadable ($_miss)';
}

bool zeroed(File twin) => unshredded(twin) == null;
