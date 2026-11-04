// SPDX-License-Identifier: GPL-3.0-or-later
// own-device sync (linked devices step 7, job 8): what one device of mine
// does reaches my others, on the own device sessions alone. 'oc' is a frame
// I sent, as sent, filed in its chat as mine; 'os' a state op (read, a
// burn clock lit, delete for me, clear, a contact's or a group's rows, a
// chat gone, my profile), each with a counter of its device's so a late
// one never undoes a newer; 'of' (phone only) a contact's frame that could
// not reach my devices; 'ob' a device's daily word after a person unlocked
// it. each is answered by a receipt and sent again until it comes. none is
// ever taken from a contact's session, from a hidden chat or in the decoy,
// and nothing here runs with the switch off
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../device_sessions.dart' show kOwnDevices;
import '../message_envelope.dart' show kEnvelopePrefix;
import 'device_send.dart';
import 'device_state.dart';

/// the own words
const kOwnWords = {'oc', 'os', 'of', 'ob'};

/// the most a frame inside an own copy or a forward may be, in characters:
/// a slice of a file is about 22k, and the copy's wrap must still fit the
/// largest seal
const kOwnFrameMost = 28 * 1024;

/// the most one state op may be, as json
const kOwnOpMost = 16 * 1024;

/// how often a linked device tells its phone it is in use
const kOwnBeatEvery = Duration(days: 1);

/// the most uids one delete or one lit op may name
const kOwnUidsMost = 256;

/// the state ops, and the order each is kept in: a 'st' op is a chat's
/// rows or its end, the newest of a device wins
const kOwnOps = {
  'read': 'read',
  'lit': '',
  'del': '',
  'clear': 'clear',
  'contact': 'st',
  'gone': 'st',
  'group': 'st',
  'ungroup': 'st',
  'profile': 'st',
};

/// the ops a linked device may send its phone: never a contact or a group
/// it made up, never my profile
const kOwnOpsFromDevice = {'read', 'lit', 'del', 'clear', 'contact', 'gone'};

/// a chat as own frames name it: 'p:' and a contact's kryfo id, or 'g:'
/// and a group's id
typedef OwnChat = ({String id, bool group});

String ownChatName(OwnChat c) => '${c.group ? 'g' : 'p'}:${c.id}';

final _chatShape = RegExp(r'^[pg]:[A-Za-z0-9_.:\-]{1,128}$');

/// the chat [c] names; null for anything else
OwnChat? ownChatOf(Object? c) {
  if (c is! String || !_chatShape.hasMatch(c)) return null;
  return (id: c.substring(2), group: c.startsWith('g:'));
}

/// what the person did on a chat here, told by the session (session.dart)
/// for my other devices: set by the app once own sync runs
void Function(String kind, OwnChat chat, Map<String, Object?> a)? ownNoted;

/// a device of mine on identity [ident]: its id and key on my list
typedef OwnPeer = ({int id, String key, int reg});

/// what the app does with an own frame. each answers whether it took it;
/// one it did not take (a chat not here, hidden or with screenshots
/// blocked) is still answered, and never comes again
abstract class OwnApply {
  /// a frame I sent from another device, filed in [chat] as mine. in a
  /// group, [notReached] are the members that device could not reach: the
  /// phone passes it on to them
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached,
  });

  /// a frame [sender] sent my phone, that could not reach my devices
  Future<bool> forward(int ident, String sender, String frame, int came);

  /// a state op of another device of mine
  Future<bool> op(
    int ident,
    OwnChat? chat,
    String kind,
    Map<String, dynamic> a,
  );

  /// my device [device] said it is in use, at [at] by this clock
  Future<void> heard(int ident, int device, String key, int at);
}

