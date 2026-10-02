// SPDX-License-Identifier: GPL-3.0-or-later
// the app lock on the pin table: every pin costs the same, a decoy unlock
// keeps the miss budget, a vault pin opens its vault and nothing else does,
// and the moves from legacy pins and from the v1 table hold up if they stop
// at any point.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
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

// the engine's rules in dart: a table is {"v", "n", "e": {index: {"p", "k",
// "c", "w"}}}, w the key an entry wraps. any call that writes gives v2
class FakeEngine implements PinEngine {
  final List<String> calls = [];

  static String legacyHash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Map<String, dynamic> _t(String s) => jsonDecode(s) as Map<String, dynamic>;

  static bool _old(String pin, Object? s, Object? h) =>
      s is String &&
      h is String &&
      s != '' &&
      h != '' &&
      legacyHash(pin, s) == h;

  // the pin opens an entry other than index, or matches an old check
  static bool _clashes(Map e, int index, String pin, Map l) {
    for (final kv in e.entries) {
      if (kv.key != '$index' && (kv.value as Map)['p'] == pin) return true;
    }
    return _old(pin, l['as'], l['ah']) || _old(pin, l['ws'], l['wh']);
  }

  @override
  Future<Map<String, dynamic>> calibrate() async {
    calls.add('calibrate');
    return {'n': 15, 'ms': 120};
  }

  @override
  Future<String> newTable(int logN) async {
    calls.add('new');
    return jsonEncode({'v': 2, 'n': logN, 'e': <String, dynamic>{}});
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
    var r = <String, dynamic>{
      'i': -1,
      'k': 0,
      'c': '',
      'la': false,
      'lw': false,
      'u': '',
    };
    for (final kv in e.entries) {
      final v = kv.value as Map;
      if (v['p'] == pin) {
        r = {
          ...r,
          'i': int.parse(kv.key),
          'k': v['k'],
          'c': v['c'] ?? '',
          'u': v['w'] ?? '',
        };
      }
    }
    r['la'] = _old(pin, l['as'], l['ah']);
    r['lw'] = _old(pin, l['ws'], l['wh']);
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
    String wrapPlain,
  ) async {
    calls.add('setup');
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map);
    final l = jsonDecode(legacy) as Map<String, dynamic>;
    if (_clashes(e, index, pin, l)) throw PinCollision();
    e['$index'] = {'p': pin, 'k': kind, 'c': container, 'w': wrapPlain};
    return {
      't': {...t, 'v': 2, 'e': e},
    };
  }

  @override
  Future<Map<String, dynamic>> rewrap(
    String oldPin,
    String newPin,
    String table,
    String legacy,
    int index,
  ) async {
    calls.add('rewrap');
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map);
    final l = jsonDecode(legacy) as Map<String, dynamic>;
    final at = e['$index'] as Map?;
    if (at == null || at['p'] != oldPin) throw StateError('error: wrong pin');
    if ((at['w'] ?? '') == '') throw StateError('error: nothing wrapped');
    if (_clashes(e, index, newPin, l)) throw PinCollision();
    e['$index'] = {...at, 'p': newPin};
    return {
      't': {...t, 'v': 2, 'e': e},
    };
  }

  @override
  Future<String> upgrade(String table) async {
    calls.add('upgrade');
    return jsonEncode({..._t(table), 'v': 2});
  }

  @override
  Future<String> clear(String table, int index) async {
    calls.add('clear');
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map)..remove('$index');
    return jsonEncode({...t, 'v': 2, 'e': e});
  }
}

class FakeBio implements LockBio {
  String key = 'ok';
  String answer = 'ok';
  int enables = 0;
  @override
  Future<bool> ready() async => true;
  @override
  Future<String> state() async => key;
  @override
  Future<bool> enable() async {
    enables++;
    key = 'ok';
    return true;
  }

  @override
  Future<void> disable() async => key = 'none';
  @override
  Future<String> unlock(String title, String cancel) async =>
      key != 'ok' ? key : answer;
}

class FakeClock implements LockClock {
  int up = 1000000;
  int boot = 7;
  @override
  Future<int> uptimeMs() async => up;
  @override
  Future<int> bootCount() async => boot;
}

// the keys the two vault entries wrap
final vKey = '1f' * 32;
final dvKey = '2e' * 32;

// what the app seals into each entry
String containerOf(int index, int kind) => switch (kind) {
  PinKind.decoy => HaloContainer.decoy.id,
  PinKind.vault when index == PinSlot.decoyVault => HaloContainer.decoyVault.id,
  PinKind.vault => HaloContainer.vault.id,
  _ => HaloContainer.everyday.id,
};

String table(
  Map<int, (String, int)> entries, {
  int v = 2,
  Map<int, String> wraps = const {},
}) => jsonEncode({
  'v': v,
  'n': 15,
  'e': {
    for (final e in entries.entries)
      '${e.key}': {
        'p': e.value.$1,
        'k': e.value.$2,
        'c': containerOf(e.key, e.value.$2),
        'w': wraps[e.key] ?? '',
      },
  },
});

