// SPDX-License-Identifier: GPL-3.0-or-later
// when a message is in a language the person does not read, and what it
// would be translated into. the person's languages are the app's own plus
// the ones they listed; a guess that is unsure or mixed is left alone.
import 'catalog.dart';
import 'detect.dart';
import 'hant.dart' show HantForm;

// below this share of its letters, a message is mixed enough that the
// person can likely read it as it is, or the guess is unsure
const kForeignShare = 0.6;

// fewer rough words than this (detect.dart roughWords) is a name, a
// greeting or a word or two: nothing is offered for it
const kOfferMinWords = 3.0;

bool wordyEnough(String text) => roughWords(text) >= kOfferMinWords;

// the language a tag is a form of: the models and the person's list do not
// tell simplified from traditional chinese
String baseLang(String tag) {
  final t = tag.toLowerCase().replaceAll('-', '_');
  final i = t.indexOf('_');
  return i < 0 ? t : t.substring(0, i);
}

// the person's languages, as bases
Set<String> readLangs(String appLang, Iterable<String> listed) => {
  baseLang(appLang),
  for (final l in listed) baseLang(l),
};

bool isForeign(LangGuess g, Set<String> mine) {
  if (g.lang.isEmpty || g.share < kForeignShare) return false;
  return !mine.contains(baseLang(g.lang));
}

// what a foreign message would be translated into: the chosen language, or
// the app's when none was chosen. when there is no model for that, english,
// if it is one the person reads
String? targetFor(
  String from,
  TranslateCatalog catalog, {
  required String appLang,
  required String chosen,
  required Set<String> mine,
}) {
  final src = baseLang(from);
  final want = baseLang(chosen.isEmpty ? appLang : chosen);
  if (want != src && catalog.route(src, want) != null) return want;
  if (src != 'en' && mine.contains('en') && catalog.route(src, 'en') != null) {
    return 'en';
  }
  return null;
}

// the traditional forms a tag asks for: hong kong's and macau's for
// those, taiwan's for the rest, none for simplified
HantForm hantForm(String tag) {
  final t = tag.toLowerCase().replaceAll('-', '_');
  if (!t.startsWith('zh_')) return HantForm.none;
  if (t.endsWith('_hk') || t.endsWith('_mo')) return HantForm.hk;
  if (t.contains('hant') || t.endsWith('_tw')) return HantForm.tw;
  return HantForm.none;
}

// a message there is something to offer for: its language and the one it
// would go into
class Offer {
  final String from;
  final String to;
  // the guess as it was, for the label: traditional chinese says so, though
  // the same model reads it
  final String seen;
  // into chinese for a reader of traditional characters, and whose forms
  final HantForm hant;
  const Offer(this.from, this.to, [String? seen, this.hant = HantForm.none])
    : seen = seen ?? from;

  @override
  bool operator ==(Object other) =>
      other is Offer &&
      other.from == from &&
      other.to == to &&
      other.hant == hant;
  @override
  int get hashCode => Object.hash(from, to, hant);
}

Offer? offerFor(
  LangGuess g,
  TranslateCatalog catalog, {
  required String appLang,
  required String chosen,
  required Set<String> mine,
}) {
  if (!isForeign(g, mine)) return null;
  final to = targetFor(
    g.lang,
    catalog,
    appLang: appLang,
    chosen: chosen,
    mine: mine,
  );
  if (to == null) return null;
  final want = chosen.isEmpty ? appLang : chosen;
  return Offer(
    baseLang(g.lang),
    to,
    g.lang,
    to == 'zh' ? hantForm(want) : HantForm.none,
  );
}
