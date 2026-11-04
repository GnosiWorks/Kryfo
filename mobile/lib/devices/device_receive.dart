// SPDX-License-Identifier: GPL-3.0-or-later
// receiving from devices (linked devices step 7, job 5): a copy on a device
// pair is opened on that device's session and admitted by the engine
// (Admit, AdmitOpener) before anything of it is kept or shown; a refused
// one is wiped. the four list and bundle frames ('dl', 'db', 'dq', 'dh')
// are taken from a contact's phone and devices, a list that moved drops
// the sessions it no longer names, an opener whose device is not on the
// list held yet waits for the list. my own devices' frames take my own
// list, their bundles and the phone's ask for more; what they write is job
// 8's. nothing here runs with the switch off
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../device_sessions.dart';
import '../dlog.dart';
import '../message_envelope.dart' show kEnvelopePrefix;
import '../signal_ffi/kryfo_signal.dart' show kLsPreKey, kLsWhisper;
import '../wire_pad.dart' show unpad;
import 'device_send.dart';
import 'device_state.dart';
import 'own_sync.dart';

/// how long an opener from a device not on the list held waits for it
const kHeldOpenerKept = Duration(days: 7);

/// the most openers held for one contact
const kHeldOpenersMost = 16;

/// how often one device's bundle is handed to one contact who asks
const kAnswerEvery = Duration(days: 1);

/// the most device ids one ask may name
const kAskMost = 16;

/// a device-pair tag as the engine's inbox lines carry it: my identity
/// [ident], the other side's identity x key, their device and mine, and
/// whether it is the opener address
typedef DevTag = ({int ident, String peerX, int their, int my, bool opener});

/// what a contact's device wrote, for the chat: [peer] the contact's chat,
/// [frame] the envelope with the device's own words taken out
typedef DevCopyIn = ({String peer, String frame});

/// the session door's open of a device copy (app/signal.dart): opened on
/// [ds]'s session with [identity]'s [device] at [addr], admitted by the
/// engine before it is kept. it throws DevRefused for a copy the engine
/// turned down, LsError for one that did not open
typedef DevOpen =
    Future<({Uint8List plain, SessionRemote remote})> Function(
      DatabaseExecutor db,
      DeviceSessions ds, {
      required int ident,
      required String identity,
      required String addr,
      required int device,
      required int type,
      required Uint8List body,
      required Uint8List pin,
      required int reg,
    });

/// listening on device pairs, [arg] as the engine names them: "x/their/my"
/// for an opener address, "x/their/my.seed" for the seeded pair
abstract class DeviceListen {
  void listen(int ident, String arg);
  void unlisten(int ident, String arg);

  /// the pair's seed, for its addresses (HaloPairSeed, replacing one held)
  Future<String> seed(int ident, String arg, String seedHex);
}

/// what step 8 shows on a contact, or (for my own identity) on me:
/// 'equivocation' (their key signed two lists at one version), 'claim'
/// (their list names a key someone else holds), 'unknown_device' (a device
/// another copy of my phone linked, [key] its key), 'removed' (my own list
/// without this device)
typedef DevAlarm = ({int ident, String peer, String kind, String key});

/// the device frames: lists, bundles, asks, handbacks, the own frames
const kDeviceWords = {
  'as', 'dl', 'db', 'dq', 'dh', 'dw', 'dn', 'dz', 'dk', 'da', 'fl', //
  'oc', 'os', 'of', 'ob', 'hs', 'ou',
};

/// why a linked device says it unlinked itself ('ou'): not opened for 30
/// days, its clock set back, its lock state unreadable, or the person
/// unlinked it there
const kOwnLeftWhy = {'unused', 'clock', 'broken', 'self'};

// what a device's copy may not say for its contact: its engine's own
// onion and keys, its caps, a phone's first-contact and restart words
const _identityWords = {'o', 'x', 'e', 'cp', 'pg', 'fs', 'rq'};

class DeviceReceive {
  DeviceReceive({
    required this.state,
    required this.db,
    required this.sessions,
    required this.send,
    required this.listener,
    required this.open,
    required this.me,
    required this.contact,
    required this.phone,
    required this.sign,
    this.shown,
    this.blockedChat,
    this.ownHome,
    Future<Database> Function()? mine,
    int Function()? clock,
  }) : mine = mine ?? db,
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final DeviceState state;

  /// where the contacts' device state is: the everyday container, or the
  /// open vault for its hidden chats
  final Future<Database> Function() db;

  /// where my own state is (my list, the pool): the everyday container
  final Future<Database> Function() mine;

  /// the everyday side, for this one when it is the open vault's: my own
  /// devices and my own list are heard and kept there alone
  final DeviceReceive? ownHome;
  final Future<DeviceSessions> Function(int ident) sessions;
  final DeviceSend send;
  final DeviceListen listener;
  final DevOpen open;

  /// this device on my identity [ident]
  final Future<DevMe?> Function(int ident) me;

  /// a contact of my [ident] by their identity key (hex), in the everyday
  /// container, accepted and not blocked; null for anyone else
  final Future<({DevMe me, DevContact c})?> Function(int ident, String identity)
  contact;

  /// a frame of mine sealed and sent to [c]'s phone on the identity pair
  /// (this device a phone): true when it went
  final Future<bool> Function(DevMe me, DevContact c, String frame) phone;

  /// [body] signed by my identity [ident] (ks_sign, the device list
  /// context): only the phone signs
  final Future<Uint8List> Function(int ident, Uint8List body) sign;

  /// a held opener that opened once its list came: its words for the chat
  final Future<void> Function(DevCopyIn copy)? shown;

  /// a contact of my [ident] by their identity key who is blocked, on the
  /// everyday side; null for anyone else
  final Future<({DevMe me, DevContact c})?> Function(
    int ident,
    String identity,
  )?
  blockedChat;
  final int Function() _clock;

