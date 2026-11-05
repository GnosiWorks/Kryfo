// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the open session: decoy, vault sessions and the lock

part of '../main.dart';

extension AppStateSession on AppState {
  // a decoy sees automatic and the status line, and nothing of how
  bool get inDecoyView => lockState.inDecoy || sessionQuiet;
  bool get movedAway => !sessionQuiet && _movedAway;
  String get sessionId => sessionQuiet ? (_quiet?.id ?? '') : myId;
  String get sessionOnion => sessionQuiet ? (_quiet?.onion ?? '') : myOnion;
  String get sessionXPub =>
      sessionQuiet ? (_quiet?.xPub ?? '') : engine.myXPubkey();
  String get sessionEdPub =>
      sessionQuiet ? (_quiet?.edPub ?? '') : engine.myEdPubkey();
  String get pairBox => (_session.vault ?? _session.primary).container.id;
  // the link and QR code that say who you are
  Future<String> sessionInvite() async =>
      sessionQuiet ? (_quiet?.invite ?? '') : _everydayInvite();

  /// what the own qr code shows: the main v4 invite without its bundle
  /// (288 bytes; a reader answers it with a hello), else the link
  Future<String> sessionInviteQr() async {
    if (sessionQuiet) {
      final qr = _quiet?.qr;
      if (qr != null) return qr;
    } else {
      try {
        final qr = await myV4Invite(qr: true);
        if (qr != null) return qr;
      } catch (e) {
        dlog('invite: no v4 qr (${e.runtimeType})');
      }
    }
    return sessionInvite();
  }

  // a counter that did not read is never taken as 0: an invite to an
  // address nobody listens on loses every first message sent to it
  // the main v4 invite once it is made (identity v4 2.1)
  Future<String> _everydayInvite() async {
    try {
      final v4 = await myV4Invite();
      if (v4 != null) return v4;
    } catch (e) {
      dlog('invite: no v4 link (${e.runtimeType})');
    }
    return _fcUnread
        ? buildHaloUriV2(myId, myOnion)
        : buildHaloUriV3(myId, myOnion, fcCounter);
  }

  Future<void> get containersReady => _containersOpen.future;
  @visibleForTesting
  void containersOpenedForTest() => _containersOpen.complete();
  // for the everyday session's own App lock screen
  bool get hasDecoy => !sessionQuiet && _decoyDb != null;

  Future<_Shown> _shownOf(Session s) async {
    final (list, pending, dev) = await _contactsOf(s);
    final a = await secureStore.read(key: s.container.key('my_avatar'));
    // the decoy's own note of the computer lock row, with its lists: the
    // row then shows at once whatever was set there
    if (s.primary.container.quiet && computerLock != null) {
      computerLock?.decoyNoteRead(
        await SqlRouterStore(s.primary.open).meta(kComputerDecoyNote),
      );
    }
    return _Shown(
      list,
      pending,
      await _groupsOf(s),
      int.tryParse(a ?? ''),
      dev,
      await _photoBookOf(
            s,
            s.primary.container.quiet ? (_decoyId?.id ?? '') : myId,
          ) ??
          const {},
    );
  }

  Future<void> _openContainers() async {
    keepComputerDecoyNote = _keepDecoyNote;
    try {
      final listed = await listedContainers();
      await sweepContainers(listed, pinTable: await pinTableKept());
      if (listed.contains(HaloContainer.decoy.id)) {
        final d = HaloDb(HaloContainer.decoy);
        final q = await _quietOf(d);
        if (q != null) {
          await _dropGroupLeftovers(d);
          final before = DateTime.now().subtract(const Duration(minutes: 10));
          await _sweepUnnamedWallpapers(d, before);
          await _sweepUnnamedMedia(before, d);
          _decoyDb = d;
          _decoyId = q;
          _otherShown = await _shownOf(Session(d));
        } else {
          await d.close();
        }
      }
    } catch (e) {
      dlog('containers: not opened ($e)');
    } finally {
      decoyReady = _decoyDb != null;
      if (!_containersOpen.isCompleted) _containersOpen.complete();
    }
  }

