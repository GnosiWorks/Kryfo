// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices and the hidden chats: a hidden chat's contact's device
// rows, pairs and device sessions live in the vault (vault_life.dart moves
// them with the chat). while it is open a receiving side and a send loop of
// its own run on them, and the engine holds the contact; while it is shut
// the engine holds nothing of them, their device pairs are listened on by
// what the vault's card names, and every line on them is sealed as it came
// for the vault to open. my own state (my list, the pool) stays on the
// everyday side. nothing here runs with the switch off, nor for the decoy

part of '../main.dart';

DeviceReceive? _vaultDevReceive;
DeviceSend? _vaultDevSend;
HaloDb? _vaultDevOf;
// the contacts (identity hex) the engine holds from the open vault
final _vaultDevPeers = <String>{};
// what is listened on for hidden chats' devices: arg to my identity
final _hiddenHeard = <String, int>{};
// the keys told to the engine for listening, by '$ident/$identity'
final _hiddenKeysTold = <String, String>{};
Timer? _hiddenCardsTimer;
// while the vault is shut, the hidden chats whose contact's phone took a
// removal owed (kHiddenRemovalMeta), by chat: the version it went with.
// memory only: a start sends each again, the vault's open queues it
final _hiddenRemovalsSent = <String, int>{};

// the open vault's restore cut (restoreCutsVaultDevices) did not run: its
// devices' side stays off until an open where it did
var _vaultCutWaits = false;

// the vault [v] opening: after a restore, every device session and pair of
// its contacts goes and their lists are marked stale, before anything reads
// them, in the vault alone (heal.dart). nothing is written on the everyday
// side. one that fails keeps the vault's devices' side off
Future<void> _vaultRestoreCut(HaloDb v) async {
  try {
    final at = await restoredAt();
    if (at != null && await restoreCutsVaultDevices(await v.open(), at)) {
      dlog('vault: its contacts\' devices cut after the restore');
    }
    _vaultCutWaits = false;
  } catch (e) {
    _vaultCutWaits = true;
    dlog('vault: the restore cut waits (${e.runtimeType})');
  }
}

@visibleForTesting
Future<void> vaultRestoreCutForTest(HaloDb v) => _vaultRestoreCut(v);

@visibleForTesting
bool get vaultCutWaitsForTest => _vaultCutWaits;

// the vault's own dev_marks kind: a removal owed (kHiddenRemovalMeta) it
// queued as its pushes, by version
const kHiddenRemovalQueued = 'hidden_removal';

// a frame of mine to a hidden chat's contact's phone, on the phone pair
// whose session the everyday side holds
Future<bool> Function(int ident, String peer, String identity, String frame)
_hiddenPhoneSend = _hiddenPhoneSendLive;

Future<bool> _hiddenPhoneSendLive(
  int ident,
  String peer,
  String identity,
  String frame,
) async {
  final me = await _devMeOf(ident);
  if (me == null) return false;
  return _devPhoneSend(me, (
    peer: peer,
    identity: identity,
    devices: true,
    phoneClassic: false,
  ), frame);
}

@visibleForTesting
set hiddenPhoneSendForTest(
  Future<bool> Function(int ident, String peer, String identity, String frame)?
  send,
) {
  _hiddenPhoneSend = send ?? _hiddenPhoneSendLive;
  _hiddenRemovalsSent.clear();
}

/// the receiving side of the open vault's hidden chats, while it is open
DeviceReceive? get vaultDeviceReceive => _vaultDevReceive;

@visibleForTesting
void vaultDevicesForTest(DeviceReceive? r, DeviceSend? s, HaloDb? of) {
  _vaultDevReceive = r;
  _vaultDevSend = s;
  _vaultDevOf = of;
}

// the open vault's device pairs heard as the everyday side's are, each
// change read into the cards a little later
class _VaultDeviceListen implements DeviceListen {
  @override
  void listen(int ident, String arg) {
    _hiddenHeard[arg] = ident;
    // a hidden chat's contact's device: a lane of its own, as the chat's
    engine.deviceListenBg(ident, arg, hidden: true);
    _hiddenCardsDue();
  }

  @override
  void unlisten(int ident, String arg) {
    _hiddenHeard.remove(arg);
    engine.deviceUnlistenBg(ident, arg);
    _hiddenCardsDue();
  }

