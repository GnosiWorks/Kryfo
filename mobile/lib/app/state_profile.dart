// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the handle, the avatar and the first contact address

part of '../main.dart';

extension AppStateProfile on AppState {
  String? get myHandle => sessionQuiet ? null : _myHandle;
  int? get myAvatar => sessionQuiet ? _quietAvatar : _myAvatar;

  Future<void> loadMyAvatar() async {
    final v = await secureStore.read(key: 'my_avatar');
    _myAvatar = v == null ? null : int.tryParse(v);
    notifyListeners();
  }

  Future<void> setMyAvatar(int? v) async {
    sessionQuiet ? _quietAvatar = v : _myAvatar = v;
    final st = secureStore;
    final k = session.container.key('my_avatar');
    if (v == null) {
      await st.delete(key: k);
    } else {
      await st.write(key: k, value: '$v');
    }
    notifyListeners();
  }

  Future<void> loadMyHandle() async {
    const st = secureStore;
    _myHandle = await st.read(key: 'my_handle');
    _handleListed = (await st.read(key: 'my_handle_listed')) == '1';
    _handleName = await st.read(key: 'my_handle_name') ?? '';
    notifyListeners();
  }

  bool get handleListed => !sessionQuiet && _handleListed;
  String get handleName => sessionQuiet ? '' : _handleName;

  Future<String> setHandleListing(bool on, {String name = ''}) async {
    final h = _myHandle;
    if (h == null || sessionQuiet) return 'error: no handle';
    final n = on ? name.trim() : '';
    final r = await engine.handleListing(h, on, n);
    if (r != 'ok') return r;
    _handleListed = on;
    _handleName = n;
    const st = secureStore;
    await st.write(key: 'my_handle_listed', value: on ? '1' : '0');
    await st.write(key: 'my_handle_name', value: n);
    notifyListeners();
    return r;
  }

  // the registry is reached over tor on every route: tor stopped between
  // check-ins, or still starting, is waited for (_noteTorStatus arms it)
  bool get _torCarries =>
      !_torHeld &&
      (_torStatus == TorStatus.bootstrapped ||
          _torStatus == TorStatus.publishing ||
          _torStatus == TorStatus.reachable);
  void _maybeRepoint() {
    if (_myHandle == null || myOnion.isEmpty || !_fcLoaded) return;
    if (!_repoint.want(torUp: _torCarries)) return;
    _repoint.going();
    _repointTimer?.cancel();
    _repointTimer = Timer(
      repointDelay(Random.secure()),
      () => unawaited(_repointHandle()),
    );
  }

  // a try that got no answer goes again later, never taken as done
  void _repointLater(String? r) {
    final wait = _repoint.settled(r);
    if (wait == null) return;
    _repointTimer?.cancel();
    _repointTimer = Timer(wait, _maybeRepoint);
  }

  @visibleForTesting
  set handleRepointForTest(HandleRepoint r) => _handleRepoint = r;

  // [invite] is the one the registry just took for [h]
  Future<void> setMyHandle(String? h, {String bio = '', String? invite}) async {
    _myHandle = h;
    _handleForeign = false;
    final st = secureStore;
    if (h == null) {
      await _handleRepoint.forget();
      await st.delete(key: 'my_handle');
      await st.delete(key: 'my_handle_bio');
      // a released handle is gone from search with the rest of it
      await st.delete(key: 'my_handle_listed');
      await st.delete(key: 'my_handle_name');
      _handleListed = false;
      _handleName = '';
    } else {
      await st.write(key: 'my_handle', value: h);
      // kept so a republish carries the same bio rather than a blank one
      await st.write(key: 'my_handle_bio', value: bio);
      if (invite != null) await _handleRepoint.claimed(h, invite);
    }
    // a new handle is put to the registry as any changed invite is, the
    // same after a restore
    _repointTimer?.cancel();
    _repoint.reset();
    _maybeRepoint();
    notifyListeners();
  }

  int get fcCounter => _fcCounter;

  @visibleForTesting
  Future<void> loadFirstContact() => _loadFirstContact();

