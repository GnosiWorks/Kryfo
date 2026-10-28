// SPDX-License-Identifier: GPL-3.0-or-later
// the seal put in place once the vault opens: the keys of the places it
// covers, the files a version before it left plain, the same set of
// container files for every install, and the onion key in the vault
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'desktop_vault.dart';
import 'sealed_file.dart';
import 'sealed_format.dart';
import 'sealed_io.dart';

const kFilesKeyEntry = 'kryfo.files';
const kOnionEntry = 'kryfo.onion';

/// a container's files key, from its database key: no second secret to
/// keep, and it goes wherever that key goes (the vault, or a pin entry)
Uint8List mediaKeyOf(String dbKey, String containerId) => Uint8List.fromList(
  Hmac(
    sha256,
    utf8.encode(dbKey),
  ).convert(utf8.encode('kryfo media $containerId')).bytes,
);

/// the key of everything else kryfo keeps, made once and kept in the vault
Future<Uint8List> filesKeyFrom(DesktopVault vault) async {
  final kept = vault.read(kFilesKeyEntry);
  if (kept != null) return keyOfText(kept);
  final k = randomBytes(32);
  await vault.write(kFilesKeyEntry, keyText(k));
  return k;
}

/// containers' keys while their databases are open, by folder suffix. two
/// handles on one container keep it open until both close
class ContainerKeys {
  ContainerKeys(this.areas, {this.onOpened});

  final SealedAreas areas;

  /// a container's folders just became readable: the start's sweep runs
  final void Function(String suffix)? onOpened;
  final _count = <String, int>{};
  final _suffix = <String, String>{};

  void opened(String id, String suffix, String dbKey) {
    final n = _count[id] ?? 0;
    _count[id] = n + 1;
    _suffix[id] = suffix;
    if (n > 0) return;
    areas.containerKeys[suffix] = mediaKeyOf(dbKey, id);
    onOpened?.call(suffix);
  }

  void closed(String id) {
    final n = (_count[id] ?? 0) - 1;
    if (n > 0) {
      _count[id] = n;
      return;
    }
    _count.remove(id);
    final k = areas.containerKeys.remove(_suffix.remove(id));
    k?.fillRange(0, k.length, 0);
  }
}

/// what the sweep did, for its tests
class SealSweep {
  int sealed = 0;
  int resumed = 0;
}

/// every plain file under [dir] sealed in place, the plain bytes zeroed
/// before the sealed copy takes the name. a sweep cut short is picked up:
/// a whole sealed copy beside its file wins, a broken one goes
SealSweep sealPlainUnder(String dir) {
  final out = SealSweep();
  final d = rawFileAccess(() => Directory(dir));
  if (!d.existsSync()) return out;
  final files = rawFileAccess(
    () => d
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .toList(),
  );
  final names = {for (final f in files) f.path};
  for (final f in files) {
    final path = f.path;
    if (path.endsWith('.sealing')) {
      final orig = path.substring(0, path.length - '.sealing'.length);
      if (_opens(path)) {
        rawFileAccess(() {
          _zero(orig);
          File(path).renameSync(orig);
        });
        out.resumed++;
      } else {
        rawFileAccess(() => File(path).deleteSync());
      }
      continue;
    }
    if (names.contains('$path.sealing')) continue;
    if (!_plain(path)) continue;
    final tmp = '$path.sealing';
    // the copy through the seam is sealed: same folder, same key
    final src = rawFileAccess(() => File(path).openSync());
    final dst = File(tmp).openSync(mode: FileMode.write);
    try {
      while (true) {
        final b = src.readSync(chunkPlain);
        if (b.isEmpty) break;
        dst.writeFromSync(b);
        b.fillRange(0, b.length, 0);
      }
      dst.flushSync();
    } finally {
      src.closeSync();
      dst.closeSync();
    }
    rawFileAccess(() {
      _zero(path);
      File(tmp).renameSync(path);
    });
    out.sealed++;
  }
  return out;
}

bool _plain(String path) => rawFileAccess(() {
  final f = File(path);
  final n = f.lengthSync();
  if (n == 0) return false;
  final r = f.openSync();
  try {
    return !isSealedHead(r.readSync(sealedHead));
  } finally {
    r.closeSync();
  }
});

