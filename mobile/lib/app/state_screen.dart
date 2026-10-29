// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: screen protection and screenshot blocking

part of '../main.dart';

extension AppStateScreen on AppState {
  // the lock going up or down moves the flag, a pin set or not the recents
  // picture. only the second changes what settings show
  void _lockMoved() {
    final now = (lockState.lockOn, lockState.locked);
    final was = _lockWas;
    if (was == now) return;
    _lockWas = now;
    unawaited(_applyScreenSecure());
    if (was?.$1 != now.$1) notifyListeners();
  }

  Future<void> loadScreenSecure() async {
    if (_lockWas == null) {
      _lockWas = (lockState.lockOn, lockState.locked);
      lockState.addListener(_lockMoved);
    }
    pinShieldHold = (on) => unawaited(forceSecure(on));
    try {
      _shotsCardWaits = (await secureStore.read(key: kOldShotsKey)) == 'true';
      if (_shotsCardWaits) await _readShotsCard();
    } catch (e) {
      dlog('shots card: not read (${e.runtimeType})');
    }
    await _applyScreenSecure();
    notifyListeners();
  }

  bool get shotsCardDue =>
      _shotsCardWaits && !sessionQuiet && !lockState.inVault;
  // a chat whose phone knows the block, for the card's yes
  bool get shotsCardCan => _shotsCardCan;
  // the whole window stays covered until the card is answered
  bool get shotsCardCovers => _shotsCardWaits;

  Future<void> _readShotsCard() async {
    final can = (await live.shotsCanTurnOn()).isNotEmpty;
    if (can == _shotsCardCan) return;
    _shotsCardCan = can;
    notifyListeners();
  }

  /// the card's answer: [on] blocks in every everyday chat that can, and
  /// with none that can yet the card stays. how many chats it turned on
  Future<int> answerShotsCard({required bool on}) async {
    if (sessionQuiet) return 0;
    final peers = on ? await live.shotsCanTurnOn() : const <String>[];
    if (on && peers.isEmpty) {
      await _readShotsCard();
      return 0;
    }
    for (final peer in peers) {
      await _turnShots(peer, true, live);
    }
    _shotsCardWaits = false;
    await secureStore.delete(key: kOldShotsKey);
    await _applyScreenSecure();
    notifyListeners();
    return peers.length;
  }

  /// the chat's switch: both phones block, or neither does. only once their
  /// phone knows the block; in a decoy it stays on this phone
  Future<void> setChatShots(String peer, bool on) async {
    final db = session.peerDb(peer);
    final s = await db.shotsOf(peer);
    if (!s.peerCan || s.blocked || s.on == on) return;
    await _turnShots(peer, on, db);
  }

  Future<void> _turnShots(String peer, bool on, HaloDb db) async {
    final was = (await db.shotsOf(peer)).blocking;
    final at = await db.turnShots(peer, on: on);
    if (at == null) return;
    // blocking from now: what the shade still shows of the chat goes
    if (!was && (await db.shotsOf(peer)).blocking) {
      unawaited(_io.unnotify(peer));
    }
    // queued first: a route that is down carries it later
    await db.queueFrame(shotsUid(peer), kFrameShots, peer, '$at');
    _bumpChatRev(peer);
    notifyListeners();
    try {
      await refreshContacts();
    } catch (e) {
      dlog('shots: list not read again (${e.runtimeType})');
    }
    if (await blockedAnywhere(peer)) return;
    await _frameNow(peer, shotsUid(peer), kFrameShots, '$at');
  }

  void _shotsHeard(String peer, ShotsWord w) {
    final was = _shotsWords[peer];
    if (was == null || shotsWins(w, on: was.on, at: was.at)) {
      _shotsWords[peer] = w;
    }
  }

