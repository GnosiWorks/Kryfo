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
  }) : appLang = appLang ?? (() => currentLanguage),
       scope = scope ?? (() => ''),
       guess = guess ?? detectLanguage {
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

  // what a message would be translated into, or null when it is in a
  // language the person reads, or one there is no model for
  Offer? offer(String text) => offerOf(guess(text));

  // the same for a guess a chat made before
  Offer? offerOf(LangGuess g) => offerFor(
    g,
    catalog,
    appLang: appLang(),
    chosen: _settings.target,
    mine: mine,
  );

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
    return out;
  }

  // the app went to the background: the models out of memory, opened
  // again when next wanted
  Future<void> away() async {
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

  // forgetChats each time [rev] moves on [state]; the returned call stops it
  VoidCallback followSessions(Listenable state, int Function() rev) {
    var last = rev();
    void heard() {
      final now = rev();
      if (now == last) return;
      last = now;
      forgetChats();
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
