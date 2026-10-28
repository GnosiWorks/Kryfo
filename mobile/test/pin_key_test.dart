// SPDX-License-Identifier: GPL-3.0-or-later
// the pin key at the lock: one call per check whatever was typed, every pin
// moving under it the first time it opens something, a pin key that fails,
// hangs or is gone never counting a miss, never deleted or made again over
// a v3 table, one lane for every table write, and the update card that
// answers every pin the same way at the same moment
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/pin_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_key_fakes.dart';

class CountStore implements LockStore {
  final Map<String, String> m = {};
  final List<String> log = [];
  int writes = 0, deletes = 0;

  @override
  Future<String?> read(String key) async => m[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    log.add('w $key');
    m[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes++;
    log.add('d $key');
    m.remove(key);
  }
}

class StillClock implements LockClock {
  @override
  Future<int> uptimeMs() async => 1000000;
  @override
  Future<int> bootCount() async => 7;
}

class NoBio implements LockBio {
  @override
  Future<bool> ready() async => false;
  @override
  Future<String> state() async => 'none';
  @override
  Future<String?> seal(String opens) async => null;
  @override
  Future<void> disable() async {}
  @override
  Future<BioOpened> unlock(String title, String cancel, String seal) async =>
      const BioOpened('none');
}

final vKey = '1f' * 32;
final dvKey = '2e' * 32;

String containerOf(int index, int kind) => switch (kind) {
  PinKind.decoy => HaloContainer.decoy.id,
  PinKind.vault when index == PinSlot.decoyVault => HaloContainer.decoyVault.id,
  PinKind.vault => HaloContainer.vault.id,
  _ => HaloContainer.everyday.id,
};

const pins = {
  PinSlot.app: ('1234', PinKind.everyday),
  PinSlot.wipe: ('9999', PinKind.wipe),
  PinSlot.decoy: ('5555', PinKind.decoy),
  PinSlot.vault: ('246810', PinKind.vault),
  PinSlot.decoyWipe: ('4444', PinKind.wipe),
  PinSlot.decoyDecoy: ('3333', PinKind.decoy),
  PinSlot.decoyVault: ('135790', PinKind.vault),
};

// a table from before the pin key: every entry under its pin alone
String v2Table() => jsonEncode({
  'v': 2,
  'n': 15,
  'e': {
    for (final e in pins.entries)
      '${e.key}': {
        'p': e.value.$1,
        'k': e.value.$2,
        'c': containerOf(e.key, e.value.$2),
        'w': e.key == PinSlot.vault
            ? vKey
            : e.key == PinSlot.decoyVault
            ? dvKey
            : '',
        'g': 2,
      },
  },
});

Map<String, dynamic> tableOf(CountStore s) =>
    jsonDecode(s.m['halo.lock.table']!) as Map<String, dynamic>;

Map<String, dynamic> entriesOf(CountStore s) =>
    tableOf(s)['e'] as Map<String, dynamic>;

int gOf(CountStore s, int slot) => (entriesOf(s)['$slot'] as Map)['g'] as int;

void main() {
  late CountStore store;
  late KeyEngine engine;
  late FakeKeys keys;

  Future<LockState> make({
    Duration reveal = Duration.zero,
    Duration macWait = const Duration(seconds: 10),
    Duration cardPad = const Duration(milliseconds: 1200),
  }) async {
    final s = LockState(
      store: store,
      engine: engine,
      clock: StillClock(),
      bio: NoBio(),
      keys: keys,
      revealAfter: reveal,
      macWait: macWait,
      cardPad: cardPad,
    );
    await s.load();
    return s;
  }

  // an everyday lock from before 0.6, with every pin set
  void seed({bool keyThere = false}) {
    store = CountStore();
    engine = KeyEngine();
    keys = FakeKeys(exists: keyThere);
    store.m['halo.lock.enabled'] = 'true';
    store.m['halo.lock.panic_enabled'] = 'true';
    store.m['halo.lock.table'] = v2Table();
    store.m[kListedContainers] = HaloContainer.decoy.id;
  }

  // every pin opened once, so the whole table is under the pin key
  Future<LockState> moved() async {
    seed();
    final s = await make(cardPad: Duration.zero);
    for (final p in ['1234', '5555', '246810', '3333', '135790']) {
      await s.verifyPin(p);
      s.inDecoy = false;
      s.inVault = false;
    }
    for (final p in ['9999', '4444']) {
      await s.cardTry(p);
    }
    expect(entriesOf(store).values.every((e) => e['g'] == 3), isTrue);
    store.m['halo.lock.state'] = const LockCounters().encode();
    return make();
  }

  setUp(() {
    decoyReady = true;
    SharedPreferences.setMockInitialValues({});
    seed();
  });

  group('the first unlock after the update', () {
    test(
      'makes the key, moves the pin that opened and marks the card',
      () async {
        final s = await make();
        expect(store.m['halo.lock.card'], '1');
        expect(keys.calls, ['info']);
        expect(await s.verifyPin('1234'), PinResult.normal);
        expect(keys.calls, ['info', 'make', 'mac']);
        final t = tableOf(store);
        expect(t['v'], 3);
        expect(t['k'], {'g': 1, 'u': 1, 'l': 2, 'kc': keys.kc});
        expect(gOf(store, PinSlot.app), 3);
        for (final slot in [1, 2, 3, 4, 5, 6]) {
          expect(gOf(store, slot), 2, reason: 'slot $slot moved too');
        }
      },
    );

    test(
      'every entry moves on its own use, the vault keeping its key',
      () async {
        final s = await make();
        for (final (pin, slot, want) in [
          ('246810', PinSlot.vault, PinResult.vault),
          ('5555', PinSlot.decoy, PinResult.decoy),
          ('135790', PinSlot.decoyVault, PinResult.decoy),
          ('3333', PinSlot.decoyDecoy, PinResult.decoy),
          ('1234', PinSlot.app, PinResult.normal),
        ]) {
          expect(await s.verifyPin(pin), want, reason: pin);
          expect(gOf(store, slot), 3, reason: pin);
        }
        expect((entriesOf(store)['${PinSlot.vault}'] as Map)['w'], vKey);
        expect((entriesOf(store)['${PinSlot.decoyVault}'] as Map)['w'], dvKey);
        // the wipe pins are typed nowhere but the card
        expect(gOf(store, PinSlot.wipe), 2);
        expect(gOf(store, PinSlot.decoyWipe), 2);
      },
    );

    test('a refused key leaves the table and shows no card', () async {
      keys.refuseMake = true;
      final s = await make();
      final before = store.m['halo.lock.table'];
      expect(await s.verifyPin('1234'), PinResult.normal);
      expect(store.m['halo.lock.table'], before);
      expect(s.updateCard, isFalse);
      expect(keys.macs, 0);
      // and it is not asked again at every unlock
      await s.verifyPin('1234');
      expect(keys.calls.where((c) => c == 'make'), hasLength(1));
    });

    test('a miss, a hold, a wipe or a decoy not ready moves nothing', () async {
      final s = await make();
      decoyReady = false;
      final before = store.m['halo.lock.table'];
      expect(await s.verifyPin('0000'), PinResult.invalid);
      expect(await s.verifyPin('5555'), PinResult.invalid);
      expect(await s.verifyPin('9999'), PinResult.panic);
      expect(store.m['halo.lock.table'], before);
    });
  });

  group('one pin key call per check', () {
    test('whatever is typed, on the lock screen', () async {
      final s = await moved();
      keys.calls.clear();
      for (final pin in [
        '1234',
        '9999',
        '5555',
        '246810',
        '135790',
        '4444',
        '3333',
        '0000',
        'correct horse battery',
      ]) {
        final before = keys.macs;
        await s.verifyPin(pin);
        expect(keys.macs - before, 1, reason: pin);
        s.inDecoy = false;
        s.inVault = false;
      }
      expect(keys.calls.toSet(), {'mac'});
    });

    test('on a half moved table, moved and unmoved alike', () async {
      final s = await make();
      await s.verifyPin('1234');
      keys.calls.clear();
      for (final pin in ['1234', '246810', '5555', '0000', '9999']) {
        final before = keys.macs;
        await s.verifyPin(pin);
        expect(keys.macs - before, 1, reason: pin);
        s.inDecoy = false;
        s.inVault = false;
      }
    });

    test('confirm, the card and every set: one; a rewrap: two', () async {
      final s = await moved();
      s.inVault = true;
      for (final pin in ['1234', '246810', '0000', '9999']) {
        final before = keys.macs;
        await s.confirmPin(pin);
        expect(keys.macs - before, 1, reason: 'confirm $pin');
      }
      store.m['halo.lock.state'] = const LockCounters().encode();
      final s2 = await make();
      for (final pin in ['1234', '0000']) {
        final before = keys.macs;
        await s2.cardTry(pin);
        expect(keys.macs - before, 1, reason: 'card $pin');
      }
      store.m['halo.lock.state'] = const LockCounters().encode();
      final s3 = await make();
      var before = keys.macs;
      await s3.setupPanicPin('7777');
      expect(keys.macs - before, 1);
      before = keys.macs;
      s3.inVault = true;
      await s3.rewrapVaultPin('246810', '112233');
      expect(keys.macs - before, 2);
    });

    test('the stand-in check of a legacy pin makes its call too', () async {
      store = CountStore();
      keys = FakeKeys(exists: true);
      store.m['halo.lock.enabled'] = 'true';
      store.m['halo.lock.pin_salt'] = 'YQ==';
      store.m['halo.lock.pin_hash'] = KeyEngine.legacyHash('8642', 'YQ==');
      final s = await make();
      keys.calls.clear();
      // the legacy pin last: its move into a new table runs after it
      for (final pin in ['0000', '8642']) {
        final before = keys.macs;
        await s.verifyPin(pin);
        expect(keys.macs - before, 1, reason: pin);
      }
    });
  });

  group('a pin key that fails', () {
    test(
      'busy: a pin only it could check is no miss and moves nothing',
      () async {
        final s = await moved();
        keys.fail = KeyFail.busy;
        keys.calls.clear();
        final table = store.m['halo.lock.table'];
        final w = store.log.length;
        for (final pin in ['1234', '0000', '246810']) {
          expect(await s.verifyPin(pin), PinResult.unavailable, reason: pin);
        }
        // only its own run is written: no table, no miss
        expect(store.log.sublist(w).toSet(), {'w halo.lock.state'});
        expect(store.m['halo.lock.table'], table);
        final c = jsonDecode(store.m['halo.lock.state']!) as Map;
        expect(c['r'], 0);
        expect(c['u'], 3);
        expect(s.keyNote, KeyNote.busy);
        expect(s.throttleLeft, Duration.zero);
        keys.fail = null;
        expect(await s.verifyPin('1234'), PinResult.normal);
        expect(s.keyNote, isNull);
        expect(keys.calls, isNot(contains('drop')));
        expect(keys.calls, isNot(contains('make')));
      },
    );

    test('an entry not moved yet still opens, and is not moved', () async {
      final s = await make();
      await s.verifyPin('1234');
      keys.fail = KeyFail.busy;
      final before = store.m['halo.lock.table'];
      expect(await s.verifyPin('246810'), PinResult.vault);
      expect(store.m['halo.lock.table'], before);
      expect(await s.verifyPin('1234'), PinResult.unavailable);
    });

    test('locked: the line says to unlock the phone, no miss', () async {
      final s = await moved();
      keys.fail = KeyFail.locked;
      expect(await s.verifyPin('0000'), PinResult.unavailable);
      expect(s.keyNote, KeyNote.locked);
      expect(await s.confirmPin('1234'), PinResult.unavailable);
    });

    test('a hung call is left behind and counts nothing', () async {
      await moved();
      final s2 = LockState(
        store: store,
        engine: engine,
        clock: StillClock(),
        bio: NoBio(),
        keys: keys,
        revealAfter: Duration.zero,
        macWait: const Duration(milliseconds: 60),
      );
      await s2.load();
      keys.hang = Completer<void>();
      final t0 = DateTime.now();
      expect(await s2.verifyPin('1234'), PinResult.unavailable);
      expect(
        DateTime.now().difference(t0),
        lessThan(const Duration(seconds: 2)),
      );
      expect(s2.throttleLeft, Duration.zero);
      keys.hang!.complete();
      keys.hang = null;
    });

    test('a set while it fails is refused and writes nothing', () async {
      final s = await moved();
      keys.fail = KeyFail.busy;
      final before = store.m['halo.lock.table'];
      await expectLater(s.setupPanicPin('7777'), throwsA(isA<PinKeyBusy>()));
      expect(store.m['halo.lock.table'], before);
    });

    test('gone with a v3 table: shown, never made again, no misses', () async {
      await moved();
      keys.exists = false;
      keys.calls.clear();
      final s = await make();
      expect(s.keyNote, KeyNote.lost);
      for (var i = 0; i < 4; i++) {
        expect(await s.verifyPin('0000'), PinResult.unavailable);
      }
      expect(s.throttleLeft, Duration.zero);
      expect(keys.calls, isNot(contains('make')));
      expect(keys.calls, isNot(contains('drop')));
      expect(s.updateCard, isFalse);
      expect(s.keyLine, isNull);
      await expectLater(s.setupPanicPin('7777'), throwsA(isA<PinKeyBusy>()));
      expect(keys.calls, isNot(contains('make')));
    });

    test('a key replaced under the same name is the old one lost', () async {
      await moved();
      keys.replace();
      keys.calls.clear();
      final s = await make();
      expect(s.keyNote, KeyNote.lost);
      expect(await s.verifyPin('1234'), PinResult.unavailable);
      expect(keys.calls, isNot(contains('make')));
    });

    test(
      'gone while the table is v2 loses nothing and is made again',
      () async {
        keys = FakeKeys(exists: true);
        final s = await make();
        keys.exists = false;
        expect(await s.verifyPin('1234'), PinResult.normal);
        expect(tableOf(store)['v'], 2);
      },
    );
  });

  group('one lane for the table', () {
    test(
      'a move worked out before a new vault never puts the old one back',
      () async {
        final s = await make();
        await s.verifyPin('1234');
        engine.gate = Completer<void>();
        final opening = s.verifyPin('246810');
        // the check waits after the pin key: a new vault lands meanwhile
        await Future<void>.delayed(Duration.zero);
        await s.clearVault();
        expect(await s.setupVaultPin('112233', '3c' * 32), isTrue);
        engine.gate!.complete();
        engine.gate = null;
        expect(await opening, PinResult.vault);
        final v = entriesOf(store)['${PinSlot.vault}'] as Map;
        expect(v['p'], '112233');
        expect(v['w'], '3c' * 32);
      },
    );

    test(
      'writes run one after another, each from the table there is',
      () async {
        final s = await moved();
        await Future.wait([
          s.setupPanicPin('7777'),
          s.clearVault(),
          s.disablePanicPin(),
        ]);
        // the set waited for its try, so it landed last, on the table the
        // two clears left
        final e = entriesOf(store);
        expect(e.containsKey('${PinSlot.vault}'), isFalse);
        expect((e['${PinSlot.wipe}'] as Map)['p'], '7777');
        expect(e['${PinSlot.app}'], isNotNull);
        expect(e['${PinSlot.decoyVault}'], isNotNull);
      },
    );
  });

  group('the update card', () {
    test(
      'every pin: the same answer, the same time, one table write',
      () async {
        final s = await make(cardPad: const Duration(milliseconds: 120));
        await s.verifyPin('1234');
        for (final pin in ['1234', '9999', '5555', '246810', '4444', '0000']) {
          store.m['halo.lock.state'] = const LockCounters().encode();
          final s3 = await make(cardPad: const Duration(milliseconds: 120));
          final w = store.log.length;
          final t0 = Stopwatch()..start();
          expect(await s3.cardTry(pin), CardAnswer.taken, reason: pin);
          final took = t0.elapsed;
          expect(took, greaterThanOrEqualTo(const Duration(milliseconds: 120)));
          expect(store.log.sublist(w), [
            'w halo.lock.state',
            'w halo.lock.table',
          ], reason: pin);
          expect(s3.inDecoy, isFalse);
        }
        // and every one typed there moved
        for (final slot in [0, 1, 2, 3, 4]) {
          expect(gOf(store, slot), 3, reason: 'slot $slot');
        }
      },
    );

    test(
      'the wipe pin there never wipes, the decoy pin never switches',
      () async {
        final s = await make();
        await s.verifyPin('1234');
        var outcomes = 0;
        for (final pin in ['9999', '5555', '246810']) {
          store.m['halo.lock.state'] = const LockCounters().encode();
          final s2 = await make(cardPad: Duration.zero);
          s2.onOutcome = (r, {vaultKey}) async => outcomes++;
          expect(await s2.cardTry(pin), CardAnswer.taken);
          expect(s2.inDecoy, isFalse);
          expect(s2.inVault, isFalse);
        }
        expect(outcomes, 0);
        expect(store.m['halo.lock.table'], isNotNull);
      },
    );

    test('every input is a try, a real pin too, refused when held', () async {
      final s = await make(cardPad: Duration.zero);
      await s.verifyPin('1234');
      for (var i = 0; i < 4; i++) {
        expect(await s.cardTry('1234'), CardAnswer.taken);
      }
      expect(await s.cardTry('0000'), CardAnswer.taken);
      final checks = engine.calls.where((c) => c == 'check').length;
      expect(await s.cardTry('1234'), CardAnswer.held);
      expect(engine.calls.where((c) => c == 'check').length, checks);
    });

    test('in a decoy session: shown alike, nothing moves', () async {
      final s = await make(cardPad: Duration.zero);
      await s.verifyPin('1234');
      s.inDecoy = true;
      expect(s.updateCard, isTrue);
      final before = store.m['halo.lock.table'];
      for (final pin in ['5555', '9999', '0000']) {
        final w = store.log.length;
        expect(await s.cardTry(pin), CardAnswer.taken);
        expect(store.log.sublist(w), [
          'w halo.lock.state',
          'w halo.lock.table',
        ]);
      }
      expect(entriesOf(store), jsonDecode(before!)['e']);
      // done there ends it there only
      await s.cardFinished();
      expect(s.updateCard, isFalse);
      s.inDecoy = false;
      expect(s.updateCard, isTrue);
      await s.cardFinished();
      expect(s.updateCard, isFalse);
      expect((await make()).updateCard, isFalse);
    });

    test('never on a lock set up on 0.6', () async {
      store = CountStore();
      final s = await make();
      expect(await s.setupPin('1234'), isTrue);
      expect(store.m['halo.lock.card'], '0');
      expect(tableOf(store)['v'], 3);
      expect(s.updateCard, isFalse);
      expect((await make()).updateCard, isFalse);
    });

    test('away while the pin key fails or is gone', () async {
      final s = await make();
      await s.verifyPin('1234');
      expect(s.updateCard, isTrue);
      keys.fail = KeyFail.busy;
      expect(await s.cardTry('5555'), CardAnswer.unavailable);
      expect(s.updateCard, isFalse);
    });

    test('moves the legacy wipe pin and lets its hash go', () async {
      store.m['halo.lock.panic_salt'] = 'Yg==';
      store.m['halo.lock.panic_hash'] = KeyEngine.legacyHash('7531', 'Yg==');
      final s = await make(cardPad: Duration.zero);
      await s.verifyPin('1234');
      await s.disablePanicPin();
      store.m['halo.lock.panic_salt'] = 'Yg==';
      store.m['halo.lock.panic_hash'] = KeyEngine.legacyHash('7531', 'Yg==');
      // an old version's wipe pin that showed on
      store.m['halo.lock.panic_enabled'] = 'true';
      final s2 = await make(cardPad: Duration.zero);
      expect(s2.legacyWipe, isTrue);
      expect(await s2.cardTry('7531'), CardAnswer.taken);
      expect(store.m.containsKey('halo.lock.panic_hash'), isFalse);
      expect(store.m['halo.lock.panic_enabled'], 'true');
      expect(gOf(store, PinSlot.wipe), 3);
      expect(await s2.verifyPin('7531'), PinResult.panic);
    });
  });

  test('a legacy app pin moves in the unlock check itself', () async {
    store = CountStore();
    keys = FakeKeys(exists: true);
    store.m['halo.lock.enabled'] = 'true';
    store.m['halo.lock.table'] = jsonEncode({
      'v': 2,
      'n': 15,
      'e': <String, dynamic>{},
    });
    store.m['halo.lock.pin_salt'] = 'YQ==';
    store.m['halo.lock.pin_hash'] = KeyEngine.legacyHash('8642', 'YQ==');
    final s = await make();
    expect(await s.verifyPin('8642'), PinResult.normal);
    await Future<void>.delayed(Duration.zero);
    expect(engine.calls.where((c) => c == 'setup'), isEmpty);
    expect(store.m.containsKey('halo.lock.pin_hash'), isFalse);
    expect(gOf(store, PinSlot.app), 3);
    expect(await s.verifyPin('8642'), PinResult.normal);
  });

  test('a confirm miss with the vault pin writes as any miss does', () async {
    final s = await make();
    await s.verifyPin('1234');
    final w1 = store.log.length;
    expect(await s.confirmPin('0000'), PinResult.invalid);
    final miss = store.log.sublist(w1);
    final w2 = store.log.length;
    expect(await s.confirmPin('246810'), PinResult.invalid);
    expect(store.log.sublist(w2), miss);
    expect(gOf(store, PinSlot.vault), 2);
  });

  test('turning the lock off drops the pin key after the table', () async {
    final s = await moved();
    await s.disable();
    final t = store.log.lastIndexOf('d halo.lock.table');
    expect(t, greaterThanOrEqualTo(0));
    expect(keys.calls.last, 'drop');
    expect(store.m.containsKey('halo.lock.card'), isFalse);
    // a pin set again makes a new key and a fresh table
    expect(await s.setupPin('2468'), isTrue);
    expect(keys.calls.where((c) => c == 'make'), isNotEmpty);
    expect(tableOf(store)['v'], 3);
  });

  test('the line follows the key and the phone, the decoy alike', () async {
    final s = await make();
    expect(s.keyLine, isNull);
    await s.verifyPin('1234');
    expect(s.keyLine!.unlocked, isTrue);
    expect(s.keyLine!.screenLock, isTrue);
    s.inDecoy = true;
    expect(s.keyLine!.unlocked, isTrue);
    keys.screenLock = false;
    await s.recheckKey();
    expect(s.keyLine!.screenLock, isFalse);
    keys.level = PinKeyInfo.software;
    await s.recheckKey();
    expect(s.keyLine, isNull);
  });

  test('an outcome waits past the slowest check', () async {
    await moved();
    final s2 = LockState(
      store: store,
      engine: engine,
      clock: StillClock(),
      bio: NoBio(),
      keys: keys,
      revealAfter: const Duration(milliseconds: 40),
    );
    await s2.load();
    engine.gate = Completer<void>();
    final slow = s2.verifyPin('0000');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    engine.gate!.complete();
    engine.gate = null;
    await slow;
    final t0 = DateTime.now();
    await s2.verifyPin('0000');
    expect(
      DateTime.now().difference(t0),
      greaterThanOrEqualTo(const Duration(milliseconds: 200)),
    );
  });

  group('review fixes', () {
    test('one false "no key" read clears and offers no reset', () async {
      await moved();
      keys.infoFalseOnce = true;
      keys.calls.clear();
      final s = await make();
      expect(s.keyNote, KeyNote.lost);
      expect(s.resetOffered, isFalse);
      expect(await s.recheckLost(), isFalse);
      expect(s.keyNote, isNull);
      expect(await s.verifyPin('1234'), PinResult.normal);
      expect(keys.calls, isNot(contains('make')));
    });

    test('a loss that holds across two reads offers reset', () async {
      await moved();
      keys.exists = false;
      final s = LockState(
        store: store,
        engine: engine,
        clock: StillClock(),
        bio: NoBio(),
        keys: keys,
        revealAfter: Duration.zero,
        lostGap: Duration.zero,
      );
      await s.load();
      expect(s.keyNote, KeyNote.lost);
      expect(await s.recheckLost(), isTrue);
      expect(s.resetOffered, isTrue);
      // a key with another check value is sure at once
      keys.exists = true;
      keys.replace();
      final r = await make();
      expect(r.resetOffered, isTrue);
    });

    test(
      'five unanswered checks in a row hold the pad, an answer clears it',
      () async {
        final s = await moved();
        keys.fail = KeyFail.busy;
        for (var i = 0; i < 4; i++) {
          expect(await s.verifyPin('0000'), PinResult.unavailable);
        }
        expect(s.throttleLeft, Duration.zero);
        expect(await s.verifyPin('0000'), PinResult.unavailable);
        expect(s.throttleLeft, greaterThan(Duration.zero));
        expect(await s.verifyPin('0000'), PinResult.throttled);
        store.m['halo.lock.state'] = const LockCounters(unavail: 4).encode();
        final s2 = await make();
        keys.fail = null;
        expect(await s2.verifyPin('0000'), PinResult.invalid);
        final c = jsonDecode(store.m['halo.lock.state']!) as Map;
        expect(c.containsKey('u'), isFalse);
        expect(c['r'], 1);
      },
    );

    test('a handle the engine dropped is an unanswered check', () async {
      final s = await moved();
      engine.handleGone = true;
      expect(await s.verifyPin('1234'), PinResult.unavailable);
      expect(await s.verifyPin('1234'), PinResult.normal);
    });

    test('a vault entry whose key did not open is never moved', () async {
      store = CountStore();
      engine = KeyEngine();
      keys = FakeKeys(exists: true);
      store.m['halo.lock.enabled'] = 'true';
      store.m['halo.lock.table'] = jsonEncode({
        'v': 2,
        'n': 15,
        'e': {
          '0': {
            'p': '1234',
            'k': 1,
            'c': HaloContainer.everyday.id,
            'w': '',
            'g': 2,
          },
          '3': {
            'p': '246810',
            'k': 4,
            'c': HaloContainer.vault.id,
            'w': '',
            'g': 2,
          },
        },
      });
      final s = await make(cardPad: Duration.zero);
      await s.verifyPin('1234');
      await s.verifyPin('246810');
      expect(gOf(store, PinSlot.vault), 2);
      await s.cardTry('246810');
      expect(gOf(store, PinSlot.vault), 2);
    });

    test(
      'an old wipe hash that never wiped is not moved by the card',
      () async {
        store.m.remove('halo.lock.panic_enabled');
        store.m['halo.lock.panic_salt'] = 'Yg==';
        store.m['halo.lock.panic_hash'] = KeyEngine.legacyHash('7531', 'Yg==');
        final s = await make(cardPad: Duration.zero);
        await s.verifyPin('1234');
        expect(s.panicEnabled, isFalse);
        expect(await s.cardTry('7531'), CardAnswer.taken);
        expect(s.panicEnabled, isFalse);
        expect(store.m.containsKey('halo.lock.panic_enabled'), isFalse);
        expect(store.m['halo.lock.panic_hash'], isNotNull);
      },
    );

    test(
      'an old hash beside a pin set since never moves back over it',
      () async {
        final s = await make(cardPad: Duration.zero);
        await s.verifyPin('1234');
        expect(await s.setupPanicPin('8080'), isTrue);
        expect(store.m['halo.lock.set.wipe'], 'true');
        // a stop between the table and the deletes left the old hash
        store.m['halo.lock.panic_salt'] = 'Yg==';
        store.m['halo.lock.panic_hash'] = KeyEngine.legacyHash('7531', 'Yg==');
        store.m['halo.lock.state'] = const LockCounters().encode();
        final s2 = await make(cardPad: Duration.zero);
        expect(store.m.containsKey('halo.lock.panic_hash'), isFalse);
        expect(s2.legacyWipe, isFalse);
        await s2.cardTry('7531');
        expect((entriesOf(store)['${PinSlot.wipe}'] as Map)['p'], '8080');
      },
    );

    test(
      'an old app hash beside the same app pin goes after an open',
      () async {
        final s = await make();
        await s.verifyPin('1234');
        store.m['halo.lock.pin_salt'] = 'YQ==';
        store.m['halo.lock.pin_hash'] = KeyEngine.legacyHash('1234', 'YQ==');
        final s2 = await make();
        expect(await s2.verifyPin('1234'), PinResult.normal);
        await Future<void>.delayed(Duration.zero);
        expect(store.m.containsKey('halo.lock.pin_hash'), isFalse);
        expect(store.m['halo.lock.set.app'], 'true');
        expect(s.locked, isFalse);
      },
    );
  });
}
