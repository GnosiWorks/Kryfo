// SPDX-License-Identifier: GPL-3.0-or-later
// what the readme and the privacy page say about optional push
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _doc(String name) => File('../$name').readAsStringSync();

void main() {
  test('the readme says push is optional and what it learns', () {
    final r = _doc('README.md').toLowerCase();
    expect(r, isNot(contains('no push service')));
    expect(r, contains('optional push'));
    expect(r, contains('off by\n  default'));
    expect(r, contains('no sender, no count, no content'));
    expect(r, contains('privacy.md'));
  });

  test('the privacy page keeps the default and the helper mode apart', () {
    final p = _doc('PRIVACY.md');
    expect(p, contains('by default there is no push service'));
    expect(p, contains('## the helper app mode'));
    expect(p, contains('what the helper\'s server learns'));
  });
}
