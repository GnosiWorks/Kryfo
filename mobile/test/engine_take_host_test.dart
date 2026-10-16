// SPDX-License-Identifier: GPL-3.0-or-later
// the bindings against the real engine (tool/host_engine.sh): each call
// hands back one string and frees exactly one, and native memory stays
// flat over many calls. skipped when the host engine is not built
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/engine_strings.dart';
import 'package:kryfo/lock_state.dart' show tellEngineDecoy;
import 'package:kryfo/main.dart' show HaloEngine;
import 'package:kryfo/tools/age_ffi.dart' show suggestPassphrase;

import 'host_engine.dart';

typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);

void main() {
  final there = loadHostEngine();
  final skip = there ? false : 'no host engine';
  var frees = 0;

  setUp(() {
    final free = DynamicLibrary.process().lookupFunction<_FreeC, _FreeD>(
      'HaloFree',
    );
    frees = 0;
    engineFreeForTest = (p) {
      frees++;
      free(p);
    };
  });
  tearDown(() => engineFreeForTest = null);

  test('every call frees the one string it got', () {
    final e = HaloEngine();
    e.generateIdentity();
    tellEngineDecoy(false);
    final ed = e.myEdPrivkey(), x = e.myXPrivkey();
    final edPub = e.myEdPubkey(), xPub = e.myXPubkey();
    final sealed = e.encryptFor(xPub, 'hi');
    final q = e.quietIdentity()!;
    final v = e.vaultKeys();
    final box = e.vaultSeal(v.pub, base64.encode([1, 2, 3]));
    final room = e.roomKeygen()!;
    final memory = e.autoMemory(), cache = e.bridgeCache();

    // each one makes a single engine call that returns a string
    final calls = <String, Object? Function()>{
      'version': e.version,
      'generateIdentity': e.generateIdentity,
      'myId': e.myId,
      'myEdPubkey': e.myEdPubkey,
      'myXPubkey': e.myXPubkey,
      'myEdPrivkey': e.myEdPrivkey,
      'myXPrivkey': e.myXPrivkey,
      'restoreIdentity': () => e.restoreIdentity(ed, x),
      'idFromEdPub': () => e.idFromEdPub(edPub),
      'encryptFor': () => e.encryptFor(xPub, 'hi'),
      'decryptFrom': () => e.decryptFrom(xPub, sealed),
      'decryptBackup': () => e.decryptBackup('x', 'y'),
      'firstContactPk': () => e.firstContactPk(0),
      'getStatus': e.getStatus,
      'nostrKick': e.nostrKick,
      'memStats': e.memStats,
      'drainInbox': e.drainInbox,
      'catchupState': e.catchupState,
      'lastReconnect': e.lastReconnect,
      'bridgeStatus': e.bridgeStatus,
      'transportMode': e.transportMode,
      'transportState': e.transportState,
      'bridgeLineChecks': e.bridgeLineChecks,
      'autoMemory': e.autoMemory,
      'bridgeCache': e.bridgeCache,
      'setAutoMemory': () => e.setAutoMemory(memory),
      'setBridgeCache': () => e.setBridgeCache(cache),
      'builtinBridges': () => e.builtinBridges('obfs4'),
      'nostrPoll': e.nostrPoll,
      'nostrAck': () => e.nostrAck('none', const []),
      'quietIdentity': e.quietIdentity,
      'quietDescribe': () =>
          e.quietDescribe(q['ed_priv'], q['x_priv'], q['onion_key']),
      'quietFirstContactPk': () => e.quietFirstContactPk(q['x_priv'], 0),
      'vaultKeys': e.vaultKeys,
      'vaultSeal': () => e.vaultSeal(v.pub, 'AQID'),
      'vaultOpenMany': () => e.vaultOpenMany(v.priv, [box]),
      'roomKeygen': e.roomKeygen,
      'roomFcPk': () => e.roomFcPk(room.priv),
      'suggestPassphrase': suggestPassphrase,
      'tellEngineDecoy': () => tellEngineDecoy(false),
    };
    const n = 20;
    final freed = <String, int>{};
    for (final c in calls.entries) {
      final before = frees;
      for (var i = 0; i < n; i++) {
        c.value();
      }
      freed[c.key] = frees - before;
    }
    // what freed other than one string a call
    freed.removeWhere((_, got) => got == n);
    expect(freed, isEmpty);
  }, skip: skip);

  test('native memory stays flat over many calls', () {
    engineFreeForTest = null;
    final e = HaloEngine();
    // about 300 bytes a call: one left behind each time is 30 MB here
    void many() {
      for (var i = 0; i < 100000; i++) {
        e.transportState();
      }
    }

    many();
    final before = ProcessInfo.currentRss;
    many();
    final grew = ProcessInfo.currentRss - before;
    expect(grew, lessThan(10 << 20), reason: '$grew bytes');
  }, skip: skip);
}
