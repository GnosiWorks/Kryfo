// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the developer chat

part of '../main.dart';

extension AppStateDevchat on AppState {
  String get myXPub => _myXPub;
  set myXPub(String x) {
    _myXPub = x;
    _devIdentity = devModeOf(x);
  }

  // developer mode: his own phone, never in a decoy session
  bool get devMode => _devIdentity && !sessionQuiet;

  // asked by every way a message leaves the dev chat, before anything of it
  // is saved: fresh becomes everyday, or anon under a name made for this
  // chat alone. his card is checked and his session built first, then the
  // chat's rows, then its lane is listened to; the message goes out the
  // usual way after it. a key that does not check out throws
  // DevKeyCheckFailed, any other failure throws too, and neither leaves
  // anything of the start behind. a chat already started stays as it is
  Future<DevStart> devBegin({required bool anon}) {
    final out = _devStarting.then((_) => _devBegin(anon: anon));
    // the caller gets any error from out; the chain only keeps the order
    _devStarting = out.then((_) {}, onError: (_) {});
    return out;
  }

  Future<DevStart> _devBegin({required bool anon}) async {
    final s = session;
    final quiet = s.container.quiet;
    // the developer does not write to himself
    if (!quiet && devModeOf(myXPub)) return DevStart.none;
    final r = await s.devChat.load();
    if (r == null || r.state == DevState.gone) return DevStart.none;
    if (r.started) return DevStart.ok;
    final key = currentDevKey;
    if (key == null) return DevStart.none;
    // his card as pinned, checked the same way in every container
    if (!devCardChecks(key)) throw const DevKeyCheckFailed();
    final made = anon ? _devMadeName() : null;
    if (quiet) {
      // a decoy keeps its chat on this phone: no store, no lane, nothing
      // listened to, and what is written there stays parked
      if (!await s.devChat.begin(key, anon: made?.$1)) {
        throw StateError('dev chat: the row did not start');
      }
    } else if (made == null) {
      await _devBeginEveryday(s, key);
    } else {
      await _devBeginAnon(s, key, made.$1, made.$2);
    }
    await refreshContacts();
    if (!quiet) await subscribeDevLane();
    return DevStart.ok;
  }

  // three words: his session in the everyday store, then the chat's rows
  Future<void> _devBeginEveryday(Session s, DevKey key) async {
    final ss = signalSession;
    if (!ss.ready) throw StateError('dev chat: the store is not ready');
    await _devSession(ss, key);
    try {
      if (!await s.devChat.begin(key)) {
        throw StateError('dev chat: the row did not start');
      }
    } catch (_) {
      await _dropDevSession(ss, key.chatId);
      rethrow;
    }
  }

  // anonymous: a store of its own under the made name, in the everyday
  // database beside the chat's row. emptied before, and again if the start
  // fails, so no half made name stays
  Future<void> _devBeginAnon(
    Session s,
    DevKey key,
    DevAnon name,
    DevSelf self,
  ) async {
    final db = await live.open();
    await clearDevStore(db);
    try {
      final ss = SignalSession();
      final priv = _hexDecode(name.xPriv);
      try {
        await ss.bootstrapInitiator(
          database: db,
          xPubBytes: _hexDecode(self.xPub),
          xPrivBytes: priv,
          prefix: kDevSignalPrefix,
        );
      } finally {
        // the store keeps a copy of its own
        _zeroBytes(priv);
      }
      await _devSession(ss, key);
      if (!await s.devChat.begin(key, anon: name)) {
        throw StateError('dev chat: the row did not start');
      }
    } catch (_) {
      await clearDevStore(db);
      rethrow;
    }
  }

  // his card into [ss], then the key it holds for him read back: the
  // pinned one, byte for byte. a card libsignal refuses, or any other key,
  // is a key that did not check out, and no session of it stays
  Future<void> _devSession(SignalSession ss, DevKey key) async {
    final addr = SignalProtocolAddress(key.chatId, 1);
    var ok = false;
    try {
      await processPeerBundle(key.chatId, key.bundle, into: ss);
      final held = await ss.identityStore.getIdentity(addr);
      ok =
          held != null &&
          _eqBytes(held.serialize(), pinnedIdentity(key)) &&
          await ss.sessionStore.containsSession(addr);
    } on UntrustedIdentityException {
      ok = false;
    } on InvalidKeyException {
      ok = false;
    } catch (_) {
      await _dropDevSession(ss, key.chatId);
      rethrow;
    }
    if (!ok) {
      await _dropDevSession(ss, key.chatId);
      throw const DevKeyCheckFailed();
    }
  }

  Future<void> _dropDevSession(SignalSession ss, String id) async {
    final addr = SignalProtocolAddress(id, 1);
    try {
      await ss.sessionStore.deleteSession(addr);
      await ss.identityStore.removePeerIdentity(addr);
    } catch (e) {
      dlog('dev chat: the session did not clear ($e)');
    }
  }

