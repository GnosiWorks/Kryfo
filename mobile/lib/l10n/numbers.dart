// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:intl/intl.dart';

import 'dates.dart' show intlLocale;

// numbers as the chosen language writes them: decimal mark, grouping, percent
// sign and, for persian and arabic, digits. units are messages.

/// a whole number, grouped: "1,234"
String whole(num v) => NumberFormat.decimalPattern(intlLocale).format(v);

/// a number with exactly [digits] decimals: "1.5"
String decimal(num v, int digits) => NumberFormat.decimalPatternDigits(
  locale: intlLocale,
  decimalDigits: digits,
).format(v);

/// two digits, for minutes and seconds: "05"
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
