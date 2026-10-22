// SPDX-License-Identifier: GPL-3.0-or-later
// notification tags and the rings in the shade

part of '../main.dart';

mixin _NotifRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();
  bool get isOpen;

  // notification [id] rang for message [msgUid] of [chat]. the shade keeps
  // nothing for longer than a week here
  Future<void> noteRing(int id, String chat, String msgUid) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('notif_rings', {
      'id': id,
      'chat': chat,
      'msg_uid': msgUid,
      'at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete(
      'notif_rings',
      where: 'at < ?',
      whereArgs: [now - kReceiptKeptFor.inMilliseconds],
    );
  }

  // the message notification [id] of [chat] rang for, while it is here
  Future<String?> ringOf(int id, String chat) async {
    final db = await open();
    final r = await db.rawQuery(
      'SELECT r.msg_uid FROM notif_rings r JOIN messages m '
      'ON m.msg_uid = r.msg_uid WHERE r.id = ? AND r.chat = ? LIMIT 1',
      [id, chat],
    );
    return r.isEmpty ? null : r.first['msg_uid'] as String?;
  }

  // the notifications of [chat], or of [msgUid], left the shade
  Future<void> forgetRings({String? chat, String? msgUid}) async {
    if (!isOpen) return;
    final db = await open();
    if (chat != null) {
      await db.delete('notif_rings', where: 'chat = ?', whereArgs: [chat]);
    }
    if (msgUid != null) {
      await db.delete('notif_rings', where: 'msg_uid = ?', whereArgs: [msgUid]);
    }
  }

  // the tag [chat]'s notifications go under, made on its first one
  Future<String> notifTag(String chat) async => notifTagIn(await open(), chat);

  Future<String?> notifTagOf(String chat) async =>
      notifTagOfIn(await open(), chat);

  // the chat a tapped notification's tag stands for, when it is this
  // container's
  Future<String?> notifChatOf(String tag) async =>
      notifChatIn(await open(), tag);
}

Future<String?> notifTagOfIn(DatabaseExecutor db, String chat) async {
  final r = await db.query(
    'notif_tags',
    columns: ['tag'],
    where: 'chat = ?',
    whereArgs: [chat],
    limit: 1,
  );
  return r.isEmpty ? null : r.first['tag'] as String;
}

// made once: a second caller at the same moment takes the first one's
Future<String> notifTagIn(DatabaseExecutor db, String chat) async {
  final had = await notifTagOfIn(db, chat);
  if (had != null) return had;
  await db.insert('notif_tags', {
    'chat': chat,
    'tag': newNotifTag(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  return (await notifTagOfIn(db, chat))!;
}

Future<String?> notifChatIn(DatabaseExecutor db, String tag) async {
  final r = await db.query(
    'notif_tags',
    columns: ['chat'],
    where: 'tag = ?',
    whereArgs: [tag],
    limit: 1,
  );
  return r.isEmpty ? null : r.first['chat'] as String;
}
