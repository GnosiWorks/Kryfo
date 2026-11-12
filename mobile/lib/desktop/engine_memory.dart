// SPDX-License-Identifier: GPL-3.0-or-later
// the engine's memory folder over ffi (engine/folder_mem_ffi.go): every
// file crosses as bytes, the native copies zeroed as they are freed
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../engine_strings.dart' show engineTake;
import '../native_libs.dart' show haloLibrary;
import 'desktop_mode.dart' show EngineMemory;

typedef _OnC = Void Function(Int32);
typedef _On = void Function(int);
typedef _PutC = Int32 Function(Pointer<Utf8>, Pointer<Uint8>, Int64);
typedef _Put = int Function(Pointer<Utf8>, Pointer<Uint8>, int);
typedef _GetC =
    Int32 Function(Pointer<Utf8>, Pointer<Pointer<Uint8>>, Pointer<Int64>);
typedef _Get =
    int Function(Pointer<Utf8>, Pointer<Pointer<Uint8>>, Pointer<Int64>);
typedef _NamesC = Pointer<Utf8> Function();
typedef _DropC = Void Function(Pointer<Utf8>);
typedef _Drop = void Function(Pointer<Utf8>);
typedef _FreeC = Void Function(Pointer<Uint8>, Int64);
typedef _Free = void Function(Pointer<Uint8>, int);

class EngineMemoryCalls implements EngineMemory {
  /// the engine's folder in memory from here on
  EngineMemoryCalls.on([DynamicLibrary? lib]) : _lib = lib ?? haloLibrary() {
    _lib.lookupFunction<_OnC, _On>('HaloFolderMemory')(1);
  }

  final DynamicLibrary _lib;
  late final _put = _lib.lookupFunction<_PutC, _Put>('HaloFolderPut');
  late final _get = _lib.lookupFunction<_GetC, _Get>('HaloFolderGet');
  late final _names = _lib.lookupFunction<_NamesC, _NamesC>('HaloFolderNames');
  late final _drop = _lib.lookupFunction<_DropC, _Drop>('HaloFolderDrop');
  late final _free = _lib.lookupFunction<_FreeC, _Free>('HaloFreeBytes');

  @override
  void put(String name, Uint8List b) {
    final n = name.toNativeUtf8(allocator: calloc);
    final p = calloc<Uint8>(b.isEmpty ? 1 : b.length);
    try {
      p.asTypedList(b.length).setAll(0, b);
      _put(n, p, b.length);
    } finally {
      p.asTypedList(b.length).fillRange(0, b.length, 0);
      calloc.free(p);
      calloc.free(n);
    }
  }

  @override
  Uint8List? get(String name) {
    final n = name.toNativeUtf8(allocator: calloc);
    final out = calloc<Pointer<Uint8>>();
    final len = calloc<Int64>();
    try {
      if (_get(n, out, len) != 1) return null;
      final b = Uint8List.fromList(out.value.asTypedList(len.value));
      _free(out.value, len.value);
      return b;
    } finally {
      calloc.free(n);
      calloc.free(out);
      calloc.free(len);
    }
  }

  @override
  List<String> names() {
    final all = engineTake(_names());
    return all.isEmpty ? const [] : all.split('\n');
  }

  @override
  void drop([String name = '']) {
    final n = name.toNativeUtf8(allocator: calloc);
    try {
      _drop(n);
    } finally {
      calloc.free(n);
    }
  }
}
