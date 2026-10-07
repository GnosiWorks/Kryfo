// SPDX-License-Identifier: GPL-3.0-or-later
// what receiving knows of the hidden chats while their vault is shut: which
// chats the vault holds and how to reach the people in them, the key an
// arrival for them is sealed to, and what arrived sealed. the only file that
// names these tables, and no screen imports it

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

// where an arrival goes
enum RouteTo {
  // the everyday database
  everyday,
  // the open vault
  vault,
  // sealed until the vault opens
  sealed,
  // someone a vault that went held: nothing is kept, nothing is said
  dropped,
}

// kinds of a hidden_chats row
const kHiddenPeer = 'peer';
const kHiddenGroup = 'group';
// a chat of a vault that was replaced or taken away: its arrivals are
// dropped. a group's card says so with g
const kHiddenGone = 'gone';

// what may wait sealed while the vault is shut, in arrivals and in bytes.
// past either the oldest go first
const kMaxSealed = 5000;
const kMaxSealedBytes = 100 << 20;

// the three tables, in every container. the vault's are unused but for
// vault_meta, which holds its own key
Future<void> routerTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS hidden_chats (
      chat_id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      card TEXT NOT NULL,
      at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vault_meta (
      k TEXT PRIMARY KEY,
      v TEXT NOT NULL
    )
  ''');
  // uid and part stay readable so a copy is known without opening anything.
  // part is a slice's place in a file sent in slices
  await db.execute('''
    CREATE TABLE IF NOT EXISTS vault_inbox (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uid TEXT,
      part INTEGER,
      sealed BLOB NOT NULL,
      at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_vault_inbox_uid ON vault_inbox(uid)',
  );
}

// how to reach one person while the vault is shut
class RouterCard {
  const RouterCard(
    this.id,
    this.onion,
    this.xpub, {
    this.backPaired = false,
    this.blocked = false,
  });

  final String id;
  final String onion;
  final String xpub;
  final bool backPaired;
  final bool blocked;

  Map<String, Object> toJson() => {
    'h': id,
    'o': onion,
    'x': xpub,
    if (backPaired) 'bp': 1,
    if (blocked) 'bl': 1,
  };

  static RouterCard? fromJson(Object? j, {String? id}) {
    if (j is! Map) return null;
    final h = id ?? j['h'];
    if (h is! String || h.isEmpty) return null;
    final o = j['o'];
    final x = j['x'];
    return RouterCard(
      h,
      o is String ? o : '',
      x is String ? x : '',
      backPaired: j['bp'] == 1,
      blocked: j['bl'] == 1,
    );
  }
}

// a peer's card is theirs; a group's lists the members who are not
// everyday contacts
String peerCard(RouterCard c) => jsonEncode(c.toJson());
String groupCard(List<RouterCard> members) => jsonEncode({
  'm': [for (final c in members) c.toJson()],
});

// a move its list entry says is under way, for a start-up to put right.
// the files are folder/leaf names, and they belong in the vault's folders
class PendingMove {
  const PendingMove(this.chatId, this.group, this.files, {required this.hid});

  final String chatId;
  final bool group;
  final List<String> files;
  // a hide past its commit point: everyday rows of the chat go
  final bool hid;
}

// the flags a list entry carries while a move is under way: a hide past its
// commit, and an unhide before it
const _kHid = 'mv';
const _kBack = 'bk';

// a card as a hide's commit writes it: flagged with the files still to go
// into the vault's folders
String hidingCard(String card, List<String> files) {
  final j = jsonDecode(card);
  return jsonEncode({if (j is Map) ...j, _kHid: files});
}

// an arrival as it was sealed
class Unsealed {
  const Unsealed(this.from, this.wire, this.backPair, this.at, {this.wrapped});

  final String from;
  // the envelope as it was opened
  final String wire;
  // it came as a first contact
  final bool backPair;
  // when it arrived: a timer runs from here
  final int at;
  // when the sender wrapped it, by their clock, where the lane said
  final int? wrapped;
}

// the tables, behind a seam so the router runs on a stand-in
abstract class RouterStore {
  Future<List<Map<String, Object?>>> hidden();
  Future<void> putHidden(String chatId, String kind, String card, int at);
  Future<void> deleteHidden(String chatId);
  Future<String?> meta(String k);
  Future<void> putMeta(String k, String? v);
  Future<void> inboxAdd(String? uid, int? part, Uint8List sealed, int at);
  Future<bool> inboxHas(String uid, int? part);
  Future<int> inboxParts(String uid);
  Future<int> inboxCount();
  // every row's id and size, oldest first, without what it holds
  Future<List<(int, int)>> inboxSizes();
  // oldest first
  Future<List<Map<String, Object?>>> inboxOldest(int limit);
  Future<void> inboxDelete(int id);
  // everything sealed, when the vault it was sealed to goes
  Future<void> inboxClear();
}

