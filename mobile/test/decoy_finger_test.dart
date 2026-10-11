// SPDX-License-Identifier: GPL-3.0-or-later
// the decoy's own fingerprint switch. inside the decoy App lock reads as a
// fresh install's, fingerprint row included. what a finger opens is sealed,
// in the same place and the same form whichever side it opens, and while a
// decoy pin is set a finger opens the decoy and never the everyday app. the
// everyday app is pin only then, and gets its switch back, off, once the
// decoy goes. keystore and prompt are stood in at the channel
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show kIdentitySecureKeys;
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/widgets/halo_switch.dart';

import 'pin_flow_fakes.dart';

const Map<int, (String, int)> _withDecoy = {
  ...appOnly,
  PinSlot.decoy: (decoyPin, PinKind.decoy),
};

const Map<int, (String, int)> _withDecoyAndWipe = {
  ..._withDecoy,
  PinSlot.wipe: (wipePin, PinKind.wipe),
};

const _bioKey = 'halo.lock.biometric';
const _sealKey = 'halo.lock.biometric.seal';

// a phone with a finger, as local_auth answers
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

// the sessions an unlock opens, as the app's sessionFor sets them
List<PinResult> _sessions(LockState s) {
  final seen = <PinResult>[];
  s.onOutcome = (r, {vaultKey}) async {
    seen.add(r);
    s.inDecoy = r == PinResult.decoy;
  };
  return seen;
}

Map<String, dynamic> _counters(Lock l) =>
    jsonDecode(l.store.m['halo.lock.state']!) as Map<String, dynamic>;

// what changed in storage between two moments
Map<String, String?> _changed(
  Map<String, String> was,
  Map<String, String> now,
) => {
  for (final k in {...was.keys, ...now.keys})
    if (was[k] != now[k]) k: now[k],
};

// every word and switch on screen, in order
List<String> _seen(WidgetTester t) => [
  for (final w in t.widgetList<Text>(find.byType(Text)))
    w.data ?? w.textSpan?.toPlainText() ?? '',
  for (final w in t.widgetList<HaloSwitch>(find.byType(HaloSwitch)))
    'switch ${w.value}',
];

// App lock, its advanced rows open, then its how sheet
Future<List<List<String>>> _appLockPages(
  WidgetTester t,
  Lock lock, {
  bool still = false,
}) async {
  await t.pumpWidget(
    app(
      PinsScreen(
        lock: lock.state,
        host: FakeHost(lock: lock.state),
      ),
      still: still,
    ),
  );
  await t.pumpAndSettle();
  final card = _seen(t);
  await t.tap(find.text(l10n.pinsAdvanced));
  await t.pumpAndSettle();
  final rows = _seen(t);
  await t.ensureVisible(find.text(l10n.pinsHowThisWorks));
  await t.pumpAndSettle();
  await t.tap(find.text(l10n.pinsHowThisWorks));
  await t.pumpAndSettle();
  final how = _seen(t);
  await t.pumpWidget(const SizedBox());
  return [card, rows, how];
}

// a prompt and keystore that take their time, and may say no
class _SlowBio extends SealBio {
  Completer<void> gate = Completer<void>();
  bool refuse = false;
  @override
  Future<String?> seal(String opens) async {
    await gate.future;
    if (refuse) return null;
    return super.seal(opens);
  }
}

