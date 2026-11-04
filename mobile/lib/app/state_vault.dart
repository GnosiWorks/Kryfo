// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the vault: made, filled, emptied, gone, and what is sealed to it

part of '../main.dart';

// marks the zone of a vault job, so one never waits on its own chain
const _kVaultJob = #kryfoVaultJob;

extension AppStateVault on AppState {
  // an arrival for a hidden chat while the vault is shut: sealed to the
  // vault as it came, and nothing else happens. a 1:1 message still gets
  // its tick, as a visible one would, so the far side sees what it always
  // sees. a copy of one already sealed is not kept twice
  Future<void> _sealArrival(
    String sender,
    UnwrappedMessage env,
    String wire,
    bool fromBackPair, {
    // kept with it, so a block's spans in the vault judge it as they would
    // have on arrival
    int? wrappedAt,
    Reached? reached,
    // a contact's device's copy (linked devices), filed as one at the open
    bool fromDevice = false,
  }) async {
    // someone the vault blocked: nothing of it waits, and nothing is
    // answered. what they wrote is noted by its uid alone, for the vault to
    // keep as it would have on arrival, so a copy after an unblock stays
    // out. sealed like any arrival, the same size as a short one, and gone
    // first when the cap is reached (kMaxSealedNotes)
    if (_router.blocks(sender)) {
      _lastSealAt = DateTime.now().millisecondsSinceEpoch;
      final key = AppState._dataFrame(env) ? env.msgUid ?? env.mediaId : null;
      if (key == null || await _router.sealedHas(key, kNotePart)) return;
      await _router.seal(
        Unsealed(sender, '', false, _lastSealAt, blockedDrop: key),
        uid: key,
      );
      return;
    }
    _lastSealAt = DateTime.now().millisecondsSinceEpoch;
    final uid = env.msgUid;
    final total = env.chunkTotal;
    final sliced = env.mediaId != null && total != null && total > 1;
    final part = sliced ? env.chunkIndex ?? 0 : null;
    final previewOnly =
        env.preview != null &&
        env.message.isEmpty &&
        env.imageB64 == null &&
        env.fileB64 == null &&
        env.drop == null;
    final ticks =
        env.groupId == null &&
        uid != null &&
        sender != myId &&
        env.deliveredUid == null &&
        env.reaction == null &&
        env.edit == null &&
        !previewOnly &&
        // a phone's device words alone (linked devices) are never ticked
        !(linkedDevicesOn && deviceWordsOnly(wire));
    // a sliced file ticks once every slice is in, as it does when shown
    Future<bool> whole() async =>
        !sliced || await _router.sealedParts(uid!) >= total;
    if (uid != null && await _router.sealedHas(uid, part)) {
      if (ticks && (part ?? 0) == 0 && await whole()) {
        unawaited(_sendDeliveryReceipt(sender, uid));
      }
      return;
    }
    final kept = await _router.seal(
      Unsealed(
        sender,
        wire,
        fromBackPair,
        DateTime.now().millisecondsSinceEpoch,
        wrapped: wrappedAt,
        reached: reached,
        fromDevice: fromDevice,
      ),
      uid: uid,
      part: part,
      // a hidden group's end outlasts a flood of arrivals while it waits
      keep: env.groupControl?.type == 'end',
    );
    if (!kept) {
      dlog('seal: not kept');
      return;
    }
    // its file comes now and stays sealed until the hidden chats open, so
    // the service's week runs out on nothing this phone was sent. one the
    // automatic download leaves waits for a tap there
    final drop = env.drop;
    if (drop != null && await _getsNow(getKindOf(env.fileName))) {
      unawaited(_holdDrop(drop));
    }
    if (ticks && await whole()) unawaited(_sendDeliveryReceipt(sender, uid));
  }

