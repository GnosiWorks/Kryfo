// SPDX-License-Identifier: GPL-3.0-or-later
// the vault's life: made, filled, emptied and gone. the databases, the list,
// the pin entry and the engine are stand-ins that keep their rows in memory,
// the files are real ones in a scratch folder, and a fault can be set on any
// step that writes, to show what a crash there leaves once the next start
// and the next open have put it right
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, useDatabasesForTest, session;
import 'package:kryfo/router.dart';
import 'package:kryfo/search.dart' show searchBody;
import 'package:kryfo/session.dart';
import 'package:kryfo/vault_life.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const _h = 'hidden-wreck-tone';
const _v = 'visible-plain-row';
const _m = 'member-only-one';
const _r = 'request-from-afar';
const _g1 = 'g1visible001';
const _g2 = 'g2hidden0001';
const _room = 'roomburner01';

// the uids of each chat, as the everyday side holds them before any move
const _hUids = {'h0', 'h1', 'h2', 'hp'};
const _g2Uids = {'g2m', 'g2h', 'g2p'};
const _stayUids = {'v0', 'r0', 'g1h', 'rm0'};

class _Fault implements Exception {
  _Fault(this.what);
  final String what;
  @override
  String toString() => 'fault at $what';
}

// how a table's rows are told apart
const _keys = {
  'contacts': ['halo_id'],
  'groups': ['group_id'],
  'group_members': ['group_id', 'halo_id'],
  'messages': ['id'],
  'reactions': ['msg_uid', 'reactor'],
  'poll_votes': ['poll_uid', 'voter'],
  'pins_out': ['msg_uid'],
  'edits_out': ['msg_uid'],
  'media_wants': ['media_id'],
  'media_chunks': ['media_id', 'idx'],
  'held_onion': ['id'],
  'shield': ['halo_id'],
  'vouches': ['halo_id', 'voucher_id'],
};

// one database's rows, its search words by row id and its own meta
class _Tables {
  final t = {for (final k in _keys.keys) k: <Map<String, Object?>>[]};
  final fts = <int, String>{};
  final meta = <String, String>{};
  var _id = 0;

  int nextId() => ++_id;

  List<Map<String, Object?>> operator [](String table) => t[table]!;

  void put(String table, Map<String, Object?> row) {
    final k = _keys[table]!;
    t[table]!
      ..removeWhere((r) => k.every((c) => r[c] == row[c]))
      ..add({...row});
  }

  Map<String, Object?>? contact(String id) {
    for (final r in t['contacts']!) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  Set<String> get uids => {
    for (final m in t['messages']!) m['msg_uid'] as String,
  };

  Map<String, Object?>? msg(String uid) {
    for (final m in t['messages']!) {
      if (m['msg_uid'] == uid) return m;
    }
    return null;
  }

  String? message(String uid) => msg(uid)?['plaintext'] as String?;
}

Map<String, Object?> _person(
  String id, {
  int accepted = 1,
  String? nickname,
  String? atmosphere,
  int backPaired = 1,
}) => {
  'halo_id': id,
  'onion': 'o-$id',
  'xpub': 'x-$id',
  'first_seen': 1,
  'last_seen': 2,
  'back_paired': backPaired,
  'nickname': nickname,
  'blocked': 0,
  'muted': 0,
  'archived': 0,
  'verified': 0,
  'unread': 0,
  'atmosphere': atmosphere,
  'pinned': 0,
  'accepted': accepted,
};

// what a group's member or sender is where nothing else holds them
Map<String, Object?> _keyOnly(Map<String, Object?> r) => {
  ..._person(r['halo_id'] as String, accepted: 0),
  'onion': r['onion'],
  'xpub': r['xpub'],
  'last_seen': r['first_seen'],
  'back_paired': r['back_paired'],
  'blocked': r['blocked'],
};

void _say(
  _Tables t,
  String uid,
  String peer,
  String text, {
  String? group,
  String? media,
  String? file,
  String? fileName,
  String? poll,
  bool out = false,
}) {
  final row = <String, Object?>{
    'id': t.nextId(),
    'peer_id': peer,
    'direction': out || peer == 'me' ? 'out' : 'in',
    'plaintext': text,
    'sent_at': t._id,
    'msg_uid': uid,
    'group_id': group,
    'media_path': media,
    'file_path': file,
    'file_name': fileName,
    'poll': poll,
    'preview': null,
    'sticker': null,
  };
  t['messages'].add(row);
  final body = searchBody(row);
  if (body.trim().isNotEmpty) t.fts[row['id'] as int] = body;
}

// the list, as the router keeps it in the everyday database
class _Store implements RouterStore {
  _Store(this.w);
  final _World w;
  final rows = <String, Map<String, Object?>>{};
  final metas = <String, String>{};
  final inbox = <Map<String, Object?>>[];
  var _next = 1;

  @override
  Future<List<Map<String, Object?>>> hidden() async {
    w.read();
    return [
      for (final r in rows.values) {...r},
    ];
  }

  @override
  Future<void> putHidden(
    String chatId,
    String kind,
    String card,
    int at,
  ) async {
    w.step('list $chatId');
    rows[chatId] = {'chat_id': chatId, 'kind': kind, 'card': card, 'at': at};
  }

  @override
  Future<void> deleteHidden(String chatId) async {
    w.step('unlist $chatId');
    rows.remove(chatId);
  }

  @override
  Future<String?> meta(String k) async {
    w.read();
    return metas[k];
  }

  @override
  Future<void> putMeta(String k, String? v) async {
    w.step('meta $k');
    v == null ? metas.remove(k) : metas[k] = v;
  }

  @override
  Future<void> inboxAdd(
    String? uid,
    int? part,
    Uint8List sealed,
    int at,
  ) async {
    w.step('seal');
    inbox.add({
      'id': _next++,
      'uid': uid,
      'part': part,
      'sealed': sealed,
      'at': at,
    });
  }

  @override
  Future<bool> inboxHas(String uid, int? part) async =>
      inbox.any((r) => r['uid'] == uid && r['part'] == part);
  @override
  Future<int> inboxParts(String uid) async => 0;
  @override
  Future<int> inboxCount() async {
    w.read();
    return inbox.length;
  }

