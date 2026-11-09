// SPDX-License-Identifier: GPL-3.0-or-later
// sending to every device: one copy per slot
// the engine's Fanout names, the phone's too, all filled to one size and
// handed out at once in the fanout's random order. a copy that cannot go
// now (no session, its device waits for an answer or a fresh bundle, the
// relay failed) waits in dev_out for its device alone. a contact's lists
// and my devices' bundles go out through dev_pushes: removals at once,
// additions spread over hours. nothing here runs with the switch off, and
// a send the phone alone takes goes on today's path untouched
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../device_sessions.dart';
import '../message_envelope.dart' show kEnvelopePrefix;
import '../signal_ffi/kryfo_signal.dart' show kLsPreKey;
import '../signal_session.dart' show WaitsForAnswer;
import '../typing.dart' show kCapDevices;
import '../wire_pad.dart' show kSealSizes;
import 'device_receive.dart' show staleList;
import 'device_state.dart';
import 'own_device_store.dart' show ownPhoneFresh;
import 'own_sync.dart' show kOwnFrameMost, ownChatName, ownHash;

/// how long a copy waits for its device before it is let go
const kDeviceCopyKept = Duration(days: 7);

/// how long a state op waits for an own device that never answers: a
/// removal ends them with the device, this is the most until then. a chat's
/// end ('gone', 'ungroup') waits until the device answers or is removed
const kOwnOpKept = Duration(days: 30);

/// how long the last word to a device just removed is handed to the relay
/// before it is let go: the relays keep a wrap about this long
const kFarewellKept = Duration(days: 14);

/// when a last word the relay took goes again, by its age, at most: a
/// relay that drops it or a device that missed it gets it from a later
/// copy, and one that already took it cannot open the same bytes twice.
/// each wait is drawn from its second half
Duration farewellAgainAfter(Duration age) {
  if (age < const Duration(minutes: 10)) return const Duration(minutes: 2);
  if (age < const Duration(hours: 1)) return const Duration(minutes: 15);
  if (age < const Duration(days: 1)) return const Duration(hours: 4);
  return const Duration(days: 1);
}

/// a frame sealed now for one device, with where it goes: a removal's last
/// word and a linked device's own, whose session goes right after
typedef DevLast = ({String arg, String wire, bool opener});

/// the most contacts one pass of a spread push reaches
const kPushPerPass = 8;

/// the gap between two passes of a spread push, at least and at most
const kPushGapLeast = Duration(minutes: 20);
const kPushGapMost = Duration(minutes: 70);

/// a list not answered after it went goes again this long after; a
/// removal again after as long as it has waited so far, at most
/// [kRemovePushGapMost], until their phone says it holds it
const kPushAgain = Duration(days: 1);
const kRemovePushGapMost = Duration(days: 14);

/// a removal no phone answered is let go this long after it was due
const kRemovePushKept = Duration(days: 60);

/// a removal from my list owed to the hidden chats' contacts, kept on the
/// everyday side with no names (my identity, the version, when) in the
/// same write as the everyday pushes, for [kRemovePushKept] whatever the
/// vault does. the vault's next open queues it as its own pushes, kept
/// there until each phone says it holds the list, and marks it queued in
/// the vault alone. while the vault is shut it goes to each hidden
/// contact's phone at every start and pump until it went, for
/// [kRemovePushGapMost] (devices_vault_app.dart)
const kHiddenRemovalMeta = 'hidden_removal_owed:';

