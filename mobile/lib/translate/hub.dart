// SPDX-License-Identifier: GPL-3.0-or-later
// translation's one place: the settings, the packs, the guess and the
// translator, shared by every chat and the settings page. hub_live.dart
// builds the phone's; a test sets its own in [TranslationHub.instance].
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../l10n/app_locale.dart' show currentLanguage;
import 'catalog.dart';
import 'detect.dart';
import 'downloads.dart';
import 'engine_bridge.dart';
import 'foreign.dart';
import 'hant.dart';
import 'settings.dart';
import 'translator.dart';

class TranslationHub extends ChangeNotifier {
  static TranslationHub? instance;

  final TranslateStore store;
  final TranslateEngine? engine;
  final Translator translator;
  final ModelDownloads downloads;
  final String Function() appLang;
  // a message's language, made on the phone in dart
  final LangGuess Function(String text) guess;
  // whose settings these are: an identity switch reads them again
  final String Function() scope;
  // simplified into traditional chinese, read when first wanted
  final Future<HantConverter> Function() loadHant;
  late final TranslateCatalog catalog;

  TranslationHub({
    required this.store,
    required this.translator,
    required this.downloads,
    this.engine,
    TranslateCatalog? catalog,
    String Function()? appLang,
    String Function()? scope,
    LangGuess Function(String text)? guess,
    Future<HantConverter> Function()? loadHant,
  }) : appLang = appLang ?? (() => currentLanguage),
       scope = scope ?? (() => ''),
       guess = guess ?? detectLanguage,
       loadHant = loadHant ?? HantConverter.load {
    this.catalog = catalog ?? engine?.catalog() ?? builtInCatalog;
    downloads.addListener(notifyListeners);
  }

  TranslateSettings _settings = const TranslateSettings();
  TranslateSettings get settings => _settings;
  String? _loadedFor;
  Future<void>? _loading;

  // the settings for this identity, and what is on the phone, once
  Future<void> ready() {
    final now = scope();
    if (_loadedFor == now && _loading != null) return _loading!;
    _loadedFor = now;
    _chatAuto.clear();
    return _loading = () async {
      try {
        _settings = await store.load();
      } catch (_) {
        _settings = const TranslateSettings();
      }
      for (final b in catalog.langs) {
        try {
          await downloads.refresh(b.lang);
        } catch (_) {}
      }
      notifyListeners();
    }();
  }

  Future<void> saveSettings(TranslateSettings s) async {
    // a new default reaches the chats nobody set
    if (s.autoDefault != _settings.autoDefault) _chatAuto.clear();
    _settings = s;
    notifyListeners();
    await store.save(s);
  }

  Set<String> get mine => readLangs(appLang(), _settings.mine);

  // translation offered at all
  bool get on => _settings.on;

  // what a message would be translated into, or null when translation is
  // off, the message is a few words, in a language the person reads or
  // never wants offered, or one there is no model for
  Offer? offer(String text) => offerOf(guess(text), text);

  // the same for a guess a chat made before
  Offer? offerOf(LangGuess g, String text) {
    if (!on || !wordyEnough(text)) return null;
    final o = offerFor(
      g,
      catalog,
      appLang: appLang(),
      chosen: _settings.target,
      mine: mine,
    );
    if (o == null || _settings.never.contains(o.from)) return null;
    return o;
  }

  // the packs an offer needs that are not on the phone yet
  List<LangBundle> missing(Offer o) => [
    for (final b in catalog.bundlesFor(catalog.route(o.from, o.to) ?? const []))
      if (!downloads.installed(b.lang)) b,
  ];

  Future<TranslateBlock?> blockFor(Offer o) async {
    final route = catalog.route(o.from, o.to);
    if (route == null) return TranslateBlock.noModel;
    // said first: a pack fetched now is used only once the library is in
    if (!await translator.hasLibrary()) return TranslateBlock.noLib;
    if (missing(o).isNotEmpty) return TranslateBlock.noModel;
    for (final (f, t) in route) {
      final b = await translator.blockFor(f, t);
      if (b != null) return b;
    }
    return null;
  }

  // through english when there is no model straight across
  Future<String> translate(String text, Offer o) async {
    final route = catalog.route(o.from, o.to);
    if (route == null) {
      throw const TranslateUnavailable(TranslateBlock.noModel);
    }
    var out = text;
    for (final (f, t) in route) {
      out = await translator.translate(out, from: f, to: t);
    }
    if (o.hant != HantForm.none) {
      out = (await (_hant ??= loadHant())).convert(out, o.hant);
    }
    return out;
  }

  Future<HantConverter>? _hant;

  // the app went to the background: the models and the tables out of
  // memory, opened again when next wanted
  Future<void> away() async {
    _hant = null;
    try {
      await translator.close();
    } catch (_) {}
  }

  // the screens changed session, a vault shut say: what was read of its
  // chats goes, and is read again from the session that is open
  void forgetChats() {
    if (_chatAuto.isEmpty) return;
    _chatAuto.clear();
    notifyListeners();
  }