  @override
  Future<List<(int, int)>> inboxSizes() async => [
    for (final r in inbox) (r['id'] as int, (r['sealed'] as List<int>).length),
  ];
  @override
  Future<List<Map<String, Object?>>> inboxOldest(int limit) async =>
      inbox.take(limit).toList();
  @override
  Future<void> inboxDelete(int id) async {
    w.step('unseal');
    inbox.removeWhere((r) => r['id'] == id);
  }

  @override
  Future<void> inboxClear() async {
    w.step('inbox clear');
    inbox.clear();
  }

  Map<String, String> kinds() => {
    for (final r in rows.values) r['chat_id'] as String: r['kind'] as String,
  };
}

// a stand-in for age: sealed under the pair's number, opened only by its
// other half
class _Seal implements VaultSeal {
  @override
  String? seal(String pub, String b64) => pub.startsWith('pub-')
      ? base64Encode(utf8.encode('${pub.substring(4)}.$b64'))
      : null;
  @override
  List<String?> openMany(String priv, List<String> b64s) => [
    for (final s in b64s)
      if (utf8.decode(base64Decode(s)) case final x
          when x.startsWith('${priv.substring(5)}.'))
        x.substring(x.indexOf('.') + 1)
      else
        null,
  ];
}

// the pin entry, the vault's file and the disk
class _Host implements VaultHost {
  _Host(this.w);
  final _World w;
  bool lock = true;
  bool clash = false;
  // the key the vault's pin entry wraps
  String? entry;
  final log = <String>[];
  final shade = <String>[];
  var made = 0;

  @override
  bool get lockOn => lock;

  @override
  Future<bool> putEntry(HaloContainer c, String pin, String keyHex) async {
    w.step('entry');
    if (clash) return false;
    entry = keyHex;
    log.add('put');
    return true;
  }

  @override
  Future<void> clearEntry(HaloContainer c) async {
    w.step('clear entry');
    entry = null;
    log.add('clear');
  }

  @override
  Future<String> makeVault(HaloContainer c, String keyHex) async {
    w.step('make');
    made++;
    w.vault = _Tables()..meta['priv'] = 'priv-$made';
    File(p.join(w.docs.path, 'halo_v.db')).writeAsStringSync('vault $made');
    log.add('make');
    return 'pub-$made';
  }

  @override
  Future<HaloDb> openVault(HaloContainer c, String keyHex) async => w.vaultDb;

  @override
  ChatMover mover(HaloDb primary, HaloDb? vault) => _Mover(w);

  @override
  Future<void> clearShade(Iterable<String> payloads) async {
    w.step('shade');
    shade.addAll(payloads);
  }

  @override
  Future<void> moveFile(String from, String to) async {
    w.step('move ${p.basename(from)}');
    Directory(p.dirname(to)).createSync(recursive: true);
    File(from).renameSync(to);
  }

  @override
  Future<void> shred(String path) async {
    w.step('shred ${p.basename(path)}');
    File(path).deleteSync();
  }

  @override
  Future<void> wipeVault(HaloContainer c) async {
    w.step('wipe');
    await c.wipeFiles();
    w.vault = _Tables();
    log.add('wipe');
  }
}

// the rows of chats between the two stand-ins, as the sql mover moves them.
// each write is whole or not at all, like a transaction
class _Mover implements ChatMover {
  _Mover(this.w);
  final _World w;

  _Tables get _l => w.live;
  _Tables get _v => w.vault;
  String get _docs => w.docs.path;

  static bool _of(ChatRef c, Map<String, Object?> m) => c.group
      ? m['group_id'] == c.id
      : m['peer_id'] == c.id && m['group_id'] == null;

  static Set<String> _people(_Tables s, String group) => {
    for (final r in s['group_members'])
      if (r['group_id'] == group) r['halo_id'] as String,
    for (final r in s['messages'])
      if (r['group_id'] == group) r['peer_id'] as String,
  };

  String? _path(Object? path, String from, String to) {
    if (path is! String) return null;
    final a = '${p.join(_docs, 'media$from')}/';
    return path.startsWith(a)
        ? '${p.join(_docs, 'media$to')}/${path.substring(a.length)}'
        : path;
  }

  String? _wall(Object? atmo, String from, String to) {
    if (atmo is! String) return null;
    final a = 'image:${p.join(_docs, 'wallpapers$from')}/';
    return atmo.startsWith(a)
        ? 'image:${p.join(_docs, 'wallpapers$to')}/${atmo.substring(a.length)}'
        : atmo;
  }

  void _copy(ChatRef c, _Tables s, _Tables d, String from, String to) {
    final msgs = [
      for (final m in s['messages'])
        if (_of(c, m)) m,
    ];
    final uids = {for (final m in msgs) m['msg_uid']};
    if (c.group) {
      for (final g in s['groups'].where((g) => g['group_id'] == c.id)) {
        d.put('groups', {...g, 'atmosphere': _wall(g['atmosphere'], from, to)});
      }
      final people = _people(s, c.id);
      for (final r in s['contacts']) {
        if (!people.contains(r['halo_id'])) continue;
        if (d.contact(r['halo_id'] as String) != null) continue;
        d.put('contacts', _keyOnly(r));
      }
    } else {
      final row = s.contact(c.id);
      if (row != null && d.contact(c.id)?['accepted'] != 1) {
        d.put('contacts', {
          ...row,
          'atmosphere': _wall(row['atmosphere'], from, to),
        });
      }
    }
    for (final m in msgs) {
      if (d.msg(m['msg_uid'] as String) != null) continue;
      final n = {
        ...m,
        'id': d.nextId(),
        'media_path': _path(m['media_path'], from, to),
        'file_path': _path(m['file_path'], from, to),
      };
      d['messages'].add(n);
      final body = searchBody(n);
      if (body.trim().isNotEmpty) d.fts[n['id'] as int] = body;
    }
    for (final t in ['reactions', 'pins_out', 'edits_out']) {
      for (final r in s[t].where((r) => uids.contains(r['msg_uid']))) {
        d.put(t, r);
      }
    }
    for (final r in s['poll_votes'].where(
      (r) => uids.contains(r['poll_uid']),
    )) {
      d.put('poll_votes', r);
    }
    if (c.group) {
      for (final r in s['group_members'].where((r) => r['group_id'] == c.id)) {
        d.put('group_members', r);
      }
      return;
    }
    final wants = s['media_wants'].where((r) => r['peer_id'] == c.id).toList();
    final mids = {for (final r in wants) r['media_id']};
    for (final r in s['media_chunks'].where(
      (r) => mids.contains(r['media_id']),
    )) {
      d.put('media_chunks', r);
    }
    for (final r in wants) {
      d.put('media_wants', r);
    }
    for (final r in s['held_onion'].where((r) => r['peer_id'] == c.id)) {
      d.put('held_onion', {...r, 'id': d.nextId()});
    }
    for (final r in s['shield'].where((r) => r['halo_id'] == c.id)) {
      d.put('shield', r);
    }
    for (final r in s['vouches'].where(
      (r) => r['halo_id'] == c.id || r['voucher_id'] == c.id,
    )) {
      d.put('vouches', r);
    }
  }