  // what the decoy's identity shows, from its own keys, with an invite on
  // its own signal store. nothing here touches the engine's identity.
  // [freshInvite]: its main invite made again now, as a reset does
  Future<QuietIdentity?> _quietOf(HaloDb d, {bool freshInvite = false}) async {
    final raw = await d.open();
    final saved = await d.loadIdentity();
    // a restore made in the decoy leaves its onion key beside the database
    final left = File(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'onion${d.container.suffix}.key',
      ),
    );
    if (await left.exists()) {
      final hex = (await left.readAsBytes())
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await raw.insert('signal_meta', {
        'k': 'onion_key',
        'v': hex,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await shredFile(left.path);
    }
    final rows = await raw.query(
      'signal_meta',
      where: 'k = ?',
      whereArgs: ['onion_key'],
      limit: 1,
    );
    if (saved == null || rows.isEmpty) return null;
    final x = saved['x_priv']!;
    final q = engine.quietDescribe(
      saved['ed_priv']!,
      x,
      rows.first['v'] as String,
    );
    if (q == null) return null;
    final ss = SignalSession();
    final xb = _hexDecode(x);
    await ss.bootstrap(
      database: raw,
      xPubBytes: _hexDecode(q['x_pub'] as String),
      xPrivBytes: xb,
    );
    _zeroBytes(xb);
    final id = q['id'] as String;
    final onion = q['onion'] as String;
    String invite;
    String? qr;
    try {
      final row = await _decoyInvite(
        raw,
        ss,
        edPriv: saved['ed_priv']!,
        edPub: q['ed_pub'] as String,
        onion: onion,
        fresh: freshInvite,
      );
      invite = inviteLink(row.link);
      qr = inviteLink(row.qr!);
    } catch (e) {
      dlog('decoy: no v4 invite (${e.runtimeType})');
      final bundle = await makePreKeyBundleB64(ss);
      final fc = engine.quietFirstContactPk(x, 0);
      invite = quietInviteUri(id, onion, bundle, fc);
    }
    return QuietIdentity(
      id: id,
      edPub: q['ed_pub'] as String,
      xPub: q['x_pub'] as String,
      onion: onion,
      invite: invite,
      qr: qr,
    );
  }

  // the decoy's main v4 invite kept on its own store (identity v4 10, R17),
  // signed with its own face key. read from the everyday side: only when
  // this phone was set up and first ran v4, so its times fit the app's
  Future<InviteRow> _decoyInvite(
    Database raw,
    SignalSession ss, {
    required String edPriv,
    required String edPub,
    required String onion,
    bool fresh = false,
  }) async {
    final onionKey = onionKeyOf(onion);
    if (onionKey == null) throw StateError('no onion key');
    final born = await _decoyBorn(raw);
    final priv = _hexDecode(edPriv);
    try {
      return await keepDecoyInvite(
        raw,
        ss,
        fcPkOf: _fcPkOfKey,
        face: InviteFace(
          onionKey: onionKey,
          face: _hexDecode(edPub),
          sign: (m) => Uint8List.fromList(ed.sign(ed.PrivateKey(priv), m)),
        ),
        bornMs: born,
        v4SinceMs: await _everydayMeta(kMainMadeMeta),
        fresh: fresh,
      );
    } finally {
      _zeroBytes(priv);
    }
  }

  // when the decoy's identity says it was made (R17): once, a random point
  // between when this phone was set up and the decoy's oldest message or
  // its own making, then kept. its identity rows carry it
  Future<int> _decoyBorn(Database raw) async {
    final kept = await raw.query(
      'signal_meta',
      where: 'k = ?',
      whereArgs: [kDecoyBornMeta],
      limit: 1,
    );
    final had = kept.isEmpty ? null : int.tryParse('${kept.first['v']}');
    if (had != null) return had;
    // no later than its own making, nor its oldest message
    final made = await raw.query('identity', columns: ['created_at'], limit: 1);
    var hi = made.isEmpty
        ? DateTime.now().millisecondsSinceEpoch
        : made.first['created_at'] as int;
    final first = await raw.query(
      'messages',
      columns: ['sent_at'],
      orderBy: 'sent_at',
      limit: 1,
    );
    if (first.isNotEmpty) hi = min(hi, first.first['sent_at'] as int);
    final set = await _everydaySetUp() ?? hi;
    final lo = min(set, hi);
    final born = lo + (Random.secure().nextDouble() * (hi - lo)).floor();
    await raw.transaction((t) async {
      await t.update('identity', {'created_at': born});
      await t.update(
        'identities',
        {'created_at': born},
        where: 'id = ?',
        whereArgs: [kMainIdent],
      );
      // the prekeys its store was set up with show the same time; an
      // invite's carry the invite's
      for (final table in const ['signed_prekeys', 'kyber_prekeys']) {
        await t.update(
          table,
          {'created_at': born},
          where: 'invite_id = ?',
          whereArgs: [''],
        );
      }
      await t.insert('signal_meta', {
        'k': kDecoyBornMeta,
        'v': '$born',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return born;
  }

  // when the everyday identity was made on this phone, null unread
  Future<int?> _everydaySetUp() async {
    try {
      final r = await (await live.open()).query(
        'identity',
        columns: ['created_at'],
        limit: 1,
      );
      return r.isEmpty ? null : r.first['created_at'] as int?;
    } catch (_) {
      return null;
    }
  }

  // a value of the everyday signal store's meta as a number, null unread
  Future<int?> _everydayMeta(String k) async {
    try {
      final r = await (await live.open()).query(
        'signal_meta',
        where: 'k = ?',
        whereArgs: [k],
        limit: 1,
      );
      return r.isEmpty ? null : int.tryParse('${r.first['v']}');
    } catch (_) {
      return null;
    }
  }

  // "reset my invite link" in the decoy: its own invite made again now
  Future<void> _resetDecoyInvite() async {
    final d = _decoyDb;
    if (d == null) return;
    final q = await _quietOf(d, freshInvite: true);
    if (q == null) return;
    _decoyId = q;
    if (sessionQuiet) _quiet = q;
  }

  // from the everyday session: a decoy that exists gets the new pin on its
  // own entry. otherwise a new container with an identity of its own,
  // registered nowhere, listed, and its pin entry written last. false when
  // the pin is in use: the screen says pick a different one
  Future<bool> setDecoyPin(String pin) async {
    // a linked device has no decoy: its phone's is the account's
    if (sessionQuiet || linkedRole) return false;
    if (_decoyDb != null) return lockState.setupDecoyPin(pin);
    final d = HaloDb(HaloContainer.decoy);
    try {
      final q = engine.quietIdentity();
      if (q == null) throw StateError('no quiet identity');
      // on desktop a file with no key in storage holds its place: it goes
      // before the decoy's own is made
      if (onDesktop &&
          await secureStore.read(key: HaloContainer.decoy.keyName!) == null) {
        await HaloContainer.decoy.wipeFiles();
      }
      final raw = await d.open();
      await d.saveIdentity(
        q['id'] as String,
        q['ed_priv'] as String,
        q['x_priv'] as String,
      );
      await raw.insert('signal_meta', {
        'k': 'onion_key',
        'v': q['onion_key'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // an everyday finger goes before the list says there is a decoy
      await lockState.parkFingerForDecoy();
      await listContainer(HaloContainer.decoy, true);
      final id = await _quietOf(d);
      if (id == null || !await lockState.setupDecoyPin(pin)) {
        await _dropDecoyFiles(d);
        await lockState.decoyNotMade();
        return false;
      }
      _decoyDb = d;
      _decoyId = id;
      _otherShown = await _shownOf(Session(d));
      decoyReady = true;
      notifyListeners();
      return true;
    } catch (e) {
      // anything but a clash: nothing is left behind, and the flow says so
      dlog('decoy: not made ($e)');
      await _dropDecoyFiles(d);
      await lockState.decoyNotMade();
      rethrow;
    }
  }

  // the pin entries first, then the list, then the files
  Future<void> removeDecoy() async {
    if (sessionQuiet) return;
    await lockState.clearDecoyPins();
    decoyReady = false;
    computerLock?.decoyNoteRead(null);
    final d = _decoyDb ?? HaloDb(HaloContainer.decoy);
    _decoyDb = null;
    _decoyId = null;
    await _dropDecoyFiles(d);
    notifyListeners();
  }

  Future<void> _dropDecoyFiles(HaloDb d) async {
    // a draft waiting to be written would make the file again
    forgetDrafts(HaloContainer.decoy);
    forgetDrafts(HaloContainer.decoyVault);
    await listContainer(HaloContainer.decoy, false);
    await d.close();
    await HaloContainer.decoy.wipeFiles();
    // its vault goes with it: its entry went with the decoy's pins
    await _host.wipeVault(HaloContainer.decoyVault);
  }

  // the decoy's identity as a start reads it, for the tests
  @visibleForTesting
  Future<QuietIdentity?> quietOfForTest(HaloDb d) => _quietOf(d);

  // the decoy [d] open as the session, with [id], and nothing read ahead
  @visibleForTesting
  void decoyOpenForTest(HaloDb d, QuietIdentity id) {
    _decoyDb = d;
    _decoyId = id;
    _quiet = id;
  }

  // tests stand a fake in for the decoy container and its identity
  @visibleForTesting
  Future<void> useDecoyForTest(HaloDb d, QuietIdentity id) async {
    _decoyDb = d;
    _decoyId = id;
    _otherShown = await _shownOf(Session(d));
    decoyReady = true;
  }

  // an unlock's outcome, under the lock screen before it lifts: the screens
  // get the session the pin opened, and every screen of the other one goes
  Future<void> sessionFor(PinResult r, {String? vaultKey}) async {
    final wasHeld = everydayHeld;
    _pinOpened = true;
    _markKnown = true;
    if (r != PinResult.decoy) _quietMarked = false;
    // each decoy session looks up under a socks name of its own
    if (r == PinResult.decoy && kDecoyLooksUp) {
      try {
        engine.decoyLaneNew();
      } catch (e) {
        dlog('decoy: no new lane (${e.runtimeType})');
      }
    }
    try {
      await _sessionFor(r, vaultKey: vaultKey);
    } finally {
      if (wasHeld) _resumeEveryday();
    }
  }

  Future<void> _sessionFor(PinResult r, {String? vaultKey}) async {
    // nothing opened under one pin is left for another, not even unlinked
    final from = _lockedIn;
    _lockedIn = null;
    // a copy of ours from before a restart is known only by its label
    if (r == PinResult.decoy) await dropLabelledClip();
    final switched =
        from != null && from != containerFor(r, vaultKey: vaultKey);
    await dropOpenCopies(all: switched);
    // what was copied under the other pin leaves the clipboard
    if (switched) await dropOurClip();
    // an export's files go with the session that made them
    await dropNotesExports();
    // a vault left open by a lock that never reached the screen shuts first
    _shutVault();
    // and what home shows after one shut is read again before anything
    await _listsBack;
    if (vaultKey != null && r == PinResult.vault) {
      return _openVaultSession(HaloContainer.vault, vaultKey);
    }
    // the decoy's own vault comes with the decoy's outcome
    if (vaultKey != null && r == PinResult.decoy) {
      return _openVaultSession(HaloContainer.decoyVault, vaultKey);
    }
    final decoy = r == PinResult.decoy;
    final want = decoy ? _decoyDb : live;
    if (want == null) return;
    lockState.inDecoy = decoy;
    // out of the decoy the bridges are seen again at once (typing)
    if (!decoy) _typingBridgesRead();
    if (identical(_session.primary, want)) return;
    // no reads here: what home shows of the other session was read ahead,
    // and swapping it in costs the same whichever way it goes
    final leaving = _Shown(
      contacts,
      pendingCount,
      groups,
      _quietAvatar,
      devRow,
      photoBook.all,
    );
    final coming = _otherShown;
    _otherShown = leaving;
    _dropOpened();
    _session = Session(want);
    _quiet = decoy ? _decoyId : null;
    // the transfer note reads quiet again: none over a decoy
    TransferNote.instance.refresh();
    // what opened under the session before is opened again under this one.
    // a quiet session touches nothing of the everyday side's
    if (!sessionQuiet) unawaited(retryFirsts(all: true));
    if (coming != null) {
      contacts = coming.contacts;
      pendingCount = coming.pending;
      devRow = coming.dev;
      groups = coming.groups;
      if (decoy) _quietAvatar = coming.avatar;
    }
    // the book the other side read ahead, or none: never the one leaving
    photoBook.put(coming?.photos ?? const {});
    if (decoy) {
      _quietSince = DateTime.now().millisecondsSinceEpoch;
      _quietJobs = _jobRuns;
    }
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    // the new home is built now, still under the lock, so it comes up as
    // settled as the everyday one. when it shows is still verifyPin's wait,
    // the same for every outcome
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () {},
    );
    // once the lock is gone, off the clock: what was already in the shade
    // was already seen and goes, and the lists are read again for real. a
    // call into android here would hold the main thread, and dart with it,
    // and the decoy would show later than the everyday app does
    unawaited(
      Future.delayed(_afterReveal, () async {
        if (decoy) await cancelWithRetry(notifPlugin.cancelAll, 'decoy shade');
        await refreshContacts();
        await refreshGroups();
      }),
    );
  }

  // once the lock is gone and its fade is over
  Duration get _afterReveal =>
      revealGap ?? lockState.revealAfter + const Duration(milliseconds: 300);

  // a vault's pin: its identity's app with its hidden chats, the everyday
  // one's or the decoy's. its key is wrapped, so nothing of it could be read
  // ahead: it opens here, under the lock, and its lists are read before the
  // same deadline as any other outcome. it throws when the vault will not
  // open, and the lock then opens the session the vault extends
  Future<void> _openVaultSession(HaloContainer c, String key) async {
    final decoy = c == HaloContainer.decoyVault;
    final primary = decoy ? _decoyDb : live;
    if (primary == null) throw StateError('no decoy here');
    final v = await _host.openVault(c, key);
    final Session s;
    final (List<ContactPreview>, int, DevRow?) home;
    final List<GroupPreview> gs;
    final Map<String, Uint8List> book;
    try {
      // a move a crash cut short is put right before ownership is read
      await settleVault(v);
      // a restore's hidden chats: their contacts' devices cut, inside it
      if (!decoy) await _vaultRestoreCut(v);
      // cards from before they kept the mark are written again first
      if (!decoy && _router.marksUnread) {
        try {
          await _serial(() => _attached(v, _recard));
        } catch (e) {
          dlog('vault: cards not read (${e.runtimeType})');
        }
      }
      await _dropGroupLeftovers(v);
      // settled, both sides' rows name their files
      final before = DateTime.now().subtract(const Duration(minutes: 10));
      await _sweepUnnamedWallpapers(v, before);
      await _sweepUnnamedMedia(before, v);
      if (decoy) {
        await _sweepUnnamedWallpapers(primary, before, vaultOpen: true);
        await _sweepUnnamedMedia(before, primary, true);
      }
      // seats of people the everyday side let go while it was shut, and its
      // blocks and let-go words as its own rows hold them
      if (!decoy) await _marksAtOpen(v);
      if (!decoy) await trimFirstIn(v);
      s = await Session.withVault(primary, v);
      home = await _contactsOf(s);
      gs = await _groupsOf(s);
      book =
          await _photoBookOf(s, decoy ? (_decoyId?.id ?? '') : myId) ??
          const {};
    } catch (e) {
      try {
        await v.close();
      } catch (_) {
        // its key went with the close; the open error is the one passed on
      }
      rethrow;
    }
    if (decoy) {
      // from the everyday side: its lists wait as if read ahead, and the
      // decoy's face is the one read ahead for it, as at a decoy unlock
      if (!sessionQuiet) {
        final ahead = _otherShown;
        _otherShown = _Shown(
          contacts,
          pendingCount,
          groups,
          _quietAvatar,
          devRow,
          photoBook.all,
        );
        if (ahead != null) _quietAvatar = ahead.avatar;
        _quietSince = DateTime.now().millisecondsSinceEpoch;
        _quietJobs = _jobRuns;
      }
    } else if (sessionQuiet) {
      // from the decoy: its lists wait for its next unlock, as if read ahead
      _otherShown = _Shown(
        contacts,
        pendingCount,
        groups,
        _quietAvatar,
        devRow,
        photoBook.all,
      );
    }
    lockState.inDecoy = decoy;
    if (!decoy) _typingBridgesRead();
    _dropOpened();
    _session = s;
    _quiet = decoy ? _decoyId : null;
    TransferNote.instance.refresh();
    if (!sessionQuiet) unawaited(retryFirsts(all: true));
    contacts = home.$1;
    pendingCount = home.$2;
    devRow = home.$3;
    groups = gs;
    photoBook.put(book);
    _vaultFill = (at: 0, to: 0);
    lockState.inVault = true;
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(milliseconds: 250),
      onTimeout: () {},
    );
    unawaited(
      Future.delayed(
        _afterReveal,
        () => decoy ? _decoyVaultShown(v) : _vaultShown(v),
      ),
    );
  }

  // the decoy's, after the reveal and off the clock: the shade goes as at
  // any decoy unlock, and so do its timers that ran out while it was shut.
  // nothing is sealed to it and nothing in it sends
  Future<void> _decoyVaultShown(HaloDb v) async {
    if (!identical(_session.vault, v)) return;
    await cancelWithRetry(notifPlugin.cancelAll, 'decoy shade');
    try {
      await v.purgeExpired(blocked: _session.blockedIds);
      await refreshContacts();
      await refreshGroups();
    } catch (e) {
      if (identical(_session.vault, v)) {
        dlog('vault: after open (${e.runtimeType})');
      }
    }
  }

  // after the reveal, off the clock
  Future<void> _vaultShown(HaloDb v) async {
    if (!identical(_openVault, v)) return;
    // its chats draw their waiting files as such
    unawaited(_loadFileWaits());
    try {
      // its timers that ran out while it was shut go now, and what waits
      // from someone blocked on the everyday side starts
      await v.purgeExpired(blocked: _realBlocked);
      await refreshContacts();
      await refreshGroups();
      // the list names every chat it holds, whatever the last close left
      await refreshHiddenCards();
      // linked devices: its contacts' device state, before what was sealed
      await _vaultDevicesIn(v);
      // what came sealed while it was shut
      await _unseal();
      // its groups' screenshot blocks, as what came says
      await _groupShotsAtOpen(v);
      // and what its shelf still holds for people it accepted
      unawaited(letHeldIn(v));
      unawaited(_fillSearch(v));
      // what was typed in it and never went, and files half arrived
      unawaited(drainOutbox());
      unawaited(askForMissingSlices());
      unawaited(fetchDrops());
    } catch (e) {
      if (identical(_openVault, v)) {
        dlog('vault: after open (${e.runtimeType})');
      }
    }
  }

  // the lock is going up: a vault session shuts at once, and the key of a
  // vault made by a setup that did not finish goes
  void lockingUp() {
    // a file opened with another app, or shared from a hidden chat or the
    // decoy, goes with the session that handed it
    _lockedIn = (_session.vault ?? _session.primary).container;
    unawaited(dropOpenCopies());
    // in hidden chats or the decoy whatever is on the clipboard goes, a
    // field's own copy too; an everyday copy stays for another app
    unawaited(
      clipGoesWithLock()
          ? dropOurClip(all: true)
          : dropOurClip(quietOnly: true),
    );
    unawaited(dropNotesExports());
    unawaited(
      vaultSetupDone().catchError((Object e) {
        dlog('vault: setup key (${e.runtimeType})');
      }),
    );
    _shutVault();
  }

  // the session the vault extends is back before anything reads again. the
  // everyday vault's handle stays with its close until what it took in has
  // landed and the list names everyone in it. the decoy's takes nothing in
  void _shutVault() {
    final was = _session;
    final v = was.vault;
    if (v == null) return;
    // what was copied in its chats goes with them, a field's own copy too
    unawaited(dropOurClip(all: true));
    final everyday = AppState._everyday(v);
    final done = Completer<void>();
    if (everyday) _closeDone = done;
    _session = Session(was.primary);
    lockState.inVault = false;
    _forgetVaultSide();
    // its file on the way stops, and its waits go. the decoy's fetches
    // nothing, and the everyday side is not read from it
    if (everyday) _vaultFetchStops(v);
    // its contacts' photos off at once, before anything is drawn
    photoBook.put({
      for (final MapEntry(:key, :value) in photoBook.all.entries)
        if (!was.isHidden(key)) key: value,
    });
    // its chats off home now; the rest is read again below
    contacts = [
      for (final c in contacts)
        if (!was.isHidden(c.haloId)) c,
    ];
    groups = [
      for (final g in groups)
        if (!was.isHidden(g.groupId)) g,
    ];
    expiredRoomName = null;
    renewRootNavigator();
    sessionRev++;
    notifyListeners();
    _listsBack = () async {
      try {
        await refreshContacts();
        await refreshGroups();
      } catch (e) {
        dlog('lists after the vault: $e');
      }
    }();
    unawaited(everyday ? _closeVault(v, done) : _closeDecoyVault(v));
  }

  // once a move under way is done, and its key goes with the handle
  Future<void> _closeDecoyVault(HaloDb v) async {
    try {
      // its drafts are written before it shuts, and leave memory with it
      await settleDrafts(v.container);
      await _serial(v.close);
    } catch (e) {
      dlog('vault: close (${e.runtimeType})');
    }
  }

  // what the session kept of the vault beside its handle
  void _forgetVaultSide() {
    _dropOpened();
    _sealKey = null;
    _sealKeyOf = null;
    _vq = _Queue.none;
    _vaultFill = (at: 0, to: 0);
    _showFill();
  }

  Future<void> _closeVault(HaloDb v, Completer<void> done) async {
    try {
      // its drafts are written before it shuts, and leave memory with it
      await settleDrafts(v.container);
      await _serial(() async {
        // what is being filed into it, or opened from the seal, lands first
        final until = DateTime.now().add(const Duration(seconds: 10));
        while ((_unsealing || _arriving.isNotEmpty) &&
            DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        try {
          await _attached(v, _recard);
        } catch (e) {
          dlog('vault: cards left as they were (${e.runtimeType})');
        }
        // linked devices: its side stops, its pairs heard on by the cards
        await _vaultDevicesOut();
        await v.close();
      });
      await _listenHiddenDevices();
    } catch (e) {
      dlog('vault: close (${e.runtimeType})');
    } finally {
      if (identical(_closeDone, done)) _closeDone = null;
      done.complete();
    }
    // what its chats showed in the shade goes with it
    final shown = [..._vaultShade];
    _vaultShade.clear();
    for (final p in shown) {
      await cancelWithRetry(() => _io.unnotify(p), 'vault shade');
    }
  }
}

// the decoy's note goes into the decoy's own database, never the vault:
// written only while a decoy session is open
Future<void> _keepDecoyNote(String note) async {
  if (!sessionQuiet) return;
  await SqlRouterStore(_session.primary.open).putMeta(kComputerDecoyNote, note);
}
