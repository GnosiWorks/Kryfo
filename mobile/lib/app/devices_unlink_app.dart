// SPDX-License-Identifier: GPL-3.0-or-later
// removing linked devices in the app (own_unlink.dart): the devices page's
// remove and remove all, the phone's own time online that removes a device
// not used for 30 days of it, a device that says it unlinked itself. on a
// linked device: its lock state checked at every start and hourly, and its
// end (removed by its phone, unused, its clock set back, unlinked there):
// the wipe first, then the last word to the phone, then the page that says
// what happened. a restored phone's first list. never from the decoy or a
// quiet session, nothing with the switch off

part of '../main.dart';

OwnUnlink? _ownUnlink;
LinkedLock? _linkedLock;
Timer? _onlineTimer;
Timer? _linkedTimer;

/// how often the phone counts its own time online
const kOnlineTickEvery = Duration(minutes: 5);

/// how often a linked device checks its lock state while it runs
const kLinkedCheckEvery = Duration(hours: 1);

/// set once a linked device unlinked: the page over everything says why
final deviceUnlinked = ValueNotifier<LinkedEnd?>(null);

/// a linked device's lock state, in the support folder under a key in the
/// secret store
LinkedLock get linkedLock => _linkedLock ??= LinkedLock(
  dir: () async => (await getApplicationSupportDirectory()).path,
  readKey: (k) => secureStore.read(key: k),
  writeKey: (k, v) => secureStore.write(key: k, value: v),
);

@visibleForTesting
set linkedLockForTest(LinkedLock? l) => _linkedLock = l;

/// the removals, once the device state loaded; null before or with the
/// switch off
OwnUnlink? get ownUnlink => _ownUnlink;