Map<String, dynamic> entriesOf(FakeStore s) =>
    jsonDecode(s.m['halo.lock.table']!)['e'] as Map<String, dynamic>;

Map<String, dynamic> countersOf(FakeStore s) =>
    jsonDecode(s.m['halo.lock.state']!) as Map<String, dynamic>;

void main() {
  late FakeStore store;
  late FakeEngine engine;
  late FakeClock clock;
  late FakeBio bio;

  Future<LockState> make({Duration reveal = Duration.zero}) async {
    final s = LockState(
      store: store,
      engine: engine,
      clock: clock,
      bio: bio,
      revealAfter: reveal,
    );
    await s.load();
    return s;
  }

  // app, wipe, decoy, the vault and the decoy's vault
  void seed() {
    store = FakeStore();
    engine = FakeEngine();
    clock = FakeClock();
    bio = FakeBio();
    store.m['halo.lock.enabled'] = 'true';
    store.m['halo.lock.table'] = table(
      {
        PinSlot.app: ('1234', PinKind.everyday),
        PinSlot.wipe: ('9999', PinKind.wipe),
        PinSlot.decoy: ('5555', PinKind.decoy),
        PinSlot.vault: ('246810', PinKind.vault),
        PinSlot.decoyVault: ('135790', PinKind.vault),
      },
      wraps: {PinSlot.vault: vKey, PinSlot.decoyVault: dvKey},
    );
  }

  setUp(() {
    decoyReady = true;
    SharedPreferences.setMockInitialValues({});
    seed();
  });

  const everyPin = {
    '1234': PinResult.normal,
    '5555': PinResult.decoy,
    '246810': PinResult.vault,
    '135790': PinResult.decoy,
    '0000': PinResult.invalid,
    '9999': PinResult.panic,
  };

  test('every check reads nothing, writes once and calls the same', () async {
    for (final legacy in [false, true]) {
      for (final held in [false, true]) {
        seed();
        if (legacy) {
          // a move from the old hashes that stopped half way
          store.m['halo.lock.pin_salt'] = 'YQ==';
          store.m['halo.lock.pin_hash'] = FakeEngine.legacyHash('1234', 'YQ==');
          store.m['halo.lock.panic_salt'] = 'Yg==';
          store.m['halo.lock.panic_hash'] = FakeEngine.legacyHash(
            '9999',
            'Yg==',
          );
        }
        if (held) {
          store.m['halo.lock.state'] = LockCounters(
            run: 5,
            budget: 5,
            holdStart: clock.up,
            holdLen: 30000,
            holdBoot: clock.boot,
          ).encode();
        }
        final lock = await make();
        lock.onOutcome = (r, {vaultKey}) async {};
        for (final MapEntry(key: pin, value: opens) in everyPin.entries) {
          final why = '$pin, held $held, legacy $legacy';
          final want = held && opens != PinResult.panic
              ? PinResult.throttled
              : opens;
          store.log.clear();
          engine.calls.clear();
          expect(await lock.verifyPin(pin), want, reason: why);
          expect(store.log, ['w halo.lock.state'], reason: why);
          expect(engine.calls, ['check'], reason: why);
          lock.lock();
        }
      }
    }
  });

  test('every outcome shows at the same moment', () async {
    final lock = await make(reveal: const Duration(milliseconds: 80));
    // a vault takes longer to open than a session that is already there
    lock.onOutcome = (r, {vaultKey}) async {
      if (vaultKey != null) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    };
    for (final pin in everyPin.keys) {
      final t = Stopwatch()..start();
      await lock.verifyPin(pin);
      expect(t.elapsedMilliseconds, greaterThanOrEqualTo(78), reason: pin);
      lock.lock();
    }
  });

  test(
    'a vault that takes most of the wait still shows at the deadline',
    () async {
      const reveal = Duration(milliseconds: 150);
      final lock = await make(reveal: reveal);
      // opening the vault and reading its lists, under the lock
      final underLock = <bool>[];
      lock.onOutcome = (r, {vaultKey}) async {
        if (vaultKey != null) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        underLock.add(lock.locked);
      };
      final shown = <String, int>{};
      for (final pin in ['1234', '246810', '5555', '0000', '9999']) {
        store.log.clear();
        final t = Stopwatch()..start();
        await lock.verifyPin(pin);
        shown[pin] = t.elapsedMilliseconds;
        expect(store.log, ['w halo.lock.state'], reason: pin);
        lock.lock();
      }
      expect(underLock, everyElement(isTrue));
      for (final e in shown.entries) {
        expect(e.value, greaterThanOrEqualTo(148), reason: e.key);
      }
      final ms = shown.values.toList()..sort();
      expect(ms.last - ms.first, lessThan(60), reason: '$shown');
    },
  );

  test('a decoy unlock sets quiet, everyday clears it', () async {
    final lock = await make();
    await lock.verifyPin('5555');
    expect(lock.locked, isFalse);
    expect(lock.quiet, isTrue);
    expect(jsonDecode(store.m['halo.lock.state']!)['q'], isTrue);
    lock.lock();
    await lock.verifyPin('1234');
    expect(lock.quiet, isFalse);
  });

  test('the pad holds after five misses', () async {
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

  test('a decoy unlock keeps the miss budget', () async {
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
  });

  test('the hold uses uptime and restarts on reboot', () async {
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
  });

  // the move from the old sha256 pins, over a new table, a v1 table the load
  // upgrades, and a v1 table whose upgrade write failed
  for (final start in ['no table', 'v1', 'v1 not upgraded']) {
    group('from $start,', () {
      // a table from before, holding a decoy pin, next to the old hashes
      Future<LockState> open() async {
        store.m.remove('halo.lock.table');
        if (start != 'no table') {
          store.m['halo.lock.table'] = table({
            PinSlot.decoy: ('5555', PinKind.decoy),
          }, v: 1);
        }
        if (start == 'v1 not upgraded') store.failWrite = 1;
        final lock = await make();
        store.failWrite = null;
        final t = store.m['halo.lock.table'];
        expect(t == null ? null : jsonDecode(t)['v'], switch (start) {
          'no table' => null,
          'v1' => 2,
          _ => 1,
        });
        return lock;
      }

      test('a legacy pin opens and moves to the table', () async {
        store.m['halo.lock.pin_salt'] = 'c2FsdA==';
        store.m['halo.lock.pin_hash'] = FakeEngine.legacyHash(
          '2468',
          'c2FsdA==',
        );
        final lock = await open();
        store.log.clear();
        expect(await lock.verifyPin('2468'), PinResult.normal);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final table = store.log.indexOf('w halo.lock.table');
        expect(table, greaterThan(0));
        expect(store.log.indexOf('d halo.lock.pin_hash'), greaterThan(table));
        expect(store.m.containsKey('halo.lock.pin_hash'), isFalse);
        expect(jsonDecode(store.m['halo.lock.table']!)['v'], 2);
        lock.lock();
        expect(await lock.verifyPin('2468'), PinResult.normal);
        expect(await lock.verifyPin('2469'), PinResult.invalid);
        if (start != 'no table') {
          expect(await lock.verifyPin('5555'), PinResult.decoy);
        }
      });

      test('a half-done pin move opens and finishes', () async {
        store.m['halo.lock.pin_salt'] = 'c2FsdA==';
        store.m['halo.lock.pin_hash'] = FakeEngine.legacyHash(
          '2468',
          'c2FsdA==',
        );
        store.failDelete = 1;
        var lock = await open();
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
      });

      test('a legacy wipe pin wipes after the move', () async {
        store.m['halo.lock.pin_salt'] = 'YQ==';
        store.m['halo.lock.pin_hash'] = FakeEngine.legacyHash('2468', 'YQ==');
        store.m['halo.lock.panic_salt'] = 'Yg==';
        store.m['halo.lock.panic_hash'] = FakeEngine.legacyHash('1357', 'Yg==');
        final lock = await open();
        await lock.verifyPin('2468');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(lock.legacyWipe, isTrue);
        lock.lock();
        expect(await lock.verifyPin('1357'), PinResult.panic);
      });
    });
  }

  test('a pin in use is refused and counts', () async {
    final lock = await make();
    final before = store.m['halo.lock.table'];
    expect(await lock.setupPanicPin('5555'), isFalse);
    expect(store.m['halo.lock.table'], before);
    expect(jsonDecode(store.m['halo.lock.state']!)['b'], 1);
    expect(await lock.setupPanicPin('7777'), isTrue);
    lock.lock();
    expect(await lock.verifyPin('7777'), PinResult.panic);
  });

  test('the app pin may be set to itself', () async {
    final lock = await make();
    expect(await lock.setupPin('1234'), isTrue);
  });

  test('an unreadable keystore keeps the app locked', () async {
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

  test('turning the lock off clears the table', () async {
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

  test('legacy misses and hold carry over', () async {
    store.m['halo.lock.misses'] = '5';
    store.m['halo.lock.until'] =
        '${DateTime.now().millisecondsSinceEpoch + 20000}';
    final lock = await make();
    expect(store.m.containsKey('halo.lock.misses'), isFalse);
    expect(await lock.verifyPin('1234'), PinResult.throttled);
  });

  test('a decoy pin opens nothing before its session', () async {
    decoyReady = false;
    final lock = await make();
    expect(await lock.verifyPin('5555'), PinResult.invalid);
    expect(lock.locked, isTrue);
  });

  test('a new finger waits for the pin', () async {
    store.m['halo.lock.biometric'] = 'true';
    bio.key = 'invalidated';
    final lock = await make();
    // load can only offer a finger when local_auth says the phone has one,
    // which it cannot in a test: ask the key directly
    expect(await bio.unlock('', ''), 'invalidated');
    expect(await lock.tryBiometric(), isFalse);
    expect(lock.locked, isTrue);
    expect(await lock.verifyPin('1234'), PinResult.normal);
    await Future<void>.delayed(Duration.zero);
    expect(bio.enables, 1);
    expect(lock.bioStale, isFalse);
  });

  test('turning fingerprint off throws its key away', () async {
    final lock = await make();
    await lock.setBiometric(true);
    expect(bio.key, 'ok');
    await lock.setBiometric(false);
    expect(bio.key, 'none');
  });

  test('the session is built before the lock lifts', () async {
    final lock = await make();
    final seen = <(PinResult, bool)>[];
    lock.onOutcome = (r, {vaultKey}) async => seen.add((r, lock.locked));
    await lock.verifyPin('5555');
    lock.lock();
    await lock.verifyPin('1234');
    lock.lock();
    await lock.verifyPin('0000');
    expect(seen, [(PinResult.decoy, true), (PinResult.normal, true)]);
  });

  test('inside the decoy the pins are the decoy\'s own', () async {
    final lock = await make();
    lock.inDecoy = true;
    // its own pin changes entry 2, which opens the decoy
    expect(await lock.setupPin('4444'), isTrue);
    lock.inDecoy = false;
    expect(await lock.verifyPin('4444'), PinResult.decoy);
    lock.inDecoy = true;
    // a wipe pin set there is a real one
    expect(await lock.setupPanicPin('8888'), isTrue);
    expect(lock.panicEnabled, isTrue);
    lock.lock();
    expect(await lock.verifyPin('8888'), PinResult.panic);
    // a decoy pin set there opens the decoy too
    expect(await lock.setupDecoyPin('7777'), isTrue);
    expect(lock.decoyPinOn, isTrue);
    lock.lock();
    expect(await lock.verifyPin('7777'), PinResult.decoy);
  });

  test('in the decoy a hidden clash is kept nowhere', () async {
    final lock = await make();
    lock.inDecoy = true;
    final before = store.m['halo.lock.table'];
    // 1234 is the everyday pin, 9999 the everyday wipe pin
    expect(await lock.setupPin('1234'), isTrue);
    expect(await lock.setupPanicPin('9999'), isTrue);
    expect(store.m['halo.lock.table'], before);
    // each one a try, as any set there is
    expect(countersOf(store)['r'], 2);
    expect(countersOf(store)['b'], 2);
    lock.inDecoy = false;
    lock.lock();
    expect(await lock.verifyPin('1234'), PinResult.normal);
  });

  test('lock off in the decoy only pauses it', () async {
    final lock = await make();
    await lock.verifyPin('5555');
    lock.inDecoy = true;
    final before = Map.of(store.m);
    await lock.disable();
    expect(store.m, before);
    expect(lock.lockOn, isFalse);
    lock.lock();
    expect(lock.locked, isFalse);
    // the next start locks again
    final again = await make();
    expect(again.locked, isTrue);
  });

  test('in the decoy a clash and a set look the same', () async {
    final seen = <String, (bool, bool, String)>{};
    // 1234 is the everyday pin, 246810 the vault's, 4444 is free
    for (final pin in ['1234', '246810', '4444']) {
      seed();
      final lock = await make();
      await lock.verifyPin('5555');
      lock.inDecoy = true;
      await lock.disable();
      expect(lock.lockOn, isFalse);
      final ok = await lock.setupPin(pin);
      final c = countersOf(store)..remove('hs');
      seen[pin] = (ok, lock.lockOn, jsonEncode(c));
    }
    expect(seen['1234'], seen['4444']);
    expect(seen['246810'], seen['4444']);
    expect(seen['4444']!.$1, isTrue);
    expect(seen['4444']!.$2, isTrue);
  });

  test(
    'in the decoy each pin set is a try, and a held pad takes none',
    () async {
      final lock = await make();
      await lock.verifyPin('5555');
      lock.inDecoy = true;
      // a free pin and the everyday one count alike
      for (final pin in ['4444', '1234', '4445', '1234', '4446']) {
        expect(await lock.setupPin(pin), isTrue, reason: pin);
      }
      expect(countersOf(store)['r'], 5);
      expect(lock.throttleLeft, greaterThan(Duration.zero));
      expect(pinNotTakenLine(lock), tooManyTriesLine(lock.throttleLeft));
      // held: refused before the engine is asked, whatever the pin
      for (final set in <Future<bool> Function()>[
        () => lock.setupPin('1234'),
        () => lock.setupPin('4447'),
        () => lock.setupPanicPin('9999'),
        () => lock.setupDecoyPin('7777'),
        () => lock.setupVaultPin('112233', dvKey),
        () => lock.rewrapVaultPin('135790', '112233'),
      ]) {
        engine.calls.clear();
        expect(await set(), isFalse);
        expect(engine.calls, isEmpty);
      }
      expect(countersOf(store)['r'], 5);
      // the lock screen holds for the same tries
      lock.inDecoy = false;
      lock.lock();
      expect(await lock.verifyPin('1234'), PinResult.throttled);
      clock.up += 31000;
      expect(await lock.verifyPin('1234'), PinResult.normal);
    },
  );

  // someone made to open the everyday app knows its pin. a pin set there
  // may hit the hidden chats' one, so each is a try at the same limit as
  // the lock screen's, and a held pad answers before anything is matched
  test(
    'outside the decoy each pin set is a try too, and a held pad takes none',
    () async {
      final lock = await make();
      expect(await lock.setupPanicPin('4444'), isTrue);
      expect(await lock.setupPanicPin('246810'), isFalse);
      expect(await lock.setupPanicPin('135790'), isFalse);
      expect(await lock.setupDecoyPin('4446'), isTrue);
      expect(lock.throttleLeft, Duration.zero);
      expect(await lock.setupPanicPin('4447'), isTrue);
      expect(countersOf(store)['r'], 5);
      expect(countersOf(store)['b'], 5);
      expect(lock.throttleLeft, greaterThan(Duration.zero));
      expect(pinNotTakenLine(lock), tooManyTriesLine(lock.throttleLeft));
      final table = store.m['halo.lock.table'];
      // held: refused before the engine is asked, the hidden chats' pin
      // and a free one alike
      for (final set in <Future<bool> Function()>[
        () => lock.setupPanicPin('246810'),
        () => lock.setupPanicPin('4448'),
        () => lock.setupPin('246810'),
        () => lock.setupDecoyPin('135790'),
        () => lock.setupVaultPin('112233', vKey),
        () => lock.rewrapVaultPin('246810', '112233'),
      ]) {
        engine.calls.clear();
        expect(await set(), isFalse);
        expect(engine.calls, isEmpty);
      }
      expect(store.m['halo.lock.table'], table);
      expect(countersOf(store)['r'], 5);
      // the lock screen holds for the same tries
      lock.lock();
      expect(await lock.verifyPin('246810'), PinResult.throttled);
      clock.up += 31000;
      expect(await lock.setupPanicPin('4449'), isTrue);
      expect(countersOf(store)['r'], 6);
    },
  );

  test('outside the decoy a pin in use is said as before', () async {
    final lock = await make();
    expect(await lock.setupPanicPin('5555'), isFalse);
    expect(pinNotTakenLine(lock), l10n.pinPickDifferent);
  });

  test('confirming the pin works like the lock', () async {
    final lock = await make();
    expect(await lock.confirmPin('1234'), PinResult.normal);
    expect(await lock.confirmPin('5555'), PinResult.invalid);
    expect(jsonDecode(store.m['halo.lock.state']!)['b'], 1);
    expect(await lock.confirmPin('9999'), PinResult.panic);
    lock.inDecoy = true;
    expect(await lock.confirmPin('5555'), PinResult.normal);
    expect(await lock.confirmPin('1234'), PinResult.invalid);
  });

  test('removing the decoy clears its entries', () async {
    final lock = await make();
    lock.inDecoy = true;
    await lock.setupPanicPin('8888');
    await lock.setupDecoyPin('7777');
    lock.inDecoy = false;
    await lock.clearDecoyPins();
    // its vault goes with it, the everyday vault stays
    expect(entriesOf(store).keys.toSet(), {
      '${PinSlot.app}',
      '${PinSlot.wipe}',
      '${PinSlot.vault}',
    });
    expect(store.m.containsKey('halo.lock.d.wipe'), isFalse);
    expect(store.m.containsKey('halo.lock.d.decoy'), isFalse);
  });

  test('the quiet flag is read every time', () async {
    // a process the job starts has no lock state of its own: it reads this
    expect(await quietNow(store), isFalse);
    final lock = await make();
    await lock.verifyPin('5555');
    expect(await quietNow(store), isTrue);
    lock.lock();
    await lock.verifyPin('1234');
    expect(await quietNow(store), isFalse);
    // unreadable counts as quiet: a missed notification over one in a decoy
    store.failReads = true;
    expect(await quietNow(store), isTrue);
  });

  test('a pin table is kept until the lock is turned off', () async {
    // what the boot sweep asks before it takes a vault's files
    expect(await pinTableKept(store), isTrue);
    final lock = await make();
    await lock.disable();
    expect(await pinTableKept(store), isFalse);
    // unreadable counts as kept: a vault may be there
    store.failReads = true;
    expect(await pinTableKept(store), isTrue);
  });

  test('a vault pin hands its key to the session, under the lock', () async {
    final lock = await make();
    final seen = <(PinResult, String?, bool)>[];
    lock.onOutcome = (r, {vaultKey}) async =>
        seen.add((r, vaultKey, lock.locked));
    expect(await lock.verifyPin('246810'), PinResult.vault);
    expect(lock.locked, isFalse);
    lock.lock();
    // the decoy's vault opens with the decoy
    expect(await lock.verifyPin('135790'), PinResult.decoy);
    lock.lock();
    expect(await lock.verifyPin('1234'), PinResult.normal);
    lock.lock();
    expect(await lock.verifyPin('5555'), PinResult.decoy);
    expect(seen, [
      (PinResult.vault, vKey, true),
      (PinResult.decoy, dvKey, true),
      (PinResult.normal, null, true),
      (PinResult.decoy, null, true),
    ]);
  });

  test('a vault that will not open gives its primary', () async {
    final lock = await make(reveal: const Duration(milliseconds: 60));
    final seen = <(PinResult, String?)>[];
    lock.onOutcome = (r, {vaultKey}) async {
      seen.add((r, vaultKey));
      if (vaultKey != null) throw StateError('will not open');
    };
    final t = Stopwatch()..start();
    expect(await lock.verifyPin('246810'), PinResult.normal);
    // at the same moment as any other unlock, and counted as one
    expect(t.elapsedMilliseconds, greaterThanOrEqualTo(58));
    expect(lock.locked, isFalse);
    expect(countersOf(store), {
      'r': 0,
      'b': 0,
      'hs': 0,
      'hl': 0,
      'hb': -1,
      'q': false,
    });
    lock.lock();
    expect(await lock.verifyPin('135790'), PinResult.decoy);
    expect(lock.quiet, isTrue);
    expect(seen, [
      (PinResult.vault, vKey),
      (PinResult.normal, null),
      (PinResult.decoy, dvKey),
      (PinResult.decoy, null),
    ]);
  });

  test('a vault entry with no key opens the everyday session', () async {
    store.m['halo.lock.table'] = table({
      PinSlot.app: ('1234', PinKind.everyday),
      PinSlot.vault: ('246810', PinKind.vault),
    });
    final lock = await make();
    final seen = <(PinResult, String?)>[];
    lock.onOutcome = (r, {vaultKey}) async => seen.add((r, vaultKey));
    expect(await lock.verifyPin('246810'), PinResult.normal);
    expect(seen, [(PinResult.normal, null)]);
  });

  test('a vault unlock clears quiet and the budget', () async {
    final lock = await make();
    for (var i = 0; i < 4; i++) {
      expect(await lock.verifyPin('0000'), PinResult.invalid);
    }
    expect(await lock.verifyPin('5555'), PinResult.decoy);
    expect(lock.quiet, isTrue);
    lock.lock();
    for (var i = 0; i < 3; i++) {
      expect(await lock.verifyPin('0000'), PinResult.invalid);
    }
    expect(countersOf(store)['b'], 7);
    expect(await lock.verifyPin('246810'), PinResult.vault);
    expect(countersOf(store), containsPair('r', 0));
    expect(countersOf(store), containsPair('b', 0));
    expect(countersOf(store), containsPair('q', false));
    expect(lock.quiet, isFalse);
    expect(await quietNow(store), isFalse);
    // the decoy's vault counts as the decoy: quiet, and the budget kept
    lock.lock();
    for (var i = 0; i < 3; i++) {
      await lock.verifyPin('0000');
    }
    expect(await lock.verifyPin('135790'), PinResult.decoy);
    expect(countersOf(store), containsPair('r', 0));
    expect(countersOf(store), containsPair('b', 3));
    expect(await quietNow(store), isTrue);
  });

  test('a held vault pin is throttled, the wipe pin still wipes', () async {
    final lock = await make();
    final seen = <PinResult>[];
    lock.onOutcome = (r, {vaultKey}) async => seen.add(r);
    for (var i = 0; i < 5; i++) {
      expect(await lock.verifyPin('0000'), PinResult.invalid);
    }
    expect(await lock.verifyPin('246810'), PinResult.throttled);
    expect(await lock.verifyPin('135790'), PinResult.throttled);
    expect(lock.locked, isTrue);
    expect(seen, isEmpty);
    expect(await lock.verifyPin('9999'), PinResult.panic);
    clock.up += 31000;
    expect(await lock.verifyPin('246810'), PinResult.vault);
    expect(seen, [PinResult.vault]);
  });

  test('the fingerprint never opens the vault', () async {
    // a phone with a finger: local_auth answers through its channel
    TestWidgetsFlutterBinding.ensureInitialized();
    const ch = MethodChannel('plugins.flutter.io/local_auth');
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      ch,
      (c) async =>
          c.method == 'getAvailableBiometrics' ? <String>['fingerprint'] : null,
    );
    addTearDown(() => m.setMockMethodCallHandler(ch, null));
    store.m['halo.lock.biometric'] = 'true';
    final lock = await make();
    expect(lock.bioSupported, isTrue);
    final seen = <(PinResult, String?)>[];
    // the session sets inVault, as it sets inDecoy
    lock.onOutcome = (r, {vaultKey}) async {
      seen.add((r, vaultKey));
      lock.inVault = vaultKey != null;
    };
    expect(await lock.tryBiometric(), isTrue);
    expect(await lock.verifyPin('246810'), PinResult.vault);
    expect(lock.inVault, isTrue);
    lock.lock();
    expect(await lock.tryBiometric(), isTrue);
    expect(lock.inVault, isFalse);
    expect(seen, [
      (PinResult.normal, null),
      (PinResult.vault, vKey),
      (PinResult.normal, null),
    ]);
  });

  test(
    'a v1 table moves to v2 in one write, a failed one loses nothing',
    () async {
      store.m['halo.lock.table'] = table({
        PinSlot.app: ('1234', PinKind.everyday),
        PinSlot.wipe: ('9999', PinKind.wipe),
        PinSlot.decoy: ('5555', PinKind.decoy),
      }, v: 1);
      // a wipe pin still the legacy kind
      store.m['halo.lock.panic_salt'] = 'Yg==';
      store.m['halo.lock.panic_hash'] = FakeEngine.legacyHash('1357', 'Yg==');
      final v1 = store.m['halo.lock.table'];

      Future<void> samePins(LockState lock) async {
        for (final (pin, want) in [
          ('1234', PinResult.normal),
          ('5555', PinResult.decoy),
          ('0000', PinResult.invalid),
          ('9999', PinResult.panic),
          ('1357', PinResult.panic),
        ]) {
          expect(await lock.verifyPin(pin), want, reason: pin);
          lock.lock();
        }
      }

      // the upgrade's write is the first, and it fails
      store.failWrite = 1;
      var lock = await make();
      store.failWrite = null;
      expect(engine.calls, contains('upgrade'));
      expect(lock.unreadable, isFalse);
      expect(lock.locked, isTrue);
      expect(store.m['halo.lock.table'], v1);
      await samePins(lock);

      // the next start upgrades, in one write
      store.log.clear();
      engine.calls.clear();
      lock = await make();
      expect(store.log.where((l) => !l.startsWith('r ')), [
        'w halo.lock.table',
      ]);
      expect(engine.calls.where((c) => c == 'upgrade'), hasLength(1));
      expect(jsonDecode(store.m['halo.lock.table']!)['v'], 2);
      await samePins(lock);

      // and never again
      store.log.clear();
      engine.calls.clear();
      lock = await make();
      expect(store.log.where((l) => !l.startsWith('r ')), isEmpty);
      expect(engine.calls, isNot(contains('upgrade')));
    },
  );

  test('a vault pin is set, changed and cleared on its own entry', () async {
    store.m['halo.lock.table'] = table({
      PinSlot.app: ('1234', PinKind.everyday),
      PinSlot.wipe: ('9999', PinKind.wipe),
      PinSlot.decoy: ('5555', PinKind.decoy),
    });
    final lock = await make();
    final keys = <String?>[];
    lock.onOutcome = (r, {vaultKey}) async => keys.add(vaultKey);
    expect(await lock.setupVaultPin('246810', vKey), isTrue);
    expect(entriesOf(store)['${PinSlot.vault}'], {
      'p': '246810',
      'k': PinKind.vault,
      'c': HaloContainer.vault.id,
      'w': vKey,
    });
    lock.lock();
    expect(await lock.verifyPin('246810'), PinResult.vault);
    lock.inVault = true;
    expect(
      await lock.confirmPin('246810', changesVault: true),
      PinResult.normal,
    );
    expect(await lock.rewrapVaultPin('246810', '864200'), isTrue);
    lock.inVault = false;
    lock.lock();
    expect(await lock.verifyPin('246810'), PinResult.invalid);
    expect(await lock.verifyPin('864200'), PinResult.vault);
    // the same key, under the new pin
    expect(keys, [vKey, vKey]);
    await lock.clearVault();
    expect(entriesOf(store).containsKey('${PinSlot.vault}'), isFalse);
    lock.lock();
    expect(await lock.verifyPin('864200'), PinResult.invalid);
  });

  test('inside the decoy its vault is its own entry', () async {
    store.m['halo.lock.table'] = table(
      {
        PinSlot.app: ('1234', PinKind.everyday),
        PinSlot.decoy: ('5555', PinKind.decoy),
        PinSlot.vault: ('246810', PinKind.vault),
      },
      wraps: {PinSlot.vault: vKey},
    );
    final lock = await make();
    final seen = <(PinResult, String?)>[];
    lock.onOutcome = (r, {vaultKey}) async => seen.add((r, vaultKey));
    lock.inDecoy = true;
    expect(await lock.setupVaultPin('112233', dvKey), isTrue);
    expect(entriesOf(store)['${PinSlot.decoyVault}'], {
      'p': '112233',
      'k': PinKind.vault,
      'c': HaloContainer.decoyVault.id,
      'w': dvKey,
    });
    lock.inVault = true;
    expect(await lock.rewrapVaultPin('112233', '445566'), isTrue);
    lock.inVault = false;
    lock.inDecoy = false;
    lock.lock();
    expect(await lock.verifyPin('445566'), PinResult.decoy);
    expect(lock.quiet, isTrue);
    lock.lock();
    // the everyday vault is untouched
    expect(await lock.verifyPin('246810'), PinResult.vault);
    expect(seen, [(PinResult.decoy, dvKey), (PinResult.vault, vKey)]);
    // its vault goes when the decoy goes
    await lock.clearDecoyPins();
    expect(entriesOf(store).containsKey('${PinSlot.decoyVault}'), isFalse);
    expect(entriesOf(store).containsKey('${PinSlot.vault}'), isTrue);
  });

  test('a vault key that is not one is refused before the engine', () async {
    final lock = await make();
    for (final k in ['', 'zz' * 32, '1f' * 31, '${vKey}00']) {
      store.log.clear();
      engine.calls.clear();
      await expectLater(lock.setupVaultPin('112233', k), throwsArgumentError);
      expect(engine.calls, isEmpty, reason: k);
      expect(store.log, isEmpty, reason: k);
    }
  });

  test('a change that cannot be made writes nothing but its try', () async {
    final lock = await make();
    final before = store.m['halo.lock.table'];
    // a wrong old pin. the flow only passes one confirmPin took
    await expectLater(
      lock.rewrapVaultPin('000000', '112233'),
      throwsStateError,
    );
    expect(store.m['halo.lock.table'], before);
    // an entry that wraps no key
    store.m['halo.lock.table'] = table({
      PinSlot.app: ('1234', PinKind.everyday),
      PinSlot.vault: ('246810', PinKind.vault),
    });
    final bare = store.m['halo.lock.table'];
    final again = await make();
    await expectLater(
      again.rewrapVaultPin('246810', '112233'),
      throwsStateError,
    );
    expect(store.m['halo.lock.table'], bare);
    // each one a try, as any set is
    expect(countersOf(store)['r'], 2);
  });

  test('confirming inside a vault takes its pin', () async {
    final lock = await make();
    // holds would hide the answers: each call comes an hour after the last
    Future<PinResult> confirm(String pin, {bool changes = false}) async {
      final r = await lock.confirmPin(pin, changesVault: changes);
      clock.up += 3600000;
      return r;
    }

    // the everyday session: a vault pin is a wrong one, and counts
    expect(await confirm('246810'), PinResult.invalid);
    expect(await confirm('135790', changes: true), PinResult.invalid);
    expect(countersOf(store)['b'], 2);
    expect(await confirm('1234', changes: true), PinResult.normal);
    // the everyday vault: the app pin or its own, and only its own for a
    // flow that changes it
    lock.inVault = true;
    expect(await confirm('1234'), PinResult.normal);
    expect(await confirm('246810'), PinResult.normal);
    expect(await confirm('246810', changes: true), PinResult.normal);
    expect(await confirm('1234', changes: true), PinResult.invalid);
    expect(await confirm('135790'), PinResult.invalid);
    expect(await confirm('5555'), PinResult.invalid);
    expect(await confirm('9999'), PinResult.panic);
    // the decoy's vault: the decoy pin or its own
    lock.inDecoy = true;
    expect(await confirm('5555'), PinResult.normal);
    expect(await confirm('135790'), PinResult.normal);
    expect(await confirm('135790', changes: true), PinResult.normal);
    expect(await confirm('5555', changes: true), PinResult.invalid);
    expect(await confirm('246810'), PinResult.invalid);
    expect(await confirm('1234'), PinResult.invalid);
    // and a vault pin is never a match in the decoy itself
    lock.inVault = false;
    expect(await confirm('135790'), PinResult.invalid);
  });

  test('a clash never says which pin it hit', () async {
    final lock = await make();
    final before = store.m['halo.lock.table'];
    const pins = {
      'app': '1234',
      'wipe': '9999',
      'decoy': '5555',
      'vault': '246810',
      'decoy vault': '135790',
    };
    final setups = <String, Future<bool> Function(String)>{
      'app': lock.setupPin,
      'wipe': lock.setupPanicPin,
      'vault': (p) => lock.setupVaultPin(p, vKey),
      'vault change': (p) => lock.rewrapVaultPin('246810', p),
    };
    var misses = 0;
    for (final s in setups.entries) {
      for (final p in pins.entries) {
        // its own pin is no clash
        if (s.key.split(' ').first == p.key) continue;
        final why = '${s.key} to the ${p.key} pin';
        // past the hold the try before left
        clock.up += 8 * 3600000;
        store.log.clear();
        engine.calls.clear();
        expect(await s.value(p.value), isFalse, reason: why);
        misses++;
        expect(store.log, ['w halo.lock.state'], reason: why);
        expect(engine.calls, hasLength(1), reason: why);
        expect(store.m['halo.lock.table'], before, reason: why);
        expect(countersOf(store)['b'], misses, reason: why);
      }
    }
    expect(misses, 16);

    // inside the decoy a clash looks like success and is kept nowhere. each
    // set is a try, past the hold the one before left
    lock.inDecoy = true;
    for (final pin in ['1234', '9999', '246810']) {
      clock.up += 8 * 3600000;
      expect(await lock.setupVaultPin(pin, dvKey), isTrue, reason: pin);
      lock.inVault = true;
      clock.up += 8 * 3600000;
      expect(await lock.rewrapVaultPin('135790', pin), isTrue, reason: pin);
      lock.inVault = false;
    }
    expect(store.m['halo.lock.table'], before);
    expect(countersOf(store)['b'], misses + 6);
    lock.inDecoy = false;
    lock.lock();
    // past the holds the clashes above left
    clock.up += 8 * 3600000;
    expect(await lock.verifyPin('246810'), PinResult.vault);
    lock.lock();
    expect(await lock.verifyPin('135790'), PinResult.decoy);
  });

  test('no vault without an app lock', () async {
    store.m.remove('halo.lock.enabled');
    final lock = await make();
    await expectLater(lock.setupVaultPin('112233', vKey), throwsStateError);
    expect(engine.calls, isNot(contains('setup')));
  });
}