  /// what my own devices send beyond lists and bundles (job 8): set once
  /// the app can file them
  OwnSync? ownSync;

  /// my own devices a list of mine names that this device holds no row
  /// of: added with their notice (own_device_store.dart's one writer)
  Future<void> Function(int ident, List<({int id, String key, int reg})> added)?
  ownAdded;

  /// a linked device: my phone's list of my identity [ident] no longer
  /// names this device. it wipes
  Future<void> Function(int ident)? ownRemoved;

  /// a linked device: my own devices [gone] left my list of [ident]
  Future<void> Function(int ident, List<({int id, String key, int reg})> gone)?
  ownGoneHere;

  /// the phone: my own [device] of [ident] on [key] says it unlinked itself
  /// ([why], one of [kOwnLeftWhy]) and wiped
  Future<void> Function(int ident, int device, String key, String why)? ownLeft;

  final _alarms = StreamController<DevAlarm>.broadcast();

  /// the alarms as they come; dev_marks keeps them for step 8
  Stream<DevAlarm> get alarms => _alarms.stream;

  // ---- a copy on a device pair ----

  /// a line from a device-pair tag: opened, admitted, its device words
  /// taken. a contact's device's words for the chat come back; my own
  /// devices' and a copy that was refused, did not open or said nothing
  /// else give null
  ///
  /// [heldSince]: a held opener tried again keeps the time it first came
  Future<DevCopyIn?> receive(
    String tag,
    String cipher, {
    int? heldSince,
  }) async {
    if (!linkedDevicesOn) return null;
    final t = deviceTagOf(tag);
    if (t == null) return null;
    final m = await me(t.ident);
    if (m == null || t.my != m.device) return null;
    final identity = '05${t.peerX}';
    final own = identity == devHex(m.identity);
    if (own && ownHome != null) return null;
    var who = own ? null : await contact(t.ident, identity);
    // a blocked contact's device: opened and admitted, nothing of it taken
    // or answered, and what it wrote goes to the chat's block rules (noted
    // as dropped there, as their phone's is)
    var blocked = false;
    if (!own && who == null) {
      who = await blockedChat?.call(t.ident, identity);
      if (who == null) return null;
      blocked = true;
    }
    final Uint8List wire;
    try {
      wire = base64Decode(cipher);
    } on FormatException {
      return null;
    }
    if (wire.isEmpty) return null;
    final type = wire[0];
    if (type != kLsPreKey && type != kLsWhisper) return null;
    final body = Uint8List.sublistView(wire, 1);
    // the phone pair of a phone is the chat's own, never one here
    if (t.their == 1 && m.device == 1) return null;
    final d = await db();
    var entry = await _entry(d, t.ident, own ? null : identity, t.their);
    // a contact's phone, here on a linked device, before any list of theirs
    // is held: the phone is its identity key, and its opener names its reg.
    // the engine admits a phone with no list on that key alone
    if (entry == null && !own && t.their == 1) {
      var reg = 0;
      if (type == kLsPreKey) {
        try {
          final lib = (await sessions(t.ident)).s.lib;
          reg = lib.preKeyMessageInfo(body).registrationId;
        } on Object {
          return null;
        }
      }
      entry = (key: identity, reg: reg);
    }
    if (entry == null) {
      if (type == kLsPreKey && !blocked) {
        await _hold(d, t, identity, cipher, since: heldSince);
      }
      return null;
    }
    final ds = await sessions(t.ident);
    final addr = own ? kOwnDevices : who!.c.peer;
    final ({Uint8List plain, SessionRemote remote}) o;
    try {
      o = await open(
        d,
        ds,
        ident: t.ident,
        identity: identity,
        addr: addr,
        device: t.their,
        type: type,
        body: body,
        pin: _bytes(entry.key),
        reg: entry.reg,
      );
    } on DevRefused catch (e) {
      // a device the list held does not name yet: its opener waits for it
      if (type == kLsPreKey &&
          !blocked &&
          (e.why == 'not_listed' || e.why == 'unknown')) {
        await _hold(d, t, identity, cipher, since: heldSince);
      }
      return null;
    } on Object {
      return null;
    }
    final String text;
    try {
      text = unpad(utf8.decode(o.plain));
    } on FormatException {
      return null;
    } finally {
      o.plain.fillRange(0, o.plain.length, 0);
    }
    final j = _bodyOf(text);
    if (j == null) return null;
    // the session is kept now: whatever throws below never costs the copy
    // its words for the chat, it would not open a second time
    if (blocked) return _chatWords(who!.c, j);
    try {
      await _heard(d, t, m, identity, entry.key, j);
    } catch (e) {
      _note('a device not noted as heard (${e.runtimeType})');
    }
    if (own) {
      try {
        await _ownWords(d, t, m, identity, j, o.remote, entry);
      } catch (e) {
        _note('own words not taken (${e.runtimeType})');
      }
      return null;
    }
    return _contactWords(d, m, who!.c, identity, t.their, j, o.remote);
  }

  // the device spoke: its seed taken, what waited for its session goes, and
  // a pair heard on its seeded address needs its opener address no more
  Future<void> _heard(
    Database d,
    DevTag t,
    DevMe m,
    String identity,
    String key,
    Map<String, dynamic> j,
  ) async {
    final s = j['as'];
    if (s is String && s.length == 64) {
      await _takeSeed(d, t, m, identity, key, s);
    }
    await send.sessionCame(t.ident, identity, t.their);
    if (!t.opener) listener.unlisten(t.ident, '${t.peerX}/${t.their}/${t.my}');
  }

  static const _pairWhere =
      'ident = ? AND peer = ? AND their_device = ? AND my_device = ?';

