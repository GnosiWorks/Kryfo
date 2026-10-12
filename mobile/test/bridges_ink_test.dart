// SPDX-License-Identifier: GPL-3.0-or-later
// the connection pages write in text or text2, never the lighter text3
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the bridges and transport pages use no text3', () {
    for (final f in [
      'lib/screens/bridges_screen.dart',
      'lib/screens/bridge_sheets.dart',
      'lib/screens/transport_screen.dart',
      'lib/bridge_mode.dart',
      'lib/widgets/tor_boot_splash.dart',
    ]) {
      expect(File(f).readAsStringSync(), isNot(contains('text3')), reason: f);
    }
  });
}
