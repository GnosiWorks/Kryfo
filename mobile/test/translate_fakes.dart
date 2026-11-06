// SPDX-License-Identifier: GPL-3.0-or-later
// stand-ins for translation: a translator that looks words up, and a pack
// store that downloads when told to. nothing here reaches the network or
// the engine
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
  @override
  Future<List<String>> translateAll(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    batches.add(texts.length);
    return [for (final t in texts) await translate(t, from: from, to: to)];
  }

  @override
  Future<void> close() async => closes++;
}

// a pack download the test moves along by hand
class FakeBackend implements ModelBackend {
  String startAnswer = 'ok';
  FetchStatus status = const FetchStatus('idle');
  final Set<String> have = {};
  int disk = 0;
  final List<String> started = [];
  int cancels = 0;

  @override
  Future<String> start(String lang) async {
    started.add(lang);
    if (startAnswer == 'ok') status = const FetchStatus('running');
    return startAnswer;
  }

  @override
  FetchStatus progress(String lang) => status;

  @override
  void cancel(String lang) {
    cancels++;
    status = FetchStatus('cancelled', done: status.done, total: status.total);
  }

  @override
  Future<bool> installed(String lang) async => have.contains(lang);

  @override
  Future<int> onDisk(String lang) async => disk;

  @override
  Future<String> remove(String lang) async {
    have.remove(lang);
    disk = 0;
    return 'ok';
  }

  // the download ran to its end and the files checked out
  void finish(String lang) {
    final gz = builtInCatalog.bundle(lang)!.gz;
    status = FetchStatus('done', done: gz, total: gz);
    have.add(lang);
    disk = builtInCatalog.bundle(lang)!.disk;
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
}) {
  final backend = FakeBackend();
  if (installed) backend.finish('zh');
  backend.status = const FetchStatus('idle');
  store ??= MemoryTranslateStore(settings);
  late final Fakes f;
  late final TranslationHub hub;
  final downloads = ModelDownloads(
    backend: backend,
    onWifi: () async => f.wifi,
    wifiOnly: () => hub.settings.wifiOnly,
    poll: const Duration(milliseconds: 100),
    quiet: () => quiet,
  );
  final translator = FakeTranslator(
    words: words,
    lib: lib,
    installed: (a, b) =>
        downloads.installed(builtInCatalog.bundleFor(a, b)?.lang ?? ''),
  );
  hub = TranslationHub(
    store: store,
    translator: translator,
    downloads: downloads,
    catalog: builtInCatalog,
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