  // the seed a device's opener carries, for the pair's addresses. a pair
  // that holds one of mine already (both opened at once) keeps the lower:
  // both sides then settle on one, and my copies sealed meanwhile go again
  // on it until their receipts come
  Future<void> _takeSeed(
    Database d,
    DevTag t,
    DevMe m,
    String identity,
    String key,
    String theirs,
  ) async {
    final seed = _bytesOrNull(theirs);
    if (seed == null || seed.length != 32) return;
    final at = [t.ident, identity, t.their, m.device];
    final r = await d.query(
      'pairs',
      columns: ['seed'],
      where: _pairWhere,
      whereArgs: at,
      limit: 1,
    );
    final held = r.isEmpty ? null : r.first['seed'];
    if (held is List<int> && held.length == 32) {
      if (_lower(held, seed) <= 0) return;
    }
    final rec = await d.query(
      'dev_openers',
      columns: ['key'],
      where: _pairWhere,
      whereArgs: at,
      limit: 1,
    );
    final heldFor = rec.isEmpty ? null : rec.first['key'] as String?;
    await d.transaction((tx) async {
      await tx.delete('pairs', where: _pairWhere, whereArgs: at);
      await tx.insert('pairs', {
        'ident': t.ident,
        'peer': identity,
        'their_device': t.their,
        'my_device': m.device,
        'conv': 4,
        'seed': seed,
      });
      // the device key the seed came under: the send loop takes it for
      // that key only. a mark of my own opener on the same key stays
      if (heldFor != key) {
        await tx.delete('dev_openers', where: _pairWhere, whereArgs: at);
        await tx.insert('dev_openers', {
          'ident': t.ident,
          'peer': identity,
          'their_device': t.their,
          'my_device': m.device,
          'key': key,
          'at': 0,
        });
      }
    });
    final pair = '${t.peerX}/${t.their}/${m.device}';
    // the listen on the new seed takes the old one's place in the engine
    // (same tag), its addresses let go there: no unlisten that could land
    // after it
    final res = await listener.seed(t.ident, pair, theirs);
    if (res != 'ok') return;
    listener.listen(t.ident, '$pair.$theirs');
  }