  // whether a block on [haloId] in [db] held at [at], by this clock
  static Future<bool> _blockedThen(HaloDb db, String haloId, int at) async => [
    ...await db.blockSpansOf(haloId),
  ].any((s) => s.$1 <= at && (s.$2 == null || s.$2! > at));
  Future<void> drainSealed(HaloDb vault, String priv) async {
    if (_unsealing) return;
    _unsealing = true;
    try {
      // past the rows left for next time, in this vault's open
      if (!identical(_sealedPastOf, vault)) {
        _sealedPastOf = vault;
        _sealedPast = 0;
      }
      while (!haloWiping && identical(_openVault, vault) && _moveDone == null) {
        final batch = await _router.openOldest(priv, after: _sealedPast);
        if (batch.isEmpty) break;
        for (final (id, u) in batch) {
          if (!identical(_openVault, vault) || _moveDone != null) return;
          if (id > _sealedPast) _sealedPast = id;
          var stays = false;
          final rc = u?.receipt;
          if (u != null && rc != null) {
            try {
              await vault.queueFrame(rc, kFrameReceipt, u.from, '');
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: a receipt not kept (${e.runtimeType})');
            }
          } else if (u != null && u.blockedDrop != null) {
            // kept only while a block of theirs here held when it came: a
            // card that still said blocked after an unblock notes nothing
            try {
              if (await _blockedThen(vault, u.from, u.at)) {
                await vault.noteBlockedDrop(u.from, u.blockedDrop!);
              }
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: a blocked uid not kept (${e.runtimeType})');
            }
          } else if (u != null && u.deviceTag != null) {
            // a line on a hidden chat's device pair, as it came
            try {
              stays = !await _unsealDeviceLine(vault, u);
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: a device line not opened (${e.runtimeType})');
              // it opens here, not before it was sealed: tried again at the
              // next open, while the relays could still have held it
              stays =
                  DateTime.now().millisecondsSinceEpoch - u.at <
                  kBlockListenFor;
            }
          } else if (u != null && u.keyChanged) {
            _keyChangeSealed.remove(u.from);
            try {
              await vault.setKeyChanged(u.from, true);
              keyChanged();
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: a key change not kept (${e.runtimeType})');
            }
          } else if (u != null && u.resend) {
            try {
              await _resendTo(vault, u.from, since: u.resendSince);
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: an owed resend not run ($e)');
            }
            try {
              final since = u.resendSince;
              if (since != null) {
                await _resendGroupTextsTo(vault, u.from, since: since);
              }
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: owed group texts not run (${e.runtimeType})');
            }
          } else if (u != null && await _sealedBlocked(u.wire)) {
            // sealed before "this isn't them" blocked its key: it goes
            dlog('unseal: a blocked key, dropped');
          } else if (u != null) {
            try {
              final env = unwrapMessage(u.wire);
              // a first contact files its sender, as it does in the everyday
              // container, so a changed key is flagged
              if (u.backPair) {
                await vault.upsertContact(
                  u.from,
                  env.senderOnion ?? '',
                  env.senderXPub ?? '',
                  accepted: 0,
                );
              }
              await _applyIncomingPayload(
                u.from,
                env,
                wire: u.wire,
                fromBackPair: u.backPair,
                fromDevice: u.fromDevice,
                into: vault,
                arrivedAt: u.at,
                wrappedAt: u.wrapped,
                reached: u.reached,
              );
            } on CapHeld catch (e) {
              // past a stranger's two: on the shelf, let in on accept. a
              // shelf that is full or fails leaves the row for the next time
              try {
                stays =
                    await _hold(
                      e is _HeldIn ? e.into : vault,
                      u.from,
                      u.wire,
                      unwrapMessage(u.wire),
                    ) ==
                    Shelved.full;
              } catch (e) {
                dlog('unseal: the shelf failed ($e)');
                stays = true;
              }
            } on _NoProof {
              await _io.dropSession(u.from);
            } catch (e) {
              if (!identical(_openVault, vault)) return;
              dlog('unseal: one not applied ($e)');
            }
          }
          if (!stays) await _router.forgetSealed(id);
        }
        await refreshContacts();
        await refreshGroups();
        await Future.delayed(const Duration(milliseconds: 60));
      }
    } finally {
      _unsealing = false;
    }
  }

  Future<bool> _sealedBlocked(String wire) async {
    try {
      return await _keyBlockedHere(unwrapMessage(wire).senderXPub ?? '');
    } catch (_) {
      return false;
    }
  }

