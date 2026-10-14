// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../engine_strings.dart';

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
      engineTake(
        _lib().lookupFunction<_LockC, _LockD>('HaloAgeLock')(inFd, outFd, p),
      ),
    );
  } finally {
    freeSecret(p);
  }
});

Future<AgeError?> ageOpenBegin(int inFd, String pass) => Isolate.run(() {
  final p = pass.toNativeUtf8();
  try {
    return ageErrorOf(
      engineTake(
        _lib().lookupFunction<_BeginC, _BeginD>('HaloAgeOpenBegin')(inFd, p),
      ),
    );
  } finally {
    freeSecret(p);
  }
});

Future<AgeError?> ageOpenFinish(int outFd) => Isolate.run(
  () => ageErrorOf(
    engineTake(
      _lib().lookupFunction<_FinishC, _FinishD>('HaloAgeOpenFinish')(outFd),
    ),
  ),
);

typedef _OpenFdC = Int32 Function(Pointer<Utf8>, Int32, VarArgs<(Uint32,)>);
typedef _OpenFdD = int Function(Pointer<Utf8>, int, int);
typedef _CloseFdC = Int32 Function(Int32);
typedef _CloseFdD = int Function(int);

DynamicLibrary _libc() => Platform.isAndroid
    ? DynamicLibrary.open('libc.so')
    : DynamicLibrary.process();

// linux's flags, the same on arm, arm64 and x86
const _oWrite = 0x1, _oCreate = 0x40, _oExcl = 0x80, _oCloexec = 0x80000;

/// a descriptor of a file in the app's own folders, for the engine to read,
/// or to write as a new file only this app can read. -1 when it will not open
int openFd(String path, {bool write = false}) {
  final p = path.toNativeUtf8();
  try {
    return _libc().lookupFunction<_OpenFdC, _OpenFdD>('open')(
      p,
      write ? _oWrite | _oCreate | _oExcl | _oCloexec : _oCloexec,
      write ? 384 : 0, // 0600
    );
  } finally {
    calloc.free(p);
  }
}

void closeFd(int fd) =>
    _libc().lookupFunction<_CloseFdC, _CloseFdD>('close')(fd);

/// [inPath] locked into [outPath], which must not exist yet
Future<AgeError?> ageLockPath(String inPath, String outPath, String pass) {
  final inFd = openFd(inPath);
  final outFd = inFd < 0 ? -1 : openFd(outPath, write: true);
  if (outFd < 0) {
    if (inFd >= 0) closeFd(inFd);
    return Future.value(AgeError.io);
  }
  return ageLock(inFd, outFd, pass);
}

void ageOpenDrop() =>
    _lib().lookupFunction<_VoidC, _VoidD>('HaloAgeOpenDrop')();

void ageCancel() => _lib().lookupFunction<_VoidC, _VoidD>('HaloAgeCancel')();

int ageProgress() =>
    _lib().lookupFunction<_ProgressC, _ProgressD>('HaloAgeProgress')();

String suggestPassphrase() => engineTakeSecret(
  _lib().lookupFunction<_WordsC, _WordsD>('HaloSuggestPassphrase')(),
);
