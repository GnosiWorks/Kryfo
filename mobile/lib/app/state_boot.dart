// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the start of a run

part of '../main.dart';

extension AppStateBoot on AppState {
  // a window is not the same as a person: samsung relaunches a recently used
  // app's activity, unseen, right after its data is cleared, and booting then
  // would make a fresh identity out of a panic wipe. a phone that has been
  // set up boots at once; one with nothing yet waits until the app is in
  // front of someone.
  Future<void> bootWhenWanted() async {
    dlog(
      'launch lifecycle at boot request: '
      '${WidgetsBinding.instance.lifecycleState}',
    );
    if (await bootsNow(_hasLocalData)) {
      await boot();
      return;
    }
    // no await from the last state read to here: a resume cannot slip between
    if (_seen != null) return;
    dlog('launch nothing here and not in front: boot waits');
    _seen = AppLifecycleListener(
      onResume: () {
        _seen?.dispose();
        _seen = null;
        dlog('launch in front now, booting');
        unawaited(boot());
      },
    );
  }

  Future<void> boot() async {
    try {
      await _boot();
    } catch (e, st) {
      dlog('boot failed: $e\n$st');
      bootError = e.toString();
      bootStuck = e is KeyStoreStuck;
      _booting = false;
      // both deep link handlers wait on this
      if (!_signalReady.isCompleted) _signalReady.complete();
      notifyListeners();
    }
  }

  // clears the error and runs the whole thing again. the failure may well be
  // permanent, but retrying costs nothing and beats a force-stop.
  Future<void> retryBoot() async {
    bootError = null;
    bootStuck = false;
    notifyListeners();
    await boot();
  }

  // the rows go now, their files in the background as above
  Future<void> _dropGroupLeftovers(HaloDb d) async {
    // an ended group's wipe a stop cut short finishes here
    try {
      await d.finishEndedWipes(unshade: _io.unnotifyGone);
    } catch (e) {
      dlog('groups: ended ones not swept (${e.runtimeType})');
    }
    try {
      final files = await d.dropGroupLeftovers();
      if (files.isEmpty) return;
      dlog('groups: ${files.length} files of groups no longer here');
      unawaited(() async {
        for (final f in files) {
          await shredFile(f);
        }
      }());
    } catch (e) {
      dlog('groups: leftovers not swept (${e.runtimeType})');
    }
  }

  // which files go is settled here; the zeros are written after, in the
  // background: nothing names these files, so nothing can reach them
  // [d]: a vault or the decoy's container as it opens, else the everyday one.
  // a voice note's wav or a half made opus copy a stop left goes this way.
  // [vaultOpen]: the decoy's, now its own vault is open (sweepableMedia)
  Future<void> _sweepUnnamedMedia(
    DateTime before, [
    HaloDb? d,
    bool vaultOpen = false,
  ]) async {
    try {
      final gone = [
        ...await sweepableMedia(
          d ?? live,
          before: before,
          vaultOpen: vaultOpen,
        ),
        // and what a fetch dropped while the app was gone left in its
        // folder, held back as the media is
        ...await _strayFetches(d ?? live, vaultOpen),
      ];
      if (gone.isEmpty) return;
      dlog('media: ${gone.length} files no message names');
      unawaited(() async {
        for (final f in gone) {
          await shredFile(f.path);
        }
      }());
    } catch (e) {
      dlog('media: not swept (${e.runtimeType})');
    }
  }

  Future<List<File>> _strayFetches(HaloDb d, bool vaultOpen) async {
    if (restoreRunning || backupRunning) return const [];
    if (d.container == HaloContainer.decoy &&
        !vaultOpen &&
        await HaloContainer.decoyVault.onDisk()) {
      return const [];
    }
    final db = await d.open();
    final named = {
      for (final r in await db.query('file_fetches', columns: const ['path']))
        r['path'] as String,
    };
    final media = await d.container.mediaDir();
    return [
      ...await strayFetchFiles(media, named),
      ...await staleHeldFiles(media, DateTime.now()),
    ];
  }