void main() {
  setUp(() => decoyReady = true);

  testWidgets('inside the decoy App lock reads as a fresh install\'s, '
      'fingerprint row and how sheet included', (t) async {
    phone(t);
    _finger();
    final fresh = await makeLock(appOnly, bio: SealBio());
    final decoy = await makeLock(_withDecoy, bio: SealBio(), inDecoy: true);
    final a = await _appLockPages(t, fresh);
    final b = await _appLockPages(t, decoy);
    expect(a.first, contains(l10n.pinsUnlockWithFingerprint));
    expect(a.first, contains('switch false'));
    expect(a.last, contains(l10n.flowDecoyFinger));
    expect(b, a);

    // and with the switch on in each
    expect(await fresh.state.setBiometric(true), isTrue);
    expect(await decoy.state.setBiometric(true), isTrue);
    final c = await _appLockPages(t, fresh);
    final d = await _appLockPages(t, decoy);
    expect(c.first, contains('switch true'));
    expect(d, c);
  });

  testWidgets('a new pin set inside the decoy offers the fingerprint, as a '
      'fresh install\'s does, and taking it seals the decoy', (t) async {
    phone(t);
    _finger();
    final bio = SealBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    // its lock turned off, then a pin set again
    await s.disable();
    await t.pumpWidget(
      app(
        PinsScreen(
          lock: s,
          host: FakeHost(lock: s),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.pinsSetAPin));
    await t.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await typePin(t, '8642');
      await enter(t);
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
    }
    expect(find.text(l10n.lockSetupUnlockWithFingerprint), findsOneWidget);
    await t.tap(find.text(l10n.lockSetupUseFingerprint));
    await t.pumpAndSettle();
    expect(s.biometric, isTrue);
    expect(bio.calls.last, 'seal');
    s.inDecoy = false;
    final seen = _sessions(s);
    s.lock();
    expect(await s.tryBiometric(), isTrue);
    expect(seen, [PinResult.decoy]);
  });

  test(
    'the decoy\'s switch leaves storage as a fresh install\'s leaves it',
    () async {
      _finger();
      final fresh = await makeLock(appOnly, bio: SealBio());
      final decoy = await makeLock(_withDecoy, bio: SealBio(), inDecoy: true);
      final was = [Map.of(fresh.store.m), Map.of(decoy.store.m)];
      expect(await fresh.state.setBiometric(true), isTrue);
      expect(await decoy.state.setBiometric(true), isTrue);
      final a = _changed(was[0], fresh.store.m);
      final b = _changed(was[1], decoy.store.m);
      expect(a.keys.toSet(), {_bioKey, _sealKey});
      expect(b.keys.toSet(), a.keys.toSet());
      expect(b[_bioKey], 'true');
      expect(a[_bioKey], 'true');
      final hex = RegExp(r'^[0-9a-f]+$');
      expect(a[_sealKey], matches(hex));
      expect(b[_sealKey], matches(hex));
      expect(b[_sealKey]!.length, a[_sealKey]!.length);
      // and nothing anywhere names the side a finger opens
      for (final m in [fresh.store.m, decoy.store.m]) {
        for (final e in m.entries) {
          if (e.key.contains('bio')) {
            expect(e.value, isNot(contains(HaloContainer.decoy.id)));
            expect(e.value, isNot(contains(HaloContainer.everyday.id)));
          }
        }
      }
    },
  );

  test(
    'before any unlock a cold start shows the same fingerprint either way',
    () async {
      _finger();
      final fresh = await makeLock(appOnly, bio: SealBio());
      final decoy = await makeLock(_withDecoy, bio: SealBio(), inDecoy: true);
      await fresh.state.setBiometric(true);
      await decoy.state.setBiometric(true);
      for (final l in [fresh, decoy]) {
        final again = LockState(
          store: l.store,
          engine: MemEngine(),
          clock: StillClock(),
          bio: SealBio(),
          revealAfter: Duration.zero,
        );
        await again.load();
        expect(again.locked, isTrue);
        expect(again.fingerUnlock, isTrue);
      }
    },
  );

  test('a finger opens the decoy from either side, and never the everyday '
      'app', () async {
    _finger();
    final lock = await makeLock(_withDecoy, bio: SealBio(), inDecoy: true);
    final s = lock.state;
    final seen = _sessions(s);
    expect(await s.setBiometric(true), isTrue);

    // locked while in the decoy
    s.lock();
    expect(s.locked, isTrue);
    expect(await s.tryBiometric(), isTrue);
    expect(s.inDecoy, isTrue);
    expect(s.locked, isFalse);

    // over to the everyday app by its pin: pin only there
    s.lock();
    expect(await s.verifyPin(appPin), PinResult.normal);
    expect(s.inDecoy, isFalse);
    expect(s.biometric, isFalse);
    expect(s.fingerOffered, isFalse);
    expect(await s.setBiometric(true), isFalse);
    expect(await s.setBiometric(false), isFalse);
    // the lock screen still offers the finger, and it opens the decoy
    expect(s.fingerUnlock, isTrue);
    s.lock();
    expect(await s.tryBiometric(), isTrue);
    expect(seen, [PinResult.decoy, PinResult.normal, PinResult.decoy]);
    expect(s.inDecoy, isTrue);
    expect(s.quiet, isTrue);
  });

  test('a decoy that will not open keeps the lock up', () async {
    _finger();
    final bio = SealBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    await s.setBiometric(true);
    s.inDecoy = false;
    // the session stays where it was
    final tried = <PinResult>[];
    s.onOutcome = (r, {vaultKey}) async => tried.add(r);
    s.lock();
    expect(await s.tryBiometric(), isFalse);
    expect(tried, [PinResult.decoy]);
    expect(s.locked, isTrue);
    // no decoy session yet: nothing is asked of the app at all
    decoyReady = false;
    expect(await s.tryBiometric(), isFalse);
    expect(tried, [PinResult.decoy]);
    expect(s.locked, isTrue);
    // and the finger stays for when it is
    expect(s.fingerUnlock, isTrue);
    expect(lock.store.m[_sealKey], isNotNull);
  });

  test(
    'a seal for the everyday app opens nothing while a decoy pin is set',
    () async {
      _finger();
      final bio = SealBio();
      final seal = await bio.seal(HaloContainer.everyday.id);
      final lock = await makeLock(
        _withDecoy,
        bio: bio,
        stored: {_bioKey: 'true', _sealKey: seal!},
      );
      final s = lock.state;
      final seen = _sessions(s);
      expect(s.fingerUnlock, isTrue);
      expect(await s.tryBiometric(), isFalse);
      expect(seen, isEmpty);
      expect(s.locked, isTrue);
      expect(s.fingerUnlock, isFalse);
      expect(lock.store.m[_bioKey], 'false');
      expect(lock.store.m.containsKey(_sealKey), isFalse);
      expect(bio.key, 'none');
    },
  );

  test('removing the decoy takes its finger, and the everyday switch comes '
      'back off', () async {
    _finger();
    final bio = SealBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    await s.setBiometric(true);
    s.inDecoy = false;
    await s.clearDecoyPins();
    expect(lock.store.m[_bioKey], 'false');
    expect(lock.store.m.containsKey(_sealKey), isFalse);
    expect(bio.key, 'none');
    expect(s.fingerOffered, isTrue);
    expect(s.biometric, isFalse);
    expect(s.fingerUnlock, isFalse);
    // turned on again, it opens the everyday app
    expect(await s.setBiometric(true), isTrue);
    final seen = _sessions(s);
    s.lock();
    expect(await s.tryBiometric(), isTrue);
    expect(seen, [PinResult.normal]);
  });

  for (final pin in [decoyPin, appPin]) {
    test('a new finger puts the decoy\'s finger to sleep until the '
        '${pin == decoyPin ? 'decoy' : 'everyday'} pin is typed', () async {
      _finger();
      final bio = SealBio();
      final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
      final s = lock.state;
      final seen = _sessions(s);
      await s.setBiometric(true);
      bio.addFinger();
      s.lock();
      expect(await s.tryBiometric(), isFalse);
      expect(s.bioStale, isTrue);
      expect(s.locked, isTrue);
      expect(await s.tryBiometric(), isFalse);
      expect(await s.verifyPin(pin), isNot(PinResult.invalid));
      await Future<void>.delayed(Duration.zero);
      expect(s.bioStale, isFalse);
      expect(bio.calls.where((c) => c == 'seal'), hasLength(2));
      // sealed again to the decoy, whichever pin was typed
      s.lock();
      seen.clear();
      expect(await s.tryBiometric(), isTrue);
      expect(seen, [PinResult.decoy]);
    });
  }

  test('a fingerprint from before seals waits for the pin without a decoy, '
      'and goes with one', () async {
    _finger();
    final bio = SealBio();
    final plain = await makeLock(appOnly, bio: bio, stored: {_bioKey: 'true'});
    expect(plain.state.bioStale, isTrue);
    expect(await plain.state.tryBiometric(), isFalse);
    expect(await plain.state.verifyPin(appPin), PinResult.normal);
    await Future<void>.delayed(Duration.zero);
    expect(plain.state.bioStale, isFalse);
    plain.state.lock();
    final seen = _sessions(plain.state);
    expect(await plain.state.tryBiometric(), isTrue);
    expect(seen, [PinResult.normal]);

    final withDecoy = await makeLock(
      _withDecoy,
      bio: SealBio(),
      stored: {_bioKey: 'true'},
    );
    expect(withDecoy.state.fingerUnlock, isFalse);
    expect(withDecoy.store.m[_bioKey], 'false');
  });

  test('wrong fingers and a locked sensor count nothing, and the decoy\'s '
      'finger keeps the budget as its pin does', () async {
    _finger();
    final bio = SealBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    _sessions(s);
    await s.setBiometric(true);
    s.lock();
    for (var i = 0; i < 3; i++) {
      expect(await s.verifyPin('0000'), PinResult.invalid);
    }
    final before = _counters(lock);
    expect(before['r'], 3);
    expect(before['b'], 3);
    for (final answer in ['cancel', 'lockout', 'error']) {
      bio.answer = answer;
      expect(await s.tryBiometric(), isFalse);
      expect(s.locked, isTrue);
      expect(_counters(lock), before);
      expect(s.bioStale, isFalse);
    }
    bio.answer = 'ok';
    expect(await s.tryBiometric(), isTrue);
    final after = _counters(lock);
    expect(after['r'], 0);
    expect(after['b'], 3);
    expect(after['q'], isTrue);
  });

  test('the wipe pin wipes with a decoy finger on', () async {
    _finger();
    final lock = await makeLock(
      _withDecoyAndWipe,
      bio: SealBio(),
      inDecoy: true,
      wipeOn: true,
    );
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    s.lock();
    expect(await s.verifyPin(wipePin), PinResult.panic);
  });

  test('the decoy turning its lock off, or setting a decoy pin of its own, '
      'takes its finger as in any install', () async {
    _finger();
    final bio = SealBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    await s.setBiometric(true);
    await s.disable();
    expect(s.biometric, isFalse);
    expect(s.fingerUnlock, isFalse);
    expect(lock.store.m.containsKey(_sealKey), isFalse);
    expect(await s.setupPin('8642'), isTrue);
    expect(s.lockOn, isTrue);
    expect(s.biometric, isFalse);
    expect(s.fingerOffered, isTrue);

    await s.setBiometric(true);
    expect(await s.setupDecoyPin('9753'), isTrue);
    expect(s.decoyPinOn, isTrue);
    expect(s.biometric, isFalse);
    expect(s.fingerOffered, isFalse);
    expect(lock.store.m.containsKey(_sealKey), isFalse);
    expect(await s.setBiometric(true), isFalse);
    // its own decoy pin gone, the switch is back, off
    await s.clearInnerDecoyPin();
    expect(s.fingerOffered, isTrue);
    expect(s.biometric, isFalse);
  });

  test('a backup carries nothing of the lock, a finger\'s seal included', () {
    expect(kIdentitySecureKeys.where((k) => k.startsWith('halo.')), isEmpty);
    final src = File('lib/backup.dart').readAsStringSync();
    expect(src, isNot(contains('halo.lock')));
    expect(src, isNot(contains('biometric')));
  });

  testWidgets('the switch moves as it is tapped, still with reduced motion, '
      'and goes back if the phone says no', (t) async {
    phone(t);
    _finger();
    final bio = _SlowBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    await t.pumpWidget(
      app(
        PinsScreen(
          lock: lock.state,
          host: FakeHost(lock: lock.state),
        ),
        still: true,
      ),
    );
    await t.pumpAndSettle();
    bool on() => t.widget<HaloSwitch>(find.byType(HaloSwitch)).value;
    expect(on(), isFalse);
    await t.tap(find.text(l10n.pinsUnlockWithFingerprint));
    await t.pump();
    expect(on(), isTrue);
    // a second tap while it works changes nothing
    await t.tap(find.text(l10n.pinsUnlockWithFingerprint));
    await t.pump();
    expect(on(), isTrue);
    bio.gate.complete();
    await t.pumpAndSettle();
    expect(on(), isTrue);
    expect(lock.state.biometric, isTrue);
    expect(bio.calls.where((c) => c == 'seal'), hasLength(1));

    await t.tap(find.text(l10n.pinsUnlockWithFingerprint));
    await t.pumpAndSettle();
    expect(on(), isFalse);
    bio
      ..gate = Completer<void>()
      ..refuse = true;
    await t.tap(find.text(l10n.pinsUnlockWithFingerprint));
    await t.pump();
    expect(on(), isTrue);
    bio.gate.complete();
    await t.pumpAndSettle();
    expect(on(), isFalse);
    expect(lock.state.fingerUnlock, isFalse);
  });

  for (final still in [true, false]) {
    testWidgets(
      'the lock screen is the same whatever a finger opens, and a '
      'finger asleep wakes after the pin${still ? ' with reduced motion' : ''}',
      (t) async {
        phone(t);
        _finger();
        final fresh = await makeLock(appOnly, bio: SealBio());
        await fresh.state.setBiometric(true);
        fresh.state.lock();
        final bio = SealBio();
        final decoy = await makeLock(_withDecoy, bio: bio, inDecoy: true);
        final s = decoy.state;
        _sessions(s);
        await s.setBiometric(true);
        s.inDecoy = false;
        s.lock();
        // no prompt here: the screens alone
        fresh.state.onOutcome = (r, {vaultKey}) async {};
        bio.answer = 'cancel';

        Future<List<String>> shown(LockState l) async {
          await t.pumpWidget(app(LockScreen(lock: l), still: still));
          await t.pumpAndSettle();
          final out = _seen(t);
          await t.pumpWidget(const SizedBox());
          return out;
        }

        final a = await shown(fresh.state);
        expect(a, contains(l10n.lockUseFingerprint));
        expect(await shown(s), a);

        // a finger added: asleep until a pin
        bio
          ..answer = 'ok'
          ..addFinger();
        expect(await s.tryBiometric(), isFalse);
        expect(s.bioStale, isTrue);
        await t.pumpWidget(app(LockScreen(lock: s), still: still));
        await t.pumpAndSettle();
        expect(find.text(l10n.lockFingerAfterPin), findsOneWidget);
        expect(find.text(l10n.lockUseFingerprint), findsNothing);
        expect(await s.verifyPin(decoyPin), PinResult.decoy);
        s.lock();
        await t.pump();
        await t.pump();
        if (still) {
          // no fade: the button is there at once
          expect(find.text(l10n.lockFingerAfterPin), findsNothing);
        }
        await t.pumpAndSettle();
        expect(find.text(l10n.lockUseFingerprint), findsOneWidget);
        expect(find.text(l10n.lockFingerAfterPin), findsNothing);
      },
    );
  }

  testWidgets('the decoy setup says what a finger opens, in the everyday app '
      'and in the decoy alike', (t) async {
    phone(t);
    _finger();
    for (final inDecoy in [false, true]) {
      final lock = await makeLock(
        inDecoy ? _withDecoy : appOnly,
        bio: SealBio(),
        inDecoy: inDecoy,
      );
      await t.pumpWidget(
        app(
          PinFlowScreen(
            flow: PinFlow.decoy,
            lock: lock.state,
            host: FakeHost(lock: lock.state),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.flowDecoyFinger), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }
  });

  test('the line in every language', () {
    for (final e in _line.entries) {
      final parts = e.key.split('_');
      final l = lookupAppLocalizations(
        parts.length == 1
            ? Locale(parts[0])
            : Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]),
      );
      expect(l.flowDecoyFinger, e.value, reason: e.key);
    }
    expect(_line, hasLength(15));
  });

  group('through the platform channel', () {
    const ch = MethodChannel('halo/platform');
    final calls = <MethodCall>[];
    // the keystore: one key at a time, and the seals it opens
    var key = 'none';
    final opens = <String, String>{};
    var answer = 'ok';
    final rnd = Random(7);

    setUp(() {
      calls.clear();
      opens.clear();
      key = 'none';
      answer = 'ok';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async {
            calls.add(c);
            final a = c.arguments is Map ? c.arguments as Map : const {};
            switch (c.method) {
              case 'bioReady':
                return true;
              case 'bioState':
                return key;
              case 'bioSeal':
                opens.clear();
                key = 'ok';
                final s = List.generate(
                  257,
                  (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
                ).join();
                opens[s] = a['opens'] as String;
                return s;
              case 'bioDisable':
                opens.clear();
                key = 'none';
                return true;
              case 'bioUnlock':
                if (key != 'ok') return {'r': key, 'p': null};
                if (answer != 'ok') return {'r': answer, 'p': null};
                final o = opens[a['seal']];
                return o == null
                    ? {'r': 'none', 'p': null}
                    : {'r': 'ok', 'p': o};
            }
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null),
    );

    List<MethodCall> of(String m) => [
      for (final c in calls)
        if (c.method == m) c,
    ];

    test(
      'the decoy seals itself, and a finger opens it from either side',
      () async {
        _finger();
        final lock = await makeLock(
          _withDecoy,
          bio: PlatformLockBio(),
          inDecoy: true,
        );
        final s = lock.state;
        final seen = _sessions(s);
        expect(s.bioSupported, isTrue);
        expect(await s.setBiometric(true), isTrue);
        expect(of('bioSeal').single.arguments, {
          'opens': HaloContainer.decoy.id,
        });
        final seal = lock.store.m[_sealKey]!;
        expect(seal, hasLength(514));

        expect(await s.verifyPin(appPin), PinResult.normal);
        s.lock();
        expect(await s.tryBiometric(), isTrue);
        final ask = of('bioUnlock').single.arguments as Map;
        expect(ask['seal'], seal);
        expect(ask['title'], l10n.lockStateUnlockKryfo);
        expect(seen, [PinResult.normal, PinResult.decoy]);

        // a locked sensor: nothing counted, nothing opened
        answer = 'lockout';
        s.lock();
        final before = lock.store.m['halo.lock.state'];
        expect(await s.tryBiometric(), isFalse);
        expect(lock.store.m['halo.lock.state'], before);

        // a finger added: the pin, then sealed to the decoy again
        answer = 'ok';
        key = 'invalidated';
        opens.clear();
        expect(await s.tryBiometric(), isFalse);
        expect(s.bioStale, isTrue);
        expect(await s.verifyPin(appPin), PinResult.normal);
        await Future<void>.delayed(Duration.zero);
        expect(of('bioSeal').last.arguments, {'opens': HaloContainer.decoy.id});
        expect(s.bioStale, isFalse);
        s.lock();
        expect(await s.tryBiometric(), isTrue);
        expect(seen.last, PinResult.decoy);

        // the decoy goes, and its key with it
        s.inDecoy = false;
        await s.clearDecoyPins();
        expect(of('bioDisable'), isNotEmpty);
        expect(key, 'none');
        expect(lock.store.m.containsKey(_sealKey), isFalse);
      },
    );

    test('an answer android never gives opens nothing', () async {
      _finger();
      final lock = await makeLock(appOnly, bio: PlatformLockBio());
      final s = lock.state;
      expect(await s.setBiometric(true), isTrue);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            ch,
            (c) async => c.method == 'bioUnlock' ? 'ok' : null,
          );
      final seen = _sessions(s);
      s.lock();
      expect(await s.tryBiometric(), isFalse);
      expect(seen, isEmpty);
      expect(s.locked, isTrue);
    });
  });
}

// pinned: what the decoy setup and the how sheet say in each language
const _line = {
  'en':
      "While a decoy PIN is set, this app opens with your PIN only. If fingerprint is on in the decoy, a finger opens the decoy, never this app.",
  'de':
      "Solange eine Tarn-PIN gesetzt ist, öffnet sich diese App nur mit deiner PIN. Ist in der Tarnung der Fingerabdruck an, öffnet ein Finger die Tarnung, nie diese App.",
  'fr':
      "Tant qu’un code leurre est défini, cette app s’ouvre seulement avec votre code PIN. Si l’empreinte est activée dans le leurre, un doigt ouvre le leurre, jamais cette app.",
  'es':
      "Mientras haya un PIN señuelo, esta app se abre solo con tu PIN. Si la huella está activada en el señuelo, un dedo abre el señuelo, nunca esta app.",
  'pt':
      "Enquanto houver um PIN de disfarce, este app abre só com o seu PIN. Se a digital estiver ativada no disfarce, um dedo abre o disfarce, nunca este app.",
  'it':
      "Finché è impostato un PIN esca, questa app si apre solo con il tuo PIN. Se nell'esca l'impronta è attiva, un dito apre l'esca, mai questa app.",
  'ru':
      "Пока задана PIN-приманка, это приложение открывается только по PIN-коду. Если в приманке включён отпечаток, палец откроет приманку, но никогда не это приложение.",
  'uk':
      "Поки встановлено PIN-приманку, цей застосунок відкривається лише за PIN-кодом. Якщо в приманці ввімкнено відбиток, палець відкриє приманку, але ніколи не цей застосунок.",
  'tr':
      "Yem PIN’i ayarlıyken bu uygulama yalnızca PIN’inle açılır. Yemde parmak izi açıksa parmak yemi açar, bu uygulamayı asla açmaz.",
  'ar':
      "ما دام رمز PIN للتمويه مضبوطًا، يُفتح هذا التطبيق برمز PIN فقط. وإذا كانت البصمة مفعّلة في التمويه، فالإصبع يفتح التمويه، ولا يفتح هذا التطبيق أبدًا.",
  'fa':
      "تا وقتی PIN فریب تنظیم شده، این برنامه فقط با PIN شما باز می‌شود. اگر اثر انگشت در فریب روشن باشد، انگشت فریب را باز می‌کند، هرگز این برنامه را.",
  'zh': "设置伪装 PIN 后，这个应用只能用 PIN 码打开。如果在伪装里开启了指纹，手指只会打开伪装，绝不会打开这个应用。",
  'zh_Hant': "設定偽裝 PIN 後，這個應用程式只能用 PIN 碼開啟。如果在偽裝裡開啟了指紋，手指只會開啟偽裝，絕不會開啟這個應用程式。",
  'vi':
      "Khi đã đặt mã PIN ngụy trang, ứng dụng này chỉ mở bằng mã PIN của bạn. Nếu phần ngụy trang bật vân tay, ngón tay sẽ mở phần ngụy trang, không bao giờ mở ứng dụng này.",
  'id':
      "Selama PIN umpan dipasang, aplikasi ini hanya terbuka dengan PIN-mu. Jika sidik jari aktif di umpan, jari membuka umpan, tidak pernah aplikasi ini.",
};
