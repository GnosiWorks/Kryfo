// SPDX-License-Identifier: GPL-3.0-or-later
// the search index

part of '../main.dart';

mixin _SearchRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();

  // ---- search ----

  /// one batch of the first fill, oldest first. how far it got, of how
  /// many; done when [at] reaches [to].
  Future<({int at, int to})> fillSearchIndex({int batch = 300}) async {
    final db = await open();
    int meta(List<Map<String, Object?>> r) =>
        r.isEmpty ? 0 : (r.first['v'] as num).toInt();
    final to = meta(
      await db.query('search_meta', where: "k = 'fill_to'", limit: 1),
    );
    var at = meta(
      await db.query('search_meta', where: "k = 'fill_at'", limit: 1),
    );
    if (at >= to) return (at: at, to: to);
    final rows = await db.query(
      'messages',
      columns: ['id', 'plaintext', 'poll', 'file_name', 'preview', 'sticker'],
      where: 'id > ? AND id <= ?',
      whereArgs: [at, to],
      orderBy: 'id ASC',
      limit: batch,
    );
    at = rows.isEmpty ? to : rows.last['id'] as int;
    final b = db.batch();
    for (final r in rows) {
      indexSearchRowIn(b, r['id'] as int, r);
    }
    b.update('search_meta', {'v': at}, where: "k = 'fill_at'");
    await b.commit(noResult: true);
    return (at: at, to: to);
  }

  /// messages that match [match] (a full-text match, or null for every
  /// message) and [kind], newest first. never a blocked contact's, never a
  /// stranger's who has not been accepted.
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async {
    final rows = await runSearchQuery(await open(), match, kind, limit: limit);
    // the newest that came, shown in the chats' order
    return [...rows]..sort(
      (a, b) => byWritten(
        rowWrittenAt(b),
        (b['id'] as num?)?.toInt() ?? 0,
        rowWrittenAt(a),
        (a['id'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// the search query itself, on any database with the schema: the app's,
/// or the debug benchmark's scratch one
Future<List<Map<String, Object?>>> runSearchQuery(
  DatabaseExecutor db,
  String? match,
  SearchKind kind, {
  int limit = 300,
}) async {
  final where = <String>[
    'm.peer_id NOT IN (SELECT halo_id FROM contacts WHERE blocked = 1)',
    // a group's rows only while the group is here: one left before its
    // rows went with it opens nothing
    "(m.group_id IN (SELECT group_id FROM groups) OR (m.group_id IS NULL "
        "AND (m.direction = 'out' OR m.peer_id IN "
        '(SELECT halo_id FROM contacts WHERE accepted = 1))))',
    // a timed message not read yet is found in its own chat alone, where
    // reading it starts its clock
    'NOT ${burnWaitsSql('m')}',
  ];
  final args = <Object?>[];
  final kw = kindWhere(kind);
  if (kw.isNotEmpty) where.add(kw);
  // newest first by row id, the order messages arrived in: the index walks
  // its ids backwards and stops at the limit. sorting by time would sort
  // every match of a common word first
  final String from;
  final String order;
  if (match != null) {
    from = 'msg_fts JOIN messages m ON m.id = msg_fts.rowid';
    where.insert(0, 'msg_fts MATCH ?');
    args.add(match);
    order = 'msg_fts.rowid DESC';
  } else {
    if (kind == SearchKind.all) return const [];
    from = 'messages m';
    order = 'm.id DESC';
  }
  args.add(limit);
  return db.rawQuery(
    'SELECT m.id, m.msg_uid, m.peer_id, m.group_id, m.direction, '
    'm.plaintext, m.sent_at, m.written_at, m.media_path, m.file_path, '
    'm.file_name, m.poll, m.preview FROM $from WHERE ${where.join(' AND ')} '
    'ORDER BY $order LIMIT ?',
    args,
  );
}

/// the same, queued on a batch: one trip for many rows
void indexSearchRowIn(Batch b, int id, Map<String, Object?> r) {
  b.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
  final body = searchBody(r);
  if (body.trim().isNotEmpty) b.insert('msg_fts', {'rowid': id, 'body': body});
}

Future<void> indexSearchRow(
  DatabaseExecutor db,
  int id,
  Map<String, Object?> r,
) async {
  await db.delete('msg_fts', where: 'rowid = ?', whereArgs: [id]);
  final body = searchBody(r);
  if (body.trim().isEmpty) return;
  await db.insert('msg_fts', {'rowid': id, 'body': body});
}
