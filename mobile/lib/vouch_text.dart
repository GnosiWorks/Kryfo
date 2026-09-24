import 'l10n/l10n.dart';
// SPDX-License-Identifier: GPL-3.0-or-later
// the one line that says who vouched. local nicknames only, two names at
// most, then a count. pure so it can be pinned by a test.

// "alice", "alice and bob", "alice, bob and 2 others you know"
String vouchNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names[0];
  if (names.length == 2) return l10n.vouchTextAnd(names[0], names[1]);
  final rest = names.length - 2;
  return l10n.vouchTextAndOtherYouKnow(names[0], names[1], rest);
}

String vouchedByLine(List<String> names) =>
    names.isEmpty ? '' : l10n.vouchTextVouchedBy(vouchNames(names));

String introducedByLine(List<String> names) =>
    names.isEmpty ? '' : l10n.vouchTextIntroducedBy(vouchNames(names));

// "this shares alice's address with bob"
String shareWarning(String a, String b) =>
    l10n.vouchTextThisSharesSAddress(a, b);
