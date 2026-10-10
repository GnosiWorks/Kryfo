// SPDX-License-Identifier: GPL-3.0-or-later
// a file that held plaintext is zeroed before it is unlinked. best effort:
// flash wear levelling can keep an old block, but the easy read is gone.
import 'dart:io';
import 'dart:typed_data';

import 'dlog.dart';

Future<void> shredFile(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return;
    final len = await f.length();
    final raf = await f.open(mode: FileMode.writeOnly);
    try {
      const chunk = 64 * 1024;
      final zeros = Uint8List(chunk);
      var left = len;
      while (left > 0) {
        final n = left < chunk ? left : chunk;
        await raf.writeFrom(zeros, 0, n);
        left -= n;
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
    await f.delete();
  } catch (e) {
    dlog('shred: $e');
  }
}

/// every file under [path] shredded, then the folder itself removed. a
/// plain file is shredded on its own. throws only when the folder stays
Future<void> shredTree(String path) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return;
  if (type != FileSystemEntityType.directory) {
    if (type == FileSystemEntityType.file) await shredFile(path);
    if (type == FileSystemEntityType.link) await Link(path).delete();
    return;
  }
  final d = Directory(path);
  await for (final e in d.list(recursive: true, followLinks: false)) {
    if (e is File) await shredFile(e.path);
  }
  await d.delete(recursive: true);
}
