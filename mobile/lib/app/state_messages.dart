// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: edits, pins, reactions and unsends in a 1:1 chat

part of '../main.dart';

extension AppStateMessages on AppState {
  // a row of ours a block kept from going: what is queued for it waits for
  // the tap. a read that fails says held, and the next pass reads again
  Future<bool> _heldRow(HaloDb d, String uid) async {
    try {
      return await d.heldBack(uid);
    } catch (e) {
      dlog('held row: not read (${e.runtimeType})');
      return true;
    }
  }

  // blockedAnywhere read once a person in one pass of a queue
  Future<bool> Function(String id) _blockedInPass() {
    final read = <String, Future<bool>>{};
    return (id) => read[id] ??= blockedAnywhere(id);
  }

  Future<void> _drainEdits() async {
    if (everydayHeld) return;
    final blocked = _blockedInPass();
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      final Set<String> held;
      try {
        held = await _heldOf(d);
        rows = await d.unsentEdits(skip: held);
      } catch (e) {
        // the vault closed part way: its edits wait for the next open
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        // someone blocked here or in the other container: it goes, unsent
        if (await blocked(r['peer_id'] as String)) {
          try {
            await d.dropEdit(uid);
          } catch (e) {
            dlog('edit: blocked row not dropped (${e.runtimeType})');
          }
          continue;
        }
        if (age < 45000 || _editsInflight.contains(uid)) continue;
        if (held.contains(r['peer_id'])) continue;
        // its row a block kept from going: the edit waits for the tap
        if (await _heldRow(d, uid)) continue;
        if (everydayHeld) return;
        // stamped before it goes: a send cut short is a try too
        try {
          await d.triedEdit(
            uid,
            r['new_text'] as String,
            (r['tries'] as int?) ?? 0,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          continue;
        }
        _editGo(
          r['peer_id'] as String,
          uid,
          r['new_text'] as String,
          on: d,
          writtenAt: r['at'] as int,
        );
      }
    }
  }

  // one edit send per message at a time, so an older wording can never
  // land after a newer one
  void _editGo(
    String peer,
    String uid,
    String newText, {
    HaloDb? on,
    int? writtenAt,
  }) {
    if (!_editsInflight.add(uid)) {
      _editAgain.add(uid);
      return;
    }
    unawaited(
      sendEdit(peer, uid, newText, on: on, writtenAt: writtenAt).whenComplete(
        () async {
          _editsInflight.remove(uid);
          if (!_editAgain.remove(uid) || everydayHeld) return;
          try {
            final d = on ?? _ownerOf(peer);
            final q = await d.queuedEdit(uid);
            if (q == null || q['new_text'] == newText) return;
            if (await blockedAnywhere(peer) || await _heldRow(d, uid)) return;
            _editGo(
              peer,
              uid,
              q['new_text'] as String,
              on: d,
              writtenAt: q['at'] as int,
            );
          } catch (e) {
            dlog('edit: next one waits (${e.runtimeType})');
          }
        },
      ),
    );
  }

  Future<void> _drainPins() async {
    if (everydayHeld) return;
    final blocked = _blockedInPass();
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      final Set<String> held;
      try {
        held = await _heldOf(d);
        rows = await d.unsentPins(skip: held);
      } catch (e) {
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        if (await blocked(r['peer_id'] as String)) {
          try {
            await d.dropPin(uid, (r['pinned'] as int) == 1);
          } catch (e) {
            dlog('pin: blocked row not dropped (${e.runtimeType})');
          }
          continue;
        }
        if (age < 45000 || _pinsInflight.contains(uid)) continue;
        if (held.contains(r['peer_id'])) continue;
        if (await _heldRow(d, uid)) continue;
        if (everydayHeld) return;
        if (!_pinsInflight.add(uid)) continue;
        try {
          await d.triedPin(
            uid,
            (r['pinned'] as int) == 1,
            (r['tries'] as int?) ?? 0,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          _pinsInflight.remove(uid);
          continue;
        }
        unawaited(
          _sendPin(
            r['peer_id'] as String,
            uid,
            (r['pinned'] as int) == 1,
            on: d,
            writtenAt: r['at'] as int,
          ).whenComplete(() => _pinsInflight.remove(uid)),
        );
      }
    }
  }

