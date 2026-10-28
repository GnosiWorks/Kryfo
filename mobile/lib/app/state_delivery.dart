// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: how messages arrive: heartbeat, helper app, check-ins

part of '../main.dart';

extension AppStateDelivery on AppState {
  void _beat() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_awakeSince == 0 || now - _lastListenAt > kPollStallMs) {
      _awakeSince = now;
    }
    if (_lastListenAt > 0 && now - _lastListenAt > 5 * 60 * 1000) {
      _gaps.add('$_lastListenAt-$now');
      while (_gaps.length > 24) {
        _gaps.removeAt(0);
      }
      dlog('heartbeat: gap of ${(now - _lastListenAt) ~/ 60000}m');
      unawaited(_writeBeat());
    }
    _lastListenAt = now;
    if (now - _beatWritten > 60000) {
      _beatWritten = now;
      unawaited(_writeBeat());
    }
  }

  void noteJobRun() {
    _jobRuns++;
    _lastJobAt = DateTime.now().millisecondsSinceEpoch;
    unawaited(_writeBeat());
  }

  void _noteDrain() {
    _lastDrainAt = DateTime.now().millisecondsSinceEpoch;
    unawaited(_writeBeat());
  }

  Future<void> _writeBeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hb.listen', _lastListenAt);
      await prefs.setInt('hb.drain', _lastDrainAt);
      await prefs.setStringList('hb.gaps', _gaps);
      await prefs.setInt('hb.jobs', _jobRuns);
      await prefs.setInt('hb.jobAt', _lastJobAt);
    } catch (_) {
      // a record only: a miss reads as an older time
    }
  }

  // debug only: what is being held, every ten minutes, so a night's growth
  // shows up in the log with a shape rather than a single number at the end
  void startMemoryLog() {
    if (!kDebugMode) return;
    Timer.periodic(const Duration(minutes: 10), (_) {
      final m = engine.memStats();
      dlog(
        'mem rss=${ProcessInfo.currentRss ~/ 1048576}mb '
        'go heap=${((m['heapAlloc'] as num?) ?? 0) ~/ 1048576}mb '
        'sys=${((m['sys'] as num?) ?? 0) ~/ 1048576}mb '
        'goroutines=${m['goroutines']} inbox=${m['inbox']} subs=${m['subs']} '
        'sent=${m['sentIds']} imgcache=${PaintingBinding.instance.imageCache.currentSizeBytes ~/ 1048576}mb',
      );
    });
  }

  Future<void> loadHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastListenAt = prefs.getInt('hb.listen') ?? 0;
      _lastDrainAt = prefs.getInt('hb.drain') ?? 0;
      _gaps
        ..clear()
        ..addAll(prefs.getStringList('hb.gaps') ?? const []);
      _jobRuns = prefs.getInt('hb.jobs') ?? 0;
      _lastJobAt = prefs.getInt('hb.jobAt') ?? 0;
    } catch (_) {
      // unread, it starts from nothing, as on a first run
    }
  }

  // wipes the night's record so a new test starts clean
  Future<void> clearHeartbeatHistory() async {
    _gaps.clear();
    _jobRuns = 0;
    _lastJobAt = 0;
    await _writeBeat();
  }

  DeliveryMode get deliveryMode => _deliveryMode;
  @visibleForTesting
  set deliveryModeForTest(DeliveryMode m) => _deliveryMode = m;
  @visibleForTesting
  set docsPathForTest(String p) => _docsPath = p;
  bool get torHeld => _torHeld;
  bool get checkingIn => _checking;
  // a decoy with no opening time noted shows nothing from before
  bool _beforeQuiet(int at) =>
      sessionQuiet && (_quietSince <= 0 || at < _quietSince);
  int _since(int at) => _beforeQuiet(at) ? 0 : at;
  int get lastListenAt => _since(_lastListenAt);
  // a decoy never receives a message
  int get lastDrainAt => sessionQuiet ? 0 : _lastDrainAt;
  int get lastJobAt => _since(_lastJobAt);
  int get lastCheckAt => _since(_lastCheckAt);
  int get lastWakeAt => _since(_lastWakeAt);
  int get lastCheckTriedAt => _since(_lastCheckTriedAt);
  int get jobRuns => !sessionQuiet
      ? _jobRuns
      : _quietSince <= 0
      ? 0
      : max(0, _jobRuns - _quietJobs);
  String get lastCheckHow =>
      _since(_lastCheckTriedAt) == 0 && sessionQuiet ? '' : _lastCheckHow;
  // the catch-up counts the identity's subscriptions and events: a decoy
  // has neither
  String get lastCheckRelays => sessionQuiet ? '' : _lastCheckRelays;
  List<String> get gaps => sessionQuiet
      ? [
          for (final g in _gaps)
            if (!_beforeQuiet(int.tryParse(g.split('-').first) ?? 0)) g,
        ]
      : _gaps;

  // with hidden chats shut, a relay time at or before the newest sealed
  // arrival may be that arrival
  bool _maySealedAt(int atMs) =>
      _openVault == null &&
      _lastSealAt > 0 &&
      _lastSealAt >= _lastDrainAt &&
      atMs <= _lastSealAt + 1000;

  /// what the transport screen shows of the engine's traffic [tx]: in a
  /// decoy its own, which is nothing, as on a new install. with hidden
  /// chats shut nothing of theirs counts: not their subscriptions, and not
  /// an arrival sealed for them, which shows the last one the app showed
  ({int subs, int secsSinceRecv, int secsSinceSend}) shownTraffic(
    Map<String, dynamic> tx,
  ) {
    if (sessionQuiet) return (subs: 0, secsSinceRecv: -1, secsSinceSend: -1);
    final subs = tx['sub_count'] as int? ?? 0;
    final rx = tx['secs_since_recv'] as int? ?? -1;
    final sx = tx['secs_since_send'] as int? ?? -1;
    if (_openVault != null) {
      return (subs: subs, secsSinceRecv: rx, secsSinceSend: sx);
    }
    final hidden = _router.listenFor.keys.toSet();
    final listed = tx['subs'];
    final hiddenSubs = listed is List
        ? listed.where(hidden.contains).length
        : hidden.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final shownRx = rx >= 0 && _maySealedAt(now - rx * 1000)
        ? (_lastDrainAt <= 0 ? -1 : max(0, (now - _lastDrainAt) ~/ 1000))
        : rx;
    return (
      subs: max(0, subs - hiddenSubs),
      secsSinceRecv: shownRx,
      secsSinceSend: sx,
    );
  }

  /// when the newest relay event reached this phone, in unix seconds from
  /// the engine's [mem], as the transport screen shows it: never in a
  /// decoy, and never an arrival sealed for hidden chats that are shut
  int shownRelayIn(Map<String, dynamic> mem) {
    if (sessionQuiet) return 0;
    final at = (mem['lastEvRecv'] as num?)?.toInt() ?? 0;
    if (at > 0 && _maySealedAt(at * 1000)) return _lastDrainAt ~/ 1000;
    return at;
  }

  bool get nudgeDue => !sessionQuiet && _nudgeDue;

  Future<void> _judgeLastRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final booted =
          await AppState._platformChannel.invokeMethod<int>('bootedAtMs') ?? 0;
      final v = judgeRestart(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        lastBeatMs: prefs.getInt(kHeartbeatKey) ?? 0,
        bootedAtMs: booted,
        kills: prefs.getStringList(kKillsKey)?.map(int.parse).toList() ?? [],
        nudgeShown: prefs.getBool(kNudgeShownKey) ?? false,
        mode: _deliveryMode,
      );
      if (v.wasKill) {
        dlog('delivery: this phone stopped kryfo, ${v.kills.length} today');
        await prefs.setStringList(kKillsKey, v.kills.map((k) => '$k').toList());
      }
      _nudgeDue = v.showNudge;
    } catch (e) {
      dlog('delivery: could not judge the last run: $e');
    }
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _beatTimer?.cancel();
    if (_deliveryMode != DeliveryMode.always) return;
    unawaited(_writeDeliveryBeat());
    _beatTimer = Timer.periodic(
      const Duration(milliseconds: kHeartbeatEveryMs),
      (_) => unawaited(_writeDeliveryBeat()),
    );
  }

  Future<void> _writeDeliveryBeat() async {
    if (haloWiping) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kHeartbeatKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // the next beat writes it again
    }
  }

  /// the card was offered. never again, whatever the answer.
  Future<void> nudgeAnswered() async {
    _nudgeDue = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kNudgeShownKey, true);
    } catch (_) {
      // at worst the card is offered once more
    }
    notifyListeners();
  }

  Future<void> _loadDeliveryTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCheckAt = prefs.getInt(kLastCheckKey) ?? 0;
      _lastWakeAt = prefs.getInt(kLastWakeKey) ?? 0;
      _lastCheckHow = prefs.getString(kLastCheckHowKey) ?? '';
      _lastCheckRelays = prefs.getString(kLastCheckRelaysKey) ?? '';
      _lastCheckTriedAt = prefs.getInt(kLastCheckTriedKey) ?? 0;
    } catch (_) {
      // shown on screen only: unread, it starts empty
    }
  }

  // the 15-minute job runs in its own isolate and writes these to prefs,
  // which this process never sees. the transport screen calls this when it
  // opens so what is on it came from disk, not from memory.
  Future<void> refreshFromDisk() async {
    // SharedPreferences keeps an in-memory cache per isolate, filled once
    try {
      await (await SharedPreferences.getInstance()).reload();
    } catch (_) {
      // the screen shows what this process already had
    }
    await loadHeartbeat();
    await _loadDeliveryTimes();
    notifyListeners();
  }

  // who took how long on the last catch-up, by relay host, no content. kept
  // as data and worded when shown (catchupLine), so it reads in whatever
  // language the app is in by then.
  String _relayCatchupData() {
    try {
      final rs = (engine.transportState()['relays'] as List?) ?? const [];
      final out = <Map<String, Object>>[];
      for (final r in rs) {
        final m = r as Map;
        if (m['catchup_seen'] != true) continue;
        final host = (m['url'] as String? ?? '')
            .replaceFirst(RegExp(r'^wss?://'), '')
            .split('/')
            .first;
        out.add({
          'host': host,
          'ms': m['catchup_ms'] as int? ?? 0,
          'long': m['catchup_long'] == true,
          'dropped': m['catchup_dropped'] == true,
          'connect_ms': m['connect_ms'] as int? ?? 0,
          'pages': m['catchup_pages'] as int? ?? 0,
          'events': m['catchup_events'] as int? ?? 0,
          'subs': m['catchup_subs'] as int? ?? 0,
          'held': m['catchup_subs_dropped'] as int? ?? 0,
        });
      }
      return out.isEmpty ? '' : jsonEncode(out);
    } catch (_) {
      return '';
    }
  }

  // the language changed: the notification channel's name and the service's
  // own notification are android's, and are told again. the chat list's
  // previews ("you: ...") were worded when the list was read, so it is read
  // again.
  Future<void> languageChanged() async {
    unawaited(refreshContacts());
    unawaited(refreshGroups());
    try {
      await nameNotificationChannel();
      if (!kIsWeb && Platform.isAndroid) {
        await AppState._platformChannel.invokeMethod('applyDeliveryMode');
      }
    } catch (e) {
      dlog('language: android side not told: $e');
    }
  }

  // [left]: what woke the phone in the mode before was let go already
  Future<void> setDeliveryMode(DeliveryMode m, {bool left = false}) async {
    if (m == _deliveryMode) return;
    final was = _deliveryMode;
    _deliveryMode = m;
    if (knockMode(was) && !left) unawaited(helperOff(from: _pushOf(was)));
    await saveDeliveryMode(m);
    try {
      await AppState._platformChannel.invokeMethod('applyDeliveryMode');
    } catch (e) {
      dlog('delivery: platform did not take the mode: $e');
    }
    if (m == DeliveryMode.always) {
      _sleepTimer?.cancel();
      await _torWake();
    } else if (!_inFront) {
      _scheduleSleep();
    }
    _startHeartbeat();
    notifyListeners();
  }

  bool get helperRelaySaidNo => _relaySaidNo;

  // what hands out the slots' endpoints in a mode
  HelperPush _pushOf(DeliveryMode m) =>
      m == DeliveryMode.google ? GooglePush.instance : HelperPush.instance;

  /// google push can be picked: a play build, on a phone with play services
  bool get googleOffered => playBuild && _googleAvailable;
  @visibleForTesting
  set googleAvailableForTest(bool v) => _googleAvailable = v;

  /// the card that offers google push once, to a phone set up before it
  /// came. never in a decoy, and only on the onion route it needs
  bool get googleCardDue =>
      googleOffered &&
      _googleOffer == 'due' &&
      !inDecoyView &&
      _sendMode == 'private' &&
      _deliveryMode != DeliveryMode.google;
  @visibleForTesting
  set googleOfferForTest(String v) => _googleOffer = v;

  Future<void> googleCardAnswered() async {
    if (_googleOffer == 'said') return;
    _googleOffer = 'said';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kGoogleOfferKey, 'said');
    } catch (_) {
      // at worst the card is offered once more
    }
  }

  /// asks android whether play services are there, for onboarding's step
  Future<bool> lookForGoogle() async {
    if (!playBuild) return false;
    final was = _googleAvailable;
    _googleAvailable = await GooglePush.instance.available();
    if (was != _googleAvailable) notifyListeners();
    return _googleAvailable;
  }

  // play services on the phone, and whether the card is owed: a phone set
  // up before google push came gets it once, a new one is asked in its
  // onboarding instead
  Future<void> _loadGoogle() async {
    if (!playBuild) return;
    _googleAvailable = await GooglePush.instance.available();
    final prefs = await SharedPreferences.getInstance();
    var offer = prefs.getString(kGoogleOfferKey);
    if (offer == null && onboardingComplete) {
      offer = 'due';
      await prefs.setString(kGoogleOfferKey, offer);
    }
    _googleOffer = offer ?? '';
  }

  /// google push picked: firebase starts, the token is sealed once for
  /// each of the sixteen slots, the mode, then the relay. the helper app,
  /// if that was the mode, lets go first. false when no token came
  Future<bool> useGoogle() => _helperOp(() async {
    if (!googleOffered) return false;
    final was = _deliveryMode;
    if (was == DeliveryMode.google) return true;
    if (was == DeliveryMode.helper) {
      await helper.stop(from: HelperPush.instance);
      _helperName = null;
    }
    helper.usePush(GooglePush.instance);
    if (!await helper.setUp(kGooglePackage)) {
      // no token: nothing of google push is left behind
      await GooglePush.instance.unregister();
      helper.usePush(HelperPush.instance);
      if (was == DeliveryMode.helper) {
        await setDeliveryMode(DeliveryMode.checkins, left: true);
      }
      return false;
    }
    _helperGone = '';
    _googleOffer = 'said';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kHelperGoneKey);
    await prefs.setString(kGoogleOfferKey, 'said');
    await setDeliveryMode(DeliveryMode.google, left: true);
    _helperSoon();
    return true;
  });

  Future<T> _helperOp<T>(Future<T> Function() f) {
    final run = _helperQueue.then((_) => f());
    _helperQueue = run.then(
      (_) {},
      onError: (Object e) {
        dlog('helper: ${e.runtimeType}');
      },
    );
    return run;
  }

  /// the picker shows the helper app once our relay can knock, and only on
  /// the private route: registrations go over tor or not at all. a phone
  /// already on it always sees its choice
  bool get helperOffered =>
      _deliveryMode == DeliveryMode.helper ||
      (_relayKnocks && _sendMode == 'private');
  String? get helperName => _helperName;
  bool get helperRefused => _helperRefused;
  bool get helperGoneDue => _helperGone.startsWith('due:') && !sessionQuiet;
  // why the card shows: the helper app is gone, or the relay stopped
  bool get helperRelayStopped => _helperGone.startsWith('due:relay:');
  // google push that the phone can no longer use: play services went
  bool get helperGoneWasGoogle =>
      _helperGone.startsWith('due:gone:$kGooglePackage');
  @visibleForTesting
  set relayKnocksForTest(bool v) => _relayKnocks = v;
  @visibleForTesting
  set relaySaidNoForTest(bool v) => _relaySaidNo = v;
  @visibleForTesting
  Future<void> lookAtHelperForTest() => _lookAtHelper();
  @visibleForTesting
  Future<int> helperRoundForTest() => _helperRound();

  Future<void> _loadHelper() async {
    try {
      _relayKnocks = await helper.relayKnocks();
      _relaySaidNo = await helper.relayAnswer() == 'no';
      _helperRefused = await helper.refusedLasting();
      final prefs = await SharedPreferences.getInstance();
      _helperGone = prefs.getString(kHelperGoneKey) ?? '';
      await _loadGoogle();
      if (knockMode(_deliveryMode)) await _lookAtHelper();
      notifyListeners();
    } catch (e) {
      dlog('helper: not loaded (${e.runtimeType})');
    }
  }

  /// asks our relay whether it can knock, at most once a day, and only
  /// with tor up on the private route. a relay that stopped while this
  /// phone relies on it sends the phone back to check-ins
  Future<void> refreshHelperOffer() async {
    if (_sendMode != 'private' || !torReady) return;
    final was = _relayKnocks;
    final wasNo = _relaySaidNo;
    try {
      _relayKnocks = await helper.relayKnocks(ask: true);
      _relaySaidNo = await helper.relayAnswer() == 'no';
    } catch (e) {
      dlog('helper: relay not asked (${e.runtimeType})');
    }
    if (was && !_relayKnocks && knockMode(_deliveryMode)) {
      await _helperFallBack('relay', '-');
    }
    if (was != _relayKnocks || wasNo != _relaySaidNo) notifyListeners();
  }

  // the helper app's name for the status line, and whether it is still on
  // the phone. gone, the phone goes back to check-ins, the relay forgets
  // its registrations, and the home screen says so once
  Future<void> _lookAtHelper() async {
    final push = _pushOf(_deliveryMode);
    final pkg = await push.chosen();
    if (pkg == null) return;
    if (push is GooglePush) push.forgetAvailable();
    final apps = await push.apps();
    final app = apps.where((a) => a.package == pkg).firstOrNull;
    _helperName = app?.name;
    if (app == null) await _helperFallBack('gone', pkg);
    notifyListeners();
  }

  Future<void> _helperFallBack(String why, String pkg) async {
    if (!_helperGone.endsWith(':$why:$pkg')) {
      _helperGone = 'due:$why:$pkg';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kHelperGoneKey, _helperGone);
    }
    if (knockMode(_deliveryMode)) {
      await setDeliveryMode(DeliveryMode.checkins);
    }
    notifyListeners();
  }

  Future<void> helperGoneAnswered() async {
    if (!_helperGone.startsWith('due:')) return;
    _helperGone = 'said:${_helperGone.substring(4)}';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kHelperGoneKey, _helperGone);
  }

  // an endpoint came or went, or a round left more: the next round once
  // things settle, if tor is up anyway. otherwise the next check-in
  // a round already waiting keeps its time: an endpoint arriving never
  // pulls the next round forward
  void _helperSoon([Duration? after]) {
    if (_helperTimer?.isActive ?? false) return;
    _helperTimer = Timer(after ?? const Duration(seconds: 3), () {
      if (!_torHeld && torReady) unawaited(_helperRound());
    });
  }

  // one round: a group of registrations in helper mode, or a forget left
  // from before. with the app open the next round follows a few minutes
  // on; in the background the next check-in takes it
  Future<int> _helperRound() async {
    var n = 0;
    var more = false;
    try {
      var sent = false;
      if (knockMode(_deliveryMode) && _sendMode == 'private') {
        n = await _helperOp(() => helper.sync());
        more = helper.more;
        sent = helper.sent;
        final refused = await helper.refusedLasting();
        if (refused != _helperRefused) {
          _helperRefused = refused;
          notifyListeners();
        }
      }
      // one group a round, all told: a forget waits for a round with no
      // registrations in it
      if (await helper.forgetsLeft()) {
        if (!sent) n += await _helperOp(() => helper.forgetRound());
        more = more || await helper.forgetsLeft();
      }
    } catch (e) {
      dlog('helper: round (${e.runtimeType})');
    }
    if (more && _inFront) {
      _helperSoon(Duration(seconds: 60 + Random().nextInt(180)));
    }
    return n;
  }

  /// the helper app chosen: sixteen registrations with it, the mode, then
  /// the relay. false when the helper app handed back no endpoint
  Future<bool> useHelper(HelperApp app) => _helperOp(() async {
    final was = _deliveryMode;
    // google push lets go first: its token is deleted
    if (was == DeliveryMode.google) {
      await helper.stop(from: GooglePush.instance);
    }
    helper.usePush(HelperPush.instance);
    if (!await helper.setUp(app.package)) {
      if (was == DeliveryMode.google) {
        await setDeliveryMode(DeliveryMode.checkins, left: true);
      }
      return false;
    }
    _helperName = app.name;
    _helperGone = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kHelperGoneKey);
    await setDeliveryMode(DeliveryMode.helper, left: true);
    _helperSoon();
    return true;
  });

  // leaving the mode: the helper app or google push ([from]) lets go now,
  // the relay's copies are forgotten a round at a time
  Future<void> helperOff({HelperPush? from}) => _helperOp(() async {
    try {
      await helper.stop(from: from);
    } catch (e) {
      dlog('helper: stop (${e.runtimeType})');
    }
    _helperName = null;
    _helperSoon();
  });

  // the window came to the front, or left it
  void appInFront(bool front) {
    _inFront = front;
    // left the screen: a quiet moment for what a removal owes the file. a
    // vault is tidied right after a removal in it, and as it opens, never
    // as it shuts
    if (!front) {
      _typingClear();
      unawaited(_tidy(live));
      if (sessionQuiet) unawaited(_tidy(_session.primary));
    }
    // google push left while offline: its delete is tried again
    if (front && playBuild && _deliveryMode != DeliveryMode.google) {
      unawaited(GooglePush.instance.settle());
    }
    if (front && knockMode(_deliveryMode)) {
      unawaited(_lookAtHelper().catchError((Object _) {}));
      unawaited(refreshHelperOffer());
    }
    if (front) {
      unawaited(_recheckNetwork());
      // tor may be asleep or the status a beat old: automatic is looked at
      // again as the status comes in, for a little while
      _stuckLookUntil = DateTime.now().add(AppState.stuckLookFor);
      retryStuckAuto();
    }
    if (_deliveryMode == DeliveryMode.always) {
      if (front) backInFront();
      return;
    }
    if (front) {
      _sleepTimer?.cancel();
      // awake, automatic is looked at again: held, it was passed over above
      unawaited(
        _torWake().then((up) {
          if (up) retryStuckAuto();
        }),
      );
    } else {
      _scheduleSleep();
    }
  }

  // tor goes down a while after the person leaves, not the moment they do:
  // a message just sent has to get out first, and someone flicking between
  // two apps should not pay a bootstrap every time.
  void _scheduleSleep() {
    _sleepTimer?.cancel();
    var waited = 0;
    _sleepTimer = Timer.periodic(const Duration(seconds: 30), (t) {
      waited += 30;
      if (_inFront || _deliveryMode == DeliveryMode.always) {
        t.cancel();
        return;
      }
      final busy = _q.n > 0 || mediaInflight.isNotEmpty || _checking;
      if (waited < 90 || (busy && waited < 600)) return;
      t.cancel();
      unawaited(_torSleep());
    });
  }

  Future<T> _torInTurn<T>(Future<T> Function() f) {
    final run = _torGate.then((_) => f());
    _torGate = run.then((_) {}, onError: (_) {});
    return run;
  }

  @visibleForTesting
  Future<void> torSleepForTest() => _torSleep();
  @visibleForTesting
  Future<bool> torWakeForTest() => _torWake();

  Future<void> _torSleep() => _torInTurn(_torSleepNow);

  Future<bool> _torWake() => _torInTurn(_torWakeNow);

  Future<void> _torSleepNow() async {
    // back in front while it waited its turn: the wake behind it wins
    if (haloWiping || _inFront) return;
    _wakeAgain?.cancel();
    _sleepAgain?.cancel();
    // held is only the app's word: a wake that failed half way has let the
    // engine run again, and then it is stopped once more
    if (_torHeld && engine.torPaused()) return;
    _torHeld = true;
    final r = await engine.torStop();
    dlog('delivery: tor stopped ($r)');
    // a stop the control port refused leaves tor on the network, and the
    // watchdog leaves a held tor alone: the stop is tried again
    if (r.startsWith('error')) {
      _sleepLater();
    } else {
      _sleepTries = 0;
    }
    notifyListeners();
  }

  void _sleepLater() {
    _sleepAgain?.cancel();
    final wait = Duration(seconds: min(600, 30 << min(_sleepTries, 5)));
    _sleepTries++;
    _sleepAgain = Timer(wait, () {
      if (!_torHeld || haloWiping || _inFront) return;
      if (_deliveryMode == DeliveryMode.always) return;
      unawaited(_torSleep());
    });
  }

  Future<bool> _torWakeNow() async {
    _wakeAgain?.cancel();
    _sleepAgain?.cancel();
    _sleepTries = 0;
    if (!_torHeld) return true;
    // 'ok': tor was asleep and is waking. 'start': there is no tor in this
    // process yet. either way the start call below hands back the address
    // of the tor that is up, or makes one.
    final r = await engine.torResume();
    if (r.startsWith('error')) {
      dlog('delivery: tor would not wake: $r');
      _wakeLater();
      return false;
    }
    _torHeld = false;
    final addr = await engine.startListenerBg(_docsPath);
    if (addr.isEmpty || addr.startsWith('error')) {
      dlog('delivery: tor did not start: $addr');
      return false;
    }
    myOnion = addr;
    notifyListeners();
    return true;
  }

  // a wake that failed, most often a control port that stopped answering,
  // is tried again for as long as tor is wanted. the watchdog leaves a held
  // tor alone, so nothing else would
  void _wakeLater() {
    _wakeAgain?.cancel();
    _wakeAgain = Timer(const Duration(seconds: 15), () {
      if (!_torHeld || haloWiping) return;
      if (!_inFront && _deliveryMode != DeliveryMode.always) return;
      unawaited(_torWake());
    });
  }

  @visibleForTesting
  set checkClockForTest(DateTime Function() c) => _checkClock = c;

  // [jobAt]: when the job began, which may be a while before this runs. the
  // job is stopped 170 s after it began (HaloPeriodicJobService), and all of
  // this, tor's sleep too, is over by about 137 s into it (kCheck*)
  Future<int> checkIn({String why = 'job', DateTime? jobAt}) async {
    if (_checking) {
      // a knock while one runs is owed one more, once this one is done
      if (why == 'push') _knockOwed = true;
      return 0;
    }
    _checking = true;
    final now0 = _checkClock();
    final started =
        jobAt != null &&
            !jobAt.isAfter(now0) &&
            now0.difference(jobAt) <= kCheckJobOldest
        ? jobAt
        : now0;
    // what is left of the job's budget until [secs] into it
    Duration left(int secs) {
      final l = started.add(Duration(seconds: secs)).difference(_checkClock());
      return l.isNegative ? Duration.zero : l;
    }

    final drainBefore = _lastDrainAt;
    final wasHeld = _torHeld;
    // tor asleep in the background: a check-in proper, not the app in use
    final window = wasHeld && !_inFront;
    if (window) {
      engine.checkInWindow(
        true,
        ago: now0.difference(started).inSeconds.clamp(0, 600),
      );
    }
    var how = 'started';
    try {
      // too little of the job left to wake tor and be heard: nothing starts
      if (left(kCheckReadyBy) < kCheckWakeLeast) {
        how = 'late';
        return 0;
      }
      final woke = await _torWake().timeout(
        left(kCheckReadyBy),
        onTimeout: () => false,
      );
      if (!woke) {
        how = 'nowake';
        return 0;
      }
      // ready means the engine has a route a relay can be reached over
      final readyWait = min(75, left(kCheckReadyBy).inSeconds);
      for (var i = 0; i < readyWait && !torReady; i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!torReady) {
        how = 'notready';
        dlog('checkin($why): tor never became ready');
        return 0;
      }
      final listenWait = left(kCheckListenedBy);
      await _listenedFirst(
        wait: listenWait < const Duration(seconds: 30)
            ? listenWait
            : const Duration(seconds: 30),
      );
      // too late in the job for the relays' answers: what is owed goes,
      // and nothing counts as checked
      final late = left(kCheckKickBy) == Duration.zero;
      var tail = '';
      if (late) {
        tail = '_late';
      } else {
        final begunBefore = engine.catchupState().$2;
        _needRouteUp();
        try {
          engine.nostrKick();
        } catch (e) {
          dlog('checkin: kick: $e');
        }
        // the relays get their time from the kick, not from a slow wake
        final kicked = _checkClock();
        // wait for the relays to be asked, then for every answer to be in.
        // the engine caps each relay's catch-up, its dial and a socket's
        // turn, so this ends when all have finished or been given up on. a
        // socket waiting its turn counts as active, not as begun. the two
        // escapes are for no relay ever getting going.
        var quiet = 0;
        var began = false;
        while (true) {
          final now = _checkClock();
          final secs = now.difference(kicked).inSeconds;
          final (active, begun) = engine.catchupState();
          if (begun > begunBefore) began = true;
          if (began && active == 0) {
            quiet++;
            if (quiet >= 4) break;
          } else {
            quiet = 0;
          }
          if (!began && active == 0 && secs >= 45) {
            tail = '_norelay';
            break;
          }
          // the job's budget, whatever holds catchupActive up: the line on
          // the transport screen will say which relay
          if (left(kCheckLoopBy) == Duration.zero) {
            tail = '_capped';
            break;
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      _lastCheckRelays = _relayCatchupData();
      // no relay ever got going, most often no network: nothing was
      // checked, and the last check-in stays the one that was. no slices
      // are asked for either: with no relay, the ask could not go
      if (tail == '_norelay') {
        how = 'norelay';
        return 0;
      }
      // what came in is drained by the one-second poll. let it finish, and
      // let receipts and slice requests that answer it get out, briefly:
      // the job's stop is near
      await Future.delayed(const Duration(seconds: 2));
      if (!late) {
        await askForMissingSlices(
          walked: true,
        ).timeout(const Duration(seconds: 3), onTimeout: () {});
      }
      for (var i = 0; i < 5 && _q.n > 0 && !everydayHeld; i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
      if (late) {
        how = 'late';
        return 0;
      }
      // a round of registrations, or of forgets, goes to the relay while
      // tor is up, inside what is left of the job's loop budget
      final helperLeft = left(kCheckLoopBy);
      if (helperLeft.inSeconds >= 5) {
        await _helperRound().timeout(
          helperLeft > const Duration(seconds: 40)
              ? const Duration(seconds: 40)
              : helperLeft,
          onTimeout: () => 0,
        );
      }
      how = 'ok$tail';
      _lastCheckAt = DateTime.now().millisecondsSinceEpoch;
      if (why == 'push') _lastWakeAt = _lastCheckAt;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kLastCheckKey, _lastCheckAt);
        if (why == 'push') await prefs.setInt(kLastWakeKey, _lastWakeAt);
      } catch (_) {
        // shown on screen only: a miss shows an older time
      }
      dlog(
        'checkin($why): done in ${_checkClock().difference(started).inSeconds}s',
      );
      return _lastDrainAt != drainBefore ? 1 : 0;
    } finally {
      // tor back to sleep and the window shut first: a job stopped during
      // the writes below must not leave tor awake. only put it back to
      // sleep if it was asleep: a check-in that ran while the person had
      // the app open leaves tor alone
      if (wasHeld && !_inFront && _deliveryMode != DeliveryMode.always) {
        try {
          await _torSleep().timeout(const Duration(seconds: 6));
        } on TimeoutException {
          dlog('checkin: tor slow to sleep');
        }
      }
      if (window) engine.checkInWindow(false);
      _checking = false;
      if (_knockOwed) {
        _knockOwed = false;
        unawaited(HelperPush.instance.knockAgain());
      }
      _lastCheckHow = jsonEncode({
        'how': how,
        'secs': _checkClock().difference(started).inSeconds,
        'why': why,
      });
      _lastCheckTriedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kLastCheckHowKey, _lastCheckHow);
        await prefs.setString(kLastCheckRelaysKey, _lastCheckRelays);
        await prefs.setInt(kLastCheckTriedKey, _lastCheckTriedAt);
      } catch (_) {
        // shown on screen only: a miss shows an older time
      }
      notifyListeners();
    }
  }

  // [serviceUp]: the job found the listener service already running
  // [jobAgo]: how long ago the job that asks began, by the job's clock
  Future<int> drainNow({
    bool serviceUp = false,
    Duration? jobAgo,
    String why = 'job',
  }) async {
    final jobAt = jobAgo == null ? null : _checkClock().subtract(jobAgo);
    // the job can knock before a cold boot has read the mode. wait for that,
    // or the first check-in after a kill does nothing
    for (var i = 0; i < 80 && _docsPath.isEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (_deliveryMode != DeliveryMode.always && (_torHeld || !_inFront)) {
      return checkIn(why: why, jobAt: jobAt);
    }
    if (jobMayRest(
      mode: _deliveryMode,
      serviceUp: serviceUp,
      torReady: torReady,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      lastPollMs: _lastListenAt,
      awakeSinceMs: _awakeSince,
    )) {
      dlog('drainNow: listening all along, nothing to do');
      return 0;
    }
    await _listenedFirst();
    final before = _lastDrainAt;
    _needRouteUp();
    try {
      engine.nostrKick();
    } catch (e) {
      dlog('drainNow: kick: $e');
    }
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (_lastDrainAt != before && i >= 3) break;
    }
    dlog('drainNow: drained=${_lastDrainAt != before}');
    return _lastDrainAt != before ? 1 : 0;
  }

  // three facts from the platform, null when no activity is attached
  Future<bool?> isBatteryExempt() async {
    try {
      return await AppState._platformChannel.invokeMethod<bool>(
        'isBatteryExempt',
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> processUptimeMs() async {
    try {
      return await AppState._platformChannel.invokeMethod<int>(
        'processUptimeMs',
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> lastExit() async {
    if (sessionQuiet) return null;
    try {
      final r = await AppState._platformChannel.invokeMethod<Map>('lastExit');
      return r?.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }
}
