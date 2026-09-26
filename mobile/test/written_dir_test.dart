// SPDX-License-Identifier: GPL-3.0-or-later
// a person's words keep their own direction whatever the app's language
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';

void main() {
  test('the first letter decides', () {
    expect(writtenDir('Where do we eat tonight?'), TextDirection.ltr);
    expect(writtenDir('کجا شام بخوریم؟'), TextDirection.rtl);
    expect(writtenDir('أين نأكل الليلة؟'), TextDirection.rtl);
    expect(writtenDir('שלום'), TextDirection.rtl);
    expect(writtenDir('Привет'), TextDirection.ltr);
    expect(writtenDir('今晚吃什么'), TextDirection.ltr);
    // digits, marks and emoji are not letters: look further
    expect(writtenDir('8pm? مطعم'), TextDirection.ltr);
    expect(writtenDir('۱۲ شام'), TextDirection.rtl);
    expect(writtenDir('  «مرحبا» hi'), TextDirection.rtl);
    expect(writtenDir('\u2066@wren\u2069 سلام'), TextDirection.ltr);
  });

  test('no letters means no direction', () {
    expect(writtenDir(''), isNull);
    expect(writtenDir('12:30'), isNull);
    expect(writtenDir('?!…'), isNull);
    expect(writtenDir('👍🏽'), isNull);
  });
}