  Future<void> _loadFirstContact() async {
    const st = secureStore;
    _fcCounterTimer?.cancel();
    _fcCounterTimer = null;
    // a counter that does not read leaves the invite address unheard, never
    // moved or taken as 0, and is read again a while later
    // the list of who read our pair address never holds up the listener
    try {
      await _loadPairSeen();
    } catch (e) {
      dlog('pair read: not loaded (${e.runtimeType})');
    }
    try {
      _fcCounter = int.tryParse(await readFcCounter() ?? '') ?? 0;
    } catch (e) {
      _fcUnread = true;
      firstFails.note('counter');
      dlog('first contact: counter unreadable (${e.runtimeType})');
      _fcCounterTimer = Timer(fcCounterGap(_fcCounterTries++), () {
        _fcCounterTimer = null;
        unawaited(_loadFirstContact());
      });
      return;
    }
    _fcUnread = false;
    _fcCounterTries = 0;
    if (_fcLoaded) return;
    try {
      final raw = await st.read(key: 'peer_fc');
      if (raw != null && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          _peerFc[k] = v as String;
        });
      }
    } catch (e) {
      _peerFcUnread = true;
      dlog('peer fc map unreadable, kept as it is: ${e.runtimeType}');
    }
    await _sweepPeerFc();
    _fcLoaded = true;
    await _listenFirstContact();
    _maybeRepoint();
    notifyListeners();
  }

  // once: a first-contact address kept for someone who has added us back, or
  // who came on a card, is let go. the first is spent, the second second
  // hand, and neither may be handed on in a card
  Future<void> _sweepPeerFc() async {
    if (_peerFcUnread || _peerFc.isEmpty) return;
    const st = secureStore;
    try {
      if (await st.read(key: 'peer_fc_swept') == '1') return;
      final drop = <String>[];
      for (final id in _peerFc.keys) {
        if (isDevId(id)) continue;
        final d = _ownerOf(id);
        if (await d.isBackPaired(id) || await d.isVouched(id)) drop.add(id);
      }
      for (final id in drop) {
        _peerFc.remove(id);
      }
      if (drop.isNotEmpty) {
        await st.write(key: 'peer_fc', value: jsonEncode(_peerFc));
      }
      await st.write(key: 'peer_fc_swept', value: '1');
    } catch (e) {
      dlog('peer fc: not swept (${e.runtimeType})');
    }
  }

  // listen on the invite's first-contact address. an answer other than ok
  // is tried again, a while later each time
  Future<void> _listenFirstContact() async {
    _fcListenTimer?.cancel();
    _fcListenTimer = null;
    String r;
    try {
      r = await engine.subscribeFirstContact(kMainIdent, _fcCounter);
    } catch (e) {
      r = 'error: ${e.runtimeType}';
    }
    if (r == 'ok') {
      _fcListenTries = 0;
      return;
    }
    firstFails.note('listen');
    dlog('first contact: not listened on ($r)');
    _fcListenTimer?.cancel();
    _fcListenTimer = Timer(fcListenGap(_fcListenTries++), () {
      _fcListenTimer = null;
      unawaited(_listenFirstContact());
    });
  }

  // a cheap look that the first-contact listener is on a relay at all: one
  // that started on an empty list, or lost every relay, starts again
  @visibleForTesting
  void checkFirstListener() {
    // a quiet session starts nothing of the everyday side's
    if (sessionQuiet) return;
    if (!_fcLoaded) {
      if (_fcUnread && _fcCounterTimer == null) unawaited(_loadFirstContact());
      return;
    }
    if (_fcListenTimer != null) return;
    final int n;
    try {
      n = engine.firstContactRelays();
    } catch (_) {
      return;
    }
    if (n > 0) return;
    firstFails.note('deaf');
    dlog('first contact: listener on no relay ($n), listening again');
    unawaited(_listenFirstContact());
  }

  // the dev chat's is his pinned one, never a remembered one: the gate says
  // whether it is reached
  String? peerFcFor(String haloId) {
    if (!isDevId(haloId)) return _peerFc[haloId];
    for (final k in devKeys) {
      if (k.chatId == haloId) return k.fc;
    }
    return null;
  }

  Future<void> rememberPeerFc(String haloId, String fcPk) async {
    // the dev chat's address is pinned, and no one else is given his
    if (devCardClaim(id: haloId, fc: fcPk)) return;
    _peerFc[haloId] = fcPk;
    if (_peerFcUnread) return;
    await secureStore.write(key: 'peer_fc', value: jsonEncode(_peerFc));
  }

  Future<void> forgetPeerFc(String haloId) async {
    await _forgetPairSeen({haloId});
    if (_peerFc.remove(haloId) == null || _peerFcUnread) return;
    await secureStore.write(key: 'peer_fc', value: jsonEncode(_peerFc));
  }

  bool get handleForeign => !sessionQuiet && _handleForeign;

  void _setHandleForeign(bool foreign) {
    if (foreign == _handleForeign) return;
    _handleForeign = foreign;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> repointForTest() => _repointHandle();

  Future<void> _repointHandle() async {
    final before = _repointRun;
    final run = _repointRun = () async {
      if (before != null) {
        await before;
        await Future.delayed(repointApart);
      }
      await _repointHandleNow();
    }();
    try {
      await run;
    } finally {
      if (identical(_repointRun, run)) _repointRun = null;
    }
  }

  /// lets the registry have [h] back, in turn with any claim of it already
  /// on its way, so that claim cannot land after the release
  Future<String> releaseHandle(String h) async {
    _repointTimer?.cancel();
    final before = _repointRun;
    var r = 'error: not sent';
    final run = _repointRun = () async {
      if (before != null) {
        await before;
        await Future.delayed(repointApart);
      }
      r = await engine.handleRelease(h);
      if (r == 'ok' && _myHandle == h) await setMyHandle(null);
    }();
    try {
      await run;
    } finally {
      if (identical(_repointRun, run)) _repointRun = null;
    }
    return r;
  }

  /// a wipe has begun: no repoint goes after it, whatever was armed
  void stopRepoint() {
    _repointTimer?.cancel();
    _myHandle = null;
  }

  // nothing is sent while the invite is the one the registry last took
  Future<void> _repointHandleNow() async {
    if (haloWiping) return;
    final h = _myHandle;
    if (h == null || myOnion.isEmpty) {
      _repoint.putBack();
      return;
    }
    // a decoy open, or tor gone back to sleep: armed again once it is
    // left, or once tor is up
    if (everydayHeld || !_torCarries) {
      _repoint.putBack();
      return;
    }
    try {
      final r = await _handleRepoint.repoint(
        h,
        still: () => _myHandle == h && !haloWiping,
      );
      if (r != null) _setHandleForeign(r.contains('taken'));
      _repointLater(r);
    } catch (e) {
      // offline, or the registry is down. the handle stays claimed and
      // stale rather than lost, and a later try fixes it
      _repointLater('error: ${e.runtimeType}');
    }
  }

  // asked by the handle screen when it opens on a claimed handle: a read of
  // whose it is, and a claim only when the registry holds something else
  Future<void> checkHandle() async {
    final h = _myHandle;
    if (h == null || myOnion.isEmpty) return;
    try {
      switch (await _handleRepoint.check(h)) {
        case HandleAtRegistry.foreign:
          _setHandleForeign(true);
        case HandleAtRegistry.mine:
          _setHandleForeign(false);
        default:
      }
    } catch (_) {
      // no answer: the card keeps what it showed
    }
  }

  Future<void> resetInviteAddress() async {
    // a quiet session makes its own invite again, as the everyday one
    // does, and touches nothing of the everyday side's
    if (sessionQuiet) {
      await _resetDecoyInvite();
      notifyListeners();
      return;
    }
    // never on the developer's own phone, whose card every install pins
    if (_devIdentity) return;
    // nothing moves before signal is ready: the v4 link would stay as it was
    await _signalReadyForReset();
    // what was kept goes in now if it can: nothing opens it after this
    await retryFirsts(all: true);
    // the link, qr and handle people hold: the main v4 invite goes now
    await resetMyInvite();
    await _forgetAllFirst();
    // a counter that did not read is never moved past
    if (!_fcUnread) {
      // the v3 card's keys first, while they live: moving only the relay
      // address leaves every old link able to open a session and dial the
      // onion directly
      await signalSession.rotateInvitePreKey();
      _fcCounter++;
      await secureStore.write(key: 'fc_counter', value: '$_fcCounter');
      unawaited(_listenFirstContact());
    }
    // the new invite goes to the registry now, after any claim already on
    // its way and a second apart from it, and again later if this one gets
    // no answer
    _repointTimer?.cancel();
    _repoint
      ..reset()
      ..going();
    await _repointHandle();
    notifyListeners();
  }
}
