// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's own phone: the chats people start from the Marios row,
// kept in an inbox of their own, out of requests and out of the contacts.
// a chat is filed by the marker every frame to him carries, and only while
// its sender is not accepted yet. the marker is a label, not a pass: anyone
// can set it, so it lifts no gate. on every other phone the table is empty

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../message_envelope.dart' show UnwrappedMessage;
import '../notifications.dart'
    show clearSupportSummary, showSupportMessage, showSupportSummary;
import 'dev_key.dart' show isDevChat;

// what a support chat may send before he answers, as the person's side
// holds it too
const kSupportCap = 5;

// a waiting chat rings at most this often. the rest update the count
const kSupportGap = Duration(minutes: 30);

// a notification's tap: the inbox, or with an id after it, that chat
const kSupportPayload = 'support:';

const _open = 'open';
const _done = 'done';

// in every container, made the same way. empty everywhere but on his phone
Future<void> supportTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS support_chats (
      halo_id TEXT PRIMARY KEY,
      first_at INTEGER NOT NULL,
      state TEXT NOT NULL DEFAULT 'open',
      alerted_at INTEGER
    )
  ''');
}

enum SupportSection {
  // no answer yet
  waiting,
  answered,
  // put away by hand. a new message brings it back
  done,
}

// one chat as the inbox shows it
class SupportChat {
  const SupportChat({
    required this.haloId,
    required this.firstAt,
    this.done = false,
    this.answered = false,
    this.unread = 0,
    this.last,
  });

  final String haloId;
  final int firstAt;
  final bool done;
  // he wrote back: the sender is accepted
  final bool answered;
  final int unread;
  // the chat's last message, as the messages table keeps it
  final Map<String, Object?>? last;

  SupportSection get section => done
      ? SupportSection.done
      : answered
      ? SupportSection.answered
      : SupportSection.waiting;

  // the last message's time, or when the chat came in
  int get at => (last?['sent_at'] as num?)?.toInt() ?? firstAt;
}

// the support chats of one container's database
class SupportChats {
  SupportChats(this._db, {int Function()? now}) : _now = now ?? _clock;

  final Future<Database> Function() _db;
  final int Function() _now;

  static int _clock() => DateTime.now().millisecondsSinceEpoch;

  // a table a migration could not make holds nothing: home and requests
  // still read
  Future<List<Map<String, Object?>>> _rows({
    String? where,
    List<Object?>? args,
  }) async {
    try {
      final db = await _db();
      return await db.query('support_chats', where: where, whereArgs: args);
    } catch (e) {
      dlog('support: ${e.runtimeType}');
      return const [];
    }
  }

  Future<Set<String>> ids() async => {
    for (final r in await _rows()) r['halo_id'] as String,
  };

  Future<bool> has(String id) async =>
      (await _rows(where: 'halo_id = ?', args: [id])).isNotEmpty;

  // files [id] as a support chat. a done one written to again comes back
  // when [reopen]. true when the chat is new
  Future<bool> file(String id, {bool reopen = true}) async {
    final db = await _db();
    return db.transaction((t) async {
      final had = await t.query(
        'support_chats',
        columns: ['state'],
        where: 'halo_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (had.isEmpty) {
        await t.insert('support_chats', {
          'halo_id': id,
          'first_at': _now(),
          'state': _open,
        });
        return true;
      }
      if (reopen && had.first['state'] == _done) {
        await t.update(
          'support_chats',
          {'state': _open},
          where: 'halo_id = ?',
          whereArgs: [id],
        );
      }
      return false;
    });
  }

  Future<void> setDone(String id, bool done) async {
    final db = await _db();
    await db.update(
      'support_chats',
      {'state': done ? _done : _open},
      where: 'halo_id = ?',
      whereArgs: [id],
    );
  }

  // every chat the waiting section shows, put away. the ids it moved
  Future<List<String>> markWaitingDone() async {
    final ids = [
      for (final c in await list())
        if (c.section == SupportSection.waiting) c.haloId,
    ];
    final db = await _db();
    await db.transaction((t) async {
      for (final id in ids) {
        await t.update(
          'support_chats',
          {'state': _done},
          where: 'halo_id = ?',
          whereArgs: [id],
        );
      }
    });
    return ids;
  }

  // a deleted chat: if they write again it is a new one
  Future<void> forget(String id) async {
    final db = await _db();
    await db.delete('support_chats', where: 'halo_id = ?', whereArgs: [id]);
  }

  // MAX(alerted_at): when a waiting chat last rang
  Future<int?> lastAlert() async {
    try {
      final db = await _db();
      final r = await db.query(
        'support_chats',
        columns: ['alerted_at'],
        where: 'alerted_at IS NOT NULL',
        orderBy: 'alerted_at DESC',
        limit: 1,
      );
      return r.isEmpty ? null : (r.first['alerted_at'] as num).toInt();
    } catch (e) {
      dlog('support: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> alerted(String id, int at) async {
    final db = await _db();
    await db.update(
      'support_chats',
      {'alerted_at': at},
      where: 'halo_id = ?',
      whereArgs: [id],
    );
  }

  // the people behind the open chats who still wait for an answer: not
  // accepted, not blocked, not let go. with their unread counts
  Future<Map<String, int>> _waitingUnread() async {
    final open = {
      for (final r in await _rows(where: 'state = ?', args: [_open]))
        r['halo_id'] as String,
    };
    if (open.isEmpty) return const {};
    final db = await _db();
    final people = await db.query(
      'contacts',
      columns: ['halo_id', 'unread', 'archived'],
      where: 'accepted = ? AND blocked = ?',
      whereArgs: [0, 0],
    );
    return {
      for (final p in people)
        if (open.contains(p['halo_id']) && p['archived'] != 1)
          p['halo_id'] as String: (p['unread'] as num?)?.toInt() ?? 0,
    };
  }

  // how many chats wait for a first answer: the home pin's count
  Future<int> waiting() async => (await _waitingUnread()).length;

  // what the summary says: waiting chats with something unread, and how
  // many messages that is
  Future<({int chats, int messages})> news() async {
    final w = await _waitingUnread();
    var chats = 0;
    var messages = 0;
    for (final n in w.values) {
      if (n <= 0) continue;
      chats++;
      messages += n;
    }
    return (chats: chats, messages: messages);
  }

  // every chat the inbox shows, newest first. a blocked sender is on the
  // blocked list instead, and one let go has no chat left
  Future<List<SupportChat>> list() async {
    final rows = await _rows();
    if (rows.isEmpty) return const [];
    final db = await _db();
    final out = <SupportChat>[];
    for (final r in rows) {
      final id = r['halo_id'] as String;
      final c = await db.query(
        'contacts',
        columns: ['accepted', 'blocked', 'archived', 'unread'],
        where: 'halo_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (c.isEmpty) continue;
      final p = c.first;
      final answered = p['accepted'] == 1;
      if (p['blocked'] == 1 || (!answered && p['archived'] == 1)) continue;
      final last = await db.query(
        'messages',
        columns: [
          'direction',
          'plaintext',
          'sent_at',
          'media_path',
          'file_name',
          'sticker',
        ],
        where: 'peer_id = ? AND group_id IS NULL',
        whereArgs: [id],
        orderBy: 'id DESC',
        limit: 1,
      );
      out.add(
        SupportChat(
          haloId: id,
          firstAt: (r['first_at'] as num?)?.toInt() ?? 0,
          done: r['state'] == _done,
          answered: answered,
          unread: (p['unread'] as num?)?.toInt() ?? 0,
          last: last.isEmpty ? null : last.first,
        ),
      );
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}

// the requests inbox: the rows of [requests] that are not support chats
List<Map<String, Object?>> withoutSupport(
  List<Map<String, Object?>> requests,
  Set<String> support,
) => support.isEmpty
    ? requests
    : [
        for (final r in requests)
          if (!support.contains(r['halo_id'])) r,
      ];

// what the summary says: how many chats and messages, and nothing of them
String supportSummaryLine(int chats, int messages) =>
    '${l10n.supportNotifNewChats(chats)} · '
    '${l10n.supportNotifNewMessages(messages)}';

// a frame someone wrote, as opposed to a control riding along: a receipt,
// a reaction, an edit, an unsend, a pin, a vote or a need
bool supportNews(UnwrappedMessage env) =>
    env.deliveredUid == null &&
    env.groupControl == null &&
    env.intro == null &&
    env.need == null &&
    env.pin == null &&
    env.vote == null &&
    env.pollClose == null &&
    env.reaction == null &&
    env.edit == null &&
    env.unsend == null;

// what a support chat never brings in: a group or a room joined through it,
// or someone it introduces. a support chat is no way into his groups or his
// contacts
bool supportRefuses(UnwrappedMessage env) =>
    env.groupControl != null || env.intro != null;

// a frame on his own phone. a 1:1 frame with the marker from someone not
// accepted yet files their chat; a chat filed before stays one, marker or
// not, and a message brings a done one back. whether the sender's chat is
// a support chat, and whether this frame opened it
Future<({bool on, bool fresh})> fileSupport(
  SupportChats chats,
  String sender,
  UnwrappedMessage env, {
  required Future<bool> Function() accepted,
}) async {
  // the dev chat is never anyone's support chat
  if (isDevChat(sender)) return (on: false, fresh: false);
  final one = env.groupId == null;
  final news = one && supportNews(env);
  if (one && env.supportMarker != null && !await accepted()) {
    return (on: true, fresh: await chats.file(sender, reopen: news));
  }
  if (!await chats.has(sender)) return (on: false, fresh: false);
  if (news) await chats.file(sender);
  return (on: true, fresh: false);
}

// whether a new waiting chat rings: the first one ever, or the first one a
// gap after the last ring. a clock set back rings rather than going quiet
bool supportRings({
  required int? lastAlert,
  required int now,
  Duration gap = kSupportGap,
}) =>
    lastAlert == null ||
    now < lastAlert ||
    now - lastAlert >= gap.inMilliseconds;

// android, as support rings through it
class SupportBell {
  const SupportBell();

  // the one summary, updated in place: counts, never words
  Future<void> summary({
    required int chats,
    required int messages,
    required bool alert,
  }) => showSupportSummary(chats: chats, messages: messages, alert: alert);

  // an answered chat's message, as any contact's would ring
  Future<void> chat({
    required String chatId,
    required String title,
    required String body,
  }) => showSupportMessage(chatId: chatId, title: title, body: body);

  Future<void> clear() => clearSupportSummary();
}

// the summary after a waiting chat's frame. a new chat rings when the last
// ring is a gap behind it, and takes the ring for itself; anything else
// only updates the count. nothing unread left takes it down
Future<void> ringSupport(
  SupportChats chats,
  SupportBell bell, {
  required String chat,
  required bool fresh,
  int? now,
  Duration gap = kSupportGap,
}) async {
  final at = now ?? DateTime.now().millisecondsSinceEpoch;
  final n = await chats.news();
  if (n.chats == 0) return bell.clear();
  final alert =
      fresh &&
      supportRings(lastAlert: await chats.lastAlert(), now: at, gap: gap);
  if (alert) await chats.alerted(chat, at);
  await bell.summary(chats: n.chats, messages: n.messages, alert: alert);
}
