// SPDX-License-Identifier: GPL-3.0-or-later
// a seal made for a key the phone no longer has: no prompt, no count, the
// finger sleeps until the pin makes a new one, the same on either side of a
// decoy. a seal from before seals named their key is made again in the new
// form once a finger opened it
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';

import 'pin_flow_fakes.dart';

const Map<int, (String, int)> _withDecoy = {
  ...appOnly,
  PinSlot.decoy: (decoyPin, PinKind.decoy),
};

const _sealKey = 'halo.lock.biometric.seal';

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

// the keystore as BioKey.kt answers: each seal names its key, one for
// another key is "none" before any prompt. an old seal names none, opens
// with its key, and comes back made again in the new form
class _KeyedBio implements LockBio {
  int key = 0;
  bool hasKey = false;
  int prompts = 0;
  // the seals each key opens, and to what
  final _opens = <String, (int, String)>{};
  int _n = 0;
  // holds the prompt open while a test changes things under it
  Completer<void>? gate;

  String _make(String form, int k, String opens) {
    final s = form + (++_n).toRadixString(16).padLeft(528, '0');
    _opens[s] = (k, opens);
    return s;
  }

  // a seal from before tags, for the key there now
  String oldSeal(String opens) => _make('01', key, opens);

  // the phone made a new key behind the app's back: its seal is stale
  void rekey() => key++;

  @override
  Future<bool> ready() async => true;
  @override
  Future<String> state() async => hasKey ? 'ok' : 'none';

  @override
  Future<String?> seal(String opens) async {
    key++;
    hasKey = true;
    return _make('02', key, opens);
  }

  @override
  Future<void> disable() async {
    key++;
    hasKey = false;
  }

  @override
  Future<BioOpened> unlock(String title, String cancel, String seal) async {
    final o = _opens[seal];
    // another key's seal is told from the public half: no prompt
    if (!hasKey || o == null || o.$1 != key) return const BioOpened('none');
    prompts++;
    await gate?.future;
    final again = seal.startsWith('01') ? _make('02', o.$1, o.$2) : null;
    return BioOpened('ok', o.$2, again);
  }
}

Map<String, dynamic> _counters(Lock l) =>
    jsonDecode(l.store.m['halo.lock.state'] ?? '{}') as Map<String, dynamic>;

List<PinResult> _sessions(LockState s) {
  final seen = <PinResult>[];
  s.onOutcome = (r, {vaultKey}) async {
    seen.add(r);
    s.inDecoy = r == PinResult.decoy;
  };
  return seen;
}