  // the sealed arrivals of the open vault, when there may be any
  Future<void> _unseal() async {
    final v = _openVault;
    if (v == null) {
      _sealKey = null;
      _sealKeyOf = null;
      // the rows left for next time are tried at the next open
      _sealedPastOf = null;
      return;
    }
    // rows moving between the vault and the everyday side go first
    if (!_router.maybeSealed || _unsealing || _moveDone != null) return;
    try {
      if (!identical(_sealKeyOf, v)) {
        _sealKey = await VaultRouter.sealKeyIn(SqlRouterStore(v.open));
        _sealKeyOf = v;
      }
      final k = _sealKey;
      if (k != null) await drainSealed(v, k);
    } catch (e) {
      dlog('unseal: $e');
    }
  }

  /// [work] with no chat hidden, unhidden or removed meanwhile: a history
  /// copy reads the chats under it. a vault opening, closing or reading its
  /// cards never waits on it, so a hidden chats PIN answers as fast as any
  Future<void> withVaultStill(Future<void> Function() work) {
    // neither chain lets a job wait on itself
    if (Zone.current[_kVaultJob] == true) {
      throw StateError('a history copy cannot start inside vault work');
    }
    return _movingChats(work);
  }

  // hide, unhide, remove and destroy take this first, then _serial
  Future<T> _movingChats<T>(Future<T> Function() work) {
    final r = _chatMoves.then(
      (_) => runZoned(work, zoneValues: {_kVaultJob: true}),
    );
    _chatMoves = r.then((_) {}, onError: (_) {});
    return r;
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    final r = _vaultWork.then(
      (_) => runZoned(work, zoneValues: {_kVaultJob: true}),
    );
    // the caller gets any error from r; the chain only keeps the order
    _vaultWork = r.then((_) {}, onError: (_) {});
    return r;
  }

  static List<ChatRef> _refs(
    Iterable<String> people,
    Iterable<String> groups,
  ) => [
    for (final id in {...people}) ChatRef(id),
    for (final id in {...groups}) ChatRef(id, group: true),
  ];

  // the database a vault extends
  HaloDb _primaryOf(HaloDb vault) {
    if (AppState._everyday(vault)) return live;
    final d = _decoyDb;
    if (d == null) throw StateError('no decoy here');
    return d;
  }

  // the vault of the identity on screen: the decoy's in a decoy session
  HaloContainer get _ownVault =>
      sessionQuiet ? HaloContainer.decoyVault : HaloContainer.vault;

  // setup, once the pin is confirmed: the old vault goes first and the new
  // pin entry is written last. false when the pin is in use. the new vault
  // stays at hand for hideChats until vaultSetupDone. in a decoy session it
  // is the decoy's, and the everyday one is never touched. there a pin in
  // use is taken and kept nowhere, as every pin set in the decoy is: the
  // flow goes on as with any other, and what it hides no pin opens
  Future<bool> createVault(String pin) => _serial(() async {
    if (_session.vault != null) throw StateError('no vault setup from here');
    if (!_host.lockOn) throw StateError('no app lock');
    final c = _ownVault;
    await _destroy(c);
    final key = newVaultKey();
    try {
      final pub = await _host.makeVault(c, key);
      if (c == HaloContainer.vault) await _router.start(pub);
      if (await _host.putEntry(c, pin, key)) {
        _madeVault = HaloDb.withKey(c, key);
        return true;
      }
    } catch (e) {
      // the type only: an open error may quote the key
      dlog('vault: not made (${e.runtimeType})');
      await _unmake(c);
      rethrow;
    }
    await _unmake(c);
    return false;
  });

  // a vault no pin opens, with nothing listed: its key and files go
  Future<void> _unmake(HaloContainer c) async {
    try {
      if (c == HaloContainer.vault) await _router.retire();
      await _host.wipeVault(c);
    } catch (e) {
      dlog('vault: left for the next setup (${e.runtimeType})');
    }
  }

  // the setup flow is over, or the app locked during it: the new vault's
  // key goes
  Future<void> vaultSetupDone() => _serial(_dropMade);

  Future<void> _dropMade() async {
    final v = _madeVault;
    _madeVault = null;
    await v?.close();
  }