  // one chat deleted: what was read of it goes
  void forgetChat(String chatId) {
    if (_chatAuto.remove(chatId) != null) notifyListeners();
  }

  // the app locked: every open chat drops what it translated and guessed,
  // and nothing is translated or guessed until it opens again
  bool _locked = false;
  bool get locked => _locked;
  int _wipes = 0;
  int get wipes => _wipes;

  void lockedOut() {
    _locked = true;
    _wipes++;
    notifyListeners();
  }

  void unlocked() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  // lockedOut and unlocked as [isLocked] turns on [lock]; the returned call
  // stops it
  VoidCallback followLock(Listenable lock, bool Function() isLocked) {
    var was = isLocked();
    if (was) lockedOut();
    void heard() {
      final now = isLocked();
      if (now == was) return;
      was = now;
      now ? lockedOut() : unlocked();
    }

    lock.addListener(heard);
    return () => lock.removeListener(heard);
  }

  // forgetChats each time [rev] moves on [state]; the returned call stops it
  VoidCallback followSessions(Listenable state, int Function() rev) {
    var last = rev();
    void heard() {
      final now = rev();
      if (now == last) return;
      last = now;
      forgetChats();
      // a vault that opens drops what it kept before an off
      unawaited(dropKept());
    }

    state.addListener(heard);
    return () => state.removeListener(heard);
  }

  // what each chat was last read or set to, so an open chat hears a
  // change made on the person's page
  final Map<String, bool> _chatAuto = {};
  bool? chatAutoNow(String chatId) => _chatAuto[chatId];

  // a chat set on or off, or the default
  Future<bool> chatAuto(String chatId) async {
    bool on;
    try {
      on = await store.chatAuto(chatId) ?? _settings.autoDefault;
    } catch (_) {
      on = _settings.autoDefault;
    }
    return _chatAuto[chatId] = on;
  }

  // what the chat itself was set to, null when nobody set it
  Future<bool?> chatAutoSet(String chatId) async {
    try {
      return await store.chatAuto(chatId);
    } catch (_) {
      return null;
    }
  }

  // the bar a chat in another language shows at its top, put away
  Future<bool> barHidden(String chatId) async {
    try {
      return await store.barHidden(chatId);
    } catch (_) {
      return false;
    }
  }

  Future<void> hideBar(String chatId) async {
    try {
      await store.setBarHidden(chatId, true);
    } catch (_) {}
  }

  // every chat nobody set translates [lang] on its own, or stops
  Future<void> alwaysFor(String lang, bool on) => saveSettings(
    _settings.copyWith(
      always: [
        for (final l in _settings.always)
          if (l != lang) l,
        if (on) lang,
      ],
    ),
  );

  // nothing in [lang] is offered until the person takes it off the list
  Future<void> neverFor(String lang) => saveSettings(
    _settings.copyWith(
      never: [
        for (final l in _settings.never)
          if (l != lang) l,
        lang,
      ],
      always: [
        for (final l in _settings.always)
          if (l != lang) l,
      ],
    ),
  );

  // [lang] off the never list: offered again
  Future<void> offerAgain(String lang) => saveSettings(
    _settings.copyWith(
      never: [
        for (final l in _settings.never)
          if (l != lang) l,
      ],
    ),
  );

  // off deletes every kept translation
  Future<void> setOn(bool on) async {
    if (on == _settings.on) return;
    await saveSettings(
      _settings.copyWith(on: on, offs: on ? null : _settings.offs + 1),
    );
    if (!on) await dropKept();
  }

  // kept translations of the times it was turned off, gone from every
  // container open now
  Future<void> dropKept() async {
    if (_settings.offs == 0) return;
    try {
      await store.dropKept(_settings.offs);
    } catch (_) {}
  }

  // a chat's kept translations, read when it opens. a store that fails
  // keeps none
  Future<Map<String, KeptTranslation>> kept(String chatId) async {
    try {
      return await store.kept(chatId);
    } catch (_) {
      return const {};
    }
  }

  Future<void> keep(
    String chatId,
    String uid,
    KeptTranslation t,
    String words,
  ) async {
    if (!on) return;
    try {
      await store.keep(chatId, uid, t, words);
    } catch (_) {}
  }

  Future<void> unkeep(String chatId, String uid) async {
    try {
      await store.unkeep(chatId, uid);
    } catch (_) {}
  }

  Future<void> setChatAuto(String chatId, bool on) async {
    _chatAuto[chatId] = on;
    notifyListeners();
    await store.setChatAuto(chatId, on);
  }

  @override
  void dispose() {
    downloads.removeListener(notifyListeners);
    super.dispose();
  }
}

// the models closed while the app is in the background
class TranslateAway with WidgetsBindingObserver {
  final TranslationHub hub;
  TranslateAway(this.hub);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(hub.away());
    }
  }
}
