// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's photos, voice notes and files sealed at rest: the desktop's
// seal (desktop/sealed_io.dart) over each container's media and wallpapers
// folders, under a key made from that container's database key. the hidden
// chats' database key exists only inside their pin entry, so their files
// open with nothing else. code outside dart gets the plaintext through
// memory or a stream, never as a plain file in those folders
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'container.dart';
import 'desktop/desktop_mode.dart';
import 'desktop/sealed_format.dart';
import 'desktop/sealed_io.dart';
import 'desktop/sealed_setup.dart'
    show ContainerKeys, SealSweep, mediaKeyOf, sealUnderJob;
import 'dlog.dart';

/// the seal over the media folders, once [openPhoneSeal] put it in place
SealedIO? get phoneSeal => _io;
SealedIO? _io;

/// where a copy for code that cannot reopen memory waits, for a moment
const kNativeCopies = 'native_in';

/// every file the app reads and writes from here on goes through the seal.
/// before anything touches a media folder
Future<void> openPhoneSeal() async {
  if (onDesktop || !Platform.isAndroid || _io != null) return;
  try {
    final docs = (await getApplicationDocumentsDirectory()).path;
    final support = (await getApplicationSupportDirectory()).path;
    final cache = (await getTemporaryDirectory()).path;
    installPhoneSeal(
      SealedAreas(docs: docs, support: support, runtime: cache, phone: true),
      const EngineChunkCrypto(),
    );
  } catch (e) {
    dlog('seal: not in place (${e.runtimeType})');
  }
}

/// the seal over [areas]: the hooks the shared code calls
@visibleForTesting
void installPhoneSeal(SealedAreas areas, ChunkCrypto crypto) {
  final io = SealedIO(areas, crypto);
  IOOverrides.global = io;
  _io = io;
  filesSealed = true;
  isolateRunner = <R>(FutureOr<R> Function() f) => runSealed(f);
  nativeFiles =
      <T>(
        List<String> ins,
        List<String> outs,
        Future<T> Function(List<String>, List<String>) run,
        bool Function(T)? ok,
      ) => nativeFilesPhone(io, ins, outs, run, ok);
  final keys = ContainerKeys(areas);
  containerOpened = (id, suffix, dbKey) {
    keys.opened(id, suffix, dbKey);
    // a restore's database under a new key while an old handle was open:
    // its files go under the new one
    final want = mediaKeyOf(dbKey, id);
    final held = areas.containerKeys[suffix];
    if (held != null && !listEquals(held, want)) {
      areas.containerKeys[suffix] = want;
      held.fillRange(0, held.length, 0);
    }
  };
  containerClosed = (id) =>
      keys.closed(id, HaloContainer.byId(id)?.folderSuffix);
  containerSettled = (c) => unawaited(sweepContainer(c));
  containersSwept = () => makeNumberedFolders(areas.docs);
  makeNumberedFolders(areas.docs);
  // copies a reader held when the app last stopped
  rawFileAccess(() {
    final d = Directory(p.join(areas.runtime!, kNativeCopies));
    if (d.existsSync()) {
      for (final e in d.listSync(followLinks: false)) {
        if (e is File) _shredNow(e.path);
      }
    }
  });
}

@visibleForTesting
void uninstallPhoneSealForTest() {
  _io = null;
  IOOverrides.global = null;
  filesSealed = false;
  isolateRunner = null;
  nativeFiles = null;
  containerOpened = null;
  containerClosed = null;
  containerSettled = null;
  containersSwept = null;
  _memfdWorks = null;
}

/// every container's media and wallpapers folders, on every install: their
/// names and their being there say nothing of a decoy or hidden chats
void makeNumberedFolders(String docs) {
  rawFileAccess(() {
    for (final c in HaloContainer.all) {
      for (final name in ['media', 'wallpapers']) {
        Directory(
          p.join(docs, '$name${c.folderSuffix}'),
        ).createSync(recursive: true);
      }
    }
  });
}

final _sweeping = <String>{};

/// the plain files of [c]'s folders sealed in place, off the screen's
/// isolate: a version before this one wrote them so, and a restore or the
/// engine may have since. one sweep per container at a time
Future<SealSweep?> sweepContainer(HaloContainer c) async {
  final io = _io;
  if (io == null || !_sweeping.add(c.folderSuffix)) return null;
  final total = SealSweep();
  try {
    for (final name in ['media', 'wallpapers']) {
      final d = p.join(io.areas.docs, '$name${c.folderSuffix}');
      try {
        final s = await runSealed(sealUnderJob(d));
        total
          ..sealed += s.sealed
          ..resumed += s.resumed;
      } catch (e) {
        // what stayed plain is tried again at the next open
        dlog('seal: a sweep left files (${e.runtimeType})');
      }
    }
  } finally {
    _sweeping.remove(c.folderSuffix);
  }
  return total;
}