  static bool _named(_Tables s, String who) =>
      s['group_members'].any((r) => r['halo_id'] == who) ||
      s['messages'].any((r) => r['peer_id'] == who && r['group_id'] != null);

  static bool _unheld(_Tables s, String who) =>
      s.contact(who)?['accepted'] == 0 &&
      !s['group_members'].any((r) => r['halo_id'] == who) &&
      !s['messages'].any((r) => r['peer_id'] == who) &&
      !s['held_onion'].any((r) => r['peer_id'] == who) &&
      !s['media_wants'].any((r) => r['peer_id'] == who) &&
      !s['vouches'].any((r) => r['halo_id'] == who || r['voucher_id'] == who);

  void _drop(_Tables s, ChatRef c) {
    final people = c.group ? _people(s, c.id) : {c.id};
    final msgs = [
      for (final m in s['messages'])
        if (_of(c, m)) m,
    ];
    final uids = {for (final m in msgs) m['msg_uid']};
    final ids = {for (final m in msgs) m['id']};
    for (final t in ['reactions', 'pins_out', 'edits_out']) {
      s[t].removeWhere((r) => uids.contains(r['msg_uid']));
    }
    s['poll_votes'].removeWhere((r) => uids.contains(r['poll_uid']));
    s['messages'].removeWhere((m) => ids.contains(m['id']));
    s.fts.removeWhere((id, _) => ids.contains(id));
    if (c.group) {
      s['group_members'].removeWhere((r) => r['group_id'] == c.id);
      s['groups'].removeWhere((r) => r['group_id'] == c.id);
      for (final who in people) {
        if (!_unheld(s, who)) continue;
        s['contacts'].removeWhere((r) => r['halo_id'] == who);
        s['shield'].removeWhere((r) => r['halo_id'] == who);
      }
      return;
    }
    final mids = {
      for (final r in s['media_wants'])
        if (r['peer_id'] == c.id) r['media_id'],
    };
    s['media_chunks'].removeWhere((r) => mids.contains(r['media_id']));
    s['media_wants'].removeWhere((r) => r['peer_id'] == c.id);
    s['held_onion'].removeWhere((r) => r['peer_id'] == c.id);
    s['shield'].removeWhere((r) => r['halo_id'] == c.id);
    s['vouches'].removeWhere(
      (r) => r['halo_id'] == c.id || r['voucher_id'] == c.id,
    );
    final row = s.contact(c.id);
    s['contacts'].removeWhere((r) => r['halo_id'] == c.id);
    if (row != null && _named(s, c.id)) s.put('contacts', _keyOnly(row));
  }

  List<String> _files(_Tables s, ChatRef c, String suffix) {
    final out = <String>[];
    final media = '${p.join(_docs, 'media$suffix')}/';
    final walls = 'image:${p.join(_docs, 'wallpapers$suffix')}/';
    for (final m in s['messages'].where((m) => _of(c, m))) {
      for (final x in [m['media_path'], m['file_path']]) {
        if (x is String && x.startsWith(media)) {
          out.add('media/${x.substring(media.length)}');
        }
      }
    }
    final holder = c.group
        ? s['groups'].where((g) => g['group_id'] == c.id)
        : s['contacts'].where((r) => r['halo_id'] == c.id);
    for (final r in holder) {
      final a = r['atmosphere'];
      if (a is String && a.startsWith(walls)) {
        out.add('wallpapers/${a.substring(walls.length)}');
      }
    }
    return out;
  }

  RouterCard _cardOf(Map<String, Object?> r) => RouterCard(
    r['halo_id'] as String,
    r['onion'] as String,
    r['xpub'] as String,
    backPaired: r['back_paired'] == 1,
    blocked: r['blocked'] == 1,
  );

  String? _card(ChatRef c) {
    if (!c.group) {
      final r = _v.contact(c.id);
      return r == null ? null : peerCard(_cardOf(r));
    }
    final who = [
      for (final r in _v['group_members'])
        if (r['group_id'] == c.id && _l.contact(r['halo_id'] as String) == null)
          r['halo_id'] as String,
    ]..sort();
    return groupCard([
      for (final id in who)
        if (_v.contact(id) case final r?) _cardOf(r),
    ]);
  }

  @override
  Future<void> attach() async => w.read();
  @override
  Future<void> detach() async => w.read();

  @override
  Future<MoveMarks> marks() async {
    w.read();
    return MoveMarks.decode(_v.meta['moves']);
  }

  void _mark(MoveMarks m) {
    final s = m.encode();
    s == null ? _v.meta.remove('moves') : _v.meta['moves'] = s;
  }

  @override
  Future<void> putMarks(MoveMarks m) async {
    w.step('marks');
    _mark(m);
  }

  @override
  Future<bool> hideable(ChatRef c) async {
    w.read();
    final here = c.group
        ? _l['groups'].any(
            (g) => g['group_id'] == c.id && g['room_pub'] == null,
          )
        : _l.contact(c.id)?['accepted'] == 1;
    return here && !await held(c);
  }

