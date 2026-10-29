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

import '../dlog.dart';

import 'desktop_vault.dart';
import 'sealed_file.dart';
import 'sealed_format.dart';
import 'sealed_io.dart';

const kFilesKeyEntry = 'kryfo.files';
const kOnionEntry = 'kryfo.onion';

/// the vault's word that an area's sweep finished: '*' or a container's
/// folder suffix
String sweptEntry(String area) => 'kryfo.swept.$area';

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

  /// [suffix] names the container's folders: a key a restore took from
  /// the vault before its database opened goes with the rest
  void closed(String id, [String? suffix]) {
    final n = (_count[id] ?? 0) - 1;
    if (n > 0) {
      _count[id] = n;
      return;
    }
    _count.remove(id);
    final k = areas.containerKeys.remove(_suffix.remove(id) ?? suffix);
    k?.fillRange(0, k.length, 0);
  }

  bool holds(String id) => (_count[id] ?? 0) > 0;

  /// the app ends: every key zeroed
  void closeAll() {
    for (final k in areas.containerKeys.values) {
      k.fillRange(0, k.length, 0);
    }
    areas.containerKeys.clear();
    _count.clear();
    _suffix.clear();
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
    // the copy is read back whole before the plain one is touched
    if (!_opens(tmp)) {
      rawFileAccess(() => File(tmp).deleteSync());
      continue;
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

// a whole sealed file: its head, and every chunk read through to the last
// one, before anything it stands in for is zeroed
bool _opens(String path) {
  if (rawFileAccess(() => File(path).lengthSync()) == 0 || _plain(path)) {
    return false;
  }
  try {
    final r = File(path).openSync();
    try {
      while (r.readSync(chunkPlain).isNotEmpty) {}
    } finally {
      r.closeSync();
    }
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

/// the engine's folder on desktop: in memory, so the names of its files
/// (which carry the start of receive keys) and their contents never reach
/// the disk as they are. what it keeps between runs is sealed: the onion
/// key as docs/onion.key, the relay marks in support/engine.state. tor's
/// own state stays on the disk through a link, docs/tor. windows makes a
/// link only for an admin or in developer mode, and its engine folder is
/// on the disk already: tor's is a real folder there, kept across starts
class EngineFiles {
  EngineFiles({
    required this.docs,
    required this.support,
    required this.runtime,
    bool? windows,
  }) : windows = windows ?? Platform.isWindows;

  final String docs;
  final String support;
  final String runtime;
  final bool windows;
  Timer? _watch;

  String get dir => p.join(runtime, kEngineFolder);
  String get _key => p.join(dir, 'onion.key');
  String get _sealedKey => p.join(docs, 'onion.key');
  String get _state => p.join(support, 'engine.state');
  static final _marks = RegExp(r'^nostr_(seen|last|heard)_');

  String get _anchorsEntry => 'kryfo.anchors';

  /// every start, before the engine: what memory held from before goes,
  /// the folder is laid out, an older layout is moved in, the marks come
  /// back from their sealed copy
  Future<void> prepare(DesktopVault vault) async {
    clearMemory();
    rawFileAccess(() {
      Directory(dir).createSync(recursive: true);
      Directory(p.join(docs, 'tor')).createSync(recursive: true);
      _linkTor();
    });
    await _fromOlderLayout(vault);
    _restoreMarks(vault);
  }

  // engine/tor is a link to docs/tor and nothing else: a real folder in
  // its place, a file or a link elsewhere goes first
  void _linkTor() {
    final at = p.join(dir, 'tor');
    final want = p.join(docs, 'tor');
    if (windows) return _torFolderOnWindows(at, want);
    switch (FileSystemEntity.typeSync(at, followLinks: false)) {
      case FileSystemEntityType.link:
        if (Link(at).targetSync() == want) return;
        Link(at).deleteSync();
      case FileSystemEntityType.directory:
        Directory(at).deleteSync(recursive: true);
      case FileSystemEntityType.notFound:
        break;
      default:
        File(at).deleteSync();
    }
    Link(at).createSync(want);
  }

  // a link a developer mode run made to docs/tor stays; any other link or
  // a file goes, and a real folder takes its place
  void _torFolderOnWindows(String at, String want) {
    switch (FileSystemEntity.typeSync(at, followLinks: false)) {
      case FileSystemEntityType.link:
        if (p.equals(Link(at).targetSync(), want)) return;
        Link(at).deleteSync();
      case FileSystemEntityType.directory:
        return;
      case FileSystemEntityType.notFound:
        break;
      default:
        File(at).deleteSync();
    }
    Directory(at).createSync(recursive: true);
  }

  // round two kept a link and the key in the vault; before that the key and
  // the marks lay plain in docs
  Future<void> _fromOlderLayout(DesktopVault vault) async {
    final type = FileSystemEntity.typeSync(_sealedKey, followLinks: false);
    if (type == FileSystemEntityType.link) {
      rawFileAccess(() => Link(_sealedKey).deleteSync());
      final kept = vault.read(kOnionEntry);
      if (kept != null) File(_sealedKey).writeAsBytesSync(base64.decode(kept));
    } else if (type == FileSystemEntityType.file && _plain(_sealedKey)) {
      _sealPlainKey();
    }
    if (vault.read(kOnionEntry) != null) await vault.delete(kOnionEntry);
    final old = rawFileAccess(
      () => Directory(docs)
          .listSync()
          .whereType<File>()
          .where((f) => _marks.hasMatch(p.basename(f.path)))
          .toList(),
    );
    if (old.isEmpty) return;
    final m = readMarkState(_state) ?? {};
    for (final f in old) {
      final name = p.basename(f.path);
      m[name] = base64.encode(
        rawFileAccess(() => File(f.path).readAsBytesSync()),
      );
      rawFileAccess(() {
        _zero(f.path);
        File(f.path).deleteSync();
      });
    }
    writeMarkState(_state, m);
  }

  // a plain docs/onion.key sealed where it lies: the sealed copy is written
  // and read back whole, the plain bytes zeroed, then the copy takes the
  // name. nothing is held open over the rename, which windows refuses. a
  // whole copy found beside it is such a run cut short, and wins
  void _sealPlainKey() {
    final fresh = '$_sealedKey.new';
    if (!rawFileAccess(() => File(fresh).existsSync()) || !_opens(fresh)) {
      final k = rawFileAccess(() => File(_sealedKey).readAsBytesSync());
      try {
        File(fresh).writeAsBytesSync(k, flush: true);
        final back = File(fresh).readAsBytesSync();
        final same = listEquals(back, k);
        back.fillRange(0, back.length, 0);
        if (!same) throw FileSystemException('not sealed whole', fresh);
      } finally {
        k.fillRange(0, k.length, 0);
      }
    }
    rawFileAccess(() {
      _zero(_sealedKey);
      File(fresh).renameSync(_sealedKey);
    });
  }

  void _restoreMarks(DesktopVault vault) {
    var m = readMarkState(_state);
    if (m == null) {
      // neither copy reads: the relays are read again from the last anchors
      // the vault holds, never from nothing
      dlog('engine marks: neither copy reads, catch-up starts at the anchors');
      m = {};
      final kept = vault.read(_anchorsEntry);
      if (kept != null) {
        try {
          m.addAll((jsonDecode(kept) as Map).cast<String, String>());
        } catch (_) {}
      }
    }
    rawFileAccess(() {
      for (final e in m!.entries) {
        if (!_marks.hasMatch(e.key) || e.key.contains('/')) continue;
        // whole or not at all: the engine never reads half a file
        final to = p.join(dir, e.key);
        File('$to.new').writeAsBytesSync(base64.decode(e.value), flush: true);
        File('$to.new').renameSync(to);
      }
    });
  }

  /// the marks as they are now, sealed into their copy, off the screen's
  /// isolate. the anchors go to the vault too, as the floor if both copies
  /// are ever lost
  Future<void> keepMarksOff(DesktopVault vault) async {
    final d = dir, st = _state;
    final anchors = await runSealed(() => keepMarksIn(d, st));
    await _keepAnchors(vault, anchors);
  }

  Future<void> _keepAnchors(DesktopVault vault, Map<String, String> a) async {
    if (a.isEmpty) return;
    final text = jsonEncode(a);
    if (vault.isOpen && vault.read(_anchorsEntry) != text) {
      await vault.write(_anchorsEntry, text);
    }
  }

  /// the same, here and now: as the app ends
  void keepMarks() => keepMarksIn(dir, _state);

  /// every minute: the marks kept, and a key the engine wrote sealed at
  /// once, though it stays for the engine until a start succeeds
  void watch(
    DesktopVault vault, {
    Duration every = const Duration(minutes: 1),
  }) {
    _watch ??= Timer.periodic(every, (_) async {
      try {
        sealNewKey();
        await keepMarksOff(vault);
      } catch (_) {}
    });
  }

  /// a key in the engine's folder that the sealed copy does not hold yet,
  /// sealed into it. the plain one stays
  void sealNewKey() {
    final k = rawFileAccess(() {
      final f = File(_key);
      return f.existsSync() ? f.readAsBytesSync() : null;
    });
    if (k == null || k.isEmpty) return;
    try {
      if (!File(_sealedKey).existsSync() ||
          !listEquals(File(_sealedKey).readAsBytesSync(), k)) {
        File('$_sealedKey.new').writeAsBytesSync(k, flush: true);
        rawFileAccess(() => File('$_sealedKey.new').renameSync(_sealedKey));
      }
    } finally {
      k.fillRange(0, k.length, 0);
    }
  }

  /// the engine's start: the onion key in its folder only while it reads
  /// it. a new one it made is sealed into docs/onion.key. after an error
  /// the key stays, for the engine's own retry
  Future<String> start(Future<String> Function(String dir) run) async {
    if (File(_sealedKey).existsSync()) {
      final k = File(_sealedKey).readAsBytesSync();
      rawFileAccess(() => File(_key).writeAsBytesSync(k, flush: true));
      k.fillRange(0, k.length, 0);
    }
    final r = await run(dir);
    if (!r.startsWith('error')) takeKey();
    return r;
  }

  /// a key the engine wrote kept sealed, and its plain copy zeroed
  void takeKey() {
    sealNewKey();
    rawFileAccess(() {
      if (!File(_key).existsSync()) return;
      _zero(_key);
      File(_key).deleteSync();
    });
  }

  /// the plain things memory holds: the onion key and the temporary files,
  /// zeroed and gone. at every start and as the app ends
  void clearMemory() {
    rawFileAccess(() {
      try {
        if (File(_key).existsSync()) {
          _zero(_key);
          File(_key).deleteSync();
        }
      } catch (_) {}
      final tmp = Directory(p.join(runtime, 'tmp'));
      if (!tmp.existsSync()) return;
      for (final e in tmp.listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            _zero(e.path);
          } catch (_) {}
        }
      }
      for (final e in tmp.listSync(followLinks: false)) {
        try {
          e.deleteSync(recursive: true);
        } catch (_) {}
      }
    });
  }

  /// the app ends: the marks kept, memory cleared
  void detach() {
    _watch?.cancel();
    try {
      keepMarks();
    } catch (_) {}
    clearMemory();
  }

  /// the wipe's: all of it zeroed and gone
  void destroy() {
    _watch?.cancel();
    clearMemory();
    rawFileAccess(() {
      try {
        final d = Directory(dir);
        for (final e in d.listSync(followLinks: false)) {
          if (e is File) _zero(e.path);
        }
        Directory(runtime).deleteSync(recursive: true);
      } catch (_) {}
    });
  }
}

/// the marks' sealed copy at [state], or its previous one when the newest
/// does not read (a write cut short). null when neither reads but one is
/// there; an empty map when there are none yet
@visibleForTesting
Map<String, String>? readMarkState(String state) {
  var any = false;
  for (final f in [state, '$state.old']) {
    if (!File(f).existsSync()) continue;
    any = true;
    try {
      return (jsonDecode(File(f).readAsStringSync()) as Map)
          .cast<String, String>();
    } catch (_) {}
  }
  return any ? null : {};
}

/// [m] as the newest copy; the one before is kept as the previous
@visibleForTesting
void writeMarkState(String state, Map<String, String> m) {
  final tmp = '$state.new';
  File(tmp).writeAsStringSync(jsonEncode(m), flush: true);
  rawFileAccess(() {
    if (File(state).existsSync()) File(state).renameSync('$state.old');
    File(tmp).renameSync(state);
  });
}

/// the marks in [dir] sealed into [state] when they changed. answers the
/// catch-up anchors (nostr_last_) as they are
Map<String, String> keepMarksIn(String dir, String state) {
  final marks = RegExp(r'^nostr_(seen|last|heard)_[0-9a-f]+$');
  final files = rawFileAccess(() {
    final d = Directory(dir);
    if (!d.existsSync()) return <File>[];
    return d
        .listSync()
        .whereType<File>()
        .where((f) => marks.hasMatch(p.basename(f.path)))
        .toList();
  });
  final m = {
    for (final f in files)
      p.basename(f.path): base64.encode(
        rawFileAccess(() => File(f.path).readAsBytesSync()),
      ),
  };
  if (!mapEquals(m, readMarkState(state))) writeMarkState(state, m);
  return {
    for (final e in m.entries)
      if (e.key.startsWith('nostr_last_')) e.key: e.value,
  };
}