/// the key one file's chunks open with, for code outside dart that reads it
/// through a stream: null when [path] is not sealed (outside the folders,
/// or a plain one not swept yet)
Uint8List? fileKeyOf(String path) {
  final io = _io;
  if (io == null || !io.areas.sealedPlace(path)) return null;
  final head = rawFileAccess(() {
    final f = File(path);
    if (!f.existsSync()) return null;
    final r = f.openSync();
    try {
      return r.readSync(sealedHead);
    } finally {
      r.closeSync();
    }
  });
  if (head == null || !isSealedHead(head)) return null;
  final k = io.areas.keyFor(path);
  return k == null ? null : fileKey(k, head);
}

bool _sealedHead(String path) => rawFileAccess(() {
  final f = File(path);
  if (!f.existsSync()) return false;
  final r = f.openSync();
  try {
    return isSealedHead(r.readSync(sealedHead));
  } finally {
    r.closeSync();
  }
});

/// [args] for a call that reads [path] outside dart, with the file's key
/// when it is sealed
Map<String, Object?> withFileKey(String path, Map<String, Object?> args) {
  try {
    final k = fileKeyOf(path);
    return k == null ? args : {...args, 'key': k};
  } on SealedLocked {
    return args;
  }
}

/// a sealed file's plaintext where code outside dart reads it by path
abstract class PlainView {
  String get path;
  void close();
}

class _Same implements PlainView {
  const _Same(this.path);
  @override
  final String path;
  @override
  void close() {}
}

/// [path] for a reader outside dart: itself when it is not sealed, else an
/// anonymous file in memory, or where the phone will not reopen one, a copy
/// in the cache that goes when [PlainView.close] is called
PlainView plainViewOf(String path) {
  final io = _io;
  if (io == null || !io.areas.sealedPlace(path) || !_sealedHead(path)) {
    return _Same(path);
  }
  final v = _emptyView(io.areas);
  try {
    final src = File(path).openSync();
    final dst = rawFileAccess(
      () => File(v.path).openSync(mode: FileMode.write),
    );
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
    return v;
  } catch (_) {
    v.close();
    rethrow;
  }
}

/// [path] too big for the reader that asked
class PlainTooBig implements Exception {
  const PlainTooBig();
}

/// a copy ended by its caller, the lock
class PlainStopped implements Exception {
  const PlainStopped();
}

/// [plainViewOf] a chunk at a time, letting the screen draw between them,
/// so a big file does not hold a frame. [most]: refused above it, in
/// plaintext bytes. [stop]: asked between chunks, true ends the copy (the
/// lock went up) and the view is closed
Future<PlainView> plainViewOfLater(
  String path, {
  int? most,
  bool Function()? stop,
}) async {
  final io = _io;
  if (io == null || !io.areas.sealedPlace(path) || !_sealedHead(path)) {
    if (most != null && File(path).lengthSync() > most) {
      throw const PlainTooBig();
    }
    return _Same(path);
  }
  if (most != null && File(path).lengthSync() > most) {
    throw const PlainTooBig();
  }
  final v = _emptyView(io.areas);
  RandomAccessFile? src, dst;
  try {
    final from = File(path).openSync();
    src = from;
    final to = rawFileAccess(() => File(v.path).openSync(mode: FileMode.write));
    dst = to;
    var n = 0;
    while (true) {
      final b = from.readSync(chunkPlain);
      if (b.isEmpty) break;
      to.writeFromSync(b);
      b.fillRange(0, b.length, 0);
      // a frame's room every few chunks
      if (++n % 8 == 0) {
        await Future<void>.delayed(Duration.zero);
        if (stop?.call() ?? false) throw const PlainStopped();
      }
    }
    to.flushSync();
    return v;
  } catch (_) {
    v.close();
    rethrow;
  } finally {
    src?.closeSync();
    dst?.closeSync();
  }
}

PlainView _emptyView(SealedAreas areas) {
  if (memfdWorks()) {
    final m = _MemView.create();
    if (m != null) return m;
  }
  return _CacheView.create(areas.runtime!);
}