  // as for media: settled here, zeroed in the background
  Future<void> _sweepUnnamedWallpapers(
    HaloDb d,
    DateTime before, {
    bool vaultOpen = false,
  }) async {
    try {
      final gone = await tidyWallpapers(
        d,
        before: before,
        vaultOpen: vaultOpen,
      );
      if (gone.isEmpty) return;
      dlog('wallpaper: ${gone.length} files no chat names');
      unawaited(() async {
        for (final f in gone) {
          await shredFile(f.path);
        }
      }());
    } catch (e) {
      dlog('wallpaper: not swept (${e.runtimeType})');
    }
  }

  // a move a crash cut short put right, as its list entry says, then the
  // files no message names any more go, before anything here can move or
  // write one. with a move still open the rows may be on the other side,
  // so nothing goes. a file from the last minutes may be one another start
  // of the app is still filing
  @visibleForTesting
  Future<void> tidyAtStart(DateTime bootAt) async {
    try {
      await repairVaultMoves();
    } catch (e) {
      dlog('vault: repair left for the next start (${e.runtimeType})');
      return;
    }
    await _dropGroupLeftovers(live);
    await _sweepUnnamedMedia(bootAt.subtract(const Duration(minutes: 10)));
    await _sweepUnnamedWallpapers(
      live,
      bootAt.subtract(const Duration(minutes: 10)),
    );
  }