  // replace, or the lock turned off: the entry first, then the list (its
  // people stay as a drop list), the files last. never from inside a vault,
  // and only the identity on screen's
  Future<void> destroyVault() => _movingChats(
    () => _serial(() async {
      await _destroy(_ownVault);
      // linked devices: what its cards named is heard on no more
      await _listenHiddenDevices();
    }),
  );

  Future<void> _destroy(HaloContainer c) async {
    if (_session.vault != null) throw StateError('the vault is open');
    forgetDrafts(c);
    await _host.clearEntry(c);
    await _dropMade();
    if (c == HaloContainer.vault) {
      // what a move cut short left in the everyday folders goes with it
      await _repairMoves();
      // its marks of "this isn't them" stay with the list, unseen, and hold
      await _router.forget();
      await _forgetPeers(_router.ids);
    }
    await _host.wipeVault(c);
  }

  // chats and groups into the vault, from the setup picker or from inside
  // the vault. requests, rooms and notes stay where they are. how many went
  Future<int> hideChats({
    Iterable<String> people = const [],
    Iterable<String> groups = const [],
  }) => _movingChats(
    () => _serial(() async {
      final v = _session.vault ?? _madeVault;
      if (v == null) throw StateError('no vault at hand');
      final chats = _refs(people, groups);
      if (chats.isEmpty) return 0;
      final went = await _move(v, chats, (m) => _hide(m, v, chats), out: false);
      // a copy open to a new device may already hold their rows: it ends
      if (went.isNotEmpty) endHistoryCopies();
      // linked devices: their pairs heard on as the vault's cards say
      if (AppState._everyday(v)) await _listenHiddenDevices();
      // what could still name them outside the vault, and what they showed.
      // the decoy keeps no one outside and never shows anything
      if (AppState._everyday(v)) {
        await _forgetPeers(_router.ids);
        if (went.isNotEmpty) {
          await _host.clearShade([
            for (final c in went) c.group ? 'group:${c.id}' : c.id,
          ]);
        }
      }
      await refreshContacts();
      await refreshGroups();
      _relistenMoved();
      return went.length;
    }),
  );

  // hidden chats back in the chat list, from inside the vault. how many
  // came back
  Future<int> unhideChats({
    Iterable<String> people = const [],
    Iterable<String> groups = const [],
  }) => _movingChats(
    () => _serial(() async {
      final v = _session.vault ?? _madeVault;
      if (v == null) throw StateError('no vault at hand');
      final chats = _refs(people, groups);
      if (chats.isEmpty) return 0;
      final before = _router.listenFor.keys.toSet();
      final n = await _move(v, chats, (m) => _unhide(m, v, chats), out: true);
      // linked devices: back on the everyday side, heard on from there, and
      // lists go both ways again
      if (linkedDevicesOn && AppState._everyday(v)) {
        await _devShown(chats);
      }
      await refreshContacts();
      await refreshGroups();
      _relistenMoved(out: before.difference(_router.listenFor.keys.toSet()));
      return n;
    }),
  );

  // remove hidden chats, from inside the vault: every chat it holds comes
  // back first, then the pin entry goes, then its key and files. a crash
  // part way leaves the rest hidden behind the same pin
  Future<void> removeVault() => _movingChats(
    () => _serial(() async {
      final v = _session.vault ?? _madeVault;
      if (v == null) throw StateError('no vault at hand');
      final everyday = AppState._everyday(v);
      final before = _router.listenFor.keys.toSet();
      // every chat it holds, so each comes back alike: as the list names them
      // on the everyday side, as its own rows do on the decoy's
      final List<ChatRef> all;
      if (everyday) {
        await _attached(v, _recard);
        all = [
          for (final (id, g) in _router.hiddenChats) ChatRef(id, group: g),
        ];
      } else {
        all = await _attached(
          v,
          (m) async => [
            for (final MapEntry(key: id, value: (kind, _))
                in (await m.vaultCards()).entries)
              ChatRef(id, group: kind == kHiddenGroup),
          ],
        );
      }
      await _move(v, all, (m) => _unhide(m, v, all), out: true);
      // what came out, read before the unlist below: a chat deleted inside
      // the vault is no one's on the everyday side and never listened on
      // there. its hidden runner goes at the next start
      final out = before.difference(_router.listenFor.keys.toSet());
      if (everyday && linkedDevicesOn) await _devShown(all);
      if (everyday) {
        // what is still listed the vault no longer holds: deleted inside it
        await _router.unlist([for (final (id, _) in _router.hiddenChats) id]);
        _relistenMoved(out: out);
      }
      // its blocked keys and let-go words stay, on the side its chats went to
      await _primaryOf(v).takeBlocks(await v.blockedKeys(), await v.tombs());
      await _host.clearEntry(v.container);
      if (everyday) await _router.retire();
      if (identical(_session.vault, v)) {
        _session = Session(_session.primary);
        lockState.inVault = false;
        _forgetVaultSide();
        _vaultShade.clear();
      }
      if (everyday) await _vaultDevicesOut();
      if (identical(_madeVault, v)) _madeVault = null;
      await v.close();
      await _host.wipeVault(v.container);
      await refreshContacts();
      await refreshGroups();
    }),
  );

