// SPDX-License-Identifier: GPL-3.0-or-later
// no camera on desktop yet: the screens hear none, and say it for a computer
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_start.dart';

void main() {
  test('the desktop offers no camera rather than none answering', () async {
    expect(await NoCameras().availableCameras(), isEmpty);
  });

  test('the scan and camera screens name the computer on desktop', () {
    for (final f in [
      'lib/screens/scan_screen.dart',
      'lib/screens/camera_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, contains('onDesktop'), reason: f);
      expect(src, contains('l10n.desktopNoCamera'), reason: f);
    }
  });
}
