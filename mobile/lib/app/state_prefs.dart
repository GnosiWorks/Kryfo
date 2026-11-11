// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: small settings: ghost, disguise and theme

part of '../main.dart';

extension AppStatePrefs on AppState {
  // the open session's own, like everything a screen sets for an identity
  Future<void> saveGhostPref(bool on, int secs) async {
    const s = secureStore;
    final c = session.container;
    await s.write(key: c.key('ghost_on'), value: on ? '1' : '0');
    await s.write(key: c.key('ghost_secs'), value: '$secs');
  }

  /// a chat's flame: its own setting, or for a chat with none yet what the
  /// one switch for every chat was before each chat had its own
  Future<(bool, int)> loadChatBurn(String chatId, {bool group = false}) async {
    int? own;
    try {
      own = await session.chatBurnOf(chatId, group: group);
    } catch (e) {
      dlog('chat timer: not read (${e.runtimeType})');
    }
    final before = await loadGhostPref();
    if (own == null) return before;
    // off keeps the last length picked, so the picker opens on it
    return own == 0 ? (false, before.$2) : (true, own);
  }

  /// this chat's flame, kept with the chat and nowhere else
  Future<void> saveChatBurn(
    String chatId,
    bool on,
    int secs, {
    bool group = false,
  }) async {
    try {
      await session.setChatBurn(chatId, on ? secs : 0, group: group);
    } catch (e) {
      // not kept: the chat keeps it for as long as it is open
      dlog('chat timer: not kept (${e.runtimeType})');
    }
  }

  Future<(bool, int)> loadGhostPref() async {
    const s = secureStore;
    final c = session.container;
    final on = (await s.read(key: c.key('ghost_on'))) == '1';
    final secs =
        int.tryParse(await s.read(key: c.key('ghost_secs')) ?? '') ?? 300;
    return (on, secs);
  }

  // the identity's default for chats with no choice of their own. it was
  // the one switch for every chat before each chat had its own
  Future<bool> loadDisguisePref() async {
    const s = secureStore;
    return (await s.read(key: session.container.key('disguise_on'))) == '1';
  }

  // whether a chat's notes go out disguised: its own choice, else on in a
  // burner room, else the identity's default
  Future<bool> loadChatDisguise(
    String chatId, {
    bool group = false,
    bool burner = false,
  }) async {
    bool? own;
    try {
      own = await session.voiceDisguiseOf(chatId, group: group);
    } catch (e) {
      // unread, the chat takes the default
      dlog('voice choice: not read (${e.runtimeType})');
    }
    return chatDisguise(
      own: own,
      burner: burner,
      fallback: own == null && !burner && await loadDisguisePref(),
    );
  }

  Future<void> saveChatDisguise(String chatId, bool on, {bool group = false}) =>
      session.setVoiceDisguise(chatId, on, group: group);

  Future<void> saveDisguisePref(bool on) async {
    const s = secureStore;
    await s.write(
      key: session.container.key('disguise_on'),
      value: on ? '1' : '0',
    );
  }

  Future<void> loadThemePref() async {
    try {
      final v = (await secureStore.read(key: 'theme_light')) == 'true';
      HaloColors.setLight(v);
      HaloColors.setAccent(
        HaloAccent.byName(await secureStore.read(key: 'theme_accent')),
      );
    } catch (e) {
      dlog('theme pref: $e');
    }
  }

  Future<void> setLight(bool v) async {
    HaloColors.setLight(v);
    themeRevision.value++;
    notifyListeners();
    await secureStore.write(key: 'theme_light', value: v.toString());
  }

  // one accent for the whole app, like the theme: every identity, hidden
  // chats and the decoy show the same, so none of them stands out
  Future<void> setAccent(HaloAccent a) async {
    if (a == HaloColors.accent) return;
    HaloColors.setAccent(a);
    themeRevision.value++;
    notifyListeners();
    await secureStore.write(key: 'theme_accent', value: a.name);
  }
}
