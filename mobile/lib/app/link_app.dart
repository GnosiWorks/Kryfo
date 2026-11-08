// SPDX-License-Identifier: GPL-3.0-or-later
// linking in the app: the devices page's source, the phone's side of a
// link (sign the next list, keep what the device sent), and the new
// device's side (take its place, make its bundles). a linked device holds
// its own device key alone: the identity it serves is a public key in
// ident_pub, never a private one. nothing here runs with the switch off

part of '../main.dart';

bool _linkedRole = false;

/// this container is a linked device's: it has no identity of its own,
/// only its device key for the account on its phone. no invites, handle,
/// backups, decoy, vault, rooms or developer chat here
bool get linkedRole => linkedDevicesOn && _linkedRole;

@visibleForTesting
set linkedRoleForTest(bool on) => _linkedRole = on;

/// read once the everyday container is open
Future<void> readLinkedRole(DatabaseExecutor db) async {
  if (!linkedDevicesOn) return;
  _linkedRole = await linkedRoleOf(db);
  await readLinkNotices(db);
}

/// a linked device's tor is a client: it reaches relays and its phone's
/// onion and publishes no onion of its own (decision 4). told before tor's
/// first start, and right after a link, whose process published the new
/// device's onion already: the engine takes that one down. on a phone this
/// does nothing
Future<void> torAsLinked({required String at}) async {
  if (!linkedDevicesOn) return;
  if (at == 'boot') {
    try {
      _linkedRole = await linkedRoleOf(await live.open());
    } catch (e) {
      dlog('linked: role not read before tor (${e.runtimeType})');
    }
  }
  if (!linkedRole) return;
  appState.myOnion = '';
  try {
    final r = await engine.torClientOnly();
    if (r != 'ok') dlog('linked: tor as a client at $at: $r');
  } catch (e) {
    dlog('linked: tor as a client at $at (${e.runtimeType})');
  }
  await shredPreLinkOnion();
}

/// the onion key this device made before its link: a client tor never
/// reads it again, so it does not stay on the disk in the clear. after the
/// flag above, so a start can no longer read it. desktop keeps its copy
/// sealed and hands it to the engine per start, left as it is there
@visibleForTesting
Future<void> shredPreLinkOnion() async {
  if (onDesktop) return;
  try {
    final docs = await getApplicationDocumentsDirectory();
    await shredFile(p.join(docs.path, 'onion.key'));
  } catch (e) {
    dlog('linked: the old onion key not shredded (${e.runtimeType})');
  }
}

/// where the devices page reads from, for the session open now. the
/// decoy's is this phone alone, linking to nobody: it reads nothing real
Future<OwnDevices> ownDevicesSource() async {
  if (sessionQuiet || lockState.inDecoy) {
    return DecoyDevices(
      phoneName: l10n.devicesThisPhoneShown,
      here: !onDesktop,
    );
  }
  final db = await live.open();
  if (linkedRole) {
    return StoredOwnDevices(
      db: db,
      thisName: l10n.devicesThisPhoneShown,
      thisKind: onDesktop ? DeviceKind.computer : DeviceKind.phone,
      phoneName: l10n.devicesYourPhone,
      leave: _leaveHere,
    );
  }
  return StoredOwnDevices(
    db: db,
    thisName: l10n.devicesThisPhoneShown,
    thisKind: onDesktop ? DeviceKind.computer : DeviceKind.phone,
    unlink: _ownUnlink == null ? null : _unlinkOwn,
    // phones link in 0.6: a computer that holds the account has no camera
    // to scan with
    link: deviceState == null || onDesktop
        ? null
        : (code, history) => PhoneLinkFlow(
            EngineLinkCalls(),
            code: code,
            hooks: _PhoneLinkApp(history),
          ),
  );
}

Uint8List _linkUnhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

// the phone's side
class _PhoneLinkApp implements PhoneLinkHooks {
  _PhoneLinkApp(this.history);
  // what the new device gets of the history: chats and contacts always,
  // their messages unless "no history", their files unless skipped
  final LinkHistory history;

  Future<IdentityRow> _main() async {
    final row = await identityRow(await live.open(), kMainIdent);
    if (row == null) throw StateError('no main identity');
    return row;
  }

  @override
  Future<String> identity() async {
    final row = await _main();
    return devHex(signalSession.lib.identityFromPrivate(row.xPriv).public);
  }

  @override
  Future<int> phoneReg() async => (await _main()).regId;

  @override
  Future<Uint8List> sign(Uint8List body) async {
    final lib = signalSession.lib;
    return lib.sign(
      lib.identityFromPrivate((await _main()).xPriv),
      LsSigContext.deviceList,
      body,
    );
  }