class OwnSync {
  OwnSync({
    required this.state,
    required this.db,
    required this.send,
    required this.me,
    required this.apply,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final DeviceState state;

  /// the everyday container: my list, the counters, the order kept
  final Future<Database> Function() db;
  final DeviceSend send;

  /// this device on my identity [ident]
  final Future<DevMe?> Function(int ident) me;
  final OwnApply apply;
  final int Function() _clock;

  /// my other devices on [ident]'s list, as the engine holds it
  Future<List<OwnPeer>> others(int ident) async {
    final m = await me(ident);
    if (m == null) return const [];
    final Map<String, dynamic> j;
    try {
      j = await state.call(await db(), 'current', {'ident': ident});
    } on DevRefused {
      return const [];
    }
    return [
      for (final e in (j['devices'] as List? ?? const []))
        if (e is Map && e['id'] is int && e['key'] is String)
          if (e['id'] != m.device)
            (
              id: e['id'] as int,
              key: e['key'] as String,
              reg: (e['reg'] as num?)?.toInt() ?? 0,
            ),
    ];
  }

  // ---- sending ----

  /// a state op to every other device of mine. false when there is none
  Future<bool> op(
    int ident,
    String kind,
    OwnChat? chat,
    Map<String, Object?> a,
  ) async {
    if (!linkedDevicesOn || !kOwnOps.containsKey(kind)) return false;
    final m = await me(ident);
    if (m == null) return false;
    if (m.device != 1 && !kOwnOpsFromDevice.contains(kind)) return false;
    final to = await others(ident);
    if (to.isEmpty) return false;
    final n = await _next(ident);
    final body = {
      'n': n,
      'k': kind,
      if (chat != null) 'c': ownChatName(chat),
      ...a,
    };
    if (jsonEncode(body).length > kOwnOpMost) return false;
    final frame =
        '$kEnvelopePrefix${jsonEncode({'u': 'os:${m.device}:$n', 'os': body})}';
    await _toAll(m, to, frame);
    return true;
  }

  /// my own [frame] in [chat], to every other device of mine: one copy of
  /// a group's frame, whichever members it went to. [notReached], in a
  /// group, the members this device could not reach
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
  }) async {
    if (!linkedDevicesOn || frame.length > kOwnFrameMost) return false;
    final m = await me(ident);
    if (m == null) return false;
    final to = await others(ident);
    if (to.isEmpty) return false;
    final oc = {
      'i': ident,
      'c': ownChatName(chat),
      'f': frame,
      if (chat.group && notReached.isNotEmpty) 'n': notReached,
    };
    await _toAll(
      m,
      to,
      '$kEnvelopePrefix${jsonEncode({'u': 'oc:${_hash(frame)}', 'oc': oc})}',
    );
    return true;
  }

