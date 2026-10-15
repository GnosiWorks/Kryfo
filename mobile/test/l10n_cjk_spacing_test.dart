// SPDX-License-Identifier: GPL-3.0-or-later
// chinese punctuation is full width and carries its own space: an ascii
// space after it shows as a gap
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['zh', 'zh_Hant']) {
    test('$locale has no space after full-width punctuation', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final gap = RegExp('[。，、：；！？] ');
      final bad = [
        for (final kv in arb.entries)
          if (!kv.key.startsWith('@') &&
              kv.value is String &&
              gap.hasMatch(kv.value as String))
            kv.key,
      ];
      expect(bad, isEmpty);
    });
  }
}