void _bootUnlink(DeviceState ds, DeviceSend send, DeviceReceive recv) {
  _ownUnlink = OwnUnlink(
    state: ds,
    db: live.open,
    send: send,
    recv: recv,
    me: _devMeOf,
    sign: (ident, body) async {
      final ss = await signalOfIdent(ident);
      return ss.lib.sign(ss.identity, LsSigContext.deviceList, body);
    },
    historyEnd: _historyUnlinked,
    allowed: () => _ownSends && !linkedRole,
    // the push book lets the removed devices' addresses go at its next round
    removed: (_, _) => _madeApp?._helperSoon(),
  );
  recv.ownLeft = (ident, device, key, why) async =>
      _ownUnlink?.left(ident, device, key);
  // the callbacks run inside a receive: the wipe goes on beside it
  recv.ownRemoved = (_) async => unawaited(_linkedEnds(LinkedEnd.removed));
  recv.ownGoneHere = (ident, gone) async {
    final db = await live.open();
    final uids = await ownDevicesWithKeys(db, ident, [
      for (final g in gone) (id: g.id, key: g.key),
    ]);
    if (uids.isEmpty) return;
    await markOwnDevicesGone(
      db,
      uids,
      why: kGoneRemoved,
      at: DateTime.now().millisecondsSinceEpoch,
      notice: true,
    );
    await readLinkNotices(db);
  };
  recv.alarms.listen((a) {
    if (a.kind != 'unknown_device') return;
    unawaited(() async {
      try {
        await readLinkNotices(await live.open());
      } catch (_) {
        // read at the next start
      }
    }());
  });
  _onlineTimer?.cancel();
  _onlineTimer = Timer.periodic(kOnlineTickEvery, (_) {
    // nothing of it while this device is being erased
    if (haloWiping) return;
    unawaited(linkedRole ? _quietTick() : _onlineTick());
  });
  if (!linkedRole) {
    unawaited(_onlineTick());
    // a removal a kill cut short, or one that waited, is finished now
    unawaited(() async {
      try {
        await _ownUnlink?.removeUnused();
      } catch (e) {
        dlog('devices: a removal waits (${e.runtimeType})');
      }
    }());
    // the last words still owed get their addresses back
    unawaited(() async {
      try {
        final db = await live.open();
        for (final r in await db.rawQuery(
          'SELECT DISTINCT ident FROM dev_farewell',
        )) {
          await send.leaving(r['ident'] as int);
        }
        await pruneGoneDevices(db, DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        dlog('devices: last words wait (${e.runtimeType})');
      }
    }());
  }
}

// the phone's time in touch with a relay since the last tick counts for
// every device; one past 30 days of it is removed, from the everyday side
// alone. a removal owed goes with it
Future<void> _onlineTick() async {
  final u = _ownUnlink;
  if (u == null || linkedRole) return;
  try {
    final due = await u.tick(online: _relayInTouch(u.lastTick));
    if (due.isNotEmpty) await u.removeUnused();
  } catch (e) {
    dlog('devices: time online not counted (${e.runtimeType})');
  }
}

// whether a relay answered since [since], read at the tick itself
bool _relayInTouch(int? since) {
  appState.sampleRelayUp();
  return relayContactSince(appState.relayUpAt, since);
}

// a linked device's time in touch with a relay without a word from its
// phone: past 30 days of it, the phone holds it no more and it ends
Future<void> _quietTick() async {
  final u = _ownUnlink;
  if (u == null || !linkedRole || haloWiping || deviceUnlinked.value != null) {
    return;
  }
  try {
    // a removal taken and not finished ends it now, not at the hour
    final end = await _linkedStanding();
    if (end != null) return _linkedEnds(end);
    if (await u.quietTick(online: _relayInTouch(u.lastQuiet))) {
      await _linkedEnds(LinkedEnd.silent);
    }
  } catch (e) {
    dlog('devices: the quiet time not counted (${e.runtimeType})');
  }
}

/// the devices page's removal: from the everyday side of the phone alone
Future<void> _unlinkOwn(List<String> uids) async {
  await _ownUnlink?.remove(uids, why: kGoneRemoved);
}

// a device's history copy ends at once: a run of it stops, the door says
// "ended" from the copy's ask key, the stream key goes
Future<void> _historyUnlinked(String uid) async {
  _phoneCopies[uid]?.stop();
  for (var i = 0; i < 50 && _phoneRuns.running(uid); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await PhoneHistoryCopy.unlinked(await live.open(), uid, EngineHistoryDoor());
}

// ---- a linked device ----

/// a person used this device: its lock state says so. checked first: a
/// device past its 30 days ends, a use never brings it back
void linkedUsed() {
  if (!linkedRole || haloWiping || deviceUnlinked.value != null) return;
  unawaited(() async {
    final LinkedEnd? end;
    try {
      end = await linkedLock.check();
    } catch (_) {
      return _linkedEnds(LinkedEnd.broken);
    }
    if (end != null) return _linkedEnds(end);
    try {
      await linkedLock.used();
    } catch (e) {
      dlog('devices: a use not kept (${e.runtimeType})');
    }
  }());
}

/// a linked device's lock state at its start, before anything of it runs:
/// null while all is well
Future<LinkedEnd?> _linkedPeek() async {
  if (!linkedRole) return null;
  try {
    return await _linkedStanding() ?? await linkedLock.check();
  } catch (_) {
    return LinkedEnd.broken;
  }
}

@visibleForTesting
Future<LinkedEnd?> linkedStandingForTest() => _linkedStanding();

/// a test's stand-in for a linked device's erase
@visibleForTesting
Future<void> Function()? linkedWipeForTest;

/// a linked device's 5-minute tick, as its timer runs it
@visibleForTesting
Future<void> linkedTickForTest() => _quietTick();

/// a linked device that ended, as before it did
@visibleForTesting
void linkedEndResetForTest() {
  _linkedEnding = false;
  _linkedWipe = null;
  deviceUnlinked.value = null;
}

// a linked device's standing with its phone: its phone's signed list
// without it was taken (the list held went with it) and the wipe did not
// finish, a kill or a cut start in between. only that list drops it, so
// nobody else can bring this on
Future<LinkedEnd?> _linkedStanding() async {
  if (!linkedRole) return null;
  try {
    return await ownListHeld(await live.open(), kMainIdent)
        ? null
        : LinkedEnd.removed;
  } catch (e) {
    // not read: asked again at the next tick, never a wipe for it
    dlog('devices: the standing not read (${e.runtimeType})');
    return null;
  }
}

// at every start of a linked device, and hourly while it runs
Future<void> _linkedBoot() async {
  if (!linkedRole) return;
  // linked, so set up: a kill between the link and the mark left it unsaid
  if (!appState.onboardingComplete) await appState.markOnboardingComplete();
  await _linkedCheck();
  _linkedTimer ??= Timer.periodic(
    kLinkedCheckEvery,
    (_) => unawaited(_linkedCheck()),
  );
}

Future<void> _linkedCheck() async {
  if (!linkedRole || haloWiping || deviceUnlinked.value != null) return;
  final LinkedEnd? end;
  try {
    end = await _linkedStanding() ?? await linkedLock.check();
  } catch (_) {
    return _linkedEnds(LinkedEnd.broken);
  }
  if (end != null) await _linkedEnds(end);
}

// set once a linked device's end began: a second one (the hourly check
// and a removal at once) does nothing
bool _linkedEnding = false;

// the erase of a linked device that ended, for the page's close
Future<void>? _linkedWipe;

/// how long a linked device's last word may take to seal before the wipe
/// goes on without it
const kLinkedWordMost = Duration(seconds: 2);

/// this linked device ends: its last word to the phone sealed first (but
/// for a removal, which the phone made), then everything erased, then the
/// word handed to the relay, and the page says what happened
Future<void> _linkedEnds(LinkedEnd why) async {
  if (!linkedRole || haloWiping || deviceUnlinked.value != null) return;
  if (_linkedEnding) return;
  _linkedEnding = true;
  final ds = _deviceState;
  // at a start the send loop may not run yet: one for the word alone
  final send = _deviceSend ?? (ds == null ? null : _wordSend(ds));
  DevLast? last;
  final word = linkedEndWord(why);
  if (word != null && send != null && ds != null) {
    try {
      last = await _sealWord(send, ds, word).timeout(kLinkedWordMost);
    } catch (e) {
      dlog('devices: no last word (${e.runtimeType})');
    }
  }
  _linkedTimer?.cancel();
  _onlineTimer?.cancel();
  deviceUnlinked.value = why;
  final told = last;
  final fake = linkedWipeForTest;
  final wipe = fake != null
      ? fake()
      : wipeHalo(
          stay: true,
          afterErase: told == null || send == null
              ? null
              : () async {
                  await send.handLast(kMainIdent, told);
                },
        );
  _linkedWipe = wipe;
  await wipe;
}

// a send loop for a linked device's last word alone: no listens, no pump
DeviceSend _wordSend(DeviceState ds) {
  engine.devicePairsOn(true);
  return DeviceSend(
    state: ds,
    db: live.open,
    sessions: (ident) async => DeviceSessions(await signalOfIdent(ident)),
    wire: _EngineDeviceWire(),
  );
}

/// the page's close: once the erase is done, the app ends
Future<void> _closeUnlinked() async {
  try {
    await _linkedWipe;
  } catch (_) {
    // the end goes on: what is left is sealed and the next start wipes
  }
  await wipeFinish();
}

// the 'ou' word to my phone, sealed on its own session
Future<DevLast?> _sealWord(DeviceSend send, DeviceState ds, String word) async {
  final m = await _devMeOf(kMainIdent);
  final cur = await ds.call(await live.open(), 'current', {
    'ident': kMainIdent,
  });
  final phone = [
    for (final e in (cur['devices'] as List? ?? const []))
      if (e is Map && e['id'] == 1) e,
  ];
  if (m == null || phone.isEmpty) return null;
  return send.sealLast(
    me: m,
    identity: devHex(m.identity),
    device: 1,
    addr: kOwnDevices,
    pin: phone.first['key'] as String,
    reg: (phone.first['reg'] as num?)?.toInt() ?? 0,
    frame:
        '$kEnvelopePrefix${jsonEncode({
          'u': 'ou:${m.device}',
          'ou': {'w': word},
        })}',
  );
}

/// this linked device unlinks itself, from its devices page
Future<void> _leaveHere() => _linkedEnds(LinkedEnd.self);
