// SPDX-License-Identifier: GPL-3.0-or-later
// a language as the app's own language names it. a pack and a guess say
// "chinese" whichever way it is written; traditional says so when the
// guess saw it.
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../widgets/language_sheet.dart' show languageNameHere;

String langName(String tag) => switch (tag.toLowerCase()) {
  'zh' => l10n.translateLangZh,
  'zh_hant' => l10n.languageNameZhHant,
  _ => languageNameHere(tag),
};

// a pack's size, as a person would say it: "75 MB", "0.4 MB"
String packSize(int bytes) {
  final mb = bytes / 1000000;
  return l10n.transportMb(mb >= 10 ? whole(mb.round()) : decimal(mb, 1));
}
