// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/dates.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart';

void main() {
  tearDown(() => setL10nLocale(const Locale('en')));

  test('formats english numbers', () {
    expect(whole(5), '5');
    expect(whole(1234), '1,234');
    expect(decimal(1.25, 1), '1.3');
    expect(decimal(12, 0), '12');
    expect(twoDigits(5), '05');
    expect(percent(0.42), '42%');
    expect(dollars(20), r'$20');
    expect(l10n.home1Chat(1234), '1,234 chats');
  });

  test('each language formats its own numbers', () {
    setDateLocale(intlLocaleFor('de'));
    expect(decimal(1.5, 1), '1,5');
    expect(whole(1234), '1.234');
    expect(percent(0.42), '42\u00a0%');
    setDateLocale(intlLocaleFor('tr'));
    expect(percent(0.42), '%42');
    setDateLocale(intlLocaleFor('fr'));
    expect(whole(1234), '1 234');
    expect(dollars(20), '20 \$');
  });
}
