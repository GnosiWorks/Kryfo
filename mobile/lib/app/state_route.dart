// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the send mode, tor, the relays and the network

part of '../main.dart';

extension AppStateRoute on AppState {
  String get sendMode => _sendMode;
  String get _engineMode => _engineModeKept ??= _askEngineMode();
  set _engineMode(String m) => _engineModeKept = m;
  String _askEngineMode() {
    try {
      final m = engine.transportMode();
      return const {'private', 'balanced', 'fast'}.contains(m)
          ? routeOf(m)
          : 'private';
    } catch (_) {
      return 'private';
    }
  }

  @visibleForTesting
  set sendModeForTest(String m) {
    _sendMode = _engineMode = m;
    // a switch left waiting by an earlier test never completes
    _modeQueue = Future.value();
  }

  Future<void> loadSendMode() async {
    final stored = await secureStore.read(key: 'send_mode');
    // the old fast mode's marker has nothing left to say
    unawaited(_dropFastMarker());
    // relay and fast are one route now, and whoever was on either is on it
    _sendMode = routeAtBoot(stored);
    if (_sendMode != (stored ?? 'private')) {
      await secureStore.write(key: 'send_mode', value: _sendMode);
    }
    // the card about the merge is due once, for those who were on relay or
    // fast when this version first started
    _routeMergeNote = await secureStore.read(key: kRouteMergeNote);
    if (_routeMergeNote == null) {
      _routeMergeNote = routeMergeNoteAt(stored);
      await secureStore.write(key: kRouteMergeNote, value: _routeMergeNote);
    }
    notifyListeners();
  }

