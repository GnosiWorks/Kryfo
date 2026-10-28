// SPDX-License-Identifier: GPL-3.0-or-later
// what the phone sends a newly linked device: every text, and the last 30
// days of photos, videos, voice notes and files unless they are skipped.
// read from the everyday database alone: hidden chats, the decoy and the
// chat with the developer never go, and no hidden contact's key, address or
// id is in any row that does
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../container.dart';
import '../router.dart' show hiddenNames;
import 'history_ffi.dart';

/// how far back files go with the text
const kHistoryMediaDays = 30;

/// the columns a chat or a message takes along. keys, sessions, wallpapers,
/// counters and anything naming a third person stay on the phone
const kHistoryContactCols = [
  'halo_id',
  'onion',
  'xpub',
  'first_seen',
  'last_seen',
  'back_paired',
  'nickname',
  'blocked',
  'muted',
  'archived',
  'verified',
  'verified_key',
  'note',
  'pinned',
  'key_changed',
  'accepted',
  'avatar',
  'voice_disguise',
  'shots_on',
  'shots_at',
  'shots_can',
  'shots_by',
  'shots_when',
  'opus_can',
  'caps',
  'caps_at',
];
const kHistoryGroupCols = [
  'group_id',
  'name',
  'description',
  'created_at',
  'is_admin',
  'admin_id',
  'creator_pub',
  'member_cap',
  'voice_disguise',
  'ended_at',
  'ended_by',
];
const kHistoryMessageCols = [
  'peer_id',
  'direction',
  'plaintext',
  'sent_at',
  'msg_uid',
  'reply_to',
  'group_id',
  'edited',
  'pinned',
  'pinned_at',
  'secure',
  'media_path',
  'file_path',
  'file_name',
  'voice_disguised',
  'saved',
  'sent',
  'delivered',
  'preview',
  'poll',
  'sticker',
  'written_at',
  'album_id',
  'album_n',
  'album_i',
];

/// a history stream only ever comes from the everyday container, alone
class HistoryNotHere implements Exception {
  const HistoryNotHere(this.why);
  final String why;
  @override
  String toString() => 'HistoryNotHere($why)';
}

/// a chat in the stream, by its number
class HistoryChatRef {
  const HistoryChatRef(this.group, this.id);
  final bool group;
  final String id;
}

/// a chat the device counted otherwise than the phone sent it
class HistoryChatGap {
  const HistoryChatGap(this.chat, this.want, this.got);
  final HistoryChatRef chat;
  final HistoryCount want;
  final HistoryCount got;
}

/// the planned stream on the phone
class HistoryOutgoing {
  HistoryOutgoing._(this._s, this.head, this.chats);
  final HistorySender _s;
  final HistoryHead head;
  final List<HistoryChatRef> chats;

  Uint8List record(int i) => _s.record(i);

  /// the device's tally: every chat it counted otherwise
  List<HistoryChatGap> checkTally(Uint8List tally) => [
    for (final g in _s.checkTally(tally))
      HistoryChatGap(chats[g.chat], g.want, g.got),
  ];

  void close() => _s.close();
}

Future<bool> _hasTable(DatabaseExecutor db, String t) async =>
    (await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      [t],
    )).isNotEmpty;

Future<Set<String>> _colsOf(DatabaseExecutor db, String t) async => {
  for (final r in await db.rawQuery('PRAGMA table_info($t)'))
    r['name'] as String,
};

bool _isDev(Object? id) => id is String && id.startsWith('dev:');