  @override
  Future<String> seed(int ident, String arg, String seedHex) async {
    final r = await engine.pairSeed(ident, arg, seedHex);
    _hiddenCardsDue();
    return r;
  }
}

void _hiddenCardsDue() {
  _hiddenCardsTimer?.cancel();
  _hiddenCardsTimer = Timer(const Duration(seconds: 2), () {
    unawaited(() async {
      try {
        await appState.refreshHiddenCards();
        await appState._listenHiddenDevices();
      } catch (e) {
        dlog('devices: hidden cards not read again (${e.runtimeType})');
      }
    }());
  });
}

// the database [peer]'s device state is in: the everyday container, or
// the open vault while its side runs; null for a hidden chat while the
// vault is shut, when nothing of theirs is read or written
HaloDb? _devHomeDb(String peer) {
  final app = _madeApp;
  if (app == null) return live;
  if (!app._devHidden(peer)) return live;
  final v = _vaultDevOf;
  return v != null && identical(app._openVault, v) ? v : null;
}

DeviceReceive? _devReceiveFor(String peer) {
  final h = _devHomeDb(peer);
  if (h == null) return null;
  return identical(h, live) ? _deviceReceive : _vaultDevReceive;
}

DeviceSend? _devSendFor(String peer) {
  final h = _devHomeDb(peer);
  if (h == null) return null;
  return identical(h, live) ? _deviceSend : _vaultDevSend;
}

// a contact of my [ident] by their identity key in the open vault [v]:
// accepted, and blocked as [blocked] says
Future<({DevMe me, DevContact c})?> _devVaultByKey(
  HaloDb v,
  int ident,
  String identity, {
  required bool blocked,
}) async {
  final db = await v.open();
  final r = await db.query(
    'contacts',
    columns: ['halo_id'],
    where: 'ident = ? AND ikey = ? AND accepted = 1 AND blocked = ?',
    whereArgs: [ident, identity, blocked ? 1 : 0],
    limit: 1,
  );
  if (r.isEmpty) return null;
  final peer = r.first['halo_id'] as String;
  if (!appState._devHidden(peer)) return null;
  final ss = await signalOfIdent(ident);
  return _devWhoOf(ident, peer, ss, on: v);
}

/// the engine's load of [ids] (identity hex), or of every accepted contact
/// with a key when null, from [db]: their contact rows and device rows
Future<Map<String, Object?>> devPeerLoadArgs(
  DatabaseExecutor db, {
  Set<String>? ids,
}) async {
  final contacts = [
    for (final r in await db.query(
      'contacts',
      columns: ['ident', 'ikey'],
      where: 'ikey IS NOT NULL AND accepted = 1',
      orderBy: 'rowid',
    ))
      if (ids == null || ids.contains(r['ikey']))
        {'ident': r['ident'] ?? 0, 'identity': r['ikey']},
  ];
  final held = {for (final c in contacts) c['identity']};
  final out = <String, Object?>{'contacts': contacts};
  for (final t in const ['dev_lists', 'dev_proven', 'dev_pq', 'dev_quiet']) {
    final owner = t == 'dev_lists' ? 'owner' : 'peer';
    out[t] = [
      for (final r in await db.query(
        t,
        columns: kDevRowTables[t],
        orderBy: 'rowid',
      ))
        if (held.contains(r[owner]))
          {
            for (final e in r.entries)
              e.key: e.value is List<int>
                  ? base64Encode(e.value as List<int>)
                  : e.value,
          },
    ];
  }
  return out;
}

extension AppStateVaultDevices on AppState {
  // [peer]'s device state is the vault's: their chat is hidden
  bool _devHidden(String peer) =>
      _router.keeps(peer) || (_openVault != null && _session.isHidden(peer));

