// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: tor bridges

part of '../main.dart';

extension AppStateBridges on AppState {
  BridgeSetup get bridge => _bridge;
  BridgeChoice get bridgeChoice => _bridge.choice;
  BridgeStatus get bridgeStatus => _bridgeStatus;
  List<BridgeLineCheck> lineChecksFor(BridgeChoice c) =>
      _checksOf == c ? _lineChecks : const [];

  // the status line every screen shows
  BridgeLine get bridgeLine => bridgeStatusLine(
    _bridgeStatus.withSince(_bridgeSinceMs),
    decoy: inDecoyView,
    consent: _bridge.consent,
  );

  // the one bridge card the home shows, in this order: automatic's own
  // line, a picked bridge not getting through, tor alone not getting
  // through, the offer of automatic. never two at once, never over hidden
  // chats
  String? get homeBridgeCard {
    if (inDecoyView || lockState.inVault) return null;
    if (autoStruggling || captiveWait) return 'auto';
    if (suggestBridgesOff) return 'stuck';
    if (suggestBridges) return 'hint';
    if (_bridge.offerAuto &&
        _bridge.choice != BridgeChoice.auto &&
        _sendMode == 'private') {
      return 'offer';
    }
    return null;
  }

  // a bridge picked by hand, not automatic and not tor alone
  bool get manualBridge =>
      _bridge.choice != BridgeChoice.auto &&
      _bridge.choice != BridgeChoice.direct;
  bool get firstRunAsk => _firstRunAsk;

  @visibleForTesting
  set bridgeSetupForTest(BridgeSetup b) => _bridge = b;

  @visibleForTesting
  void setBridgeStatusForTest(BridgeStatus s) {
    _bridgeStatus = s;
    _bridgeSinceMs = s.sinceMs;
    notifyListeners();
  }

  Future<void> _loadBridges() async {
    // the session can change while storage is read, so it is read after
    final quiet = await quietNow();
    tellEngineDecoy(lockState.inDecoy || quiet);
    const st = secureStore;
    _bridgeHintOff = (await st.read(key: 'bridge_hint_off')) == '1';
    final asked = _firstRunAsk;
    _bridge = await readBridgeSetup(firstStart: !onboardingComplete);
    _firstRunAsk = _firstRunAsk || asked;
    // what automatic learnt and the lines the engine refreshed, back in
    _memKept = await st.read(key: 'bridge_auto_mem');
    _cacheKept = await st.read(key: 'bridge_cache');
    _handBridgeMemoryOver();
    if (!_lockHooked) {
      _lockHooked = true;
      lockState.addListener(_bridgesOnLock);
    }
    if (_firstRunAsk) {
      // tor waits for the answer, so the splash does not say it starts.
      // started with no window, it waits for one and asks then
      final phase = bootPhase;
      bootPhase = '';
      _firstRunPick = Completer<void>();
      notifyListeners();
      await _firstRunPick!.future;
      bootPhase = phase;
    }
    final r = restoreBridgeAtBoot();
    dlog('bridges: ${_bridge.choice.id}: $r');
    notifyListeners();
  }

  @visibleForTesting
  Future<void> loadBridgesForTest() => _loadBridges();

  @visibleForTesting
  void dropBridgeHooks() {
    if (!_lockHooked) return;
    _lockHooked = false;
    lockState.removeListener(_bridgesOnLock);
  }

  void _handBridgeMemoryOver() {
    if (_memIn || inDecoyView) return;
    final mem = _memKept, cache = _cacheKept;
    final a = mem == null ? 'ok' : engine.setAutoMemory(mem);
    final b = cache == null ? 'ok' : engine.setBridgeCache(cache);
    _memIn = a == 'ok' && b == 'ok';
  }

  @visibleForTesting
  bool get bridgeMemoryIn => _memIn;

