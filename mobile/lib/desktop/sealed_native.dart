// SPDX-License-Identifier: GPL-3.0-or-later
// code outside dart (the engine's opus, gstreamer) reads and writes by
// path. a sealed file reaches it as an anonymous file in memory
// (memfd_create): its plaintext is copied in, the code gets
// /proc/self/fd/<n>, and what the code wrote there is sealed into place
// after. nothing plain touches the disk, but on windows, which has no
// memfd: there the copy is a file that goes when the code is done
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import 'sealed_io.dart';

typedef _MemfdC = Int32 Function(Pointer<Utf8>, Uint32);
typedef _Memfd = int Function(Pointer<Utf8>, int);
typedef _CloseC = Int32 Function(Int32);
typedef _Close = int Function(int);

const _mfdCloexec = 1;

/// a file code outside dart reads or writes by [path], gone at [close]
abstract interface class NativeCopy {
  String get path;
  void close();
}

/// stands in for a system without memfd_create (windows) in tests
@visibleForTesting
bool noMemfdForTest = false;

/// an anonymous file in memory, open until [close]
class MemFile implements NativeCopy {
  MemFile._(this.fd);

  final int fd;
  bool _closed = false;

  /// the path code outside dart opens it by
  @override
  String get path => '/proc/self/fd/$fd';

  static MemFile create() {
    if (noMemfdForTest) throw const FileSystemException('no memfd');
    final libc = DynamicLibrary.process();
    final f = libc.lookupFunction<_MemfdC, _Memfd>('memfd_create');
    final n = 'kryfo'.toNativeUtf8();
    try {
      final fd = f(n, _mfdCloexec);
      if (fd < 0) throw const FileSystemException('no memfd');
      return MemFile._(fd);
    } finally {
      calloc.free(n);
    }
  }

  /// its bytes zeroed, then let go
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    rawFileAccess(() {
      try {
        final f = File(path);
        final n = f.lengthSync();
        final r = f.openSync(mode: FileMode.writeOnlyAppend);
        r.setPositionSync(0);
        r.writeFromSync(List.filled(n, 0));
        r.closeSync();
      } catch (_) {}
    });
    DynamicLibrary.process().lookupFunction<_CloseC, _Close>('close')(fd);
  }
}

/// where there is no memfd (windows): a plain copy under a random name in
/// [dir], zeroed and deleted the moment the reader is done
class DiskCopy implements NativeCopy {
  DiskCopy._(this.path);
  @override
  final String path;

  static final _rnd = Random.secure();

  static DiskCopy create(String dir) {
    rawFileAccess(() => Directory(dir).createSync(recursive: true));
    final leaf = [
      for (var i = 0; i < 16; i++)
        _rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final c = DiskCopy._(p.join(dir, leaf));
    rawFileAccess(() => File(c.path).writeAsBytesSync(const []));
    return c;
  }

  @override
  void close() {
    rawFileAccess(() {
      try {
        final f = File(path);
        if (!f.existsSync()) return;
        final n = f.lengthSync();
        final r = f.openSync(mode: FileMode.writeOnlyAppend);
        try {
          r.setPositionSync(0);
          final z = Uint8List(1 << 16);
          for (var left = n; left > 0; left -= z.length) {
            r.writeFromSync(z, 0, left < z.length ? left : z.length);
          }
          r.flushSync();
        } finally {
          r.closeSync();
        }
        f.deleteSync();
      } catch (_) {}
    });
  }
}

/// memory where the system has memfd, else a copy in [spill]
NativeCopy _newCopy(String? spill) {
  try {
    return MemFile.create();
  } catch (_) {
    if (spill == null) rethrow;
    return DiskCopy.create(spill);
  }
}

/// [sealed] read through the seam into memory, a block at a time
MemFile memCopyOf(String sealed) {
  final m = MemFile.create();
  try {
    _fill(m, sealed);
    return m;
  } catch (_) {
    m.close();
    rethrow;
  }
}

// [sealed]'s plaintext into [c]
void _fill(NativeCopy c, String sealed) {
  final src = File(sealed).openSync();
  final dst = rawFileAccess(
    () => File(c.path).openSync(mode: FileMode.writeOnly),
  );
  try {
    while (true) {
      final b = src.readSync(1 << 16);
      if (b.isEmpty) break;
      dst.writeFromSync(b);
      b.fillRange(0, b.length, 0);
    }
  } finally {
    src.closeSync();
    dst.closeSync();
  }
}

/// what code outside dart wrote into [m], sealed at [to]
void sealFromMem(NativeCopy m, String to) {
  final src = rawFileAccess(() => File(m.path).openSync());
  final dst = File(to).openSync(mode: FileMode.write);
  try {
    while (true) {
      final b = src.readSync(1 << 16);
      if (b.isEmpty) break;
      dst.writeFromSync(b);
      b.fillRange(0, b.length, 0);
    }
  } finally {
    src.closeSync();
    dst.closeSync();
  }
}

/// the desktop's withNativeFiles: a sealed input goes in as memory, a
/// sealed output comes back from memory into place. a plain one is passed
/// as it is. without memfd (windows) the copies are plain files in [spill]
/// that go when the code is done
Future<T> nativeFilesSealed<T>(
  SealedAreas areas,
  List<String> ins,
  List<String> outs,
  Future<T> Function(List<String> ins, List<String> outs) run, [
  bool Function(T answer)? ok,
  String? spill,
]) async {
  final mems = <NativeCopy>[];
  try {
    final i = <String>[];
    for (final path in ins) {
      if (areas.sealedPlace(path) && File(path).existsSync()) {
        final m = _newCopy(spill);
        mems.add(m);
        _fill(m, path);
        i.add(m.path);
      } else {
        i.add(path);
      }
    }
    final o = <String>[];
    final back = <(NativeCopy, String)>[];
    for (final path in outs) {
      if (areas.sealedPlace(path)) {
        final m = _newCopy(spill);
        mems.add(m);
        back.add((m, path));
        o.add(m.path);
      } else {
        o.add(path);
      }
    }
    final r = await run(i, o);
    // what a failed write left is not kept
    if (ok != null && !ok(r)) return r;
    for (final (m, to) in back) {
      if (rawFileAccess(() => File(m.path).lengthSync()) > 0) {
        sealFromMem(m, to);
      }
    }
    return r;
  } finally {
    for (final m in mems) {
      m.close();
    }
  }
}