/// builds and signs the stream for a new device. [db] is the everyday
/// database, nothing attached; [mediaDir] its media folder; [sign] signs
/// the head's body with the identity under "history-counts"
Future<HistoryOutgoing> exportHistory({
  required Database db,
  required HaloContainer container,
  required String mediaDir,
  required String spool,
  required String keyHex,
  required String bindHex,
  required String identityHex,
  required Future<Uint8List> Function(Uint8List body) sign,
  bool skipMedia = false,
  DateTime? now,
  int chunk = 0,
}) async {
  if (container != HaloContainer.everyday) {
    throw const HistoryNotHere('container');
  }
  // a vault or a decoy attached to this connection would be readable here
  for (final r in await db.rawQuery('PRAGMA database_list')) {
    if (r['name'] != 'main' && r['name'] != 'temp') {
      throw const HistoryNotHere('attached');
    }
  }
  final hidden = await hiddenNames(db);
  final support = <String>{
    if (await _hasTable(db, 'support_chats'))
      for (final r in await db.rawQuery('SELECT halo_id FROM support_chats'))
        r['halo_id'] as String,
  };
  bool gone(Object? id) =>
      id is String &&
      (hidden.contains(id) || support.contains(id) || _isDev(id));
  // a field naming a hidden person is dropped from the row that goes
  Map<String, Object?> clean(Map<String, Object?> row) => {
    for (final e in row.entries)
      e.key: e.value is String && hidden.contains(e.value) ? null : e.value,
  };

  final ccols = await _colsOf(db, 'contacts');
  final gcols = await _colsOf(db, 'groups');
  final mcols = await _colsOf(db, 'messages');
  final contactCols = [
    for (final c in kHistoryContactCols)
      if (ccols.contains(c)) c,
  ];
  final groupCols = [
    for (final c in kHistoryGroupCols)
      if (gcols.contains(c)) c,
  ];
  final msgCols = [
    for (final c in kHistoryMessageCols)
      if (mcols.contains(c)) c,
  ];
  final since =
      (now ?? DateTime.now()).millisecondsSinceEpoch -
      kHistoryMediaDays * 86400000;
  final when = mcols.contains('written_at')
      ? 'COALESCE(written_at, sent_at)'
      : 'sent_at';

  // the chats, the one written in last first
  final last = <String, int>{};
  for (final r in await db.rawQuery(
    'SELECT peer_id AS k, MAX($when) AS t FROM messages '
    'WHERE group_id IS NULL GROUP BY peer_id',
  )) {
    last['p:${r['k']}'] = (r['t'] as num?)?.toInt() ?? 0;
  }
  for (final r in await db.rawQuery(
    'SELECT group_id AS k, MAX($when) AS t FROM messages '
    'WHERE group_id IS NOT NULL GROUP BY group_id',
  )) {
    last['g:${r['k']}'] = (r['t'] as num?)?.toInt() ?? 0;
  }
  final peers = [
    for (final r in await db.rawQuery(
      'SELECT ${contactCols.join(', ')} FROM contacts c '
      'WHERE ${ccols.contains('accepted') ? 'c.accepted = 1 OR ' : ''}'
      'EXISTS (SELECT 1 FROM messages m WHERE m.peer_id = c.halo_id '
      'AND m.group_id IS NULL)',
    ))
      if (!gone(r['halo_id'])) r,
  ];
  // burner rooms burn: they stay on the phone that holds them
  final rooms = [
    if (gcols.contains('room_priv')) 'room_priv IS NULL',
    if (gcols.contains('expires_at')) 'expires_at IS NULL',
  ];
  final groups = [
    for (final r in await db.rawQuery(
      'SELECT ${groupCols.join(', ')} FROM groups'
      '${rooms.isEmpty ? '' : ' WHERE ${rooms.join(' AND ')}'}',
    ))
      if (!gone(r['group_id'])) r,
  ];
  final order = [
    for (final r in peers) (false, r['halo_id'] as String, r),
    for (final r in groups) (true, r['group_id'] as String, r),
  ];
  int lastOf((bool, String, Map<String, Object?>) c) =>
      last['${c.$1 ? 'g' : 'p'}:${c.$2}'] ?? 0;
  order.sort((a, b) {
    final t = lastOf(b).compareTo(lastOf(a));
    if (t != 0) return t;
    if (a.$1 != b.$1) return a.$1 ? 1 : -1;
    return a.$2.compareTo(b.$2);
  });

  final s = HistorySender.open(
    keyHex: keyHex,
    bindHex: bindHex,
    identityHex: identityHex,
    spool: spool,
    root: mediaDir,
    skipMedia: skipMedia,
    chunk: chunk,
  );
  try {
    final chats = <HistoryChatRef>[];
    final media = <String>{};
    final hasReactions = await _hasTable(db, 'reactions');
    final hasVotes = await _hasTable(db, 'poll_votes');
    for (final (group, id, row) in order) {
      final meta = <String, Object?>{
        'kind': group ? 'group' : 'peer',
        'id': id,
        'row': clean(row),
      };
      if (group) {
        final members = [
          for (final m in await db.rawQuery(
            'SELECT halo_id, joined_at FROM group_members WHERE group_id = ?',
            [id],
          ))
            if (!gone(m['halo_id'])) m,
        ];
        meta['members'] = members;
        meta['people'] = [
          for (final c in await db.rawQuery(
            'SELECT halo_id, onion, xpub, first_seen FROM contacts '
            'WHERE halo_id IN (SELECT halo_id FROM group_members '
            'WHERE group_id = ?1 UNION SELECT peer_id FROM messages '
            'WHERE group_id = ?1) ORDER BY halo_id',
            [id],
          ))
            if (!gone(c['halo_id'])) c,
        ];
      }
      final n = s.chat(meta);
      chats.add(HistoryChatRef(group, id));
      var after = 0;
      while (true) {
        final page = await db.rawQuery(
          'SELECT id, ${msgCols.join(', ')}'
          '${mcols.contains('via_dev') ? ', via_dev' : ''}'
          '${mcols.contains('burn_at') ? ', burn_at' : ''}'
          '${mcols.contains('burn_secs') ? ', burn_secs' : ''}'
          '${mcols.contains('burn_unseen') ? ', burn_unseen' : ''} '
          'FROM messages WHERE '
          '${group ? 'group_id = ?' : 'peer_id = ? AND group_id IS NULL'} '
          'AND id > ? ORDER BY id LIMIT 500',
          [id, after],
        );
        if (page.isEmpty) break;
        after = page.last['id'] as int;
        final keep = [
          for (final m in page)
            // timed messages burn where they are; what came through the
            // developer's lane stays with it
            if (m['via_dev'] != 1 &&
                m['burn_at'] == null &&
                m['burn_secs'] == null &&
                (m['burn_unseen'] ?? 0) == 0 &&
                !gone(m['peer_id']))
              m,
        ];
        final uids = [
          for (final m in keep)
            if (m['msg_uid'] case final String u) u,
        ];
        final reactions = <String, List<Map<String, Object?>>>{};
        final votes = <String, List<Map<String, Object?>>>{};
        if (uids.isNotEmpty) {
          final marks = List.filled(uids.length, '?').join(', ');
          if (hasReactions) {
            for (final r in await db.rawQuery(
              'SELECT msg_uid, reactor, emoji, reacted_at FROM reactions '
              'WHERE msg_uid IN ($marks)',
              uids,
            )) {
              if (gone(r['reactor'])) continue;
              (reactions[r['msg_uid'] as String] ??= []).add({
                'reactor': r['reactor'],
                'emoji': r['emoji'],
                'reacted_at': r['reacted_at'],
              });
            }
          }
          if (hasVotes) {
            for (final r in await db.rawQuery(
              'SELECT poll_uid, voter, group_id, choices, seq, at '
              'FROM poll_votes WHERE poll_uid IN ($marks)',
              uids,
            )) {
              if (gone(r['voter'])) continue;
              (votes[r['poll_uid'] as String] ??= []).add({
                'voter': r['voter'],
                'group_id': r['group_id'],
                'choices': r['choices'],
                'seq': r['seq'],
                'at': r['at'],
              });
            }
          }
        }
        for (final m in keep) {
          final row = <String, Object?>{for (final c in msgCols) c: m[c]};
          final at = (m['written_at'] as num? ?? m['sent_at'] as num? ?? 0)
              .toInt();
          for (final col in const ['media_path', 'file_path']) {
            final path = row[col];
            if (path is! String || path.isEmpty) continue;
            // only a file of this container's own folder, by its name there
            if (!p.isWithin(mediaDir, path)) {
              row[col] = null;
              continue;
            }
            final rel = p.posix.joinAll(
              p.split(p.relative(path, from: mediaDir)),
            );
            row[col] = rel;
            if (!skipMedia && at >= since && media.add(rel)) {
              s.media(n, at, rel);
            }
          }
          final uid = m['msg_uid'];
          if (uid is String) {
            if (reactions[uid] case final r?) row['x_reactions'] = r;
            if (votes[uid] case final v?) row['x_votes'] = v;
          }
          s.message(clean(row));
        }
      }
    }
    final body = await s.plan();
    s.signed(await sign(body));
    return HistoryOutgoing._(s, s.head(), chats);
  } catch (_) {
    s.close();
    rethrow;
  }
}
