// SPDX-License-Identifier: GPL-3.0-or-later
// the add field and the handle fields show a placeholder, never a name
// that reads like a real person's: "@name" in every language, in latin
// letters, since a handle is written in them
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/app_localizations.dart';

void main() {
  test('every language shows @name as the example', () {
    final seen = <String>{};
    for (final loc in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(loc);
      seen.add(loc.toLanguageTag());
      expect(l.appAKryfoLinkA, endsWith('@name'), reason: '$loc');
      expect(l.appAKryfoLinkA.toLowerCase(), isNot(contains('wren')));
      expect(l.handleHintName, 'name', reason: '$loc');
    }
    expect(seen, hasLength(17));
  });

  test('right to left keeps the @ before the word', () {
    for (final code in ['ar', 'fa']) {
      final l = lookupAppLocalizations(Locale(code));
      expect(l.appAKryfoLinkA, endsWith('‎@name'), reason: code);
    }
  });
}