  /// the kept mode, to the engine before tor starts. a decoy open or not:
  /// it shows automatic, and tor keeps what the person picked. with nothing
  /// to use, or a mode the engine refuses, automatic without tor alone,
  /// never direct; the engine falls back the same way
  @visibleForTesting
  String restoreBridgeAtBoot() {
    var m = _bridge.engineMode(
      builtin: _bridge.choice == BridgeChoice.builtin
          ? engine.builtinBridges('obfs4')
          : const [],
    );
    if (m == null) {
      _bridge = _bridge.copyWith(choice: BridgeChoice.auto, skipDirect: true);
      unawaited(_writeBridgeSetup(_bridge));
      m = _bridge.engineMode();
    }
    final r = engine.restoreBridgeMode(m!.$1, m.$2);
    // already set, or the restore already asked for: the engine has a
    // mode, not a refusal
    const taken = {'error: mode already set', 'error: restore used'};
    if (r.startsWith('error') && !taken.contains(r)) {
      dlog('bridges: kept mode refused ($r)');
      // kept at once, the yes and the country with it, as the engine does
      _bridge = _bridge.copyWith(choice: BridgeChoice.auto, skipDirect: true);
      unawaited(_writeBridgeSetup(_bridge));
      return r;
    }
    if (m.$1 != 'auto' && m.$2.contains('"lines"')) {
      _lineChecks = BridgeLineCheck.parse(engine.bridgeLineChecks());
      _checksOf = _bridge.choice;
    }
    return r;
  }

  /// a new install, asked before tor starts. nothing is written until the
  /// answer, so a kill on the question asks again
  @visibleForTesting
  Future<bool> firstRunWanted() async {
    const st = secureStore;
    if (await st.read(key: 'bridge_mode') != null) return false;
    // a fresh install asked before and not answered yet
    if (await st.read(key: 'bridge_fresh') == '1') return true;
    if (onboardingComplete) return false;
    if (await st.read(key: 'bridges_on') != null) return false;
    return (await st.read(key: 'bridge_lines') ?? '').isEmpty;
  }

  /// the boot's last step before the first screen: whether a new install
  /// is asked how to connect is known by then, so onboarding never shows
  /// first
  @visibleForTesting
  Future<void> markReady() async {
    _firstRunAsk = await firstRunWanted();
    ready = true;
  }

  // the setup as kept, or, on the first start of this version, what 0.5.0
  // kept, moved over once, in an order a kill at any point survives
  @visibleForTesting
  Future<BridgeSetup> readBridgeSetup({required bool firstStart}) async {
    const st = secureStore;
    final mode = BridgeChoice.parse(await st.read(key: 'bridge_mode'));
    final source = await st.read(key: 'bridge_source');
    if (mode != null) {
      final offerRaw = await st.read(key: 'bridge_offer_auto');
      _offerRaw = offerRaw;
      var offer = offerRaw == '1';
      final again = int.tryParse(
        offerRaw != null && offerRaw.startsWith('again:')
            ? offerRaw.substring(6)
            : '',
      );
      if (again != null &&
          mode != BridgeChoice.auto &&
          DateTime.now().millisecondsSinceEpoch >= again) {
        offer = _offerSecond = true;
      }
      final b = BridgeSetup(
        choice: mode,
        // a move cut short: bridge_lines still holds the tor project's
        friendLines: source == 'moat'
            ? ''
            : await st.read(key: 'bridge_lines') ?? '',
        torProjectLines: await st.read(key: 'bridge_moat_lines') ?? '',
        consent: await st.read(key: 'bridge_consent') ?? 'no',
        skipDirect: (await st.read(key: 'bridge_skip_direct')) == '1',
        country: await st.read(key: 'bridge_country') ?? '',
        offerAuto: offer,
      );
      await _finishBridgeMove(source, b);
      return b;
    }
    final on = await st.read(key: 'bridges_on');
    final lines = await st.read(key: 'bridge_lines');
    // a fresh install stays one until its answer, whatever the onboarding
    final fresh = await st.read(key: 'bridge_fresh') == '1';
    final upgrade =
        !fresh && (!firstStart || on != null || (lines ?? '').isNotEmpty);
    final b = migrateBridges(
      upgrade: upgrade,
      on: on,
      lines: lines,
      source: source,
    );
    // a new install keeps only that it is one, and is asked: now, or when
    // it is next in front
    if (!upgrade) {
      _firstRunAsk = true;
      if (!fresh) await _bridgeWrite('bridge_fresh', '1');
      return b;
    }
    // the new keys, the tor project's lines first and the mode last, with
    // bridge_lines as it was: a kill before the mode moves over again
    await _writeBridgeSetup(b, lines: false);
    await _finishBridgeMove(source, b);
    return b;
  }