  // pin or unpin in a 1:1 chat, for both of us. ours is written first; the
  // frame queues like an edit does, so it survives tor being down.
  Future<void> pinInChat(String peer, String uid, bool pinned) async {
    await session.setPinned(uid, pinned);
    // someone blocked is told nothing: it stays ours alone
    if (await blockedAnywhere(peer)) {
      notifyListeners();
      return;
    }
    await session.queuePin(uid, peer, pinned);
    notifyListeners();
    // a quiet session keeps it queued here: nothing leaves. on a row a
    // block kept from going it waits for the tap
    if (everydayHeld || await session.heldBack(uid)) return;
    _pinsInflight.add(uid);
    unawaited(
      _sendPin(peer, uid, pinned).whenComplete(() => _pinsInflight.remove(uid)),
    );
  }

  Future<bool> _sendPin(
    String peer,
    String uid,
    bool pinned, {
    HaloDb? on,
    // a queued one: when it was queued
    int? writtenAt,
  }) async {
    try {
      final wrapped = await wrapMessage(
        '',
        pin: PinFrame(targetUid: uid, pinned: pinned),
        sender: _mySender(),
        writtenAt: writtenAt,
      );
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) await (on ?? _ownerOf(peer)).dropPin(uid, pinned);
      return ok;
    } catch (e) {
      dlog('pin: $uid still stuck ($e)');
      return false;
    }
  }

  Future<void> _drainFrames() async {
    if (everydayHeld) return;
    final blocked = _blockedInPass();
    for (final d in [live, ?_openVault]) {
      final List<Map<String, Object?>> rows;
      final Set<String> held;
      try {
        held = await _heldOf(d);
        // what waits on a card or a check is left out, or it would fill
        // the window
        rows = await d.unsentFrames(waiting: {..._waitingCard, ...held});
      } catch (e) {
        continue;
      }
      for (final r in rows) {
        final uid = r['msg_uid'] as String;
        final kind = r['kind'] as String;
        final peer = r['peer_id'] as String;
        // nothing goes to someone blocked, here or in the other container:
        // what was queued for them goes. a take-back only withdraws, and
        // still goes
        if (kind != kFrameUnsend && await blocked(peer)) {
          try {
            await d.dropFrame(uid, kind, peer, r['body'] as String);
          } catch (e) {
            dlog('$kind: blocked row not dropped (${e.runtimeType})');
          }
          continue;
        }
        final age = DateTime.now().millisecondsSinceEpoch - (r['at'] as int);
        // a receipt has no send of its own still going: it waits only on
        // the card the session waits on
        if (kind == kFrameReceipt ? _waitingCard.contains(peer) : age < 45000) {
          continue;
        }
        if (held.contains(peer)) continue;
        if (kind == kFrameReaction && await _heldRow(d, uid)) continue;
        if (everydayHeld) return;
        if (!_framesInflight.add('$kind $uid')) continue;
        // stamped before it goes: its next turn waits its gap, on disk
        try {
          await d.triedFrame(
            uid,
            kind,
            peer,
            r['body'] as String,
            (r['tries'] as int?) ?? 0,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          _framesInflight.remove('$kind $uid');
          continue;
        }
        unawaited(
          _sendFrame(
            peer,
            uid,
            kind,
            r['body'] as String,
            on: d,
            writtenAt: r['at'] as int,
          ).whenComplete(() => _framesInflight.remove('$kind $uid')),
        );
      }
    }
  }

  // take a message back in a 1:1 chat. queued first, so one taken back
  // offline still reaches them
  Future<void> unsendInChat(String peer, String uid) async {
    await session.queueUnsend(uid, peer);
    await _frameNow(peer, uid, kFrameUnsend, '');
  }

  // an edit in a 1:1 chat, once the row here has it. queued first, sent
  // now: if the route is down the outbox carries it. none for someone
  // blocked: it stays here alone. on a row a block kept from going it is
  // queued and waits for the tap: the row may be on a relay already
  Future<void> editInChat(String peer, String uid, String newText) async {
    if (await blockedAnywhere(peer)) return;
    await session.queueEdit(uid, peer, newText);
    // a quiet session keeps it queued here: nothing leaves
    if (everydayHeld || await session.heldBack(uid)) return;
    _editGo(peer, uid, newText);
  }

  // a reaction in a 1:1 chat, empty to take it off. queued like a pin.
  // none for someone blocked. on a row a block kept from going it waits
  // for the tap, as an edit does
  Future<void> reactInChat(String peer, String uid, String emoji) async {
    if (await blockedAnywhere(peer)) return;
    await session.queueReaction(uid, peer, emoji);
    if (await session.heldBack(uid)) return;
    await _frameNow(peer, uid, kFrameReaction, emoji);
  }

  Future<void> _frameNow(
    String peer,
    String uid,
    String kind,
    String body,
  ) async {
    // a quiet session keeps it queued here: nothing leaves
    if (everydayHeld) return;
    if (!_framesInflight.add('$kind $uid')) return;
    unawaited(
      _sendFrame(
        peer,
        uid,
        kind,
        body,
      ).whenComplete(() => _framesInflight.remove('$kind $uid')),
    );
  }

  Future<bool> _sendFrame(
    String peer,
    String uid,
    String kind,
    String body, {
    HaloDb? on,
    // a queued one: when it was queued
    int? writtenAt,
  }) async {
    try {
      final wrapped = switch (kind) {
        kFrameUnsend => await wrapMessage(
          '',
          unsend: uid,
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
        kFrameReceipt => await wrapMessage(
          '',
          deliveredUid: uid,
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
        // nothing but the block, which the seal puts on
        kFrameShots => await wrapMessage(
          '',
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
        _ => await wrapMessage(
          '',
          reaction: ReactionFrame(targetUid: uid, emoji: body),
          sender: _mySender(),
          writtenAt: writtenAt,
        ),
      };
      final ok = await _sendOneEnvelope(
        peer,
        wrapped,
        takeBack: kind == kFrameUnsend,
      );
      if (ok) await (on ?? _ownerOf(peer)).dropFrame(uid, kind, peer, body);
      return ok;
    } catch (e) {
      dlog('$kind: $uid still stuck ($e)');
      return false;
    }
  }

  // the edit frame, through the same routes a message takes. true when a
  // route that reaches them took it; the queued row goes with it.
  // on is the container its queued row is in, the chat's when not given
  Future<bool> sendEdit(
    String peer,
    String uid,
    String newText, {
    HaloDb? on,
    // a queued one: when the edit was made, not when the message was
    int? writtenAt,
  }) async {
    try {
      final wrapped = await wrapMessage(
        '',
        edit: EditFrame(targetUid: uid, newText: newText),
        sender: _mySender(),
        writtenAt: writtenAt,
      );
      final ok = await _sendOneEnvelope(peer, wrapped);
      if (ok) await (on ?? _ownerOf(peer)).dropEdit(uid, newText: newText);
      return ok;
    } catch (e) {
      dlog('edit: $uid still stuck ($e)');
      return false;
    }
  }

  int chatRevOf(String haloId) => _chatRev[haloId] ?? 0;
  void _bumpChatRev(String haloId) {
    _chatRev[haloId] = (_chatRev[haloId] ?? 0) + 1;
  }

  // a chat's rows changed from outside it: an upload that a screen since
  // closed started, finishing. whichever screen shows the chat now re-reads.
  void chatChanged(String haloId) {
    _bumpChatRev(haloId);
    notifyListeners();
  }
}
