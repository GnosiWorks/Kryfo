// SPDX-License-Identifier: GPL-3.0-or-later
// a hard link to a file shares its blocks, so once the file's name is gone
// it still shows what was left in them: zeros after a shred, the plaintext
// after a plain unlink
import 'dart:io';

/// a hard link to [path] in [into], a folder no sweep under test touches
File twinOf(String path, Directory into) {
  final twin = File('${into.path}/${into.listSync().length}.twin');
  final r = Process.runSync('ln', [path, twin.path]);
  if (r.exitCode != 0) throw StateError('ln: ${r.stderr}');
  return twin;
}

/// the blocks hold something, and all of it zeros
bool zeroed(File twin) {
  final b = twin.readAsBytesSync();
  return b.isNotEmpty && b.every((x) => x == 0);
}
