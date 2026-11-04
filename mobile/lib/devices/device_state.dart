// SPDX-License-Identifier: GPL-3.0-or-later
// the linked-devices state in the engine (engine/dev_ffi.go,
// dev_session.go): the engine holds every contact's device list, my own
// lists, the quiet devices and the pool, loaded at the start from the
// rows of device_store.dart. every call that changes them answers with
// the rows to write, written here in one transaction with whatever the
// caller writes, before anything is sent. list signatures are checked by
// the engine through the signal library, never here
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../engine_strings.dart' show engineTake;
import 'device_store.dart';
import 'linked_switch.dart';

bool _onForTest = false;

/// the switch, as the app reads it: off in every build until linking is
/// wired end to end, and then nothing here runs and every table stays empty
bool get linkedDevicesOn => kLinkedDevicesOn || _onForTest;

@visibleForTesting
set linkedDevicesForTest(bool on) => _onForTest = on;

/// what libsignal's decrypt returned as the remote identity of a message
/// that opened: the only remote the engine takes as a source. made only by
/// the session layer (app/signal.dart), right where ks_decrypt_* answered;
/// a key read out of a message is never one
class SessionRemote {
  const SessionRemote._(this.hex);
  factory SessionRemote.opened(List<int> remote) =>
      SessionRemote._(devHex(remote));
  final String hex;
}

String devHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// the bytes of a hex key as [devHex] writes it
Uint8List devBytes(String hex) => Uint8List.fromList([
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

/// the engine turned a call down. [why] is its name for the reason
/// (rollback, equivocation, signature, not_listed, ...)
class DevRefused implements Exception {
  const DevRefused(this.why, this.answer);
  final String why;
  final Map<String, dynamic> answer;
  @override
  String toString() => 'DevRefused($why)';
}

typedef _DevCallC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DevCall = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _DevShimC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DevShim = Pointer<Utf8> Function(Pointer<Utf8>);

/// the engine's three calls
class DeviceEngine {
  DeviceEngine([DynamicLibrary? lib]) {
    final l =
        lib ??
        (Platform.isAndroid
            ? DynamicLibrary.open('libhalo.so')
            : DynamicLibrary.process());
    _call = l.lookupFunction<_DevCallC, _DevCall>('HaloDevCall');
    _session = l.lookupFunction<_DevCallC, _DevCall>('HaloDevSession');
    _shim = l.lookupFunction<_DevShimC, _DevShim>('HaloDevShim');
  }

  late final _DevCall _call;
  late final _DevCall _session;
  late final _DevShim _shim;

  // the op and the args as c strings for one call, freed after
  String _with(
    String op,
    Map<String, Object?> args,
    String Function(Pointer<Utf8> op, Pointer<Utf8> args) run,
  ) {
    final o = op.toNativeUtf8();
    final a = jsonEncode(args).toNativeUtf8();
    try {
      return run(o, a);
    } finally {
      calloc.free(o);
      calloc.free(a);
    }
  }

  String call(String op, Map<String, Object?> args) =>
      _with(op, args, (o, a) => engineTake(_call(o, a)));

  // the session door: private, so only DeviceState in this file names a
  // session's remote to the engine (session_door_test.go)
  String _door(String op, Map<String, Object?> args) =>
      _with(op, args, (o, a) => engineTake(_session(o, a)));

  /// opens the signal library in the engine, by the name or path the app
  /// loaded it by. null when it opened, else why not
  String? openShim(String path) {
    final p = path.toNativeUtf8();
    try {
      final r = engineTake(_shim(p));
      return r == 'ok' ? null : r;
    } finally {
      calloc.free(p);
    }
  }
}

/// the state, through one engine
class DeviceState {
  DeviceState(this.engine);
  final DeviceEngine engine;

  /// how many stored rows did not load at the last start
  int skipped = 0;

  /// the contacts whose lists name a key someone else holds, from the
  /// last call that said: the alarm goes on them (step 8)
  List<String> claimants = const [];

  Map<String, dynamic> _answer(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final c = j['claimants'];
    if (c is List) claimants = c.cast<String>();
    return j;
  }

  /// the state from [db]'s rows, after the engine opened the signal
  /// library at [shimPath]. nothing is written: a row that no longer
  /// loads stays where it is
  Future<void> load(
    DatabaseExecutor db,
    List<DevMine> mine, {
    required String shimPath,
  }) async {
    final why = engine.openShim(shimPath);
    if (why != null) throw DevRefused('no_shim', {'why': why});
    final j = _answer(engine.call('load', await devLoadArgs(db, mine)));
    final err = j['err'] as String?;
    if (err != null) throw DevRefused(err, j);
    skipped = (j['skipped'] as num?)?.toInt() ?? 0;
  }

  /// a call that names no session remote. its rows are written in [db]
  /// (a transaction of the caller's, or one of its own) before it returns;
  /// a refusal still writes what the engine changed, then throws
  Future<Map<String, dynamic>> call(
    DatabaseExecutor db,
    String op,
    Map<String, Object?> args,
  ) => _write(db, _answer(engine.call(op, args)));

  /// a call on what came inside a session: [remote] is what libsignal's
  /// decrypt returned for it
  Future<Map<String, dynamic>> session(
    DatabaseExecutor db,
    String op,
    Map<String, Object?> args,
    SessionRemote remote,
  ) => _write(db, _answer(engine._door(op, {...args, 'remote': remote.hex})));

  /// the phone's own list of my identity [ident], as it signed it
  Future<Map<String, dynamic>> ownMine(
    DatabaseExecutor db,
    int ident,
    Uint8List wire,
  ) => _write(
    db,
    _answer(
      engine._door('own_mine', {'ident': ident, 'list': base64Encode(wire)}),
    ),
  );

  Future<Map<String, dynamic>> _write(
    DatabaseExecutor db,
    Map<String, dynamic> j,
  ) async {
    final rows = (j['rows'] as List?) ?? const [];
    if (rows.isNotEmpty) {
      if (db is Database) {
        await db.transaction((t) => applyDevRows(t, rows));
      } else {
        await applyDevRows(db, rows);
      }
    }
    final err = j['err'] as String?;
    if (err != null) throw DevRefused(err, j);
    return j;
  }
}
