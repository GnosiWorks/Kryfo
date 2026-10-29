// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the typing indicator (typing.dart)

part of '../main.dart';

extension AppStateTyping on AppState {
  /// the key [chatId]'s typing shows under: the container that holds it
  String typingKey(String chatId) => _ownerOf(chatId).container.chatKey(chatId);

  bool get typingOn => typing.on;

  /// tor may go through a bridge, picked or tried by automatic: typing is
  /// off then, as a network that needs one may be watched closely enough
  /// to match its signals. it comes back by itself when bridges are off
  bool get typingBridged =>
      _sendMode == 'private' && (manualBridge || _bridgeStatus.mayRideBridge);

  // the status as the engine has it now, not as the decoy last saw it:
  // read again as a session opens, before a frame could go
  void _typingBridgesRead() {
    try {
      takeBridgeStatus(engine.bridgeStatus());
    } catch (e) {
      dlog('typing: bridges not read (${e.runtimeType})');
    }
  }

  // bridges came into use: what shows goes at once
  void _typingBridgesMoved() {
    if (typingBridged) _typingClear();
  }

  @visibleForTesting
  set inFrontForTest(bool v) => _inFront = v;

  Future<void> loadTypingPref() async {
    try {
      typing.on = await loadTypingOn();
    } catch (e) {
      dlog('typing: switch not read (${e.runtimeType})');
    }
    if (typing.watching) return;
    typing.watching = true;
    lockState.addListener(_typingLockMoved);
  }

  /// the settings switch, for the open session's identity. a decoy's is
  /// its own and changes nothing
  Future<void> setTypingOn(bool on) async {
    final c = session.container;
    await saveTypingOn(on, c);
    if (c.quiet) return;
    typing.on = on;
    if (!on) _typingClear();
  }

  // what may change while a typing frame is sealed or read: the session,
  // the lock, the decoy, the app's place on screen, the switch, the route
  bool _typingStill(int epoch) =>
      epoch == _openedEpoch &&
      typing.on &&
      _sendMode == 'private' &&
      !lockState.locked &&
      !inDecoyView &&
      !typingBridged &&
      _inFront;

  void _typingLockMoved() {
    if (lockState.locked) _typingClear();
  }

  void _typingClear() => typing.board.clearAll();

  /// an edit in [peer]'s composer. [userEdit]: a keystroke or a paste, as
  /// against words put there by the app. a frame goes when every gate
  /// holds and the pace allows one. a failure is dropped
  Future<void> typingEdit(
    String peer, {
    required bool userEdit,
    required bool nonEmpty,
  }) async {
    // what memory knows first: most keystrokes stop here
    if (!userEdit || !nonEmpty || !typing.on || isDevId(peer)) return;
    if (inDecoyView || _sendMode != 'private' || !_inFront) return;
    final owner = _ownerOf(peer);
    final key = owner.container.chatKey(peer);
    final epoch = _openedEpoch;
    if (!typing.pacer.take(key, peer: peer)) return;
    var tried = false;
    var ok = false;
    try {
      final row = await owner.getContact(peer);
      final onion = (row?['onion'] as String?) ?? '';
      final facts = TypingSendFacts(
        switchOn: typing.on,
        decoy: inDecoyView,
        held: everydayHeld || haloWiping,
        locked: lockState.locked,
        inFront: _inFront,
        onScreen: readingIn(peer, owner.container),
        oneToOne: !peer.startsWith('group:') && !isDevId(peer),
        accepted: row?['accepted'] == 1,
        backPaired: row?['back_paired'] == 1,
        blocked:
            row == null || row['blocked'] == 1 || await blockedAnywhere(peer),
        peerCan: capsOfText(row?['caps'] as String?).contains(kCapTyping),
        hasOnion: onion.isNotEmpty,
        privateRoute: _sendMode == 'private',
        torUsable: torUsable,
        linkUp: linkUp,
        userEdit: userEdit,
        nonEmpty: nonEmpty,
        bridges: typingBridged,
        archived: row?['archived'] == 1,
      );
      if (!typingMaySend(facts)) return;
      final cipher = await _io.typingSeal(
        peer,
        wrapTyping(writtenAt: DateTime.now().millisecondsSinceEpoch),
      );
      // a lock, a decoy, the back or another route may have come while it
      // sealed: then it stays here
      if (!_typingStill(epoch) || !readingIn(peer, owner.container)) return;
      tried = true;
      ok = await _io.typingSend(onion, cipher) == 'ok';
    } on KeyHeld {
      // nothing goes to a key waiting on a check
    } on StartingAfresh {
      // nor on a session a restore brought back
    } on NotSettled {
      // nor as the opener of a session
    } catch (e) {
      dlog('typing: not sent (${e.runtimeType})');
    } finally {
      tried
          ? typing.pacer.done(key, peer: peer, ok: ok)
          : typing.pacer.spent(key);
    }
  }

  /// a typing frame from the onion door, opened under [peer]'s session. it
  /// shows, or it is dropped; either way nothing is written of it but what
  /// it says their phone understands, and that only when it changed
  Future<void> _typingCame(String peer, UnwrappedMessage env) async {
    final epoch = _openedEpoch;
    try {
      final to = _routeOf(peer, env.groupId);
      final db = switch (to) {
        RouteTo.everyday => live,
        RouteTo.vault => _openVault,
        _ => null,
      };
      if (db == null || isDevId(peer)) return;
      final row = await db.getContact(peer);
      if (row == null) return;
      final key = db.container.chatKey(peer);
      final facts = TypingShowFacts(
        viaOnion: true,
        switchOn: typing.on,
        privateRoute: _sendMode == 'private',
        decoy: inDecoyView,
        locked: lockState.locked,
        inFront: _inFront,
        route: to,
        contact: row['accepted'] == 1 && row['back_paired'] == 1,
        blocked: row['blocked'] == 1 || await blockedAnywhere(peer),
        dev: isDevId(peer),
        group: env.groupId != null,
        written: env.writtenAt,
        floor: typing.board.floorOf(key),
        bridges: typingBridged,
        archived: row['archived'] == 1,
      );
      if (facts.contact && !facts.blocked && !facts.group) {
        await _takeCaps(peer, env, db);
      }
      // and again after the reads: a lock that came meanwhile cleared the
      // board already, and nothing sets it again behind the lock
      if (typingMayShow(facts) && _typingStill(epoch)) {
        typing.board.heard(key);
      }
    } catch (e) {
      dlog('typing: not read (${e.runtimeType})');
    }
  }

  /// a message of [peer]'s shown in a 1:1 chat: their typing there ends
  void _typingAnswered(String peer, UnwrappedMessage env) {
    if (env.groupId != null || isDevId(peer)) return;
    if (!AppState._dataFrame(env)) return;
    typing.board.message(typingKey(peer), env.writtenAt);
  }

  /// what a 1:1 frame says of the sender's phone, on an accepted
  /// contact's row in the container that holds the chat
  /// true when their list changed
  Future<bool> _takeCaps(String peer, UnwrappedMessage env, HaloDb db) async {
    if (env.groupId != null || isDevId(peer)) return false;
    try {
      final moved = await db.takeCaps(
        peer,
        caps: env.caps,
        counts: AppState._dataFrame(env) && env.msgUid != null,
        written: env.writtenAt,
      );
      // their phone may take a photo now, or no longer
      if (moved) unawaited(photoSweep());
      return moved;
    } catch (e) {
      dlog('typing: caps not taken (${e.runtimeType})');
      return false;
    }
  }
}
