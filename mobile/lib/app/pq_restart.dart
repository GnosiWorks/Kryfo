// SPDX-License-Identifier: GPL-3.0-or-later
// the pq restart of held chats. a chat made
// before 0.6 runs on a classic session. once both phones say they take a
// restart (caps 'pq'), the one with the smaller identity key sends a KDB1
// of its phone inside that session; the other starts a pqxdh session on it
// in front of the held one and seals its next frame on it, the opener. the
// pair keeps its addresses. 15 days after each side's first message from
// the other on the new state, the classic states go from its record: every
// wrap sealed on them has left the relays by then. a 0.5.x phone never says
// 'pq', so nothing here ever reaches its chat

part of '../main.dart';

/// whether a restarted chat shows its line, on both phones (Q10)
const kPqRestartLine = true;

/// how long the classic states stay after the first message from the
/// other side opened on the pq state: a wrap's life on the relays (14 days
/// and up to one more) and a day, as kSessionKeyGrace
const kClassicDropAfter = Duration(days: 16);

/// a KDB1 written longer ago than this by their clock is not built on: its
/// one-time kyber is gone 16 days after it was made, and the opener built
/// on it needs the rest of that time to reach them
const kRestartFresh = Duration(days: 7);

/// how long the smaller side waits before it sends its KDB1 again while no
/// pq message of theirs has opened: 1, 2, 4 and 8 days, then every 14
Duration restartWait(int asks) => switch (asks) {
  <= 1 => const Duration(days: 1),
  2 => const Duration(days: 2),
  3 => const Duration(days: 4),
  4 => const Duration(days: 8),
  _ => const Duration(days: 14),
};

/// how often a running app goes over its held chats
const kPqUpkeep = Duration(hours: 1);

/// whether [a] is smaller than [b] as bytes: the side that starts
bool keyBefore(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return a.length < b.length;
}

/// a KDB1 of [s]'s phone (device 1, the bundle on its identity): its
/// session signed prekey and a one-time kyber prekey made for this restart
Future<Uint8List> phoneRestartBundle(SignalSession s, {int? now}) async {
  final ids = await s.sessionPreKeysForUse(now: now);
  final kyberId = await s.makeHealKyber(now: now);
  final spk = s.lib.preKeyPublic(
    kLsSigned,
    (await s.signedPreKeyStore.load(ids.signedId))!,
  );
  final kyber = s.lib.preKeyPublic(
    kLsKyber,
    (await s.kyberPreKeyStore.load(kyberId))!,
  );
  return Uint8List.fromList([
    ...ascii.encode('KDB1'),
    1,
    ...bundleBlock(registrationId: s.registrationId, spk: spk, kyber: kyber),
  ]);
}

/// the frame a KDB1 goes in: the empty envelope with 'rq'. the seal adds
/// the caps and the screenshot word, and fills it to 2767 bytes, the size
/// a pq opener and a long text have (pq_restart_size_test)
Future<String> pqRestartFrame(
  SenderInfo sender,
  Uint8List kdb1, {
  required int writtenAt,
}) async {
  final wrapped = await wrapMessage('', sender: sender, writtenAt: writtenAt);
  final j =
      jsonDecode(wrapped.substring(kEnvelopePrefix.length))
          as Map<String, dynamic>;
  j[kPqRestartWire] = base64Encode(kdb1);
  return '$kEnvelopePrefix${jsonEncode(j)}';
}

/// what a KDB1 from [peer] inside a held session is, when it arrives
enum PqRestartTake {
  /// a session started on it, its opener goes next
  started,

  /// not taken: from the larger key, too old, done already, no held
  /// classic chat, or not a phone's bundle on the held session's identity
  refused,
}

// the one upkeep pass, and when the last began
Future<void>? _pqPass;
var _pqPassAt = 0;

// the chats whose pq_at is written, so the open path asks no more
final Set<String> _pqNoted = {};

// one KDB1 at a time per chat
final Set<String> _pqAsking = {};

