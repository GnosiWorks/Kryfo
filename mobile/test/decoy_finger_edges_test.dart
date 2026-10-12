// SPDX-License-Identifier: GPL-3.0-or-later
// the decoy's fingerprint at its edges: every finger unlock takes as long
// as any other, a seal that comes back late never replaces a newer one, a
// stop at any step of making a decoy never turns the owner's finger into
// the decoy's, a decoy that does not open leaves the counters as they
// were, and a decoy pin changed from the everyday app keeps the decoy's
// finger
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_setup_screen.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart';

const Map<int, (String, int)> _withDecoy = {
  ...appOnly,
  PinSlot.decoy: (decoyPin, PinKind.decoy),
};

const _bioKey = 'halo.lock.biometric';
const _sealKey = 'halo.lock.biometric.seal';
final _decoy = HaloContainer.decoy.id;
final _everyday = HaloContainer.everyday.id;

void _finger() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('plugins.flutter.io/local_auth');
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(
    ch,
    (c) async => switch (c.method) {
      'getAvailableBiometrics' => ['fingerprint'],
      'isDeviceSupported' => true,
      _ => null,
    },
  );
  addTearDown(() => m.setMockMethodCallHandler(ch, null));
}

// the sessions an unlock opens, as the app's sessionFor sets them, each
// taking [build] to put together
List<PinResult> _sessions(LockState s, {Duration build = Duration.zero}) {
  final seen = <PinResult>[];
  s.onOutcome = (r, {vaultKey}) async {
    seen.add(r);
    if (build > Duration.zero) await Future<void>.delayed(build);
    s.inDecoy = r == PinResult.decoy;
  };
  return seen;
}

// the keystore with its work in one queue, as BioKey.kt has it: the last
// seal asked for holds the key. each answer waits until let go, in any
// order, as channel replies may
class _QueuedBio implements LockBio {
  int _asked = 0;
  int _key = 0;
  bool added = false;
  final _gates = <int, Completer<void>>{};
  final _opens = <String, (int, String)>{};
  final asked = <String>[];

  @override
  Future<bool> ready() async => true;
  @override
  Future<String> state() async =>
      added ? 'invalidated' : (_key == 0 ? 'none' : 'ok');

  @override
  Future<String?> seal(String opens) async {
    final n = ++_asked;
    _key = n;
    added = false;
    asked.add(opens);
    final s = n.toRadixString(16).padLeft(514, 'c');
    _opens[s] = (n, opens);
    final g = _gates[n] = Completer<void>();
    if (n == 1) g.complete();
    await g.future;
    return s;
  }

  void letGo(int n) => _gates[n]!.complete();

  @override
  Future<void> disable() async {
    _key = 0;
  }

  @override
  Future<BioOpened> unlock(String title, String cancel, String seal) async {
    if (added) return const BioOpened('invalidated');
    final o = _opens[seal];
    if (o == null || o.$1 != _key) return const BioOpened('none');
    return BioOpened('ok', o.$2);
  }
}

class _Killed implements Exception {}

// storage that stops for good after [left] more changes, as a killed
// process does
class _KillStore implements LockStore {
  _KillStore(this.left, Map<String, String> from) {
    m.addAll(from);
  }
  int left;
  final Map<String, String> m = {};
  bool dead = false;

  void _tick() {
    if (dead || left-- <= 0) {
      dead = true;
      throw _Killed();
    }
  }