// the list and a vault's own marks, written inside a transaction the caller
// holds, so a chat's rows and its entry move together. schema is the
// database's name on the connection: main, or an attached vault
class RouterRows {
  const RouterRows._();

  static Future<void> put(
    DatabaseExecutor t,
    String chatId,
    String kind,
    String card,
    int at,
  ) async {
    await t.rawInsert(
      'INSERT OR REPLACE INTO main.hidden_chats (chat_id, kind, card, at) '
      'VALUES (?, ?, ?, ?)',
      [chatId, kind, card, at],
    );
  }

  static Future<void> delete(DatabaseExecutor t, String chatId) async {
    await t.rawDelete('DELETE FROM main.hidden_chats WHERE chat_id = ?', [
      chatId,
    ]);
  }

  static Future<String?> meta(
    DatabaseExecutor t,
    String k, {
    String schema = 'main',
  }) async {
    final r = await t.rawQuery(
      'SELECT v FROM $schema.vault_meta WHERE k = ? LIMIT 1',
      [k],
    );
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  static Future<void> putMeta(
    DatabaseExecutor t,
    String k,
    String? v, {
    String schema = 'main',
  }) async {
    if (v == null) {
      await t.rawDelete('DELETE FROM $schema.vault_meta WHERE k = ?', [k]);
      return;
    }
    await t.rawInsert(
      'INSERT OR REPLACE INTO $schema.vault_meta (k, v) VALUES (?, ?)',
      [k, v],
    );
  }
}

class SqlRouterStore implements RouterStore {
  SqlRouterStore(this._open);

  final Future<Database> Function() _open;

  @override
  Future<List<Map<String, Object?>>> hidden() async =>
      (await _open()).query('hidden_chats');