  // the vault [v] opened: its contacts' device state into the engine, its
  // side of receiving and sending started, its pairs heard on, and my list
  // to each who reads lists and has not had this version
  Future<void> _vaultDevicesIn(HaloDb v) async {
    final ds = _deviceState;
    final everyday = _deviceReceive;
    if (!linkedDevicesOn || ds == null || everyday == null) return;
    if (!AppState._everyday(v) || !identical(_openVault, v)) return;
    // devices from before a restore are never let in
    if (_vaultCutWaits) return;
    // a lock during any wait below: the close ran with nothing to let go,
    // so what this took in goes here
    var took = <String>[];
    Future<bool> shut() async {
      if (identical(_openVault, v)) return false;
      if (identical(_vaultDevOf, v)) {
        _vaultDevReceive = null;
        _vaultDevSend = null;
        _vaultDevOf = null;
        // its listens as the cards say, now that it is shut
        unawaited(_listenHiddenDevices());
      }
      _vaultDevPeers.removeAll(took);
      if (took.isNotEmpty) {
        await ds.call(await live.open(), 'drop_peers', {
          'peers': took,
          'keep': await _keptByKey(took),
        });
      }
      return true;
    }

    try {
      final vdb = await v.open();
      final args = await devPeerLoadArgs(vdb);
      if (await shut()) return;
      await ds.call(vdb, 'load_peers', args);
      took = [
        for (final c in args['contacts'] as List)
          (c as Map)['identity'] as String,
      ];
      if (await shut()) return;
      _vaultDevPeers
        ..clear()
        ..addAll(took);
      final sessions = <int, DeviceSessions>{};
      Future<DeviceSessions> vs(int ident) async {
        final ss = await signalOfIdent(ident);
        final held = sessions[ident];
        if (held != null && identical(held.s, ss)) return held;
        return sessions[ident] = DeviceSessions(ss, store: vdb);
      }

      final listen = _VaultDeviceListen();
      final send = DeviceSend(
        state: ds,
        db: v.open,
        mine: live.open,
        noOwn: true,
        sessions: vs,
        wire: _EngineDeviceWire(),
        listen: listen.listen,
        door: _devDoor,
      );
      _vaultDevOf = v;
      _vaultDevSend = send;
      _vaultDevReceive = DeviceReceive(
        state: ds,
        db: v.open,
        mine: live.open,
        ownHome: everyday,
        sessions: vs,
        send: send,
        listener: listen,
        open: deviceOpenAt,
        me: _devMeOf,
        contact: (ident, identity) =>
            _devVaultByKey(v, ident, identity, blocked: false),
        blockedChat: (ident, identity) =>
            _devVaultByKey(v, ident, identity, blocked: true),
        phone: _devPhoneSend,
        sign: (ident, body) async {
          final ss = await signalOfIdent(ident);
          return ss.lib.sign(ss.identity, LsSigContext.deviceList, body);
        },
        shown: (c) async {
          final went = await _applyDeviceCopy(c);
          if (AppState._shown(went)) notifyListeners();
        },
      );
      _vaultDevReceive?.lined = chatChanged;
      await _vaultDevReceive?.listenAll();
      if (await shut()) return;
      await _vaultListsOwed(v);
      // a removal owed while it was shut: queued in it now, kept there
      // until each phone answers
      if (!await shut()) await _pushHiddenRemovals();
      await shut();
    } catch (e) {
      dlog('devices: the vault\'s not loaded (${e.runtimeType})');
    }
  }

  @visibleForTesting
  Future<void> vaultDevicesInForTest(HaloDb v) => _vaultDevicesIn(v);