  @override
  Future<String?> read(String key) async {
    if (dead) throw _Killed();
    return m[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _tick();
    m[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _tick();
    m.remove(key);
  }
}

void main() {
  setUp(() => decoyReady = true);

  test('a finger unlock takes the same time whichever side it opens', () async {
    _finger();
    const reveal = Duration(milliseconds: 300);
    final fresh = await makeLock(appOnly, bio: SealBio(), revealAfter: reveal);
    await fresh.state.setBiometric(true);
    _sessions(fresh.state);
    final decoy = await makeLock(
      _withDecoy,
      bio: SealBio(),
      inDecoy: true,
      revealAfter: reveal,
    );
    await decoy.state.setBiometric(true);
    decoy.state.inDecoy = false;
    // the decoy's session takes a while to build
    _sessions(decoy.state, build: const Duration(milliseconds: 120));
    // once each first, so nothing measured is the first run of anything
    for (final s in [fresh.state, decoy.state]) {
      s.lock();
      expect(await s.tryBiometric(), isTrue);
    }
    decoy.state.inDecoy = false;
    final took = <int>[];
    for (final s in [fresh.state, decoy.state]) {
      s.lock();
      final w = Stopwatch()..start();
      expect(await s.tryBiometric(), isTrue);
      took.add(w.elapsedMilliseconds);
    }
    for (final ms in took) {
      expect(ms, greaterThanOrEqualTo(295));
    }
    expect((took[0] - took[1]).abs(), lessThan(250), reason: "$took");
  });

  test('a decoy finger that does not open waits as long too', () async {
    _finger();
    const reveal = Duration(milliseconds: 250);
    final lock = await makeLock(
      _withDecoy,
      bio: SealBio(),
      inDecoy: true,
      revealAfter: reveal,
    );
    final s = lock.state;
    await s.setBiometric(true);
    s.inDecoy = false;
    s.onOutcome = (r, {vaultKey}) async {};
    s.lock();
    final w = Stopwatch()..start();
    expect(await s.tryBiometric(), isFalse);
    expect(w.elapsedMilliseconds, greaterThanOrEqualTo(245));
  });

  test('a seal that comes back late never replaces a newer one', () async {
    _finger();
    final bio = _QueuedBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    final seen = _sessions(s);
    // seal 1, let go at once
    expect(await s.setBiometric(true), isTrue);
    bio.added = true;
    s.lock();
    expect(await s.tryBiometric(), isFalse);
    expect(s.bioStale, isTrue);
    // the pin: seal 2 goes out and waits
    expect(await s.verifyPin(decoyPin), PinResult.decoy);
    await Future<void>.delayed(Duration.zero);
    // turned off and on meanwhile: seal 3
    await s.setBiometric(false);
    final on = s.setBiometric(true);
    await Future<void>.delayed(Duration.zero);
    // the replies cross: 3 first, then 2
    bio.letGo(3);
    expect(await on, isTrue);
    final newest = lock.store.m[_sealKey];
    bio.letGo(2);
    await Future<void>.delayed(Duration.zero);
    expect(lock.store.m[_sealKey], newest);
    s.lock();
    seen.clear();
    expect(await s.tryBiometric(), isTrue);
    expect(seen, [PinResult.decoy]);
  });

  test('a finger turned off while a seal runs stays off', () async {
    _finger();
    final bio = _QueuedBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    _sessions(s);
    await s.setBiometric(true);
    bio.added = true;
    s.lock();
    await s.tryBiometric();
    expect(await s.verifyPin(appPin), PinResult.normal);
    await Future<void>.delayed(Duration.zero);
    s.inDecoy = true;
    await s.setBiometric(false);
    bio.letGo(2);
    await Future<void>.delayed(Duration.zero);
    expect(lock.store.m.containsKey(_sealKey), isFalse);
    expect(s.fingerUnlock, isFalse);
  });

  test('a stop at any step of making a decoy never turns the owner\'s '
      'finger into the decoy\'s', () async {
    _finger();
    var finished = false;
    for (var k = 0; !finished; k++) {
      // the owner's finger, on
      final bio = SealBio();
      final before = await makeLock(appOnly, bio: bio);
      expect(await before.state.setBiometric(true), isTrue);
      final store = _KillStore(k, before.store.m);
      final s = LockState(
        store: store,
        engine: MemEngine(),
        clock: StillClock(),
        bio: bio,
        revealAfter: Duration.zero,
      );
      await s.load();
      // as the app makes a decoy: the finger, the list, the pin
      try {
        await s.parkFingerForDecoy();
        await store.write(kListedContainers, _decoy);
        expect(await s.setupDecoyPin(decoyPin), isTrue);
        finished = true;
      } on _Killed {
        // stopped here
      }
      // started again on what was written
      final after = MemStore()..m.addAll(store.m);
      final listed = after.m[kListedContainers] == _decoy;
      final again = LockState(
        store: after,
        engine: MemEngine(),
        clock: StillClock(),
        bio: bio,
        revealAfter: Duration.zero,
      );
      await again.load();
      final seen = _sessions(again);
      final sealsBefore = bio.sealedFor.length;
      expect(await again.verifyPin(appPin), PinResult.normal, reason: '$k');
      await Future<void>.delayed(Duration.zero);
      if (listed) {
        expect(bio.sealedFor.skip(sealsBefore), isNot(contains(_decoy)));
        again.lock();
        seen.clear();
        expect(await again.tryBiometric(), isFalse, reason: 'step $k');
        expect(seen, isEmpty, reason: 'step $k');
        expect(again.fingerUnlock, isFalse, reason: 'step $k');
      }
      expect(k, lessThan(30));
    }
  });

  test(
    'a stop while the finger goes off leaves it off, never asleep',
    () async {
      _finger();
      for (var k = 0; k < 8; k++) {
        final bio = SealBio();
        final before = await makeLock(_withDecoy, bio: bio, inDecoy: true);
        expect(await before.state.setBiometric(true), isTrue);
        final store = _KillStore(k, before.store.m);
        final s = LockState(
          store: store,
          engine: MemEngine(),
          clock: StillClock(),
          bio: bio,
          revealAfter: Duration.zero,
        );
        await s.load();
        try {
          await s.clearDecoyPins();
        } on _Killed {
          // stopped here
        }
        final again = LockState(
          store: MemStore()..m.addAll(store.m),
          engine: MemEngine(),
          clock: StillClock(),
          bio: bio,
          revealAfter: Duration.zero,
        );
        await again.load();
        // on as it was, or off: a pin never seals it again for anything
        final n = bio.sealedFor.length;
        await again.verifyPin(appPin);
        await Future<void>.delayed(Duration.zero);
        expect(bio.sealedFor.length, n, reason: 'step $k');
      }
    },
  );

  test('a decoy that does not open leaves the counters as they were', () async {
    _finger();
    final lock = await makeLock(_withDecoy, bio: SealBio(), inDecoy: true);
    final s = lock.state;
    await s.setBiometric(true);
    s.inDecoy = false;
    s.lock();
    _sessions(s);
    for (var i = 0; i < 2; i++) {
      await s.verifyPin('0000');
    }
    final before = lock.store.m['halo.lock.state'];
    // the session stays where it was
    s.onOutcome = (r, {vaultKey}) async {};
    expect(await s.tryBiometric(), isFalse);
    expect(lock.store.m['halo.lock.state'], before);
    expect(s.quiet, isFalse);
    // or throws on the way
    s.onOutcome = (r, {vaultKey}) async => throw StateError('no decoy');
    expect(await s.tryBiometric(), isFalse);
    expect(s.locked, isTrue);
    expect(lock.store.m['halo.lock.state'], before);
    expect((jsonDecode(before!) as Map)['r'], 2);
  });

  test(
    'a decoy pin changed from the everyday app keeps the decoy\'s finger',
    () async {
      _finger();
      final bio = SealBio();
      final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
      final s = lock.state;
      await s.setBiometric(true);
      final seal = lock.store.m[_sealKey];
      s.inDecoy = false;
      expect(await s.setupDecoyPin('9753'), isTrue);
      expect(s.fingerUnlock, isTrue);
      expect(lock.store.m[_sealKey], seal);
      expect(lock.store.m[_bioKey], 'true');
      final seen = _sessions(s);
      s.lock();
      expect(await s.tryBiometric(), isTrue);
      expect(seen, [PinResult.decoy]);
    },
  );

  test('a new decoy that is not made gives the owner\'s finger back', () async {
    _finger();
    final bio = SealBio();
    // 5555 taken by the wipe pin: the decoy pin clashes
    final lock = await makeLock({
      ...appOnly,
      PinSlot.wipe: ('5555', PinKind.wipe),
    }, bio: bio);
    final s = lock.state;
    await s.setBiometric(true);
    expect(await s.setupDecoyPin('5555'), isFalse);
    expect(s.biometric, isTrue);
    expect(s.decoySet, isFalse);
    expect(bio.sealedFor, [_everyday, _everyday]);
    final seen = _sessions(s);
    s.lock();
    expect(await s.tryBiometric(), isTrue);
    expect(seen, [PinResult.normal]);
  });

  test('a seal without the switch goes at start', () async {
    final lock = await makeLock(
      appOnly,
      bio: SealBio(),
      stored: {_bioKey: 'false', _sealKey: 'ab' * 257},
    );
    expect(lock.store.m.containsKey(_sealKey), isFalse);
    expect(lock.state.fingerUnlock, isFalse);
  });

  test(
    'no seal means asleep from the start, even with a key that opens',
    () async {
      _finger();
      final bio = SealBio();
      await bio.seal(_everyday);
      final lock = await makeLock(appOnly, bio: bio, stored: {_bioKey: 'true'});
      expect(await bio.state(), 'ok');
      expect(lock.state.bioStale, isTrue);
    },
  );

  test(
    'a decoy finger in the first seconds waits for the decoy to be there',
    () async {
      _finger();
      final lock = await makeLock(_withDecoy, bio: SealBio(), inDecoy: true);
      final s = lock.state;
      await s.setBiometric(true);
      s.inDecoy = false;
      final seen = _sessions(s);
      // a cold start: the decoy's session is not ready yet
      decoyReady = false;
      final ready = Completer<void>();
      s.sessionsReady = ready.future;
      s.lock();
      final opened = s.tryBiometric();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seen, isEmpty);
      decoyReady = true;
      ready.complete();
      expect(await opened, isTrue);
      expect(seen, [PinResult.decoy]);
    },
  );

  test(
    'the hidden chats pin wakes the decoy\'s finger for the decoy',
    () async {
      _finger();
      final bio = SealBio();
      final lock = await makeLock(
        {..._withDecoy, PinSlot.vault: (vaultPin, PinKind.vault)},
        bio: bio,
        inDecoy: true,
      );
      final s = lock.state;
      await s.setBiometric(true);
      s.inDecoy = false;
      final seen = _sessions(s);
      bio.addFinger();
      s.lock();
      expect(await s.tryBiometric(), isFalse);
      expect(await s.verifyPin(vaultPin), PinResult.vault);
      await Future<void>.delayed(Duration.zero);
      expect(bio.sealedFor.last, _decoy);
      expect(s.bioStale, isFalse);
      s.lock();
      seen.clear();
      expect(await s.tryBiometric(), isTrue);
      expect(seen, [PinResult.decoy]);
    },
  );

  testWidgets('the fingerprint offer says it is turning on while the key is '
      'made', (t) async {
    phone(t);
    _finger();
    SharedPreferences.setMockInitialValues({});
    final bio = _QueuedBio();
    // the first seal waits too
    bio._asked = 1;
    final lock = await makeLock(null, bio: bio);
    expect(lock.state.fingerOffered, isTrue);
    await t.pumpWidget(app(const SizedBox(), still: true));
    unawaited(
      t
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => LockSetupScreen(lock: lock.state),
            ),
          ),
    );
    await t.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await typePin(t, '8642');
      await enter(t);
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
    }
    await t.tap(find.text(l10n.lockSetupUseFingerprint));
    await t.pump();
    expect(find.text(l10n.lockSetupTurningOn), findsOneWidget);
    expect(find.text(l10n.lockSetupUnlockWithFingerprint), findsOneWidget);
    // a second tap does nothing
    await t.tap(find.text(l10n.lockSetupTurningOn));
    await t.pump();
    bio.letGo(2);
    await t.pumpAndSettle();
    expect(find.text(l10n.lockSetupUnlockWithFingerprint), findsNothing);
    expect(find.byType(LockSetupScreen), findsNothing);
    expect(lock.state.biometric, isTrue);
    expect(bio.asked, [_everyday]);
    // the lock screen offers it at once
    lock.state.lock();
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app(LockScreen(lock: lock.state), still: true));
    await t.pumpAndSettle();
    expect(find.text(l10n.lockUseFingerprint), findsOneWidget);
  });
}