  // the old keys go once the mode is written. bridge_lines last, while
  // bridge_source still says what it holds
  Future<void> _finishBridgeMove(String? source, BridgeSetup b) async {
    const st = secureStore;
    if (await st.read(key: 'bridges_on') != null) {
      await _bridgeDelete('bridges_on');
    }
    if (source == null) return;
    if (b.friendLines.isEmpty) await _bridgeDelete('bridge_lines');
    await _bridgeDelete('bridge_source');
  }

  Future<void> _bridgeWrite(String key, String value) async {
    bridgeWriteTap?.call(key);
    await secureStore.write(key: key, value: value);
  }

  Future<void> _bridgeDelete(String key) async {
    bridgeWriteTap?.call(key);
    await secureStore.delete(key: key);
  }

  Future<void> _writeBridgeSetup(BridgeSetup b, {bool lines = true}) async {
    final offer = b.offerAuto
        ? '1'
        : !_offerSecond && (_offerRaw?.startsWith('again:') ?? false)
        ? _offerRaw!
        : '0';
    await _bridgeWrite('bridge_moat_lines', b.torProjectLines);
    await _bridgeWrite('bridge_consent', b.consent);
    await _bridgeWrite('bridge_skip_direct', b.skipDirect ? '1' : '0');
    await _bridgeWrite('bridge_country', b.country);
    await _bridgeWrite('bridge_offer_auto', offer);
    if (lines) await _bridgeWrite('bridge_lines', b.friendLines);
    // the mode last: a setup without it is read as not moved over yet
    await _bridgeWrite('bridge_mode', b.choice.id);
  }

  /// the first-run answer: connect as usual, or tor is blocked or watched
  /// here and automatic starts without trying it
  Future<void> pickFirstRun({required bool risky}) async {
    _bridge = _bridge.copyWith(skipDirect: risky);
    await _writeBridgeSetup(_bridge);
    await _bridgeDelete('bridge_fresh');
    _firstRunAsk = false;
    notifyListeners();
    final p = _firstRunPick;
    if (p != null && !p.isCompleted) p.complete();
  }

  /// hands the choice to the engine now. "ok" or why not
  String applyBridgeNow() {
    _bridgeApply?.cancel();
    _bridgeApply = null;
    // a decoy changes nothing underneath
    if (inDecoyView) return 'error: decoy';
    final m = _bridge.engineMode(
      builtin: _bridge.choice == BridgeChoice.builtin
          ? engine.builtinBridges('obfs4')
          : const [],
    );
    if (m == null) return 'error: nothing to use';
    final r = engine.setBridgeMode(m.$1, m.$2);
    if (m.$1 != 'auto' && m.$2.contains('"lines"')) {
      _lineChecks = BridgeLineCheck.parse(engine.bridgeLineChecks());
      _checksOf = _bridge.choice;
    }
    _newRoute();
    return r;
  }

  /// a card or a row was picked: it shows at once and reaches the engine a
  /// moment after the last tap
  Future<void> chooseBridge(BridgeChoice c) async {
    if (inDecoyView) return;
    final was = _bridge.choice;
    _bridge = _bridge.copyWith(choice: c, offerAuto: false);
    notifyListeners();
    _bridgeApply?.cancel();
    if (c != was) {
      _bridgeApply = Timer(AppState.bridgeApplyAfter, applyBridgeNow);
    }
    await _writeBridgeSetup(_bridge);
  }