  @override
  Future<void> keep(LinkTaken t, Future<void> Function() kept) async {
    final ds = deviceState;
    if (ds == null) throw StateError('devices not loaded');
    final db = await live.open();
    final now = DateTime.now();
    // the own session from the device's first bundle comes first: its
    // prekey signatures are checked here, and a bad bundle keeps nothing.
    // the first frame on it is the opener with the list and the history
    final key = _linkUnhex(t.key);
    final lib = signalSession.lib;
    final me = lib.identityFromPrivate((await _main()).xPriv).public;
    final sessions = DeviceSessions(signalSession);
    await sessions.build(
      kOwnDevices,
      t.device,
      lib.parseDeviceBundle(t.first, me),
      key,
      t.reg,
    );
    final uid = newDeviceUid();
    final bind = t.bind;
    try {
      await db.transaction((tx) async {
        // a last word still owed to a device removed under this id goes:
        // it would go to the new device's pair with the old seed
        await tx.delete(
          'dev_farewell',
          where: 'ident = ? AND device = ?',
          whereArgs: [kMainIdent, t.device],
        );
        await ds.ownMine(tx, kMainIdent, t.list);
        await ds.call(tx, 'pool_put', {
          'ident': kMainIdent,
          'device': t.device,
          'once': [for (final b in t.once) base64Encode(b)],
          'last': base64Encode(t.last),
          'made': t.made,
          'now': now.millisecondsSinceEpoch,
        });
        await addOwnDevice(
          tx,
          uid: uid,
          // phones link computers in 0.6: named by that kind
          name: l10n.devicesNameComputer,
          kind: DeviceKind.computer,
          linkedAt: now,
          // the link is a use of it
          heardAt: now,
          keys: [(ident: kMainIdent, dev: t.device, key: t.key, reg: t.reg)],
          stream: bind == null ? null : t.stream,
          hist: bind == null
              ? null
              : historyCopyHist(
                  bind: bind,
                  identityHex: devHex(me),
                  choice: switch (history) {
                    LinkHistory.all => 'all',
                    LinkHistory.textOnly => 'text',
                    LinkHistory.none => 'none',
                  },
                ),
        );
        // last, inside: the engine acks the device only now, and when it
        // gave up already nothing here is kept
        await kept();
      });
    } catch (_) {
      // the engine's state as the rows are, and no session left behind
      await sessions.drop(kOwnDevices, t.device);
      await bootDevices();
      rethrow;
    }
    await readLinkNotices(db);
    // the engine's leaving keys as the rows are now
    try {
      await _deviceSend?.leaving(kMainIdent);
    } catch (e) {
      dlog('devices: leaving keys not set (${e.runtimeType})');
    }
    // the history copy for the new device, made and served from here
    if (bind != null) startPhoneHistoryCopy(uid);
    // my profile and badge, so what the device sends carries the badge
    unawaited(_madeApp?._ownTellMe());
    // the contacts who read lists learn of the new device, spread out
    // over passes. the link is kept whatever happens here
    try {
      final held = await db.query(
        'dev_lists',
        columns: ['version'],
        where: "ident = ? AND owner = 'me'",
        whereArgs: [kMainIdent],
        limit: 1,
      );
      if (held.isNotEmpty) {
        await deviceSend?.listsChanged([
          (
            ident: kMainIdent,
            version: held.first['version'] as int,
            added: [t.device],
            removed: false,
          ),
        ]);
      }
    } catch (e) {
      dlog('devices: the new list waits for its pushes (${e.runtimeType})');
    }
  }
}

/// a new link on this device, as a new device joining a phone
LinkFlow newJoinFlow() =>
    JoinLinkFlow(EngineLinkCalls(), hooks: _JoinLinkApp());

// the new device's side
class _JoinLinkApp implements JoinLinkHooks {
  @override
  Future<({String key, int reg})> myKey() async {
    await appState._signalReady.future;
    return (
      key: devHex(signalSession.identity.public),
      reg: signalSession.registrationId,
    );
  }

  // the place, in memory: the engine's state as the device would hold it,
  // nothing in the container until joined
  @override
  Future<void> placed(JoinPlace p) async {
    final db = await live.open();
    final path = KryfoSignal.loadedFrom;
    if (path == null) throw StateError('the signal library has no path');
    final key = signalSession.identity.public;
    final ds = DeviceState(DeviceEngine());
    await ds.load(db, [
      (
        ident: kMainIdent,
        identity: _linkUnhex(p.identity),
        key: key,
        dev: p.device,
      ),
    ], shimPath: path);
    _deviceState = ds;
  }

  @override
  Future<JoinBundles> bundles(int device, int want) async {
    final ds = DeviceSessions(signalSession, linked: true);
    final first = await ds.makeBundle(device);
    final last = await ds.lastResortBundle(device);
    return (
      first: first,
      last: last,
      once: [for (var i = 0; i < want; i++) await ds.makeBundle(device)],
      made: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> joined(
    JoinPlace p,
    LinkStream stream,
    Map<String, dynamic> ownRows,
  ) async {
    // its own end is kept from the start: a linked device with no lock
    // state wipes at its next start
    await linkedLock.start();
    await joinedRows(
      await live.open(),
      identity: _linkUnhex(p.identity),
      device: p.device,
      rows: (ownRows['rows'] as List?) ?? const [],
      stream: stream.key,
      bind: stream.bind,
      onion: stream.onion,
    );
    _linkedRole = true;
    // no onion of its own from here: the one this process published goes
    unawaited(torAsLinked(at: 'link'));
    // the state as the rows now hold it, loaded as every start loads it
    await bootDevices();
    // the history copy comes from the phone from here
    startDeviceHistoryCopy();
    // linked: the app opens as the linked device from here, whatever
    // happens to this page
    await appState.markOnboardingComplete();
  }

  // the container as it was: the state loaded again from its rows
  @override
  Future<void> failed() => bootDevices();
}

// what a device of mine is called when another device of mine learns of it
// from my list (devices_own_app.dart): renamed in the list
String get _ownDeviceName => l10n.devicesNameComputer;
