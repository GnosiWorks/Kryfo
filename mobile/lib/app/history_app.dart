// SPDX-License-Identifier: GPL-3.0-or-later
// the history copy in the app: the phone makes and serves a copy for each
// device it linked, the linked device takes its own in. both start when
// the link is done and again at every start until the copy is over, and
// what it came to is kept until the person has seen it. the real everyday
// container only: never the decoy, never the vault, nothing with the
// switch off

part of '../main.dart';

final _phoneCopies = <String, PhoneHistoryCopy>{};
final _phoneRuns = HistoryCopyRuns();
DeviceHistoryCopy? _deviceCopy;

/// the copy the home card and the copy page show: the device's own on a
/// linked device, on the phone the one last under way
final historyCopyShown = ValueNotifier<HistoryCopyStage?>(null);

/// the person has seen how the copy ended: the card goes
final historyCopySeen = ValueNotifier<bool>(true);

const _kHistoryCopySeenMeta = 'history_copy_seen';

bool get _copiesHere =>
    linkedDevicesOn &&
    !sessionQuiet &&
    !lockState.inDecoy &&
    live.container == HaloContainer.everyday;

/// the private folder spools go in: kept out of every backup
Future<String> _historySpoolDir() async {
  final d = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'history'),
  );
  await d.create(recursive: true);
  return d.path;
}

Future<HistoryOutgoing> _makeHistory({
  required String keyHex,
  required String bindHex,
  required String identityHex,
  required bool skipMedia,
  required bool rowsOnly,
}) async {
  if (!_copiesHere) throw const HistoryNotHere('session');
  return exportHistory(
    db: await live.open(),
    container: live.container,
    mediaDir: (await HaloContainer.everyday.mediaDir()).path,
    spoolDir: await _historySpoolDir(),
    keyHex: keyHex,
    bindHex: bindHex,
    identityHex: identityHex,
    skipMedia: skipMedia,
    rowsOnly: rowsOnly,
    hold: appState.withVaultStill,
    fileKeyOf: _historyFileKey,
  );
}

// a media file's own key for the device, when it is sealed here. a key
// that cannot be had leaves the file's bytes unopenable there: the device
// counts it as not come
Uint8List? _historyFileKey(String path) {
  try {
    return fileKeyOf(path);
  } catch (e) {
    dlog('history: a file key not read (${e.runtimeType})');
    return null;
  }
}

void _showCopy(ValueNotifier<HistoryCopyStage> s) {
  void moved() {
    historyCopyShown.value = s.value;
    if (historyCopyOver(s.value.step)) unawaited(_copyEnded());
  }

  s.addListener(moved);
  moved();
}

Future<void> _copyEnded() async {
  try {
    final db = await live.open();
    final r = await db.query(
      'signal_meta',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [_kHistoryCopySeenMeta],
    );
    historyCopySeen.value = r.isNotEmpty;
  } catch (_) {
    historyCopySeen.value = false;
  }
}