  @override
  Future<bool> held(ChatRef c) async {
    w.read();
    return c.group
        ? _v['groups'].any((g) => g['group_id'] == c.id)
        : _v.contact(c.id)?['accepted'] == 1 ||
              _v['messages'].any(
                (m) => m['peer_id'] == c.id && m['group_id'] == null,
              );
  }

  @override
  Future<Set<String>> peopleIn(ChatRef c, {required bool inVault}) async {
    w.read();
    return c.group ? _people(inVault ? _v : _l, c.id) : {c.id};
  }

  @override
  Future<void> copyIn(ChatRef c, MoveMarks marks) async {
    w.step('copy in ${c.id}');
    _copy(c, _l, _v, '', '_v');
    _mark(marks);
  }

  @override
  Future<List<String>> commitIn(ChatRef c, int at) async {
    w.step('commit in ${c.id}');
    final files = _files(_l, c, '');
    _drop(_l, c);
    final card = _card(c)!;
    w.store.rows[c.id] = {
      'chat_id': c.id,
      'kind': c.group ? kHiddenGroup : kHiddenPeer,
      'card': hidingCard(card, files),
      'at': at,
    };
    return files;
  }

  @override
  Future<List<String>> vaultFiles(ChatRef c) async {
    w.read();
    return _files(_v, c, '_v');
  }

  @override
  Future<void> commitOut(ChatRef c) async {
    w.step('commit out ${c.id}');
    _copy(c, _v, _l, '_v', '');
    w.store.rows.remove(c.id);
  }

  @override
  Future<void> dropVault(ChatRef c, MoveMarks marks) async {
    w.step('drop vault ${c.id}');
    _drop(_v, c);
    _mark(marks);
  }

  @override
  Future<void> dropLive(ChatRef c) async {
    w.step('drop live ${c.id}');
    _drop(_l, c);
  }

  @override
  Future<Map<String, (String, String)>> vaultCards() async {
    w.read();
    final chats = [
      for (final r in _v['contacts'])
        if (r['accepted'] == 1 ||
            _v['messages'].any(
              (m) => m['peer_id'] == r['halo_id'] && m['group_id'] == null,
            ))
          ChatRef(r['halo_id'] as String),
      for (final g in _v['groups'])
        ChatRef(g['group_id'] as String, group: true),
    ];
    return {
      for (final c in chats)
        if (_card(c) case final card?)
          c.id: (c.group ? kHiddenGroup : kHiddenPeer, card),
    };
  }
}

// a database as a session reads it, over the stand-in's rows
class _Db implements HaloDb {
  _Db(this._container, this._rows);
  final HaloContainer _container;
  final _Tables Function() _rows;

  _Tables get _t => _rows();

  @override
  HaloContainer get container => _container;

  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (
        people: {
          for (final r in _t['contacts'])
            r['halo_id'] as String: r['accepted'] == 1,
        },
        groups: {for (final g in _t['groups']) g['group_id'] as String},
      );

  @override
  Future<List<Map<String, Object?>>> contacts() async => [
    for (final r in _t['contacts'])
      if (r['accepted'] == 1) r,
  ];

  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {
    for (final m in _t['messages'])
      if (m['group_id'] == null) m['peer_id'] as String: m,
  };

  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => [
    for (final r in _t['contacts'])
      if (r['accepted'] == 0 && r['blocked'] == 0 && r['archived'] == 0) r,
  ];

  @override
  Future<int> pendingRequestCount() async => (await pendingRequests()).length;
  @override
  Future<List<Map<String, Object?>>> requestsInbox() => pendingRequests();

  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [
    for (final g in _t['groups']) {'created_at': 1, ...g},
  ];

  @override
  Future<List<String>> getGroupMembers(String groupId) async => [
    for (final r in _t['group_members'])
      if (r['group_id'] == groupId) r['halo_id'] as String,
  ];

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

class _World {
  _World(this.docs);

  final Directory docs;
  final live = _Tables();
  var vault = _Tables();
  late final store = _Store(this);
  late final host = _Host(this);
  final seal = _Seal();
  late VaultRouter router;
  late AppState app;
  late final liveDb = _Db(HaloContainer.everyday, () => live);
  late final vaultDb = _Db(HaloContainer.vault, () => vault);

  // the fault: the step it strikes at, and whether the app dies there
  var steps = 0;
  int? failAt;
  var crash = false;
  var dead = false;

  void step(String what) {
    if (dead) throw _Fault('after the crash: $what');
    steps++;
    if (steps == failAt) {
      if (crash) dead = true;
      throw _Fault(what);
    }
  }

  void read() {
    if (dead) throw _Fault('after the crash');
  }

  String get media => p.join(docs.path, 'media');
  String get mediaV => p.join(docs.path, 'media_v');