  // for a vault just opened, before its session is built: its side of a
  // move a crash cut short is put right
  Future<void> settleVault(HaloDb vault) =>
      _serial(() => _attached(vault, (m) => _settle(m, vault)));

  // what receiving needs of the hidden chats, read again from the open
  // vault's rows
  Future<void> refreshHiddenCards() => _serial(() async {
    final v = _openVault;
    if (v != null) await _attached(v, _recard);
  });

  Future<T> _attached<T>(
    HaloDb vault,
    Future<T> Function(ChatMover m) work,
  ) async {
    final m = _host.mover(_primaryOf(vault), vault);
    await m.attach();
    try {
      return await work(m);
    } finally {
      await m.detach();
    }
  }

  // what arrives for the moving chats waits, and a fault puts right what it
  // can before it is passed on. nothing arrives for the decoy's
  Future<T> _move<T>(
    HaloDb vault,
    List<ChatRef> chats,
    Future<T> Function(ChatMover m) work, {
    required bool out,
  }) async {
    final everyday = AppState._everyday(vault);
    final primary = _primaryOf(vault);
    final m = _host.mover(primary, vault);
    await m.attach();
    // the decoy's moves wait the same way: a row of ours written meanwhile
    // goes with its chat, and the two take the same time
    final done = Completer<void>();
    _moveDone = done;
    void Function()? letDrafts;
    try {
      // what waits for the vault goes out with the chat's rows
      if (out) {
        for (final c in chats) {
          await writeDraftNow(vault, c.id, group: c.group);
        }
      }
      // until the session is rebuilt it still names the old side: a draft
      // typed meanwhile would land there
      letDrafts = holdDraftsOf([for (final c in chats) c.id]);
      for (final c in chats) {
        _moving.add(c.id);
        if (c.group) _moving.addAll(await m.peopleIn(c, inVault: out));
      }
      // what is being filed for them lands first, and no unseal runs
      // while rows move
      while (_unsealing || _arriving.keys.any(_moving.contains)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await _settle(m, vault);
      return await work(m);
    } catch (e) {
      dlog('vault: move cut short (${e.runtimeType})');
      try {
        if (everyday) {
          await _router.load();
          await _repairMoves(m);
        }
        await _settle(m, vault);
      } catch (_) {
        // the next start and the next open put it right
      }
      rethrow;
    } finally {
      try {
        await m.detach();
      } catch (e) {
        // attached to this connection until the next start opens a new one
        dlog('vault: not detached (${e.runtimeType})');
      }
      if (identical(_session.vault, vault)) {
        try {
          final rebuilt = await Session.withVault(primary, vault);
          // a lock that shut the vault meanwhile keeps it shut
          if (identical(_session.vault, vault)) _session = rebuilt;
        } catch (e) {
          dlog('vault: session not rebuilt (${e.runtimeType})');
        }
      }
      letDrafts?.call();
      _moving.clear();
      _moveDone = null;
      done.complete();
    }
  }

  // a row of ours for [chat] written after a wait, as a voice note's once
  // its disguise is made: a move of the chat under way ends first, and one
  // that starts waits for it, as for an arrival
  Future<T> keepOwn<T>(String chat, Future<T> Function() work) async {
    if (_moveDone != null) await _afterMove(chat, null);
    _arriving[chat] = (_arriving[chat] ?? 0) + 1;
    try {
      return await work();
    } finally {
      final n = (_arriving[chat] ?? 1) - 1;
      n > 0 ? _arriving[chat] = n : _arriving.remove(chat);
    }
  }

  @visibleForTesting
  int get waitingOnMoveForTest => _onMove;

  // a move of [chats] under way until the call handed back ends it
  @visibleForTesting
  void Function() holdMoveForTest(Iterable<String> chats) {
    final done = Completer<void>();
    _moveDone = done;
    _moving.addAll(chats);
    return () {
      _moving.clear();
      _moveDone = null;
      done.complete();
    };
  }

  Future<void> _afterMove(String sender, String? groupId) async {
    while (true) {
      final done = _moveDone;
      if (done == null) return;
      final g = groupId != null && groupId.isNotEmpty ? groupId : null;
      if (!_moving.contains(sender) && (g == null || !_moving.contains(g))) {
        return;
      }
      _onMove++;
      try {
        await done.future;
      } finally {
        _onMove--;
      }
    }
  }

  Future<List<ChatRef>> _hide(
    ChatMover m,
    HaloDb vault,
    List<ChatRef> chats,
  ) async {
    final everyday = AppState._everyday(vault);
    final primary = _primaryOf(vault);
    final from = primary.container;
    var marks = await m.marks();
    final went = <ChatRef>[];
    for (final c in chats) {
      // the developer chat is never hidden
      if (isDevChat(c.id) || !await m.hideable(c)) continue;
      // its unsent words go, before its rows are copied over
      await dropDraft(primary, c.id, group: c.group);
      // linked devices: their device state goes with the chat's rows
      // (vault_life.dart), and the everyday side hears on their pairs no
      // more (read before the row goes)
      final ikey = everyday && !c.group ? await _devHiding(c.id) : null;
      marks = marks.hiding(c);
      await m.copyIn(c, marks);
      if (everyday) {
        // the commit point: from here what arrives for it goes to the vault
        final files = await m.commitIn(
          c,
          DateTime.now().millisecondsSinceEpoch,
        );
        await _router.load();
        await _placeFiles(files, from, vault.container);
        await _router.settle(c.id);
        if (ikey != null) await _devMoved(ikey, toVault: true);
      } else {
        // no list: the commit point is the chat leaving the decoy's
        // database, and the vault's next open puts right what a crash
        // leaves after it
        final files = await m.vaultFiles(c);
        await m.dropLive(c);
        await _placeFiles(files, from, vault.container);
      }
      marks = marks.done(c);
      await m.putMarks(marks);
      // its unsent words are not kept outside the vault, nor written back
      // by a screen of it still open
      await (c.group ? dropGroupDraft(c.id) : dropChatDraft(c.id));
      await dropDraft(vault, c.id, group: c.group);
      _bumpChatRev(c.group ? 'group:${c.id}' : c.id);
      went.add(c);
    }
    if (everyday) await _recard(m);
    return went;
  }

  Future<int> _unhide(ChatMover m, HaloDb vault, List<ChatRef> chats) async {
    final everyday = AppState._everyday(vault);
    final to = _primaryOf(vault).container;
    var marks = await m.marks();
    var n = 0;
    for (final c in chats) {
      if (everyday && !_router.hides(c.id)) continue;
      if (!await m.held(c)) continue;
      marks = marks.showing(c);
      await m.putMarks(marks);
      // the files go first, flagged on the list entry, so a start-up before
      // the commit puts them back. the decoy's next open does it there
      final files = await m.vaultFiles(c);
      if (everyday) await _router.markBack(c.id, files);
      await _placeFiles(files, vault.container, to);
      // the commit point: from here it shows without the vault again
      await m.commitOut(c);
      if (everyday) await _router.load();
      if (everyday && !c.group) {
        final ikey = await _devShownKey(c.id);
        if (ikey != null) await _devMoved(ikey, toVault: false);
      }
      marks = marks.done(c);
      await m.dropVault(c, marks);
      // its draft went out with its rows: the vault's copy in memory goes
      forgetDraft(vault.container, c.id, group: c.group);
      _bumpChatRev(c.group ? 'group:${c.id}' : c.id);
      n++;
    }
    if (everyday) await _recard(m);
    return n;
  }

  // linked devices: chats back on the everyday side, their pairs heard on
  // from there and no more by the vault's cards, and lists both ways
  Future<void> _devShown(List<ChatRef> chats) async {
    await _listenHiddenDevices();
    for (final c in chats) {
      if (c.group) continue;
      final ikey = await _devShownKey(c.id);
      if (ikey != null) await _deviceReceive?.listenAll(only: ikey);
      unawaited(_devicesShown(c.id));
    }
  }

  // every chat the vault holds listed, with a card from its rows
  Future<void> _recard(ChatMover m) async =>
      _router.recard(await m.vaultCards());

  // the vault's side of a move cut short: a hide that never reached its
  // commit, or an unhide past it, left a copy in the vault, which goes. the
  // list says which on the everyday side; on the decoy's, whether its
  // database still holds the chat, and the files follow the rows
  Future<void> _settle(ChatMover m, HaloDb vault) async {
    final everyday = AppState._everyday(vault);
    final primary = _primaryOf(vault);
    if (everyday) await _router.load();
    var left = await m.marks();
    if (left.isEmpty) return;
    for (final c in [...left.inbound, ...left.outbound]) {
      left = left.done(c);
      final hidden = everyday ? _router.hides(c.id) : !await _holds(primary, c);
      if (hidden) {
        if (!everyday) {
          await _placeFiles(
            await m.vaultFiles(c),
            primary.container,
            vault.container,
          );
        }
        await m.putMarks(left);
        continue;
      }
      await _placeFiles(
        await m.vaultFiles(c),
        vault.container,
        primary.container,
      );
      await m.dropVault(c, left);
    }
  }

  // the database holds the chat as one: an added person, or the group
  static Future<bool> _holds(HaloDb d, ChatRef c) async => c.group
      ? await d.groupExists(c.id)
      : (await d.getContact(c.id))?['accepted'] == 1;

  // a move cut short, as its list entry's flags say: the chat's everyday
  // rows go and its files into the vault's folders
  Future<void> _repairMoves([ChatMover? mover]) async {
    final pending = _router.pending;
    if (pending.isEmpty) return;
    final m = mover ?? _host.mover(live, null);
    if (mover == null) await m.attach();
    try {
      for (final p in pending) {
        final c = ChatRef(p.chatId, group: p.group);
        if (p.hid) await m.dropLive(c);
        await _placeFiles(p.files, live.container, HaloContainer.vault);
        await _router.settle(p.chatId);
      }
    } finally {
      if (mover == null) await m.detach();
    }
  }

  // each file into the folders its rows are in now. one already there wins
  // and the other is shredded
  Future<void> _placeFiles(
    List<String> names,
    HaloContainer from,
    HaloContainer to,
  ) async {
    // each file with its blur, if it has one
    for (final n in [
      for (final x in names) ...[x, '$x$kBlurLeaf'],
    ]) {
      final src = await chatFilePath(n, from);
      final dst = await chatFilePath(n, to);
      if (src == null || dst == null || !await File(src).exists()) continue;
      if (await File(dst).exists()) {
        await _host.shred(src);
      } else {
        await _host.moveFile(src, dst);
      }
    }
  }

  // the people the vault keeps, out of what the everyday side keeps on disk
  // about reaching someone: first-contact keys and the listen cache
  Future<void> _forgetPeers(Set<String> ids) async {
    if (ids.isEmpty) return;
    const st = secureStore;
    var fc = false;
    for (final id in ids) {
      if (_peerFc.remove(id) != null) fc = true;
    }
    await _forgetPairSeen(ids);
    if (fc && !_peerFcUnread) {
      await st.write(key: 'peer_fc', value: jsonEncode(_peerFc));
    }
    try {
      final raw = await st.read(key: 'xpub_cache');
      if (raw == null || raw.isEmpty) return;
      final cache = Map<String, Object?>.from(jsonDecode(raw) as Map);
      final before = cache.length;
      cache.removeWhere((_, v) => ids.contains(v));
      if (cache.length != before) {
        await st.write(key: 'xpub_cache', value: jsonEncode(cache));
      }
    } catch (e) {
      dlog('xpub cache: $e');
    }
  }
}
