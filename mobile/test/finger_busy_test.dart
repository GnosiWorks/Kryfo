// SPDX-License-Identifier: GPL-3.0-or-later
// a phone whose keystore was busy: the finger stays on, nothing counts, the
// pin works and the lock screen says to try again. the same on either side
// of a decoy
import 'dart:convert';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/lock_screen.dart';

import 'pin_flow_fakes.dart';

const Map<int, (String, int)> _withDecoy = {
  ...appOnly,
  PinSlot.decoy: (decoyPin, PinKind.decoy),
};

const _bioKey = 'halo.lock.biometric';
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
    test('a busy keystore keeps the finger on, counts nothing, and the pin '
        'still opens, $side', () async {
      _finger();
      final bio = SealBio();
      final lock = await makeLock(
        decoy ? _withDecoy : appOnly,
        bio: bio,
        inDecoy: decoy,
      );
      final s = lock.state;
      final seen = _sessions(s);
      expect(await s.setBiometric(true), isTrue);
      s.lock();
      expect(await s.verifyPin('0000'), PinResult.invalid);
      final before = _counters(lock);
      final seal = lock.store.m[_sealKey];
      bio.calls.clear();

      bio.answer = 'error';
      expect(await s.tryBiometric(), isFalse);
      expect(s.locked, isTrue);
      expect(s.fingerNote, FingerNote.tryAgain);
      expect(s.bioStale, isFalse);
      expect(s.fingerUnlock, isTrue);
      expect(lock.store.m[_bioKey], 'true');
      expect(lock.store.m[_sealKey], seal);
      expect(bio.calls, ['unlock']);
      expect(_counters(lock), before);

      // the next try starts clean and opens
      bio.answer = 'ok';
      expect(await s.tryBiometric(), isTrue);
      expect(s.fingerNote, isNull);
      expect(seen.last, decoy ? PinResult.decoy : PinResult.normal);

      // and the pin opens while the keystore is busy
      s.lock();
      bio.answer = 'error';
      expect(await s.tryBiometric(), isFalse);
      final pin = decoy ? decoyPin : appPin;
      expect(
        await s.verifyPin(pin),
        decoy ? PinResult.decoy : PinResult.normal,
      );
      expect(s.locked, isFalse);
      expect(s.fingerUnlock, isTrue);
      // a new lock drops the line
      s.lock();
      expect(s.fingerNote, isNull);
    });
  }

  test('a keystore busy three times in a row gets a new key after the pin, '
      'calmly', () async {
    _finger();
    final bio = SealBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    _sessions(s);
    expect(await s.setBiometric(true), isTrue);
    s.lock();
    bio.answer = 'error';
    for (var i = 0; i < 2; i++) {
      expect(await s.tryBiometric(), isFalse);
      expect(s.bioStale, isFalse);
    }
    // a cancel in between neither counts nor clears the run
    bio.answer = 'cancel';
    expect(await s.tryBiometric(), isFalse);
    bio.answer = 'error';
    expect(await s.tryBiometric(), isFalse);
    expect(s.bioStale, isTrue);
    expect(s.fingerNote, isNull);
    expect(s.fingerUnlock, isTrue);
    // asleep: no prompt until the pin
    bio.calls.clear();
    expect(await s.tryBiometric(), isFalse);
    expect(bio.calls, isEmpty);
    bio.answer = 'ok';
    expect(await s.verifyPin(appPin), PinResult.normal);
    await pumpEventQueue();
    expect(bio.calls, contains('seal'));
    expect(s.bioStale, isFalse);
    s.lock();
    expect(await s.tryBiometric(), isTrue);
  });

  test('a run of busy answers starts again after any other one', () async {
    _finger();
    final bio = SealBio();
    final lock = await makeLock(appOnly, bio: bio);
    final s = lock.state;
    _sessions(s);
    expect(await s.setBiometric(true), isTrue);
    s.lock();
    for (final answer in ['error', 'error', 'lockout', 'error', 'error']) {
      bio.answer = answer;
      expect(await s.tryBiometric(), isFalse);
      expect(s.bioStale, isFalse, reason: answer);
    }
  });

  test('a keystore busy at the start leaves the finger awake', () async {
    _finger();
    final bio = SealBio();
    final first = await makeLock(appOnly, bio: bio);
    expect(await first.state.setBiometric(true), isTrue);
    // the app starts again while the keystore is busy
    bio.key = 'error';
    final again = await makeLock(appOnly, bio: bio, stored: first.store.m);
    expect(again.state.fingerUnlock, isTrue);
    expect(again.state.bioStale, isFalse);
    // with no seal there is nothing a finger could open
    final noSeal = Map.of(first.store.m)..remove(_sealKey);
    final bare = await makeLock(appOnly, bio: bio, stored: noSeal);
    expect(bare.state.bioStale, isTrue);
    // a key that is gone still wants the pin
    bio.key = 'none';
    final gone = await makeLock(appOnly, bio: bio, stored: first.store.m);
    expect(gone.state.bioStale, isTrue);
  });

  for (final still in [false, true]) {
    testWidgets(
      'the lock screen says try again, keeps the finger button, '
      'and the line goes with the next try${still ? ', reduced motion' : ''}',
      (t) async {
        phone(t);
        _finger();
        final bio = SealBio();
        final lock = await makeLock(appOnly, bio: bio);
        final s = lock.state;
        _sessions(s);
        expect(await s.setBiometric(true), isTrue);
        s.lock();
        bio.answer = 'error';
        await t.pumpWidget(app(LockScreen(lock: s), still: still));
        await t.pumpAndSettle();
        expect(await s.tryBiometric(), isFalse);
        await t.pumpAndSettle();
        expect(find.text(l10n.lockFingerTryAgain), findsOneWidget);
        expect(find.text(l10n.lockUseFingerprint), findsOneWidget);
        expect(find.text(l10n.lockFingerRefused), findsNothing);
        expect(find.text(l10n.lockFingerAfterPin), findsNothing);
        bio.answer = 'cancel';
        expect(await s.tryBiometric(), isFalse);
        await t.pumpAndSettle();
        expect(find.text(l10n.lockFingerTryAgain), findsNothing);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
