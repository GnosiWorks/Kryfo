// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:intl/intl.dart';

import 'dates.dart' show intlLocale;

// numbers as the chosen language writes them: its decimal mark (1.5, 1,5),
// its grouping (1,234, 1.234, 1 234), where the percent sign goes (42%,
// 42 %, %42) and, for persian and arabic, its digits. the units around them
// (kb, MB, km, s) are messages.

/// a whole number, grouped: "1,234"
String whole(num v) => NumberFormat.decimalPattern(intlLocale).format(v);

/// a number with exactly [digits] decimals: "1.5"
String decimal(num v, int digits) => NumberFormat.decimalPatternDigits(
  locale: intlLocale,
  decimalDigits: digits,
).format(v);

/// two digits, for the minutes and seconds after an hour or a minute:
/// "05"
String twoDigits(int v) => NumberFormat('00', intlLocale).format(v);

/// a share, 0 to 1, as a percentage: "42%"
String percent(num share) =>
    NumberFormat.percentPattern(intlLocale).format(share);

/// a dollar amount with no cents: "$20"
String dollars(int amount) => NumberFormat.currency(
  locale: intlLocale,
  symbol: r'$',
  decimalDigits: 0,
).format(amount);
