// SPDX-License-Identifier: GPL-3.0-or-later
// a stale or foreign library is refused when it opens, by its abi, with a
// message that says what to rebuild, before any other symbol is looked up
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';

import 'shim_lib.dart';

Matcher _says(String what) =>
    isA<StateError>().having((e) => e.message, 'message', contains(what));

void main() {
  test('the abi the bindings want passes', () {
    expect(() => lsCheckAbi(kLsAbi), returnsNormally);
  });

  test('an older or missing abi says the library is older', () {
    expect(() => lsCheckAbi(kLsAbi - 1), throwsA(_says('older than the app')));
    expect(() => lsCheckAbi(null), throwsA(_says('abi none')));
  });

  test('a newer abi says the library is newer', () {
    expect(() => lsCheckAbi(kLsAbi + 1), throwsA(_says('newer than the app')));
  });

  test(
    'a library without the shim is refused by its abi, not a lookup',
    () {
      expect(
        () => KryfoSignal.open('libc.so.6'),
        throwsA(_says('older than the app')),
      );
    },
    skip: Platform.isLinux ? false : 'needs libc.so.6',
  );

  test('the built library opens and reports the abi', () {
    expect(shim, isNotNull);
  }, skip: needsShim);

  test(
    'the shared library is opened once',
    () {
      expect(identical(KryfoSignal.shared, KryfoSignal.shared), isTrue);
    },
    skip: (Platform.environment[KryfoSignal.envVar] ?? '').isEmpty
        ? 'set ${KryfoSignal.envVar} to the built library'
        : false,
  );
}