  /// lines from a friend: the engine reads them, and when one is good they
  /// are kept and used at once. what it made of each line comes back
  Future<FriendLines> useFriendLines(String text) async {
    final lines = bridgeLinesFrom(text);
    if (lines.isEmpty || inDecoyView) return FriendLines.none(lines.length);
    final r = engine.setBridgeMode('own', jsonEncode({'lines': lines}));
    final checks = BridgeLineCheck.parse(engine.bridgeLineChecks());
    if (r != 'ok') {
      dlog('bridges: friend lines: $r');
      return FriendLines(false, lines.length, checks);
    }
    _bridgeApply?.cancel();
    _lineChecks = checks;
    _checksOf = BridgeChoice.friend;
    _bridge = _bridge.copyWith(
      choice: BridgeChoice.friend,
      friendLines: lines.join('\n'),
      offerAuto: false,
    );
    _newRoute();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
    return FriendLines(true, lines.length, checks);
  }

  /// one kept line goes. with none left the friend's card hands over to
  /// automatic. what was there before and after comes back, for an undo
  Future<(BridgeSetup, BridgeSetup)?> removeBridgeLine(
    BridgeChoice from,
    int i,
  ) async {
    final before = _bridge;
    final ls = splitBridgeLines(
      from == BridgeChoice.friend
          ? _bridge.friendLines
          : _bridge.torProjectLines,
    );
    if (i < 0 || i >= ls.length) return null;
    ls.removeAt(i);
    _bridge = from == BridgeChoice.friend
        ? _bridge.copyWith(friendLines: ls.join('\n'))
        : _bridge.copyWith(torProjectLines: ls.join('\n'));
    if (_checksOf == from) _lineChecks = const [];
    if (_bridge.choice == from) {
      if (ls.isEmpty) _bridge = _bridge.copyWith(choice: BridgeChoice.auto);
      applyBridgeNow();
    }
    final after = _bridge;
    notifyListeners();
    await _writeBridgeSetup(_bridge);
    return (before, after);
  }

  static bool _sameSetup(BridgeSetup a, BridgeSetup b) =>
      a.choice == b.choice &&
      a.friendLines == b.friendLines &&
      a.torProjectLines == b.torProjectLines &&
      a.consent == b.consent &&
      a.skipDirect == b.skipDirect &&
      a.country == b.country;

  // the lines tor uses under a setup, or null for none
  static String? _linesInUse(BridgeSetup b) => switch (b.choice) {
    BridgeChoice.friend => b.friendLines,
    BridgeChoice.torProject => b.torProjectLines,
    _ => null,
  };

  /// the undo of a removed line. refused once anything changed since, and
  /// tor bounces only when the lines it uses come back
  Future<bool> putBridgeSetupBack(BridgeSetup before, BridgeSetup after) async {
    if (inDecoyView || !_sameSetup(_bridge, after)) return false;
    final again =
        before.choice != after.choice ||
        _linesInUse(before) != _linesInUse(after);
    _bridge = before;
    if (again) applyBridgeNow();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
    return true;
  }

