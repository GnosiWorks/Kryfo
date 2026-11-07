// SPDX-License-Identifier: GPL-3.0-or-later
// which packs can be downloaded, what each costs and which directions it
// holds. a pack is one direction to or from english ("de-en", "en-de");
// an older pack may hold both of a language's. the engine's pinned
// manifest (engine/translate/models.json) is the source; the copy here is
// what the app shows when the engine cannot be asked, and a test keeps the
// two the same.
import 'dart:convert';

class LangBundle {
  // what the engine downloads it by
  final String id;
  // bytes on the wire, padding included, and once unpacked
  final int gz;
  final int disk;
  // its directions, "zh-en", and the folder each one unpacks into
  final List<String> pairs;
  final List<String> dirs;
  const LangBundle({
    required this.id,
    required this.gz,
    required this.disk,
    required this.pairs,
    required this.dirs,
  });

  bool holds(String from, String to) => pairs.contains('$from-$to');

  // the languages it is for, english aside
  Set<String> get langs => {
    for (final p in pairs)
      for (final l in p.split('-'))
        if (l != 'en') l,
  };
}

// which ways a language goes with english
enum LangWays { both, intoEnglish, fromEnglish }

class TranslateCatalog {
  // where the files come from: the pinned mirror, nothing else
  final String base;
  final List<LangBundle> packs;
  const TranslateCatalog({required this.base, required this.packs});

  // the engine's HaloTranslateCatalog answer, or null when it is not one.
  // a pack may name its one direction ("from", "to", "dir") or list them
  static TranslateCatalog? parse(String s) {
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      final list = (j['packs'] ?? j['langs']) as List? ?? const [];
      return TranslateCatalog(
        base: j['base'] as String,
        packs: [for (final l in list.cast<Map<String, dynamic>>()) _pack(l)],
      );
    } catch (_) {
      return null;
    }
  }

  static LangBundle _pack(Map<String, dynamic> l) {
    final pairs = l['pairs'] == null
        ? ['${l['from'] as String}-${l['to'] as String}']
        : [for (final p in l['pairs'] as List) p as String];
    final dirs = l['dirs'] == null
        ? [l['dir'] as String]
        : [for (final d in l['dirs'] as List) d as String];
    if (pairs.isEmpty || pairs.length != dirs.length) {
      throw const FormatException('pairs');
    }
    return LangBundle(
      id: (l['id'] ?? l['lang']) as String,
      gz: (l['gz'] as num).toInt(),
      disk: (l['disk'] as num).toInt(),
      pairs: pairs,
      dirs: dirs,
    );
  }

  LangBundle? bundle(String id) {
    for (final b in packs) {
      if (b.id == id) return b;
    }
    return null;
  }

  // the pack that holds the direction from -> to
  LangBundle? bundleFor(String from, String to) {
    for (final b in packs) {
      if (b.holds(from, to)) return b;
    }
    return null;
  }

  // the steps from one language to another: straight across when a pack
  // holds that direction, else through english when both legs have one,
  // null when there is no way
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

  // the packs a route needs that are not there: all of them when [have]
  // is not given
  List<LangBundle> bundlesFor(
    List<(String, String)> route, {
    bool Function(String id)? have,
  }) {
    final out = <LangBundle>[];
    for (final (f, t) in route) {
      final b = bundleFor(f, t);
      if (b == null || out.contains(b)) continue;
      if (have != null && have(b.id)) continue;
      out.add(b);
    }
    return out;
  }

  // every language with a pack to or from english, in catalog order. the
  // traditional chinese packs ("zh_hant") are not offered: chinese is one
  // language here, read either way, and traditional readers get the
  // chinese model's words in their own forms (hant.dart)
  List<String> get languages => [
    ...{
      for (final b in packs) ...b.langs,
    }.where((l) => !l.contains('_') && waysOf(l) != null),
  ];

  // the packs a language's own download is: its directions with english
  List<LangBundle> packsOf(String lang) => [
    for (final b in packs)
      if (b.holds(lang, 'en') || b.holds('en', lang)) b,
  ];

  // what a language's download is good for, null when there is none
  LangWays? waysOf(String lang) {
    final into = bundleFor(lang, 'en') != null;
    final from = bundleFor('en', lang) != null;
    if (into && from) return LangWays.both;
    if (into) return LangWays.intoEnglish;
    if (from) return LangWays.fromEnglish;
    return null;
  }

  // a language's download size: every pack of it, on the wire
  int sizeOf(String lang) => packsOf(lang).fold(0, (n, b) => n + b.gz);
}

