// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's own devices: his phone and his linked computer name his
// pinned key in every device pair between them, and those pairs are his
// own. the doors hand them to the engine, his list without a removed
// computer and his profile word included. a contact's device pair with him
// stays refused, as the dev chat has no devices
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_gate.dart' show kDevRefused;
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        devPairRefused,
        deviceStateForTest,
        engineDeviceWireForTest,
        useEngineForTest;
import 'package:sqflite_sqlcipher/sqflite.dart' show DatabaseExecutor;

import 'host_engine.dart';

// his pinned key, an ordinary one, a pair's seed
final _his = 'ab' * 32;
final _other = 'cd' * 32;
final _seed = '11' * 32;

final _card = DevKey(
  keyId: 't1',
  threeWords: 'calm-test-stone',
  xPub: _his,
  bundle: '',
  fc: '22' * 32,
);

class _Eng implements DeviceEngine {
  @override
  String? openShim(String path) => null;
  @override
  String call(String op, Map<String, Object?> args) => '{}';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// a container with no device rows yet
class _NoRows implements DatabaseExecutor {
  @override
  dynamic noSuchMethod(Invocation i) => i.memberName == #query
      ? Future.value(<Map<String, Object?>>[])
      : super.noSuchMethod(i);
}

Uint8List _key(String x) => Uint8List.fromList([5, ...devBytes(x)]);

// the device state as a start loads it: identity [x] on ident 0 as device
// [dev], and [x1] on ident 1
Future<void> _loaded(String x, {int dev = 1, String? x1}) async {
  final ds = DeviceState(_Eng());
  await ds.load(_NoRows(), [
    (
      ident: 0,
      identity: _key(x),
      key: _key(dev == 1 ? x : 'ef' * 32),
      dev: dev,
    ),
    if (x1 != null) (ident: 1, identity: _key(x1), key: _key(x1), dev: 1),
  ], shimPath: 'shim');
  deviceStateForTest(ds);
}

void main() {
  setUp(() => useDevKeysForTest([_card]));
  tearDown(() {
    useDevKeysForTest(null);
    deviceStateForTest(null);
  });

  group('the question both device doors ask', () {
    test('his phone and his computer pair with each other', () async {
      await _loaded(_his);
      expect(devPairRefused(0, '$_his/2/1'), isFalse);
      expect(devPairRefused(0, '$_his/2/1.$_seed'), isFalse);
      await _loaded(_his, dev: 2);
      expect(devPairRefused(0, '$_his/1/2'), isFalse);
      expect(devPairRefused(0, '$_his/1/2.$_seed'), isFalse);
      // a contact's pair names no pinned key
      expect(devPairRefused(0, '$_other/1/2'), isFalse);
    });

    test('a contact\'s device pair with him stays refused', () async {
      await _loaded(_other);
      expect(devPairRefused(0, '$_his/2/1'), isTrue);
      expect(devPairRefused(0, '$_his/2/1.$_seed'), isTrue);
      // his key as a contact of another identity of mine
      await _loaded(_his, x1: _other);
      expect(devPairRefused(1, '$_his/2/1.$_seed'), isTrue);
      // nothing loaded yet: nothing of his
      deviceStateForTest(null);
      expect(devPairRefused(0, '$_his/2/1.$_seed'), isTrue);
    });
  });

  // the doors on the engine built for this computer: what the phone's
  // device wire gets back is the engine's answer, not the gate's
  group('the device wire', () {
    final there = loadHostEngine();
    final skip = there ? false : 'no host engine';

    test('his phone hands its computer\'s copies and last word on', () async {
      useEngineForTest(HaloEngine());
      await _loaded(_his);
      final w = engineDeviceWireForTest;
      expect(await w.send(0, '$_his/2/1.$_seed', 'c'), isNot(kDevRefused));
      expect(
        await w.sendOpener(0, '$_his/2/1.$_seed', 'c'),
        isNot(kDevRefused),
      );
    }, skip: skip);

    test('his computer hands its words to its phone on', () async {
      useEngineForTest(HaloEngine());
      await _loaded(_his, dev: 2);
      final w = engineDeviceWireForTest;
      expect(await w.send(0, '$_his/1/2.$_seed', 'c'), isNot(kDevRefused));
    }, skip: skip);

    test('a contact\'s copy to his devices never leaves', () async {
      useEngineForTest(HaloEngine());
      await _loaded(_other);
      final w = engineDeviceWireForTest;
      expect(await w.send(0, '$_his/2/1.$_seed', 'c'), kDevRefused);
      expect(await w.sendOpener(0, '$_his/2/1.$_seed', 'c'), kDevRefused);
    }, skip: skip);
  });
}