  /// may automatic ask the tor project: yes or no
  Future<void> setBridgeConsent(bool yes) async {
    if (inDecoyView) return;
    _bridge = _bridge.copyWith(consent: yes ? 'yes' : 'no');
    if (_bridge.choice == BridgeChoice.auto) applyBridgeNow();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  Future<void> setBridgeCountry(String cc) async {
    if (inDecoyView) return;
    _bridge = _bridge.copyWith(country: cc);
    if (_bridge.choice == BridgeChoice.auto) applyBridgeNow();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  /// a soft no: the offer comes back once, a week on
  Future<void> dismissAutoOffer() async {
    _offerRaw = _offerSecond
        ? '0'
        : 'again:${DateTime.now().add(AppState.offerAgainAfter).millisecondsSinceEpoch}';
    _bridge = _bridge.copyWith(offerAuto: false);
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  /// automatic gave up: try again now
  void bridgeRetry() {
    if (inDecoyView) return;
    engine.bridgeRetry();
    _newRoute();
  }

  @visibleForTesting
  void retryStuckAuto({DateTime? now}) {
    if (inDecoyView || _sendMode != 'private' || !_online || _torHeld) return;
    if (_bridge.choice != BridgeChoice.auto) return;
    final s = _bridgeStatus;
    final held =
        s.phase == 'trying' &&
        !s.canSend &&
        const {'pt_failed', 'not_applied', 'no_mode'}.contains(s.errorCode);
    if (s.mode != 'auto' || !(s.exhausted || held)) return;
    final at = now ?? DateTime.now();
    final last = _stuckRetryAt;
    if (last != null && at.difference(last) < AppState.stuckRetryGap) return;
    _stuckRetryAt = at;
    _stuckLookUntil = null;
    dlog('bridges: stuck on coming back, trying again');
    bridgeRetry();
  }

  // never over hidden chats either, and never once tor is in: the ask can
  // wait a long while behind onboarding
  bool get bridgeAskDue =>
      _askDue && !_askShown && !_torIn && !inDecoyView && !lockState.inVault;
  bool get _torIn =>
      _bridgeStatus.phase == 'connected' || _bridgeStatus.canSend || torUsable;
  void bridgeAskTaken() => _askShown = true;
  void bridgeAskAgain() => _askShown = false;

  /// the answer on the tor-is-blocked sheet. yes lets automatic ask the
  /// tor project and puts automatic on; a no on the one-time sheet is final
  Future<void> answerBridgeAsk(bool yes, {bool asked = false}) async {
    if (inDecoyView) return;
    if (!yes) {
      if (asked && _bridge.consent == 'ask') {
        _bridge = _bridge.copyWith(consent: 'no');
        await _writeBridgeSetup(_bridge);
      }
      return;
    }
    _bridge = _bridge.copyWith(
      consent: 'yes',
      choice: BridgeChoice.auto,
      offerAuto: false,
    );
    applyBridgeNow();
    if (_bridgeStatus.exhausted) engine.bridgeRetry();
    notifyListeners();
    await _writeBridgeSetup(_bridge);
  }

  String? get moatGuess => _moatGuess;

  /// asked only when the person picks the tor project's guess, and only
  /// over meek with the yes: through tor the guess would be the exit
  /// relay's country, so with tor up there is no guess, only the list
  Future<String?> askMoatGuess() async {
    if (inDecoyView || torUsable || _bridge.consent != 'yes') return null;
    try {
      final m = jsonDecode(await engine.moatSettings(''));
      final cc = m is Map ? m['country'] : null;
      if (m is Map && m['ok'] == true && cc is String && cc.length == 2) {
        _moatGuess = cc.toLowerCase();
        notifyListeners();
      }
    } catch (e) {
      dlog('bridges: no country guess (${e.runtimeType})');
    }
    return _moatGuess;
  }

  /// the engine's status line facts, read with tor's status each second
  @visibleForTesting
  void takeBridgeStatus(String raw) {
    final s = BridgeStatus.parse(raw);
    _bridgeSinceMs = s.sinceMs;
    if (s == _bridgeStatus) return;
    final was = _bridgeStatus;
    _bridgeStatus = s;
    if (s.phase == 'connected' || s.canSend) {
      _askDue = false;
    } else if (s.askConsent && _bridge.consent == 'ask') {
      _askDue = true;
    }
    // what automatic learnt is kept once something gets through
    if (s.phase == 'connected' && was.phase != 'connected') {
      unawaited(_keepBridgeMemory());
    }
    final look = _stuckLookUntil;
    if (look != null) {
      if (DateTime.now().isAfter(look)) {
        _stuckLookUntil = null;
      } else {
        retryStuckAuto();
      }
    }
    notifyListeners();
  }

  Future<void> _keepBridgeMemory() async {
    if (inDecoyView || !_memIn) return;
    const st = secureStore;
    final mem = engine.autoMemory();
    if (!mem.contains('"error"')) {
      await st.write(key: 'bridge_auto_mem', value: mem);
    }
    final cache = engine.bridgeCache();
    if (!cache.contains('"error"')) {
      await st.write(key: 'bridge_cache', value: cache);
    }
  }
}