/// the person opened the copy's page once it was over
Future<void> historyCopyOpened() async {
  final s = historyCopyShown.value;
  if (s == null || !historyCopyOver(s.step)) return;
  historyCopySeen.value = true;
  try {
    final db = await live.open();
    await db.insert('signal_meta', {
      'k': _kHistoryCopySeenMeta,
      'v': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  } catch (e) {
    dlog('history: seen not kept (${e.runtimeType})');
  }
}

/// the phone's copy for the device [uid] it just kept, or that a start
/// finds under way
void startPhoneHistoryCopy(String uid) {
  if (!_copiesHere) return;
  // taken before any await: a second start for the device waits for none
  unawaited(
    _phoneRuns.start(uid, () async {
      final db = await live.open();
      final c = PhoneHistoryCopy(
        db: db,
        uid: uid,
        door: EngineHistoryDoor(),
        make: _makeHistory,
      );
      _phoneCopies[uid] = c;
      _showCopy(c.stage);
      try {
        // a new copy, not yet seen
        await db.delete(
          'signal_meta',
          where: 'k = ?',
          whereArgs: [_kHistoryCopySeenMeta],
        );
        await c.run();
      } catch (e) {
        dlog('history: the phone\'s copy stopped (${e.runtimeType})');
      } finally {
        if (_phoneCopies[uid] == c) _phoneCopies.remove(uid);
      }
    }),
  );
}

/// a linked device takes its copy in, from where it was
void startDeviceHistoryCopy() {
  if (!_copiesHere || !linkedRole || _deviceCopy != null) return;
  unawaited(() async {
    final db = await live.open();
    final place = await linkPlaceOf(db);
    final key = await linkStreamOf(db);
    if (place == null) return;
    final kept = await DeviceHistoryCopy.kept(db);
    if (key == null && (kept == null || !historyCopyOver(kept.step))) return;
    final c = _deviceCopy = DeviceHistoryCopy(
      db: db,
      mediaDir: (await HaloContainer.everyday.mediaDir()).path,
      wire: EngineHistoryWire(
        onion: place.onion,
        keyHex: key == null ? '' : historyHex(key),
        bindHex: place.bind,
      ),
      identityHex: place.identity,
      bindHex: place.bind,
      landed: (lists) => _copyLanded(db, lists),
      unlanded: _copyTakenBack,
      forgetKey: () => forgetLinkStream(db),
      coming: historyFilesComing,
      rowsIn: _copyRowsIn,
    );
    _showCopy(c.stage);
    await _copyEnded();
    try {
      await c.run();
    } catch (e) {
      dlog('history: the copy stopped (${e.runtimeType})');
    } finally {
      if (_deviceCopy == c) _deviceCopy = null;
    }
  }());
}

// chats and messages of the copy came in: the home list shows them as they
// come, a beat apart at most, not only after the next start
Timer? _copyRowsSoon;
void _copyRowsIn() {
  if (_copyRowsSoon?.isActive ?? false) return;
  _copyRowsSoon = Timer(const Duration(milliseconds: 700), () {
    unawaited(() async {
      try {
        await appState.refreshContacts();
        await appState.refreshGroups();
      } catch (e) {
        dlog('history: lists not refreshed (${e.runtimeType})');
      }
      await _copyHearNew();
    }());
  });
}

// the contacts the copy brought so far are known to the device state and
// heard on now, not only once it landed: a contact's app opens a pair to
// this device as soon as my phone's list reaches it, so sending works while
// the copy runs. their own lists still come last, with the copy's end
final _copyHeard = <String>{};
Future<void> _copyHearNew() async {
  if (!linkedRole) return;
  try {
    await deviceReceive?.hearNew(_copyHeard);
  } catch (e) {
    dlog('history: copied contacts not heard yet (${e.runtimeType})');
  }
}

// every record is in: the contacts that came are known to the device state,
// their lists the phone held are taken as first lists, the device listens
// for them, and what came early for the copied messages goes in
Future<void> _copyLanded(
  Database db,
  List<({String identity, String wire})> lists,
) async {
  await bootDevices();
  final ds = deviceState;
  if (ds != null) {
    for (final l in lists) {
      try {
        await ds.call(db, 'copy_list', {
          'ident': kMainIdent,
          'identity': l.identity,
          'list': l.wire,
        });
      } on DevRefused catch (e) {
        dlog('history: a held list not taken (${e.why})');
      }
    }
  }
  // the proofs the copy brought count once their contact's list is held
  if (ds != null && lists.isNotEmpty) await bootDevices();
  try {
    await deviceReceive?.listenAll();
  } catch (e) {
    dlog('history: listens wait (${e.runtimeType})');
  }
  await appState.applyEarlyCopied();
  // my phone hears this device is in use and tells it my name, which a
  // word sent at the link itself can miss
  unawaited(_ownBeat());
}

// a copy taken back: the contacts it made are forgotten by the device
// state (their lists, proofs, listens) before their rows go
Future<void> _copyTakenBack(List<String> haloIds) async {
  _copyHeard.clear();
  for (final id in haloIds) {
    try {
      await _devForget(id);
    } catch (e) {
      dlog('history: a contact not forgotten (${e.runtimeType})');
    }
  }
}

/// at every start: the copies still under way go on
void resumeHistoryCopies() {
  if (!_copiesHere) return;
  if (linkedRole) {
    startDeviceHistoryCopy();
    return;
  }
  unawaited(() async {
    try {
      final db = await live.open();
      // the copies over answer how they ended to a device away meanwhile
      await PhoneHistoryCopy.restAll(db, EngineHistoryDoor());
      for (final uid in await historyCopiesOwed(db)) {
        startPhoneHistoryCopy(uid);
      }
    } catch (e) {
      dlog('history: copies not resumed (${e.runtimeType})');
    }
  }());
}

/// a chat's name for the copy page, as this device shows it
Future<String> historyChatName(HistoryChatRef c) async {
  try {
    final db = await live.open();
    if (c.group) {
      final r = await db.query(
        'groups',
        columns: ['name'],
        where: 'group_id = ?',
        whereArgs: [c.id],
      );
      final n = r.isEmpty ? null : r.first['name'] as String?;
      if (n != null && n.trim().isNotEmpty) return n;
    } else {
      final r = await db.query(
        'contacts',
        columns: ['nickname'],
        where: 'halo_id = ?',
        whereArgs: [c.id],
      );
      final n = r.isEmpty ? null : r.first['nickname'] as String?;
      if (n != null && n.trim().isNotEmpty) return n;
    }
  } catch (_) {
    // the id stands in
  }
  return c.id.length > 12 ? c.id.substring(0, 12) : c.id;
}
