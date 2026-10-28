// SPDX-License-Identifier: GPL-3.0-or-later
// one chat's translations: which messages show translated, what each one
// says, and whether the chat translates on its own. held in memory only:
// a translation is made again on the phone when it is wanted, never kept.
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'catalog.dart';
import 'detect.dart';
import 'foreign.dart';
import 'hub.dart';
import 'translator.dart';

enum MsgPhase { idle, working, shown, failed }

@immutable
class MsgTranslation {
  final MsgPhase phase;
  final String? text;
  final Offer? offer;
  const MsgTranslation(this.phase, {this.text, this.offer});
}

// what a tap on "translate" ran into: what the sheet that offers the pack
// shows
@immutable
class PackNeed {
  final Offer offer;
  final List<LangBundle> missing;
  final TranslateBlock why;
  const PackNeed(this.offer, this.missing, this.why);
}

class ChatTranslation extends ChangeNotifier {
  final TranslationHub hub;
  final String chatId;
  ChatTranslation(this.hub, this.chatId) : _seenWipes = hub.wipes {
    hub.addListener(_hubChanged);
    unawaited(_load());
  }

  // the hub's lock count this chat last wiped for
  int _seenWipes;

  // the app locked: nothing of what was translated or guessed stays
  void _wipe() {
    _msgs.clear();
    _source.clear();
    _guesses.clear();
    _byAuto.clear();
    _keptOriginal.clear();
    _autoTried.clear();
    _burnt.clear();
  }

  bool? _auto;
  // null until read: no message translates on its own before then
  bool? get auto => _auto;
  bool _gone = false;

  final Map<String, MsgTranslation> _msgs = {};
  // ones the person turned back to the original: auto leaves them be
  final Set<String> _keptOriginal = {};
  // ones auto looked at already: a pack or a library that is not there is
  // not asked about again on every build
  final Set<String> _autoTried = {};

  Future<void> _load() async {
    await hub.ready();
    final on = await hub.chatAuto(chatId);
    final set = await hub.chatAutoSet(chatId);
    final hidden = await hub.barHidden(chatId);
    var lib = false;
    try {
      lib = await hub.translator.hasLibrary();
    } catch (_) {}
    if (_gone) return;
    _auto = on;
    _explicit = set;
    _barHidden = hidden;
    _hasLib = lib;
    notifyListeners();
  }

  // what this chat itself was set to, null when nobody set it: then a
  // language set to always translate does
  bool? _explicit;
  bool? _barHidden;
  bool? _hasLib;

  // whether messages in [o]'s language translate on their own here
  bool autoOn(Offer o) =>
      _auto == true ||
      (_auto != null &&
          _explicit == null &&
          hub.settings.always.contains(o.from));

  // the language most of their recent messages are in, when the person
  // does not read it: what the bar at the top of the chat offers. two of
  // them at least, and at least half of those with words
  Offer? barOffer(Iterable<String> theirs) {
    if (_barHidden != false || _hasLib != true || _auto == null) return null;
    if (hub.locked) return null;
    final counts = <Offer, int>{};
    var seen = 0;
    for (final t in theirs) {
      if (t.trim().isEmpty) continue;
      seen++;
      final o = offer(t);
      if (o != null) counts[o] = (counts[o] ?? 0) + 1;
    }
    Offer? best;
    var most = 0;
    counts.forEach((o, n) {
      if (n > most) {
        best = o;
        most = n;
      }
    });
    return most >= 2 && most * 2 >= seen ? best : null;
  }

  // the bar's tap: the whole chat in the reader's language from now on.
  // what it needs first when a pack or the library is not there
  Future<PackNeed?> translateAll(Offer o) async {
    if (hub.locked) return null;
    final block = await hub.blockFor(o);
    if (block != null) return PackNeed(o, hub.missing(o), block);
    _explicit = true;
    await setAuto(true);
    return null;
  }

  // and back: every message as it came, tapped ones too
  Future<void> showOriginalAll() async {
    _explicit = false;
    await setAuto(false);
    if (_gone) return;
    for (final e in _msgs.entries.toList()) {
      if (e.value.phase != MsgPhase.shown) continue;
      _msgs[e.key] = MsgTranslation(
        MsgPhase.idle,
        text: e.value.text,
        offer: e.value.offer,
      );
      _keptOriginal.add(e.key);
    }
    notifyListeners();
  }

  // put away for this chat: the bar goes and does not come back here
  Future<void> hideBar() async {
    _barHidden = true;
    notifyListeners();
    await hub.hideBar(chatId);
  }

  // a pack that came, settings that changed, or this chat set on its page:
  // auto may look again
  void _hubChanged() {
    if (_gone) return;
    if (hub.wipes != _seenWipes) {
      _seenWipes = hub.wipes;
      _wipe();
    }
    final now = hub.chatAutoNow(chatId);
    if (now == null && _auto != null) {
      unawaited(_load());
    } else if (now != null && now != _auto) {
      _auto = now;
      // a change is someone setting it, here or on the person's page
      _explicit = now;
      _keptOriginal.clear();
    }
    // what auto translated and no longer would goes back; what was tapped
    // stays
    bool undone(String k) {
      final o = _msgs[k]?.offer;
      return _byAuto.contains(k) && (o == null || !autoOn(o));
    }

    final back = [
      for (final k in _byAuto)
        if (undone(k)) k,
    ];
    for (final k in back) {
      // the words go back; what was made stays for a tap or the next turn
      // on, in memory with the rest
      final m = _msgs[k]!;
      _msgs[k] = MsgTranslation(MsgPhase.idle, text: m.text, offer: m.offer);
      _byAuto.remove(k);
    }
    _autoTried.clear();
    notifyListeners();
  }

