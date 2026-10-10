// SPDX-License-Identifier: GPL-3.0-or-later
// a file that held plaintext is zeroed before it is unlinked. best effort:
// flash wear levelling can keep an old block, but the easy read is gone.
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'dlog.dart';

/// zeros over [path] where its bytes are, then the name goes, also when a
/// write fails. a link is only unlinked, never followed. [probe] hears the
/// file's length after each write, for tests
Future<void> shredFile(String path, {void Function(int length)? probe}) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return;
  if (type == FileSystemEntityType.link) {
    await _unlink(Link(path));
    return;
  }
  final f = File(path);
  try {
    // append keeps the length and the blocks; a write mode would truncate
    // and the zeros would land in new blocks
    final raf = await f.open(mode: FileMode.append);
    try {
      final len = await raf.length();
      await raf.setPosition(0);
      const chunk = 64 * 1024;
      final zeros = Uint8List(chunk);
      var left = len;
      while (left > 0) {
        final n = left < chunk ? left : chunk;
        await raf.writeFrom(zeros, 0, n);
        left -= n;
        probe?.call(await raf.length());
      }
      await raf.flush();
      if (await raf.length() != len) dlog('shred: the length moved');
    } finally {
      await raf.close();
    }
  } catch (e) {
    dlog('shred: $e');
  } finally {
    await _unlink(f);
  }
}

Future<void> _unlink(FileSystemEntity e) async {
  try {
    await e.delete();
  } on PathNotFoundException {
    // gone already
  } catch (err) {
    dlog('shred: not unlinked (${err.runtimeType})');
  }
}

/// every file under [path] shredded, then the folder itself removed. a
/// plain file is shredded on its own, a link only unlinked. throws only
/// when the folder stays
Future<void> shredTree(String path) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return;
  if (type != FileSystemEntityType.directory) {
    await shredFile(path);
    return;
  }
  final d = Directory(path);
  await for (final e in d.list(recursive: true, followLinks: false)) {
    if (e is File) await shredFile(e.path);
  }
  await d.delete(recursive: true);
}

/// what was handed to another app to open: it goes with the session that
/// opened it, on a lock, a switch to another pin's side or a wipe
Future<void> shredOpenCopies([Directory? cache]) async {
  try {
    final c = cache ?? await getTemporaryDirectory();
    await shredTree('${c.path}/open');
  } catch (e) {
    dlog('shred: open copies (${e.runtimeType})');
  }
}
