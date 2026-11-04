// SPDX-License-Identifier: GPL-3.0-or-later
// voice note transcripts kept beside their note, in the encrypted database
// that holds it (the vault's for a hidden chat). a row goes with its
// message however that goes (deleted, unsent, burned, the chat or the
// contact or the group deleted) and is never in a copy that leaves the
// phone. the settings are the identity's, in its own database.
import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

/// the transcripts' settings for one identity
class VoiceTxSettings {
  // offered under voice notes at all
  final bool on;
  // times it was turned off: each container drops its transcripts once for
  // each
  final int offs;
  const VoiceTxSettings({this.on = true, this.offs = 0});

  VoiceTxSettings copyWith({bool? on, int? offs}) =>
      VoiceTxSettings(on: on ?? this.on, offs: offs ?? this.offs);

  Map<String, Object?> toJson() => {'on': on, 'offs': offs};

  static VoiceTxSettings fromJson(String? s) {
    if (s == null) return const VoiceTxSettings();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return VoiceTxSettings(
        on: j['on'] as bool? ?? true,
        offs: (j['offs'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const VoiceTxSettings();
    }
  }
}

/// one stretch of words and where it sits in the note
class TxPiece {
  final int startMs;
  final int endMs;
  final String text;
  const TxPiece(this.startMs, this.endMs, this.text);
}

/// a note's transcript as kept: the words by stretch, the language the
/// model heard, which model made it, and whether it was left open
class KeptTranscript {
  final String lang;
  final String model;
  final List<TxPiece> pieces;
  final bool open;
  const KeptTranscript({
    required this.lang,
    required this.model,
    required this.pieces,
    this.open = true,
  });

  String get text => pieces.map((p) => p.text).join().trim();

  KeptTranscript opened(bool open) =>
      KeptTranscript(lang: lang, model: model, pieces: pieces, open: open);

  String piecesJson() => jsonEncode([
    for (final p in pieces) [p.startMs, p.endMs, p.text],
  ]);

  static List<TxPiece> piecesOf(String s) {
    try {
      return [
        for (final e in jsonDecode(s) as List)
          TxPiece((e[0] as num).toInt(), (e[1] as num).toInt(), e[2] as String),
      ];
    } catch (_) {
      return const [];
    }
  }
}

abstract class VoiceTxStore {
  Future<VoiceTxSettings> load();
  Future<void> save(VoiceTxSettings s);
  // the chat's transcripts by message uid
  Future<Map<String, KeptTranscript>> kept(String chatId);
  Future<void> keep(String chatId, String uid, KeptTranscript t);
  Future<void> setOpen(String chatId, String uid, bool open);
  Future<void> unkeep(String chatId, String uid);
  // every transcript in the open containers goes, once per [offs]
  Future<void> dropAll(int offs);
}

class MemoryVoiceTxStore implements VoiceTxStore {
  VoiceTxSettings settings;
  MemoryVoiceTxStore([this.settings = const VoiceTxSettings()]);

  // uids a keep is refused for: a message the database does not hold
  final Set<String> gone = {};
  final Map<String, Map<String, KeptTranscript>> rows = {};
  int dropped = 0;

  @override
  Future<VoiceTxSettings> load() async => settings;
  @override
  Future<void> save(VoiceTxSettings s) async => settings = s;
  @override
  Future<Map<String, KeptTranscript>> kept(String chatId) async => {
    ...?rows[chatId],
  };
  @override
  Future<void> keep(String chatId, String uid, KeptTranscript t) async {
    if (gone.contains(uid)) return;
    (rows[chatId] ??= {})[uid] = t;
  }

  @override
  Future<void> setOpen(String chatId, String uid, bool open) async {
    final r = rows[chatId]?[uid];
    if (r != null) rows[chatId]![uid] = r.opened(open);
  }

  @override
  Future<void> unkeep(String chatId, String uid) async =>
      rows[chatId]?.remove(uid);
  @override
  Future<void> dropAll(int offs) async {
    if (offs <= dropped) return;
    dropped = offs;
    rows.clear();
  }
}

/// the table's name, for the copies that empty it (backup.dart)
const kVoiceTxTable = 'voice_tx';

class DbVoiceTxStore implements VoiceTxStore {
  // the identity's database, the one a chat lives in, and every container
  // open now (the primary, and the vault while it is open)
  final Future<Database> Function() db;
  final Future<Database> Function(String chatId) chatDb;
  final Future<List<Database>> Function() open;
  DbVoiceTxStore(
    this.db, {
    Future<Database> Function(String)? chatDb,
    Future<List<Database>> Function()? open,
  }) : chatDb = chatDb ?? ((_) => db()),
       open = open ?? (() async => [await db()]);

  static final _made = Expando<Future<void>>();

  static Future<Database> _ready(Database d) async {
    final f = _made[d] ??= _make(d);
    try {
      await f;
    } catch (_) {
      _made[d] = null;
      rethrow;
    }
    return d;
  }

  // the tables and their triggers in one go: a table without its triggers
  // would outlive what it belongs to
  static Future<void> _make(Database d) async {
    final b = d.batch()
      ..execute('''
        CREATE TABLE IF NOT EXISTS voice_prefs (
          k TEXT PRIMARY KEY,
          v TEXT NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS voice_tx (
          uid TEXT PRIMARY KEY,
          chat TEXT NOT NULL,
          lang TEXT NOT NULL,
          model TEXT NOT NULL,
          pieces TEXT NOT NULL,
          open INTEGER NOT NULL DEFAULT 1
        )
      ''')
      ..execute('CREATE INDEX IF NOT EXISTS voice_tx_chat ON voice_tx(chat)')
      ..execute(
        'CREATE TRIGGER IF NOT EXISTS voice_tx_gone AFTER DELETE ON messages '
        'BEGIN DELETE FROM voice_tx WHERE uid = old.msg_uid; END',
      )
      // the note's file let go (cleared to free space, say): nothing left
      // to have been heard
      ..execute(
        'CREATE TRIGGER IF NOT EXISTS voice_tx_unfiled AFTER UPDATE OF '
        'file_path ON messages WHEN new.file_path IS NULL BEGIN DELETE FROM '
        'voice_tx WHERE uid = old.msg_uid; END',
      )
      ..execute(
        'CREATE TRIGGER IF NOT EXISTS voice_tx_follow AFTER DELETE ON '
        'contacts BEGIN DELETE FROM voice_tx WHERE chat = old.halo_id; END',
      );
    await b.commit(noResult: true);
  }

  static Future<String?> _get(Database d, String k) async {
    final r = await d.query(
      'voice_prefs',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [k],
    );
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  @override
  Future<VoiceTxSettings> load() async =>
      VoiceTxSettings.fromJson(await _get(await _ready(await db()), 'all'));

  @override
  Future<void> save(VoiceTxSettings s) async {
    final d = await _ready(await db());
    await d.insert('voice_prefs', {
      'k': 'all',
      'v': jsonEncode(s.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, KeptTranscript>> kept(String chatId) async {
    final d = await _ready(await chatDb(chatId));
    return {
      for (final r in await d.query(
        'voice_tx',
        where: 'chat = ?',
        whereArgs: [chatId],
      ))
        r['uid'] as String: KeptTranscript(
          lang: r['lang'] as String,
          model: r['model'] as String,
          pieces: KeptTranscript.piecesOf(r['pieces'] as String),
          open: (r['open'] as num?)?.toInt() != 0,
        ),
    };
  }

  // only for a note this chat's database holds, with its file still there,
  // so its triggers take it and one that went meanwhile leaves nothing
  @override
  Future<void> keep(String chatId, String uid, KeptTranscript t) async {
    final d = await _ready(await chatDb(chatId));
    await d.rawInsert(
      'INSERT OR REPLACE INTO voice_tx (uid, chat, lang, model, pieces, open) '
      'SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM messages WHERE '
      'msg_uid = ? AND file_path IS NOT NULL AND (peer_id = ? OR '
      'group_id = ?))',
      [
        uid,
        chatId,
        t.lang,
        t.model,
        t.piecesJson(),
        t.open ? 1 : 0,
        uid,
        chatId,
        chatId,
      ],
    );
  }

  @override
  Future<void> setOpen(String chatId, String uid, bool open) async {
    final d = await _ready(await chatDb(chatId));
    await d.update(
      'voice_tx',
      {'open': open ? 1 : 0},
      where: 'uid = ? AND chat = ?',
      whereArgs: [uid, chatId],
    );
  }

  @override
  Future<void> unkeep(String chatId, String uid) async {
    final d = await _ready(await chatDb(chatId));
    await d.delete('voice_tx', where: 'uid = ?', whereArgs: [uid]);
  }

  // each container keeps the count it last dropped for, so a vault that
  // was shut catches up when it opens
  @override
  Future<void> dropAll(int offs) async {
    for (final d in await open()) {
      await _ready(d);
      await d.transaction((t) async {
        final r = await t.query(
          'voice_prefs',
          columns: ['v'],
          where: 'k = ?',
          whereArgs: ['offs'],
        );
        final had = r.isEmpty ? 0 : int.tryParse('${r.first['v']}') ?? 0;
        if (had >= offs) return;
        await t.delete('voice_tx');
        await t.insert('voice_prefs', {
          'k': 'offs',
          'v': '$offs',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }
  }
}
