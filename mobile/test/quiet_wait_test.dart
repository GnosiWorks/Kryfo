// SPDX-License-Identifier: GPL-3.0-or-later
// what a quiet session answers in place of the network comes after a wait
// of two to eight seconds, the same for every stand-in: the handle page,
// pair codes and gif search
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/quiet_wait.dart';

void main() {
  test('the wait is two to eight seconds', () {
    for (var i = 0; i < 200; i++) {
      final d = quietWait();
      expect(d.inMilliseconds, inInclusiveRange(2000, 8000));
    }
  });

  test('the answer comes after the wait, not before', () async {
    quietWait = () => const Duration(milliseconds: 300);
    String? got;
    unreachedLater('error: unreached').then((v) => got = v);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(got, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(got, 'error: unreached');
  });

  test('every stand-in answers through it', () {
    final sites = {
      'lib/screens/handle_screen.dart': 3,
      'lib/screens/pair_code_screen.dart': 1,
      'lib/widgets/pair_code_panel.dart': 1,
      'lib/gifs/gif_source.dart': 2,
    };
    for (final MapEntry(key: f, value: n) in sites.entries) {
      final src = File(f).readAsStringSync();
      expect(RegExp(r'unreachedLater\(').allMatches(src).length, n, reason: f);
      // no quiet answer handed back at once
      expect(src, isNot(contains('sessionQuiet ? _unreached')), reason: f);
      expect(src, isNot(contains('sessionQuiet ? pairUnreached')), reason: f);
      expect(
        src,
        isNot(contains('if (quiet()) return const GifPage')),
        reason: f,
      );
    }
  });
}