  Future<void> _boot() async {
    dlog('launch boot');
    final bsw = Stopwatch()..start();
    final bootAt = DateTime.now();
    // both _OnboardingGate and _RootShell call boot() on cold start, before
    // ready flips, and must not race through generateIdentity and db open
    if (ready || _booting) return;
    _booting = true;
    // let the splash paint one frame before any heavy native call. sqlcipher
    // key derivation + the first go ffi hop block the ui thread long enough
    // to trip the anr watchdog on weak phones.
    await Future.delayed(const Duration(milliseconds: 16));
    dlog('launch boot after yield');
    unawaited(_openContainers());
    final docsDir = await getApplicationDocumentsDirectory();
    final saved = await live.loadIdentity();
    dlog('launch identity loaded');
    // a decoy left open by the run before: held until a pin says otherwise.
    // read once the store has answered for the database key
    await readDecoyMark();
    // the hidden chats' list, before anything can arrive: without it an
    // arrival for one would land in the everyday container
    await _router.load();
    await tidyAtStart(bootAt);
    if (saved != null) {
      _mainKeys = (ed: saved['ed_priv']!, x: saved['x_priv']!);
      myId = engine.restoreIdentity(_mainKeys!.ed, _mainKeys!.x);
      restored = true;
    } else {
      myId = engine.generateIdentity();
      _mainKeys = (ed: engine.myEdPrivkey(), x: engine.myXPrivkey());
      await live.saveIdentity(myId, _mainKeys!.ed, _mainKeys!.x);
    }
    myXPub = engine.myXPubkey();
    dlog('boot identity +${bsw.elapsedMilliseconds}ms');
    bootPhase = l10n.appOpeningYourChats;
    notifyListeners();
    _appLinks = AppLinks();
    // a link carries a prekey bundle, and taking one needs the signal
    // store, which boots after the home paints. both handlers wait for it.
    _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme != 'kryfo') return;
      await _outsideLink(uri, 'deep link');
    });
    // the stream only fires while we're already running. a link tapped with
    // kryfo closed cold-starts the app and would otherwise be dropped.
    unawaited(
      _appLinks
          .getInitialLink()
          .then((uri) async {
            if (uri == null || uri.scheme != 'kryfo') return;
            await _outsideLink(uri, 'deep link (cold start)');
          })
          .catchError((Object e) {
            dlog('deep link (cold start) failed: $e');
          }),
    );

    await refreshContacts();
    dlog('boot contacts +${bsw.elapsedMilliseconds}ms');
    await refreshGroups();
    dlog('boot groups +${bsw.elapsedMilliseconds}ms');
    // paint the home as soon as contacts/groups are ready; notifications,
    // nostr subscriptions keep warming up in the background.
    onboardingComplete =
        (await keyStoreCall(() => secureStore.read(key: 'onboarding_done'))) ==
        'true';
    _movedAway =
        (await SharedPreferences.getInstance()).getInt('moved.at') != null;
    // let the onion linger a beat before the home appears
    if (onboardingComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await markReady();
    bootPhase = l10n.appStartingTor;
    dlog('boot ready +${bsw.elapsedMilliseconds}ms');
    notifyListeners();
    // moved away: home can show what was here, and that is all. no tor,
    // no relays, no outbox. see movedAway.
    if (_movedAway) {
      bootPhase = '';
      if (!_signalReady.isCompleted) _signalReady.complete();
      _booting = false;
      notifyListeners();
      return;
    }
    // signal prekey gen is cpu-heavy (~5s on a fresh identity) and nothing
    // above needs it, so it waits until the home paints. tor + nostr also
    // start after this, and both take longer to warm than the prekeys, so
    // the session is ready well before any message can arrive.
    _signalBoot = _bootSignal().whenComplete(() {
      dlog('boot signal (deferred) done');
      if (!_signalReady.isCompleted) _signalReady.complete();
      // a row kept as it came needs signal to open
      if (signalSession.ready) unawaited(letHeldIn(live));
    });
    // outbox drainer: anything the wire never confirmed gets re-sent for the
    // life of the app, whatever screen you're on and across restarts.
    startOutboxDrain();
    // files moving show in the shade and keep the process up while they do
    if (!onDesktop) TransferNote.instance.start();
    // a chat opened now draws its waiting files as such
    unawaited(_loadFileWaits());
    await _loadBridges();
    // drop week-old partial transfers nobody ever completed.
    unawaited(live.sweepMediaChunks());
    _deliveryMode = await loadDeliveryMode();
    // drafts an older version wrote down for a restart, into their rows
    await restoreKeptDrafts(live).catchError((Object e) {
      dlog('drafts: not restored (${e.runtimeType})');
    });
    // a timed chat's draft that ran out while the app was stopped goes
    await sweepDrafts(live);
    // read now, so settings shows it whole from the first frame
    unawaited(loadHideNotifContent());
    // in front means resumed, not that a view exists: android hands every
    // engine an implicit view, window or not
    _inFront =
        _inFront ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    await _judgeLastRun();
    // a knock comes as a job (HaloPeriodicJobService), whatever mode is
    // set. an endpoint that arrives is registered with the relay
    HelperPush.instance.onChange = () => _helperSoon();
    HelperPush.instance.listen();
    // google push hands the slots their endpoints in its mode (play only)
    GooglePush.instance.seal ??= engine.pushSeal;
    GooglePush.instance.onChange = () => _helperSoon();
    if (playBuild) GooglePush.instance.listen();
    // the tip jar hears of payments the sheet closed on (play only)
    if (kPlayBuild) TipJar.instance.listen();
    if (_deliveryMode == DeliveryMode.google) {
      helper.usePush(GooglePush.instance);
    }
    unawaited(_loadHelper());
    await _loadDeliveryTimes();
    // a linked device's tor runs as a client: told before it starts
    await torAsLinked(at: 'boot');
    // start tor last: nothing above needs it, and earlier it stalls the main
    // thread while tor bootstraps. a process the fifteen-minute job started,
    // with no window, in a mode that sleeps between checks leaves tor down;
    // the job's own check-in brings it up for its minute.
    if (_deliveryMode != DeliveryMode.always && !_inFront) {
      _torHeld = true;
      await engine.torStop();
      _docsPath = docsDir.path;
    } else {
      _docsPath = docsDir.path;
      startEngineIn(docsDir.path, engine.startListenerBg).then((addr) {
        if (addr.isNotEmpty && !addr.startsWith('error')) {
          myOnion = onionOfStart(addr);
          _maybeRepoint();
          notifyListeners();
        }
      });
    }
    // poll bootstrap so the app is not held up while the listener warms up.
    // it runs for the life of the app and doubles as the watchdog.
    var torKickedAt = DateTime.now();
    var ticks = 0;
    var startWatch = true;
    var traceLeft = onDesktop;
    // why a first contact did not file, on a computer's trace: codes only
    if (onDesktop) {
      firstFails.onNote = (c) => desk_trace.trace('first contact: $c');
    }
    var startTicks = 0;
    var autoTicks = 0;
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (haloWiping) return;
      if (_sendMode == 'balanced' && ++ticks % 5 == 0) sampleRelayHealth();
      // the start's steps, read before the status so a ready route never
      // shows ready before it says getting new messages: whether the new
      // messages are in, and on a computer the trace's lines. watched until
      // both are done, ten minutes at most
      if (startWatch || traceLeft) {
        try {
          if (startWatch) takeStartCaught(engine.startCaught());
          if (traceLeft) {
            for (final l in engine.startSteps()) {
              desk_trace.trace(l);
            }
          }
        } catch (_) {
          startWatch = traceLeft = false;
        }
        if (_startCaught && (_everUsable || _sendMode != 'private')) {
          startWatch = false;
        }
        // the trace goes on for the life of the app: a first contact
        // later is traced as it comes
        if (++startTicks >= 600) startWatch = false;
        if (!startWatch && !_startCaught) takeStartCaught(true);
      }
      final st = takeTorStatus(engine.getStatus());
      takeBridgeStatus(engine.bridgeStatus());
      flushOnRouteUp();
      if (++autoTicks % 15 == 0) unawaited(autoRestart.tick());
      // tor died or never came up in this process. nothing else
      // restarts it, so we do. throttled: a start takes a while.
      if (st == TorStatus.off &&
          !_torHeld &&
          DateTime.now().difference(torKickedAt).inSeconds > 45) {
        torKickedAt = DateTime.now();
        dlog('tor watchdog: tor off, restarting listener');
        startEngineIn(docsDir.path, engine.startListenerBg).then((addr) {
          if (addr.isNotEmpty && !addr.startsWith('error')) {
            myOnion = onionOfStart(addr);
            notifyListeners();
          }
        });
      }
    });
    _initConnectivity();
    // back in front: the first-contact listener is looked at again
    _fcResume ??= AppLifecycleListener(onResume: checkFirstListener);
    // read the saved mode before anything touches the network, tell the
    // engine, and pick the matching relay list. doing this after would start
    // every session on tor regardless of what the person chose.
    await loadSendMode();
    await loadMyHandle();
    await loadMyAvatar();
    // 'normal' was the old name for private. migrating here rather than on
    // the modes screen means the rest of the app never sees it.
    if (_sendMode == 'normal') await setSendMode('private');
    engine.setTransportMode(_sendMode);
    _engineMode = _sendMode;
    dlog('transport: booting in $_sendMode');
    // only takes a lock in the engine, so it is set right here, before the
    // first-contact runner: that snapshots the list on start and gives up
    // if it is empty.
    engine.nostrInit(relaysFor(_sendMode));
    _loadFirstContact();
    await loadScreenSecure();
    await loadTypingPref();
    await loadHeartbeat();
    startMemoryLog();
    await initNotifications(
      onTap: openChatForNotif,
      tagsOf: (chat) => session.notifTagsOf(chat),
      forget: ({chat, msgUid}) =>
          session.forgetRings(chat: chat, msgUid: msgUid),
    );
    // the first call into android's notification service after a start is
    // slow, a tenth of a second or more. every start pays it here, so
    // nothing later pays it where it could be timed
    // a warm-up only: an id that was never shown, and no answer wanted
    unawaited(notifPlugin.cancel(id: 0x7ffffffe).catchError((_) {}));

    unawaited(_fillSearch());
    if (kDebugMode) unawaited(maybeRunSearchBench());
    // periodic sweep: delete messages whose burn_at has passed. a sweep
    // that keeps failing means burned messages are staying, which the
    // user was promised would not happen, so after a minute of it say so
    var sweepFails = 0;
    var sweeps = 0;
    Timer.periodic(const Duration(seconds: 5), (_) async {
      if (haloWiping) return;
      // hourly: a block grown old is listened on no more
      if (++sweeps % 720 == 0) unawaited(unlistenOldBlocks());
      // each minute: the first-contact listener is on a relay, and our
      // openers with no receipt go again as they fall due
      if (sweeps % 12 == 0) {
        checkFirstListener();
        unawaited(sendOpenersAgain());
      }
      try {
        final gone = await sweepBurns(stray: sweeps % 12 == 0);
        sweepFails = 0;
        // a row whose newest message just burned needs a new preview. a
        // decoy shut while its files are swapped is not read
        if (gone > 0 && session.primary.isOpen) {
          unawaited(refreshContacts());
          unawaited(refreshGroups());
        }
      } catch (e) {
        sweepFails++;
        dlog('burn sweep failed ($sweepFails): $e');
        if (sweepFails == 12) {
          final ctx = rootNavKey.currentContext;
          if (ctx != null && ctx.mounted) {
            showHaloToast(ctx, l10n.appTimedMessagesAreNot);
          }
        }
      }
    });
    listenAtStart();
    // once after the update: each group's admin hears what this app can
    unawaited(_announceCaps(live));
    // what the removed ntfy mode left behind in the prefs
    unawaited(forgetNtfy());

    // continuous drain of direct-onion inbox. handles back-
    // pair from strangers + falls back to trial-decrypt against known
    // contacts for in-session direct-onion messages.
    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // while the vault is open, what came sealed goes in, a tick at a time
      unawaited(_unseal());
      // reentrancy guard: the ffi drain + decrypt can outrun the 1s tick,
      // and stacked calls pin the main thread hard enough to anr on weak
      // phones. no tor gate here: the bytes are already in the go inbox and
      // opening them needs nothing from the network.
      if (_draining) return;
      _draining = true;
      try {
        final ciphers = engine.drainInbox();
        if (ciphers.isEmpty) return;
        await receiveOnion(ciphers);
      } finally {
        _draining = false;
      }
    });

    Timer.periodic(const Duration(seconds: 1), (_) async {
      if (haloWiping) return;
      // same as the onion drain above: the relay queue is already on this
      // phone, so it is read whatever tor is doing
      if (_polling) return;
      _polling = true;
      _beat();
      try {
        final batch = engine.nostrPoll();
        if (batch.token.isEmpty) return;
        // not confirmed when this throws: the next poll offers it again
        final held = <int, String>{};
        final failed = await receiveRelay(
          batch.msgs,
          written: batch.written,
          reached: batch.reached,
          held: held,
        );
        final keys = held.keys.toList()..sort();
        final r = engine.nostrAck(
          batch.token,
          failedPlaces(batch, failed),
          held: failedPlaces(batch, keys),
          groups: [for (final k in keys) held[k]!],
        );
        if (r != 'ok') dlog('relay poll: ack $r');
      } finally {
        _polling = false;
      }
    });
    final stored = await secureStore.read(key: 'onboarding_done');
    onboardingComplete = stored == 'true';
    ready = true;
    notifyListeners();
  }

  Future<void> _bootSignal() async {
    try {
      final database = await live.open();
      final prefs = await SharedPreferences.getInstance();
      restoreLandedAt = restoreLandedOf(prefs);
      final after = prefs.getInt(kRestoreAfterPref);
      final from = after != null && after > 0 ? after : null;
      // before any store or drain can send: what of ours the file still
      // had waiting waits for a tap
      if (after != null) {
        await holdOutboxAfterRestore(
          database,
          landed: restoreLandedAt,
          made: from,
        );
      }
      // linked devices go before anything can seal to them, and every other
      // identity's sessions are marked before the store is ready
      var marked = true;
      if (after != null) {
        await restoreCutsLinkedDevices(database);
        marked = await markRestoredIdentities(database, from: from);
      }
      final xpb = _hexDecode(_mainKeys!.x);
      await openSignalStore(
        signalSession,
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: xpb,
      );
      _zeroBytes(xpb); // priv bytes consumed by bootstrap, wipe from ram
      // cleared only once every identity was done: a failure runs it all
      // again on the next start
      if (after != null && await afterRestore(database) && marked) {
        await prefs.remove(kRestoreAfterPref);
      }
      // linked devices, before any message opens (switch off: nothing)
      await bootDevices();
      // a history copy under way goes on where it was
      resumeHistoryCopies();
    } catch (e, st) {
      dlog('signal bootstrap failed: $e\n$st');
    }
  }

  Uint8List _hexDecode(String s) {
    final bytes = Uint8List(s.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
