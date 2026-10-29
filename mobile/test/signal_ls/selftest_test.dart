// SPDX-License-Identifier: GPL-3.0-or-later
// the phone self-test (tool/shim_selftest.dart) passes on the host library,
// so a failure on a phone is the phone's, not the test's
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart'
    show kLsAbi, kLsLibsignal, kLsSpqr;

import '../../tool/shim_selftest.dart';
import 'shim_lib.dart';

void main() {
  test('the self-test round passes', () {
    final line = runShimSelfTest(shim!);
    expect(line, startsWith('shim self-test ok: abi $kLsAbi,'));
    expect(line, endsWith('built from $kLsLibsignal and $kLsSpqr'));
  }, skip: needsShim);
}
