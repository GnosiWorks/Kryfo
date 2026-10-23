// SPDX-License-Identifier: GPL-3.0-or-later
// the phone self-test (tool/shim_selftest.dart) passes on the host library,
// so a failure on a phone is the phone's, not the test's
import 'package:flutter_test/flutter_test.dart';

import '../../tool/shim_selftest.dart';
import 'shim_lib.dart';

void main() {
  test('the self-test round passes', () {
    expect(runShimSelfTest(shim!), startsWith('shim self-test ok: abi 2'));
  }, skip: needsShim);
}