  // the name an anonymous chat writes under: made by the engine for this
  // chat alone, read back from its own keys, and sharing nothing with the
  // everyday identity or the session's
  (DevAnon, DevSelf) _devMadeName() {
    // pure: touches no engine state and logs nothing
    final q = engine.quietIdentity();
    final id = q?['id'], ed = q?['ed_priv'], x = q?['x_priv'];
    final edPub = q?['ed_pub'], xPub = q?['x_pub'];
    if (id is! String ||
        ed is! String ||
        x is! String ||
        edPub is! String ||
        xPub is! String) {
      throw StateError('dev chat: no name was made');
    }
    final self = DevSelf.ofKeys(id, ed, x);
    if (self == null ||
        self.edPub != edPub.toLowerCase() ||
        self.xPub != xPub.toLowerCase()) {
      throw StateError('dev chat: the made name does not read');
    }
    final mine = {
      myId,
      sessionId,
      for (final k in [_io.edPub(), _io.xPub(), sessionEdPub, sessionXPub])
        k.toLowerCase(),
    }..remove('');
    if (mine.contains(self.id) ||
        mine.contains(self.edPub) ||
        mine.contains(self.xPub)) {
      throw StateError('dev chat: the made name is not new');
    }
    return (DevAnon(id: id, edPriv: ed, xPriv: x), self);
  }

  // ---- the dev chat on the wire ----

  // its own lane, once it has started and while it can hear: his key's
  // pair lane with three words, the made name's room lane when anonymous
  // (the gate turns the listen into the room export). the everyday
  // container's chat only, never before its first send or after a delete
  @visibleForTesting
  Future<void> subscribeDevLane() async {
    final DevChatRow? r;
    try {
      r = await live.devChat.load();
    } catch (e) {
      dlog('dev lane: the chat did not read ($e)');
      return;
    }
    final k = r?.key;
    if (r == null ||
        !r.started ||
        r.nameless ||
        k == null ||
        k.status == DevKeyStatus.retired) {
      return;
    }
    _io.listen(k.xPub);
  }

  // a line on one of his lanes. taken only by the everyday chat running on
  // that lane, opened in its own store; anything else, and anything outside
  // signal, is dropped and marked seen. true when it shows
  Future<bool> _receiveDev(
    String tag,
    String cipher,
    String h,
    int epoch,
    Reached? reached,
  ) async {
    final DevChatRow? r;
    try {
      r = await live.devChat.load();
    } catch (e) {
      // not kept: the engine offers it again
      dlog('dev lane: the chat did not read ($e)');
      rethrow;
    }
    final id = r?.chatId;
    if (id == null || !devLaneTakes(r, tag) || cipher.startsWith('{')) {
      dlog('dev lane: a line not taken');
      await live.markSeen(h);
      return false;
    }
    // opened on a try that did not get as far as kept: signal will not
    // open it again
    final before = _relayOpened[h];
    final plain = before != null && before.id == id
        ? before.plain
        : await _io.decrypt(id, cipher, flagKeyChange: true);
    if (plain == null) {
      _strikeUndecryptable(h, 'dev lane');
      return false;
    }
    _keepOpened(h, id, plain, epoch);
    final RouteTo went;
    try {
      went = await _applyIncomingPayload(
        id,
        unwrapMessage(plain),
        wire: plain,
        reached: reached,
      );
    } on CapHeld catch (e) {
      // kept as opened, let in on accept
      await _hold(
        e is _HeldIn ? e.into : live,
        id,
        plain,
        unwrapMessage(plain),
      );
      await live.markSeen(h);
      _relayOpened.take(h);
      return false;
    }
    await live.markSeen(h);
    _relayOpened.take(h);
    return AppState._shown(went);
  }

  // deleted means gone: every row of it in the session's container. for
  // the everyday chat the wire lets go too: the seal forgets its store and
  // ciphers, the made name's room lane is dropped and his key maps to no
  // chat. his pair lane stays open until the app restarts, and what comes
  // on it is dropped. a decoy's delete leaves the everyday chat running
  //
  // with [takeBack], what was sent there is taken back from his phone too:
  // each take-back is sealed before the wipe, under the name it was sent
  // with, and goes after it, so a kill midway still leaves nothing here.
  // how many could not be taken back
  Future<int> devDelete({bool takeBack = false}) async {
    final d = devDeleteSteps(takeBack: takeBack);
    await d.wiped;
    return d.missed;
  }

