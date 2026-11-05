// SPDX-License-Identifier: GPL-3.0-or-later
// the few libc calls the desktop start needs, with linux's numbers for x64
// and arm64. linux only: on windows a lookup in the process opens kryfo.exe
// for reading first, which its own dacl refuses, so every call returns early
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final _libc = DynamicLibrary.process();
final _arm = Abi.current() == Abi.linuxArm64;

const _rdwr = 2, _creat = 64, _cloexec = 524288;
int get _nofollow => _arm ? 32768 : 131072;
int get _directory => _arm ? 16384 : 65536;
const _lockEx = 2, _lockNb = 4;

typedef _OpenC = Int32 Function(Pointer<Utf8>, Int32, Uint32);
typedef _Open = int Function(Pointer<Utf8>, int, int);
typedef _IntC = Int32 Function(Int32);
typedef _Int = int Function(int);
typedef _Int2C = Int32 Function(Int32, Int32);
typedef _Int2 = int Function(int, int);
typedef _UidC = Uint32 Function();
typedef _Uid = int Function();
typedef _StatC = Int32 Function(Pointer<Utf8>, Pointer<Uint8>);
typedef _Stat = int Function(Pointer<Utf8>, Pointer<Uint8>);
typedef _ExecC = Int32 Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>);
typedef _Exec = int Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>);

int _open(String path, int flags, [int mode = 0]) {
  final p = path.toNativeUtf8();
  try {
    return _libc.lookupFunction<_OpenC, _Open>('open')(p, flags, mode);
  } finally {
    calloc.free(p);
  }
}

int _close(int fd) => _libc.lookupFunction<_IntC, _Int>('close')(fd);

/// fsync of a folder, so a rename in it survives a cut. best effort
void syncFolder(String dir) {
  if (!Platform.isLinux) return;
  final fd = _open(dir, _directory | _cloexec);
  if (fd < 0) return;
  _libc.lookupFunction<_IntC, _Int>('fsync')(fd);
  _close(fd);
}

/// 0 off linux, where the folder's owner is checked by the runner
int getuid() =>
    Platform.isLinux ? _libc.lookupFunction<_UidC, _Uid>('getuid')() : 0;

/// the owner of [path] (lstat: a link is its own owner), null when unread
int? ownerOf(String path) {
  if (!Platform.isLinux) return null;
  final buf = calloc<Uint8>(256);
  final p = path.toNativeUtf8();
  try {
    if (_libc.lookupFunction<_StatC, _Stat>('lstat')(p, buf) != 0) return null;
    // st_uid sits at 28 in x64's struct stat, 24 in arm64's
    return (buf + (_arm ? 24 : 28)).cast<Uint32>().value;
  } finally {
    calloc.free(p);
    calloc.free(buf);
  }
}

// held for the life of the process; exec and exit let them go
final _locks = <String, int>{};

/// an exclusive kernel lock on [path], never through a link. false when
/// another process holds it or the file cannot be had
bool holdLock(String path) {
  if (!Platform.isLinux) return true;
  if (_locks.containsKey(path)) return true;
  final fd = _open(path, _rdwr | _creat | _nofollow | _cloexec, 384); // 0600
  if (fd < 0) return false;
  if (_libc.lookupFunction<_Int2C, _Int2>('flock')(fd, _lockEx | _lockNb) !=
      0) {
    _close(fd);
    return false;
  }
  _locks[path] = fd;
  return true;
}

/// this process becomes a new run of [exe]; returns only when exec failed
void execSelf(String exe) {
  if (!Platform.isLinux) return;
  final path = exe.toNativeUtf8();
  final argv = calloc<Pointer<Utf8>>(2);
  try {
    argv[0] = path;
    argv[1] = nullptr;
    _libc.lookupFunction<_ExecC, _Exec>('execv')(path, argv);
  } finally {
    calloc.free(argv);
    calloc.free(path);
  }
}