// a whole sealed file: its head, and every chunk to the last one opens
bool _opens(String path) {
  if (rawFileAccess(() => File(path).lengthSync()) == 0 || _plain(path)) {
    return false;
  }
  try {
    final r = File(path).openSync();
    r.closeSync();
    return true;
  } on SealedDamaged {
    return false;
  } on FileSystemException {
    return false;
  }
}

// the bytes overwritten in place, flushed
void _zero(String path) {
  final f = File(path);
  if (!f.existsSync()) return;
  final n = f.lengthSync();
  final r = f.openSync(mode: FileMode.writeOnlyAppend);
  try {
    r.setPositionSync(0);
    final z = Uint8List(chunkPlain);
    for (var left = n; left > 0; left -= z.length) {
      r.writeFromSync(z, 0, left < z.length ? left : z.length);
    }
    r.flushSync();
  } finally {
    r.closeSync();
  }
}

/// the numbered containers every install has on disk, decoy and hidden
/// chats or not: a database of random bytes where none is, and the folders
/// beside it. the app takes one for an unopened container, as a phone
/// takes one a pin may open; a new decoy or vault clears its place first
@visibleForTesting
const placeholderSets = [
  ('k2.db', ['media_k2', 'wallpapers_k2']),
  ('k3.db', ['media_k3', 'wallpapers_k3']),
  ('k4.db', ['media_k4', 'wallpapers_k4']),
];

void makePlaceholders(String docs, {Random? random}) {
  final rnd = random ?? Random.secure();
  rawFileAccess(() {
    for (final (db, folders) in placeholderSets) {
      final f = File(p.join(docs, db));
      if (!f.existsSync()) {
        // the size of a database that holds a few chats
        final pages = 40 + rnd.nextInt(80);
        final r = f.openSync(mode: FileMode.write);
        try {
          for (var i = 0; i < pages; i++) {
            r.writeFromSync(List.generate(4096, (_) => rnd.nextInt(256)));
          }
          r.flushSync();
        } finally {
          r.closeSync();
        }
      }
      for (final d in folders) {
        Directory(p.join(docs, d)).createSync(recursive: true);
      }
    }
  });
}

/// docs/onion.key: the engine reads and writes it by path, so it is a
/// link to a file in memory, filled from the vault before the engine
/// starts and read back into the vault when the engine or a restore wrote
/// a new one
class OnionKeyLink {
  OnionKeyLink({
    required this.docs,
    required this.runtime,
    required this.vault,
  });

  final String docs;
  final String runtime;
  final DesktopVault vault;
  Timer? _watch;

  String get _link => p.join(docs, 'onion.key');
  String get _target => p.join(runtime, 'onion.key');

  /// before the engine starts
  Future<void> place() async {
    await rawFileAccess(() async {
      final link = Link(_link);
      final type = FileSystemEntity.typeSync(_link, followLinks: false);
      if (type == FileSystemEntityType.file) {
        // one a version before this left plain: into the vault, then gone
        final k = File(_link).readAsBytesSync();
        if (k.isNotEmpty) await vault.write(kOnionEntry, base64.encode(k));
        _zero(_link);
        File(_link).deleteSync();
      }
      await pull();
      final kept = vault.read(kOnionEntry);
      final t = File(_target);
      if (!t.existsSync() && kept != null) {
        t.writeAsBytesSync(base64.decode(kept), flush: true);
      }
      if (FileSystemEntity.typeSync(_link, followLinks: false) !=
              FileSystemEntityType.link ||
          link.targetSync() != _target) {
        if (link.existsSync()) link.deleteSync();
        link.createSync(_target);
      }
    });
  }

  /// a key written into memory since, kept in the vault
  Future<void> pull() async {
    final t = rawFileAccess(() => File(_target));
    if (!t.existsSync()) return;
    final now = base64.encode(t.readAsBytesSync());
    if (now.isEmpty || vault.read(kOnionEntry) == now) return;
    await vault.write(kOnionEntry, now);
  }

  void watch({Duration every = const Duration(seconds: 10)}) {
    _watch ??= Timer.periodic(
      every,
      (_) => unawaited(pull().catchError((_) {})),
    );
  }

  /// the wipe's: the key in memory zeroed and gone
  void destroy() {
    _watch?.cancel();
    rawFileAccess(() {
      try {
        _zero(_target);
        File(_target).deleteSync();
      } catch (_) {}
    });
  }
}
