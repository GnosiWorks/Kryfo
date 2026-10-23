// SPDX-License-Identifier: GPL-3.0-or-later
// which languages can be downloaded and what each costs. the engine's
// pinned manifest (engine/translate/models.json) is the source; the copy
// here is what the app shows when the engine cannot be asked, and a test
// keeps the two the same.
import 'dart:convert';

class LangBundle {
  final String lang;
  // bytes on the wire, padding included, and once unpacked
  final int gz;
  final int disk;
  // its directions, "zh-en", and the folder each one unpacks into
  final List<String> pairs;
  final List<String> dirs;
  const LangBundle({
    required this.lang,
    required this.gz,
    required this.disk,
    required this.pairs,
    required this.dirs,
  });
}

class TranslateCatalog {
  // where the files come from: the pinned mirror, nothing else
  final String base;
  final List<LangBundle> langs;
  const TranslateCatalog({required this.base, required this.langs});

  // the engine's HaloTranslateCatalog answer, or null when it is not one
  static TranslateCatalog? parse(String s) {
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return TranslateCatalog(
        base: j['base'] as String,
        langs: [
          for (final l in (j['langs'] as List? ?? const []))
            LangBundle(
              lang: l['lang'] as String,
              gz: (l['gz'] as num).toInt(),
              disk: (l['disk'] as num).toInt(),
              pairs: [for (final p in l['pairs'] as List) p as String],
              dirs: [for (final d in l['dirs'] as List) d as String],
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  LangBundle? bundle(String lang) {
    for (final b in langs) {
      if (b.lang == lang) return b;
    }
    return null;
  }

  // the bundle that holds the direction from -> to
  LangBundle? bundleFor(String from, String to) {
    for (final b in langs) {
      if (b.pairs.contains('$from-$to')) return b;
    }
    return null;
  }

  // the steps from one language to another: one when there is a model for
  // it, two through english when there are both, null when there is no way
  List<(String, String)>? route(String from, String to) {
    if (from == to) return null;
    if (bundleFor(from, to) != null) return [(from, to)];
    if (from != 'en' &&
        to != 'en' &&
        bundleFor(from, 'en') != null &&
        bundleFor('en', to) != null) {
      return [(from, 'en'), ('en', to)];
    }
    return null;
  }

  // the bundles a route needs
  List<LangBundle> bundlesFor(List<(String, String)> route) {
    final out = <LangBundle>[];
    for (final (f, t) in route) {
      final b = bundleFor(f, t);
      if (b != null && !out.contains(b)) out.add(b);
    }
    return out;
  }
}

// the pinned manifest's numbers: chinese both ways, base-memory models,
// from our mirror, the download padded to its size class
const builtInCatalog = TranslateCatalog(
  base:
      'http://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion/models/',
  langs: [
    LangBundle(
      lang: 'zh',
      gz: 100663296,
      disk: 104470603,
      pairs: ['zh-en', 'en-zh'],
      dirs: ['zhen-base-memory', 'enzh-base-memory'],
    ),
  ],
);
