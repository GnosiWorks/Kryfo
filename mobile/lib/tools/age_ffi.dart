// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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

// the engine's entry, another name in tests to make the lookup fail
@visibleForTesting
String ageLockSymbol = 'HaloAgeLock';

/// one lock or open of a file, with a stop and a count of its own. the
/// engine keeps one of each for every job, so jobs take turns and only the
/// one running ever reaches them
class AgeJob {
  bool _stopped = false;
  final _stop = Completer<void>();

  void cancel() {
    _stopped = true;
    if (!_stop.isCompleted) _stop.complete();
    if (identical(_running, this)) _engineCancel();
  }

  /// bytes done, 0 while it waits its turn
  int progress() => identical(_running, this) ? _engineProgress() : 0;
}

AgeJob? _running;
Future<void> _turn = Future.value();

// one job in the engine at a time, in the order asked. one stopped while
// it waits answers at once and passes its turn on when the one before ends,
// after [inTurn]. a stop is said again while it runs: the engine clears it
// as a job begins. the turn is kept in the root zone, so a caller's zone
// that goes away never holds it
Future<T> _inTurn<T>(
  AgeJob job,
  Future<T> Function() body, {
  required T Function() stopped,
  void Function()? inTurn,
}) => Zone.root.run(() async {
  final before = _turn;
  final mine = Completer<void>();
  _turn = mine.future;
  await Future.any([before, job._stop.future]);
  if (job._stopped) {
    unawaited(
      before.then((_) {
        try {
          inTurn?.call();
        } catch (_) {
          // the caller already has its answer
        } finally {
          mine.complete();
        }
      }),
    );
    return stopped();
  }
  _running = job;
  final again = Timer.periodic(const Duration(milliseconds: 50), (_) {
    if (job._stopped) _engineCancel();
  });
  try {
    return await body();
  } finally {
    again.cancel();
    if (identical(_running, job)) _running = null;
    mine.complete();
  }
});

// the engine owns both descriptors once HaloAgeLock is called. until then
// they are this side's, and closed on any way out
Future<AgeError?> ageLock(
  int inFd,
  int outFd,
  String pass, [
  AgeJob? job,
]) async {
  final symbol = ageLockSymbol;
  final mine = job ?? AgeJob();
  return _inTurn(
    mine,
    stopped: () {
      closeFd(inFd);
      closeFd(outFd);
      return AgeError.cancelled;
    },
    () async {
      try {
        return await Isolate.run(() {
          var p = nullptr.cast<Utf8>();
          var handed = false;
          try {
            final lock = _lib().lookupFunction<_LockC, _LockD>(symbol);
            p = pass.toNativeUtf8();
            handed = true;
            return ageErrorOf(engineTake(lock(inFd, outFd, p)));
          } catch (_) {
            return AgeError.io;
          } finally {
            if (!handed) {
              closeFd(inFd);
              closeFd(outFd);
            }
            freeSecret(p);
          }
        });
      } catch (_) {
        // the body never throws: the isolate did not run, the descriptors are
        // still ours
        closeFd(inFd);
        closeFd(outFd);
        return AgeError.io;
      }
    },
  );
}

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

Future<AgeError?> ageOpenFinish(int outFd, [AgeJob? job]) {
  final mine = job ?? AgeJob();
  return _inTurn(
    mine,
    stopped: () {
      closeFd(outFd);
      return AgeError.cancelled;
    },
    // the engine's lock is free by then
    inTurn: ageOpenDrop,
    () => Isolate.run(
      () => ageErrorOf(
        engineTake(
          _lib().lookupFunction<_FinishC, _FinishD>('HaloAgeOpenFinish')(outFd),
        ),
      ),
    ),
  );
}

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
Future<AgeError?> ageLockPath(
  String inPath,
  String outPath,
  String pass, [
  AgeJob? job,
]) {
  final inFd = openFd(inPath);
  final outFd = inFd < 0 ? -1 : openFd(outPath, write: true);
  if (outFd < 0) {
    if (inFd >= 0) closeFd(inFd);
    return Future.value(AgeError.io);
  }
  return ageLock(inFd, outFd, pass, job);
}

void ageOpenDrop() =>
    _lib().lookupFunction<_VoidC, _VoidD>('HaloAgeOpenDrop')();

void _engineCancel() =>
    _lib().lookupFunction<_VoidC, _VoidD>('HaloAgeCancel')();

int _engineProgress() =>
    _lib().lookupFunction<_ProgressC, _ProgressD>('HaloAgeProgress')();

String suggestPassphrase() => engineTakeSecret(
  _lib().lookupFunction<_WordsC, _WordsD>('HaloSuggestPassphrase')(),
);