// the pinned manifest's numbers: one pack per direction with english for
// every app language, from our mirror, each padded to the 48 MiB class
const builtInCatalog = TranslateCatalog(
  base:
      'http://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion/models/',
  packs: [
    LangBundle(
      id: 'ar-en',
      gz: 50331648,
      disk: 37049022,
      pairs: ['ar-en'],
      dirs: ['aren-base-memory'],
    ),
    LangBundle(
      id: 'de-en',
      gz: 50331648,
      disk: 37317656,
      pairs: ['de-en'],
      dirs: ['deen-base-memory'],
    ),
    LangBundle(
      id: 'en-ar',
      gz: 50331648,
      disk: 35565070,
      pairs: ['en-ar'],
      dirs: ['enar-base-memory'],
    ),
    LangBundle(
      id: 'en-de',
      gz: 50331648,
      disk: 36719532,
      pairs: ['en-de'],
      dirs: ['ende-base-memory'],
    ),
    LangBundle(
      id: 'en-es',
      gz: 50331648,
      disk: 36576277,
      pairs: ['en-es'],
      dirs: ['enes-base-memory'],
    ),
    LangBundle(
      id: 'en-fa',
      gz: 50331648,
      disk: 21615516,
      pairs: ['en-fa'],
      dirs: ['enfa-tiny'],
    ),
    LangBundle(
      id: 'en-fr',
      gz: 50331648,
      disk: 36749127,
      pairs: ['en-fr'],
      dirs: ['enfr-base-memory'],
    ),
    LangBundle(
      id: 'en-hi',
      gz: 50331648,
      disk: 21571231,
      pairs: ['en-hi'],
      dirs: ['enhi-tiny'],
    ),
    LangBundle(
      id: 'en-id',
      gz: 50331648,
      disk: 21429690,
      pairs: ['en-id'],
      dirs: ['enid-tiny'],
    ),
    LangBundle(
      id: 'en-it',
      gz: 50331648,
      disk: 36507703,
      pairs: ['en-it'],
      dirs: ['enit-base-memory'],
    ),
    LangBundle(
      id: 'en-pl',
      gz: 50331648,
      disk: 35923451,
      pairs: ['en-pl'],
      dirs: ['enpl-base-memory'],
    ),
    LangBundle(
      id: 'en-pt',
      gz: 50331648,
      disk: 36348853,
      pairs: ['en-pt'],
      dirs: ['enpt-base-memory'],
    ),
    LangBundle(
      id: 'en-ru',
      gz: 50331648,
      disk: 35240782,
      pairs: ['en-ru'],
      dirs: ['enru-base-memory'],
    ),
    LangBundle(
      id: 'en-tr',
      gz: 50331648,
      disk: 21201144,
      pairs: ['en-tr'],
      dirs: ['entr-tiny'],
    ),
    LangBundle(
      id: 'en-uk',
      gz: 50331648,
      disk: 35538228,
      pairs: ['en-uk'],
      dirs: ['enuk-base-memory'],
    ),
    LangBundle(
      id: 'en-vi',
      gz: 50331648,
      disk: 36944671,
      pairs: ['en-vi'],
      dirs: ['envi-base-memory'],
    ),
    LangBundle(
      id: 'en-zh',
      gz: 50331648,
      disk: 51934991,
      pairs: ['en-zh'],
      dirs: ['enzh-base-memory'],
    ),
    LangBundle(
      id: 'en-zh_hant',
      gz: 50331648,
      disk: 49462340,
      pairs: ['en-zh_hant'],
      dirs: ['enzh_hant-base-memory'],
    ),
    LangBundle(
      id: 'es-en',
      gz: 50331648,
      disk: 37014089,
      pairs: ['es-en'],
      dirs: ['esen-base-memory'],
    ),
    LangBundle(
      id: 'fa-en',
      gz: 50331648,
      disk: 21880624,
      pairs: ['fa-en'],
      dirs: ['faen-tiny'],
    ),
    LangBundle(
      id: 'fr-en',
      gz: 50331648,
      disk: 37200311,
      pairs: ['fr-en'],
      dirs: ['fren-base-memory'],
    ),
    LangBundle(
      id: 'hi-en',
      gz: 50331648,
      disk: 22672471,
      pairs: ['hi-en'],
      dirs: ['hien-tiny'],
    ),
    LangBundle(
      id: 'id-en',
      gz: 50331648,
      disk: 21964340,
      pairs: ['id-en'],
      dirs: ['iden-tiny'],
    ),
    LangBundle(
      id: 'it-en',
      gz: 50331648,
      disk: 37088127,
      pairs: ['it-en'],
      dirs: ['iten-base-memory'],
    ),
    LangBundle(
      id: 'pl-en',
      gz: 50331648,
      disk: 37347607,
      pairs: ['pl-en'],
      dirs: ['plen-base-memory'],
    ),
    LangBundle(
      id: 'pt-en',
      gz: 50331648,
      disk: 37013005,
      pairs: ['pt-en'],
      dirs: ['pten-base-memory'],
    ),
    LangBundle(
      id: 'ru-en',
      gz: 50331648,
      disk: 36912066,
      pairs: ['ru-en'],
      dirs: ['ruen-base-memory'],
    ),
    LangBundle(
      id: 'tr-en',
      gz: 50331648,
      disk: 22614681,
      pairs: ['tr-en'],
      dirs: ['tren-tiny'],
    ),
    LangBundle(
      id: 'uk-en',
      gz: 50331648,
      disk: 21941581,
      pairs: ['uk-en'],
      dirs: ['uken-tiny'],
    ),
    LangBundle(
      id: 'vi-en',
      gz: 50331648,
      disk: 21808485,
      pairs: ['vi-en'],
      dirs: ['vien-tiny'],
    ),
    LangBundle(
      id: 'zh-en',
      gz: 50331648,
      disk: 54556676,
      pairs: ['zh-en'],
      dirs: ['zhen-base-memory'],
    ),
    LangBundle(
      id: 'zh_hant-en',
      gz: 50331648,
      disk: 51817972,
      pairs: ['zh_hant-en'],
      dirs: ['zh_hanten-base-memory'],
    ),
  ],
);