  @override
  Future<void> putHidden(
    String chatId,
    String kind,
    String card,
    int at,
  ) async {
    await (await _open()).insert('hidden_chats', {
      'chat_id': chatId,
      'kind': kind,
      'card': card,
      'at': at,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteHidden(String chatId) async {
    await (await _open()).delete(
      'hidden_chats',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
  }

  @override
  Future<String?> meta(String k) async {
    final r = await (await _open()).query(
      'vault_meta',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [k],
      limit: 1,
    );
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  @override
  Future<void> putMeta(String k, String? v) async {
    final db = await _open();
    if (v == null) {
      await db.delete('vault_meta', where: 'k = ?', whereArgs: [k]);
      return;
    }
    await db.insert('vault_meta', {
      'k': k,
      'v': v,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> inboxAdd(
    String? uid,
    int? part,
    Uint8List sealed,
    int at,
  ) async {
    await (await _open()).insert('vault_inbox', {
      'uid': uid,
      'part': part,
      'sealed': sealed,
      'at': at,
    });
  }

  @override
  Future<bool> inboxHas(String uid, int? part) async {
    final r = await (await _open()).query(
      'vault_inbox',
      columns: ['id'],
      where: part == null ? 'uid = ? AND part IS NULL' : 'uid = ? AND part = ?',
      whereArgs: part == null ? [uid] : [uid, part],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  @override
  Future<int> inboxParts(String uid) async {
    final r = await (await _open()).rawQuery(
      'SELECT COUNT(DISTINCT part) c FROM vault_inbox '
      'WHERE uid = ? AND part IS NOT NULL',
      [uid],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<int> inboxCount() async {
    final r = await (await _open()).rawQuery(
      'SELECT COUNT(*) c FROM vault_inbox',
    );
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<List<(int, int)>> inboxSizes() async => [
    for (final r in await (await _open()).rawQuery(
      'SELECT id, length(sealed) n FROM vault_inbox ORDER BY id ASC',
    ))
      ((r['id'] as num).toInt(), (r['n'] as num? ?? 0).toInt()),
  ];

  @override
  Future<List<Map<String, Object?>>> inboxOldest(int limit) async =>
      (await _open()).query('vault_inbox', orderBy: 'id ASC', limit: limit);

  @override
  Future<void> inboxDelete(int id) async {
    await (await _open()).delete(
      'vault_inbox',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> inboxClear() async {
    await (await _open()).delete('vault_inbox');
  }
}

// the engine's sealing (engine/vault.go), behind a seam. base64 in and out.
// null where a seal failed or an item would not open
abstract class VaultSeal {
  String? seal(String pub, String b64);
  List<String?> openMany(String priv, List<String> b64s);
}

class VaultRouter {
  VaultRouter(
    this._store,
    this._sealer, {
    this.maxSealed = kMaxSealed,
    this.maxSealedBytes = kMaxSealedBytes,
  });

  final RouterStore _store;
  final VaultSeal _sealer;
  final int maxSealed;
  final int maxSealedBytes;

  // hidden people: their 1:1 frames go to the vault
  final Map<String, RouterCard> _peers = {};
  // hidden groups, with the members no everyday row holds
  final Map<String, List<RouterCard>> _groups = {};
  // those members, by id: what they send 1:1 goes to the vault too
  final Map<String, RouterCard> _members = {};
  // people and groups of a vault that went
  final Set<String> _gonePeople = {};
  final Set<String> _goneGroups = {};
  final List<PendingMove> _pending = [];
  String? _pub;
  bool _loaded = false;
  // rows may be waiting. while they do, a new arrival for the vault queues
  // behind them, so everything reaches the vault in the order it came
  bool _maybeSealed = false;
  int _sealGen = 0;

  bool get loaded => _loaded;
  bool get maybeSealed => _maybeSealed;

  // read whole before anything changes, so a route never sees half a list
  Future<void> load() async {
    final peers = <String, RouterCard>{};
    final groups = <String, List<RouterCard>>{};
    final gonePeople = <String>{};
    final goneGroups = <String>{};
    final pending = <PendingMove>[];
    for (final r in await _store.hidden()) {
      final id = r['chat_id'] as String;
      final card = _json(r['card']);
      if ((r['kind'] == kHiddenPeer || r['kind'] == kHiddenGroup) &&
          card is Map) {
        final hid = card[_kHid];
        final back = card[_kBack];
        final files = hid is List ? hid : back;
        if (files is List) {
          pending.add(
            PendingMove(id, r['kind'] == kHiddenGroup, [
              for (final f in files)
                if (f is String) f,
            ], hid: hid is List),
          );
        }
      }
      switch (r['kind']) {
        case kHiddenPeer:
          final c = RouterCard.fromJson(card, id: id);
          if (c != null) peers[id] = c;
        case kHiddenGroup:
          final m = card is Map ? card['m'] : null;
          groups[id] = [
            if (m is List)
              for (final x in m) ?RouterCard.fromJson(x),
          ];
        case kHiddenGone:
          if (card is Map && card['g'] == 1) {
            goneGroups.add(id);
          } else {
            gonePeople.add(id);
          }
      }
    }
    final pub = await _store.meta('pub');
    final waiting = await _store.inboxCount() > 0;
    _peers
      ..clear()
      ..addAll(peers);
    _groups
      ..clear()
      ..addAll(groups);
    _members.clear();
    for (final list in groups.values) {
      for (final c in list) {
        _members.putIfAbsent(c.id, () => c);
      }
    }
    _gonePeople
      ..clear()
      ..addAll(gonePeople);
    _goneGroups
      ..clear()
      ..addAll(goneGroups);
    _pending
      ..clear()
      ..addAll(pending);
    _pub = pub;
    _maybeSealed = _maybeSealed || waiting;
    _loaded = true;
  }

  static Object? _json(Object? s) {
    try {
      return jsonDecode(s as String? ?? '{}');
    } catch (_) {
      return const {};
    }
  }

  // moves a crash or a fault cut short, as the list says
  List<PendingMove> get pending => List.unmodifiable(_pending);

  // the chat is hidden: its vault holds it
  bool hides(String chatId) =>
      _peers.containsKey(chatId) || _groups.containsKey(chatId);

  // every hidden chat, with whether it is a group
  List<(String, bool)> get hiddenChats => [
    for (final id in _peers.keys) (id, false),
    for (final id in _groups.keys) (id, true),
  ];

  // a new vault's key, written before any chat is listed
  Future<void> start(String pub) async {
    await _store.putMeta('pub', pub);
    await load();
  }

  // an unhide is moving the chat's files out: until its commit, a start-up
  // puts them back
  Future<void> markBack(String chatId, List<String> files) =>
      _flag(chatId, _kBack, files);

  // a move done: the entry carries only what receiving needs
  Future<void> settle(String chatId) => _flag(chatId, null, null);

  Future<void> _flag(String chatId, String? key, List<String>? files) async {
    for (final r in await _store.hidden()) {
      if (r['chat_id'] != chatId) continue;
      final card = _json(r['card']);
      if (card is! Map) break;
      final next = {...card}
        ..remove(_kHid)
        ..remove(_kBack);
      if (key != null) next[key] = files;
      await _store.putHidden(
        chatId,
        r['kind'] as String,
        jsonEncode(next),
        r['at'] as int,
      );
      break;
    }
    await load();
  }

  // the cards of the chats a vault holds, read again from its rows: new
  // ones listed, changed ones rewritten. a move under way keeps its entry
  Future<void> recard(Map<String, (String, String)> cards) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final have = {
      for (final r in await _store.hidden()) r['chat_id'] as String: r,
    };
    for (final MapEntry(key: id, value: (kind, card)) in cards.entries) {
      final r = have[id];
      final old = r == null ? null : _json(r['card']);
      if (old is Map && (old.containsKey(_kHid) || old.containsKey(_kBack))) {
        continue;
      }
      if (r != null && r['kind'] == kind && r['card'] == card) continue;
      final at = r != null && r['kind'] == kind ? r['at'] as int : now;
      await _store.putHidden(id, kind, card, at);
    }
    // someone an older vault's drop list names who is in this vault's
    // groups now: what they send goes to this vault
    for (final (kind, card) in cards.values) {
      final m = kind == kHiddenGroup ? _json(card) : null;
      if (m is! Map || m['m'] is! List) continue;
      for (final x in m['m'] as List) {
        final id = RouterCard.fromJson(x)?.id;
        final r = have[id];
        if (r == null || r['kind'] != kHiddenGone) continue;
        final g = _json(r['card']);
        if (g is Map && g['g'] == 1) continue;
        await _store.deleteHidden(id!);
        have.remove(id);
      }
    }
    await load();
  }

  // the vault went, replaced or with the lock. everyone it held stays on
  // the list only so what they send is dropped, and its key and what came
  // sealed go
  Future<void> forget() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final people = <String>{};
    for (final r in await _store.hidden()) {
      final id = r['chat_id'] as String;
      switch (r['kind']) {
        case kHiddenPeer:
          people.add(id);
        case kHiddenGroup:
          final card = _json(r['card']);
          final m = card is Map ? card['m'] : null;
          if (m is List) {
            for (final x in m) {
              final c = RouterCard.fromJson(x);
              if (c != null) people.add(c.id);
            }
          }
          await _store.putHidden(id, kHiddenGone, jsonEncode({'g': 1}), now);
      }
    }
    for (final id in people) {
      await _store.putHidden(id, kHiddenGone, '{}', now);
    }
    await _store.putMeta('pub', null);
    await _store.inboxClear();
    _maybeSealed = false;
    await load();
  }

  // entries for chats no vault holds any more
  Future<void> unlist(Iterable<String> ids) async {
    for (final id in ids) {
      await _store.deleteHidden(id);
    }
    await load();
  }

  // the hidden chats came back and their pin went: nothing is hidden, and
  // the key and anything sealed go. an older vault's drop list stays
  Future<void> retire() async {
    await _store.putMeta('pub', null);
    await _store.inboxClear();
    _maybeSealed = false;
    await load();
  }

  // group frames go by the group, 1:1 frames by the sender. a hidden
  // contact writing in an everyday group lands in the everyday container.
  // open: the vault is open. held: whether the open vault holds a chat,
  // for one the list does not name yet
  RouteTo route(
    String sender,
    String? groupId, {
    bool open = false,
    bool Function(String chatId)? held,
  }) {
    assert(_loaded, 'the router routes once it has loaded');
    final g = groupId != null && groupId.isNotEmpty ? groupId : null;
    if (g != null ? _goneGroups.contains(g) : _gonePeople.contains(sender)) {
      return RouteTo.dropped;
    }
    final hidden = g != null
        ? _groups.containsKey(g)
        : _peers.containsKey(sender) || _members.containsKey(sender);
    if (hidden || (open && held != null && held(g ?? sender))) {
      return open && !_maybeSealed ? RouteTo.vault : RouteTo.sealed;
    }
    return RouteTo.everyday;
  }

  // everyone receiving has to be able to open a message from, the gone
  // included: theirs open, and go nowhere
  Set<String> get ids => {..._peers.keys, ..._members.keys, ..._gonePeople};

  // someone the everyday side must never file
  bool keeps(String id) =>
      _peers.containsKey(id) ||
      _members.containsKey(id) ||
      _gonePeople.contains(id);

  RouterCard? cardOf(String id) => _peers[id] ?? _members[id];

  // no tick for someone the vault blocked
  bool blocks(String id) => cardOf(id)?.blocked ?? false;

  // the keys to listen on, each to its person. no one the vault blocked
  Map<String, String> get listenFor => {
    for (final c in [..._members.values, ..._peers.values])
      if (c.xpub.isNotEmpty && !c.blocked) c.xpub: c.id,
  };

  // an arrival sealed to the vault. false when there is nothing to seal to,
  // or when it alone is past the cap
  Future<bool> seal(Unsealed a, {String? uid, int? part}) async {
    final pub = _pub;
    if (pub == null) return false;
    final plain = utf8.encode(
      jsonEncode({
        'f': a.from,
        'w': a.wire,
        'bp': a.backPair ? 1 : 0,
        'at': a.at,
        'a': ?a.wrapped,
      }),
    );
    final sealed = _sealer.seal(pub, base64Encode(plain));
    if (sealed == null) return false;
    await _store.inboxAdd(uid, part, base64Decode(sealed), a.at);
    _sealGen++;
    _maybeSealed = true;
    return _trim();
  }

  // what waits sealed held to the cap, the oldest going first. false when
  // the newest is past it on its own: it goes, and takes nothing with it
  Future<bool> _trim() async {
    final rows = await _store.inboxSizes();
    if (rows.isEmpty) return false;
    final (newest, size) = rows.last;
    if (size > maxSealedBytes) {
      await _store.inboxDelete(newest);
      return false;
    }
    var n = rows.length;
    var bytes = 0;
    for (final (_, size) in rows) {
      bytes += size;
    }
    for (final (id, size) in rows) {
      if (n <= maxSealed && bytes <= maxSealedBytes) break;
      await _store.inboxDelete(id);
      n--;
      bytes -= size;
    }
    return true;
  }

  Future<bool> sealedHas(String uid, int? part) => _store.inboxHas(uid, part);

  // how many slices of one file are sealed
  Future<int> sealedParts(String uid) => _store.inboxParts(uid);

  // the oldest sealed arrivals, opened. one that will not open comes back
  // null, so its row goes with the rest
  Future<List<(int, Unsealed?)>> openOldest(
    String priv, {
    int limit = 24,
  }) async {
    final gen = _sealGen;
    final rows = await _store.inboxOldest(limit);
    if (rows.isEmpty) {
      // nothing sealed since the look began: arrivals go straight in
      if (gen == _sealGen) _maybeSealed = false;
      return const [];
    }
    final opened = _sealer.openMany(priv, [
      for (final r in rows) base64Encode(r['sealed'] as List<int>),
    ]);
    // a short answer would read as rows that will not open, and they go
    if (opened.length != rows.length) throw StateError('vault open: count');
    return [
      for (final (i, r) in rows.indexed) (r['id'] as int, _unsealed(opened[i])),
    ];
  }

  static Unsealed? _unsealed(String? b64) {
    if (b64 == null) return null;
    try {
      final j = jsonDecode(utf8.decode(base64Decode(b64)));
      if (j is! Map) return null;
      final f = j['f'];
      final w = j['w'];
      final at = j['at'];
      if (f is! String || w is! String || at is! int) return null;
      final a = j['a'];
      return Unsealed(f, w, j['bp'] == 1, at, wrapped: a is int ? a : null);
    } catch (_) {
      return null;
    }
  }

  Future<void> forgetSealed(int id) => _store.inboxDelete(id);

  // the open vault's own half of its key pair, kept in the vault
  static Future<String?> sealKeyIn(RouterStore vault) => vault.meta('priv');
}

// a copy of the everyday database made to carry nothing of hidden chats: the
// list, the vault's key and what came sealed go, and everyone the list names
// leaves the signal store, so where the copy lands their messages never
// open. freed pages are zeroed. who the list named
Future<Set<String>> scrubHidden(Database db) async {
  final router = VaultRouter(SqlRouterStore(() async => db), const _NoSeal());
  await router.load();
  final people = router.ids;
  await db.rawQuery('PRAGMA secure_delete = 1');
  await db.transaction((t) async {
    await t.delete('hidden_chats');
    await t.delete('vault_meta');
    await t.delete('vault_inbox');
    final ids = people.toList();
    for (var i = 0; i < ids.length; i += 400) {
      final part = ids.sublist(i, i + 400 > ids.length ? ids.length : i + 400);
      final marks = List.filled(part.length, '?').join(', ');
      for (final table in const ['sessions', 'peer_identities']) {
        await t.delete(table, where: 'address IN ($marks)', whereArgs: part);
      }
    }
  });
  return people;
}

// a scrub reads the list and seals nothing
class _NoSeal implements VaultSeal {
  const _NoSeal();
  @override
  String? seal(String pub, String b64) => null;
  @override
  List<String?> openMany(String priv, List<String> b64s) => [
    for (final _ in b64s) null,
  ];
}