  int _lower(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  // ---- my own devices ----

  Future<void> _ownWords(
    Database d,
    DevTag t,
    DevMe m,
    String identity,
    Map<String, dynamic> j,
    SessionRemote remote,
    ({String key, int reg}) entry,
  ) async {
    // what another device of mine did: its copies, state, forwards and
    // heartbeat (own_sync.dart), on this session alone
    final own = ownSync;
    if (own != null && (kOwnWords.any(j.containsKey) || j['dr'] is String)) {
      try {
        await own.take(m, (id: t.their, key: entry.key, reg: entry.reg), j);
      } catch (e) {
        _note('own frame not taken (${e.runtimeType})');
      }
    }
    final list = j['dl'];
    // a linked device takes its own list from its phone, or a device the
    // list it holds names; the phone signs its own
    if (list is String && m.device != 1) {
      await _ownList(d, m, identity, list, remote);
    }
    // the phone's pool: a batch from its own device, its ask checked
    if (m.device == 1 && j['dk'] is int && j['db'] is List) {
      final args = await send.batchArgs(j, t.ident, t.their);
      if (args != null) {
        try {
          await state.call(d, 'pool_put', args);
        } on DevRefused catch (e) {
          // a batch of another entry, or none that read: nothing kept
          _note('a batch not taken (${e.why})');
        }
      }
    }
    // a linked device's phone asks for bundles: a batch made now, its ask
    // echoed so the phone ages it from the ask
    final dn = j['dn'];
    if (dn is Map && m.device != 1 && t.their == 1) {
      await _batch(d, m, identity, dn);
    }
    // a contact's list my phone took, passed on: forward only
    final fl = j['fl'];
    if (fl is Map && m.device != 1 && t.their == 1) {
      await _fromMyPhone(m, fl, remote);
    }
    // a device of mine unlinked itself: the phone takes it off my list
    final ou = j['ou'];
    if (ou is Map && m.device == 1 && t.their != 1) {
      final w = ou['w'];
      if (w is String && kOwnLeftWhy.contains(w)) {
        await ownLeft?.call(m.ident, t.their, entry.key, w);
      }
    }
  }

  // a contact's list my phone took and passed on, inside its session: the
  // engine takes it only from my phone, forward only, as their own
  Future<void> _fromMyPhone(
    DevMe m,
    Map<dynamic, dynamic> fl,
    SessionRemote remote,
  ) async {
    final identity = fl['i'], list = fl['w'];
    if (identity is! String || list is! String) return;
    final who = await contact(m.ident, identity);
    if (who == null) return;
    final d = await db();
    final Map<String, dynamic> j;
    try {
      j = await state.session(d, 'phone_list', {
        'ident': m.ident,
        'identity': identity,
        'list': list,
      }, remote);
    } on DevRefused catch (e) {
      if (e.why == 'equivocation') {
        await _alarm(d, m.ident, identity, 'equivocation', '');
      }
      return;
    }
    await _claims(d, m.ident);
    final outcome = j['outcome'];
    if (outcome == 'first' || outcome == 'changed') {
      await listChanged(m, identity, who.c.peer);
    }
  }

  // a contact's list this phone took goes on to each of my own devices,
  // sealed on its session: a linked device that took the copy holds the
  // lists of then, and their next change may reach this phone alone
  Future<void> _passOn(DevMe m, String identity, String list) async {
    if (m.device != 1 || ownHome != null) return;
    final Map<String, dynamic> own;
    try {
      own = await state.call(await mine(), 'current', {'ident': m.ident});
    } on DevRefused {
      return;
    }
    final frame =
        '$kEnvelopePrefix${jsonEncode({
          'fl': {'i': identity, 'w': list},
        })}';
    for (final e in _entries(own['devices'])) {
      if (e.id == m.device) continue;
      await send.toOne(
        ident: m.ident,
        identity: devHex(m.identity),
        device: e.id,
        addr: kOwnDevices,
        pin: e.key,
        reg: e.reg,
        own: true,
        frame: frame,
      );
    }
  }

  Future<void> _ownList(
    Database d,
    DevMe m,
    String identity,
    String list,
    SessionRemote remote,
  ) async {
    Map<String, dynamic> j;
    try {
      j = await state.session(d, 'own_set', {
        'ident': m.ident,
        'identity': identity,
        'list': list,
      }, remote);
    } on DevRefused catch (e) {
      if (e.why == 'removed') {
        await _alarm(d, m.ident, identity, 'removed', '');
        // signed by my phone, without this device: it wipes
        await ownRemoved?.call(m.ident);
      }
      if (e.why == 'equivocation') {
        await _alarm(d, m.ident, identity, 'equivocation', '');
      }
      return;
    }
    await ownGone(m, identity, _entries(j['gone']));
    // a device of mine this one has no row of: its notice shows here too,
    // as on the phone that linked it
    final add = ownAdded;
    if (add != null) {
      try {
        final cur = await state.call(d, 'current', {'ident': m.ident});
        await add(m.ident, [
          for (final e in _entries(cur['devices']))
            if (e.id != m.device && e.id != 1) e,
        ]);
      } on DevRefused {
        // no list held
      }
    }
    await listenAll(only: identity);
  }

  /// my own devices [gone] from my list of my identity: their sessions,
  /// copies, seeds, pool and listens go
  Future<void> ownGone(
    DevMe m,
    String identity,
    List<({int id, String key, int reg})> gone,
  ) async {
    if (gone.isEmpty) return;
    final d = await db();
    for (final e in gone) {
      if (m.device == 1) {
        try {
          await state.call(d, 'pool_drop', {'ident': m.ident, 'device': e.id});
        } on DevRefused {
          // nothing pooled
        }
      }
      await _dropDevice(d, m, identity, kOwnDevices, e.id);
    }
    if (m.device != 1) await ownGoneHere?.call(m.ident, gone);
  }

  Future<void> _batch(
    Database d,
    DevMe m,
    String identity,
    Map<dynamic, dynamic> dn,
  ) async {
    final n = dn['n'];
    final a = dn['a'];
    if (n is! int || n <= 0) return;
    final own = await _entry(d, m.ident, null, 1);
    if (own == null) return;
    final ds = await sessions(m.ident);
    final now = _clock();
    final once = <Uint8List>[
      for (var i = 0; i < n.clamp(1, 64); i++)
        await ds.makeBundle(m.device, now: now),
    ];
    final last = await ds.lastResortBundle(m.device, now: now);
    await send.toOne(
      ident: m.ident,
      identity: identity,
      device: 1,
      addr: kOwnDevices,
      pin: own.key,
      reg: own.reg,
      own: true,
      frame: ownBatchFrame(
        once: once,
        last: last,
        made: now,
        asked: a is int ? a : null,
      ),
    );
  }

  // ---- a contact's phone and devices ----

  Future<DevCopyIn?> _contactWords(
    Database d,
    DevMe m,
    DevContact c,
    String identity,
    int device,
    Map<String, dynamic> j,
    SessionRemote remote,
  ) async {
    try {
      await _takeWords(d, m, c, identity, device, j, remote);
    } catch (e) {
      _note('device words not taken (${e.runtimeType})');
    }
    // a receipt from each device: the first counts, the rest go. a list's
    // own and a starter's are this file's
    final dr = j['dr'];
    var first = true;
    if (dr is String) {
      try {
        first = await send.receipt(m.ident, identity, device, dr);
      } catch (e) {
        _note('a receipt not noted (${e.runtimeType})');
      }
    }
    return _chatWords(c, j, receipt: first);
  }

  // what a contact's device wrote, for the chat: the device words and the
  // device's own keys out, a list's or starter's uid out, and a receipt
  // only when it is the first for its uid
  DevCopyIn? _chatWords(
    DevContact c,
    Map<String, dynamic> j, {
    bool receipt = true,
  }) {
    final out = Map<String, dynamic>.of(j)
      ..removeWhere((k, _) => kDeviceWords.contains(k))
      ..removeWhere((k, _) => _identityWords.contains(k));
    final dr = out['dr'];
    if (dr is String && (!receipt || _devUid(dr))) out.remove('dr');
    final u = out['u'];
    if (u is String && _devUid(u)) out.remove('u');
    if (!_says(out)) return null;
    return (peer: c.peer, frame: '$kEnvelopePrefix${jsonEncode(out)}');
  }

  /// the device words of a frame from [c]'s phone, on the identity pair:
  /// what libsignal's decrypt returned as its remote is [remote]. true when
  /// the frame says nothing else and is never shown
  Future<bool> takePhone(
    int ident,
    String identity,
    String text,
    SessionRemote remote,
  ) async {
    if (!linkedDevicesOn) return false;
    final j = _bodyOf(text);
    if (j == null || !hasDeviceWords(text)) return false;
    final who = await contact(ident, identity);
    if (who == null) return false;
    final d = await db();
    await _takeWords(d, who.me, who.c, identity, 1, j, remote);
    return deviceWordsOnly(text);
  }

  Future<void> _takeWords(
    Database d,
    DevMe m,
    DevContact c,
    String identity,
    int device,
    Map<String, dynamic> j,
    SessionRemote remote,
  ) async {
    final list = j['dl'];
    if (list is String) {
      await _takeList(d, m, c, identity, list, remote);
      // each device's receipt ends its own copy of a list
      final u = j['u'];
      if (u is String && u.startsWith('dl:') && device != 1) {
        await _answer(m, c, identity, device, {'dr': u});
      }
    }
    final db = j['db'];
    if (db is List) {
      await _takeBundles(d, m, c, identity, db.whereType<String>(), remote);
    }
    final dq = j['dq'];
    if (dq is List && m.device == 1) {
      await _answerAsk(d, m, c, identity, device, dq.whereType<int>());
    }
    final dh = j['dh'];
    if (dh is String && m.device == 1) {
      // my own list, so the everyday side's to sign and keep
      final h = ownHome ?? this;
      await h._handedBack(await h.db(), m, identity, dh);
    }
    if (j['dw'] == 1 && m.device == 1 && c.devices) {
      await _wantsMine(d, m, identity);
    }
  }

  // a contact's list: Accept, then the sessions it no longer names go and
  // the opener addresses of the ones it adds are heard. a list older than
  // the one held, from their phone, gets the held one back once per
  // version, so another copy of their phone signs above it
  Future<void> _takeList(
    Database d,
    DevMe m,
    DevContact c,
    String identity,
    String list,
    SessionRemote remote,
  ) async {
    final Map<String, dynamic> j;
    try {
      j = await state.session(d, 'accept', {
        'identity': identity,
        'list': list,
      }, remote);
    } on DevRefused catch (e) {
      switch (e.why) {
        case 'rollback':
          final held = e.answer['held'];
          if (held is String) await _handBack(d, m, c, identity, list, held);
        case 'equivocation':
          await _alarm(d, m.ident, identity, 'equivocation', '');
      }
      await _claims(d, m.ident);
      return;
    }
    await _claims(d, m.ident);
    final outcome = j['outcome'];
    if (outcome == 'first' || outcome == 'changed') {
      await listChanged(m, identity, c.peer);
      await _passOn(m, identity, list);
    }
  }

  /// [identity]'s list held moved: every session it no longer names on its
  /// key goes, with its copies, seed, quiet row and listens; every device
  /// it names that has not answered is heard on its opener address; the
  /// openers that waited for it are tried again
  Future<void> listChanged(DevMe m, String identity, String addr) async {
    final d = await db();
    final ds = await sessions(m.ident);
    final held = await ds.held(addr);
    if (held.isNotEmpty) {
      final j = await state.call(d, 'stale', {
        'identity': identity,
        'own': addr == kOwnDevices,
        'held': [
          for (final h in held) {'id': h.device, 'key': devHex(h.key)},
        ],
      });
      for (final id in (j['stale'] as List? ?? const []).whereType<int>()) {
        await _dropDevice(d, m, identity, addr, id);
      }
    }
    await listenAll(only: identity);
    await _retryHeld(d, m, identity);
  }

  Future<void> _dropDevice(
    Database d,
    DevMe m,
    String identity,
    String addr,
    int id,
  ) async {
    final ds = await sessions(m.ident);
    await ds.drop(addr, id);
    await send.dropDevice(m.ident, identity, id);
    try {
      await state.call(d, 'quiet', {
        'op': 'forget',
        'identity': identity,
        'device': id,
      });
    } on DevRefused {
      // nothing held
    }
    await d.delete(
      'dev_held_openers',
      where: 'ident = ? AND peer = ? AND device = ?',
      whereArgs: [m.ident, identity, id],
    );
    final pair = '${identity.substring(2)}/$id/${m.device}';
    listener.unlisten(m.ident, pair);
    listener.unlisten(m.ident, '$pair.0');
  }

  /// [identity], a contact of my [ident], is forgotten (deleted, "not
  /// them", declined, hidden): every device pair of theirs is no longer
  /// heard on, and what was marked for them goes. read before their rows go
  Future<void> forget(int ident, String identity) async {
    if (!linkedDevicesOn) return;
    await unlistenAll(ident, identity);
    await (await db()).delete(
      'dev_marks',
      where: 'ident = ? AND peer = ?',
      whereArgs: [ident, identity],
    );
  }

  /// every device pair of [identity], a contact of my [ident], heard on
  /// no more, with nothing of theirs deleted: their rows are moving to the
  /// other side (hidden or shown)
  Future<void> unlistenAll(int ident, String identity) async {
    if (!linkedDevicesOn) return;
    final d = await db();
    final m = await me(ident);
    if (m == null) return;
    final x = identity.substring(2);
    final pairs = <String>{
      for (final r in await d.query(
        'pairs',
        columns: ['their_device', 'my_device'],
        where:
            'ident = ? AND peer = ? AND (their_device != 1 OR my_device != 1)',
        whereArgs: [ident, identity],
      ))
        '$x/${r['their_device']}/${r['my_device']}',
    };
    try {
      final cur = await state.call(d, 'current', {'identity': identity});
      for (final e in _entries(cur['devices'])) {
        if (e.id == 1 && m.device == 1) continue;
        pairs.add('$x/${e.id}/${m.device}');
      }
    } on DevRefused {
      // no list held
    }
    for (final p in pairs) {
      listener.unlisten(ident, p);
      listener.unlisten(ident, '$p.0');
    }
  }

  /// every device pair of mine heard on: the seeded pair where a seed is
  /// held, the opener address while the device has not answered. [only]
  /// one identity's (a contact's, or mine for my own devices)
  Future<void> listenAll({String? only}) async {
    if (!linkedDevicesOn) return;
    final d = await db();
    final peers = <({int ident, String identity, String addr})>[];
    for (final r in await d.query(
      'contacts',
      columns: ['ident', 'ikey', 'halo_id'],
      where: 'ikey IS NOT NULL AND accepted = 1 AND blocked = 0',
    )) {
      final identity = r['ikey'] as String;
      if (only != null && identity != only) continue;
      peers.add((
        ident: r['ident'] as int? ?? 0,
        identity: identity,
        addr: r['halo_id'] as String,
      ));
    }
    for (final r
        in ownHome != null
            ? const <Map<String, Object?>>[]
            : await d.query('identities', columns: ['id'])) {
      final ident = r['id'] as int;
      final m = await me(ident);
      if (m == null) continue;
      final identity = devHex(m.identity);
      if (only != null && identity != only) continue;
      peers.add((ident: ident, identity: identity, addr: kOwnDevices));
    }
    for (final p in peers) {
      final m = await me(p.ident);
      if (m == null) continue;
      final own = p.addr == kOwnDevices;
      Map<String, dynamic> cur;
      try {
        cur = await state.call(
          d,
          'current',
          own ? {'ident': p.ident} : {'identity': p.identity},
        );
      } on DevRefused {
        // a linked device holds no list of this contact yet: their phone,
        // which is their identity key, may still open to it
        if (own || m.device == 1) continue;
        cur = {
          'devices': [
            {'id': 1, 'key': p.identity, 'reg': 0},
          ],
        };
      }
      final ds = await sessions(p.ident);
      for (final e in _entries(cur['devices'])) {
        if (own && e.id == m.device) continue;
        if (e.id == 1 && m.device == 1) continue;
        final pair = '${p.identity.substring(2)}/${e.id}/${m.device}';
        final s = await d.query(
          'pairs',
          columns: ['seed'],
          where: _pairWhere,
          whereArgs: [p.ident, p.identity, e.id, m.device],
          limit: 1,
        );
        final seed = s.isEmpty ? null : s.first['seed'];
        if (seed is List<int> && seed.length == 32) {
          listener.listen(p.ident, '$pair.${devHex(seed)}');
        }
        var answered = false;
        try {
          answered = await ds.answered(p.addr, e.id, _bytes(e.key));
        } on Object {
          answered = false;
        }
        if (!answered) listener.listen(p.ident, pair);
      }
    }
  }

  // the bundles of a contact's devices for this device: a session built
  // from each that lists, a held one built again only when it is a fresh
  // push for a silent device or the answer to my ask after a Rebuild
  Future<void> _takeBundles(
    Database d,
    DevMe m,
    DevContact c,
    String identity,
    Iterable<String> bundles,
    SessionRemote remote,
  ) async {
    final ds = await sessions(m.ident);
    for (final b in bundles.take(kAskMost)) {
      final Map<String, dynamic> j;
      try {
        j = await state.session(d, 'bundle', {
          'identity': identity,
          'kdb1': b,
        }, remote);
      } on DevRefused catch (e) {
        _note('a bundle not taken (${e.why})');
        continue;
      }
      final blk = j['block'] as Map<String, dynamic>;
      final dev = blk['device'] as int;
      if (dev == 1 && m.device == 1) continue;
      final key = blk['key'] as String? ?? identity;
      final reg = (blk['reg'] as num).toInt();
      try {
        final block = ds.s.lib.parseDeviceBundle(
          base64Decode(b),
          _bytes(identity),
        );
        final has = await ds.has(c.peer, dev);
        var fresh = false;
        var asked = false;
        if (has) {
          fresh =
              (await state.call(d, 'quiet', {
                'op': 'fresh',
                'identity': identity,
                'device': dev,
                'key': key,
              }))['fresh'] ==
              true;
          asked = !fresh && await send.waitsFor(m.ident, identity, dev);
        }
        final built = await ds.build(
          c.peer,
          dev,
          block,
          _bytes(key),
          reg,
          rebuild: fresh || asked,
        );
        if (!built) continue;
        if (asked) {
          await state.call(d, 'quiet', {
            'op': 'rebuilt',
            'identity': identity,
            'device': dev,
          });
        }
        await send.sessionCame(m.ident, identity, dev);
      } on Object catch (e) {
        _note('a session not built (${e.runtimeType})');
      }
    }
  }

  // a contact asks this phone for fresh bundles of my devices: one per
  // device a day for that contact, whichever of their devices asks, taken
  // from the pool and written before the answer goes
  Future<void> _answerAsk(
    Database d,
    DevMe m,
    DevContact c,
    String identity,
    int asker,
    Iterable<int> ids,
  ) async {
    final now = _clock();
    final out = <String>[];
    for (final id in ids.toSet().take(kAskMost)) {
      if (id < 2 || id > 127) continue;
      if (await _markedSince(
        d,
        m.ident,
        identity,
        'dq',
        '$id',
        now - kAnswerEvery.inMilliseconds,
      )) {
        continue;
      }
      await _mark(d, m.ident, identity, 'dq', '$id', now);
      try {
        // the pool is mine, wherever the contact's marks are
        final j = await state.call(await mine(), 'pool_take', {
          'ident': m.ident,
          'device': id,
          'now': now,
        });
        final b = j['kdb1'] as String?;
        if (b != null) out.add(b);
      } on DevRefused {
        // none pooled for it
      }
    }
    if (out.isEmpty) return;
    await _answer(m, c, identity, asker, {'db': out});
  }

  // a list of theirs refused as older, from their own phone: the one held
  // goes back to that phone once per version refused
  Future<void> _handBack(
    Database d,
    DevMe m,
    DevContact c,
    String identity,
    String refused,
    String held,
  ) async {
    final v = '${_listVersion(refused)}';
    if (await _markedSince(d, m.ident, identity, 'dh', v, -1)) return;
    await _mark(d, m.ident, identity, 'dh', v, _clock());
    await _answer(m, c, identity, 1, {'dh': held});
  }

  // a contact hands back my own list they hold, above mine: another copy of
  // this phone signed it. mine goes above it, signed here, to every contact
  // at once, and each device on it this phone does not know is told
  Future<void> _handedBack(
    Database d,
    DevMe m,
    String identity,
    String held,
  ) async {
    final Map<String, dynamic> j;
    try {
      j = await state.call(d, 'own_above', {'ident': m.ident, 'list': held});
    } on DevRefused catch (e) {
      _note('a handed back list not taken (${e.why})');
      return;
    }
    if (j['outcome'] != 'above') return;
    final mine = devHex(m.identity);
    for (final e in _entries(j['devices'])) {
      await _alarm(d, m.ident, mine, 'unknown_device', e.key);
    }
    final body = base64Decode(j['list'] as String);
    final sig = await sign(m.ident, body);
    final wire = Uint8List.fromList([...body, ...sig]);
    final Map<String, dynamic> set;
    try {
      set = await state.ownMine(d, m.ident, wire);
    } on DevRefused catch (e) {
      _note('the list above not kept (${e.why})');
      return;
    }
    await ownGone(m, mine, _entries(set['gone']));
    await send.listsChanged([
      (
        ident: m.ident,
        version: _listVersion(base64Encode(wire)),
        added: const [],
        removed: true,
      ),
    ]);
  }

  // a contact holds no list of mine (they deleted me and added me again):
  // mine goes to them, once a day at most
  Future<void> _wantsMine(Database d, DevMe m, String identity) async {
    final now = _clock();
    if (await _markedSince(
      d,
      m.ident,
      identity,
      'dw',
      '',
      now - kAnswerEvery.inMilliseconds,
    )) {
      return;
    }
    await _mark(d, m.ident, identity, 'dw', '', now);
    await send.devicesShown(m.ident, identity);
  }

  /// [identity], a contact of my [ident], showed they read lists and no
  /// list of theirs is held here: their phone is asked for it, once a day
  Future<void> askList(int ident, String identity) async {
    if (!linkedDevicesOn) return;
    final d = await db();
    try {
      await state.call(d, 'current', {'identity': identity});
      return;
    } on DevRefused catch (e) {
      if (e.why != 'not_listed') return;
    }
    final now = _clock();
    if (await _markedSince(
      d,
      ident,
      identity,
      'dw-sent',
      '',
      now - kAnswerEvery.inMilliseconds,
    )) {
      return;
    }
    final who = await contact(ident, identity);
    if (who == null || who.me.device != 1 || !who.c.devices) return;
    await _mark(d, ident, identity, 'dw-sent', '', now);
    await phone(who.me, who.c, '$kEnvelopePrefix${jsonEncode({'dw': 1})}');
  }

  // a frame of mine to one of [c]'s devices: their phone on the identity
  // pair when this is a phone, else that device's session
  Future<void> _answer(
    DevMe m,
    DevContact c,
    String identity,
    int device,
    Map<String, Object?> words,
  ) async {
    // none goes to a phone that does not read lists
    if (device == 1 && !c.devices) return;
    final frame = '$kEnvelopePrefix${jsonEncode(words)}';
    if (device == 1 && m.device == 1) {
      await phone(m, c, frame);
      return;
    }
    final d = await db();
    final e = await _entry(d, m.ident, identity, device);
    if (e == null) return;
    await send.toOne(
      ident: m.ident,
      identity: identity,
      device: device,
      addr: c.peer,
      pin: e.key,
      reg: e.reg,
      frame: frame,
    );
  }

  // ---- held openers ----

  Future<void> _hold(
    Database d,
    DevTag t,
    String identity,
    String cipher, {
    int? since,
  }) async {
    final now = _clock();
    await d.delete(
      'dev_held_openers',
      where: 'came_at < ?',
      whereArgs: [now - kHeldOpenerKept.inMilliseconds],
    );
    final n = (await d.query(
      'dev_held_openers',
      columns: ['id'],
      where: 'ident = ? AND peer = ?',
      whereArgs: [t.ident, identity],
    )).length;
    if (n >= kHeldOpenersMost) return;
    final bytes = utf8.encode(cipher);
    final same = await d.query(
      'dev_held_openers',
      columns: ['cipher'],
      where: 'ident = ? AND peer = ? AND device = ?',
      whereArgs: [t.ident, identity, t.their],
    );
    for (final r in same) {
      final c = r['cipher'];
      if (c is List<int> && _same(c, bytes)) return;
    }
    await d.insert('dev_held_openers', {
      'ident': t.ident,
      'peer': identity,
      'device': t.their,
      'cipher': bytes,
      // a retry keeps the first time it came: 7 days from then, not from
      // each list that moves
      'came_at': since ?? now,
    });
  }

  Future<void> _retryHeld(Database d, DevMe m, String identity) async {
    final now = _clock();
    await d.delete(
      'dev_held_openers',
      where: 'came_at < ?',
      whereArgs: [now - kHeldOpenerKept.inMilliseconds],
    );
    final rows = await d.query(
      'dev_held_openers',
      where: 'ident = ? AND peer = ? AND came_at >= ?',
      whereArgs: [m.ident, identity, now - kHeldOpenerKept.inMilliseconds],
      orderBy: 'id',
    );
    for (final r in rows) {
      await d.delete('dev_held_openers', where: 'id = ?', whereArgs: [r['id']]);
      final c = r['cipher'];
      if (c is! List<int>) continue;
      final tag = _tagOf(
        m.ident,
        identity.substring(2),
        r['device'] as int,
        m.device,
      );
      final got = await receive(
        tag,
        utf8.decode(c),
        heldSince: r['came_at'] as int?,
      );
      final s = shown;
      if (got != null && s != null) await s(got);
    }
  }

  // ---- marks and alarms ----

  Future<bool> _markedSince(
    DatabaseExecutor d,
    int ident,
    String peer,
    String kind,
    String key,
    int since,
  ) async => (await d.query(
    'dev_marks',
    columns: ['at'],
    where: 'ident = ? AND peer = ? AND kind = ? AND key = ? AND at > ?',
    whereArgs: [ident, peer, kind, key, since],
    limit: 1,
  )).isNotEmpty;

  Future<void> _mark(
    DatabaseExecutor d,
    int ident,
    String peer,
    String kind,
    String key,
    int at,
  ) => d.insert('dev_marks', {
    'ident': ident,
    'peer': peer,
    'kind': kind,
    'key': key,
    'at': at,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _alarm(
    Database d,
    int ident,
    String peer,
    String kind,
    String key,
  ) async {
    await _mark(d, ident, peer, 'alarm:$kind', key, _clock());
    _alarms.add((ident: ident, peer: peer, kind: kind, key: key));
  }

  // the contacts whose lists name a key someone else holds, as the engine
  // said last
  Future<void> _claims(Database d, int ident) async {
    for (final p in state.claimants) {
      if (await _markedSince(d, ident, p, 'alarm:claim', '', -1)) continue;
      await _alarm(d, ident, p, 'claim', '');
    }
  }

  void _note(String what) => dlog('devices: $what');

  // ---- reading ----

  Future<({String key, int reg})?> _entry(
    DatabaseExecutor d,
    int ident,
    String? identity,
    int device,
  ) async {
    final Map<String, dynamic> j;
    try {
      j = await state.call(
        d,
        'current',
        identity == null ? {'ident': ident} : {'identity': identity},
      );
    } on DevRefused {
      return null;
    }
    for (final e in _entries(j['devices'])) {
      if (e.id == device) return (key: e.key, reg: e.reg);
    }
    return null;
  }
}

List<({int id, String key, int reg})> _entries(Object? l) => [
  for (final e in (l as List? ?? const []))
    if (e is Map && e['id'] is int && e['key'] is String)
      (
        id: e['id'] as int,
        key: e['key'] as String,
        reg: (e['reg'] as num?)?.toInt() ?? 0,
      ),
];

// the device words a phone's frame may carry: 'as' there is a v4 opener's
// seed, the chat's own
final _phoneWords = kDeviceWords.difference(const {'as'});

/// whether [text], an envelope from a phone, carries device words
bool hasDeviceWords(String text) =>
    _bodyOf(text)?.keys.any(_phoneWords.contains) ?? false;

/// whether [text] carries device words and nothing a chat shows: a list,
/// bundles, an ask or a handback alone
bool deviceWordsOnly(String text) {
  final j = _bodyOf(text);
  if (j == null || !j.keys.any(_phoneWords.contains)) return false;
  return !_says(_rest(j));
}

/// [text] with its device words out, as it is filed; as it is when it has
/// none
String withoutDeviceWords(String text) {
  final j = _bodyOf(text);
  if (j == null || !j.keys.any(_phoneWords.contains)) return text;
  return '$kEnvelopePrefix${jsonEncode(_rest(j))}';
}

Map<String, dynamic> _rest(Map<String, dynamic> j) {
  final rest = Map<String, dynamic>.of(j)
    ..removeWhere((k, _) => _phoneWords.contains(k));
  final u = rest['u'];
  if (u is String && _devUid(u)) rest.remove('u');
  return rest;
}

// a uid that is this file's or the send loop's: a list's, a starter's
bool _devUid(String u) => u.startsWith('dl:') || u.startsWith('s:');

// whether a frame says anything for the chat once the device words are out
bool _says(Map<String, dynamic> j) =>
    j.keys.any((k) => k != 'pz' && k != 'w' && k != 'cp');

/// the tag a device pair's lines carry, as the engine makes it (devTag)
String _tagOf(int ident, String peerX, int their, int my) =>
    '${ident == 0 ? '' : 'i$ident:'}$peerX/$their/$my/opn';

/// what a device-pair tag names, null for any other tag (the engine's
/// devTagOf)
DevTag? deviceTagOf(String tag) {
  var rest = tag;
  var ident = 0;
  if (rest.startsWith('i')) {
    final i = rest.indexOf(':');
    if (i < 2) return null;
    final n = int.tryParse(rest.substring(1, i));
    if (n == null || n <= 0 || '$n' != rest.substring(1, i)) return null;
    ident = n;
    rest = rest.substring(i + 1);
  }
  final opener = rest.endsWith('/opn');
  if (opener) rest = rest.substring(0, rest.length - 4);
  final p = rest.split('/');
  if (p.length != 3) return null;
  if (!_hexKey.hasMatch(p[0])) return null;
  final their = _devId(p[1]);
  final my = _devId(p[2]);
  if (their == null || my == null) return null;
  return (ident: ident, peerX: p[0], their: their, my: my, opener: opener);
}

final _hexKey = RegExp(r'^[0-9a-f]{64}$');

int? _devId(String s) {
  final n = int.tryParse(s);
  if (n == null || n < 1 || n > 127 || '$n' != s) return null;
  return n;
}

Map<String, dynamic>? _bodyOf(String frame) {
  if (!frame.startsWith(kEnvelopePrefix)) return null;
  try {
    final j = jsonDecode(frame.substring(kEnvelopePrefix.length));
    return j is Map<String, dynamic> ? j : null;
  } catch (_) {
    return null;
  }
}

int _listVersion(String b64) {
  try {
    final w = base64Decode(b64);
    if (w.length < 45) return 0;
    return ByteData.sublistView(w, 37, 45).getUint64(0);
  } catch (_) {
    return 0;
  }
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Uint8List _bytes(String hex) => devBytes(hex);

Uint8List? _bytesOrNull(String hex) {
  if (hex.length.isOdd || !RegExp(r'^[0-9a-f]*$').hasMatch(hex)) return null;
  return _bytes(hex);
}