  /// the delete in its two steps: [wiped] once the rows are gone, an error
  /// when they would not go, and [missed] once the take-backs have ended.
  /// another delete before the wipe is this one, after it a new one
  ({Future<void> wiped, Future<int> missed}) devDeleteSteps({
    bool takeBack = false,
  }) {
    final s = session;
    // a decoy's chat is its own: it never waits on the everyday one's
    if (s.container.quiet) {
      final w = s.devChat.delete();
      return (wiped: w, missed: w.then((_) => 0, onError: (_) => 0));
    }
    final going = _devWipe;
    if (going != null) return going;
    final wiped = Completer<void>();
    final missed = Completer<int>();
    final steps = (wiped: wiped.future, missed: missed.future);
    wiped.future.ignore();
    _devWipe = steps;
    devGoing = wiped.future.then((_) {}, onError: (_) {});
    void gone([Object? e]) {
      if (identical(_devWipe, steps)) {
        _devWipe = null;
        devGoing = null;
      }
      if (wiped.isCompleted) return;
      e == null ? wiped.complete() : wiped.completeError(e);
    }

    unawaited(
      _devDelete(s, takeBack, gone).then(
        missed.complete,
        onError: (Object e) {
          dlog('dev delete: ${e.runtimeType}');
          gone(e);
          missed.complete(0);
        },
      ),
    );
    return steps;
  }

  Future<int> _devDelete(
    Session s,
    bool takeBack,
    void Function([Object? e]) gone,
  ) async {
    DevChatRow? was;
    try {
      was = await live.devChat.load();
    } catch (e) {
      dlog('dev delete: the chat did not read ($e)');
    }
    final back = takeBack ? await _sealTakeBacks(was) : null;
    try {
      await s.devChat.delete();
    } catch (_) {
      // kept: nothing of it goes, its take-backs neither
      for (final c in back?.ciphers ?? const <String>[]) {
        devGate.parted(c);
      }
      rethrow;
    }
    devLane.forget();
    _xPubToHaloId.removeWhere((_, id) => isDevId(id));
    final self = DevSelf.ofKeys(was?.anonId, was?.anonEdPriv, was?.anonXPriv);
    if (self != null) engine.roomUnsubscribeBg(self.xPub);
    gone();
    if (back == null) return 0;
    final missed = await _sendTakeBacks(back);
    // sending as the made name opened its lane again: it goes with them
    if (self != null) engine.roomUnsubscribeBg(self.xPub);
    return missed;
  }

  // the most a delete seals: what goes in half a minute, and some
  static const _kTakeBackMost = 200;

  // a take-back sealed for each message this phone sent in the dev chat,
  // under the name it went with, and where they go. none for a chat that
  // never sent, only reads or talks to a retired key
  Future<_TakeBacks?> _sealTakeBacks(DevChatRow? was) async {
    final chat = was?.chatId;
    if (was == null ||
        chat == null ||
        !was.started ||
        was.nameless ||
        (was.key?.status ?? DevKeyStatus.retired) == DevKeyStatus.retired) {
      return null;
    }
    final List<String> uids;
    try {
      uids = await live.devChat.sentUids();
    } catch (e) {
      // the wipe reads the same file: it says what went wrong
      dlog('dev delete: what was sent did not read (${e.runtimeType})');
      return null;
    }
    if (uids.isEmpty) return null;
    // the gate holds only what it needs of the chat, no more of its keys
    final held = DevChatRow(
      state: was.state,
      keyId: was.keyId,
      anonXPriv: was.anonXPriv,
      createdAt: was.createdAt,
    );
    final to = await _reach(chat);
    final ciphers = <String>[];
    // newest first: past the most, the oldest are counted as missed
    var failed = to == null
        ? uids.length
        : max(0, uids.length - _kTakeBackMost);
    for (final uid
        in to == null ? const <String>[] : uids.take(_kTakeBackMost)) {
      try {
        final c = await _io.encrypt(
          chat,
          await wrapMessage('', unsend: uid, sender: _mySender()),
        );
        devGate.part(c, held);
        ciphers.add(c);
      } catch (e) {
        dlog('dev delete: a take-back did not seal (${e.runtimeType})');
        failed++;
      }
    }
    return (
      xPub: to?.xpub ?? '',
      fc: to == null || to.backPaired ? null : peerFcFor(chat),
      backPaired: to?.backPaired ?? false,
      ciphers: ciphers,
      failed: failed,
    );
  }

  // the sealed take-backs, a few at a time for half a minute at most. the
  // gate lets them go until then and forgets them after. how many did not
  // get through
  Future<int> _sendTakeBacks(_TakeBacks t) async {
    final left = {...t.ciphers};
    var next = 0;
    var stop = false;
    // as the chat's own send goes: his first-contact address until he is
    // added back, the pair lane after
    Future<bool> one(String c) async {
      final fc = t.fc;
      if (fc != null && fc.isNotEmpty) {
        return await _io.firstContactSend(t.xPub, fc, c) == 'ok';
      }
      return await _io.relaySend(t.xPub, c) == 'ok' && t.backPaired;
    }

    Future<void> lane() async {
      while (!stop && next < t.ciphers.length) {
        final c = t.ciphers[next++];
        try {
          if (await one(c)) left.remove(c);
        } catch (e) {
          dlog('dev delete: a take-back did not go (${e.runtimeType})');
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < 4; i++) lane(),
    ]).timeout(devTakeBackFor, onTimeout: () => const []);
    stop = true;
    for (final c in t.ciphers) {
      devGate.parted(c);
    }
    return left.length + t.failed;
  }
}