void main() {
  setUp(() => decoyReady = true);

  for (final decoy in [false, true]) {
    final side = decoy ? 'in a decoy' : 'in any install';
    test('a seal for another key puts the finger to sleep until the pin, '
        'with no prompt and no count, $side', () async {
      _finger();
      final bio = _KeyedBio();
      final lock = await makeLock(
        decoy ? _withDecoy : appOnly,
        bio: bio,
        inDecoy: decoy,
      );
      final s = lock.state;
      final seen = _sessions(s);
      expect(await s.setBiometric(true), isTrue);
      s.lock();
      for (var i = 0; i < 2; i++) {
        expect(await s.verifyPin('0000'), PinResult.invalid);
      }
      final before = _counters(lock);
      final stale = lock.store.m[_sealKey];
      bio.rekey();

      expect(await s.tryBiometric(), isFalse);
      expect(s.locked, isTrue);
      expect(s.bioStale, isTrue);
      expect(s.fingerNote, isNull);
      // still on: it wakes with the pin, not off with a refusal
      expect(s.fingerUnlock, isTrue);
      expect(lock.store.m['halo.lock.biometric'], 'true');
      expect(_counters(lock), before);
      expect(bio.prompts, 0);
      // asked again: nothing, no prompt, no loop
      expect(await s.tryBiometric(), isFalse);
      expect(bio.prompts, 0);
      expect(lock.store.m[_sealKey], stale);

      // the pin opens, and a new seal for the new key follows it
      final pin = decoy ? decoyPin : appPin;
      expect(
        await s.verifyPin(pin),
        decoy ? PinResult.decoy : PinResult.normal,
      );
      await pumpEventQueue();
      expect(s.bioStale, isFalse);
      expect(lock.store.m[_sealKey], isNot(stale));
      s.lock();
      expect(await s.tryBiometric(), isTrue);
      expect(bio.prompts, 1);
      expect(seen.last, decoy ? PinResult.decoy : PinResult.normal);
    });
  }

  test('with a decoy, a stale seal made again after the everyday pin '
      'still opens only the decoy', () async {
    _finger();
    final bio = _KeyedBio();
    final lock = await makeLock(_withDecoy, bio: bio, inDecoy: true);
    final s = lock.state;
    final seen = _sessions(s);
    expect(await s.setBiometric(true), isTrue);
    s.lock();
    bio.rekey();
    expect(await s.tryBiometric(), isFalse);
    expect(s.bioStale, isTrue);
    expect(await s.verifyPin(appPin), PinResult.normal);
    await pumpEventQueue();
    expect(s.bioStale, isFalse);
    s.lock();
    expect(await s.tryBiometric(), isTrue);
    expect(seen, [PinResult.normal, PinResult.decoy]);
  });

  testWidgets('the lock screen says the pin wakes the finger, and asks for '
      'no finger', (t) async {
    phone(t);
    _finger();
    final bio = _KeyedBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    expect(await s.setBiometric(true), isTrue);
    s.lock();
    bio.rekey();
    await t.pumpWidget(app(LockScreen(lock: s), still: true));
    await t.pumpAndSettle();
    expect(await s.tryBiometric(), isFalse);
    await t.pumpAndSettle();
    expect(find.text(l10n.lockFingerAfterPin), findsOneWidget);
    expect(find.text(l10n.lockFingerRefused), findsNothing);
    expect(find.text(l10n.lockUseFingerprint), findsNothing);
    expect(bio.prompts, 0);
    await t.pumpWidget(const SizedBox());
  });

  for (final decoy in [false, true]) {
    test('an old seal a finger opened is kept in the new form, '
        '${decoy ? 'in a decoy' : 'in any install'}', () async {
      _finger();
      final bio = _KeyedBio();
      final lock = await makeLock(
        decoy ? _withDecoy : appOnly,
        bio: bio,
        inDecoy: decoy,
      );
      final s = lock.state;
      final seen = _sessions(s);
      expect(await s.setBiometric(true), isTrue);
      final opens = decoy ? HaloContainer.decoy.id : everydayContainer;
      final old = bio.oldSeal(opens);
      lock.store.m[_sealKey] = old;
      s.lock();
      expect(await s.tryBiometric(), isTrue);
      await pumpEventQueue();
      final now = lock.store.m[_sealKey]!;
      expect(now, isNot(old));
      expect(now.substring(0, 2), '02');
      expect(now.length, old.length);
      // the new one opens the same side, and stays
      s.lock();
      expect(await s.tryBiometric(), isTrue);
      await pumpEventQueue();
      expect(lock.store.m[_sealKey], now);
      expect(
        seen,
        decoy
            ? [PinResult.decoy, PinResult.decoy]
            : [PinResult.normal, PinResult.normal],
      );
    });
  }

  test('an old seal is not kept over a finger set again meanwhile', () async {
    _finger();
    final bio = _KeyedBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    _sessions(s);
    expect(await s.setBiometric(true), isTrue);
    lock.store.m[_sealKey] = bio.oldSeal(everydayContainer);
    s.lock();
    bio.gate = Completer<void>();
    final tried = s.tryBiometric();
    await pumpEventQueue();
    expect(bio.prompts, 1);
    // set anew while the prompt is up
    expect(await s.setBiometric(true), isTrue);
    final set = lock.store.m[_sealKey];
    bio.gate!.complete();
    await tried;
    await pumpEventQueue();
    expect(lock.store.m[_sealKey], set);
  });

  test('an old seal is not kept after the finger was turned off', () async {
    _finger();
    final bio = _KeyedBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    _sessions(s);
    expect(await s.setBiometric(true), isTrue);
    lock.store.m[_sealKey] = bio.oldSeal(everydayContainer);
    s.lock();
    bio.gate = Completer<void>();
    final tried = s.tryBiometric();
    await pumpEventQueue();
    expect(await s.setBiometric(false), isTrue);
    bio.gate!.complete();
    await tried;
    await pumpEventQueue();
    expect(lock.store.m.containsKey(_sealKey), isFalse);
  });
}
