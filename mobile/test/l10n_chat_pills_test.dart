// SPDX-License-Identifier: GPL-3.0-or-later
// a one-sentence pill in the thread reads like a day's: no full stop, in
// every language
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pills = [
  'chatNowPostQuantum',
  'chatHealRestored',
  'chatHealNewSession',
  'chatNeedsUpdateToChat',
  'chatShotsYouTurnedOff',
  'chatShotsTheyTurnedOff',
];

void main() {
  final arbs = Directory(
    'lib/l10n',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList();

  test('every language is here', () {
    expect(arbs.length, 17);
  });

  for (final f in arbs) {
    test('${f.uri.pathSegments.last} pills end without a full stop', () {
      final arb = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final stop = RegExp(r'[.。।۔]$');
      final bad = [
        for (final k in _pills)
          if (stop.hasMatch((arb[k] as String).trim())) k,
      ];
      expect(bad, isEmpty);
    });
  }
}
