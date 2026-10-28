// SPDX-License-Identifier: GPL-3.0-or-later
// code outside dart (the engine's opus, gstreamer) reads and writes by
// path. a sealed file reaches it as an anonymous file in memory
// (memfd_create): its plaintext is copied in, the code gets
// /proc/self/fd/<n>, and what the code wrote there is sealed into place
// after. nothing plain touches the disk
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'sealed_io.dart';

typedef _MemfdC = Int32 Function(Pointer<Utf8>, Uint32);
typedef _Memfd = int Function(Pointer<Utf8>, int);
typedef _CloseC = Int32 Function(Int32);
typedef _Close = int Function(int);

const _mfdCloexec = 1;

/// an anonymous file in memory, open until [close]
class MemFile {
  MemFile._(this.fd);

  final int fd;
  bool _closed = false;

  /// the path code outside dart opens it by
  String get path => '/proc/self/fd/$fd';

  static MemFile create() {
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

/// [sealed] read through the seam into memory, a block at a time
MemFile memCopyOf(String sealed) {
  final m = MemFile.create();
  try {
    final src = File(sealed).openSync();
    final dst = rawFileAccess(
      () => File(m.path).openSync(mode: FileMode.writeOnly),
    );
    try {
      while (true) {
        final b = src.readSync(1 << 16);
        if (b.isEmpty) break;
        dst.writeFromSync(b);
      }
    } finally {
      src.closeSync();
      dst.closeSync();
    }
    return m;
  } catch (_) {
    m.close();
    rethrow;
  }
}

/// what code outside dart wrote into [m], sealed at [to]
void sealFromMem(MemFile m, String to) {
  final src = rawFileAccess(() => File(m.path).openSync());
  final dst = File(to).openSync(mode: FileMode.write);
  try {
    while (true) {
      final b = src.readSync(1 << 16);
      if (b.isEmpty) break;
      dst.writeFromSync(b);
    }
  } finally {
    src.closeSync();
    dst.closeSync();
  }
}

/// the desktop's withNativeFiles: a sealed input goes in as memory, a
/// sealed output comes back from memory into place. a plain one is passed
/// as it is
Future<T> nativeFilesSealed<T>(
  SealedAreas areas,
  List<String> ins,
  List<String> outs,
  Future<T> Function(List<String> ins, List<String> outs) run,
) async {
  final mems = <MemFile>[];
  try {
    final i = <String>[];
    for (final path in ins) {
      if (areas.sealedPlace(path) && File(path).existsSync()) {
        final m = memCopyOf(path);
        mems.add(m);
        i.add(m.path);
      } else {
        i.add(path);
      }
    }
    final o = <String>[];
    final back = <(MemFile, String)>[];
    for (final path in outs) {
      if (areas.sealedPlace(path)) {
        final m = MemFile.create();
        mems.add(m);
        back.add((m, path));
        o.add(m.path);
      } else {
        o.add(path);
      }
    }
    final r = await run(i, o);
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
