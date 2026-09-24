// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// every date and time kryfo shows, in the chosen language's own order and
// words: "23 Sep", "23. Sept.", "23 сент.", "9月23日". skeletons, not
// patterns, so the order is the language's and not ours. "today", "yesterday"
// and the relative times ("5m", "just now") stay messages in the arb.
//
// english uses british date data: day before month, as the rest of kryfo's
// english is british (colour, metre).

String _chosen = 'en_GB';
bool _ready = false;

// the data for every locale ships with intl; this only indexes it, once,
// and synchronously despite the future it returns
String get _locale {
  if (!_ready) {
    initializeDateFormatting();
    _ready = true;
  }
  return _chosen;
}

/// the intl locale dates are formatted in. set with the app's language.
String get dateLocale => _locale;

void setDateLocale(String intlLocale) => _chosen = intlLocale;

/// intl's name for a language's date and number data. english is british,
/// portuguese is brazil's (intl's plain "pt"), chinese by script.
String intlLocaleFor(String languageCode, {String? scriptCode}) {
  if (languageCode == 'en') return 'en_GB';
  if (languageCode == 'zh') return scriptCode == 'Hant' ? 'zh_TW' : 'zh';
  return languageCode;
}

/// "23 Sep"
String dayMonth(DateTime d) => DateFormat.MMMd(_locale).format(d);

/// "23 Sep 2025"
String dayMonthYear(DateTime d) => DateFormat.yMMMd(_locale).format(d);

/// "23 Sep" this year, "23 Sep 2025" otherwise
String dayMonthMaybeYear(DateTime d, {DateTime? now}) =>
    d.year == (now ?? DateTime.now()).year ? dayMonth(d) : dayMonthYear(d);

/// "23 September"
String dayMonthLong(DateTime d) => DateFormat.MMMMd(_locale).format(d);

/// "Wednesday"
String weekday(DateTime d) => DateFormat.EEEE(_locale).format(d);

/// "Wed"
String weekdayShort(DateTime d) => DateFormat.E(_locale).format(d);

/// "15:19", 24-hour everywhere, as kryfo has always shown times
String hourMinute(DateTime d) => DateFormat.Hm(_locale).format(d);

/// "Wednesday 23 September 2026" (with the time: see [longDateTime])
String longDate(DateTime d) => DateFormat.yMMMMEEEEd(_locale).format(d);

/// "Wednesday 23 September 2026 15:19"
String longDateTime(DateTime d) =>
    DateFormat.yMMMMEEEEd(_locale).add_Hm().format(d);

/// "23 Sep 2026 15:19:07"
String mediumDateTime(DateTime d) =>
    DateFormat.yMMMd(_locale).add_Hms().format(d);
