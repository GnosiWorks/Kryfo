// SPDX-License-Identifier: GPL-3.0-or-later
// the vault's life: made, filled with chats moved out of the everyday
// database, emptied back into it, gone. a move commits with its list entry,
// in the everyday transaction that moves the rows, so the everyday side
// always matches. the vault's side of a move cut short is put right when it
// next opens

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'container.dart';
import 'lock_state.dart' show LockState, lockState;
import 'main.dart' show HaloDb, engine, shredFile;
import 'notifications.dart'
    show cancelWithRetry, clearNotificationsFor, notifPlugin;
import 'router.dart';
import 'search.dart' show searchBody;

// a chat as a move sees it: a person's, or a group's
class ChatRef {
  const ChatRef(this.id, {this.group = false});

  final String id;
  final bool group;

  @override
  bool operator ==(Object other) =>
      other is ChatRef && other.id == id && other.group == group;

  @override
  int get hashCode => Object.hash(id, group);

  @override
  String toString() => '${group ? 'g' : 'p'}:$id';
}

// moves under way, kept in the vault for its next open to finish or undo
class MoveMarks {
  const MoveMarks([this.inbound = const {}, this.outbound = const {}]);

  final Set<ChatRef> inbound;
  final Set<ChatRef> outbound;

  bool get isEmpty => inbound.isEmpty && outbound.isEmpty;

  MoveMarks hiding(ChatRef c) => MoveMarks({...inbound, c}, outbound);
  MoveMarks showing(ChatRef c) => MoveMarks(inbound, {...outbound, c});
  MoveMarks done(ChatRef c) =>
      MoveMarks({...inbound}..remove(c), {...outbound}..remove(c));

  String? encode() => isEmpty
      ? null
      : jsonEncode({
          'in': [for (final c in inbound) '$c'],
          'out': [for (final c in outbound) '$c'],
        });

  static MoveMarks decode(String? s) {
    if (s == null) return const MoveMarks();
    ChatRef? ref(Object? x) {
      if (x is! String || x.length < 3 || x[1] != ':') return null;
      return ChatRef(x.substring(2), group: x[0] == 'g');
    }

    try {
      final j = jsonDecode(s);
      if (j is! Map) return const MoveMarks();
      Set<ChatRef> refs(Object? l) => {
        if (l is List)
          for (final x in l) ?ref(x),
      };
      return MoveMarks(refs(j['in']), refs(j['out']));
    } catch (_) {
      return const MoveMarks();
    }
  }
}

// the rows of chats, between the database a vault extends (the everyday one
// or the decoy's) and the vault attached to it. each step that writes is one
// transaction
abstract class ChatMover {
  Future<void> attach();
  Future<void> detach();

  Future<MoveMarks> marks();
  Future<void> putMarks(MoveMarks m);

  // the side it extends holds it as a chat that may be hidden: an accepted
  // contact, or a group that is not a room. and the vault does not
  Future<bool> hideable(ChatRef c);
  // the vault holds it as a chat: a group, or a person it holds more than
  // the key of
  Future<bool> held(ChatRef c);
  // who a chat reaches: its person, or a group's members and senders
  Future<Set<String>> peopleIn(ChatRef c, {required bool inVault});

  // a hide before its commit: the chat's rows into the vault, with their
  // search words and paths in the vault's folders, and the marks
  Future<void> copyIn(ChatRef c, MoveMarks marks);
  // a hide's commit: its list entry, flagged with the files still to move,
  // and the chat out of the everyday database. the files
  Future<List<String>> commitIn(ChatRef c, int at);
  // the files the vault's rows of a chat point at
  Future<List<String>> vaultFiles(ChatRef c);
  // an unhide's commit: the chat's rows back in the side it extends with
  // their search words, and its list entry out where there is one
  Future<void> commitOut(ChatRef c);
  // the chat out of the vault, and the marks
  Future<void> dropVault(ChatRef c, MoveMarks marks);
  // the chat out of the side it extends. for the decoy's vault, which has
  // no list, this is a hide's commit
  Future<void> dropLive(ChatRef c);
  // every chat the vault holds, as its list kind and card
  Future<Map<String, (String, String)>> vaultCards();
}

