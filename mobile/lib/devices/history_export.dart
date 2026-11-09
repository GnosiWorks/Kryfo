// SPDX-License-Identifier: GPL-3.0-or-later
// what the phone sends a newly linked device: every text, and the last 30
// days of photos, videos, voice notes and files (voice notes alone when the
// rest is skipped). a file sealed at rest goes as it lies on the disk, with
// its own key beside its row, so the device opens that file and no other.
// read from the everyday database alone, every everyday chat as this phone
// holds it, the developer's inbox with its states. hidden chats (whole,
// by id), the decoy, the chat with the developer, burner rooms, timed
// messages and chats with screenshots blocked stay here
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../container.dart';
import '../router.dart' show hiddenChatIds;
import '../voice_format.dart' show isVoiceName;
import 'history_ffi.dart';
import 'history_open.dart';

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

/// a chat of the developer's inbox: its state there and when it came
const kHistorySupport = 'support';

/// a message that came through the developer chat
const kHistoryViaDev = 'x_via_dev';

/// a record of the copy that is no chat: what the device needs to go on
/// where the phone is (lists the phone holds and what its engine learnt of
/// those contacts, messages it deleted lately),
/// sent with every copy, "no history" too
const kHistoryMaterial = 'material';

// a material record stays well inside a chat record
const _kMaterialMost = 48 << 10;

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
  // v4: my identity for the contact, and theirs
  'ident',
  'ikey',
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
  'shots_on',
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

// a copy on the open list from the moment its sender exists, so a hide
// queued while the chats are read ends it however far it got
class _Open {
  _Open(this.s) {
    off = historyCopyOpened(end);
  }
  final HistorySender s;
  late final void Function() off;
  bool ended = false;
  // the engine holds the sender's lock while it reads the files, so a close
  // then would stall the hide for all of it: the export closes it after
  bool planning = false;

  void end() {
    if (ended) return;
    ended = true;
    if (!planning) s.close();
  }
}

/// the planned stream on the phone
class HistoryOutgoing {
  HistoryOutgoing._(this._o, this.id, this.head, this.chats, this._gone);
  final _Open _o;
  final _GoneSince _gone;
  HistorySender get _s => _o.s;

  /// a chat was hidden while the copy was open: nothing more goes, and the
  /// device discards what it took
  bool get ended => _o.ended;

  /// the engine's handle of the sender, for the door that serves it
  int get handle => _s.handle;

  /// the stream id the device needs with the first record, as hex
  final String id;
  final HistoryHead head;
  final List<HistoryChatRef> chats;

  /// what the phone could not send, chat by chat, and whole chats
  List<HistoryChatLeft> get left => historyLeftOf(head, chats);
  int get leftChats => head.leftChats;

  Uint8List record(int i) {
    if (ended) throw const HistoryRefused('ended', forGood: true);
    return _s.record(i);
  }

  /// the device's tally: every chat it counted otherwise
  List<HistoryChatGap> checkTally(Uint8List tally) => [
    for (final g in _s.checkTally(tally))
      HistoryChatGap(chats[g.chat], g.want, g.got),
  ];

  /// what this phone deleted since it made the copy, in the chats whose
  /// row went, as the copy's own gone rows: [uid, key, at]
  Future<List<List<Object?>>> goneSince() => _gone.rows();

  void close() {
    _o.off();
    _o.end();
  }
}

// the gone rows the copy carried, and the chats they are for: whatever
// gone_in holds beyond them later went since the export
class _GoneSince {
  _GoneSince(this.db, this.peers, this.groups, this.sent);
  final Database db;
  final Set<String> peers;
  final Set<String> groups;
  final Set<String> sent;

  static String keyOf(Object? uid, Object? peer, Object? at) =>
      '$uid|$peer|$at';

  Future<List<List<Object?>>> rows() async => [
    if (await _hasTable(db, 'gone_in'))
      for (final r in await db.rawQuery(
        'SELECT msg_uid, peer_id, at FROM main.gone_in ORDER BY at',
      ))
        if (_goneFor(r['peer_id'] as String, peers, groups) &&
            !sent.contains(keyOf(r['msg_uid'], r['peer_id'], r['at'])))
          [r['msg_uid'], r['peer_id'], r['at']],
  ];
}

