import '../l10n/l10n.dart';

// SPDX-License-Identifier: GPL-3.0-or-later
enum PassGrade { none, tooShort, weak, fair, strong }

const kMinPassLength = 8;

PassGrade gradePassword(String p) {
  if (p.isEmpty) return PassGrade.none;
  if (p.runes.length < kMinPassLength) return PassGrade.tooShort;
  final words = p
      .split(RegExp(r'[\s\-_.]+'))
      .where((w) => w.runes.length >= 3)
      .toList();
  if (words.length >= 4 && words.toSet().length >= 4) return PassGrade.strong;
  if (RegExp(r'^(.)\1*$').hasMatch(p)) return PassGrade.weak;
  var kinds = 0;
  if (RegExp(r'[a-z]').hasMatch(p)) kinds++;
  if (RegExp(r'[A-Z]').hasMatch(p)) kinds++;
  if (RegExp(r'\d').hasMatch(p)) kinds++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) kinds++;
  final n = p.runes.length;
  if (n >= 20 || (n >= 14 && kinds >= 3)) return PassGrade.strong;
  if (n >= 12 || (n >= 10 && kinds >= 3)) return PassGrade.fair;
  return PassGrade.weak;
}

String gradeLine(PassGrade g) => switch (g) {
  PassGrade.none => l10n.lockWordsFourRandomWordsBeat,
  PassGrade.tooShort => l10n.lockWordsTooShortAtLeast(kMinPassLength),
  PassGrade.weak => l10n.lockWordsWeakWhoeverGetsThe,
  PassGrade.fair => l10n.lockWordsFairLongerIsStronger,
  PassGrade.strong => l10n.lockWordsStrongFourRandomWords,
};

const _neutral = 'locked file';

// the name a locked file gets when its own name is hidden. a file name, so
// it stays the same in every language
const neutralLockedName = '$_neutral.age';

String lockedName(String? original, {required bool hide}) {
  final base = (original ?? '')
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .trim();
  if (hide || base.isEmpty) return '$_neutral.age';
  final cut = base.length > 100 ? base.substring(base.length - 100) : base;
  return '$cut.age';
}

String openedName(String? locked) {
  var n = (locked ?? '')
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .trim();
  if (n.toLowerCase().endsWith('.age')) n = n.substring(0, n.length - 4);
  n = n.replaceFirst(RegExp(r' \(\d+\)$'), '').trim();
  if (n.isEmpty || n == _neutral) return 'opened file';
  return n;
}