  // my list to each hidden contact who reads lists, once a version: it
  // could not go while the vault was shut
  Future<void> _vaultListsOwed(HaloDb v) async {
    final send = _vaultDevSend;
    if (send == null) return;
    final vdb = await v.open();
    final mine = await live.open();
    for (final r in await vdb.query(
      'contacts',
      columns: ['ident', 'ikey', 'caps'],
      where: 'ikey IS NOT NULL AND accepted = 1 AND blocked = 0',
    )) {
      if (!capsOfText(r['caps'] as String?).contains(kCapDevices)) continue;
      final ident = r['ident'] as int? ?? kMainIdent;
      final ikey = r['ikey'] as String;
      final my = await mine.query(
        'dev_lists',
        columns: ['version'],
        where: "ident = ? AND owner = 'me'",
        whereArgs: [ident],
        limit: 1,
      );
      if (my.isEmpty) continue;
      final version = '${my.first['version']}';
      final had = await vdb.query(
        'dev_marks',
        where: "ident = ? AND peer = ? AND kind = 'mine' AND key = ?",
        whereArgs: [ident, ikey, version],
        limit: 1,
      );
      if (had.isNotEmpty) continue;
      try {
        await send.devicesShown(ident, ikey);
        await vdb.insert('dev_marks', {
          'ident': ident,
          'peer': ikey,
          'kind': 'mine',
          'key': version,
          'at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        dlog('devices: a list to a hidden chat not queued (${e.runtimeType})');
      }
    }
  }

  // the vault is shutting: its side stops and the engine lets its contacts
  // go, with nothing written. their pairs stay heard on, by the cards
  Future<void> _vaultDevicesOut() async {
    final ds = _deviceState;
    _vaultDevReceive = null;
    _vaultDevSend = null;
    _vaultDevOf = null;
    if (ds == null || _vaultDevPeers.isEmpty) return;
    final peers = [..._vaultDevPeers];
    _vaultDevPeers.clear();
    try {
      await ds.call(await live.open(), 'drop_peers', {
        'peers': peers,
        'keep': await _keptByKey(peers),
      });
    } catch (e) {
      dlog('devices: the vault\'s not let go (${e.runtimeType})');
    }
  }

  // of [peers] (identity hex), those the everyday side knows by key alone:
  // they stay known that way
  Future<List<String>> _keptByKey(List<String> peers) async => [
    for (final r in await (await live.open()).query(
      'contacts',
      columns: ['ikey'],
      where: 'ikey IS NOT NULL',
    ))
      if (peers.contains(r['ikey'])) r['ikey'] as String,
  ];

  // a chat moved ([toVault] into the vault, else back): its contact
  // [ikey]'s device state held by the engine from where its rows are now,
  // and heard on from there. after the move's commit
  Future<void> _devMoved(String ikey, {required bool toVault}) async {
    final ds = _deviceState;
    if (!linkedDevicesOn || ds == null) return;
    try {
      final everyday = await live.open();
      // one the everyday side still knows by key alone stays known that way
      final keyOnly =
          toVault &&
          (await everyday.query(
            'contacts',
            columns: ['ikey'],
            where: 'ikey = ?',
            whereArgs: [ikey],
            limit: 1,
          )).isNotEmpty;
      await ds.call(everyday, 'drop_peers', {
        'peers': [ikey],
        'keep': [if (keyOnly) ikey],
      });
      _vaultDevPeers.remove(ikey);
      // into a vault whose side is not running: held by nothing until it
      // opens
      final home = toVault ? _vaultDevOf : live;
      if (home == null) return;
      final hdb = await home.open();
      await ds.call(hdb, 'load_peers', await devPeerLoadArgs(hdb, ids: {ikey}));
      if (toVault) _vaultDevPeers.add(ikey);
      await (toVault ? _vaultDevReceive : _deviceReceive)?.listenAll(
        only: ikey,
      );
    } catch (e) {
      dlog('devices: a moved chat not taken (${e.runtimeType})');
    }
  }

  // before a hide: the everyday side hears on their device pairs no more.
  // their identity key, for the move's end
  Future<String?> _devHiding(String peer) async {
    final recv = _deviceReceive;
    if (!linkedDevicesOn || recv == null || isDevId(peer)) return null;
    try {
      final r = await (await live.open()).query(
        'contacts',
        columns: ['ident', 'ikey'],
        where: 'halo_id = ?',
        whereArgs: [peer],
        limit: 1,
      );
      final ikey = r.isEmpty ? null : r.first['ikey'] as String?;
      if (ikey == null) return null;
      await recv.unlistenAll(r.first['ident'] as int? ?? kMainIdent, ikey);
      return ikey;
    } catch (e) {
      dlog('devices: a hidden chat still heard (${e.runtimeType})');
      return null;
    }
  }

  // after an unhide's commit: the identity key the everyday row names
  Future<String?> _devShownKey(String peer) async {
    if (!linkedDevicesOn || _deviceState == null || isDevId(peer)) return null;
    final r = await (await live.open()).query(
      'contacts',
      columns: ['ikey'],
      where: 'halo_id = ? AND accepted = 1',
      whereArgs: [peer],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['ikey'] as String?;
  }

  /// the hidden chats' device pairs as their cards name them, heard on:
  /// their keys told to the engine, their seeds, and a listen on each.
  /// while the vault is shut what the cards no longer name goes; while it
  /// is open its own side listens, and only a contact no card names any
  /// more is let go here
  Future<void> _listenHiddenDevices() async {
    if (!linkedDevicesOn || _deviceState == null) return;
    final cards = _router.hiddenDevices;
    final want = <String, int>{};
    final keys = <String, ({int ident, String identity, String held})>{};
    for (final d in cards.values) {
      if (d.pairs.isEmpty) continue;
      final x = d.identity.substring(2);
      keys['${d.ident}/${d.identity}'] = (
        ident: d.ident,
        identity: d.identity,
        held: jsonEncode([
          for (final p in d.pairs) {'id': p.their, 'key': p.key},
        ]),
      );
      for (final p in d.pairs) {
        final pair = '$x/${p.their}/${p.my}';
        if (p.opener) want[pair] = d.ident;
        if (p.seed != null) {
          final arg = '$pair.${p.seed}';
          if (_hiddenHeard[arg] == d.ident) {
            want[arg] = d.ident;
          } else if (await engine.pairSeed(d.ident, pair, p.seed!) == 'ok') {
            want[arg] = d.ident;
          }
        }
      }
    }
    final open = _vaultDevReceive != null;
    final named = {for (final d in cards.values) d.identity.substring(2)};
    for (final e in [..._hiddenHeard.entries]) {
      if (want.containsKey(e.key)) continue;
      if (open && named.contains(e.key.split('/').first)) continue;
      _hiddenHeard.remove(e.key);
      engine.deviceUnlistenBg(e.value, e.key);
    }
    for (final e in keys.entries) {
      if (_hiddenKeysTold[e.key] == e.value.held) continue;
      try {
        await _deviceState!.call(await live.open(), 'listen_keys', {
          'ident': e.value.ident,
          'identity': e.value.identity,
          'held': jsonDecode(e.value.held),
        });
        _hiddenKeysTold[e.key] = e.value.held;
      } on DevRefused catch (x) {
        dlog('devices: hidden keys not told (${x.why})');
      }
    }
    for (final k in [..._hiddenKeysTold.keys]) {
      if (keys.containsKey(k)) continue;
      _hiddenKeysTold.remove(k);
      final cut = k.indexOf('/');
      try {
        await _deviceState!.call(await live.open(), 'listen_keys', {
          'ident': int.parse(k.substring(0, cut)),
          'identity': k.substring(cut + 1),
        });
      } on DevRefused {
        // nothing held
      }
    }
    for (final e in want.entries) {
      if (_hiddenHeard[e.key] == e.value) continue;
      _hiddenHeard[e.key] = e.value;
      engine.deviceListenBg(e.value, e.key, hidden: true);
    }
  }

  // my lists changed (devices_send_app.dart): the open vault's side queues
  // its own pushes; while it is shut a removal is owed (kHiddenRemovalMeta)
  // and goes at once to each hidden contact's phone that reads lists, on
  // the phone pair the everyday side holds, so a removed device of mine
  // stops getting their copies now. additions wait for the vault's next
  // open
  Future<void> _hiddenListsChanged(
    List<({int ident, int version, List<int> added, bool removed})> changes,
  ) async {
    if (!linkedDevicesOn) return;
    final v = _vaultDevSend;
    if (v != null) {
      try {
        await v.listsChanged(changes);
      } catch (e) {
        dlog('devices: the vault\'s pushes not queued (${e.runtimeType})');
      }
    }
    // the everyday send loop kept what is owed (kHiddenRemovalMeta) with
    // its own pushes, in one write
    await _pushHiddenRemovals();
  }

  // the removals owed to hidden contacts: with the vault open, queued as
  // its own pushes (kept in it until each phone answers) and marked queued
  // in the vault; while it is shut, my list as I hold it to each hidden
  // contact's phone, the same bytes each time, once a version a start. the
  // everyday value goes by its age alone, vault or no vault
  Future<void> _pushHiddenRemovals() async {
    final ds = _deviceState;
    if (!linkedDevicesOn || ds == null) return;
    final db = await live.open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final owed = <int, ({int version, int at})>{};
    for (final r in await db.query(
      'signal_meta',
      columns: ['k', 'v'],
      where: 'k LIKE ?',
      whereArgs: ['$kHiddenRemovalMeta%'],
    )) {
      final k = r['k'] as String;
      final ident = int.tryParse(k.substring(kHiddenRemovalMeta.length));
      final o = hiddenRemovalOf(r['v'] as String?);
      if (ident == null || o == null) continue;
      if (now - o.at > kRemovePushKept.inMilliseconds) {
        await dropDevMeta(db, k);
        continue;
      }
      owed[ident] = o;
    }
    if (owed.isEmpty) return;
    final v = _vaultDevSend;
    final vdb = _vaultDevOf;
    if (v != null && vdb != null) {
      try {
        final vd = await vdb.open();
        for (final e in owed.entries) {
          final key = '${e.value.version}';
          final had = await vd.query(
            'dev_marks',
            where: "ident = ? AND peer = '' AND kind = ? AND key = ?",
            whereArgs: [e.key, kHiddenRemovalQueued, key],
            limit: 1,
          );
          if (had.isEmpty) {
            await v.listsChanged([
              (
                ident: e.key,
                version: e.value.version,
                added: const [],
                removed: true,
              ),
            ]);
            await vd.insert('dev_marks', {
              'ident': e.key,
              'peer': '',
              'kind': kHiddenRemovalQueued,
              'key': key,
              'at': now,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final c in _router.hiddenDevices.entries) {
            if (c.value.ident == e.key) {
              _hiddenRemovalsSent[c.key] = e.value.version;
            }
          }
        }
      } catch (e) {
        dlog('devices: the vault\'s removals wait (${e.runtimeType})');
      }
      return;
    }
    for (final e in _router.hiddenDevices.entries) {
      final card = e.value;
      final o = owed[card.ident];
      if (!card.lists || o == null) continue;
      // past the relays' keep only the vault's open queues it
      if (now - o.at > kRemovePushGapMost.inMilliseconds) continue;
      final version = o.version;
      if ((_hiddenRemovalsSent[e.key] ?? 0) >= version) continue;
      try {
        final cur =
            jsonDecode(ds.engine.call('current', {'ident': card.ident}))
                as Map<String, dynamic>;
        final list = cur['list'];
        if (cur['err'] != null || list is! String) continue;
        final w = base64Decode(list);
        final at = w.length < 45
            ? 0
            : ByteData.sublistView(w, 37, 45).getUint64(0);
        final frame =
            '$kEnvelopePrefix${jsonEncode({'u': 'dl:$at', 'dl': list})}';
        if (await _hiddenPhoneSend(card.ident, e.key, card.identity, frame)) {
          _hiddenRemovalsSent[e.key] = max(version, at);
        }
      } catch (x) {
        dlog('devices: a removal to a hidden chat waits (${x.runtimeType})');
      }
    }
  }

  @visibleForTesting
  Future<void> hiddenListsChangedForTest(
    List<({int ident, int version, List<int> added, bool removed})> changes,
  ) => _hiddenListsChanged(changes);

  @visibleForTesting
  Future<void> pushHiddenRemovalsForTest() => _pushHiddenRemovals();

  // a line on a device pair of a hidden chat's contact while the vault is
  // shut: sealed as it came, opened as the vault opens
  Future<bool> _sealDeviceLine(
    String peer,
    String tag,
    String cipher, {
    int? wrappedAt,
    Reached? reached,
  }) async {
    _lastSealAt = DateTime.now().millisecondsSinceEpoch;
    return _router.seal(
      Unsealed(
        peer,
        cipher,
        false,
        _lastSealAt,
        wrapped: wrappedAt,
        reached: reached,
        deviceTag: tag,
      ),
    );
  }

  // a sealed device line, as the vault [vault] opens: opened on the
  // device's session the vault holds, admitted, filed in it. false when it
  // waits for the vault's side to run
  Future<bool> _unsealDeviceLine(HaloDb vault, Unsealed u) async {
    if (!linkedDevicesOn) return true;
    final r = _vaultDevReceive;
    if (r == null || !identical(_vaultDevOf, vault)) return false;
    final got = await r.receive(u.deviceTag!, u.wire);
    if (got == null) return true;
    await _applyIncomingPayload(
      got.peer,
      unwrapMessage(got.frame),
      wire: got.frame,
      fromDevice: true,
      into: vault,
      arrivedAt: u.at,
      wrappedAt: u.wrapped,
      reached: u.reached,
    );
    return true;
  }
}
