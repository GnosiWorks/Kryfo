// SPDX-License-Identifier: GPL-3.0-or-later
// the one line that says who vouched. local nicknames only, two names at
// most, then a count. pure so it can be pinned by a test.

// "alice", "alice and bob", "alice, bob and 2 others you know"
String vouchNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names[0];
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  final rest = names.length - 2;
  return '${names[0]}, ${names[1]} and $rest other${rest == 1 ? '' : 's'} you know';
}

String vouchedByLine(List<String> names) =>
    names.isEmpty ? '' : 'vouched by ${vouchNames(names)}';

String introducedByLine(List<String> names) =>
    names.isEmpty ? '' : 'introduced by ${vouchNames(names)}';

// "this shares alice's address with bob"
String shareWarning(String a, String b) => "this shares $a's address with $b";