  /// [frame] from [sender], which my phone took at [came], to each of my
  /// linked devices: phone only
  Future<bool> forward(int ident, String sender, String frame, int came) async {
    if (!linkedDevicesOn || frame.length > kOwnFrameMost) return false;
    final m = await me(ident);
    if (m == null || m.device != 1) return false;
    final to = await others(ident);
    if (to.isEmpty) return false;
    await _toAll(
      m,
      to,
      '$kEnvelopePrefix${jsonEncode({
        'u': 'of:${_hash('$sender\n$frame')}',
        'of': {'h': sender, 't': came, 'f': frame},
      })}',
    );
    return true;
  }

  /// a linked device's word to its phone that a person uses it: at most
  /// once a [kOwnBeatEvery], after an unlock. true when one went
  Future<bool> beat(int ident) async {
    if (!linkedDevicesOn) return false;
    final m = await me(ident);
    if (m == null || m.device == 1) return false;
    final d = await db();
    final now = _clock();
    final last = int.tryParse(await _meta(d, 'own_beat:$ident') ?? '') ?? 0;
    if (last <= now && now - last < kOwnBeatEvery.inMilliseconds) return false;
    final phone = [
      for (final p in await others(ident))
        if (p.id == 1) p,
    ];
    if (phone.isEmpty) return false;
    await _putMeta(d, 'own_beat:$ident', '$now');
    final day = now ~/ Duration.millisecondsPerDay;
    await _toAll(
      m,
      phone,
      '$kEnvelopePrefix${jsonEncode({
        'u': 'ob:${m.device}:$day',
        'ob': {'t': now},
      })}',
    );
    return true;
  }

  Future<void> _toAll(DevMe m, List<OwnPeer> to, String frame) async {
    for (final p in to) {
      await send.toOne(
        ident: m.ident,
        identity: devHex(m.identity),
        device: p.id,
        addr: kOwnDevices,
        pin: p.key,
        reg: p.reg,
        frame: frame,
        own: true,
        receipt: true,
      );
    }
  }

  // ---- taking ----

  /// the own words of a frame from my device [from] on its own session
  /// (device_receive.dart's own door): taken, answered, and each kept in
  /// order. a receipt of mine back ends that copy
  Future<void> take(DevMe m, OwnPeer from, Map<String, dynamic> j) async {
    if (!linkedDevicesOn) return;
    final dr = j['dr'];
    if (dr is String && _ownUid(dr)) {
      await send.receipt(m.ident, devHex(m.identity), from.id, dr);
    }
    final u = j['u'];
    if (u is! String || !_ownUid(u)) return;
    try {
      await _taken(m, from, u, j);
    } finally {
      // answered even when it was not taken, so it never comes again
      await send.toOne(
        ident: m.ident,
        identity: devHex(m.identity),
        device: from.id,
        addr: kOwnDevices,
        pin: from.key,
        reg: from.reg,
        frame: '$kEnvelopePrefix${jsonEncode({'dr': u})}',
        own: true,
      );
    }
  }

  Future<bool> _taken(
    DevMe m,
    OwnPeer from,
    String u,
    Map<String, dynamic> j,
  ) async {
    final oc = j['oc'];
    if (oc is Map && u.startsWith('oc:')) {
      final chat = ownChatOf(oc['c']);
      final f = oc['f'];
      if (chat == null || f is! String || f.length > kOwnFrameMost) {
        return false;
      }
      if (!f.startsWith(kEnvelopePrefix) || 'oc:${_hash(f)}' != u) return false;
      final n = oc['n'];
      return apply.copy(
        m.ident,
        chat,
        f,
        notReached: [
          if (chat.group && n is List)
            for (final x in n.take(1024))
              if (x is String && x.length <= 128) x,
        ],
      );
    }
    final of = j['of'];
    if (of is Map && u.startsWith('of:')) {
      // only my phone passes a contact's frames on
      if (from.id != 1 || m.device == 1) return false;
      final h = of['h'], f = of['f'], t = of['t'];
      if (h is! String || h.isEmpty || h.length > 128) return false;
      if (f is! String || f.length > kOwnFrameMost) return false;
      if (!f.startsWith(kEnvelopePrefix) || 'of:${_hash('$h\n$f')}' != u) {
        return false;
      }
      final now = _clock();
      final came = t is int && t > 0 && t <= now ? t : now;
      return apply.forward(m.ident, h, f, came);
    }
    final os = j['os'];
    if (os is Map && u.startsWith('os:')) {
      if (jsonEncode(os).length > kOwnOpMost) return false;
      final k = os['k'], n = os['n'];
      if (k is! String || n is! int || !kOwnOps.containsKey(k)) return false;
      if (u != 'os:${from.id}:$n') return false;
      // a linked device asks its phone only what a device may
      if (m.device == 1 && !kOwnOpsFromDevice.contains(k)) return false;
      // and a device takes state from its phone alone
      if (m.device != 1 && from.id != 1) return false;
      final chat = ownChatOf(os['c']);
      if (os.containsKey('c') && chat == null) return false;
      final order = kOwnOps[k]!;
      if (order.isNotEmpty &&
          !await _inOrder(
            m,
            from,
            chat == null ? '-' : ownChatName(chat),
            order,
            n,
          )) {
        return false;
      }
      return apply.op(m.ident, chat, k, os.cast<String, dynamic>());
    }
    final ob = j['ob'];
    if (ob is Map && u.startsWith('ob:')) {
      if (m.device != 1 || from.id == 1) return false;
      await apply.heard(m.ident, from.id, from.key, _clock());
      return true;
    }
    return false;
  }

  // a state op of [from]'s, newer than the last one of its kind it sent
  // for [chat]: kept in frame_order under the device's key, so a new key on
  // the id starts again and a late copy never undoes a newer op
  Future<bool> _inOrder(
    DevMe m,
    OwnPeer from,
    String chat,
    String order,
    int n,
  ) async {
    final d = await db();
    final sender = 'own:${m.ident}/${from.id}/${from.key}';
    final key = 'os:$chat';
    return d.transaction((t) async {
      final r = await t.query(
        'frame_order',
        columns: ['w'],
        where: 'msg_uid = ? AND sender = ? AND kind = ?',
        whereArgs: [key, sender, order],
        limit: 1,
      );
      if (r.isNotEmpty && (r.first['w'] as int) >= n) return false;
      await t.insert('frame_order', {
        'msg_uid': key,
        'sender': sender,
        'kind': order,
        'w': n,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  // this device's next op counter on [ident], kept before the op goes:
  // never one twice, also across a restart
  Future<int> _next(int ident) async {
    final d = await db();
    return d.transaction((t) async {
      final k = 'own_n:$ident';
      final n = (int.tryParse(await _meta(t, k) ?? '') ?? 0) + 1;
      await _putMeta(t, k, '$n');
      return n;
    });
  }
}

bool _ownUid(String u) =>
    u.length <= 96 &&
    (u.startsWith('oc:') ||
        u.startsWith('os:') ||
        u.startsWith('of:') ||
        u.startsWith('ob:'));

/// the hash an own frame's uid carries
String ownHash(String s) =>
    devHex(sha256.convert(utf8.encode(s)).bytes.sublist(0, 16));

String _hash(String s) => ownHash(s);

Future<String?> _meta(DatabaseExecutor d, String k) async {
  final r = await d.query(
    'signal_meta',
    columns: ['v'],
    where: 'k = ?',
    whereArgs: [k],
    limit: 1,
  );
  return r.isEmpty ? null : r.first['v'] as String?;
}

Future<void> _putMeta(DatabaseExecutor d, String k, String v) => d.insert(
  'signal_meta',
  {'k': k, 'v': v},
  conflictAlgorithm: ConflictAlgorithm.replace,
);

/// a chat's rows as an own op carries them, for the digest that tells
/// whether they moved
String ownDigest(Object? rows) =>
    devHex(sha256.convert(utf8.encode(jsonEncode(rows))).bytes.sublist(0, 16));
