// SPDX-License-Identifier: GPL-3.0-or-later
// a chunk key the engine holds: it crosses once as bytes, the native copy
// zeroed at once, and every chunk after names it by a handle. a backup or a
// restore holds one for its whole run; a one-off seal opens and drops one

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _OpenC = Int64 Function(Pointer<Uint8>, Int32);
typedef _Open = int Function(Pointer<Uint8>, int);
typedef _DropC = Void Function(Int64);
typedef _Drop = void Function(int);
typedef _ChunkC =
    Int32 Function(Int64, Uint64, Uint8, Pointer<Uint8>, Int32, Pointer<Uint8>);
typedef ChunkCall =
    int Function(int, int, int, Pointer<Uint8>, int, Pointer<Uint8>);

class ChunkKeys {
  ChunkKeys(DynamicLibrary lib)
    : _open = lib.lookupFunction<_OpenC, _Open>('HaloChunkKeyOpen'),
      _drop = lib.lookupFunction<_DropC, _Drop>('HaloChunkKeyDrop'),
      seal = lib.lookupFunction<_ChunkC, ChunkCall>('HaloSealChunk'),
      open = lib.lookupFunction<_ChunkC, ChunkCall>('HaloOpenChunk');

  final _Open _open;
  final _Drop _drop;
  final ChunkCall seal;
  final ChunkCall open;

  /// a handle on [key], 0 when the engine took none. [key] stays the
  /// caller's to zero
  int take(Uint8List key) {
    final p = calloc<Uint8>(key.length);
    try {
      p.asTypedList(key.length).setAll(0, key);
      return _open(p, key.length);
    } finally {
      p.asTypedList(key.length).fillRange(0, key.length, 0);
      calloc.free(p);
    }
  }

  void drop(int handle) {
    if (handle > 0) _drop(handle);
  }
}
