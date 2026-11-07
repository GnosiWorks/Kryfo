// SPDX-License-Identifier: GPL-3.0-or-later
// every string the engine returns is malloc'd on its side and ours once it
// is copied: it goes back through the engine's own free. a string that can
// hold a key, a pin or plaintext is zeroed first, so none of it lingers in
// freed native memory.

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'native_libs.dart';

typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);

/// takes the engine's place for a test, which counts what comes back
@visibleForTesting
void Function(Pointer<Utf8>)? engineFreeForTest;

// looked up once per isolate
final void Function(Pointer<Utf8>) _engineFree = lookupEngineFree(
  () => haloLibrary(),
  windows: Platform.isWindows,
);

/// the engine's own free. with no engine in the process (host tests) the
/// strings were made by the same libc malloc, so its free does. never on
/// windows: dart's malloc there is CoTaskMemFree, and the engine's strings
/// come from its own crt's heap, so a free by the wrong one corrupts the heap
@visibleForTesting
void Function(Pointer<Utf8>) lookupEngineFree(
  DynamicLibrary Function() open, {
  required bool windows,
}) {
  try {
    return open().lookupFunction<_FreeC, _FreeD>('HaloFree');
  } on ArgumentError {
    if (windows) rethrow;
    return malloc.free;
  }
}

// no real string sits in windows' first 64 KiB, which is never mapped: a
// pointer there is a broken call, said rather than read
const _lowest = 0x10000;

void _checkAddress(Pointer p) {
  if (p.address < _lowest) {
    throw StateError('engine string at a bad address');
  }
}

void _free(Pointer<Utf8> p) => (engineFreeForTest ?? _engineFree)(p);

/// the engine's string, copied into dart and freed
String engineTake(Pointer<Utf8> p) {
  if (p == nullptr) return '';
  _checkAddress(p);
  try {
    return p.toDartString();
  } finally {
    _free(p);
  }
}

/// as [engineTake], with the native bytes zeroed before they are freed
String engineTakeSecret(Pointer<Utf8> p) {
  if (p == nullptr) return '';
  _checkAddress(p);
  try {
    return p.toDartString();
  } finally {
    final n = p.length;
    p.cast<Uint8>().asTypedList(n).fillRange(0, n, 0);
    _free(p);
  }
}

/// as [engineTakeSecret] for a key the engine gives as hex: its bytes, and
/// no dart string made of it. null for anything but 64 hex digits (an
/// error the engine said)
Uint8List? engineTakeSecretKey(Pointer<Utf8> p) {
  if (p == nullptr) return null;
  _checkAddress(p);
  final n = p.length;
  final h = p.cast<Uint8>().asTypedList(n);
  try {
    if (n != 64) return null;
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      final hi = _nibble(h[2 * i]), lo = _nibble(h[2 * i + 1]);
      if (hi < 0 || lo < 0) {
        out.fillRange(0, 32, 0);
        return null;
      }
      out[i] = hi << 4 | lo;
    }
    return out;
  } finally {
    h.fillRange(0, n, 0);
    _free(p);
  }
}

int _nibble(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  return -1;
}

/// the bytes of a native string set to zero, up to its end
void zeroNative(Pointer<Utf8> p) {
  if (p == nullptr) return;
  final n = p.length;
  p.cast<Uint8>().asTypedList(n).fillRange(0, n, 0);
}

/// a string another native library made (the translation library), copied
/// into dart, zeroed and handed back to that library's own free. what it
/// holds is a message's words
String nativeTakeSecret(Pointer<Utf8> p, void Function(Pointer<Utf8>) free) {
  if (p == nullptr) return '';
  try {
    return p.toDartString();
  } finally {
    zeroNative(p);
    free(p);
  }
}

/// frees a native string made here that held a key, a pin, a passphrase or
/// plaintext for the engine, its bytes zeroed first
void freeSecret(Pointer<Utf8> p) {
  if (p == nullptr) return;
  zeroNative(p);
  malloc.free(p);
}