extension AppStatePqRestart on AppState {
  /// the upkeep once kPqUpkeep has passed since the last, from the
  /// outbox's tick and at start
  Future<void> pqUpkeepDue({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (_pqPass != null || (now - _pqPassAt).abs() < kPqUpkeep.inMilliseconds) {
      return Future.value();
    }
    return pqUpkeep(nowMs: nowMs);
  }

  /// every held chat of the everyday side looked at once: a KDB1 sent
  /// where this side starts and one is due, and the classic states dropped
  /// where their time is up. [only]: that chat alone (its caps just said
  /// 'pq'). one pass at a time
  Future<void> pqUpkeep({int? nowMs, String? only}) {
    if (only == null) {
      _pqPassAt = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    }
    return _pqPass ??=
        _pqRound(nowMs ?? DateTime.now().millisecondsSinceEpoch, only: only)
            .catchError((Object e) {
              dlog('pq restart: upkeep stopped (${e.runtimeType})');
            })
            .whenComplete(() => _pqPass = null);
  }

  Future<void> _pqRound(int now, {String? only}) async {
    if (sessionQuiet || everydayHeld || !signalSession.ready) return;
    final db = await live.open();
    if (only == null) await _pqDrops(db, now);
    // the open vault's chats too: their sessions are in the everyday store.
    // a shut vault's are never looked for, and wait for it to open
    final rows = [
      for (final d in [live, ?_openVault])
        ...await (await d.open()).query(
          'contacts',
          columns: ['halo_id', 'caps', 'back_paired'],
          where: only == null
              ? 'accepted = ? AND blocked = ? AND ident = ?'
              : 'accepted = ? AND blocked = ? AND ident = ? AND halo_id = ?',
          whereArgs: [1, 0, kMainIdent, ?only],
        ),
    ];
    final mine = signalSession.identity.public;
    for (final r in rows) {
      final id = r['halo_id'] as String;
      if (isDevId(id)) continue;
      try {
        final info = await signalSession.sessionInfo(id);
        final their = info?.remoteIdentity;
        if (info == null || their == null || info.current == null) continue;
        // a session a restore brought back waits for its heal, which
        // builds a pq one: no KDB1 for it
        if (await signalSession.sealsOnRestored(id)) continue;
        final key = _hexOf(their);
        final row = await _pqRow(db, id, key);
        // over already: _pqDrops lets its classic states go
        if (row?['pq_at'] != null) continue;
        final classic =
            info.version < 4 || info.archived.any((s) => s.version < 4);
        if (!classic) continue;
        if (!capsOfText(r['caps'] as String?).contains(kCapPqRestart)) {
          continue;
        }
        if ((r['back_paired'] as int? ?? 0) != 1) continue;
        // the smaller key starts; the other waits for its KDB1
        if (!keyBefore(mine, their)) continue;
        final asked = row?['asked_at'] as int?;
        final asks = row?['asks'] as int? ?? 0;
        if (asked != null &&
            now - asked < restartWait(asks).inMilliseconds &&
            now >= asked) {
          continue;
        }
        await _sendRestart(db, id, key, asks, now);
      } catch (e) {
        dlog('pq restart: a chat skipped (${e.runtimeType})');
      }
    }
  }

  // the row of [peer]'s chat while its session runs on [key]; one left by
  // an earlier key of theirs counts for nothing
  Future<Map<String, Object?>?> _pqRow(
    DatabaseExecutor db,
    String peer,
    String key,
  ) async {
    final r = await db.query(
      'pq_restarts',
      where: 'ident = ? AND peer = ?',
      whereArgs: [kMainIdent, peer],
      limit: 1,
    );
    if (r.isEmpty || r.first['key'] != key) return null;
    return r.first;
  }

  Future<void> _putPqRow(
    DatabaseExecutor db,
    String peer,
    String key,
    Map<String, Object?> put,
  ) async {
    final had = await db.query(
      'pq_restarts',
      columns: ['key'],
      where: 'ident = ? AND peer = ?',
      whereArgs: [kMainIdent, peer],
      limit: 1,
    );
    if (had.isEmpty || had.first['key'] != key) {
      await db.insert('pq_restarts', {
        'ident': kMainIdent,
        'peer': peer,
        'key': key,
        ...put,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    // the row is there and nothing changes: sqlite takes no empty update
    if (put.isEmpty) return;
    await db.update(
      'pq_restarts',
      put,
      where: 'ident = ? AND peer = ?',
      whereArgs: [kMainIdent, peer],
    );
  }

  // the KDB1 inside [peer]'s held session. the time goes on the row before
  // the try, so a send that fails waits like one that went
  Future<void> _sendRestart(
    DatabaseExecutor db,
    String peer,
    String key,
    int asks,
    int now,
  ) async {
    if (!_pqAsking.add(peer)) return;
    try {
      await _putPqRow(db, peer, key, {'asked_at': now, 'asks': asks});
      final kdb1 = await phoneRestartBundle(signalSession, now: now);
      final ok = await _sendOneEnvelope(
        peer,
        await pqRestartFrame(_mySender(), kdb1, writtenAt: now),
      );
      if (ok) {
        await _putPqRow(db, peer, key, {'asks': asks + 1});
        dlog('pq restart: the bundle went');
      } else {
        dlog('pq restart: the bundle did not go');
      }
    } finally {
      _pqAsking.remove(peer);
    }
  }

  /// the classic states of every chat over to pq for kClassicDropAfter
  /// go, by the restart rows themselves: a chat hidden since, shut vault or
  /// open, and the dev chat, whose session is its seat's, drop on time. a
  /// row whose session went goes too. nothing of the vault is read for it
  Future<void> _pqDrops(Database db, int now) async {
    final over = await db.query(
      'pq_restarts',
      columns: ['peer', 'key', 'pq_at', 'dropped_at'],
      where: 'ident = ?',
      whereArgs: [kMainIdent],
    );
    for (final r in over) {
      final peer = r['peer'] as String;
      try {
        final store = isDevId(peer)
            ? (await devLane.seat(peer))?.store
            : signalSession;
        if (store == null) continue;
        final their = (await store.sessionInfo(peer))?.remoteIdentity;
        // their session went, or runs on another key now: the row names
        // them for nothing
        if (their == null || _hexOf(their) != r['key']) {
          await db.delete(
            'pq_restarts',
            where: 'ident = ? AND peer = ?',
            whereArgs: [kMainIdent, peer],
          );
          continue;
        }
        if (r['pq_at'] == null ||
            r['dropped_at'] != null ||
            now - (r['pq_at'] as int) < kClassicDropAfter.inMilliseconds) {
          continue;
        }
        await _dropClassic(db, store, peer, now);
      } catch (e) {
        dlog('pq restart: a drop skipped (${e.runtimeType})');
      }
    }
  }

  /// a KDB1 from [peer] ('rq'), as the arrival path finds it on a frame
  /// that opened on their held session, filed [on] the everyday container
  /// or the open vault
  Future<PqRestartTake> takePqRestart(
    String peer,
    String bundleB64, {
    int? writtenAt,
    int? nowMs,
    HaloDb? on,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (sessionQuiet || isDevId(peer) || !signalSession.ready) {
      return PqRestartTake.refused;
    }
    final w = writtenAt;
    if (w == null ||
        now - w > kRestartFresh.inMilliseconds ||
        w - now > kCapsAheadMost.inMilliseconds) {
      dlog('pq restart: a bundle out of its time, dropped');
      return PqRestartTake.refused;
    }
    final db = await live.open();
    final c = await (await (on ?? live).open()).query(
      'contacts',
      columns: ['accepted', 'blocked', 'ident'],
      where: 'halo_id = ?',
      whereArgs: [peer],
      limit: 1,
    );
    if (c.isEmpty ||
        c.first['accepted'] != 1 ||
        c.first['blocked'] != 0 ||
        (c.first['ident'] as int? ?? kMainIdent) != kMainIdent) {
      return PqRestartTake.refused;
    }
    final info = await signalSession.sessionInfo(peer);
    final their = info?.remoteIdentity;
    if (info == null || their == null) return PqRestartTake.refused;
    // one side starts: theirs must be the smaller key
    if (!keyBefore(their, signalSession.identity.public)) {
      dlog('pq restart: a bundle from the larger key, dropped');
      return PqRestartTake.refused;
    }
    final key = _hexOf(their);
    final row = await _pqRow(db, peer, key);
    if (row?['pq_at'] != null) return PqRestartTake.refused;
    final classic = info.version < 4 || info.archived.any((s) => s.version < 4);
    if (!classic) return PqRestartTake.refused;
    final LsBlock block;
    try {
      block = signalSession.lib.parseDeviceBundle(
        base64Decode(bundleB64),
        their,
      );
    } catch (e) {
      dlog('pq restart: a bundle that does not read (${e.runtimeType})');
      return PqRestartTake.refused;
    }
    if (block.deviceId != 1 || block.key != null) {
      return PqRestartTake.refused;
    }
    final bool built;
    try {
      built = await signalSession.restartFrom(peer, block.bundle);
    } catch (e) {
      dlog('pq restart: no session from the bundle (${e.runtimeType})');
      return PqRestartTake.refused;
    }
    if (!built) return PqRestartTake.refused;
    await _putPqRow(db, peer, key, const {});
    // the opener goes at once, the empty envelope, so their answer comes
    // without waiting for anyone to write
    unawaited(_sendRestartOpener(peer));
    return PqRestartTake.started;
  }

  Future<void> _sendRestartOpener(String peer) async {
    try {
      await _sendOneEnvelope(peer, await wrapMessage('', sender: _mySender()));
    } catch (e) {
      dlog('pq restart: the opener did not go (${e.runtimeType})');
    }
  }

  /// a message from [peer] opened on the pq state of a record that still
  /// holds classic ones (SignalSession.onPqOver): their side of the
  /// restart is done, and the 16 days begin. noted once: for an accepted
  /// contact of the everyday side, someone the vault holds (as the router
  /// says, shut or open: their session is in the everyday store), or the
  /// dev chat on its seat's store
  Future<void> notePqOver(String peer, {int? nowMs}) async {
    if (_pqNoted.contains(peer) || sessionQuiet) return;
    try {
      final db = await live.open();
      SignalSession store = signalSession;
      if (isDevId(peer)) {
        final seat = await devLane.seat(peer);
        if (seat == null) return;
        store = seat.store;
      } else if (!_hiddenPeer(peer)) {
        final c = await db.query(
          'contacts',
          columns: ['ident'],
          where: 'halo_id = ? AND accepted = ?',
          whereArgs: [peer, 1],
          limit: 1,
        );
        if (c.isEmpty || (c.first['ident'] as int? ?? 0) != kMainIdent) {
          return;
        }
      }
      final their = (await store.sessionInfo(peer))?.remoteIdentity;
      if (their == null) return;
      final key = _hexOf(their);
      final row = await _pqRow(db, peer, key);
      if (row?['pq_at'] == null) {
        await _putPqRow(db, peer, key, {
          'pq_at': nowMs ?? DateTime.now().millisecondsSinceEpoch,
        });
        dlog('pq restart: their side is on pq');
        if (kPqRestartLine) {
          _bumpChatRev(peer);
          notifyListeners();
        }
      }
      _pqNoted.add(peer);
    } catch (e) {
      dlog('pq restart: not noted (${e.runtimeType})');
    }
  }

  // a 1:1 chat the vault holds, as the router says
  bool _hiddenPeer(String peer) {
    try {
      final to = _routeOf(peer, null);
      return to == RouteTo.vault || to == RouteTo.sealed;
    } catch (_) {
      return false;
    }
  }

  Future<void> _dropClassic(
    DatabaseExecutor db,
    SignalSession store,
    String peer,
    int now,
  ) async {
    final n = await store.dropClassic(peer);
    if (n == null) return;
    await db.update(
      'pq_restarts',
      {'dropped_at': now},
      where: 'ident = ? AND peer = ?',
      whereArgs: [kMainIdent, peer],
    );
    dlog('pq restart: $n classic states dropped');
  }

  /// when [peer]'s chat went over to post-quantum, for its line; null for
  /// none, or with the line off
  Future<int?> pqLineAt(String peer) async {
    if (!kPqRestartLine || sessionQuiet) return null;
    try {
      final db = await live.open();
      final r = await db.query(
        'pq_restarts',
        columns: ['pq_at'],
        where: 'ident = ? AND peer = ?',
        whereArgs: [kMainIdent, peer],
        limit: 1,
      );
      return r.isEmpty ? null : r.first['pq_at'] as int?;
    } catch (_) {
      return null;
    }
  }
}
