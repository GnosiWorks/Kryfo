// SPDX-License-Identifier: GPL-3.0-or-later
// the app lock around a picker, the camera or a share sheet (lockState.hold):
// coming straight back from one keeps the app open, leaving from inside one
// locks, and what it gives back after that waits for the pin.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_state.dart';

import 'source_body.dart';

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
    lockState.picksDropped = null;
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

  test('a leave just after the picker came back still locks', () async {
    final p = _Picker();
    await _settle();
    lockState.leaving();
    // android hands the picker's cancel over first, then says the person
    // left, then resumes the app
    p.give(null);
    expect(await p.result, isNull);
    lockState.left();
    lockState.returned();
    expect(lockState.locked, isTrue);
    expect(lockState.holding, isFalse);
  });

  test('a pick from the decoy unlocked into the decoy goes through', () async {
    lockState.inDecoy = true;
    final p = _Picker();
    await _settle();
    lockState.left();
    p.give('photo');
    await _settle();
    // the decoy pin again: the same session, so what was picked is its own
    _unlock(decoy: true);
    expect(await p.result, 'photo');
  });

  test('a dropped pick takes the picker copies with it', () async {
    var swept = 0;
    lockState.picksDropped = () async => swept++;
    final p = _Picker();
    await _settle();
    lockState.left();
    p.give('photo');
    await _settle();
    lockState.inDecoy = true;
    _unlock(decoy: true);
    await expectLater(p.result, throwsA(isA<LockDropped>()));
    expect(swept, 1);
  });

  test('a pick handed over keeps its copies for the screen', () async {
    var swept = 0;
    lockState.picksDropped = () async => swept++;
    final p = _Picker();
    await _settle();
    lockState.left();
    p.give('photo');
    await _settle();
    _unlock();
    expect(await p.result, 'photo');
    expect(swept, 0);
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

  test('a pick dropped by the lock is a quiet cancel on screen', () {
    final chat = sourceOf('lib/screens/chat_screen.dart');
    final group = sourceOf('lib/screens/group_chat_screen.dart');
    final qr = sourceOf('lib/screens/qr_screen.dart');
    for (final (src, fn) in [
      (chat, 'Future<void> _pickAndSendFile('),
      (chat, 'Future<void> _pickAndSendGif('),
      (group, 'Future<void> _pickGroupGif('),
      (group, 'Future<void> _pickGroupFile('),
      (qr, 'Future<void> _out('),
    ]) {
      final body = bodyOf(src, fn);
      final quiet = body.indexOf('} on LockDropped {');
      expect(quiet, greaterThan(0), reason: fn);
      // ahead of the catch that says it could not be read or drawn
      expect(quiet, lessThan(body.indexOf('} catch (')), reason: fn);
      final arm = body.substring(quiet, body.indexOf('} catch (', quiet));
      expect(arm, isNot(contains('showHaloToast')), reason: fn);
      expect(arm, isNot(contains('l10n.')), reason: fn);
    }
  });
}