// the pin entry, a new vault's file, the shade and the disk, behind a seam
// so the vault's life runs on stand-ins. vault is the everyday identity's
// or the decoy's
abstract class VaultHost {
  // a pin can open a vault only with the app lock on
  bool get lockOn;
  // the vault's pin entry, its key sealed inside. false when the pin is in
  // use
  Future<bool> putEntry(HaloContainer vault, String pin, String keyHex);
  Future<void> clearEntry(HaloContainer vault);
  // a new vault under the key: the whole schema, and for the everyday one
  // its sealing identity inside. the public half, '' when nothing is ever
  // sealed to it
  Future<String> makeVault(HaloContainer vault, String keyHex);
  // the vault under the key its pin handed back, open. throws when there is
  // none or the key does not open it
  Future<HaloDb> openVault(HaloContainer vault, String keyHex);
  ChatMover mover(HaloDb primary, HaloDb? vault);
  // the notifications of chats that just went out of sight
  Future<void> clearShade(Iterable<String> payloads);
  Future<void> moveFile(String from, String to);
  Future<void> shred(String path);
  // the vault's files: its database and folders
  Future<void> wipeVault(HaloContainer vault);
}

class LiveVaultHost implements VaultHost {
  const LiveVaultHost({LockState? lock}) : _lock = lock;

  final LockState? _lock;
  LockState get _l => _lock ?? lockState;

  @override
  bool get lockOn => _l.enabled;

  // the lock works on the entry of the session's own identity: another
  // identity's vault is never written from here
  void _own(HaloContainer vault) {
    final own = _l.inDecoy ? HaloContainer.decoyVault : HaloContainer.vault;
    if (vault != own) throw StateError('not this session\'s vault');
  }

  @override
  Future<bool> putEntry(HaloContainer vault, String pin, String keyHex) {
    _own(vault);
    return _l.setupVaultPin(pin, keyHex);
  }

  @override
  Future<void> clearEntry(HaloContainer vault) {
    _own(vault);
    return _l.clearVault();
  }

  @override
  Future<String> makeVault(HaloContainer vault, String keyHex) async {
    // nothing arrives for the decoy, so nothing is ever sealed to its vault
    final keys = vault == HaloContainer.vault ? engine.vaultKeys() : null;
    final d = HaloDb.withKey(vault, keyHex);
    try {
      await d.open();
      if (keys != null) {
        await SqlRouterStore(d.open).putMeta('priv', keys.priv);
      }
    } finally {
      await d.close();
    }
    return keys?.pub ?? '';
  }

  @override
  Future<HaloDb> openVault(HaloContainer vault, String keyHex) async {
    // opening a file that is not there would make one
    if (!await File(await vault.dbPath()).exists()) {
      throw StateError('no vault here');
    }
    final d = HaloDb.withKey(vault, keyHex);
    try {
      await d.open();
    } catch (_) {
      await d.close();
      rethrow;
    }
    return d;
  }

  @override
  ChatMover mover(HaloDb primary, HaloDb? vault) =>
      SqlChatMover(primary, vault);

  @override
  Future<void> clearShade(Iterable<String> payloads) async {
    for (final p in payloads) {
      await clearNotificationsFor(p);
    }
    // what the receiving job showed cannot be told apart by chat here
    await cancelWithRetry(notifPlugin.cancelAll, 'hidden shade');
  }

  @override
  Future<void> moveFile(String from, String to) async {
    await Directory(p.dirname(to)).create(recursive: true);
    try {
      await File(from).rename(to);
    } on FileSystemException {
      // another file system: a copy, and the original shredded
      await File(from).copy(to);
      await shredFile(from);
    }
  }

  @override
  Future<void> shred(String path) => shredFile(path);

  @override
  Future<void> wipeVault(HaloContainer vault) => vault.wipeFiles();
}