/// a [kHiddenRemovalMeta] value: the version and when it was owed. it goes
/// by age alone ([kRemovePushKept]), the same with a vault or without, so
/// the everyday side never shows that a vault opened
({int version, int at})? hiddenRemovalOf(String? v) {
  final p = (v ?? '').split(':');
  final version = int.tryParse(p.first);
  if (version == null) return null;
  return (version: version, at: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

/// how often a contact's phone is asked for a fresh bundle of one device
const kAskEvery = Duration(days: 1);

/// how many lists a device of mine may have sent again with fresh bundles
/// in a day, over every contact ('dp'): each one spends a pool bundle
const kPushAgainMost = 20;

/// a pair's starter and its answer wait this long at least and at most
const kStartWaitLeast = Duration(seconds: 2);
const kStartWaitMost = Duration(seconds: 30);

// a copy that failed at the relay goes again after these, then every last
const _again = [
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
  Duration(hours: 1),
  Duration(hours: 6),
];

// a copy handed off with no receipt yet goes again after these, then not
const _unheard = [Duration(hours: 6), Duration(days: 1), Duration(days: 3)];

/// the relay calls a device copy takes. [arg] names the device pair as the
/// engine does: "x/their/my.seed"
abstract class DeviceWire {
  /// a copy on the seeded pair
  Future<String> send(int ident, String arg, String cipher);

  /// the pair's first opener, to the receiver's opener address
  Future<String> sendOpener(int ident, String arg, String cipher);
}

/// my side of a send: the identity, its key, and this device's id on it
/// (1 on the phone)
typedef DevMe = ({int ident, Uint8List identity, int device});

/// a contact as a send knows them: the chat's address, their identity key
/// (hex, as the engine takes it), whether their phone showed [kCapDevices]
/// and whether the phone's session is a held classic one
typedef DevContact = ({
  String peer,
  String identity,
  bool devices,
  bool phoneClassic,
});

/// the phone's own copy on the phone: [measure] says the seal size the
/// frame takes on its session now (SignalSession.sealSize), [seal] seals
/// it filled to a burst's size (SignalSession.encryptTo with size)
typedef DevPhone = ({
  Future<int?> Function(String frame) measure,
  Future<String> Function(String frame, int size) seal,
});

/// one slot of a fanout, as the engine names it
typedef DevSlot = ({
  String identity,
  int device,
  String key,
  int reg,
  bool own,
  bool rebuild,
});

/// what a burst did: the phone's cipher for the caller to send (null when
/// it had no copy), the size every copy took, the copies owed to devices
typedef DevBurst = ({String? phone, int size, int copies});

class DeviceSend {
  DeviceSend({
    required this.state,
    required this.db,
    required this.sessions,
    required this.wire,
    this.listen,
    Future<Database> Function()? mine,
    this.noOwn = false,
    this.hiddenRemovals = false,
    this.changed,
    this.door,
    int Function()? clock,
    Random? random,
    Duration Function()? jitter,
  }) : mine = mine ?? db,
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
       _rand = random ?? Random.secure(),
       _jitter = jitter;

  final DeviceState state;

  /// the everyday container: the dev tables, the contacts and the pairs
  final Future<Database> Function() db;

  /// the device sessions of my identity [ident]
  final Future<DeviceSessions> Function(int ident) sessions;
  final DeviceWire wire;

  /// where my own state is (my identities, my list, the pool, my asks):
  /// the everyday container, also when [db] is the open vault
  final Future<Database> Function() mine;

  /// the open vault's: a hidden chat's copies go to the contact's
  /// devices and never to mine
  final bool noOwn;

  /// the everyday side's: a removal is kept owed to the hidden chats too
  /// ([kHiddenRemovalMeta])
  final bool hiddenRemovals;

  /// told every change of my lists once its pushes are queued here: the
  /// hidden chats' contacts are not this side's
  final void Function(
    List<({int ident, int version, List<int> added, bool removed})> changes,
  )?
  changed;

  /// the one door (app/door.dart) for a frame to a contact's device, as
  /// signalSeal takes the phone's: the frame filled for the identity they
  /// know, and one naming another identity of mine throws, so that copy
  /// goes nowhere. my own devices' frames are mine
  final Future<String> Function(String peer, String frame)? door;

  /// listens on a device pair, [arg] as the engine names it
  /// ("x/their/my.seed"): a pair given a seed here is heard on from then on
  final void Function(int ident, String arg)? listen;
  final int Function() _clock;
  final Random _rand;
  final Duration Function()? _jitter;

  /// how long a pair's starter or its answer waits before it goes, so it
  /// does not leave in step with what it answers: [kStartWaitLeast] to
  /// [kStartWaitMost]
  Duration startWait() {
    final j = _jitter;
    if (j != null) return j();
    final least = kStartWaitLeast.inMilliseconds;
    return Duration(
      milliseconds:
          least + _rand.nextInt(kStartWaitMost.inMilliseconds - least + 1),
    );
  }

  // [run] after [wait]; the row's next_at says the same, so a pump after a
  // restart takes it if the timer is lost
  void _later(Duration wait, Future<void> Function() run) {
    if (wait <= Duration.zero) {
      unawaited(run().catchError((Object _) {}));
      return;
    }
    Timer(wait, () => unawaited(run().catchError((Object _) {})));
  }

  // when each (ident, contact, device) was last asked for a fresh bundle
  final _asked = <String, int>{};
  // contacts ("ident/identity") whose list push a device of mine asked
  // for now: on the next pump, ahead of the spread
  final _urgent = <String>{};
  // uids a receipt came for, so the second device's is dropped
  final _receipts = <String>{};
  // one pump at a time, one hand-off of a copy at a time
  Future<void>? _pumping;
  final _inflight = <String>{};

  // ---- the burst ----

  /// every copy of [frame] from my identity to [c]: null when the phone
  /// alone takes it (a contact without [kCapDevices] and no device of mine,
  /// or one the engine does not know), and the caller seals and sends it as
  /// today. else the phone's copy is sealed by [phone] filled to the burst's
  /// size and handed back, and every other copy is sealed to that size, kept
  /// in dev_out and handed to the relay at once. [frameFor] may change a
  /// slot's frame (a list push's bundles) or leave a slot out (null);
  /// [force] makes a burst of the phone alone too
  Future<DevBurst?> burst(
    DevMe me,
    DevContact c,
    String frame, {
    DevPhone? phone,
    String? Function(DevSlot slot, String frame)? frameFor,
    bool force = false,
    // false: no own copy in this burst (a chat with screenshots blocked;
    // a group's goes once after its members', OwnSync.copy)
    bool ownCopy = true,
    // a linked device's send: nothing is kept unless a device of theirs
    // holds a session with this one now, so a copy that would only wait
    // is never counted as gone
    bool mustReach = false,
  }) async {
    if (!linkedDevicesOn || !frame.startsWith(kEnvelopePrefix)) return null;
    final body = _bodyOf(frame);
    if (body == null) return null;
    final d = await db();
    final now = _clock();
    final List<DevSlot> slots;
    try {
      slots = _slots(
        await state.call(d, 'fanout', {
          'ident': me.ident,
          'contact': c.identity,
          'devices': c.devices,
          'phone_classic': c.phoneClassic,
          'now': now,
          if (noOwn) 'no_own': true,
        }),
      );
    } on DevRefused catch (e) {
      // a contact the engine does not hold yet: the phone alone, as today
      if (e.why == 'unknown') return null;
      rethrow;
    }
    bool isPhone(DevSlot s) => !s.own && s.device == 1 && me.device == 1;
    if (!force && slots.every(isPhone)) return null;
    // a linked device that has not heard its phone lately copies to the
    // phone alone: my list may have moved without it
    final peersFresh = me.device == 1 || await ownPhoneFresh(await mine(), now);
    // a list a restore left: their phone alone until it is sent again
    final stale = await staleList(d, me.ident, c.identity);
    final uid = _uidOf(body, frame);
    // an own copy is answered by its own uid (OwnSync.take)
    final ownUid = 'oc:${ownHash(frame)}';
    String uidOf(DevSlot s) => s.own ? ownUid : uid;
    final receipt = body['u'] is String;
    final ds = await sessions(me.ident);

    // each slot's frame, and the ones that wait for a bundle
    final ready = <(DevSlot, DeviceCopy)>[];
    final waiting = <(DevSlot, String)>[];
    final ask = <int>[];
    String? phoneFrame;
    for (final s in slots) {
      if (noOwn && s.own) continue;
      if (s.own && s.device != 1 && !peersFresh) continue;
      if (!s.own && s.device != 1 && stale) continue;
      if (isPhone(s)) {
        phoneFrame = frameFor == null ? frame : frameFor(s, frame);
        continue;
      }
      var f = s.own
          ? (ownCopy ? ownCopyOf(me.ident, c.peer, frame) : null)
          : frame;
      if (f != null && frameFor != null) f = frameFor(s, f);
      if (f == null) continue;
      final addr = s.own ? kOwnDevices : c.peer;
      // a slot that fails here (a session held on another key, a row that
      // does not read, a frame the door refuses) misses this message; the
      // phone and the others go
      try {
        final dr = door;
        if (!s.own && dr != null) f = await dr(c.peer, f);
        if (await _owed(d, uidOf(s), me.ident, s)) continue;
        final pin = _bytes(s.key);
        final has = await ds.has(addr, s.device);
        final answered = has && await ds.answered(addr, s.device, pin);
        // the pair's seed rides on every copy until the device answers
        if (!answered) f = _withSeed(f, await _seed(d, me, s));
        // a pair built again before its device ever answered: the new
        // opener goes to the opener address again, the first may never
        // have been read
        if (s.rebuild && !answered) await _openAfresh(d, me, s);
        if (!has || s.rebuild) {
          if (!s.own && _askDue(me.ident, c.identity, s.device, now)) {
            ask.add(s.device);
          }
          waiting.add((s, f));
          continue;
        }
        ready.add((s, (peer: addr, device: s.device, pin: pin, plain: f)));
      } on Object {
        continue;
      }
    }
    if (phoneFrame != null && ask.isNotEmpty) {
      phoneFrame = _withAsk(phoneFrame, ask);
    }
    if (mustReach && !ready.any((r) => !r.$1.own)) {
      return (phone: null, size: 0, copies: 0);
    }

    // one size for the burst: the largest copy, the phone's measured too
    final copies = [for (final r in ready) r.$2];
    var size = await ds.burstSize(copies);
    final p = phone;
    if (phoneFrame != null && p != null) {
      size = max(size, await p.measure(phoneFrame) ?? 0);
    }
    // the phone's copy first: when it throws, no device copy is made
    String? phoneCipher;
    if (phoneFrame != null && p != null) {
      phoneCipher = await p.seal(phoneFrame, size);
    }
    final sealed = copies.isEmpty
        ? const <DeviceSealed>[]
        : await ds.sealAll(copies, size: size);

    // every copy owed written before any goes
    final rows = <Map<String, Object?>>[];
    Map<String, Object?> row(DevSlot s, String addr) => {
      'uid': uidOf(s),
      'ident': me.ident,
      'peer': s.identity,
      'device': s.device,
      'at': now,
      'own': s.own ? 1 : 0,
      'addr': addr,
      'pin': s.key,
      'reg': s.reg,
      'size': size,
      // my own devices answer every own copy (OwnSync.take)
      'receipt': (receipt && !s.own) || s.own ? 1 : 0,
      // the hand-off below runs first; the pump takes it after a failure
      'next_at': now + _again.first.inMilliseconds,
    };
    for (var i = 0; i < ready.length; i++) {
      final (s, copy) = ready[i];
      final w = sealed[i].wire;
      // an opener too big for the burst: a small starter goes on the pair
      // alone, so the device answers and the copy goes as a plain message
      if (sealed[i].error is WaitsForAnswer) {
        final st = await _starter(d, ds, me, s, copy, now);
        if (st != null) rows.add(st);
      }
      rows.add({
        ...row(s, copy.peer),
        if (w != null) ...{
          'wire': w,
          'state': 'go',
        } else ...{
          // its device answers first, or the session comes again
          'plain': copy.plain,
          'state': 'wait',
        },
      });
    }
    for (final (s, f) in waiting) {
      rows.add({
        ...row(s, s.own ? kOwnDevices : c.peer),
        'plain': f,
        'state': 'wait',
        // waits for a bundle: sessionCame makes it due
        'next_at': 0,
      });
    }
    await d.transaction((t) async {
      for (final r in rows) {
        await t.insert(
          'dev_out',
          r,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    for (final r in rows) {
      if (r['state'] == 'go') unawaited(_go(d, r));
    }
    return (phone: phoneCipher, size: size, copies: rows.length);
  }

  /// whether a device of [c]'s holds a session with this one now: what a
  /// burst with mustReach counts as reached. a peek: no silent device's
  /// probe is spent by asking
  Future<bool> reaches(DevMe me, DevContact c) async {
    if (!linkedDevicesOn) return false;
    final d = await db();
    final List<DevSlot> slots;
    try {
      slots = _slots(
        await state.call(d, 'fanout', {
          'ident': me.ident,
          'contact': c.identity,
          'devices': c.devices,
          'phone_classic': c.phoneClassic,
          'now': _clock(),
          'no_own': true,
          'peek': true,
        }),
      );
    } on DevRefused {
      return false;
    }
    final ds = await sessions(me.ident);
    for (final s in slots) {
      if (s.own || s.rebuild) continue;
      if (s.device == 1 && me.device == 1) continue;
      try {
        if (await ds.has(c.peer, s.device)) return true;
      } on Object {
        continue;
      }
    }
    return false;
  }

  List<DevSlot> _slots(Map<String, dynamic> j) => [
    for (final s in (j['slots'] as List? ?? const []))
      (
        identity: (s as Map)['identity'] as String,
        device: s['device'] as int,
        key: s['key'] as String,
        reg: (s['reg'] as num?)?.toInt() ?? 0,
        own: s['own'] == true,
        rebuild: s['rebuild'] == true,
      ),
  ];

  // a copy of this frame to the slot owed already: a send of the same uid
  // again (a retry of the phone's copy) does not make a second one
  Future<bool> _owed(
    DatabaseExecutor d,
    String uid,
    int ident,
    DevSlot s,
  ) async => (await d.query(
    'dev_out',
    columns: ['uid'],
    where: 'uid = ? AND ident = ? AND peer = ? AND device = ?',
    whereArgs: [uid, ident, s.identity, s.device],
    limit: 1,
  )).isNotEmpty;

  bool _askDue(int ident, String identity, int device, int now) {
    final k = '$ident/$identity/$device';
    final at = _asked[k];
    if (at != null && now - at < kAskEvery.inMilliseconds && now >= at) {
      return false;
    }
    _asked[k] = now;
    return true;
  }

  // the starter of a device pair whose first copy waits for its answer:
  // the empty envelope with the pair's seed, an opener at the second size.
  // one owed per pair at a time
  Future<Map<String, Object?>?> _starter(
    Database d,
    DeviceSessions ds,
    DevMe me,
    DevSlot s,
    DeviceCopy copy,
    int now,
  ) async {
    final uid = 's:${s.identity.substring(2, 18)}/${s.device}';
    if (await _owed(d, uid, me.ident, s)) return null;
    final String w;
    try {
      w = await ds.seal(
        copy.peer,
        s.device,
        _withSeed('$kEnvelopePrefix{}', await _seed(d, me, s)),
        copy.pin,
        size: kSealSizes[1],
      );
    } on Object {
      return null;
    }
    return {
      'uid': uid,
      'ident': me.ident,
      'peer': s.identity,
      'device': s.device,
      'at': now,
      'own': s.own ? 1 : 0,
      'addr': copy.peer,
      'pin': s.key,
      'reg': s.reg,
      'size': kSealSizes[1],
      'receipt': 0,
      'wire': w,
      'state': 'go',
      'next_at': now + _again.first.inMilliseconds,
    };
  }

  // ---- seeds and openers ----

  static const _pairWhere =
      'ident = ? AND peer = ? AND their_device = ? AND my_device = ?';

  // the device pair's seed, made and kept with the first copy to it, for
  // the device key the slot names: a new key under the id is another pair,
  // and never gets the seed the old device knows
  Future<Uint8List> _seed(Database d, DevMe me, DevSlot s) async {
    final at = [me.ident, s.identity, s.device, me.device];
    final rec = await d.query(
      'dev_openers',
      columns: ['key'],
      where: _pairWhere,
      whereArgs: at,
      limit: 1,
    );
    final r = await d.query(
      'pairs',
      columns: ['seed'],
      where: _pairWhere,
      whereArgs: at,
      limit: 1,
    );
    final held = r.isEmpty ? null : r.first['seed'];
    final mine = rec.isEmpty || rec.first['key'] == s.key;
    if (held is List<int> && held.length == 32 && mine) {
      // a seed taken from the device's own opener has no record yet
      if (rec.isEmpty) await _record(d, at, s.key);
      return Uint8List.fromList(held);
    }
    final seed = Uint8List.fromList([
      for (var i = 0; i < 32; i++) _rand.nextInt(256),
    ]);
    await d.transaction((t) async {
      // the old key's seed and opener mark go
      await t.delete('pairs', where: _pairWhere, whereArgs: at);
      await t.delete('dev_openers', where: _pairWhere, whereArgs: at);
      await t.insert('pairs', {
        'ident': me.ident,
        'peer': s.identity,
        'their_device': s.device,
        'my_device': me.device,
        'conv': 4,
        'seed': seed,
      });
      await _record(t, at, s.key);
    });
    // its answers come on the seeded pair
    listen?.call(
      me.ident,
      '${s.identity.substring(2)}/${s.device}/${me.device}.${devHex(seed)}',
    );
    return seed;
  }

  Future<void> _record(DatabaseExecutor d, List<Object?> at, String key) =>
      d.insert('dev_openers', {
        'ident': at[0],
        'peer': at[1],
        'their_device': at[2],
        'my_device': at[3],
        'key': key,
        'at': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

  // the pair's next opener goes to its opener address again
  Future<void> _openAfresh(Database d, DevMe me, DevSlot s) => d.update(
    'dev_openers',
    {'at': 0},
    where: '$_pairWhere AND key = ?',
    whereArgs: [me.ident, s.identity, s.device, me.device, s.key],
  );

  String _arg(Map<String, Object?> r, int myDevice, Uint8List seed) {
    final identity = r['peer'] as String;
    return '${identity.substring(2)}/${r['device']}/$myDevice.${devHex(seed)}';
  }

  // ---- handing off ----

  Future<void> _go(Database d, Map<String, Object?> r) async {
    final k = _keyArgs(r).join('/');
    if (!_inflight.add(k)) return;
    try {
      await _goOnce(d, r);
    } finally {
      _inflight.remove(k);
    }
  }

  Future<void> _goOnce(Database d, Map<String, Object?> r) async {
    final ident = r['ident'] as int;
    final device = r['device'] as int;
    final identity = r['peer'] as String;
    final myDevice = await _myDevice(d, ident);
    final seeds = await d.query(
      'pairs',
      columns: ['seed'],
      where: _pairWhere,
      whereArgs: [ident, identity, device, myDevice],
      limit: 1,
    );
    final seed = seeds.isEmpty ? null : seeds.first['seed'];
    if (seed is! List<int> || seed.length != 32) return;
    final arg = _arg(r, myDevice, Uint8List.fromList(seed));
    final w = r['wire'] as String;
    // the first copy on a pair goes to its opener address, and so does
    // every send of that copy again; the rest go on the seeded pair
    final at = [ident, identity, device, myDevice];
    final rec = await d.query(
      'dev_openers',
      columns: ['key', 'at'],
      where: _pairWhere,
      whereArgs: at,
      limit: 1,
    );
    // a copy sealed for a key the pair no longer runs on is owed to no one
    if (rec.isNotEmpty && rec.first['key'] != r['pin']) {
      await d.delete('dev_out', where: _slotWhere, whereArgs: _keyArgs(r));
      return;
    }
    var opener = r['opener'] == 1;
    if (!opener &&
        base64Decode(w)[0] == kLsPreKey &&
        (rec.isEmpty || rec.first['at'] == 0)) {
      opener = true;
      await d.transaction((t) async {
        await _record(t, at, r['pin'] as String);
        await t.update(
          'dev_openers',
          {'at': _clock()},
          where: _pairWhere,
          whereArgs: at,
        );
        await t.update(
          'dev_out',
          {'opener': 1},
          where: _slotWhere,
          whereArgs: _keyArgs(r),
        );
      });
    }
    String res;
    try {
      res = opener
          ? await wire.sendOpener(ident, arg, w)
          : await wire.send(ident, arg, w);
    } catch (e) {
      res = 'error: ${e.runtimeType}';
    }
    final now = _clock();
    final tries = (r['tries'] as int? ?? 0);
    if (res != 'ok') {
      final gap = _again[min(tries, _again.length - 1)];
      await d.update(
        'dev_out',
        {
          'state': 'go',
          'tries': tries + 1,
          'next_at': now + gap.inMilliseconds,
        },
        where: _slotWhere,
        whereArgs: _keyArgs(r),
      );
      return;
    }
    // a device that never answered on this session counts from the hand
    // off, not from the seal
    final addr = r['addr'] as String;
    try {
      final ds = await sessions(ident);
      if (!await ds.answered(addr, device, _bytes(r['pin'] as String))) {
        await state.call(d, 'quiet', {
          'op': 'sent',
          'identity': identity,
          'device': device,
          'key': r['pin'],
          'now': now,
        });
      }
    } on Object {
      // the copy went: what quiet keeps is only a count
    }
    if (r['receipt'] != 1) {
      await d.delete('dev_out', where: _slotWhere, whereArgs: _keyArgs(r));
      return;
    }
    final sent = (r['sent_at'] as int? ?? 0);
    final round = sent == 0 ? 0 : (r['tries'] as int? ?? 0);
    await d.update(
      'dev_out',
      {
        'state': 'sent',
        'sent_at': sent == 0 ? now : sent,
        'tries': sent == 0 ? 0 : round,
        'next_at': round < _unheard.length
            ? now + _unheard[round].inMilliseconds
            : _keptOwn(r)
            ? now + _unheard.last.inMilliseconds
            : 0,
      },
      where: _slotWhere,
      whereArgs: _keyArgs(r),
    );
  }

  // a state op to my own device goes again until its receipt, and so does
  // anything kept for good (my list after a removal)
  static bool _keptOwn(Map<String, Object?> r) =>
      r['own'] == 1 &&
      ((r['uid'] as String? ?? '').startsWith('os:') || r['keep'] == 1);

  static const _slotWhere = 'uid = ? AND ident = ? AND peer = ? AND device = ?';
  List<Object?> _keyArgs(Map<String, Object?> r) => [
    r['uid'],
    r['ident'],
    r['peer'],
    r['device'],
  ];

  Future<int> _myDevice(DatabaseExecutor _, int ident) async {
    final r = await (await mine()).query(
      'identities',
      columns: ['dev_id'],
      where: 'id = ?',
      whereArgs: [ident],
      limit: 1,
    );
    return r.isEmpty ? 1 : (r.first['dev_id'] as int? ?? 1);
  }

  // ---- the pump ----

  /// every copy owed that is due: one waiting for a session seals now if
  /// it can, one the relay failed goes again, one with no receipt goes
  /// again a few times; past [kDeviceCopyKept] it goes. then the pushes
  /// due. one pump at a time
  Future<void> pump() {
    if (!linkedDevicesOn) return Future.value();
    final run = _pumping;
    if (run != null) return run;
    final next = _pump().whenComplete(() => _pumping = null);
    _pumping = next;
    return next;
  }

  Future<void> _pump() async {
    final d = await db();
    final now = _clock();
    // a state op to my own device is kept until it answers: a hide that
    // never reached a laptop would leave the chat there. one that never
    // answers for [kOwnOpKept] is let go, but for a chat's end: that one
    // stays until the device answers or is removed, so a laptop that is
    // used and never online with the phone still loses the hidden chat.
    // my list after a removal is kept the same way (keep)
    await d.delete(
      'dev_out',
      where:
          "(at < ? AND keep = 0 AND NOT (own = 1 AND uid LIKE 'os:%')) OR "
          "(own = 1 AND uid LIKE 'os:%' AND at < ? AND keep = 0)",
      whereArgs: [
        now - kDeviceCopyKept.inMilliseconds,
        now - kOwnOpKept.inMilliseconds,
      ],
    );
    if (!noOwn) await _farewells(now);
    final due = await d.query(
      'dev_out',
      where: 'next_at > 0 AND next_at <= ?',
      whereArgs: [now],
      orderBy: 'at',
    );
    for (final r in due) {
      switch (r['state']) {
        case 'wait':
          await _sealWaiting(d, r);
        case 'go':
          await _go(d, r);
        case 'sent':
          // no receipt yet: the same wire again, on the pair as it is now
          await _go(d, {...r, 'tries': (r['tries'] as int? ?? 0) + 1});
      }
    }
  }

  // [plain] with its 'as' set to the pair's seed held now, when it has one
  Future<String> _seedNow(
    Database d,
    Map<String, Object?> r,
    String plain,
  ) async {
    final b = _bodyOf(plain);
    if (b == null || b['as'] is! String) return plain;
    final ident = r['ident'] as int;
    final seeds = await d.query(
      'pairs',
      columns: ['seed'],
      where: _pairWhere,
      whereArgs: [ident, r['peer'], r['device'], await _myDevice(d, ident)],
      limit: 1,
    );
    final seed = seeds.isEmpty ? null : seeds.first['seed'];
    if (seed is! List<int> || seed.length != 32) return plain;
    final hex = devHex(seed);
    if (b['as'] == hex) return plain;
    return _with(plain, (j) => j['as'] = hex);
  }

  Future<void> _sealWaiting(Database d, Map<String, Object?> r) async {
    final ident = r['ident'] as int;
    final addr = r['addr'] as String;
    final device = r['device'] as int;
    final plain = r['plain'] as String?;
    final ds = await sessions(ident);
    final now = _clock();
    Future<void> later() => d.update(
      'dev_out',
      {'next_at': now + _again[min(2, _again.length - 1)].inMilliseconds},
      where: _slotWhere,
      whereArgs: _keyArgs(r),
    );
    if (plain == null || !await ds.has(addr, device)) {
      // waits for its bundle: the session's build pumps it
      await d.update(
        'dev_out',
        {'next_at': 0},
        where: _slotWhere,
        whereArgs: _keyArgs(r),
      );
      return;
    }
    // the pair's seed as it is now: one taken from their opener since the
    // copy was made takes the place of the one it was made with
    final framed = await _seedNow(d, r, plain);
    final String w;
    try {
      w = await ds.seal(
        addr,
        device,
        framed,
        _bytes(r['pin'] as String),
        size: r['size'] as int? ?? 0,
      );
    } on WaitsForAnswer {
      // a first copy too big for an opener at its size: the pair's starter
      // goes alone, so the device answers and the copy goes after it
      final myDevice = await _myDevice(d, ident);
      final st = await _starter(
        d,
        ds,
        (ident: ident, identity: Uint8List(0), device: myDevice),
        (
          identity: r['peer'] as String,
          device: device,
          key: r['pin'] as String,
          reg: r['reg'] as int? ?? 0,
          own: r['own'] == 1,
          rebuild: false,
        ),
        (
          peer: addr,
          device: device,
          pin: _bytes(r['pin'] as String),
          plain: plain,
        ),
        now,
      );
      if (st != null) {
        await d.insert(
          'dev_out',
          st,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await _go(d, st);
      }
      return later();
    } on Object {
      return later();
    }
    final next = {...r, 'wire': w, 'plain': null, 'state': 'go'};
    await d.update(
      'dev_out',
      {'wire': w, 'plain': null, 'state': 'go', 'next_at': now},
      where: _slotWhere,
      whereArgs: _keyArgs(r),
    );
    await _go(d, next);
  }

  /// a session with [identity]'s [device] came (built from a bundle): the
  /// copies that waited for it are due now
  Future<void> sessionCame(int ident, String identity, int device) async {
    final d = await db();
    await d.update(
      'dev_out',
      {'next_at': _clock()},
      where: "ident = ? AND peer = ? AND device = ? AND state = 'wait'",
      whereArgs: [ident, identity, device],
    );
  }

  /// a session with [identity]'s [device] ([key], [reg]) at [addr], built
  /// here from a bundle their phone pushed: when nothing of mine waits for
  /// it and the device never answered, the pair's starter goes at once, so
  /// the new device can write to me before I write to it
  Future<void> start(
    DevMe me,
    String identity,
    int device,
    String addr,
    String key,
    int reg,
  ) async {
    if (!linkedDevicesOn) return;
    if (device == 1 && me.device == 1) return;
    if (await waitsFor(me.ident, identity, device)) return;
    final d = await db();
    final ds = await sessions(me.ident);
    final pin = _bytes(key);
    if (!await ds.has(addr, device) || await ds.answered(addr, device, pin)) {
      return;
    }
    final st = await _starter(
      d,
      ds,
      me,
      (
        identity: identity,
        device: device,
        key: key,
        reg: reg,
        own: addr == kOwnDevices,
        rebuild: false,
      ),
      (peer: addr, device: device, pin: pin, plain: ''),
      _clock(),
    );
    if (st == null) return;
    final wait = startWait();
    final row = {...st, 'next_at': _clock() + wait.inMilliseconds};
    await d.insert('dev_out', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    _later(wait, () => _go(d, row));
  }

  /// whether a copy to [identity]'s [device] waits for its session: a
  /// bundle that comes now answers an ask (a Rebuild's), not a push
  Future<bool> waitsFor(int ident, String identity, int device) async =>
      (await (await db()).query(
        'dev_out',
        columns: ['uid'],
        where: "ident = ? AND peer = ? AND device = ? AND state = 'wait'",
        whereArgs: [ident, identity, device],
        limit: 1,
      )).isNotEmpty;

  /// [frame] to [identity]'s [device] alone, on its device session: an
  /// answer (a receipt, a bundle, a held list) on the pair a frame came on.
  /// it waits in dev_out for the pump as any copy that waits does
  Future<void> toOne({
    required int ident,
    required String identity,
    required int device,
    required String addr,
    required String pin,
    required int reg,
    required String frame,
    bool own = false,
    // kept and sent again until that device's receipt (an own frame)
    bool receipt = false,
    // and never let go for its age: a chat's end, until the device answers
    // or is removed
    bool keep = false,
    // how long it waits before it goes (a pair's answer, startWait)
    Duration after = Duration.zero,
  }) async {
    final body = _bodyOf(frame);
    if (body == null) return;
    // a contact's device: through the door first, nothing kept when refused
    final dr = door;
    if (!own && dr != null) frame = await dr(addr, frame);
    final now = _clock();
    await (await db()).insert('dev_out', {
      'uid': _uidOf(body, frame),
      'ident': ident,
      'peer': identity,
      'device': device,
      'at': now,
      'own': own ? 1 : 0,
      'keep': keep ? 1 : 0,
      'addr': addr,
      'pin': pin,
      'reg': reg,
      'receipt': receipt ? 1 : 0,
      'plain': frame,
      'state': 'wait',
      'next_at': now + after.inMilliseconds,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    _later(after, pump);
  }

  // ---- last words ----

  /// [frame] sealed now on [device]'s session ([addr] its address, [pin]
  /// its key), with the arg and whether it goes to the opener address:
  /// kept nowhere, for a session that goes right after. null when there is
  /// no session or it cannot seal
  Future<DevLast?> sealLast({
    required DevMe me,
    required String identity,
    required int device,
    required String addr,
    required String pin,
    required int reg,
    required String frame,
  }) async {
    final d = await db();
    final ds = await sessions(me.ident);
    final key = _bytes(pin);
    if (!await ds.has(addr, device)) return null;
    final slot = (
      identity: identity,
      device: device,
      key: pin,
      reg: reg,
      own: addr == kOwnDevices,
      rebuild: false,
    );
    try {
      final seed = await _seed(d, me, slot);
      final answered = await ds.answered(addr, device, key);
      final w = await ds.seal(
        addr,
        device,
        answered ? frame : _withSeed(frame, seed),
        key,
        size: answered ? null : kSealSizes[1],
      );
      final at = [me.ident, identity, device, me.device];
      final rec = await d.query(
        'dev_openers',
        columns: ['at'],
        where: _pairWhere,
        whereArgs: at,
        limit: 1,
      );
      final opener =
          base64Decode(w)[0] == kLsPreKey &&
          (rec.isEmpty || rec.first['at'] == 0);
      return (
        arg: '${identity.substring(2)}/$device/${me.device}.${devHex(seed)}',
        wire: w,
        opener: opener,
      );
    } on Object {
      return null;
    }
  }

  /// [last] to the relay now: true when it took it
  Future<bool> handLast(int ident, DevLast last) async {
    try {
      final r = last.opener
          ? await wire.sendOpener(ident, last.arg, last.wire)
          : await wire.send(ident, last.arg, last.wire);
      return r == 'ok';
    } on Object {
      return false;
    }
  }

  /// my own [device] of [ident] is being removed: [frame] (my list without
  /// it) sealed on its session now and kept with where it goes, then handed
  /// to the relay until it took it, and again now and then until
  /// [kFarewellKept]. the engine keeps the device's key for its addresses
  /// alone meanwhile. true when there was a session to seal on
  Future<bool> farewell({
    required DevMe me,
    required int device,
    required String pin,
    required int reg,
    required String frame,
    bool once = false,
  }) async {
    final last = await sealLast(
      me: me,
      identity: devHex(me.identity),
      device: device,
      addr: kOwnDevices,
      pin: pin,
      reg: reg,
      frame: frame,
    );
    if (last == null) return false;
    final d = await mine();
    await d.insert('dev_farewell', {
      'ident': me.ident,
      'device': device,
      'key': pin,
      'arg': last.arg,
      'wire': last.wire,
      'opener': last.opener ? 1 : 0,
      'at': _clock(),
      'next_at': 0,
      'once': once ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await leaving(me.ident);
    return true;
  }

  /// a relay answers again after none did: the last words that waited for
  /// one go at once, not after their longest wait
  Future<void> relaysBack() async {
    final d = await mine();
    final n = await d.update('dev_farewell', {
      'tries': 0,
      'next_at': 0,
    }, where: 'tries > 0');
    if (n > 0) await pump();
  }

  /// whether the last word to my own [device] of [ident] on [key] is
  /// sealed and kept already: a removal cut short seals none twice
  Future<bool> farewellHeld(int ident, int device, String key) async =>
      (await (await mine()).query(
        'dev_farewell',
        columns: ['device'],
        where: 'ident = ? AND device = ? AND key = ?',
        whereArgs: [ident, device, key],
        limit: 1,
      )).isNotEmpty;

  /// the leaving keys the engine holds for [ident]'s last words, as the
  /// rows are: set at a start and whenever one comes or goes
  Future<void> leaving(int ident) async {
    final d = await mine();
    final rows = await d.query(
      'dev_farewell',
      columns: ['device', 'key'],
      where: 'ident = ?',
      whereArgs: [ident],
    );
    try {
      await state.call(d, 'own_leaving', {
        'ident': ident,
        'held': [
          for (final r in rows) {'id': r['device'], 'key': r['key']},
        ],
      });
    } on DevRefused {
      // a linked device: it removes no one
    }
  }

  // a last word to both addresses of its pair: the seeded one, and the
  // device's opener address, which a linked device watches for its phone
  // always, so a pair whose seeds went apart still carries it, a stolen
  // computer kept offline for days too (from the first day on, both go
  // once a day by [farewellAgainAfter]). true when a relay took either
  Future<bool> _handFarewell(int ident, DevLast last) async {
    Future<bool> one(Future<String> Function() go) async {
      try {
        return await go() == 'ok';
      } on Object {
        return false;
      }
    }

    final seeded = await one(() => wire.send(ident, last.arg, last.wire));
    final opened = await one(() => wire.sendOpener(ident, last.arg, last.wire));
    return seeded || opened;
  }

  // the last words due: each handed to the relay until it takes one, then
  // again by [farewellAgainAfter]; past [kFarewellKept] let go. the
  // engine's leaving keys follow the rows
  Future<void> _farewells(int now) async {
    final d = await mine();
    final idents = <int>{};
    for (final r in await d.query(
      'dev_farewell',
      where: 'at < ?',
      whereArgs: [now - kFarewellKept.inMilliseconds],
    )) {
      idents.add(r['ident'] as int);
    }
    if (idents.isNotEmpty) {
      await d.delete(
        'dev_farewell',
        where: 'at < ?',
        whereArgs: [now - kFarewellKept.inMilliseconds],
      );
    }
    for (final r in await d.query(
      'dev_farewell',
      where: 'next_at <= ?',
      whereArgs: [now],
    )) {
      final ident = r['ident'] as int;
      final age = Duration(milliseconds: now - (r['at'] as int));
      final once = r['once'] == 1;
      final ok = await _handFarewell(ident, (
        arg: r['arg'] as String,
        wire: r['wire'] as String,
        opener: r['opener'] == 1,
      ));
      final where = 'ident = ? AND device = ?';
      final args = [ident, r['device']];
      if (ok && once) {
        await d.delete('dev_farewell', where: where, whereArgs: args);
        idents.add(ident);
        continue;
      }
      if (ok) {
        final step = farewellAgainAfter(age).inMilliseconds;
        final half = step ~/ 2;
        await d.update(
          'dev_farewell',
          {'tries': 0, 'next_at': now + half + _rand.nextInt(half + 1)},
          where: where,
          whereArgs: args,
        );
        continue;
      }
      final tries = r['tries'] as int? ?? 0;
      await d.update(
        'dev_farewell',
        {
          'tries': tries + 1,
          'next_at': now + _again[min(tries, _again.length - 1)].inMilliseconds,
        },
        where: where,
        whereArgs: args,
      );
    }
    for (final i in idents) {
      await leaving(i);
    }
  }

  /// [identity]'s [device] left its list: nothing more is owed to it
  Future<void> dropDevice(int ident, String identity, int device) async {
    final d = await db();
    await d.delete(
      'dev_out',
      where: 'ident = ? AND peer = ? AND device = ?',
      whereArgs: [ident, identity, device],
    );
    // its seed goes too: a new device under the id never gets it
    for (final table in const ['dev_openers', 'pairs']) {
      await d.delete(
        table,
        // never the identity pair (1 to 1), the chat's own
        where:
            'ident = ? AND peer = ? AND their_device = ? AND '
            '(their_device != 1 OR my_device != 1)',
        whereArgs: [ident, identity, device],
      );
    }
  }

  /// [identity], a contact of my [ident], is gone (deleted, "not them"):
  /// nothing more is owed or pushed to any device of theirs, and their
  /// device pairs go. the phone's pair (device 1 to 1) is the chat's, not
  /// this file's
  Future<void> forget(int ident, String identity) async {
    final d = await db();
    await d.transaction((t) async {
      for (final table in const ['dev_out', 'dev_pushes', 'dev_openers']) {
        await t.delete(
          table,
          where: 'ident = ? AND peer = ?',
          whereArgs: [ident, identity],
        );
      }
      await t.delete(
        'dev_held_openers',
        where: 'ident = ? AND peer = ?',
        whereArgs: [ident, identity],
      );
      await t.delete(
        'pairs',
        where:
            'ident = ? AND peer = ? AND (their_device != 1 OR my_device != 1)',
        whereArgs: [ident, identity],
      );
    });
  }

  /// a receipt for [uid] from [identity]'s [device]: its copy is no longer
  /// owed. true for the first receipt of the uid, which the chat takes;
  /// every later one, from another device, is dropped
  Future<bool> receipt(
    int ident,
    String identity,
    int device,
    String uid,
  ) async {
    final d = await db();
    await d.delete(
      'dev_out',
      where: 'uid = ? AND ident = ? AND peer = ? AND device = ?',
      whereArgs: [uid, ident, identity, device],
    );
    final first = _receipts.add('$ident/$identity/$uid');
    while (_receipts.length > 512) {
      _receipts.remove(_receipts.first);
    }
    return first;
  }

  // ---- list pushes ----

  /// my lists of these identities changed: removals go to every contact
  /// that reads lists at once; additions ([added], the new devices' ids)
  /// reach at most [kPushPerPass] contacts a pass, passes some tens of
  /// minutes apart, the contacts of every identity in one random order
  Future<void> listsChanged(
    List<({int ident, int version, List<int> added, bool removed})> changes,
  ) async {
    if (!linkedDevicesOn) return;
    final d = await db();
    final now = _clock();
    final spread = <({int ident, String peer, int version, String devs})>[];
    final rows = <Map<String, Object?>>[];
    for (final ch in changes) {
      for (final peer in await _readers(d, ch.ident)) {
        if (ch.removed) {
          rows.add({
            'ident': ch.ident,
            'peer': peer,
            'version': ch.version,
            'kind': 'remove',
            'due_at': now,
            'devs': '',
          });
        }
        if (ch.added.isNotEmpty) {
          spread.add((
            ident: ch.ident,
            peer: peer,
            version: ch.version,
            devs: ch.added.join(','),
          ));
        }
      }
    }
    _shuffle(spread);
    var at = now;
    for (var i = 0; i < spread.length; i++) {
      if (i % kPushPerPass == 0) at += _gap(i == 0);
      final s = spread[i];
      rows.add({
        'ident': s.ident,
        'peer': s.peer,
        'version': s.version,
        'kind': 'add',
        // inside a pass the contacts go a few seconds apart
        'due_at': at + _rand.nextInt(60000),
        'devs': s.devs,
      });
    }
    await d.transaction((t) async {
      for (final r in rows) {
        await t.insert(
          'dev_pushes',
          r,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!hiddenRemovals) return;
      for (final ch in changes) {
        if (!ch.removed) continue;
        final k = '$kHiddenRemovalMeta${ch.ident}';
        final was = await t.query(
          'signal_meta',
          columns: ['v'],
          where: 'k = ?',
          whereArgs: [k],
        );
        final v = was.isEmpty
            ? 0
            : hiddenRemovalOf(was.first['v'] as String?)?.version ?? 0;
        if (ch.version <= v) continue;
        await t.insert('signal_meta', {
          'k': k,
          'v': '${ch.version}:$now',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    changed?.call(changes);
  }

  // a removal sent and not answered: again after as long as it has waited
  // (1, 2, 4, 8 days ...), at most [kRemovePushGapMost]
  static bool _againDue(Map<String, Object?> r, int now) {
    final sent = r['sent_at'] as int? ?? 0;
    if (r['kind'] != 'remove' || sent == 0) return true;
    final waited = sent - (r['due_at'] as int? ?? sent);
    final gap = waited.clamp(
      kPushAgain.inMilliseconds,
      kRemovePushGapMost.inMilliseconds,
    );
    return now - sent >= gap;
  }

  int _gap(bool first) {
    if (first) return _rand.nextInt(5 * 60000);
    final least = kPushGapLeast.inMilliseconds;
    return least + _rand.nextInt(kPushGapMost.inMilliseconds - least);
  }

  void _shuffle<T>(List<T> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = _rand.nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }

  // the identity keys of [ident]'s contacts whose phones read lists. only
  // current ones: a contact I deleted gets no list, a removal neither, as
  // it would show them I am still here
  Future<List<String>> _readers(DatabaseExecutor d, int ident) async => [
    for (final r in await d.query(
      'contacts',
      columns: ['ikey', 'caps'],
      where: 'ident = ? AND ikey IS NOT NULL AND accepted = 1',
      whereArgs: [ident],
    ))
      if ((r['caps'] as String? ?? '').split(',').contains(kCapDevices))
        r['ikey'] as String,
  ];

  // whether [identity] is still a contact of my [ident] here
  static Future<bool> _current(Database d, int ident, String identity) async =>
      (await d.query(
        'contacts',
        columns: ['ikey'],
        where: 'ident = ? AND ikey = ? AND accepted = 1',
        whereArgs: [ident, identity],
        limit: 1,
      )).isNotEmpty;

  /// [identity], a contact of my [ident], showed [kCapDevices] for the
  /// first time: my list goes to them once, with a bundle of each of my
  /// devices for each of theirs, a few minutes on
  Future<void> devicesShown(int ident, String identity) async {
    if (!linkedDevicesOn) return;
    await _queueAdd(
      await db(),
      ident,
      identity,
      _clock() + _rand.nextInt(10 * 60000),
    );
  }

  /// a device of mine opened [identity]'s chat and their app does not
  /// reach it yet: my list goes to them on the next pump, ahead of the
  /// spread, one contact at a time as any message goes. a push owed and not
  /// sent is brought forward; with none owed, or one sent and not answered,
  /// it goes again, once a day at most. true when one is due now
  Future<bool> pushNow(int ident, String identity) async {
    if (!linkedDevicesOn) return false;
    final d = await db();
    final now = _clock();
    final c = await d.query(
      'contacts',
      columns: ['caps'],
      where: 'ident = ? AND ikey = ? AND accepted = 1 AND blocked = 0',
      whereArgs: [ident, identity],
      limit: 1,
    );
    if (c.isEmpty ||
        !(c.first['caps'] as String? ?? '').split(',').contains(kCapDevices)) {
      return false;
    }
    final owed = await d.query(
      'dev_pushes',
      where: "ident = ? AND peer = ? AND kind = 'add' AND sent_at = 0",
      whereArgs: [ident, identity],
    );
    if (owed.isNotEmpty) {
      await _pushRows(d, owed, {'next_at': 0});
      await d.update(
        'dev_pushes',
        {'due_at': now},
        where:
            "ident = ? AND peer = ? AND kind = 'add' AND sent_at = 0 AND "
            'due_at > ?',
        whereArgs: [ident, identity, now],
      );
    } else {
      final again = await d.query(
        'dev_marks',
        columns: ['at'],
        where: "ident = ? AND peer = ? AND kind = 'dp' AND at > ?",
        whereArgs: [ident, identity, now - kAskEvery.inMilliseconds],
        limit: 1,
      );
      if (again.isNotEmpty) return false;
      // a rogue device asking for every contact spends at most this many
      // pool bundles a day
      final today = await d.query(
        'dev_marks',
        columns: ['peer'],
        where: "ident = ? AND kind = 'dp' AND at > ?",
        whereArgs: [ident, now - kAskEvery.inMilliseconds],
      );
      if (today.length >= kPushAgainMost) return false;
      await d.insert('dev_marks', {
        'ident': ident,
        'peer': identity,
        'kind': 'dp',
        'key': '',
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (!await _queueAdd(d, ident, identity, now, again: true)) return false;
    }
    _urgent.add('$ident/$identity');
    return true;
  }

  // an addition of my list's devices to [identity], due at [due]; [again]
  // takes the place of one sent, so it goes once more with fresh bundles
  Future<bool> _queueAdd(
    Database d,
    int ident,
    String identity,
    int due, {
    bool again = false,
  }) async {
    final held = await (await mine()).query(
      'dev_lists',
      columns: ['version'],
      where: "ident = ? AND owner = 'me'",
      whereArgs: [ident],
      limit: 1,
    );
    // no list of mine yet: it goes with the first one
    if (held.isEmpty) return false;
    final version = held.first['version'] as int;
    final Map<String, dynamic> own;
    try {
      own = await state.call(d, 'current', {'ident': ident});
    } on DevRefused {
      return false;
    }
    final devs = [
      for (final e in (own['devices'] as List? ?? const []))
        if ((e as Map)['phone'] != true) e['id'] as int,
    ];
    if (again && devs.isEmpty) return false;
    await d.insert(
      'dev_pushes',
      {
        'ident': ident,
        'peer': identity,
        'version': version,
        'kind': 'add',
        'due_at': due,
        'devs': devs.join(','),
      },
      conflictAlgorithm: again
          ? ConflictAlgorithm.replace
          : ConflictAlgorithm.ignore,
    );
    return true;
  }

  /// a message from [identity] opened at [at]: every addition that went to
  /// them before it was taken, as far as I can know. a removal waits for
  /// their phone to say it holds the list ([listTaken]): a message they
  /// wrote before it reached them says nothing of it
  Future<void> heard(int ident, String identity, int at) async {
    final d = await db();
    await d.delete(
      'dev_pushes',
      where:
          "ident = ? AND peer = ? AND kind != 'remove' AND sent_at > 0 AND "
          'sent_at <= ?',
      whereArgs: [ident, identity, at],
    );
  }

  /// [identity]'s phone holds my list of [ident] at [version]: every push
  /// of it or an older one that went is done
  Future<void> listTaken(int ident, String identity, int version) async {
    final d = await db();
    await d.delete(
      'dev_pushes',
      where: 'ident = ? AND peer = ? AND version <= ? AND sent_at > 0',
      whereArgs: [ident, identity, version],
    );
  }

  /// the pushes due now, one burst per contact: the list I hold now (the
  /// same bytes each time, stored before the first went) to each of their
  /// devices, and the first time, with an addition, one bundle of each new
  /// device of mine for each device of theirs, taken from the pool and
  /// written before the copy goes. [contact] reads a contact's row,
  /// [send] seals and sends the phone's copy
  Future<void> pushes({
    required Future<({DevMe me, DevContact c})?> Function(
      int ident,
      String identity,
    )
    contact,
    required DevPhone Function(DevMe me, DevContact c) phone,
    required Future<bool> Function(DevMe me, DevContact c, String cipher) send,
  }) async {
    if (!linkedDevicesOn) return;
    final d = await db();
    final now = _clock();
    // a removal no phone answered is let go at last: its contact may be
    // gone for good
    await d.delete(
      'dev_pushes',
      where: "kind = 'remove' AND sent_at > 0 AND due_at < ?",
      whereArgs: [now - kRemovePushKept.inMilliseconds],
    );
    final due = [
      for (final r in await d.query(
        'dev_pushes',
        where:
            'next_at <= ? AND ((sent_at = 0 AND due_at <= ?) OR '
            '(sent_at > 0 AND sent_at <= ?))',
        whereArgs: [now, now, now - kPushAgain.inMilliseconds],
        orderBy: 'due_at',
      ))
        if (_againDue(r, now)) r,
    ];
    final byContact = <String, List<Map<String, Object?>>>{};
    for (final r in due) {
      byContact.putIfAbsent('${r['ident']}/${r['peer']}', () => []).add(r);
    }
    // a removal goes at once; the rest at most a pass a pump, so a phone
    // that was off through the spread does not send its backlog in one go
    // and one a device of mine asked for now (pushNow)
    bool removal(List<Map<String, Object?>> rs) =>
        rs.any((r) => r['kind'] == 'remove' && r['sent_at'] == 0) ||
        _urgent.contains('${rs.first['ident']}/${rs.first['peer']}');
    final now1 = [
      for (final rs in byContact.values)
        if (removal(rs)) rs,
    ];
    final rest = [
      for (final rs in byContact.values)
        if (!removal(rs)) rs,
    ];
    _shuffle(rest);
    final go = [...now1, ...rest.take(kPushPerPass)];
    var at = now;
    for (var i = kPushPerPass; i < rest.length; i++) {
      if ((i - kPushPerPass) % kPushPerPass == 0) at += _gap(false);
      await _pushRows(d, rest[i], {'next_at': at + _rand.nextInt(60000)});
    }
    for (final rs in go) {
      final ident = rs.first['ident'] as int;
      final identity = rs.first['peer'] as String;
      _urgent.remove('$ident/$identity');
      // one not a contact now gets nothing: a removal owed to one deleted
      // since goes, a list waits for a request to be accepted
      if (!await _current(d, ident, identity)) {
        await d.delete(
          'dev_pushes',
          where: "ident = ? AND peer = ? AND kind = 'remove'",
          whereArgs: [ident, identity],
        );
        continue;
      }
      final who = await contact(ident, identity);
      if (who == null) continue;
      final Map<String, dynamic> own;
      try {
        own = await state.call(d, 'current', {'ident': ident});
      } on DevRefused {
        continue;
      }
      final list = own['list'] as String;
      // bundles only with an addition's first send
      final add = <int>{
        for (final r in rs)
          if (r['kind'] == 'add' && r['sent_at'] == 0)
            for (final s in (r['devs'] as String? ?? '').split(','))
              if (int.tryParse(s) != null) int.parse(s),
      };
      // each device of theirs its own bundles: taken from the pool once and
      // kept on the push in the same transaction, then the same ones on
      // every retry. a crash after hands none twice, a failed push spends
      // no more. a device of theirs or of mine that came since the take
      // gets its own then: kept with the set they were taken for
      var per = _bundlesOf(rs);
      if (add.isNotEmpty && await _bundlesOwed(d, per, add, identity)) {
        try {
          final slots = _slots(
            await state.call(d, 'fanout', {
              'ident': ident,
              'contact': identity,
              'devices': who.c.devices,
              'phone_classic': who.c.phoneClassic,
              'now': now,
              if (noOwn) 'no_own': true,
            }),
          );
          final kept = per;
          final took = <int, List<String>>{
            if (kept != null)
              for (final e in kept.s.entries) e.key: [...e.value],
          };
          final keptFor = kept?.a ?? const <int>{};
          final newMine = add.difference(keptFor);
          final theirs = [
            for (final s in slots)
              if (!s.own) s.device,
          ];
          final owed = theirs.any(
            (dev) => !took.containsKey(dev) || newMine.isNotEmpty,
          );
          if (owed) {
            await d.transaction((t) async {
              for (final dev in theirs) {
                final want = took.containsKey(dev) ? newMine : add;
                if (want.isEmpty) continue;
                // the pool is mine: taken where it is, before the push
                // row notes it, so a crash spends a bundle and never hands
                // it twice
                final pool = identical(mine, db) ? t : await mine();
                (took[dev] ??= []).addAll(await _take(pool, ident, want, now));
              }
              await _pushRows(t, rs, {
                'bundles': jsonEncode({
                  'a': [...keptFor.union(add)],
                  's': {for (final e in took.entries) '${e.key}': e.value},
                }),
              });
            });
          }
          per = (a: keptFor.union(add), s: took);
        } on Object {
          await _pushFailed(d, rs, now);
          continue;
        }
      }
      final bundles = per?.s ?? const <int, List<String>>{};
      // with an addition's first send, each device of theirs gets a fresh
      // bundle of this phone too, at most once a day a device: a device of
      // theirs can then write to this phone before it ever wrote to them
      final phoneOf = <int, String>{};
      if (who.me.device == 1 &&
          rs.any((r) => r['kind'] == 'add' && r['sent_at'] == 0)) {
        try {
          phoneOf.addAll(await _phoneBundles(d, ident, identity, now));
        } on Object {
          // the list goes without
        }
      }
      // a device whose copy of this list is still owed (in dev_out until its
      // receipt) gets no second one: burst skips a slot owed under the uid,
      // so a retry after a failed phone copy is the phone's alone, and a
      // removal due with such an add still reaches every device not owed
      final DevBurst? r;
      try {
        r = await burst(
          who.me,
          who.c,
          // a uid, so each device's copy goes again until that device's
          // receipt; the version names it, one list a uid
          '$kEnvelopePrefix${jsonEncode({'u': 'dl:${_listVersion(list)}', 'dl': list})}',
          phone: phone(who.me, who.c),
          force: true,
          frameFor: (slot, f) {
            // my own devices get my list from the phone, not as a push
            if (slot.own) return null;
            final b = [
              ...bundles[slot.device] ?? const <String>[],
              ?phoneOf[slot.device],
            ];
            return b.isEmpty ? f : _with(f, (j) => j['db'] = b);
          },
        );
      } on Object {
        await _pushFailed(d, rs, now);
        continue;
      }
      if (r == null) {
        await _pushFailed(d, rs, now);
        continue;
      }
      final pc = r.phone;
      if (pc != null && !await send(who.me, who.c, pc)) {
        await _pushFailed(d, rs, now);
        continue;
      }
      await _pushRows(d, rs, {
        'sent_at': now,
        'bundles': '',
        'tries': 0,
        'next_at': 0,
      });
    }
  }

  // a fresh bundle of this phone for each device of [identity]'s list not
  // given one in the last [kAskEvery], marked before it goes
  Future<Map<int, String>> _phoneBundles(
    Database d,
    int ident,
    String identity,
    int now,
  ) async {
    final Map<String, dynamic> theirs;
    try {
      theirs = await state.call(d, 'current', {'identity': identity});
    } on DevRefused {
      return const {};
    }
    final out = <int, String>{};
    final ds = await sessions(ident);
    for (final e in (theirs['devices'] as List? ?? const [])) {
      if (e is! Map || e['id'] is! int || e['id'] == 1) continue;
      final dev = e['id'] as int;
      final had = await d.query(
        'dev_marks',
        columns: ['at'],
        where: "ident = ? AND peer = ? AND kind = 'p1' AND key = ? AND at > ?",
        whereArgs: [ident, identity, '$dev', now - kAskEvery.inMilliseconds],
        limit: 1,
      );
      if (had.isNotEmpty) continue;
      await d.insert('dev_marks', {
        'ident': ident,
        'peer': identity,
        'kind': 'p1',
        'key': '$dev',
        'at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      out[dev] = base64Encode(await ds.phoneBundle(now: now));
    }
    return out;
  }

  // whether a push still owes bundles: none taken yet, a device of mine
  // added since, or a device of theirs the list held names that has none.
  // read from the list, so a retry never runs the fanout (and its quiet
  // probes) for nothing
  Future<bool> _bundlesOwed(
    Database d,
    ({Set<int> a, Map<int, List<String>> s})? per,
    Set<int> add,
    String identity,
  ) async {
    if (per == null || add.difference(per.a).isNotEmpty) return true;
    try {
      final cur = await state.call(d, 'current', {'identity': identity});
      return [
        for (final e in (cur['devices'] as List? ?? const []))
          (e as Map)['id'] as int,
      ].any((id) => !per.s.containsKey(id));
    } on DevRefused {
      return !per.s.containsKey(1);
    }
  }

  // the bundles a push took, and the devices of mine they were taken for
  ({Set<int> a, Map<int, List<String>> s})? _bundlesOf(
    List<Map<String, Object?>> rs,
  ) {
    for (final r in rs) {
      final b = r['bundles'] as String? ?? '';
      if (b.isEmpty) continue;
      try {
        final j = jsonDecode(b) as Map;
        return (
          a: {for (final x in (j['a'] as List)) x as int},
          s: {
            for (final e in (j['s'] as Map).entries)
              int.parse(e.key as String): (e.value as List).cast<String>(),
          },
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _pushRows(
    DatabaseExecutor d,
    List<Map<String, Object?>> rs,
    Map<String, Object?> values,
  ) async {
    for (final row in rs) {
      await d.update(
        'dev_pushes',
        values,
        where: 'ident = ? AND peer = ? AND version = ? AND kind = ?',
        whereArgs: [row['ident'], row['peer'], row['version'], row['kind']],
      );
    }
  }

  // a push that did not go waits longer each time, its bundles kept
  Future<void> _pushFailed(Database d, List<Map<String, Object?>> rs, int now) {
    final tries = rs.map((r) => r['tries'] as int? ?? 0).reduce(max);
    final gap = _again[min(tries, _again.length - 1)];
    return _pushRows(d, rs, {
      'tries': tries + 1,
      'next_at': now + gap.inMilliseconds,
    });
  }

  // one bundle of each of [devices] (my own, of [ident]) from the pool
  Future<List<String>> _take(
    DatabaseExecutor d,
    int ident,
    Set<int> devices,
    int now,
  ) async {
    final out = <String>[];
    for (final dev in devices) {
      try {
        final j = await state.call(d, 'pool_take', {
          'ident': ident,
          'device': dev,
          'now': now,
        });
        final b = j['kdb1'] as String?;
        if (b != null) out.add(b);
        if (j['low'] == true) await _askRefill(d, ident, dev, now);
      } on DevRefused {
        // none held: their device asks for one (dq) when it needs it
        await _askRefill(d, ident, dev, now);
      }
    }
    return out;
  }

  /// the pool_put args for a batch frame's json from my own [device] of
  /// [ident] (ownBatchArgs): its 'da' counts only when it is the ask this
  /// phone made last of that device, and only once; any other batch ages
  /// from its make time alone
  Future<Map<String, Object?>?> batchArgs(
    Map<String, dynamic> body,
    int ident,
    int device,
  ) async {
    final d = await mine();
    final held = await d.query(
      'dev_asks',
      columns: ['asked_at'],
      where: 'ident = ? AND device = ?',
      whereArgs: [ident, device],
      limit: 1,
    );
    final ask = held.isEmpty ? null : held.first['asked_at'] as int?;
    final da = body['da'];
    final take = ask != null && da is int && da == ask;
    final args = ownBatchArgs(
      body,
      ident,
      device,
      _clock(),
      asked: take ? ask : null,
    );
    if (args != null && take) {
      await d.delete(
        'dev_asks',
        where: 'ident = ? AND device = ?',
        whereArgs: [ident, device],
      );
    }
    return args;
  }

  // the pool of my own [device] of [ident] runs low: the device is asked
  // for more ('dn': how many, and when, which its answer echoes so the
  // batch ages from no earlier than the ask), at most once a day
  Future<void> _askRefill(
    DatabaseExecutor d,
    int ident,
    int device,
    int now,
  ) async {
    final k = 'own/$ident/$device';
    final at = _asked[k];
    if (at != null && now >= at && now - at < kAskEvery.inMilliseconds) return;
    final int need;
    final Map<String, dynamic> own;
    try {
      need =
          ((await state.call(d, 'pool_need', {
                    'ident': ident,
                    'device': device,
                    'now': now,
                  }))['need']
                  as num?)
              ?.toInt() ??
          0;
      own = await state.call(d, 'current', {'ident': ident});
    } on DevRefused {
      return;
    }
    if (need <= 0) return;
    Map? entry;
    for (final e in (own['devices'] as List? ?? const [])) {
      if ((e as Map)['id'] == device) entry = e;
    }
    final identity = _listIdentity(own['list']);
    if (entry == null || identity == null) return;
    _asked[k] = now;
    final uid = 'dn:$device:$now';
    // the ask kept: its answer's 'da' is taken only when it names it
    await d.insert('dev_asks', {
      'ident': ident,
      'device': device,
      'asked_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await d.insert('dev_out', {
      'uid': uid,
      'ident': ident,
      'peer': identity,
      'device': device,
      'at': now,
      'own': 1,
      'addr': kOwnDevices,
      'pin': entry['key'],
      'reg': entry['reg'] ?? 0,
      'plain':
          '$kEnvelopePrefix${jsonEncode({
            'dn': {'n': need, 'a': now},
          })}',
      'state': 'wait',
      'next_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

// the version a KDL2 wire names, after its magic and identity; 0 when it
// does not read
int _listVersion(Object? b64) {
  try {
    final w = base64Decode(b64 as String);
    if (w.length < 4 + 33 + 8) return 0;
    return ByteData.sublistView(w, 37, 45).getUint64(0);
  } catch (_) {
    return 0;
  }
}

// the identity key (hex) a KDL2 wire names, after its magic
String? _listIdentity(Object? b64) {
  try {
    final w = base64Decode(b64 as String);
    if (w.length < 4 + 33) return null;
    return devHex(w.sublist(4, 37));
  } catch (_) {
    return null;
  }
}

/// a linked device's batch for its phone's pool: its one-time KDB1s
/// ('db'), its last resort ('dz', on every change of its session keys) and
/// 'dk', when it made them by its own clock, which every batch carries; with
/// [asked], the phone's ask it answers ('da', echoed from 'dn')
String ownBatchFrame({
  required List<Uint8List> once,
  Uint8List? last,
  required int made,
  int? asked,
}) =>
    '$kEnvelopePrefix${jsonEncode({
      'db': [for (final b in once) base64Encode(b)],
      if (last != null) 'dz': base64Encode(last),
      'dk': made,
      'da': ?asked,
    })}';

/// the phone's pool_put args for a batch frame's json from its own
/// [device] of [ident] at [now]; null when it is no batch. a batch with
/// no make time is none: its bundles would age out on arrival. [asked] is
/// the phone's own ask the batch answers, checked against what it kept
/// (DeviceSend.batchArgs), never the frame's word alone
Map<String, Object?>? ownBatchArgs(
  Map<String, dynamic> body,
  int ident,
  int device,
  int now, {
  int? asked,
}) {
  final made = body['dk'];
  final once = body['db'];
  if (made is! int || once is! List || once.any((b) => b is! String)) {
    return null;
  }
  final last = body['dz'];
  return {
    'ident': ident,
    'device': device,
    'once': once,
    if (last is String) 'last': last,
    'made': made,
    if (asked != null && asked > 0) 'asked': asked,
    'now': now,
  };
}

// ---- frames ----

Map<String, dynamic>? _bodyOf(String frame) {
  try {
    final j = jsonDecode(frame.substring(kEnvelopePrefix.length));
    return j is Map<String, dynamic> ? j : null;
  } catch (_) {
    return null;
  }
}

String _uidOf(Map<String, dynamic> body, String frame) {
  final u = body['u'];
  if (u is String && u.isNotEmpty) return u;
  return 'h:${devHex(sha256.convert(utf8.encode(frame)).bytes.sublist(0, 12))}';
}

String _with(String frame, void Function(Map<String, dynamic> body) put) {
  final b = _bodyOf(frame);
  if (b == null) return frame;
  put(b);
  return '$kEnvelopePrefix${jsonEncode(b)}';
}

// the pair's seed, carried until the device answers
String _withSeed(String frame, Uint8List seed) =>
    _with(frame, (b) => b['as'] = devHex(seed));

// a fresh bundle asked of the contact's phone for these devices
String _withAsk(String frame, List<int> devices) =>
    _with(frame, (b) => b['dq'] = devices);

/// the own copy of [frame], sent in my chat with [peer] (their kryfo id),
/// for my other devices: a message (one with a uid) or my edit, reaction,
/// pin, take-back, vote or poll close, as it went. never a group's (that
/// goes once, after its members'), a chat with screenshots blocked, a
/// receipt, typing, a list frame or anything else of the session's own.
/// null when none goes
String? ownCopyOf(int ident, String peer, String frame) {
  if (frame.length > kOwnFrameMost) return null;
  final b = _bodyOf(frame);
  if (b == null || b.containsKey('g') || !ownCopyFits(b)) return null;
  final chat = ownChatName((id: peer, group: false));
  return '$kEnvelopePrefix${jsonEncode({
    'u': 'oc:${ownHash(frame)}',
    'oc': {'i': ident, 'c': chat, 'f': frame},
  })}';
}

// what an own copy never carries: receipts, typing, the session's and the
// devices' own words, a profile photo's slices, a slice ask, a card
const _notCopied = {
  'dr', 'dl', 'db', 'dq', 'dh', 'dn', 'dk', 'dz', 'da', 'dw', 'dy', 'fl', //
  'dp', 'oc', 'os', 'of', 'ob', 'hs', 'ou', 'ty', 'pp', 'rq', 'nd', 'in', //
  'gc', 'oa',
};

// my words on a message that carry its uid inside
const _copiedControls = {'ed', 'r', 'pn', 'un', 'vt', 'pc'};

/// whether a frame's [body] is one an own copy may carry: a message or my
/// word on one, nothing of _notCopied, no screenshot block
bool ownCopyFits(Map<String, dynamic> body) {
  for (final k in _notCopied) {
    if (body.containsKey(k)) return false;
  }
  final ss = body['ss'];
  if (ss is Map && ss['o'] == 1) return false;
  return body['u'] is String || _copiedControls.any(body.containsKey);
}

/// the keys of a group frame of my device's that my phone sends on as its
/// own: what a message says, never who sent it or anything else of theirs
const kOwnPassOnKeys = {
  'm', 'w', 'op', 'bl', 'st', 'pl', 'vt', 'pc', 'u', 'r', 'pn', 'ed', 'q', //
  'i', 'un', 'cr', 'f', 'fn', 'vo', 'vd', 'pv', 'mid', 'ci', 'ct', 'b', 'g',
  'sc', 'al', 'gf',
};

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

@visibleForTesting
Uint8List devBytesForTest(String hex) => _bytes(hex);
