// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop's wipe, after its keys are gone: every file in kryfo's folder
// removed, past the ones that will not go, and the folder itself. windows
// deletes no file another process still holds (tor.exe's own, the runner's
// lock), so what stays goes at the next start: a folder with no vault holds
// nothing that opens any more
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// the vault's file and its write on the way, in the data folder
const kVaultFiles = ['vault.kv', 'vault.kv.new'];

/// kept by a start's sweep: this run's lock, and the trace a run with
/// KRYFO_TRACE writes from its first step, and the engine's crash file
/// beside it
const kStartKeeps = {'lock', 'trace.txt', 'engine-crash.txt'};

/// every entry under [root] deleted, children first, each on its own so
/// one that stays never keeps the rest. tried again for [patience] while
/// anything is left; then [root] itself, when empty. what stayed, as paths
/// relative to [root]
Future<List<String>> clearDataDir(
  String root, {
  Duration patience = const Duration(seconds: 2),
  Set<String> keep = const {},
}) async {
  final until = DateTime.now().add(patience);
  while (true) {
    _clearOnce(root, keep);
    final left = leftIn(root, keep: keep);
    if (left.isEmpty || !DateTime.now().isBefore(until)) {
      if (keep.isEmpty) {
        try {
          Directory(root).deleteSync();
        } catch (_) {}
      }
      return left;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void _clearOnce(String root, Set<String> keep) {
  final d = Directory(root);
  if (!d.existsSync()) return;
  List<FileSystemEntity> top;
  try {
    top = d.listSync(followLinks: false);
  } catch (_) {
    return;
  }
  for (final e in top) {
    if (keep.contains(p.basename(e.path))) continue;
    _drop(e);
  }
}

// a link goes as a link, never what it points to
void _drop(FileSystemEntity e) {
  if (e is Directory) {
    try {
      for (final c in e.listSync(followLinks: false)) {
        _drop(c);
      }
    } catch (_) {}
  }
  try {
    e.deleteSync();
  } catch (_) {}
}

/// what is under [root] but [keep], as relative paths, sorted
List<String> leftIn(String root, {Set<String> keep = const {}}) {
  final d = Directory(root);
  if (!d.existsSync()) return const [];
  try {
    return [
      for (final e in d.listSync(recursive: true, followLinks: false))
        if (!keep.contains(p.split(p.relative(e.path, from: root)).first))
          p.relative(e.path, from: root),
    ]..sort();
  } catch (_) {
    return const [];
  }
}

/// at the start, before anything reads the folder: one with no vault is
/// what a wipe left, or a start that never made one. nothing in it opens,
/// so it all goes, plain files zeroed first. true when there was something
/// to clear
Future<bool> clearWithoutVault(String root) async {
  if (kVaultFiles.any((f) => File(p.join(root, f)).existsSync())) {
    return false;
  }
  if (leftIn(root, keep: kStartKeeps).isEmpty) return false;
  _zeroUnder(root);
  await clearDataDir(root, keep: kStartKeeps, patience: Duration.zero);
  return true;
}

// a database is ciphertext under a key already gone: unlinked only
final _sealed = RegExp(r'\.db(-wal|-shm|-journal)?$');

void _zeroUnder(String root) {
  final List<FileSystemEntity> all;
  try {
    all = Directory(root).listSync(recursive: true, followLinks: false);
  } catch (_) {
    return;
  }
  for (final e in all) {
    final name = p.basename(e.path);
    if (e is! File || _sealed.hasMatch(name)) continue;
    if (kStartKeeps.contains(p.relative(e.path, from: root))) continue;
    try {
      final n = e.lengthSync();
      final r = e.openSync(mode: FileMode.writeOnlyAppend);
      try {
        r.setPositionSync(0);
        for (var at = 0; at < n; at += 1 << 16) {
          r.writeFromSync(Uint8List(n - at < 1 << 16 ? n - at : 1 << 16));
        }
        r.flushSync();
      } finally {
        r.closeSync();
      }
    } catch (_) {}
  }
}
