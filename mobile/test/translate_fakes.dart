// SPDX-License-Identifier: GPL-3.0-or-later
// stand-ins for translation: a translator that looks words up, and a pack
// store that downloads when told to. nothing here reaches the network or
// the engine
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/downloads.dart';
import 'package:kryfo/translate/engine_bridge.dart';
import 'package:kryfo/translate/hant.dart';
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:kryfo/translate/translator.dart';

class FakeTranslator implements Translator {
  // what each text becomes; anything else gets a mark in front
  final Map<String, String> words;
  // the library is in this build
  bool lib;
  // whether a direction's pack is on the phone
  bool Function(String from, String to) installed;
  // the next translation fails in the library
  bool breakNext = false;
  final List<String> asked = [];
  int closes = 0;
  FakeTranslator({
    this.words = const {},
    this.lib = true,
    bool Function(String, String)? installed,
  }) : installed = installed ?? ((_, _) => true);

  @override
  Future<bool> hasLibrary() async => lib;

  @override
  Future<TranslateBlock?> blockFor(String from, String to) async {
    if (!installed(from, to)) return TranslateBlock.noModel;
    if (!lib) return TranslateBlock.noLib;
    return null;
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final b = await blockFor(from, to);
    if (b != null) throw TranslateUnavailable(b);
    asked.add('$from-$to:$text');
    if (breakNext) {
      breakNext = false;
      throw StateError('broken');
    }
    return words[text] ?? '[$to] $text';
  }

  // each text as translate would, in one go
  final List<int> batches = [];
  Completer<void>? gate;
  @override
  Future<List<String>> translateAll(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    batches.add(texts.length);
    // a model still loading: nothing comes back until the test lets it
    final g = gate;
    if (g != null) await g.future;
    return [for (final t in texts) await translate(t, from: from, to: to)];
  }

  @override
  Future<void> close() async => closes++;
}

// a pack download the test moves along by hand
class FakeBackend implements ModelBackend {
  final TranslateCatalog catalog;
  FakeBackend([this.catalog = zhCatalog]);
  String startAnswer = 'ok';
  // every pack's status, unless it has its own in [statuses]
  FetchStatus status = const FetchStatus('idle');
  final Map<String, FetchStatus> statuses = {};
  final Set<String> have = {};
  int disk = 0;
  final Map<String, int> disks = {};
  final List<String> removed = [];
  bool get _one => catalog.packs.length == 1;
  final List<String> started = [];
  int cancels = 0;

  @override
  Future<String> start(String lang) async {
    started.add(lang);
    if (startAnswer == 'ok') {
      if (_one) {
        status = const FetchStatus('running');
      } else {
        statuses[lang] = const FetchStatus('running');
      }
    }
    return startAnswer;
  }

  @override
  FetchStatus progress(String lang) => statuses[lang] ?? status;

  @override
  void cancel(String lang) {
    cancels++;
    final s = progress(lang);
    final c = FetchStatus('cancelled', done: s.done, total: s.total);
    _one ? status = c : statuses[lang] = c;
  }

  @override
  Future<bool> installed(String lang) async => have.contains(lang);

  @override
  Future<int> onDisk(String lang) async => _one ? disk : disks[lang] ?? 0;

  @override
  Future<String> remove(String lang) async {
    removed.add(lang);
    have.remove(lang);
    disks.remove(lang);
    if (_one) disk = 0;
    return 'ok';
  }

  // the download ran to its end and the files checked out
  void finish(String lang) {
    final b = catalog.bundle(lang)!;
    final done = FetchStatus('done', done: b.gz, total: b.gz);
    _one ? status = done : statuses[lang] = done;
    have.add(lang);
    disks[lang] = b.disk;
    if (_one) disk = b.disk;
  }
}

class Fakes {
  final FakeTranslator translator;
  final FakeBackend backend;
  final MemoryTranslateStore store;
  final TranslationHub hub;
  bool wifi;
  Fakes._(this.translator, this.backend, this.store, this.hub, this.wifi);
}

