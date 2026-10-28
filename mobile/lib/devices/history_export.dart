// SPDX-License-Identifier: GPL-3.0-or-later
// what the phone sends a newly linked device: every text and voice note,
// and the last 30 days of photos, videos and files unless they are skipped.
// read from the everyday database alone, every everyday chat as this phone
// holds it. hidden chats (whole, by id), the decoy, the chat with the
// developer, burner rooms, timed messages and chats with screenshots
// blocked stay here
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../container.dart';
import '../router.dart' show hiddenChatIds;
import '../voice_format.dart' show isVoiceName;
import 'history_ffi.dart';

/// how far back files go with the text
const kHistoryMediaDays = 30;

/// the spools' names, in the folder the caller gives: the app's private
/// no-backup folder. each sender has its own
const kHistorySpoolPrefix = 'history-';
const kHistorySpoolSuffix = '.spool';

/// the biggest voice note that still goes when files are skipped
const kHistoryVoiceMax = 10 << 20;

/// why a chat came only as its row
const kHistoryStaysShots = 'shots';

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

/// a chat the phone left rows or files of out: too big, unreadable, a name
/// that cannot be one, a file outside its media folder
class HistoryChatLeft {
  const HistoryChatLeft(this.chat, this.rows, this.files);
  final HistoryChatRef chat;
  final int rows;
  final int files;
}

List<HistoryChatLeft> historyLeftOf(
  HistoryHead head,
  List<HistoryChatRef> chats,
) => [
  for (var i = 0; i < head.chats.length && i < chats.length; i++)
    if (head.chats[i].leftRows > 0 || head.chats[i].leftFiles > 0)
      HistoryChatLeft(
        chats[i],
        head.chats[i].leftRows,
        head.chats[i].leftFiles,
      ),
];

/// the planned stream on the phone
class HistoryOutgoing {
  HistoryOutgoing._(this._s, this.id, this.head, this.chats);
  final HistorySender _s;

  /// the stream id the device needs with the first record, as hex
  final String id;
  final HistoryHead head;
  final List<HistoryChatRef> chats;

  /// what the phone could not send, chat by chat, and whole chats
  List<HistoryChatLeft> get left => historyLeftOf(head, chats);
  int get leftChats => head.leftChats;

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
      "SELECT 1 FROM main.sqlite_master WHERE type = 'table' AND name = ?",
      [t],
    )).isNotEmpty;

Future<Set<String>> _colsOf(DatabaseExecutor db, String t) async => {
  for (final r in await db.rawQuery('PRAGMA main.table_info($t)'))
    r['name'] as String,
};

bool _isDev(Object? id) => id is String && id.startsWith('dev:');

/// the vault's move lock: [work] runs with no chat hidden or unhidden
/// meanwhile (AppState.withVaultStill)
typedef HistoryHold = Future<void> Function(Future<void> Function() work);

/// a chat was hidden while the copy read the chats: nothing of it goes
class HistoryHiddenMeanwhile implements Exception {
  const HistoryHiddenMeanwhile();
}

// a voice note by its bytes as well as its name: under skip a name alone
// would let a sender's choice of name bring any file along
Future<bool> _voiceFile(String path) async {
  try {
    final f = File(path);
    final n = await f.length();
    if (n < 12 || n > kHistoryVoiceMax) return false;
    final raf = await f.open();
    try {
      final h = await raf.read(12);
      bool at(int i, String s) => String.fromCharCodes(h, i, i + 4) == s;
      return at(0, 'OggS') || (at(0, 'RIFF') && at(8, 'WAVE'));
    } finally {
      await raf.close();
    }
  } catch (_) {
    return false;
  }
}

// what a crash or another sender left in the spool folder. a spool still
// open keeps working: its file stays readable once unlinked
Future<void> _sweepSpools(String dir) async {
  try {
    await for (final e in Directory(dir).list(followLinks: false)) {
      final name = p.basename(e.path);
      if (e is File &&
          name.startsWith(kHistorySpoolPrefix) &&
          name.endsWith(kHistorySpoolSuffix)) {
        await e.delete();
      }
    }
  } on FileSystemException {
    // nothing there yet
  }
}