// whether a gone row's key names a chat of these
bool _goneFor(String k, Set<String> peers, Set<String> groups) {
  final g = k.startsWith('group:') ? k.substring(6, k.lastIndexOf(':')) : null;
  return g == null ? peers.contains(k) : groups.contains(g);
}

// the material in records that each stay inside one chat record
List<Map<String, Object?>> _materialRecords(Map<String, List<Object?>> m) {
  final out = <Map<String, Object?>>[];
  var cur = <String, List<Object?>>{};
  var size = 0;
  void flush() {
    if (cur.isEmpty) return;
    out.add({'kind': kHistoryMaterial, 'id': '', ...cur});
    cur = {};
    size = 0;
  }

  for (final e in m.entries) {
    for (final item in e.value) {
      final n = jsonEncode(item).length + 1;
      if (size + n > _kMaterialMost) flush();
      (cur[e.key] ??= []).add(item);
      size += n;
    }
  }
  flush();
  return out;
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

/// the key one media file is sealed under at rest, null when it lies plain
/// (phone_seal.dart fileKeyOf)
typedef HistoryFileKey = Uint8List? Function(String path);

/// a chat was hidden while the copy read the chats: nothing of it goes
class HistoryHiddenMeanwhile implements Exception {
  const HistoryHiddenMeanwhile();
}

enum _Voice { yes, no, tooBig }

// a voice note by its bytes as well as its name: under skip a name alone
// would let a sender's choice of name bring any file along
Future<_Voice> _voiceFile(String path) async {
  try {
    final f = File(path);
    final n = await f.length();
    if (n < 12) return _Voice.no;
    final raf = await f.open();
    try {
      final h = await raf.read(12);
      bool at(int i, String s) => String.fromCharCodes(h, i, i + 4) == s;
      if (!at(0, 'OggS') && !(at(0, 'RIFF') && at(8, 'WAVE'))) return _Voice.no;
    } finally {
      await raf.close();
    }
    return n > kHistoryVoiceMax ? _Voice.tooBig : _Voice.yes;
  } catch (_) {
    return _Voice.no;
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
  bool rowsOnly = false,
  DateTime? now,
  int chunk = 0,
  HistoryHold? hold,
  HistoryFileKey? fileKeyOf,
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
  final sentPeers = <String>{};
  final sentGroups = <String>{};
  final goneSent = <String>{};
  var hidden = <String>{};
  HistorySender? sender;
  _Open? open;
  // the chats and their messages, read while the vault stays still
  Future<void> text() async {
    hidden = await hiddenChatIds(db);
    // the developer's inbox goes with its state, moved to Chats or not
    final support = <String, Map<String, Object?>>{
      if (await _hasTable(db, 'support_chats'))
        for (final r in await db.rawQuery(
          'SELECT halo_id, first_at, state FROM main.support_chats',
        ))
          r['halo_id'] as String: {'f': r['first_at'], 's': r['state']},
    };
    // whole chats that stay: the vault's and the developer chat
    bool stays(String id) => hidden.contains(id) || _isDev(id);

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
    // on the open list while the hold still holds
    open = _Open(s);
    final media = <String>{};
    final hasReactions = await _hasTable(db, 'reactions');
    final hasVotes = await _hasTable(db, 'poll_votes');
    final hasOrder = await _hasTable(db, 'frame_order');
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
        if (!group && support.containsKey(id)) kHistorySupport: support[id],
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
      // what was deleted of it goes too, "no history" included, so a copy
      // of it the device got live goes there as it went here
      (group ? sentGroups : sentPeers).add(id);
      // "no history": the chat's row alone, and only new messages after
      if (rowsOnly) continue;
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
            // timed messages burn where they are
            if (m['burn_at'] == null &&
                m['burn_secs'] == null &&
                (m['burn_unseen'] ?? 0) == 0)
              m,
        ];
        final uids = [
          for (final m in keep)
            if (m['msg_uid'] case final String u) u,
        ];
        // the sender's time on the last edit this phone took of each: the
        // device keeps a later edit of its own over the copy's words
        final edits = <String, int>{};
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
          if (hasOrder) {
            for (final r in await db.rawQuery(
              "SELECT msg_uid, sender, w FROM main.frame_order WHERE kind = 'edit' "
              'AND msg_uid IN ($marks)',
              uids,
            )) {
              edits['${r['msg_uid']}|${r['sender']}'] = (r['w'] as num).toInt();
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
            if (at < since) continue;
            final voice = skipMedia && named
                ? await _voiceFile(path)
                : _Voice.no;
            // voice notes always come: one too big to is counted
            if (voice == _Voice.tooBig) {
              s.left(n);
              continue;
            }
            if (skipMedia && voice != _Voice.yes) continue;
            // a file that would have gone and cannot is counted
            if (rel == null) {
              s.left(n);
              continue;
            }
            if (media.add(rel)) s.media(n, at, rel);
            // the engine sends the bytes as they lie: a sealed file's key
            // goes with its row, or the device holds bytes it cannot open
            final k = fileKeyOf?.call(path);
            if (k != null) {
              ((row['x_keys'] ??= <String, String>{}) as Map)[rel] =
                  base64Encode(k);
            }
          }
          // the tag a message through the developer chat wears
          if (m['via_dev'] == 1) row[kHistoryViaDev] = 1;
          final uid = m['msg_uid'];
          if (uid is String) {
            if (reactions[uid] case final r?) row['x_reactions'] = r;
            if (votes[uid] case final v?) row['x_votes'] = v;
            if (edits['$uid|${m['peer_id']}'] case final w?) {
              row['x_edit_w'] = w;
            }
          }
          s.message(row);
        }
      }
    }
    // last, what is no chat: the contacts' lists this phone holds, and the
    // messages of the chats that went that it deleted lately, so a copy of
    // one the device got live goes there too
    final material = <String, List<Object?>>{
      'gone': [],
      'lists': [],
      'proven': [],
      'pq': [],
    };
    final keys = <String>{
      for (final (group, _, row) in order)
        if (!group && row['ikey'] is String) row['ikey'] as String,
    };
    if (await _hasTable(db, 'gone_in')) {
      for (final r in await db.rawQuery(
        'SELECT msg_uid, peer_id, at FROM main.gone_in ORDER BY at',
      )) {
        final k = r['peer_id'] as String;
        if (!_goneFor(k, sentPeers, sentGroups)) continue;
        material['gone']!.add([r['msg_uid'], k, r['at']]);
        goneSent.add(_GoneSince.keyOf(r['msg_uid'], k, r['at']));
      }
    }
    // the keys each contact's messages came under, and whether a session
    // with them was post-quantum: the device starts where this phone is
    if (await _hasTable(db, 'dev_proven')) {
      for (final r in await db.rawQuery(
        'SELECT peer, key FROM main.dev_proven WHERE ident = 0 '
        'ORDER BY peer, key',
      )) {
        if (!keys.contains(r['peer'])) continue;
        material['proven']!.add([r['peer'], r['key']]);
      }
    }
    if (await _hasTable(db, 'dev_pq')) {
      for (final r in await db.rawQuery(
        'SELECT peer FROM main.dev_pq WHERE ident = 0 ORDER BY peer',
      )) {
        if (keys.contains(r['peer'])) material['pq']!.add(r['peer']);
      }
    }
    if (await _hasTable(db, 'dev_lists')) {
      for (final r in await db.rawQuery(
        "SELECT owner, wire FROM main.dev_lists WHERE ident = 0 AND owner != 'me' "
        'ORDER BY owner',
      )) {
        final owner = r['owner'] as String;
        final wire = r['wire'];
        if (!keys.contains(owner) || wire is! List<int>) continue;
        material['lists']!.add([owner, base64Encode(wire)]);
      }
    }
    for (final meta in _materialRecords(material)) {
      if (s.chat(meta) == null) continue;
      chats.add(const HistoryChatRef(false, ''));
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
    final o = open!;
    o.planning = true;
    try {
      await o.s.plan();
    } finally {
      o.planning = false;
    }
    if (o.ended) throw const HistoryHiddenMeanwhile();
    return HistoryOutgoing._(
      o,
      o.s.id,
      o.s.head(),
      chats,
      _GoneSince(db, sentPeers, sentGroups, goneSent),
    );
  } catch (e) {
    final ended = open?.ended ?? false;
    open?.off();
    open?.end();
    sender?.close();
    // a hide ended it on the way, whatever else went wrong then
    if (ended && e is! HistoryHiddenMeanwhile) {
      throw const HistoryHiddenMeanwhile();
    }
    rethrow;
  }
}