// a hub for an english reader unless [app] says otherwise, with the pack
// on the phone when [installed]
Fakes fakeHub({
  bool installed = false,
  bool lib = true,
  String app = 'en',
  TranslateSettings settings = const TranslateSettings(wifiOnly: false),
  Map<String, String> words = const {},
  bool wifi = true,
  LangGuess Function(String text)? guess,
  Future<HantConverter> Function()? loadHant,
  bool quiet = false,
  MemoryTranslateStore? store,
  TranslateCatalog catalog = zhCatalog,
  // packs on the phone, by id, when [installed] is not all of them
  Set<String> have = const {},
  Duration? wifiWait,
}) {
  final backend = FakeBackend(catalog);
  if (installed) {
    for (final b in catalog.packs) {
      backend.finish(b.id);
    }
  }
  for (final id in have) {
    backend.finish(id);
  }
  backend.status = const FetchStatus('idle');
  backend.statuses.clear();
  store ??= MemoryTranslateStore(settings);
  late final Fakes f;
  late final TranslationHub hub;
  final downloads = ModelDownloads(
    backend: backend,
    onWifi: () async => f.wifi,
    wifiOnly: () => hub.settings.wifiOnly,
    poll: const Duration(milliseconds: 100),
    quiet: () => quiet,
    wifiWait: wifiWait,
  );
  final translator = FakeTranslator(
    words: words,
    lib: lib,
    installed: (a, b) => downloads.installed(catalog.bundleFor(a, b)?.id ?? ''),
  );
  hub = TranslationHub(
    store: store,
    translator: translator,
    downloads: downloads,
    catalog: catalog,
    appLang: () => app,
    guess: guess,
    loadHant: loadHant ?? _hantFromDisk,
  );
  f = Fakes._(translator, backend, store, hub, wifi);
  return f;
}

// the shipped tables, read from the checkout as the asset bundle would
Future<HantConverter> _hantFromDisk() async {
  String read(String a) => utf8.decode(gzip.decode(File(a).readAsBytesSync()));
  return HantConverter.parse(
    read(HantConverter.charsAsset),
    read(HantConverter.phrasesAsset),
    tw: read(HantConverter.twAsset),
    hk: read(HantConverter.hkAsset),
  );
}

// chinese as release-06 shipped it: one pack holding both directions, the
// shape older engines answer with, which still works
const zhCatalog = TranslateCatalog(
  base: 'http://example.onion/models/',
  packs: [
    LangBundle(
      id: 'zh',
      gz: 100663296,
      disk: 104470603,
      pairs: ['zh-en', 'en-zh'],
      dirs: ['zhen-base-memory', 'enzh-base-memory'],
    ),
  ],
);

// a catalog of one pack per direction, as the per-direction packs come:
// german both ways, russian both ways, turkish only into english, and
// chinese in its older pack that holds both
const dirCatalog = TranslateCatalog(
  base: 'http://example.onion/models/',
  packs: [
    LangBundle(
      id: 'de-en',
      gz: 50331648,
      disk: 41000000,
      pairs: ['de-en'],
      dirs: ['deen-base-memory'],
    ),
    LangBundle(
      id: 'en-de',
      gz: 50331648,
      disk: 42000000,
      pairs: ['en-de'],
      dirs: ['ende-base-memory'],
    ),
    LangBundle(
      id: 'ru-en',
      gz: 50331648,
      disk: 43000000,
      pairs: ['ru-en'],
      dirs: ['ruen-base-memory'],
    ),
    LangBundle(
      id: 'en-ru',
      gz: 100663296,
      disk: 44000000,
      pairs: ['en-ru'],
      dirs: ['enru-base-memory'],
    ),
    LangBundle(
      id: 'tr-en',
      gz: 50331648,
      disk: 40000000,
      pairs: ['tr-en'],
      dirs: ['tren-base-memory'],
    ),
    LangBundle(
      id: 'zh',
      gz: 100663296,
      disk: 104470603,
      pairs: ['zh-en', 'en-zh'],
      dirs: ['zhen-base-memory', 'enzh-base-memory'],
    ),
  ],
);
