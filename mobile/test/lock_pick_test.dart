// SPDX-License-Identifier: GPL-3.0-or-later
// the app lock around a picker, the camera or a share sheet (lockState.hold):
// coming straight back from one keeps the app open, leaving from inside one
// locks, and what it gives back after that waits for the pin.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_state.dart';

// a picker on screen until the test says what it gave back
class _Picker {
  _Picker() {
    result = lockState.hold(() => _done.future);
  }
  final _done = Completer<String?>();
  late final Future<String?> result;
  void give(String? v) => _done.complete(v);
}

// the pin typed: the lock lifts and what waited for it runs
void _unlock({bool decoy = false}) {
  lockState.openForTest(enabled: true);
  decoy ? lockGuard.dropHeld() : lockGuard.lifted();
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // no hold carried over from the test before
    lockState.openForTest(enabled: true);
    lockState.left();
    lockState.openForTest(enabled: true);
    lockState.inDecoy = false;
    lockState.inVault = false;
  });

  test('coming straight back from a picker keeps the app open', () async {
    final p = _Picker();
    await _settle();
    expect(lockState.holding, isTrue);
    // the picker covers the app
    lockState.leaving();
    expect(lockState.locked, isFalse);
    p.give('photo');
    lockState.returned();
    expect(await p.result, 'photo');
    expect(lockState.locked, isFalse);
  });

  test('leaving from inside a picker locks', () async {
    final p = _Picker();
    await _settle();
    lockState.leaving();
    lockState.left();
    expect(lockState.locked, isTrue);
    // back through the picker, cancelled: still locked
    p.give(null);
    lockState.returned();
    await _settle();
    expect(lockState.locked, isTrue);
    _unlock();
    expect(await p.result, isNull);
  });

  test('leaving ends the hold, so the next leave locks too', () async {
    final p = _Picker();
    await _settle();
    lockState.left();
    p.give(null);
    _unlock();
    await p.result;
    expect(lockState.holding, isFalse);
    lockState.leaving();
    expect(lockState.locked, isTrue);
  });

  test('with no picker open the lifecycle decides, not this', () {
    lockState.left();
    expect(lockState.locked, isFalse);
  });

  test('what a picker gives after a leave waits for the pin', () async {
    final p = _Picker();
    await _settle();
    lockState.left();
    p.give('photo');
    String? got;
    unawaited(p.result.then((v) => got = v));
    await _settle();
    await _settle();
    expect(got, isNull, reason: 'nothing comes back under the lock');
    _unlock();
    await _settle();
    expect(got, 'photo');
  });

  test('a decoy unlock after a leave drops what the picker gave', () async {
    final p = _Picker();
    await _settle();
    lockState.left();
    p.give('photo');
    await _settle();
    lockState.inDecoy = true;
    _unlock(decoy: true);
    await expectLater(p.result, throwsA(isA<LockDropped>()));
  });

  test('a vault shut by the leave gets nothing from the picker', () async {
    lockState.inVault = true;
    final p = _Picker();
    await _settle();
    lockState.left();
    // the lock going up shuts the vault
    lockState.inVault = false;
    p.give('photo');
    await _settle();
    // the everyday pin: the session the picker was opened from is gone
    _unlock();
    await expectLater(p.result, throwsA(isA<LockDropped>()));
  });

  test('a leave with the lock off changes nothing', () async {
    lockState.openForTest();
    final p = _Picker();
    await _settle();
    lockState.left();
    expect(lockState.locked, isFalse);
    p.give('photo');
    expect(await p.result, 'photo');
  });
}
