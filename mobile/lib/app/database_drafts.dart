// SPDX-License-Identifier: GPL-3.0-or-later
// unsent words, a row per chat, in the container that holds the chat

part of '../main.dart';

mixin _DraftRows implements DraftRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();

  /// a chat here gone: its draft goes from memory and from its row
  Future<void> dropDraftOf(String chatId, {required bool group}) =>
      dropDraft(this, chatId, group: group);

  @override
  Future<Draft?> draftOf(String chatId, {required bool group}) async {
    final db = await open();
    final r = await db.query(
      'drafts',
      where: 'chat = ?',
      whereArgs: [wallKey(chatId, group: group)],
    );
    return r.isEmpty ? null : _draftOfRow(r.first);
  }

  @override
  Future<void> putDraft(String chatId, Draft d, {required bool group}) async {
    final db = await open();
    await db.insert('drafts', {
      'chat': wallKey(chatId, group: group),
      'body': d.text,
      'reply_to': d.replyTo,
      'updated_at': d.at,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> dropDraftRow(String chatId, {required bool group}) async {
    final db = await open();
    await db.delete(
      'drafts',
      where: 'chat = ?',
      whereArgs: [wallKey(chatId, group: group)],
    );
  }

  /// every draft held here, newest first: what the chat list shows in
  /// place of a row's last message
  Future<List<KeptDraft>> drafts() async {
    final db = await open();
    final rows = await db.query('drafts', orderBy: 'updated_at DESC');
    return [
      for (final r in rows)
        if (r['chat'] case final String chat)
          chat.startsWith('group:')
              ? (chat: chat.substring(6), group: true, draft: _draftOfRow(r))
              : (chat: chat, group: false, draft: _draftOfRow(r)),
    ];
  }

  static Draft _draftOfRow(Map<String, Object?> r) => Draft(
    r['body'] as String? ?? '',
    replyTo: r['reply_to'] as String?,
    at: (r['updated_at'] as num?)?.toInt() ?? 0,
  );
}