  Future<void> _dropFastMarker() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/fast_ok');
      if (await f.exists()) await f.delete();
    } catch (e) {
      dlog('fast marker: ${e.runtimeType}');
    }
  }

  /// home's one-time card: relay and fast are one now. only while the
  /// route it speaks of is the one in use
  bool get routeMergeCardDue =>
      _routeMergeNote == 'due' && _sendMode == 'balanced' && !inDecoyView;

  Future<void> routeMergeCardSeen() async {
    if (_routeMergeNote == 'done') return;
    _routeMergeNote = 'done';
    notifyListeners();
    await secureStore.write(key: kRouteMergeNote, value: 'done');
  }

  @visibleForTesting
  set routeMergeNoteForTest(String? v) => _routeMergeNote = v;

  // private goes through tor to everything. balanced, shown as fast, talks
  // plain tls to our two servers and nothing else, so only we see an ip.
  // the public relays are its backup while neither of ours answers, and
  // only through tor, so they never do
  static const _clearnetRelay = 'wss://relay.kryfo.app';
  static const _secondRelay = 'wss://relay2.kryfo.app';
  // one list. two copies drift, and the drift is invisible until someone
  // cannot receive on one route.
  static const _publicRelays =
      'wss://nos.lol,wss://relay.primal.net,wss://nostr.mom,'
      'wss://nostr.oxtr.dev';

  // the engine takes the backups after a |
  String relaysFor(String mode) {
    switch (routeOf(mode)) {
      case 'balanced':
        return '$_clearnetRelay,$_secondRelay|$_publicRelays';
      default:
        // our relay's clearnet name rides along, dialled over tor like the
        // rest, since a friend on an older relay mode publishes only there.
        // the second server's onion comes right after the first's
        return 'ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid'
            '.onion,${_privateSecond ? '$_secondOnion,' : ''}'
            '$_clearnetRelay,$_publicRelays';
    }
  }

  // the second server's onion on the private route, its own store as on fast
  static const _privateSecond = true;
  static const _secondOnion =
      'ws://cvwpee5zgbargtxd5wtbtnc6lkbgzxj5byfig3e53ic4t7su7r45n4yd.onion';

  Future<void> setSendMode(String m) {
    m = routeOf(m);
    // a route picked by hand: the card about the merge has nothing to say
    if (_routeMergeNote == 'due') unawaited(routeMergeCardSeen());
    final run = _modeQueue.then((_) => _switchSendMode(m));
    _modeQueue = run.catchError((Object e) => dlog('mode: $e'));
    return run;
  }

  Future<void> _switchSendMode(String m) async {
    // what carried on the old route is not held for the new one
    _usableAt = null;
    // typing goes and shows on the onion route alone
    if (m != 'private') _typingClear();
    // the helper app and google push register over tor or not at all: off the
    // private route the phone checks in instead, and the relay forgets
    if (m != 'private' && knockMode(_deliveryMode)) {
      await setDeliveryMode(DeliveryMode.checkins);
    }
    // saved first: a mode that was not saved is gone at the next start, so
    // a failed save moves nothing and the caller hears of it
    await secureStore.write(key: 'send_mode', value: m);
    // measured against the engine, not the screen: the two only part when
    // something failed half way, and then the engine still has to move
    if (_engineMode == m) {
      if (_sendMode != m) {
        _sendMode = m;
        notifyListeners();
      }
      if (_resubscribeDue) await _moveListeners(m);
      return;
    }
    // an outage seen on another mode is not this one's
    _relayDownSince = null;
    _oursDownHintShown = false;
    _newTorTry();
    // the engine caches one http client per route, so the mode has to land
    // before the relay list is rebuilt or the first connection uses the old
    // one. the list is in place before anything subscribes: each runner
    // copies it once, as it starts
    engine.setTransportMode(m);
    _engineMode = m;
    engine.nostrInit(relaysFor(m));
    // the app follows the engine: nothing reads the new mode while the
    // engine still routes the old way
    _sendMode = m;
    notifyListeners();
    await _moveListeners(m);
  }

  Future<void> _moveListeners(String m) async {
    try {
      await resubscribe();
      _resubscribeDue = false;
      dlog('mode: $m, relays rebuilt');
    } catch (e) {
      _resubscribeDue = true;
      dlog('mode: $m, runners not moved (${e.runtimeType})');
    }
    // the first-contact runner keeps the relay list it started with; it
    // has to follow the switch or strangers' openers go unread
    if (_fcLoaded) unawaited(_listenFirstContact());
  }

  // every key listened on, never the screen's list, on the relays of a new
  // mode: a runner left alone keeps the old mode's relays and route until
  // the app restarts. the dev chat's lane is its own, and only once it has
  // started
  @visibleForTesting
  Future<void> resubscribe() async {
    // rooms first and on their own, as at boot: a runner keeps the relays it
    // started with, and a contact that hangs must not leave a room on the
    // old ones
    try {
      await _listenToRooms();
    } catch (e) {
      dlog('rooms: not listened to again ($e)');
    }
    // whoever boot listens for, then whoever was listened for since: a
    // stranger who back-paired, a card filed in the vault, a chat deleted
    // while its runner lives on. once each, and no block grown old
    await unlistenOldBlocks();
    final done = (await _listenKnown()).keys;
    for (final e in _xPubToHaloId.entries.toList()) {
      if (done.contains(e.key) || isDevId(e.value) || devIdClaim(e.key)) {
        continue;
      }
      _listen(identOf(e.value), e.key);
    }
    await subscribeDevLane();
  }

  TorStatus get torStatus => _torStatus;
  @visibleForTesting
  void setTorStatusForTest(TorStatus s) {
    _torStatus = s;
    notifyListeners();
  }

  @visibleForTesting
  void setRouteOKForTest(bool ok) {
    _routeOK = ok;
    notifyListeners();
  }

  @visibleForTesting
  void setRouteGenForTest(int gen) {
    _routeGen = gen;
    notifyListeners();
  }

  bool get routeOK => _routeOK;
  int get routeGen => _routeGen;

  // called from the status poll. the clock runs while tor is trying and
  // resets the moment it can carry traffic.
  void _noteTorProgress(DateTime now) {
    // the relay rows carry the only live signal: fails counts failures since
    // that relay's last success and is cleared the moment one lands.
    try {
      final tx = engine.transportState();
      _noteRelayHealth(tx['relays'] as List?, now: now);
    } catch (_) {
      // transport not readable yet: nothing to conclude
    }
    // only a climb past the best of this try is progress: a route torn down
    // that climbs back to where it stuck has not moved
    if (_bootstrapPct > _pctBest) {
      _pctBest = _bootstrapPct;
      _pctMovedAt = now;
    }
    if (torReady) {
      _torTryingSince = null;
      _pctBest = -1;
    } else {
      _torTryingSince ??= now;
    }
  }

  void _newTorTry() {
    _torTryNew = true;
    // a peer that could not be reached may be now
    typing.pacer.freshRoute();
  }

  // a route changed on purpose: a try of its own, and nothing the old one
  // carried is held for it. a network handover keeps the grace
  void _newRoute() {
    _newTorTry();
    _usableAt = null;
    _routeOnPurpose = AppState.routeOnPurposePolls;
  }

  // tor torn down and started again on purpose
  void restartTor() {
    engine.restartTor();
    _newRoute();
  }

  // the same, waited on, for the way out a stuck send offers
  Future<String> reconnectNow() {
    _newRoute();
    return engine.reconnectNow().then((r) {
      // turned down: no bounce is coming, the next bump is not this one
      if (r.startsWith('error')) _routeOnPurpose = 0;
      return r;
    });
  }

  // automatic is trying a way in: a long wait is its work, not a dead tor
  bool get autoPassRuns =>
      _bridgeStatus.mode == 'auto' &&
      const {'trying', 'asking'}.contains(_bridgeStatus.phase);

  // what the restart out of sight reads. the engine is asked only out of
  // sight, in always-on, with tor meant to be up and not
  @visibleForTesting
  AutoView autoView() {
    final ready = torReady;
    final always = _deliveryMode == DeliveryMode.always;
    final private = _sendMode == 'private';
    var silent = 0;
    if (!_inFront && always && private && !_torHeld && _online && !ready) {
      silent = (engine.transportState()['ctrl_silent'] as num?)?.toInt() ?? 0;
    }
    return AutoView(
      inFront: _inFront,
      alwaysOn: always,
      private: private,
      quiet: sessionQuiet,
      online: _online,
      held:
          haloWiping ||
          torValve.restartBlocked ||
          lockState.holding ||
          backupRunning ||
          restoreRunning,
      torHeld: _torHeld,
      torReady: ready,
      ctrlSilent: silent,
      passRuns: autoPassRuns,
      stuckSince: ready ? null : (_pctMovedAt ?? _torTryingSince),
    );
  }

  @visibleForTesting
  void backInFront({DateTime? now}) {
    if (_sendMode != 'private' || _torHeld || !_online || sessionQuiet) return;
    // a start in front comes before the boot started tor or read its status:
    // off is then only where the status starts, and there is nothing to kick
    if (!_torStatusRead) return;
    if (torReady) return;
    final at = now ?? DateTime.now();
    final moved = _pctMovedAt ?? _torTryingSince;
    final stalled =
        _torStatus != TorStatus.off &&
        moved != null &&
        at.difference(moved) >= AppState.backInFrontStall;
    if (_torStatus != TorStatus.off && !stalled) return;
    engine.networkChanged();
    _newTorTry();
  }

  // tor's status as the poll reads it each second. the bridge cards turn on
  // by time alone, so a change in them is announced too
  @visibleForTesting
  TorStatus takeTorStatus(String raw, {DateTime? now}) {
    final at = now ?? DateTime.now();
    _torStatusRead = true;
    final fresh = _torTryNew;
    _torTryNew = false;
    if (fresh) {
      _pctBest = -1;
      _pctMovedAt = at;
    }
    final st = parseTorStatus(raw);
    final pct = parseBootstrapPct(raw);
    final rok = parseRouteOK(raw);
    final rgen = parseRouteGen(raw);
    var changed = false;
    if (st != _torStatus ||
        pct != _bootstrapPct ||
        rok != _routeOK ||
        rgen != _routeGen) {
      // the bounce asked for has begun: what the old route carried is not
      // held through it
      if (rgen != _routeGen && _routeOnPurpose > 0) {
        _routeOnPurpose = 0;
        _usableAt = null;
      }
      _torStatus = st;
      _routeOK = rok;
      _routeGen = rgen;
      _bootstrapPct = pct;
      // tor down, even between outbox ticks: its return starts a pass
      // (flushOnRouteUp, right after this read)
      if (!torReady) _outboxWasReady = false;
      _noteTorProgress(at);
      changed = true;
      // a repoint waiting on tor goes once tor carries
      if (_torCarries) _maybeRepoint();
    }
    if (fresh) _torTryingSince = torReady ? null : at;
    // a change asked for and no new generation after a while: the engine
    // turned it down or did it without a bounce
    if (_routeOnPurpose > 0 && rgen == _routeGen) _routeOnPurpose--;
    // relays through tor while the watch says none: the engine tried and
    // found a network, and the app goes by that until the watch speaks
    if (_netWatchOn == false && _sendMode == 'private' && torUsable) {
      _netWatchOn = null;
      noteOnline(true);
    }
    // outside onion the route always reads usable, so only onion is held
    if (_sendMode == 'private' && torUsable) {
      _usableAt = at;
      if (!_everUsable) {
        _everUsable = true;
        changed = true;
      }
    }
    final hints = (suggestBridgesAt(at), suggestBridgesOffAt(at));
    if (hints != _bridgeHintsShown) {
      _bridgeHintsShown = hints;
      changed = true;
    }
    if (changed) notifyListeners();
    return st;
  }

  // the one test the outbox, the transport screen and the ui share; mirrors
  // torReadyNow() in the engine. outside onion nothing waits on a bootstrap.
  // it does not ask for a network: linkUp does
  bool get torReady => _sendMode != 'private' || torUsable;
  DateTime? get usableAt => _usableAt;
  @visibleForTesting
  set usableAtForTest(DateTime? at) => _usableAt = at;

  /// what the home pill shows as ready: the route, held through a blip
  /// shorter than kPillGrace so the pill does not flicker. nothing that
  /// sends goes by this
  bool get pillReady => pillHoldsReady(
    usable: torUsable,
    usableAt: _usableAt,
    status: _torStatus,
    online: _online,
    now: DateTime.now(),
  );

  /// when a pill held ready has to look again, null when it is not held
  DateTime? get pillGraceEnd => pillGraceEnds(
    usable: torUsable,
    usableAt: _usableAt,
    status: _torStatus,
    online: _online,
    now: DateTime.now(),
  );

  /// the connection as the home pill and the tor sheet both show it
  LinkView get linkView => linkViewAt(DateTime.now());

  /// tor's stage as the screens show it. a linked device's tor is a client:
  /// at 100% it is all the way there, with no address of its own to finish
  TorStatus get shownTorStatus =>
      linkedRole && _torStatus == TorStatus.bootstrapped
      ? TorStatus.reachable
      : _torStatus;

  @visibleForTesting
  LinkView linkViewAt(DateTime now) => linkViewOf(
    mode: _sendMode,
    status: shownTorStatus,
    pct: _bootstrapPct,
    online: _online,
    usable: torUsable,
    usableAt: _usableAt,
    tryingSince: _torTryingSince,
    relayDownSince: _relayDownSince,
    now: now,
    everUsable: _everUsable,
    caught: _startCaught,
  );

  /// a card is on screen, to scan or to show: the engine builds the hello
  /// lane's circuits now rather than after the scan. a quiet session asks
  /// nothing of the network
  void warmHelloLane() {
    if (sessionQuiet) return;
    try {
      engine.nostrWarmHello();
    } catch (e) {
      dlog('hello lane: not warmed (${e.runtimeType})');
    }
  }

  /// the start's new messages, as the engine says it: true once in, and
  /// for an engine that does not know
  void takeStartCaught(bool caught) {
    if (caught == _startCaught) return;
    _startCaught = caught;
    notifyListeners();
  }

  @visibleForTesting
  set everUsableForTest(bool v) => _everUsable = v;
  @visibleForTesting
  set startCaughtForTest(bool v) => _startCaught = v;

  DateTime? get relayDownSince => _relayDownSince;
  @visibleForTesting
  set relayDownSinceForTest(DateTime? t) => _relayDownSince = t;

  // tor can carry traffic. "reachable" is the end of publishing, not the
  // start of being usable. tor's word is not enough on its own: it can say
  // publishing while every relay connection through it fails, so this also
  // needs the engine's verdict that a relay has connected since the route
  // was last torn down, and that they are not all failing now.
  bool get torUsable =>
      _routeOK &&
      (_torStatus == TorStatus.bootstrapped ||
          _torStatus == TorStatus.publishing ||
          _torStatus == TorStatus.reachable);
  // tor can carry the services lane: the registry, people search and the
  // badges go over it on every route. on onion the route's verdict is about
  // tor and counts; elsewhere it is about the direct route, so tor's own
  // word, and not held asleep, is what there is
  bool get servicesReady => _torCarries && (_sendMode != 'private' || _routeOK);
  int get bootstrapPct => _bootstrapPct;

  // what every screen means by connected: a network, and the route the send
  // mode uses can carry traffic. connecting is that route not up yet while
  // something is still trying to bring it up
  bool get linkUp => _online && torReady;
  bool get linkComing => !torReady && _torStatus != TorStatus.off;

  // a reloaded 'sending' row has no send future left to resolve it, so past
  // a minute it is dead and becomes retryable. while tor warms up it is
  // queued, not dead: the reconnect retry fires it. torReady rather than
  // reachable, since an onion that will not publish never reaches
  // 'reachable'. a file still going out is never dead: its row is saved
  // before the first slice leaves, however long the rest takes. the one
  // rule for every chat screen
  bool sendLooksDead(DateTime sentAt, {String? msgUid, DateTime? now}) =>
      torReady &&
      (msgUid == null || !mediaInflight.contains(msgUid)) &&
      sentAt.isBefore(
        (now ?? DateTime.now()).subtract(const Duration(seconds: 60)),
      );

  // how long tor has been unable to carry traffic while kryfo is meant to be
  // connected. null when it is fine, when check-ins are holding tor off on
  // purpose, or when nothing has started trying yet. five minutes of this
  // and the home screen says so. it watches tor's own status; dropping wifi
  // does not make tor report off, and plain loss of network has its own
  // strip.
  Duration? get offlineFor => offlineDurationFor(
    mode: _deliveryMode,
    torHeld: _torHeld || haloWiping,
    torReady: torReady,
    tryingSince: _torTryingSince,
    now: DateTime.now(),
  );

  bool get looksOffline =>
      (offlineFor ?? Duration.zero) >= AppState.offlineAfter;
  DateTime? get torTryingSince => _torTryingSince;
  @visibleForTesting
  set torTryingSinceForTest(DateTime? t) => _torTryingSince = t;

  bool _torLooksBlockedAt(DateTime now) {
    if (_sendMode != 'private') return false;
    if (torReady) return false;
    final t = _torTryingSince;
    if (t == null) return false;
    // still early: give it room before calling anything wrong
    if (now.difference(t).inSeconds < 120) return false;
    // it is climbing, just not quickly. that is a slow network, not a wall.
    final moved = _pctMovedAt;
    if (moved != null && now.difference(moved).inSeconds < 90) {
      return false;
    }
    // past halfway it is talking to the network fine and something else is
    // wrong. blocking bites at the start, not the end.
    return _bootstrapPct < 50;
  }

  bool get suggestBridges => suggestBridgesAt(DateTime.now());

  // tor alone is not getting through. automatic says so itself, and a
  // bridge picked by hand has its own card
  @visibleForTesting
  bool suggestBridgesAt(DateTime now) {
    if (_bridgeHintOff || !_online || inDecoyView) return false;
    if (_bridge.choice != BridgeChoice.direct) return false;
    return _torLooksBlockedAt(now);
  }

  // a wi-fi that wants a sign-in first: its line and the way to the
  // settings go on home, whatever way tor is set to take
  bool get captiveWait =>
      !inDecoyView &&
      _sendMode == 'private' &&
      _bridgeStatus.phase == 'captive';

  // automatic is past the usual way, or gave up: the home shows its line
  bool get autoStruggling =>
      _bridge.choice == BridgeChoice.auto &&
      !inDecoyView &&
      _sendMode == 'private' &&
      (_bridgeStatus.tryingAnother || _bridgeStatus.exhausted);

  bool get suggestPrivateFallback => suggestPrivateFallbackAt(DateTime.now());

  // neither of our servers answers on fast: messages wait, and private
  // gets through the long way meanwhile
  @visibleForTesting
  bool suggestPrivateFallbackAt(DateTime now) {
    if (_relayHintOff || _sendMode != 'balanced' || !_online) return false;
    final t = _relayDownSince;
    if (t == null) return false;
    return now.difference(t).inSeconds > 90;
  }

  // relay mode's read of its relay, on its own clock: tor sits still in that
  // mode, so a read taken only when tor changes misses an outage and keeps a
  // stale one. the hint turns on by time alone, so a change is announced.
  // the fast pages read it each second while they are open
  void sampleRelayHealth({DateTime? now}) {
    final at = now ?? DateTime.now();
    final wasDown = _relayDownSince != null;
    try {
      _noteRelayHealth(engine.transportState()['relays'] as List?, now: at);
    } catch (_) {
      // transport not readable yet: nothing to conclude
    }
    final v = suggestPrivateFallbackAt(at);
    // the pill counts the spell from here on its own clock
    final moved = wasDown != (_relayDownSince != null);
    if (v != _oursDownHintShown || moved) {
      _oursDownHintShown = v;
      notifyListeners();
    }
  }

  Future<void> dismissRelayHint() async {
    _relayHintOff = true;
    notifyListeners();
  }

  // fed by the transport poll. not sub_count: that counts peer subscriptions,
  // not relay connections. a relay row's fails counts failures since that
  // relay's last success and is deleted the moment one lands, so it says
  // what is true now. benched means it is in backoff. down is: nothing in
  // the list is usable.
  void _noteRelayHealth(List? relays, {DateTime? now}) {
    final answers = relaysAnswer(relays);
    if (answers) {
      _relayUpAt = (now ?? DateTime.now()).millisecondsSinceEpoch;
    }
    // a relay answering again after none did: the outbox goes now
    final was = _relaysAnswered;
    if (relays != null && relays.isNotEmpty) _relaysAnswered = answers;
    if (answers && was == false) outboxRouteBack();
    if (_sendMode != 'balanced') {
      _relayDownSince = null;
      return;
    }
    // no rows yet: the engine has not been configured, which is not the
    // same as a relay that will not answer
    if (relays == null || relays.isEmpty) {
      _relayDownSince = null;
      return;
    }
    // a backup standing by says nothing about ours
    final anyUsable = relays.any((r) {
      if (r is! Map) return true;
      if (r['backup'] == true) return false;
      final fails = (r['fails'] as num?)?.toInt() ?? 0;
      return fails == 0 && r['benched'] != true;
    });
    if (anyUsable) {
      _relayDownSince = null;
    } else {
      _relayDownSince ??= now ?? DateTime.now();
    }
  }

  bool get suggestBridgesOff => suggestBridgesOffAt(DateTime.now());

  @visibleForTesting
  bool suggestBridgesOffAt(DateTime now) {
    if (!manualBridge || !_online || inDecoyView) return false;
    return _torLooksBlockedAt(now);
  }

  Future<void> dismissBridgeHint() async {
    _bridgeHintOff = true;
    await secureStore.write(key: 'bridge_hint_off', value: '1');
    notifyListeners();
  }

  bool get online => _online;

  /// the last time a relay answered, null before one did
  int? get relayUpAt => _relayUpAt;

  /// the relays read now, for the linked devices' clocks: the reads above
  /// run only in balanced mode or when tor moves, so a tick reads its own
  void sampleRelayUp({DateTime? now}) {
    try {
      if (relaysAnswer(engine.transportState()['relays'] as List?)) {
        _relayUpAt = (now ?? DateTime.now()).millisecondsSinceEpoch;
      }
    } catch (_) {
      // transport not readable: nothing counts
    }
  }

  Future<void> _initConnectivity() async {
    // what the network was when we started, so the first event the listener
    // delivers is not taken for a change and bounced
    try {
      final init = await Connectivity().checkConnectivity();
      if (_lastKinds != null) {
        // a recheck in front got the start already: this is a word like any
        connectivityEvent(init);
      } else {
        _connSeen = init.any((r) => r != ConnectivityResult.none);
        _online = _netWatchOn ?? _connSeen;
        engine.connectivitySeen(_connSeen);
        _lastKinds = (init.map((r) => r.name).toList()..sort()).join(',');
        notifyListeners();
      }
    } catch (e) {
      // the listener's first event is the start then
      dlog('connectivity init: $e');
    }
    Connectivity().onConnectivityChanged.listen(connectivityEvent);
    unawaited(listenNetDetail(netDetailEvent));
  }

  @visibleForTesting
  void recheckNetDetail(String? json) {
    if (json != null && json != _lastNetDetail) netDetailEvent(json);
  }

  // the watch's word on the default network, as json: to the engine, and
  // online follows it
  @visibleForTesting
  void netDetailEvent(String json) {
    _lastNetDetail = json;
    engine.networkDetail(json);
    bool? on;
    int? net;
    try {
      final m = jsonDecode(json);
      if (m is Map && m['on'] is bool) on = m['on'] as bool;
      if (m is Map && m['net'] is int) net = m['net'] as int;
    } catch (_) {}
    if (on == null) return;
    _netWatchOn = on;
    // another network in place of the one there, of the same type or not:
    // wifi to another wifi is a change connectivity does not see
    final was = _netWatchNet;
    _netWatchNet = on ? net : null;
    final moved = on && was != null && net != null && net != was;
    if (on == _online) {
      if (moved) networkMoved();
      return;
    }
    // back on a network connectivity may not have reported
    if (on) networkMoved();
    noteOnline(on);
  }

  // back in front: connectivity and the watch are asked again, as either
  // may have missed a change while the app slept
  Future<void> _recheckNetwork() async {
    recheckNetDetail(await readNetDetail());
    try {
      connectivityEvent(await Connectivity().checkConnectivity());
    } catch (e) {
      dlog('connectivity recheck: $e');
    }
  }

  // every change reaches the engine: wifi and mobile data either way, a vpn
  // up or down, airplane mode on and off, offline and back. tor's open
  // connections belong to the network that went, and each change re-arms
  // the engine's rescue. the engine waits for the network to settle before
  // it bounces, so a burst of flips is one reconnect after the last
  @visibleForTesting
  void connectivityEvent(List<ConnectivityResult> results) {
    final seen = results.any((r) => r != ConnectivityResult.none);
    final kinds = (results.map((r) => r.name).toList()..sort()).join(',');
    // connectivity's own word goes to the engine, which weighs it against
    // the watch's: a word the watch outranks is a dispute, not a change
    engine.connectivitySeen(seen);
    final last = _lastKinds;
    final flip = last == null
        ? null
        : networkFlip(
            wasOnline: _connSeen,
            lastKinds: last,
            on: seen,
            kinds: kinds,
          );
    _connSeen = seen;
    _lastKinds = kinds;
    if (flip == true) networkMoved();
    if (flip == false) engine.networkChanged(online: false);
    // online goes by the watch once it has spoken, as the engine does
    noteOnline(_netWatchOn ?? seen);
  }

  // tor's connections belong to the network that went
  @visibleForTesting
  void networkMoved() {
    _needRouteUp();
    engine.networkChanged();
    _newTorTry();
    checkFirstListener();
    outboxRouteBack();
  }

  // the route just became usable: flush anything the outbox is holding
  // instead of waiting out the next 20s tick. torReady asks the mode first,
  // so outside onion this never waits on a bootstrap
  @visibleForTesting
  void flushOnRouteUp() {
    if (linkUp && !_outboxWasReady) outboxRouteBack();
  }

  static const _offlineSpell = Duration(seconds: 60);

  @visibleForTesting
  void noteOnline(bool on, {DateTime? now}) {
    if (on == _online) return;
    final at = now ?? DateTime.now();
    _online = on;
    // the relay's clock starts again from here: dials that failed while
    // the network was gone were not the relay's fault
    _relayDownSince = null;
    if (!on) {
      _offlineAt = at;
    } else {
      // back from a spell offline, waiting rows go with their tries whole. a
      // network that flaps keeps its count, or a failing row never stops
      final gone = _offlineAt;
      _offlineAt = null;
      // past a handover the pill has said offline: what it held before
      // is not held again, the new route shows as connecting
      if (gone != null && at.difference(gone) >= kPillHandover) {
        _usableAt = null;
      }
      if (gone == null || at.difference(gone) >= _offlineSpell) {
        _outboxTries.clear();
        _outboxNextAt.clear();
        // the wait goes, the count toward the cap stays
        _ackNextAt.clear();
      }
      // the status poll sees the route come up and drains
      _outboxWasReady = false;
      unawaited(_drainAcks());
    }
    notifyListeners();
  }
}
