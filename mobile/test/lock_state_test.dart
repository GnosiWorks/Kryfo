// SPDX-License-Identifier: GPL-3.0-or-later
// the app lock on the pin table: every pin costs the same, the throttle
// cannot be walked around with a decoy pin, and the move from the old sha256
// pins survives a crash at any point.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStore implements LockStore {
  final Map<String, String> m = {};
  final List<String> log = [];
  int? failWrite; // throw on this write (1-based) and every later one
  int? failDelete;
  bool failReads = false;
  int writes = 0, deletes = 0;

  @override
  Future<String?> read(String key) async {
    log.add('r $key');
    if (failReads) throw StateError('keystore');
    return m[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (failWrite != null && writes >= failWrite!) throw StateError('crash');
    log.add('w $key');
    m[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes++;
    if (failDelete != null && deletes >= failDelete!) throw StateError('crash');
    log.add('d $key');
    m.remove(key);
  }
}

// the engine's rules in dart: a table is {"n": cost, "e": {index: {"p", "k"}}}
class FakeEngine implements PinEngine {
  final List<String> calls = [];

  static String legacyHash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Map<String, dynamic> _t(String s) => jsonDecode(s) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> calibrate() async {
    calls.add('calibrate');
    return {'n': 15, 'ms': 120};
  }

  @override
  Future<String> newTable(int logN) async {
    calls.add('new');
    return jsonEncode({'n': logN, 'e': <String, dynamic>{}});
  }

  @override
  Future<Map<String, dynamic>> check(
    String pin,
    String table,
    String legacy,
  ) async {
    calls.add('check');
    final e = _t(table)['e'] as Map<String, dynamic>;
    final l = jsonDecode(legacy) as Map<String, dynamic>;
    var r = <String, dynamic>{'i': -1, 'k': 0, 'la': false, 'lw': false};
    for (final kv in e.entries) {
      if ((kv.value as Map)['p'] == pin) {
        r = {...r, 'i': int.parse(kv.key), 'k': (kv.value as Map)['k']};
      }
    }
    bool old(String s, String h) =>
        s != '' && h != '' && legacyHash(pin, s) == h;
    r['la'] = old(l['as'] ?? '', l['ah'] ?? '');
    r['lw'] = old(l['ws'] ?? '', l['wh'] ?? '');
    return r;
  }

  @override
  Future<Map<String, dynamic>> setup(
    String pin,
    String table,
    String legacy,
    int index,
    int kind,
    String container,
  ) async {
    calls.add('setup');
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map);
    final l = jsonDecode(legacy) as Map<String, dynamic>;
    for (final kv in e.entries) {
      if (kv.key != '$index' && (kv.value as Map)['p'] == pin) {
        throw PinCollision();
      }
    }
    bool old(String s, String h) =>
        s != '' && h != '' && legacyHash(pin, s) == h;
    if (old(l['as'] ?? '', l['ah'] ?? '') ||
        old(l['ws'] ?? '', l['wh'] ?? '')) {
      throw PinCollision();
    }
    e['$index'] = {'p': pin, 'k': kind};
    return {
      't': {...t, 'e': e},
      'w': '',
    };
  }

  @override
  Future<String> clear(String table, int index) async {
    calls.add('clear');
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map)..remove('$index');
    return jsonEncode({...t, 'e': e});
  }
}

class FakeClock implements LockClock {
  int up = 1000000;
  int boot = 7;
  @override
  Future<int> uptimeMs() async => up;
  @override
  Future<int> bootCount() async => boot;
}

String table(Map<int, (String, int)> entries) => jsonEncode({
  'n': 15,
  'e': {
    for (final e in entries.entries)
      '${e.key}': {'p': e.value.$1, 'k': e.value.$2},
  },
});

