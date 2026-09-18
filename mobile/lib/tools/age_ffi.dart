// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _LockC = Pointer<Utf8> Function(Int32, Int32, Pointer<Utf8>);
typedef _LockD = Pointer<Utf8> Function(int, int, Pointer<Utf8>);
typedef _BeginC = Pointer<Utf8> Function(Int32, Pointer<Utf8>);
typedef _BeginD = Pointer<Utf8> Function(int, Pointer<Utf8>);
typedef _FinishC = Pointer<Utf8> Function(Int32);
typedef _FinishD = Pointer<Utf8> Function(int);
typedef _VoidC = Void Function();
typedef _VoidD = void Function();
typedef _ProgressC = Int64 Function();
typedef _ProgressD = int Function();
typedef _WordsC = Pointer<Utf8> Function();
typedef _WordsD = Pointer<Utf8> Function();

DynamicLibrary _lib() => Platform.isAndroid
    ? DynamicLibrary.open('libhalo.so')
    : DynamicLibrary.process();

enum AgeError {
  wrongPassword,
  corrupt,
  lockedToKey,
  notAge,
  needsMemory,
  cancelled,
  emptyPassword,
  io,
}

AgeError? ageErrorOf(String result) {
  if (result == 'ok') return null;
  return switch (result.replaceFirst('error: ', '')) {
    'wrong-password' => AgeError.wrongPassword,
    'corrupt' => AgeError.corrupt,
    'locked-to-key' => AgeError.lockedToKey,
    'not-age' => AgeError.notAge,
    'needs-memory' => AgeError.needsMemory,
    'cancelled' => AgeError.cancelled,
    'empty-password' => AgeError.emptyPassword,
    _ => AgeError.io,
  };
}

Future<AgeError?> ageLock(int inFd, int outFd, String pass) => Isolate.run(() {
  final p = pass.toNativeUtf8();
  try {
    return ageErrorOf(
      _lib()
          .lookupFunction<_LockC, _LockD>('HaloAgeLock')(inFd, outFd, p)
          .toDartString(),
    );
  } finally {
    malloc.free(p);
  }
});

Future<AgeError?> ageOpenBegin(int inFd, String pass) => Isolate.run(() {
  final p = pass.toNativeUtf8();
  try {
    return ageErrorOf(
      _lib()
          .lookupFunction<_BeginC, _BeginD>('HaloAgeOpenBegin')(inFd, p)
          .toDartString(),
    );
  } finally {
    malloc.free(p);
  }
});

Future<AgeError?> ageOpenFinish(int outFd) => Isolate.run(
  () => ageErrorOf(
    _lib()
        .lookupFunction<_FinishC, _FinishD>('HaloAgeOpenFinish')(outFd)
        .toDartString(),
  ),
);

void ageOpenDrop() =>
    _lib().lookupFunction<_VoidC, _VoidD>('HaloAgeOpenDrop')();

void ageCancel() => _lib().lookupFunction<_VoidC, _VoidD>('HaloAgeCancel')();

int ageProgress() =>
    _lib().lookupFunction<_ProgressC, _ProgressD>('HaloAgeProgress')();

String suggestPassphrase() => _lib()
    .lookupFunction<_WordsC, _WordsD>('HaloSuggestPassphrase')()
    .toDartString();
