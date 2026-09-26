// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/dates.dart';
import 'package:kryfo/l10n/l10n.dart';

void main() {
  final d = DateTime(2026, 9, 23, 7, 5, 9);
  final lastYear = DateTime(2025, 3, 4, 18, 30);

  tearDown(() => setL10nLocale(const Locale('en')));

  test('english dates are day first and 24-hour', () {
    expect(dayMonth(d), '23 Sept');
    expect(dayMonthYear(lastYear), '4 Mar 2025');
    expect(dayMonthMaybeYear(d, now: d), '23 Sept');
    expect(dayMonthMaybeYear(lastYear, now: d), '4 Mar 2025');
    expect(dayMonthLong(d), '23 September');
    expect(weekday(d), 'Wednesday');
    expect(weekdayShort(d), 'Wed');
    expect(hourMinute(d), '07:05');
    expect(longDateTime(d), 'Wednesday, 23 September 2026 07:05');
    expect(mediumDateTime(d), '23 Sept 2026 07:05:09');
  });

  test('each language gets its own date data', () {
    expect(intlLocaleFor('en'), 'en_GB');
    expect(intlLocaleFor('pt'), 'pt');
    expect(intlLocaleFor('zh', scriptCode: 'Hans'), 'zh');
    expect(intlLocaleFor('zh', scriptCode: 'Hant'), 'zh_TW');
    setDateLocale(intlLocaleFor('de'));
    expect(dayMonthLong(d), '23. September');
    expect(hourMinute(d), '07:05');
    setDateLocale(intlLocaleFor('zh', scriptCode: 'Hant'));
    expect(dayMonth(d), '9月23日');
    expect(dateCaps(dayMonth(d)), '9月23日');
    setDateLocale(intlLocaleFor('tr'));
    expect(dateCaps(dayMonth(DateTime(2026, 4, 1))), '1 NİS');
    setDateLocale(intlLocaleFor('en'));
    expect(dateCaps(dayMonth(d)), '23 SEPT');
  });
}