void main() {
  late FakeStore store;
  late FakeEngine engine;
  late FakeClock clock;

  Future<LockState> make({Duration reveal = Duration.zero}) async {
    final s = LockState(
      store: store,
      engine: engine,
      clock: clock,
      revealAfter: reveal,
    );
    await s.load();
    return s;
  }

  setUp(() {
    decoyReady = true;
    SharedPreferences.setMockInitialValues({});
    store = FakeStore();
    engine = FakeEngine();
    clock = FakeClock();
    store.m['halo.lock.enabled'] = 'true';
    store.m['halo.lock.table'] = table({
      PinSlot.app: ('1234', PinKind.everyday),
      PinSlot.wipe: ('9999', PinKind.wipe),
      PinSlot.decoy: ('5555', PinKind.decoy),
    });
  });

  test('every pin reads nothing, checks once and writes once', () async {
    final lock = await make();
    for (final (pin, want) in [
      ('1234', PinResult.normal),
      ('5555', PinResult.decoy),
      ('0000', PinResult.invalid),
      ('9999', PinResult.panic),
    ]) {
      store.log.clear();
      engine.calls.clear();
      expect(await lock.verifyPin(pin), want, reason: pin);
      expect(store.log.where((l) => l.startsWith('r ')), isEmpty, reason: pin);
      expect(store.log, ['w halo.lock.state'], reason: pin);
      expect(engine.calls, ['check'], reason: pin);
    }
  });

  test('every outcome is shown at the same moment', () async {
    final lock = await make(reveal: const Duration(milliseconds: 80));
    for (final pin in ['1234', '5555', '0000', '9999']) {
      final t = Stopwatch()..start();
      await lock.verifyPin(pin);
      expect(t.elapsedMilliseconds, greaterThanOrEqualTo(78), reason: pin);
    }
  });

  test('a decoy unlock opens quietly and the everyday one clears it', () async {
    final lock = await make();
    await lock.verifyPin('5555');
    expect(lock.locked, isFalse);
    expect(lock.quiet, isTrue);
    expect(jsonDecode(store.m['halo.lock.state']!)['q'], isTrue);
    lock.lock();
    await lock.verifyPin('1234');
    expect(lock.quiet, isFalse);
  });

  test('five misses hold the pad; the wipe pin still wipes', () async {
    final lock = await make();
    for (var i = 0; i < 5; i++) {
      expect(await lock.verifyPin('0000'), PinResult.invalid);
    }
    expect(await lock.verifyPin('1234'), PinResult.throttled);
    expect(await lock.verifyPin('5555'), PinResult.throttled);
    expect(await lock.verifyPin('9999'), PinResult.panic);
    clock.up += 31000;
    expect(await lock.verifyPin('1234'), PinResult.normal);
  });

  test(
    'a decoy unlock does not reset the count that guards the real pin',
    () async {
      final lock = await make();
      // four wrong, then the decoy, four times over: never five in a row
      for (var round = 0; round < 4; round++) {
        for (var i = 0; i < 4; i++) {
          expect(await lock.verifyPin('0000'), PinResult.invalid);
        }
        expect(await lock.verifyPin('5555'), PinResult.decoy);
        lock.lock();
      }
      for (var i = 0; i < 4; i++) {
        expect(await lock.verifyPin('0000'), PinResult.invalid);
      }
      // twenty misses since the last everyday unlock: the long hold is on,
      // for the decoy pin as much as the real one
      final c = jsonDecode(store.m['halo.lock.state']!) as Map;
      expect(c['b'], 20);
      expect(c['hl'], greaterThanOrEqualTo(5 * 60000));
      expect(await lock.verifyPin('5555'), PinResult.throttled);
      expect(await lock.verifyPin('1234'), PinResult.throttled);
      expect(await lock.verifyPin('9999'), PinResult.panic);
    },
  );

  test(
    'the hold follows the uptime clock and starts over after a reboot',
    () async {
      final lock = await make();
      for (var i = 0; i < 5; i++) {
        await lock.verifyPin('0000');
      }
      clock.up += 20000;
      expect(await lock.verifyPin('1234'), PinResult.throttled);
      clock.boot += 1;
      clock.up = 5000;
      expect(await lock.verifyPin('1234'), PinResult.throttled);
      clock.up += 31000;
      expect(await lock.verifyPin('1234'), PinResult.normal);
    },
  );

  test(
    'an old sha256 pin opens and moves into the table, table first',
    () async {
      store.m.remove('halo.lock.table');
      store.m['halo.lock.pin_salt'] = 'c2FsdA==';
      store.m['halo.lock.pin_hash'] = FakeEngine.legacyHash('2468', 'c2FsdA==');
      final lock = await make();
      store.log.clear();
      expect(await lock.verifyPin('2468'), PinResult.normal);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final table = store.log.indexOf('w halo.lock.table');
      expect(table, greaterThan(0));
      expect(store.log.indexOf('d halo.lock.pin_hash'), greaterThan(table));
      expect(store.m.containsKey('halo.lock.pin_hash'), isFalse);
      lock.lock();
      expect(await lock.verifyPin('2468'), PinResult.normal);
      expect(await lock.verifyPin('2469'), PinResult.invalid);
    },
  );

  test(
    'a crash between the table and the delete still opens, and finishes',
    () async {
      store.m.remove('halo.lock.table');
      store.m['halo.lock.pin_salt'] = 'c2FsdA==';
      store.m['halo.lock.pin_hash'] = FakeEngine.legacyHash('2468', 'c2FsdA==');
      store.failDelete = 1;
      var lock = await make();
      await lock.verifyPin('2468');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(store.m.containsKey('halo.lock.table'), isTrue);
      expect(store.m.containsKey('halo.lock.pin_hash'), isTrue);
      // the next start: both the table and the old hash open it
      store.failDelete = null;
      store.deletes = 0;
      lock = await make();
      expect(await lock.verifyPin('2468'), PinResult.normal);
    },
  );

  test('an old wipe pin still wipes after the app pin moved', () async {
    store.m.remove('halo.lock.table');
    store.m['halo.lock.pin_salt'] = 'YQ==';
    store.m['halo.lock.pin_hash'] = FakeEngine.legacyHash('2468', 'YQ==');
    store.m['halo.lock.panic_salt'] = 'Yg==';
    store.m['halo.lock.panic_hash'] = FakeEngine.legacyHash('1357', 'Yg==');
    final lock = await make();
    await lock.verifyPin('2468');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(lock.legacyWipe, isTrue);
    lock.lock();
    expect(await lock.verifyPin('1357'), PinResult.panic);
  });

  test(
    'a pin already in use is refused without saying which, and counts',
    () async {
      final lock = await make();
      final before = store.m['halo.lock.table'];
      expect(await lock.setupPanicPin('5555'), isFalse);
      expect(store.m['halo.lock.table'], before);
      expect(jsonDecode(store.m['halo.lock.state']!)['b'], 1);
      expect(await lock.setupPanicPin('7777'), isTrue);
      lock.lock();
      expect(await lock.verifyPin('7777'), PinResult.panic);
    },
  );

  test('changing the app pin to itself is not a clash', () async {
    final lock = await make();
    expect(await lock.setupPin('1234'), isTrue);
  });

  test('a keystore that will not answer keeps the app locked', () async {
    store.failReads = true;
    final lock = LockState(
      store: store,
      engine: engine,
      clock: clock,
      revealAfter: Duration.zero,
    );
    await lock.load();
    expect(lock.unreadable, isTrue);
    expect(lock.locked, isTrue);
  });

  test('turning the lock off removes the table and the counters', () async {
    final lock = await make();
    await lock.verifyPin('0000');
    await lock.disable();
    for (final k in [
      'halo.lock.table',
      'halo.lock.state',
      'halo.lock.enabled',
    ]) {
      expect(store.m.containsKey(k), isFalse, reason: k);
    }
    expect(lock.locked, isFalse);
  });

  test('misses and a hold from before the table carry over', () async {
    store.m['halo.lock.misses'] = '5';
    store.m['halo.lock.until'] =
        '${DateTime.now().millisecondsSinceEpoch + 20000}';
    final lock = await make();
    expect(store.m.containsKey('halo.lock.misses'), isFalse);
    expect(await lock.verifyPin('1234'), PinResult.throttled);
  });

  test('until the decoy session exists, its pin opens nothing', () async {
    decoyReady = false;
    final lock = await make();
    expect(await lock.verifyPin('5555'), PinResult.invalid);
    expect(lock.locked, isTrue);
  });
}