String _spoolName() {
  final r = Random.secure();
  final hex = [
    for (var i = 0; i < 8; i++)
      r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  return '$kHistorySpoolPrefix$hex$kHistorySpoolSuffix';
}

/// builds the stream for a new device. [db] is the everyday database,
/// nothing attached; [mediaDir] its media folder; [spoolDir] the app's
/// private no-backup folder. [skipMedia] leaves photos, videos and files
/// out; voice notes always go. [hold] keeps the vault still while the
/// chats are read; whatever it is, a chat hidden meanwhile stops the copy
Future<HistoryOutgoing> exportHistory({
  required Database db,
  required HaloContainer container,
  required String mediaDir,
  required String spoolDir,
  required String keyHex,
  required String bindHex,
  required String identityHex,
  bool skipMedia = false,
  DateTime? now,
  int chunk = 0,
  HistoryHold? hold,
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
  final chats = <HistoryChatRef>[];
  var hidden = <String>{};
  HistorySender? sender;
  // the chats and their messages, read while the vault stays still
  Future<void> text() async {
    hidden = await hiddenChatIds(db);
    final support = <String>{
      if (await _hasTable(db, 'support_chats'))
        for (final r in await db.rawQuery(
          'SELECT halo_id FROM main.support_chats',
        ))
          r['halo_id'] as String,
    };
    // whole chats that stay: the vault's, the developer's and what it started
    bool stays(String id) =>
        hidden.contains(id) || support.contains(id) || _isDev(id);

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
      if (gcols.contains('shots_on')) 'shots_on',
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
      'SELECT peer_id AS k, MAX($when) AS t FROM main.messages '
      'WHERE group_id IS NULL GROUP BY peer_id',
    )) {
      last['p:${r['k']}'] = (r['t'] as num?)?.toInt() ?? 0;
    }
    for (final r in await db.rawQuery(
      'SELECT group_id AS k, MAX($when) AS t FROM main.messages '
      'WHERE group_id IS NOT NULL GROUP BY group_id',
    )) {
      last['g:${r['k']}'] = (r['t'] as num?)?.toInt() ?? 0;
    }
    final peers = [
      for (final r in await db.rawQuery(
        'SELECT ${contactCols.join(', ')} FROM main.contacts c '
        'WHERE ${ccols.contains('accepted') ? 'c.accepted = 1 OR ' : ''}'
        'EXISTS (SELECT 1 FROM main.messages m WHERE m.peer_id = c.halo_id '
        'AND m.group_id IS NULL)',
      ))
        if (!stays(r['halo_id'] as String)) r,
    ];
    // burner rooms burn: they stay on the phone that holds them
    final rooms = [
      if (gcols.contains('room_priv')) 'room_priv IS NULL',
      if (gcols.contains('expires_at')) 'expires_at IS NULL',
    ];
    final groups = [
      for (final r in await db.rawQuery(
        'SELECT ${groupCols.join(', ')} FROM main.groups'
        '${rooms.isEmpty ? '' : ' WHERE ${rooms.join(' AND ')}'}',
      ))
        if (!stays(r['group_id'] as String)) r,
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

    await _sweepSpools(spoolDir);
    final s = sender = HistorySender.open(
      keyHex: keyHex,
      bindHex: bindHex,
      identityHex: identityHex,
      spool: p.join(spoolDir, _spoolName()),
      root: mediaDir,
      skipMedia: skipMedia,
      chunk: chunk,
    );
    final media = <String>{};
    final hasReactions = await _hasTable(db, 'reactions');
    final hasVotes = await _hasTable(db, 'poll_votes');
    for (final (group, id, row) in order) {
      // a linux desktop cannot keep a screenshot block: the chat shows there
      // as staying on this phone, nothing of what was said in it
      final shots = row['shots_on'] == 1;
      final meta = <String, Object?>{
        'kind': group ? 'group' : 'peer',
        'id': id,
        // a blocked group's row shows only what the stays line needs
        'row': group && shots
            ? {'group_id': row['group_id'], 'name': row['name'], 'shots_on': 1}
            : row,
        if (shots) 'stays': kHistoryStaysShots,
      };
      if (group && !shots) {
        meta['members'] = await db.rawQuery(
          'SELECT halo_id, joined_at FROM main.group_members '
          'WHERE group_id = ? ORDER BY halo_id',
          [id],
        );
        meta['people'] = await db.rawQuery(
          'SELECT halo_id, onion, xpub, first_seen, last_seen, back_paired, '
          'blocked FROM main.contacts '
          'WHERE halo_id IN (SELECT halo_id FROM main.group_members '
          'WHERE group_id = ?1 UNION SELECT peer_id FROM main.messages '
          'WHERE group_id = ?1) ORDER BY halo_id',
          [id],
        );
      }
      final n = s.chat(meta);
      // a row too big to go: counted in the head, the rest goes on
      if (n == null) continue;
      chats.add(HistoryChatRef(group, id));
      if (shots) continue;
      var after = 0;
      while (true) {
        final page = await db.rawQuery(
          'SELECT id, ${msgCols.join(', ')}'
          '${mcols.contains('via_dev') ? ', via_dev' : ''}'
          '${mcols.contains('burn_at') ? ', burn_at' : ''}'
          '${mcols.contains('burn_secs') ? ', burn_secs' : ''}'
          '${mcols.contains('burn_unseen') ? ', burn_unseen' : ''} '
          'FROM main.messages WHERE '
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
                (m['burn_unseen'] ?? 0) == 0)
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
              'SELECT msg_uid, reactor, emoji, reacted_at FROM main.reactions '
              'WHERE msg_uid IN ($marks) ORDER BY msg_uid, reactor',
              uids,
            )) {
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
              'FROM main.poll_votes WHERE poll_uid IN ($marks) '
              'ORDER BY poll_uid, voter',
              uids,
            )) {
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
          final named = isVoiceName(m['file_name'] as String?);
          for (final col in const ['media_path', 'file_path']) {
            final path = row[col];
            if (path is! String || path.isEmpty) continue;
            // only a file of this container's own folder, by its name there
            final inside = p.isWithin(mediaDir, path);
            final rel = inside
                ? p.posix.joinAll(p.split(p.relative(path, from: mediaDir)))
                : null;
            row[col] = rel;
            // the month's files; under skip only what really is a voice note
            final goes =
                at >= since &&
                (!skipMedia || (named && await _voiceFile(path)));
            if (!goes) continue;
            // a file that would have gone and cannot is counted
            if (rel == null) {
              s.left(n);
              continue;
            }
            if (media.add(rel)) s.media(n, at, rel);
          }
          final uid = m['msg_uid'];
          if (uid is String) {
            if (reactions[uid] case final r?) row['x_reactions'] = r;
            if (votes[uid] case final v?) row['x_votes'] = v;
          }
          s.message(row);
        }
      }
    }
    // a hide that slipped past the hold: nothing of it may go. checked
    // inside the hold, so a hide waiting on it cannot slip in between
    final after = await hiddenChatIds(db);
    if (after.difference(hidden).isNotEmpty) {
      throw const HistoryHiddenMeanwhile();
    }
  }

  try {
    await (hold ?? (w) => w())(text);
    final s = sender!;
    await s.plan();
    return HistoryOutgoing._(s, s.id, s.head(), chats);
  } catch (_) {
    sender?.close();
    rethrow;
  }
}
