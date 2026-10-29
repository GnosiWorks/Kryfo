// SPDX-License-Identifier: GPL-3.0-or-later
// what the computer account keeps for the vault when there is no
// passphrase: the system keyring on linux, dpapi on windows
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

/// why the system seal gave nothing back
enum SealFail {
  /// not there, or not this account's or computer's: it will not come back
  missing,

  /// there, but not now: a locked keyring, no service answering, a busy tpm
  unreachable,

  /// asked to keep a secret, it did not
  refused,
}

class SealError implements Exception {
  const SealError(this.why);
  final SealFail why;
  @override
  String toString() => 'SealError($why)';
}

/// a secret as the system keeps it: [how] says which seal, [data] is what
/// goes into the vault's file beside it (empty when the seal stores it)
class SealedSecret {
  const SealedSecret(this.how, this.data);
  final int how;
  final Uint8List data;
}

/// the ways a secret is kept, as written in the vault's slot
abstract final class SealHow {
  static const keyring = 1;
  static const dpapi = 2;
  static const tpm = 3;
}

abstract class SystemSeal {
  /// whether a secret can be kept here at all
  Future<bool> works();

  /// keeps [secret] for the vault [id]
  Future<SealedSecret> keep(Uint8List id, Uint8List secret);

  /// the secret kept for [id]. throws [SealError]
  Future<Uint8List> fetch(Uint8List id, int how, Uint8List data);

  /// whatever is kept for the vault [id] goes, whichever way its file says
  /// it was kept: a search first that never unlocks or asks, then a clear
  /// of what it found. true when nothing is left
  Future<bool> forget(Uint8List id);
}

/// blocking native calls run off the frame's thread
typedef SealRunner = Future<R> Function<R>(FutureOr<R> Function() f);

Future<R> offThread<R>(FutureOr<R> Function() f) => Isolate.run(f);

String hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