  // what a 1:1 envelope says of the chat's block, and of their phone
  Future<void> _takeShots(String peer, UnwrappedMessage env, HaloDb db) async {
    if (env.groupId != null || isDevId(peer)) return;
    // written in the developer chat, whose frames never carry the word: it
    // says nothing of their phone, and must not undo what their chat said
    if (env.supportMarker != null) return;
    try {
      final was = (await db.shotsOf(peer)).blocking;
      final changed = await db.takeShots(
        peer,
        env.shots,
        counts: AppState._dataFrame(env) && env.msgUid != null,
        written: env.writtenAt,
      );
      if (!changed) return;
      _bumpChatRev(peer);
      notifyListeners();
      // blocking from now: what the shade still shows of the chat goes,
      // once, and never what rang since
      if (!was && (await db.shotsOf(peer)).blocking) {
        unawaited(_io.unnotify(peer));
      }
      await refreshContacts();
      if (_shotsCardWaits && identical(db, live)) await _readShotsCard();
    } catch (e) {
      dlog('shots: not taken (${e.runtimeType})');
    }
  }

  /// [wrapped] as it goes to [peer]: with the chat's block on it, from the
  /// container that holds the chat
  Future<String> shotsOnWire(String peer, String wrapped) async {
    if (isDevId(peer)) return wrapped;
    final body = shotsBodyOf(wrapped);
    if (body == null) return wrapped;
    ShotsWord? word;
    try {
      final s = await _ownerOf(peer).shotsOf(peer);
      if (s.known) word = s.word;
    } catch (e) {
      dlog('shots: not read for the wire (${e.runtimeType})');
    }
    // no row here: a chat shut away in the vault says what its card kept
    // at the close, or a newer word since, as an open one would
    if (word == null) {
      word = _router.cardOf(peer)?.shots ?? const ShotsWord(on: false, at: 0);
      final heard = _shotsWords[peer];
      if (heard != null && shotsWins(heard, on: word.on, at: word.at)) {
        word = heard;
      }
    }
    _shotsHeard(peer, word);
    // and what this phone understands, on every 1:1 frame (typing.dart)
    capsPut(body);
    _toldCaps(peer);
    return shotsPut(body, word);
  }

  // the chat blocks screenshots on this phone, as its rows say. one that
  // will not read rings as it did before the block
  Future<bool> _shotsBlock(HaloDb db, String peer) async {
    try {
      return (await db.shotsOf(peer)).blocking;
    } catch (e) {
      dlog('shots: not read for the shade (${e.runtimeType})');
      return false;
    }
  }

  /// the chat blocks screenshots on this phone, as the list knows it: read
  /// at once, before a screen opens on it
  bool shotsBlocksChat(String peer) =>
      contacts.any((c) => c.haloId == peer && c.shotsBlocking);

  /// a room, which always blocks, or a group that does, as the list knows
  /// it: read at once, before a screen opens on it
  bool shotsBlocksGroup(String groupId) => groups.any(
    (g) => g.groupId == groupId && (g.expiresAt != null || g.shotsBlocking),
  );
  bool get secureForced => _secureHolds > 0;

  /// the window refuses screenshots now: a chat or room that blocks them,
  /// a viewer's or a pin screen's hold, the lock screen or the old switch's
  /// card
  bool get windowSecure => secureForced || lockState.locked || _shotsCardWaits;

  /// a pin is set: recents shows no picture of the app. a lock turned off
  /// in the decoy is off here too, as anywhere
  bool get recentsHidden => lockState.lockOn || lockState.locked;

  Future<void> forceSecure(bool on) async {
    _secureHolds = on ? _secureHolds + 1 : max(0, _secureHolds - 1);
    await _applyScreenSecure();
  }

  Future<void> _applyScreenSecure() async {
    final on = windowSecure;
    if (on != _secureSent) {
      _secureSent = on;
      try {
        await AppState._platformChannel.invokeMethod('setSecure', {'on': on});
      } catch (e) {
        _secureSent = null;
        dlog('setSecure: $e');
      }
    }
    final hide = recentsHidden;
    if (hide == _recentsSent) return;
    _recentsSent = hide;
    try {
      await AppState._platformChannel.invokeMethod('setRecentsHidden', {
        'on': hide,
      });
    } catch (e) {
      _recentsSent = null;
      dlog('setRecentsHidden: $e');
    }
  }
}
