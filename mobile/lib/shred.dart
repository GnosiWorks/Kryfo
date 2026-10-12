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

/// how long a copy handed to another app is given to be read
const kHandedGrace = Duration(minutes: 10);
const _clockSkew = Duration(minutes: 1);

/// the cache's folders of copies handed to another app that go with the
/// session that made them: opened with another app, and shared from a
/// hidden chat or the decoy. what the everyday side shares keeps its grace
/// (kSharedFolders)
const kSessionFolders = ['open', 'share_q'];

/// what the everyday side shared, and the share plugin's from before: an
/// app may read it only once this one is back, locked or not, so it stays
/// its grace and goes by the sweeps
const kSharedFolders = ['share', 'share_plus'];

/// what [kSessionFolders] hold goes with the session that made it. on a
/// lock or an unlock a copy still in its grace is only unlinked: an app
/// still reading it keeps its handle and the bytes, and the name is gone.
/// one past it is shredded. [all], for a switch to another pin's side,
/// shreds every one
Future<void> dropOpenCopies({
  bool all = false,
  Directory? cache,
  DateTime? now,
}) async {
  final Directory c;
  try {
    c = cache ?? await getTemporaryDirectory();
  } catch (e) {
    dlog('shred: no cache (${e.runtimeType})');
    return;
  }
  for (final name in kSessionFolders) {
    try {
      final dir = Directory('${c.path}/$name');
      if (all) {
        await shredTree(dir.path);
      } else {
        await sweepHanded(dir, unlinkYoung: true, now: now);
      }
    } catch (e) {
      dlog('shred: handed copies (${e.runtimeType})');
    }
  }
}

/// the copies handed out in [dir]: one past its grace, or dated so far
/// ahead the clock moved, is shredded. a younger one stays, or with
/// [unlinkYoung] loses its name. a link is unlinked, never followed. a
/// folder goes once emptied and old itself, or with [unlinkYoung] whole
Future<void> sweepHanded(
  Directory dir, {
  bool unlinkYoung = false,
  DateTime? now,
}) async {
  if (!await dir.exists()) return;
  final at = now ?? DateTime.now();
  final cutoff = at.subtract(kHandedGrace);
  final ahead = at.add(_clockSkew);
  bool old(DateTime t) => t.isBefore(cutoff) || t.isAfter(ahead);
  // a folder's time moves as its files go, so it is read first
  final folders = <(Directory, DateTime)>[];
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    try {
      if (e is Directory) {
        folders.add((e, (await e.stat()).modified));
      } else if (e is Link) {
        await e.delete();
      } else if (e is File) {
        if (old(await e.lastModified())) {
          await shredFile(e.path);
        } else if (unlinkYoung) {
          await _unlink(e);
        }
      }
    } on FileSystemException {
      // gone meanwhile
    }
  }
  if (unlinkYoung) {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // gone meanwhile
    }
    return;
  }
  // the deepest first
  folders.sort((a, b) => b.$1.path.length.compareTo(a.$1.path.length));
  for (final (d, t) in [...folders, (dir, cutoff)]) {
    if (!identical(d, dir) && !old(t)) continue;
    try {
      await d.delete();
    } on FileSystemException {
      // a young copy is still in it
    }
  }
}