/// the phone's withNativeFiles: a sealed input goes in as memory (or a
/// copy that goes at once), a sealed output comes back into place sealed
Future<T> nativeFilesPhone<T>(
  SealedIO io,
  List<String> ins,
  List<String> outs,
  Future<T> Function(List<String> ins, List<String> outs) run,
  bool Function(T answer)? ok,
) async {
  final views = <PlainView>[];
  try {
    final i = <String>[];
    for (final path in ins) {
      final v = plainViewOf(path);
      views.add(v);
      i.add(v.path);
    }
    final o = <String>[];
    final back = <(PlainView, String)>[];
    for (final path in outs) {
      if (io.areas.sealedPlace(path)) {
        final v = _emptyView(io.areas);
        views.add(v);
        back.add((v, path));
        o.add(v.path);
      } else {
        o.add(path);
      }
    }
    final r = await run(i, o);
    // what a failed write left is not kept
    if (ok != null && !ok(r)) return r;
    for (final (v, to) in back) {
      if (rawFileAccess(() => File(v.path).lengthSync()) == 0) continue;
      final src = rawFileAccess(() => File(v.path).openSync());
      final dst = File(to).openSync(mode: FileMode.write);
      try {
        while (true) {
          final b = src.readSync(chunkPlain);
          if (b.isEmpty) break;
          dst.writeFromSync(b);
          b.fillRange(0, b.length, 0);
        }
      } finally {
        src.closeSync();
        dst.closeSync();
      }
    }
    return r;
  } finally {
    for (final v in views) {
      v.close();
    }
  }
}

// ---- memory

typedef _MemfdC = Int32 Function(Pointer<Utf8>, Uint32);
typedef _Memfd = int Function(Pointer<Utf8>, int);
typedef _SyscallC = Long Function(Long, VarArgs<(Pointer<Utf8>, Uint32)>);
typedef _Syscall = int Function(int, Pointer<Utf8>, int);
typedef _CloseC = Int32 Function(Int32);
typedef _Close = int Function(int);

const _mfdCloexec = 1;

// memfd_create is in the c library from android 11; before that the kernel
// has it under its number
int _memfd() {
  final libc = DynamicLibrary.process();
  final n = 'k'.toNativeUtf8();
  try {
    try {
      return libc.lookupFunction<_MemfdC, _Memfd>('memfd_create')(
        n,
        _mfdCloexec,
      );
    } on ArgumentError {
      final nr = switch (Abi.current()) {
        Abi.androidArm64 => 279,
        Abi.androidArm => 385,
        Abi.androidX64 => 319,
        Abi.androidIA32 => 356,
        _ => -1,
      };
      if (nr < 0) return -1;
      return libc.lookupFunction<_SyscallC, _Syscall>('syscall')(
        nr,
        n,
        _mfdCloexec,
      );
    }
  } finally {
    calloc.free(n);
  }
}

bool? _memfdWorks;

/// whether an anonymous file can be made here and opened again by its path,
/// as a player or the engine opens it. asked once
bool memfdWorks() {
  final known = _memfdWorks;
  if (known != null) return known;
  var works = false;
  final m = _MemView.create();
  if (m != null) {
    try {
      rawFileAccess(() {
        File(m.path).writeAsBytesSync(const [7], flush: true);
        works = File(m.path).readAsBytesSync().single == 7;
      });
    } catch (_) {
      works = false;
    } finally {
      m.close();
    }
  }
  return _memfdWorks = works;
}

@visibleForTesting
set memfdWorksForTest(bool? v) => _memfdWorks = v;

class _MemView implements PlainView {
  _MemView(this.fd);
  final int fd;
  bool _closed = false;

  static _MemView? create() {
    try {
      final fd = _memfd();
      return fd < 0 ? null : _MemView(fd);
    } catch (_) {
      return null;
    }
  }

  @override
  String get path => '/proc/self/fd/$fd';

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    try {
      rawFileAccess(() {
        final f = File(path);
        final n = f.lengthSync();
        final r = f.openSync(mode: FileMode.writeOnlyAppend);
        try {
          r.setPositionSync(0);
          final z = Uint8List(chunkPlain);
          for (var left = n; left > 0; left -= z.length) {
            r.writeFromSync(z, 0, left < z.length ? left : z.length);
          }
        } finally {
          r.closeSync();
        }
      });
    } catch (_) {}
    DynamicLibrary.process().lookupFunction<_CloseC, _Close>('close')(fd);
  }
}

// ---- the cache, where memory will not do

final _rnd = Random.secure();

class _CacheView implements PlainView {
  _CacheView(this.path);
  @override
  final String path;

  static _CacheView create(String cache) {
    final d = Directory(p.join(cache, kNativeCopies));
    rawFileAccess(() => d.createSync(recursive: true));
    final leaf = [
      for (var i = 0; i < 16; i++)
        _rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    return _CacheView(p.join(d.path, leaf));
  }

  @override
  void close() => _shredNow(path);
}

void _shredNow(String path) {
  try {
    rawFileAccess(() {
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
      f.deleteSync();
    });
  } catch (_) {}
}