  // translated by auto, not by a tap
  final Set<String> _byAuto = {};

  Future<void> setAuto(bool on) => hub.setChatAuto(chatId, on);

  // with the message's words as they are now: one they edited since is
  // read as never translated, and what was made of the old words goes
  MsgTranslation of(String key, [String? text]) {
    if (text != null) {
      final was = _source[key];
      if (was != null && was != text) _dropEdited(key, was, text);
    }
    return _msgs[key] ?? const MsgTranslation(MsgPhase.idle);
  }

  // the words each translation was made from
  final Map<String, String> _source = {};

  // the new words are kept as the key's source, so a translation of the
  // old ones that is still under way is not taken when it comes
  void _dropEdited(String key, String was, String now) {
    _msgs.remove(key);
    _source[key] = now;
    _byAuto.remove(key);
    _keptOriginal.remove(key);
    _autoTried.remove(key);
    _guesses.remove(was);
  }

  // each text's guess, asked again on every build: kept here, so it goes
  // when the chat closes
  final Map<String, LangGuess> _guesses = {};

  // whether a message from them is offered a translation at all
  Offer? offer(String text) {
    if (text.trim().isEmpty || hub.locked) return null;
    return hub.offerOf(_guesses[text] ??= hub.guess(text));
  }

  bool shown(String key, [String? text]) =>
      of(key, text).phase == MsgPhase.shown;

  // a message that burned or was taken back: its translation and its guess
  // go now, not when the chat closes
  void forget(String key, String text) {
    _byAuto.remove(key);
    _keptOriginal.remove(key);
    _autoTried.remove(key);
    _guesses.remove(text);
    _burnt.add(key);
    _source.remove(key);
    if (_msgs.remove(key) != null && !_gone) notifyListeners();
  }

  // ones forgotten: a translation still under way for one is not kept
  final Set<String> _burnt = {};

  void _set(String key, String source, MsgTranslation m) {
    if (_gone || _burnt.contains(key)) return;
    // one made from words edited since it was asked for is not kept
    if (_source[key] case final was? when was != source) return;
    _msgs[key] = m;
    _source[key] = source;
    notifyListeners();
  }

  // the bubble's action and the menu's: translate, or back to the original.
  // what it needs first when a pack or the library is not there
  Future<PackNeed?> toggle(String key, String text) async {
    if (hub.locked) return null;
    _byAuto.remove(key);
    final now = of(key, text);
    if (now.phase == MsgPhase.shown) {
      _keptOriginal.add(key);
      _set(
        key,
        text,
        MsgTranslation(MsgPhase.idle, text: now.text, offer: now.offer),
      );
      return null;
    }
    if (now.phase == MsgPhase.working) return null;
    final o = offer(text);
    if (o == null) return null;
    _keptOriginal.remove(key);
    // made before and turned back: shown again at once
    if (now.text != null && now.offer == o) {
      _set(key, text, MsgTranslation(MsgPhase.shown, text: now.text, offer: o));
      return null;
    }
    return _run(key, text, o);
  }

  // a bubble on screen in a chat that translates on its own. a pack that is
  // not there is never fetched for it, and nothing is said
  void autoFor(String key, String text) {
    if (hub.locked || _keptOriginal.contains(key)) return;
    final now = of(key, text);
    if (now.phase != MsgPhase.idle) return;
    final o = offer(text);
    if (o == null || !autoOn(o) || !_autoTried.add(key)) return;
    if (hub.missing(o).isNotEmpty) return;
    // made before and turned back: shown again at once
    if (now.text != null && now.offer == o) {
      _set(key, text, MsgTranslation(MsgPhase.shown, text: now.text, offer: o));
      _byAuto.add(key);
      return;
    }
    unawaited(
      _run(key, text, o).then((_) {
        if (shown(key)) _byAuto.add(key);
      }),
    );
  }

  Future<PackNeed?> _run(String key, String text, Offer o) async {
    // a lock while it runs: what it made is not kept
    final w = hub.wipes;
    bool still() => hub.wipes == w && !hub.locked;
    final block = await hub.blockFor(o);
    if (!still()) return null;
    if (block != null) return PackNeed(o, hub.missing(o), block);
    _set(key, text, MsgTranslation(MsgPhase.working, offer: o));
    try {
      final out = await hub.translate(text, o);
      if (still()) {
        _set(key, text, MsgTranslation(MsgPhase.shown, text: out, offer: o));
      }
      return null;
    } on TranslateUnavailable catch (e) {
      if (!still()) return null;
      _set(key, text, const MsgTranslation(MsgPhase.idle));
      return PackNeed(o, hub.missing(o), e.why);
    } catch (_) {
      if (still()) _set(key, text, MsgTranslation(MsgPhase.failed, offer: o));
      return null;
    }
  }

  @override
  void dispose() {
    _gone = true;
    _guesses.clear();
    _msgs.clear();
    _source.clear();
    _burnt.clear();
    hub.removeListener(_hubChanged);
    super.dispose();
  }
}
