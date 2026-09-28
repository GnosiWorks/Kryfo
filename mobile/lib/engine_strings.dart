// SPDX-License-Identifier: GPL-3.0-or-later
// every string the engine returns is malloc'd on its side and ours once it
// is copied: it goes back through the engine's own free. a string that can
// hold a key, a pin or plaintext is zeroed first, so none of it lingers in
// freed native memory.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);

/// takes the engine's place for a test, which counts what comes back
@visibleForTesting
void Function(Pointer<Utf8>)? engineFreeForTest;

// looked up once per isolate
final void Function(Pointer<Utf8>) _engineFree = _lookupFree();

void Function(Pointer<Utf8>) _lookupFree() {
  try {
    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    return lib.lookupFunction<_FreeC, _FreeD>('HaloFree');
  } on ArgumentError {
    // no engine in this process (host tests): what is taken here was made
    // by the same libc malloc
    return malloc.free;
  }
}

void _free(Pointer<Utf8> p) => (engineFreeForTest ?? _engineFree)(p);

/// the engine's string, copied into dart and freed
String engineTake(Pointer<Utf8> p) {
  if (p == nullptr) return '';
  try {
    return p.toDartString();
  } finally {
    _free(p);
  }
}

/// as [engineTake], with the native bytes zeroed before they are freed
String engineTakeSecret(Pointer<Utf8> p) {
  if (p == nullptr) return '';
  try {
    return p.toDartString();
  } finally {
    final n = p.length;
    p.cast<Uint8>().asTypedList(n).fillRange(0, n, 0);
    _free(p);
  }
}
