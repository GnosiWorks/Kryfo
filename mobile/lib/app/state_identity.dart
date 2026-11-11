// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the identity: regenerate, move, onboarding

part of '../main.dart';

extension AppStateIdentity on AppState {
  // the keys a backup carries: the ones this start holds, never the engine's
  ({String ed, String x}) get mainKeysForBackup =>
      _mainKeys ?? (throw StateError('no identity yet'));

  /// a restore replaced the identity: its keys are known again only after
  /// the restart
  void mainKeysReplaced() => _mainKeys = null;

  Future<void> regenerateIdentity() => _regenerating ??= _regenerateIdentity()
      .whenComplete(() => _regenerating = null);

  Future<void> _regenerateIdentity() async {
    if (sessionQuiet) return;
    // a first signal boot still running ends on the old key, then all that
    // is made from the key is made again from the new one
    await _signalBoot;
    myId = engine.generateIdentity();
    _mainKeys = (ed: engine.myEdPrivkey(), x: engine.myXPrivkey());
    await live.saveIdentity(myId, _mainKeys!.ed, _mainKeys!.x);
    myXPub = engine.myXPubkey();
    restored = false;
    if (signalSession.ready) await _rekeySignal();
    // kept openers were made for the old key and open no more
    await _forgetAllFirst();
    // the invite address is derived from the key too
    if (_fcLoaded) unawaited(_listenFirstContact());
    notifyListeners();
  }

  Future<void> _rekeySignal() async {
    try {
      final database = await live.open();
      final xpb = _hexDecode(_mainKeys!.x);
      await signalSession.rekey(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb);
    } catch (e) {
      // the next start bootstraps on the saved key
      dlog('signal rekey failed (${e.runtimeType})');
    }
  }

  // [fresh]: the user just added or accepted them
  Future<void> subscribePeer(String haloId, {bool fresh = false}) async {
    // an add or an accept: a kept opener of theirs may file now
    unawaited(retryFirsts(all: true));
    // the dev chat listens on its own lane, and only once it runs
    if (isDevId(haloId)) return subscribeDevLane();
    // the row xpub is set by v1 pairing and is there before any session
    // exists; v2 bundle pairing leaves it empty and puts the key in the
    // signal store instead. try both, backfill the row when we learn it.
    // a hidden chat's row is in the open vault. someone blocked is heard
    // too while the block is young, and what they send is dropped as it
    // comes
    final d = _ownerOf(haloId);
    if (await d.isBlocked(haloId)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = await d.blockedRows(now: now);
      if (!rows.any((r) => r['halo_id'] == haloId && r['listen'] == 1)) {
        return;
      }
    }
    // linked devices: my list to them now
    if (fresh) unawaited(_devAdded(haloId));
    var xPub = await d.contactXPub(haloId);
    if (xPub == null || xPub.isEmpty) {
      xPub = await peerXPubOf(haloId);
      if (xPub != null && xPub.isNotEmpty) {
        await d.setContactXPub(haloId, xPub);
      }
    }
    if (xPub == null || xPub.isEmpty) return;
    _xPubToHaloId[xPub] = haloId;
    if (fresh) desk_trace.trace('listening on an added chat');
    _listen(identOf(haloId), xPub, fresh: fresh);
    // the chat on screen whose key was not known when it opened
    if (haloId == _firstChat) unawaited(_tellFirst());
  }

  // a backup reads the databases while no hide, show or close runs, so its
  // copies agree and a vault shut on the way shuts after it, never half
  // way through. the vault is the session's open one, or with made the one
  // a setup just made; null when there is none at hand
  Future<T> backupStill<T>(
    Future<T> Function(HaloDb? vault) work, {
    bool made = false,
  }) => _serial(() => work(made ? _madeVault : _session.vault));

  // the export that moved this identity writes the mark; the moved screen
  // clears it when the person says they are not moving after all
  Future<void> markMoved() async {
    // a decoy is never moved
    if (sessionQuiet) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('moved.at', DateTime.now().millisecondsSinceEpoch);
    _movedAway = true;
    notifyListeners();
    // the identity lives elsewhere now: the helper app lets go
    unawaited(_forgetOnMove());
  }

  // the helper app lets go of every endpoint, so the relay's next knock
  // finds each one gone. no forget is sent: a burst of them would tie this
  // phone's mailboxes together
  Future<void> _forgetOnMove() async {
    try {
      if (knockMode(_deliveryMode)) {
        await setDeliveryMode(DeliveryMode.checkins);
      }
      await _helperOp(() => helper.dropForgets());
    } catch (e) {
      dlog('helper: forgets on move (${e.runtimeType})');
    }
  }

  // the person chose to keep this phone to read. this session only: the
  // mark stays and the next launch asks again
  void keepMovedToRead() {
    movedReadOnly = true;
    notifyListeners();
  }

  Future<void> unmarkMoved() async {
    // a decoy is never moved
    if (sessionQuiet) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('moved.at');
    _movedAway = false;
    movedReadOnly = false;
    notifyListeners();
  }

  Future<void> markOnboardingComplete() async {
    onboardingComplete = true;
    await secureStore.write(key: 'onboarding_done', value: 'true');
    // onboarding asked how messages reach this phone: no card about it later
    if (_googleOffer.isEmpty) {
      _googleOffer = 'said';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kGoogleOfferKey, 'said');
    }
    // words and files shared while the app was being set up are let go,
    // not held for the home that comes next
    final shared = await ToolsBridge.instance.peekSharedText();
    if (shared != null) await ToolsBridge.instance.dropSharedText(shared.id);
    final files = await ToolsBridge.instance.peekSharedFiles();
    if (files != null) await ToolsBridge.instance.dropSharedFiles(files.id);
    notifyListeners();
  }
}
