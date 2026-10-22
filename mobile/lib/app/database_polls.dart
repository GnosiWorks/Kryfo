// SPDX-License-Identifier: GPL-3.0-or-later
// polls and their votes

part of '../main.dart';

mixin _PollRows {
  // what these rows take from the rest of HaloDb
  Future<Database> open();

  // ---- polls ----

  /// the poll on a row, the chat it is in, and whether it is ours
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async {
    final db = await open();
    final r = await db.query(
      'messages',
      columns: ['poll', 'group_id', 'direction'],
      where: 'msg_uid = ? AND poll IS NOT NULL',
      whereArgs: [uid],
      limit: 1,
    );
    if (r.isEmpty) return null;
    final spec = PollSpec.parse(r.first['poll']);
    if (spec == null) return null;
    return (
      spec: spec,
      groupId: r.first['group_id'] as String?,
      mine: r.first['direction'] == 'out',
    );
  }

  Future<int?> pollVoteSeq(String pollUid, String voter) async {
    final db = await open();
    final r = await db.query(
      'poll_votes',
      columns: ['seq'],
      where: 'poll_uid = ? AND voter = ?',
      whereArgs: [pollUid, voter],
      limit: 1,
    );
    return r.isEmpty ? null : (r.first['seq'] as num).toInt();
  }

  /// keeps the vote when it is newer than the one held. false when it was
  /// a duplicate or an old vote arriving late.
  Future<bool> putPollVote(
    String pollUid,
    String voter,
    String? groupId,
    List<int> choices,
    int seq,
  ) async {
    final db = await open();
    return db.transaction((tx) async {
      final r = await tx.query(
        'poll_votes',
        columns: ['seq'],
        where: 'poll_uid = ? AND voter = ?',
        whereArgs: [pollUid, voter],
        limit: 1,
      );
      final held = r.isEmpty ? null : (r.first['seq'] as num).toInt();
      if (!voteIsNewer(held, seq)) return false;
      await tx.insert('poll_votes', {
        'poll_uid': pollUid,
        'voter': voter,
        'group_id': groupId,
        'choices': jsonEncode(choices),
        'seq': seq,
        'at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  /// every vote held for these polls, voter by voter
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async {
    final out = <String, Map<String, PollVote>>{};
    if (uids.isEmpty) return out;
    final db = await open();
    for (var i = 0; i < uids.length; i += 400) {
      final part = uids.sublist(
        i,
        i + 400 > uids.length ? uids.length : i + 400,
      );
      final rows = await db.query(
        'poll_votes',
        where: 'poll_uid IN (${List.filled(part.length, '?').join(',')})',
        whereArgs: part,
      );
      for (final r in rows) {
        List<int> picks;
        try {
          picks = (jsonDecode(r['choices'] as String) as List)
              .whereType<int>()
              .toList();
        } catch (_) {
          continue;
        }
        out.putIfAbsent(r['poll_uid'] as String, () => {})[r['voter']
            as String] = PollVote(
          picks,
          (r['seq'] as num).toInt(),
        );
      }
    }
    return out;
  }

  /// the poll is closed: the row says so, and the votes are the final ones
  /// from the close. held above any seq a voter can send, so nothing late
  /// moves them.
  Future<void> closePollRow(
    String uid,
    PollSpec spec,
    Map<String, List<int>> finals,
    String? groupId,
  ) async {
    final db = await open();
    await db.transaction((tx) async {
      await tx.update(
        'messages',
        {'poll': spec.closedNow().toRow()},
        where: 'msg_uid = ?',
        whereArgs: [uid],
      );
      await tx.delete('poll_votes', where: 'poll_uid = ?', whereArgs: [uid]);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final e in finals.entries) {
        await tx.insert('poll_votes', {
          'poll_uid': uid,
          'voter': e.key,
          'group_id': groupId,
          'choices': jsonEncode(e.value),
          'seq': kPollFinalSeq,
          'at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<bool> pollGone(String uid) async {
    final db = await open();
    final r = await db.query(
      'polls_gone',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  /// votes still waiting for a poll that never came: after an hour the
  /// poll is not coming, it burned or was deleted. dropped, and the marks
  /// of polls that went with them.
  Future<void> purgeStrayVotes({
    Duration after = const Duration(hours: 1),
  }) async {
    final db = await open();
    final cut = DateTime.now().subtract(after).millisecondsSinceEpoch;
    await db.rawDelete(
      'DELETE FROM poll_votes WHERE at < ? AND poll_uid NOT IN '
      '(SELECT msg_uid FROM messages WHERE msg_uid IS NOT NULL '
      'AND poll IS NOT NULL)',
      [cut],
    );
    await db.delete('polls_gone', where: 'at < ?', whereArgs: [cut]);
  }
}
