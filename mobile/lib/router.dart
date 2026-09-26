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

// an arrival as it was sealed
class Unsealed {
  const Unsealed(this.from, this.wire, this.backPair, this.at);

  final String from;
  // the envelope as it was opened
  final String wire;
  // it came as a first contact
  final bool backPair;
  // when it arrived: a timer runs from here
  final int at;
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
  // oldest first
  Future<List<Map<String, Object?>>> inboxOldest(int limit);
  Future<void> inboxDelete(int id);
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
}

// the engine's sealing (engine/vault.go), behind a seam. base64 in and out.
// null where a seal failed or an item would not open
abstract class VaultSeal {
  String? seal(String pub, String b64);
  List<String?> openMany(String priv, List<String> b64s);
}

class VaultRouter {
  VaultRouter(this._store, this._sealer);

  final RouterStore _store;
  final VaultSeal _sealer;

  // hidden people: their 1:1 frames go to the vault
  final Map<String, RouterCard> _peers = {};
  // hidden groups, with the members no everyday row holds
  final Map<String, List<RouterCard>> _groups = {};
  // those members, by id: what they send 1:1 goes to the vault too
  final Map<String, RouterCard> _members = {};
  // people and groups of a vault that went
  final Set<String> _gonePeople = {};
  final Set<String> _goneGroups = {};
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
    for (final r in await _store.hidden()) {
      final id = r['chat_id'] as String;
      Object? card;
      try {
        card = jsonDecode(r['card'] as String? ?? '{}');
      } catch (_) {
        card = const {};
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
    _pub = pub;
    _maybeSealed = _maybeSealed || waiting;
    _loaded = true;
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

  // the keys to listen on, each to its person
  Map<String, String> get listenFor => {
    for (final c in [..._members.values, ..._peers.values])
      if (c.xpub.isNotEmpty) c.xpub: c.id,
  };

  // an arrival sealed to the vault. false when there is nothing to seal to
  Future<bool> seal(Unsealed a, {String? uid, int? part}) async {
    final pub = _pub;
    if (pub == null) return false;
    final plain = utf8.encode(
      jsonEncode({
        'f': a.from,
        'w': a.wire,
        'bp': a.backPair ? 1 : 0,
        'at': a.at,
      }),
    );
    final sealed = _sealer.seal(pub, base64Encode(plain));
    if (sealed == null) return false;
    await _store.inboxAdd(uid, part, base64Decode(sealed), a.at);
    _sealGen++;
    _maybeSealed = true;
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
      return Unsealed(f, w, j['bp'] == 1, at);
    } catch (_) {
      return null;
    }
  }

  Future<void> forgetSealed(int id) => _store.inboxDelete(id);

  // the open vault's own half of its key pair, kept in the vault
  static Future<String?> sealKeyIn(RouterStore vault) => vault.meta('priv');
}