// 32 bytes from the platform's csprng, as the 64 hex a wrapped key is
String newVaultKey() {
  final rnd = Random.secure();
  return [
    for (var i = 0; i < 32; i++)
      rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

// a chat's file by folder and leaf, 'media/x.jpg', under a container's
// folders. null for a name that would lead out of them
Future<String?> chatFilePath(String name, HaloContainer c) async {
  final cut = name.indexOf('/');
  if (cut <= 0) return null;
  final folder = name.substring(0, cut);
  final rest = name.substring(cut + 1);
  if (folder != 'media' && folder != 'wallpapers') return null;
  if (rest.isEmpty || p.isAbsolute(rest) || p.split(rest).contains('..')) {
    return null;
  }
  final docs = (await getApplicationDocumentsDirectory()).path;
  return p.join(docs, '$folder${c.suffix}', rest);
}

// where a chat's rows are beyond its person or group and its messages,
// table by table. {s} is the database read, {uids} its messages' uids.
// media_chunks goes before media_wants, which it is found through
const _peerRows = {
  'reactions': 'msg_uid IN {uids}',
  'poll_votes': 'poll_uid IN {uids}',
  'pins_out': 'msg_uid IN {uids}',
  'edits_out': 'msg_uid IN {uids}',
  // an unsend's message is gone, so these go by the person
  'frames_out': 'peer_id = ?1',
  'media_chunks':
      'media_id IN (SELECT media_id FROM {s}.media_wants WHERE peer_id = ?1)',
  'media_wants': 'peer_id = ?1',
  'held_onion': 'peer_id = ?1',
  'shield': 'halo_id = ?1',
  'vouches': 'halo_id = ?1 OR voucher_id = ?1',
};
const _groupRows = {
  'group_members': 'group_id = ?1',
  'reactions': 'msg_uid IN {uids}',
  'poll_votes': 'poll_uid IN {uids}',
  'pins_out': 'msg_uid IN {uids}',
  'edits_out': 'msg_uid IN {uids}',
};

// every table a chat's rows sit in. msg_fts and polls_gone follow its
// messages. the rest are the phone's or the identity's, and stay
Set<String> get chatTables => {
  'contacts',
  'groups',
  'messages',
  'msg_fts',
  'polls_gone',
  ..._peerRows.keys,
  ..._groupRows.keys,
};

const _kMoves = 'moves';

// a container's folders as its rows name them
class _Folders {
  _Folders(String docs, String suffix)
    : media = '${p.join(docs, 'media$suffix')}/',
      wallpapers = 'image:${p.join(docs, 'wallpapers$suffix')}/';

  final String media;
  // as an atmosphere names its picture
  final String wallpapers;
}

class SqlChatMover implements ChatMover {
  SqlChatMover(this._live, this._vault);

  final HaloDb _live;
  final HaloDb? _vault;
  late Database _db;
  late _Folders _liveAt;
  late _Folders _vaultAt;
  Object? _secure;
  var _attached = false;
  final _colsOf = <String, List<String>>{};

  @override
  Future<void> attach() async {
    _db = await _live.open();
    final docs = (await getApplicationDocumentsDirectory()).path;
    _liveAt = _Folders(docs, _live.container.suffix);
    final v = _vault;
    _vaultAt = _Folders(docs, (v?.container ?? HaloContainer.vault).suffix);
    // freed pages are zeroed: a moved chat does not linger in the file it
    // left
    final was = await _db.rawQuery('PRAGMA main.secure_delete');
    _secure = was.isEmpty ? null : was.first.values.first;
    await _db.rawQuery('PRAGMA main.secure_delete = 1');
    if (v == null) return;
    try {
      await v.attachTo(_db, 'v');
      _attached = true;
      await _db.rawQuery('PRAGMA v.secure_delete = 1');
    } catch (_) {
      await detach();
      rethrow;
    }
  }

  @override
  Future<void> detach() async {
    try {
      if (_attached) await _db.execute('DETACH DATABASE v');
      _attached = false;
    } finally {
      await _db.rawQuery('PRAGMA main.secure_delete = ${_secure == 1 ? 1 : 0}');
    }
  }

  static String _lit(String s) => "'${s.replaceAll("'", "''")}'";

  // a path under one folder, moved under the other
  static String _moved(String col, String from, String to) {
    final n = from.runes.length;
    return 'CASE WHEN substr($col, 1, $n) = ${_lit(from)} '
        'THEN ${_lit(to)} || substr($col, ${n + 1}) ELSE $col END';
  }

  static String _chatMsgs(ChatRef c) =>
      c.group ? 'group_id = ?1' : 'peer_id = ?1 AND group_id IS NULL';

  static String _fill(String where, ChatRef c, String s) => where
      .replaceAll(
        '{uids}',
        '(SELECT msg_uid FROM $s.messages WHERE ${_chatMsgs(c)} '
            'AND msg_uid IS NOT NULL)',
      )
      .replaceAll('{s}', s);

  static String _peopleOf(String s) =>
      'SELECT halo_id AS h FROM $s.group_members WHERE group_id = ?1 '
      'UNION SELECT peer_id FROM $s.messages WHERE group_id = ?1';

  Future<List<String>> _cols(
    DatabaseExecutor t,
    String schema,
    String table,
  ) async {
    final k = '$schema.$table';
    final have = _colsOf[k];
    if (have != null) return have;
    final r = await t.rawQuery('PRAGMA $schema.table_info($table)');
    return _colsOf[k] = [for (final c in r) c['name'] as String];
  }

  // the columns both have, in the target's order: an attached vault has
  // not been through a migration
  Future<List<String>> _shared(
    DatabaseExecutor t,
    String src,
    String dst,
    String table, {
    Set<String> skip = const {},
  }) async {
    final from = (await _cols(t, src, table)).toSet();
    return [
      for (final c in await _cols(t, dst, table))
        if (from.contains(c) && !skip.contains(c)) c,
    ];
  }

  Future<void> _put(
    Transaction t,
    String table,
    String where,
    ChatRef c,
    String src,
    String dst,
    _Folders from,
    _Folders to,
  ) async {
    // its own counter: the rows get new ids
    final cols = await _shared(
      t,
      src,
      dst,
      table,
      skip: table == 'held_onion' ? const {'id'} : const {},
    );
    final pick = [
      for (final col in cols)
        col == 'atmosphere' ? _moved(col, from.wallpapers, to.wallpapers) : col,
    ];
    await t.execute(
      'INSERT OR REPLACE INTO $dst.$table (${cols.join(', ')}) '
      'SELECT ${pick.join(', ')} FROM $src.$table '
      'WHERE ${_fill(where, c, src)}',
      [c.id],
    );
  }

  // a chat's rows from one database into the other, its messages as new
  // rows with their search words, paths moved to the other's folders
  Future<void> _copy(
    Transaction t,
    ChatRef c,
    String src,
    String dst,
    _Folders from,
    _Folders to,
  ) async {
    if (c.group) {
      await _put(t, 'groups', 'group_id = ?1', c, src, dst, from, to);
      // members and senders, as keys only where the other side lacks them
      await t.execute(
        'INSERT OR IGNORE INTO $dst.contacts (halo_id, onion, xpub, '
        'first_seen, last_seen, back_paired, blocked, accepted) '
        'SELECT halo_id, onion, xpub, first_seen, first_seen, back_paired, '
        'blocked, 0 FROM $src.contacts WHERE halo_id IN (${_peopleOf(src)})',
        [c.id],
      );
    } else {
      // a full row takes the place of a key-only one, never of a full one
      await _put(
        t,
        'contacts',
        'halo_id = ?1 AND NOT EXISTS (SELECT 1 FROM $dst.contacts x '
            'WHERE x.halo_id = ?1 AND x.accepted = 1)',
        c,
        src,
        dst,
        from,
        to,
      );
    }
    final top =
        Sqflite.firstIntValue(
          await t.rawQuery('SELECT IFNULL(MAX(id), 0) FROM $dst.messages'),
        ) ??
        0;
    final cols = await _shared(t, src, dst, 'messages', skip: const {'id'});
    final pick = [
      for (final col in cols)
        col == 'media_path' || col == 'file_path'
            ? _moved('m.$col', from.media, to.media)
            : 'm.$col',
    ];
    // oldest first, so the new ids keep the order they came in
    await t.execute(
      'INSERT INTO $dst.messages (${cols.join(', ')}) '
      'SELECT ${pick.join(', ')} FROM $src.messages m '
      'WHERE ${_chatMsgs(c)} AND (m.msg_uid IS NULL OR NOT EXISTS '
      '(SELECT 1 FROM $dst.messages x WHERE x.msg_uid = m.msg_uid)) '
      'ORDER BY m.id',
      [c.id],
    );
    for (final e in (c.group ? _groupRows : _peerRows).entries) {
      await _put(t, e.key, e.value, c, src, dst, from, to);
    }
    await _index(t, dst, top);
  }

  // search words for the rows a copy just made
  Future<void> _index(Transaction t, String s, int after) async {
    var at = after;
    while (true) {
      final rows = await t.rawQuery(
        'SELECT id, plaintext, poll, file_name, preview, sticker '
        'FROM $s.messages WHERE id > ? ORDER BY id LIMIT 300',
        [at],
      );
      if (rows.isEmpty) return;
      final b = t.batch();
      for (final r in rows) {
        final body = searchBody(r);
        if (body.trim().isEmpty) continue;
        b.rawInsert('INSERT INTO $s.msg_fts (rowid, body) VALUES (?, ?)', [
          r['id'],
          body,
        ]);
      }
      await b.commit(noResult: true);
      at = rows.last['id'] as int;
    }
  }

  // a chat's rows out of one database. someone a group there still names
  // keeps a key-only row, as any member you have not added. someone
  // nothing there names any more goes
  Future<void> _drop(Transaction t, ChatRef c, String s) async {
    final people = c.group
        ? {
            for (final r in await t.rawQuery(_peopleOf(s), [c.id]))
              r['h'] as String,
          }
        : {c.id};
    final polls = [
      for (final r in await t.rawQuery(
        'SELECT msg_uid FROM $s.messages WHERE ${_chatMsgs(c)} '
        'AND poll IS NOT NULL AND msg_uid IS NOT NULL',
        [c.id],
      ))
        r['msg_uid'] as String,
    ];
    for (final e in (c.group ? _groupRows : _peerRows).entries) {
      await t.execute('DELETE FROM $s.${e.key} WHERE ${_fill(e.value, c, s)}', [
        c.id,
      ]);
    }
    await t.execute('DELETE FROM $s.messages WHERE ${_chatMsgs(c)}', [c.id]);
    // the delete marked its polls as just gone: nothing of them stays
    for (var i = 0; i < polls.length; i += 400) {
      final part = polls.sublist(i, min(i + 400, polls.length));
      await t.execute(
        'DELETE FROM $s.polls_gone WHERE uid IN '
        '(${List.filled(part.length, '?').join(', ')})',
        part,
      );
    }
    if (c.group) {
      await t.execute('DELETE FROM $s.groups WHERE group_id = ?1', [c.id]);
      for (final who in people) {
        if (!await _unheld(t, s, who)) continue;
        await t.execute('DELETE FROM $s.contacts WHERE halo_id = ?1', [who]);
        await t.execute('DELETE FROM $s.shield WHERE halo_id = ?1', [who]);
      }
      return;
    }
    final row = await t.rawQuery(
      'SELECT onion, xpub, first_seen, back_paired, blocked '
      'FROM $s.contacts WHERE halo_id = ?1',
      [c.id],
    );
    await t.execute('DELETE FROM $s.contacts WHERE halo_id = ?1', [c.id]);
    if (row.isEmpty || !await _named(t, s, c.id)) return;
    final r = row.first;
    await t.execute(
      'INSERT INTO $s.contacts (halo_id, onion, xpub, first_seen, '
      'last_seen, back_paired, blocked, accepted) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, 0)',
      [
        c.id,
        r['onion'],
        r['xpub'],
        r['first_seen'],
        r['first_seen'],
        r['back_paired'],
        r['blocked'],
      ],
    );
  }

  // a group there names them, as a member or a sender
  Future<bool> _named(DatabaseExecutor t, String s, String who) async {
    final r = await t.rawQuery(
      'SELECT 1 FROM $s.group_members WHERE halo_id = ?1 UNION ALL '
      'SELECT 1 FROM $s.messages WHERE peer_id = ?1 AND group_id IS NOT NULL '
      'LIMIT 1',
      [who],
    );
    return r.isNotEmpty;
  }

  // a key-only row nothing there needs any more
  Future<bool> _unheld(DatabaseExecutor t, String s, String who) async {
    final r = await t.rawQuery(
      'SELECT 1 FROM $s.contacts WHERE halo_id = ?1 AND accepted = 0 '
      'AND NOT EXISTS (SELECT 1 FROM $s.group_members WHERE halo_id = ?1) '
      'AND NOT EXISTS (SELECT 1 FROM $s.messages WHERE peer_id = ?1) '
      'AND NOT EXISTS (SELECT 1 FROM $s.held_onion WHERE peer_id = ?1) '
      'AND NOT EXISTS (SELECT 1 FROM $s.media_wants WHERE peer_id = ?1) '
      'AND NOT EXISTS (SELECT 1 FROM $s.vouches '
      'WHERE halo_id = ?1 OR voucher_id = ?1)',
      [who],
    );
    return r.isNotEmpty;
  }

  // the files a chat's rows point at, by folder and leaf
  Future<List<String>> _files(
    DatabaseExecutor t,
    ChatRef c,
    String s,
    _Folders at,
  ) async {
    final out = <String>[];
    void take(Object? path, String prefix, String folder) {
      if (path is! String || !path.startsWith(prefix)) return;
      final rest = path.substring(prefix.length);
      if (rest.isNotEmpty) out.add('$folder/$rest');
    }

    for (final r in await t.rawQuery(
      'SELECT media_path, file_path FROM $s.messages WHERE ${_chatMsgs(c)}',
      [c.id],
    )) {
      take(r['media_path'], at.media, 'media');
      take(r['file_path'], at.media, 'media');
    }
    for (final r in await t.rawQuery(
      c.group
          ? 'SELECT atmosphere FROM $s.groups WHERE group_id = ?1'
          : 'SELECT atmosphere FROM $s.contacts WHERE halo_id = ?1',
      [c.id],
    )) {
      take(r['atmosphere'], at.wallpapers, 'wallpapers');
    }
    return out;
  }

  // what receiving needs of a hidden chat, from the vault's rows: its
  // person, or a group's members no everyday row holds
  Future<String?> _card(DatabaseExecutor t, ChatRef c) async {
    RouterCard card(Map<String, Object?> r) => RouterCard(
      r['halo_id'] as String,
      r['onion'] as String? ?? '',
      r['xpub'] as String? ?? '',
      backPaired: r['back_paired'] == 1,
      blocked: r['blocked'] == 1,
    );
    if (!c.group) {
      final r = await t.rawQuery(
        'SELECT halo_id, onion, xpub, back_paired, blocked '
        'FROM v.contacts WHERE halo_id = ?1',
        [c.id],
      );
      return r.isEmpty ? null : peerCard(card(r.first));
    }
    final r = await t.rawQuery(
      'SELECT c.halo_id, c.onion, c.xpub, c.back_paired, c.blocked '
      'FROM v.group_members gm JOIN v.contacts c ON c.halo_id = gm.halo_id '
      'WHERE gm.group_id = ?1 AND NOT EXISTS '
      '(SELECT 1 FROM main.contacts x WHERE x.halo_id = gm.halo_id) '
      'ORDER BY c.halo_id',
      [c.id],
    );
    return groupCard([for (final x in r) card(x)]);
  }

  @override
  Future<MoveMarks> marks() async =>
      MoveMarks.decode(await RouterRows.meta(_db, _kMoves, schema: 'v'));

  @override
  Future<void> putMarks(MoveMarks m) =>
      RouterRows.putMeta(_db, _kMoves, m.encode(), schema: 'v');

  @override
  Future<bool> hideable(ChatRef c) async {
    final r = await _db.rawQuery(
      c.group
          ? 'SELECT 1 FROM main.groups WHERE group_id = ?1 '
                'AND room_pub IS NULL'
          : 'SELECT 1 FROM main.contacts WHERE halo_id = ?1 AND accepted = 1',
      [c.id],
    );
    return r.isNotEmpty && !await held(c);
  }

  @override
  Future<bool> held(ChatRef c) async {
    final r = await _db.rawQuery(
      c.group
          ? 'SELECT 1 FROM v.groups WHERE group_id = ?1'
          : 'SELECT 1 FROM v.contacts WHERE halo_id = ?1 AND accepted = 1 '
                'UNION ALL SELECT 1 FROM v.messages WHERE peer_id = ?1 '
                'AND group_id IS NULL LIMIT 1',
      [c.id],
    );
    return r.isNotEmpty;
  }

  @override
  Future<Set<String>> peopleIn(ChatRef c, {required bool inVault}) async {
    if (!c.group) return {c.id};
    return {
      for (final r in await _db.rawQuery(_peopleOf(inVault ? 'v' : 'main'), [
        c.id,
      ]))
        r['h'] as String,
    };
  }

  @override
  Future<void> copyIn(ChatRef c, MoveMarks marks) => _db.transaction((t) async {
    await _copy(t, c, 'main', 'v', _liveAt, _vaultAt);
    await RouterRows.putMeta(t, _kMoves, marks.encode(), schema: 'v');
  });

  @override
  Future<List<String>> commitIn(ChatRef c, int at) =>
      _db.transaction((t) async {
        final files = await _files(t, c, 'main', _liveAt);
        await _drop(t, c, 'main');
        final card = await _card(t, c);
        if (card == null) throw StateError('hide: the vault has no row');
        await RouterRows.put(
          t,
          c.id,
          c.group ? kHiddenGroup : kHiddenPeer,
          hidingCard(card, files),
          at,
        );
        return files;
      });

  @override
  Future<List<String>> vaultFiles(ChatRef c) => _files(_db, c, 'v', _vaultAt);

  @override
  Future<void> commitOut(ChatRef c) => _db.transaction((t) async {
    await _copy(t, c, 'v', 'main', _vaultAt, _liveAt);
    await RouterRows.delete(t, c.id);
  });

  @override
  Future<void> dropVault(ChatRef c, MoveMarks marks) =>
      _db.transaction((t) async {
        await _drop(t, c, 'v');
        await RouterRows.putMeta(t, _kMoves, marks.encode(), schema: 'v');
      });

  @override
  Future<void> dropLive(ChatRef c) =>
      _db.transaction((t) => _drop(t, c, 'main'));

  @override
  Future<Map<String, (String, String)>> vaultCards() async {
    final chats = [
      for (final r in await _db.rawQuery(
        'SELECT c.halo_id FROM v.contacts c WHERE c.accepted = 1 OR EXISTS '
        '(SELECT 1 FROM v.messages m WHERE m.peer_id = c.halo_id '
        'AND m.group_id IS NULL)',
      ))
        ChatRef(r['halo_id'] as String),
      for (final r in await _db.rawQuery('SELECT group_id FROM v.groups'))
        ChatRef(r['group_id'] as String, group: true),
    ];
    return {
      for (final c in chats)
        if (await _card(_db, c) case final card?)
          c.id: (c.group ? kHiddenGroup : kHiddenPeer, card),
    };
  }
}