  // a phone with chats: V visible, H and the group G2 to hide, R a
  // request, M in G2 only, G1 visible with V and H, and a burner room
  static Future<_World> make(Directory docs) async {
    final w = _World(docs);
    final l = w.live;
    final walls = p.join(docs.path, 'wallpapers');
    l.put('contacts', _person(_v));
    l.put(
      'contacts',
      _person(_h, nickname: 'Hanna', atmosphere: 'image:$walls/$_h.jpg'),
    );
    l.put('contacts', _person(_r, accepted: 0));
    l.put('contacts', _person(_m, accepted: 0));
    for (final (g, who, room) in [
      (_g1, [_v, _h], null),
      (_g2, [_h, _m, _v], null),
      (_room, [_v], 'rp'),
    ]) {
      l.put('groups', {
        'group_id': g,
        'name': g,
        'created_at': 1,
        'is_admin': 0,
        'unread': 0,
        'mentioned': 0,
        'room_pub': room,
        'atmosphere': null,
      });
      for (final x in who) {
        l.put('group_members', {'group_id': g, 'halo_id': x, 'joined_at': 1});
      }
    }
    final m = w.media;
    _say(l, 'h0', _h, 'meet at the bridge');
    _say(l, 'h1', _h, '', media: '$m/h1.jpg');
    _say(
      l,
      'h2',
      _h,
      '',
      file: '$m/f_h2_doc.pdf',
      fileName: 'doc.pdf',
      out: true,
    );
    _say(l, 'hp', _h, 'lunch?', poll: '{"o":["soup","salad"]}', out: true);
    _say(l, 'v0', _v, 'the visible one', media: '$m/v1.jpg');
    _say(l, 'r0', _r, 'hello stranger');
    _say(l, 'g1h', _h, 'in the open group', group: _g1);
    _say(l, 'g2m', _m, 'from m', group: _g2, media: '$m/g2a.jpg');
    _say(l, 'g2h', _h, 'from h', group: _g2);
    _say(l, 'g2p', 'me', 'when', group: _g2, poll: '{"o":["noon","night"]}');
    _say(l, 'rm0', _v, 'burning', group: _room);
    l.put('reactions', {'msg_uid': 'h0', 'reactor': 'me', 'emoji': 'x'});
    l.put('reactions', {'msg_uid': 'g2m', 'reactor': _h, 'emoji': 'y'});
    l.put('reactions', {'msg_uid': 'v0', 'reactor': 'me', 'emoji': 'z'});
    l.put('poll_votes', {'poll_uid': 'hp', 'voter': _h, 'choices': '[0]'});
    l.put('poll_votes', {'poll_uid': 'g2p', 'voter': _m, 'choices': '[1]'});
    l.put('pins_out', {'msg_uid': 'h0', 'peer_id': _h, 'pinned': 1});
    l.put('edits_out', {'msg_uid': 'h2', 'peer_id': _h, 'new_text': 'e'});
    l.put('media_wants', {'media_id': 'mid1', 'peer_id': _h, 'total': 3});
    l.put('media_chunks', {'media_id': 'mid1', 'idx': 0, 'slice': 'AAAA'});
    l.put('held_onion', {'id': l.nextId(), 'peer_id': _h, 'cipher': 'c'});
    l.put('shield', {'halo_id': _h, 'headline': ''});
    l.put('vouches', {'halo_id': _h, 'voucher_id': _v});
    l.put('vouches', {'halo_id': _v, 'voucher_id': _h});
    for (final f in ['h1.jpg', 'f_h2_doc.pdf', 'g2a.jpg', 'v1.jpg']) {
      File(p.join(m, f))
        ..createSync(recursive: true)
        ..writeAsStringSync(f);
    }
    File(p.join(walls, '$_h.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('wall');
    await w.boot();
    return w;
  }

  // a start: the list read, a new app over the same disk, nothing open
  Future<void> boot() async {
    router = VaultRouter(store, seal);
    await router.load();
    app = AppState(router: router, host: host);
    useDatabasesForTest(liveDb, Session(liveDb));
  }

  // the vault's pin typed: the session over both
  Future<void> open() async =>
      useDatabasesForTest(liveDb, await Session.withVault(liveDb, vaultDb));

  // the app died at the fault: the next start puts right what the list
  // says, the next vault open what the vault's marks say
  Future<void> restart() async {
    dead = false;
    failAt = null;
    await boot();
    await app.repairVaultMoves();
    await app.settleVault(vaultDb);
  }

  Future<void> strike(int at, {required bool crash}) async {
    steps = 0;
    failAt = at;
    this.crash = crash;
  }
}

// every chat whole in exactly one place, the one the list says, with its
// files and search words beside its rows
void _whole(_World w, {String why = ''}) {
  final l = w.live;
  final v = w.vault;
  expect(w.router.pending, isEmpty, reason: '$why: flags left');
  expect(v.meta['moves'], isNull, reason: '$why: marks left');
  final all = {..._hUids, ..._g2Uids, ..._stayUids};
  for (final u in all) {
    final n = (l.uids.contains(u) ? 1 : 0) + (v.uids.contains(u) ? 1 : 0);
    expect(n, 1, reason: '$why: $u is in $n places');
  }
  final hHidden = w.router.hides(_h);
  final g2Hidden = w.router.hides(_g2);
  expect(
    (hHidden ? v : l).uids.containsAll(_hUids),
    isTrue,
    reason: '$why: H where the list says',
  );
  expect(
    (g2Hidden ? v : l).uids.containsAll(_g2Uids),
    isTrue,
    reason: '$why: G2 where the list says',
  );
  expect(l.uids.containsAll(_stayUids), isTrue, reason: '$why: everyday');
  expect(l.contact(_h)?['accepted'], hHidden ? 0 : 1, reason: '$why: H row');
  expect(v.contact(_h)?['accepted'] == 1, hHidden, reason: '$why: vault H');
  expect(l['groups'].any((g) => g['group_id'] == _g2), !g2Hidden);
  expect(v['groups'].any((g) => g['group_id'] == _g2), g2Hidden);
  expect(l.contact(_m) == null, g2Hidden, reason: '$why: M');
  expect(l.contact(_v)?['accepted'], 1);
  for (final (t, name) in [(l, 'everyday'), (v, 'vault')]) {
    final ids = {for (final m in t['messages']) m['id']};
    for (final m in t['messages']) {
      for (final f in [m['media_path'], m['file_path']]) {
        if (f is String) {
          expect(File(f).existsSync(), isTrue, reason: '$why: $name $f');
        }
      }
      final body = searchBody(m);
      if (body.trim().isNotEmpty) {
        expect(t.fts[m['id']], body, reason: '$why: $name words');
      }
    }
    expect(ids.containsAll(t.fts.keys), isTrue, reason: '$why: stale words');
    for (final tb in ['reactions', 'pins_out', 'edits_out']) {
      for (final r in t[tb]) {
        expect(t.uids, contains(r['msg_uid']), reason: '$why: $name $tb');
      }
    }
    for (final r in t['poll_votes']) {
      expect(t.uids, contains(r['poll_uid']), reason: '$why: $name vote');
    }
  }
  final hWall = (hHidden ? v : l).contact(_h)!['atmosphere'] as String;
  expect(File(hWall.substring('image:'.length)).existsSync(), isTrue);
  // no file in both folders
  for (final f in ['h1.jpg', 'f_h2_doc.pdf', 'g2a.jpg', 'v1.jpg']) {
    final a = File(p.join(w.media, f)).existsSync();
    final b = File(p.join(w.mediaV, f)).existsSync();
    expect(a != b, isTrue, reason: '$why: $f in ${a && b ? 'both' : 'none'}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('vault_life');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('create', () {
    test('the entry is written last, the list key before any chat', () async {
      final w = await _World.make(docs);
      expect(await w.app.createVault('246810'), isTrue);
      expect(w.host.log, ['clear', 'wipe', 'make', 'put']);
      expect(w.host.entry, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(w.store.metas['pub'], 'pub-1');
      expect(w.store.rows, isEmpty);
      expect(w.vault.meta['priv'], 'priv-1');
      // everyday is as it was
      expect(w.live.uids, {..._hUids, ..._g2Uids, ..._stayUids});
    });

    test('two setups make two keys', () async {
      final w = await _World.make(docs);
      await w.app.createVault('246810');
      final first = w.host.entry;
      await w.app.createVault('135790');
      expect(w.host.entry, isNot(first));
      expect(w.store.metas['pub'], 'pub-2');
    });

    test('no app lock: refused before anything is touched', () async {
      final w = await _World.make(docs);
      w.host.lock = false;
      await expectLater(w.app.createVault('246810'), throwsStateError);
      expect(w.host.log, isEmpty);
      expect(w.store.metas, isEmpty);
    });

    test('a pin in use: no entry, no key, no file', () async {
      final w = await _World.make(docs);
      w.host.clash = true;
      expect(await w.app.createVault('246810'), isFalse);
      expect(w.host.entry, isNull);
      expect(w.store.metas['pub'], isNull);
      expect(File(p.join(docs.path, 'halo_v.db')).existsSync(), isFalse);
      await expectLater(
        w.app.hideChats(people: [_h]),
        throwsA(isA<StateError>()),
      );
    });

    test('a fault part way leaves nothing a pin opens', () async {
      for (var at = 1; at <= 7; at++) {
        final w = await _World.make(docs);
        await w.strike(at, crash: false);
        try {
          await w.app.createVault('246810');
        } catch (_) {}
        expect(w.host.entry, isNull, reason: 'step $at');
        expect(w.live.uids, {..._hUids, ..._g2Uids, ..._stayUids});
        w.failAt = null;
        // the next setup goes through
        expect(await w.app.createVault('246810'), isTrue, reason: 'at $at');
        expect(w.host.entry, isNotNull);
      }
    });
  });

  group('hide', () {
    test('every row and file moves and the words follow', () async {
      final w = await _World.make(docs);
      await w.app.rememberPeerFc(_h, 'fc-h');
      await w.app.rememberPeerFc(_v, 'fc-v');
      await const FlutterSecureStorage().write(
        key: 'xpub_cache',
        value: jsonEncode({'x-$_h': _h, 'x-$_v': _v, 'x-$_m': _m}),
      );
      await w.app.createVault('246810');
      final n = await w.app.hideChats(
        people: [_h, _r, 'notes-or-nobody'],
        groups: [_g2, _room],
      );
      // a request and a room stay where they are
      expect(n, 2);
      _whole(w, why: 'hidden');
      final l = w.live;
      final v = w.vault;
      expect(w.router.hides(_h) && w.router.hides(_g2), isTrue);
      expect(v.uids, {..._hUids, ..._g2Uids});
      // H keeps a key-only row for the group everyone sees, M goes
      final stub = l.contact(_h)!;
      expect(stub['nickname'], isNull);
      expect(stub['atmosphere'], isNull);
      expect(stub['xpub'], 'x-$_h');
      expect(l.contact(_m), isNull);
      expect(v.contact(_h)!['nickname'], 'Hanna');
      expect(v.contact(_m)!['accepted'], 0);
      expect(v.contact(_v)!['accepted'], 0);
      // what came with the chats
      for (final t in [
        'pins_out',
        'edits_out',
        'media_wants',
        'media_chunks',
        'held_onion',
        'shield',
        'vouches',
      ]) {
        expect(l[t], isEmpty, reason: 'everyday $t');
        expect(v[t], isNotEmpty, reason: 'vault $t');
      }
      expect(l['reactions'].map((r) => r['msg_uid']), ['v0']);
      expect(v['reactions'], hasLength(2));
      expect(v['poll_votes'], hasLength(2));
      expect(l['poll_votes'], isEmpty);
      expect(v['group_members'], hasLength(3));
      // paths into the vault's folders, files with them
      final m = w.mediaV;
      expect(v.msg('h1')!['media_path'], '$m/h1.jpg');
      expect(v.msg('h2')!['file_path'], '$m/f_h2_doc.pdf');
      expect(
        v.contact(_h)!['atmosphere'],
        'image:${p.join(docs.path, 'wallpapers_v')}/$_h.jpg',
      );
      expect(Directory(w.media).listSync().map((f) => p.basename(f.path)), [
        'v1.jpg',
      ]);
      // search finds hidden words only in the vault
      final words = searchBody(v.msg('h0')!);
      expect(v.fts.values, contains(words));
      expect(l.fts.values, isNot(contains(words)));
      // the list: what receiving needs, nothing more
      final cards = w.store.rows;
      expect(jsonDecode(cards[_h]!['card'] as String), {
        'h': _h,
        'o': 'o-$_h',
        'x': 'x-$_h',
        'bp': 1,
      });
      expect(jsonDecode(cards[_g2]!['card'] as String), {
        'm': [
          {'h': _m, 'o': 'o-$_m', 'x': 'x-$_m', 'bp': 1},
        ],
      });
      // the everyday home without them
      expect(w.app.contacts.map((c) => c.haloId), [_v]);
      expect(w.app.groups.map((g) => g.groupId), [_g1, _room]);
      // nothing outside the vault names them
      expect(w.app.peerFcFor(_h), isNull);
      expect(w.app.peerFcFor(_v), 'fc-v');
      final fc = await const FlutterSecureStorage().read(key: 'peer_fc');
      expect(jsonDecode(fc!), {_v: 'fc-v'});
      final cache = await const FlutterSecureStorage().read(key: 'xpub_cache');
      expect(jsonDecode(cache!), {'x-$_v': _v});
      expect(w.host.shade, [_h, 'group:$_g2']);
      // arrivals for them now seal
      expect(w.router.route(_h, null), RouteTo.sealed);
      expect(w.router.route(_m, null), RouteTo.sealed);
      expect(w.router.route(_v, _g2), RouteTo.sealed);
      expect(w.router.route(_h, _g1), RouteTo.everyday);
      expect(w.router.route(_v, null), RouteTo.everyday);
    });

    test('with the vault open, its session owns them at once', () async {
      final w = await _World.make(docs);
      await w.app.createVault('246810');
      await w.app.hideChats(people: [_h]);
      await w.app.vaultSetupDone();
      await w.open();
      expect(await w.app.hideChats(groups: [_g2]), 1);
      expect(session.isHidden(_g2), isTrue);
      expect(session.isHidden(_h), isTrue);
      expect(session.isHidden(_v), isFalse);
      _whole(w, why: 'open');
    });

    test('once setup is done the key is gone', () async {
      final w = await _World.make(docs);
      await w.app.createVault('246810');
      await w.app.vaultSetupDone();
      await expectLater(w.app.hideChats(people: [_h]), throwsStateError);
      expect(w.live.contact(_h)!['accepted'], 1);
    });

    for (final crash in [false, true]) {
      test('a ${crash ? 'crash' : 'fault'} at each step loses nothing and '
          'shows nothing twice', () async {
        // how many steps a whole hide takes
        final dry = await _World.make(docs);
        await dry.app.createVault('246810');
        dry.steps = 0;
        await dry.app.hideChats(people: [_h], groups: [_g2]);
        final total = dry.steps;
        expect(total, greaterThan(8));
        for (var at = 1; at <= total; at++) {
          docs.deleteSync(recursive: true);
          docs.createSync();
          final w = await _World.make(docs);
          await w.app.createVault('246810');
          await w.strike(at, crash: crash);
          Object? err;
          try {
            await w.app.hideChats(people: [_h], groups: [_g2]);
          } catch (e) {
            err = e;
          }
          expect(err, isA<_Fault>(), reason: 'step $at');
          if (!crash) {
            // put right in place, with the vault at hand
            w.failAt = null;
            await w.app.settleVault(w.vaultDb);
            _whole(w, why: 'fault at $at');
          }
          await w.restart();
          _whole(w, why: '${crash ? 'crash' : 'fault'} at $at');
          // and a new setup goes through
          expect(await w.app.createVault('246810'), isTrue);
        }
      });
    }
  });

  group('unhide', () {
    Future<_World> hidden() async {
      final w = await _World.make(docs);
      await w.app.createVault('246810');
      await w.app.hideChats(people: [_h], groups: [_g2]);
      await w.app.vaultSetupDone();
      await w.open();
      return w;
    }

    test('every row and file comes back', () async {
      final w = await hidden();
      final before = w.live.fts.length;
      expect(await w.app.unhideChats(people: [_h], groups: [_g2]), 2);
      _whole(w, why: 'shown');
      expect(w.router.hides(_h) || w.router.hides(_g2), isFalse);
      expect(w.store.rows, isEmpty);
      expect(w.vault['messages'], isEmpty);
      expect(w.vault['contacts'], isEmpty);
      expect(w.vault.fts, isEmpty);
      expect(w.live.contact(_h)!['nickname'], 'Hanna');
      expect(w.live.contact(_m)!['accepted'], 0);
      expect(w.live.fts.length, before + 6);
      expect(Directory(w.mediaV).listSync(), isEmpty);
      expect(w.router.route(_h, null, open: true), RouteTo.everyday);
      expect(session.isHidden(_h), isFalse);
    });

    test('one of two back: the other keeps its people', () async {
      final w = await hidden();
      expect(await w.app.unhideChats(people: [_h]), 1);
      _whole(w, why: 'H back');
      // H stays in the hidden group as a key
      expect(w.vault.contact(_h)!['accepted'], 0);
      expect(w.router.hides(_g2), isTrue);
    });

    for (final crash in [false, true]) {
      test(
        'a ${crash ? 'crash' : 'fault'} at each step loses nothing',
        () async {
          final dry = await hidden();
          dry.steps = 0;
          await dry.app.unhideChats(people: [_h], groups: [_g2]);
          final total = dry.steps;
          expect(total, greaterThan(8));
          for (var at = 1; at <= total; at++) {
            docs.deleteSync(recursive: true);
            docs.createSync();
            final w = await hidden();
            await w.strike(at, crash: crash);
            Object? err;
            try {
              await w.app.unhideChats(people: [_h], groups: [_g2]);
            } catch (e) {
              err = e;
            }
            expect(err, isA<_Fault>(), reason: 'step $at');
            if (!crash) _whole(w, why: 'fault at $at');
            await w.restart();
            _whole(w, why: '${crash ? 'crash' : 'fault'} at $at');
          }
        },
      );
    }
  });

  group('replace and destroy', () {
    test('replace leaves no old file, entry, key or sealed row', () async {
      final w = await _World.make(docs);
      await w.app.createVault('246810');
      final oldKey = w.host.entry;
      await w.app.hideChats(people: [_h], groups: [_g2]);
      await w.app.vaultSetupDone();
      await w.router.seal(const Unsealed(_h, 'wire', false, 5), uid: 'late');
      expect(w.store.inbox, hasLength(1));
      w.host.log.clear();
      expect(await w.app.createVault('135790'), isTrue);
      // the old entry went first, the new one last
      expect(w.host.log, ['clear', 'wipe', 'make', 'put']);
      expect(w.host.entry, isNot(oldKey));
      expect(w.store.inbox, isEmpty);
      expect(w.store.metas['pub'], 'pub-2');
      expect(
        File(p.join(docs.path, 'halo_v.db')).readAsStringSync(),
        'vault 2',
      );
      expect(Directory(w.mediaV).existsSync(), isFalse);
      expect(
        Directory(p.join(docs.path, 'wallpapers_v')).existsSync(),
        isFalse,
      );
      expect(w.vault['messages'], isEmpty);
      // its people are kept only to drop what they send
      expect(w.store.kinds(), {
        _h: kHiddenGone,
        _m: kHiddenGone,
        _g2: kHiddenGone,
      });
      expect(w.router.route(_h, null), RouteTo.dropped);
      expect(w.router.route(_m, null), RouteTo.dropped);
      expect(w.router.route(_v, _g2), RouteTo.dropped);
      expect(w.router.route(_h, _g1), RouteTo.everyday);
      expect(w.router.route(_v, null), RouteTo.everyday);
      expect(w.router.ids, containsAll([_h, _m]));
      expect(w.router.listenFor, isEmpty);
      // the everyday side is untouched
      expect(w.live.uids, _stayUids);
    });

    test('destroy: entry first, list next, files last', () async {
      final w = await _World.make(docs);
      await w.app.createVault('246810');
      await w.app.hideChats(people: [_h]);
      w.host.log.clear();
      await w.app.destroyVault();
      expect(w.host.log, ['clear', 'wipe']);
      expect(w.host.entry, isNull);
      expect(w.store.metas['pub'], isNull);
      expect(w.store.kinds(), {_h: kHiddenGone});
      expect(File(p.join(docs.path, 'halo_v.db')).existsSync(), isFalse);
      await expectLater(w.app.hideChats(people: [_v]), throwsStateError);
    });

    test('never from inside the vault', () async {
      final w = await _World.make(docs);
      await w.app.createVault('246810');
      await w.app.hideChats(people: [_h]);
      await w.open();
      await expectLater(w.app.destroyVault(), throwsStateError);
      await expectLater(w.app.createVault('135790'), throwsStateError);
      expect(w.host.entry, isNotNull);
      expect(w.vault.uids, _hUids);
    });

    test('remove hidden chats brings every one back, then goes', () async {
      final w = await _World.make(docs);
      // a drop list from a vault before stays
      await w.store.putHidden('older-gone-one', kHiddenGone, '{}', 1);
      await w.app.createVault('246810');
      await w.app.hideChats(people: [_h], groups: [_g2]);
      await w.app.vaultSetupDone();
      await w.open();
      // someone the vault holds that the list does not name yet
      w.vault.put('contacts', _person('accepted-inside'));
      _say(w.vault, 'in0', 'accepted-inside', 'said in the vault');
      await w.app.removeVault();
      expect(w.host.entry, isNull);
      expect(w.store.metas['pub'], isNull);
      expect(w.store.kinds(), {'older-gone-one': kHiddenGone});
      expect(w.live.uids, {..._hUids, ..._g2Uids, ..._stayUids, 'in0'});
      expect(w.live.contact('accepted-inside')!['accepted'], 1);
      expect(File(p.join(docs.path, 'halo_v.db')).existsSync(), isFalse);
      expect(Directory(w.mediaV).existsSync(), isFalse);
      expect(File(p.join(w.media, 'h1.jpg')).existsSync(), isTrue);
      expect(session.vault, isNull);
      expect(w.app.contacts.map((c) => c.haloId).toSet(), {
        _v,
        _h,
        'accepted-inside',
      });
    });
  });

  group('a forgotten vault pin', () {
    test(
      'set up, never opened: everyday works, a new setup replaces it',
      () async {
        final w = await _World.make(docs);
        await w.app.createVault('246810');
        await w.app.hideChats(people: [_h], groups: [_g2]);
        await w.app.vaultSetupDone();
        // the pin is never typed again. the app starts over and over
        for (var i = 0; i < 2; i++) {
          await w.boot();
          await w.app.repairVaultMoves();
          await w.app.refreshContacts();
          await w.app.refreshGroups();
          expect(w.app.contacts.map((c) => c.haloId), [_v]);
          expect(w.app.groups.map((g) => g.groupId), [_g1, _room]);
          expect(w.live.uids, _stayUids);
          expect(w.router.route(_h, null), RouteTo.sealed);
          expect(w.router.route(_v, null), RouteTo.everyday);
        }
        // what comes for them waits sealed, and the everyday side moves on
        await w.router.seal(const Unsealed(_h, 'wire', false, 9), uid: 'w1');
        w.live.put('contacts', _person('new-friend'));
        _say(w.live, 'n0', 'new-friend', 'hi');
        // a new setup replaces the one nobody can open
        expect(await w.app.createVault('112233'), isTrue);
        expect(w.store.inbox, isEmpty);
        expect(w.store.kinds().values.toSet(), {kHiddenGone});
        expect(w.live.uids, {..._stayUids, 'n0'});
        expect(Directory(w.mediaV).existsSync(), isFalse);
        // and the new vault takes chats
        expect(await w.app.hideChats(people: ['new-friend']), 1);
        expect(w.vault.uids, {'n0'});
        expect(w.router.route('new-friend', null), RouteTo.sealed);
      },
    );

    test('with no vault a start changes nothing', () async {
      final w = await _World.make(docs);
      w.steps = 0;
      await w.app.repairVaultMoves();
      expect(w.steps, 0);
      expect(w.host.log, isEmpty);
      expect(w.store.rows, isEmpty);
    });
  });

  test('every table a chat has rows in moves with it', () {
    // the rest belong to the phone, the identity or the router
    const stays = {
      'identity',
      'seen_msgs',
      'prekeys',
      'signed_prekeys',
      'sessions',
      'peer_identities',
      'signal_meta',
      'search_meta',
      'hidden_chats',
      'vault_meta',
      'vault_inbox',
    };
    final src = [
      'lib/main.dart',
      'lib/router.dart',
    ].map((f) => File(f).readAsStringSync()).join('\n');
    // a prefixed name is another set of the signal store's tables
    final tables = {
      for (final m in RegExp(
        r'CREATE (?:VIRTUAL )?TABLE(?: IF NOT EXISTS)? (?:\$\{prefix\})?(\w+)',
      ).allMatches(src))
        m.group(1)!,
    };
    expect(tables.length, greaterThan(20));
    expect(
      tables.difference({...chatTables, ...stays}),
      isEmpty,
      reason: 'a new table: does a chat have rows in it?',
    );
    expect(chatTables.difference(tables), isEmpty);
  });
}
