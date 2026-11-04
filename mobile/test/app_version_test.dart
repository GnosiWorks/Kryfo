// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_version.dart';

void main() {
  test('the version settings shows is the one in pubspec.yaml', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version: '));
    expect(line.substring(9).split('+').first.trim(), kAppVersion);
  });
}
