// SPDX-License-Identifier: GPL-3.0-or-later
// translation's settings and each chat's auto-translate switch. they say
// which languages a person reads, so they are kept in the identity's
// encrypted database, never in plain preferences.
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:sqflite_sqlcipher/sqflite.dart';

class TranslateSettings {
  // translation offered at all
  final bool on;
  // languages read besides the app's own, as tags of kLanguageNames
  final List<String> mine;
  // what to translate into: '' for the app's language
  final String target;
  // a chat nobody set translates on its own
  final bool autoDefault;
  // model downloads wait for wi-fi
  final bool wifiOnly;
  // languages every chat nobody set translates on its own
  final List<String> always;
  // languages never offered, until the person takes one off the list
  final List<String> never;
  // times translation was turned off: each container drops its kept
  // translations once for each
  final int offs;

  const TranslateSettings({
    this.on = true,
    this.mine = const [],
    this.target = '',
    this.autoDefault = false,
    this.wifiOnly = true,
    this.always = const [],
    this.never = const [],
    this.offs = 0,
  });

  TranslateSettings copyWith({
    bool? on,
    List<String>? mine,
    String? target,
    bool? autoDefault,
    bool? wifiOnly,
    List<String>? always,
    List<String>? never,
    int? offs,
  }) => TranslateSettings(
    on: on ?? this.on,
    mine: mine ?? this.mine,
    target: target ?? this.target,
    autoDefault: autoDefault ?? this.autoDefault,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    always: always ?? this.always,
    never: never ?? this.never,
    offs: offs ?? this.offs,
  );

  Map<String, Object?> toJson() => {
    'on': on,
    'mine': mine,
    'target': target,
    'auto': autoDefault,
    'wifi': wifiOnly,
    'always': always,
    'never': never,
    'offs': offs,
  };

  static TranslateSettings fromJson(String? s) {
    if (s == null) return const TranslateSettings();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return TranslateSettings(
        on: j['on'] as bool? ?? true,
        mine: [for (final l in (j['mine'] as List? ?? const [])) l as String],
        target: j['target'] as String? ?? '',
        autoDefault: j['auto'] as bool? ?? false,
        wifiOnly: j['wifi'] as bool? ?? true,
        always: [
          for (final l in (j['always'] as List? ?? const [])) l as String,
        ],
        never: [for (final l in (j['never'] as List? ?? const [])) l as String],
        offs: (j['offs'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const TranslateSettings();
    }
  }
}

// a message's translation kept beside it: made from the words with this
// hash, in this direction
class KeptTranslation {
  final String src;
  final String way;
  final String text;
  const KeptTranslation(this.src, this.way, this.text);

  static String hashOf(String words) =>
      sha256.convert(utf8.encode(words)).toString();
}

abstract class TranslateStore {
  Future<TranslateSettings> load();
  Future<void> save(TranslateSettings s);
  // null when the chat was never set: the default applies
  Future<bool?> chatAuto(String chatId);
  Future<void> setChatAuto(String chatId, bool? on);
  // the person put the chat's translate bar away
  Future<bool> barHidden(String chatId);
  Future<void> setBarHidden(String chatId, bool hidden);
  // the chat's kept translations by message uid
  Future<Map<String, KeptTranslation>> kept(String chatId);
  // [words] are only checked against the message, never stored
  Future<void> keep(String chatId, String uid, KeptTranslation t, String words);
  Future<void> unkeep(String chatId, String uid);
  // every kept translation in the open containers goes, once per [offs]
  Future<void> dropKept(int offs);
}

class MemoryTranslateStore implements TranslateStore {
  TranslateSettings settings;
  final Map<String, bool> chats = {};
  MemoryTranslateStore([this.settings = const TranslateSettings()]);

  @override
  Future<TranslateSettings> load() async => settings;
  @override
  Future<void> save(TranslateSettings s) async => settings = s;
  @override
  Future<bool?> chatAuto(String chatId) async => chats[chatId];
  @override
  Future<void> setChatAuto(String chatId, bool? on) async =>
      on == null ? chats.remove(chatId) : chats[chatId] = on;
  final Set<String> barsHidden = {};
  @override
  Future<bool> barHidden(String chatId) async => barsHidden.contains(chatId);
  @override
  Future<void> setBarHidden(String chatId, bool hidden) async =>
      hidden ? barsHidden.add(chatId) : barsHidden.remove(chatId);
  final Map<String, Map<String, KeptTranslation>> keptRows = {};
  @override
  Future<Map<String, KeptTranslation>> kept(String chatId) async => {
    ...?keptRows[chatId],
  };
  @override
  Future<void> keep(
    String chatId,
    String uid,
    KeptTranslation t,
    String words,
  ) async => (keptRows[chatId] ??= {})[uid] = t;
  @override
  Future<void> unkeep(String chatId, String uid) async =>
      keptRows[chatId]?.remove(uid);
  int dropped = 0;
  @override
  Future<void> dropKept(int offs) async {
    if (offs <= dropped) return;
    dropped = offs;
    keptRows.clear();
  }
}

// two small tables, made when first used. a chat's rows go with its
// contact, a kept translation with its message or its words
class DbTranslateStore implements TranslateStore {
  // the identity's database, and the one a chat lives in (a hidden chat's
  // is the vault's)
  final Future<Database> Function() db;
  final Future<Database> Function(String chatId) chatDb;
  // every container open now: the primary, and the vault while it is open
  final Future<List<Database>> Function() open;
  DbTranslateStore(
    this.db, {
    Future<Database> Function(String)? chatDb,
    Future<List<Database>> Function()? open,
  }) : chatDb = chatDb ?? ((_) => db()),
       open = open ?? (() async => [await db()]);

  // the setup, once per open database
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
        CREATE TABLE IF NOT EXISTS translate_prefs (
          k TEXT PRIMARY KEY,
          v TEXT NOT NULL
        )
      ''')
      ..execute(
        'CREATE TRIGGER IF NOT EXISTS translate_prefs_follow AFTER DELETE ON '
        "contacts BEGIN DELETE FROM translate_prefs WHERE k IN ('chat:' || "
        "old.halo_id, 'bar:' || old.halo_id); END",
      )
      ..execute('''
        CREATE TABLE IF NOT EXISTS translate_kept (
          uid TEXT PRIMARY KEY,
          chat TEXT NOT NULL,
          src TEXT NOT NULL,
          way TEXT NOT NULL,
          body TEXT NOT NULL
        )
      ''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS translate_kept_chat ON '
        'translate_kept(chat)',
      )
      ..execute(
        'CREATE TRIGGER IF NOT EXISTS translate_kept_gone AFTER DELETE ON '
        'messages BEGIN DELETE FROM translate_kept WHERE uid = old.msg_uid; '
        'END',
      )
      ..execute(
        'CREATE TRIGGER IF NOT EXISTS translate_kept_edited AFTER UPDATE OF '
        'plaintext ON messages WHEN old.plaintext IS NOT new.plaintext BEGIN '
        'DELETE FROM translate_kept WHERE uid = old.msg_uid; END',
      )
      ..execute(
        'CREATE TRIGGER IF NOT EXISTS translate_kept_follow AFTER DELETE ON '
        'contacts BEGIN DELETE FROM translate_kept WHERE chat = old.halo_id; '
        'END',
      );
    await b.commit(noResult: true);
  }

  static Future<String?> _get(Database d, String k) async {
    final r = await d.query(
      'translate_prefs',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [k],
    );
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  static Future<void> _put(Database d, String k, String? v) async {
    if (v == null) {
      await d.delete('translate_prefs', where: 'k = ?', whereArgs: [k]);
      return;
    }
    await d.insert('translate_prefs', {
      'k': k,
      'v': v,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<TranslateSettings> load() async =>
      TranslateSettings.fromJson(await _get(await _ready(await db()), 'all'));

  @override
  Future<void> save(TranslateSettings s) async =>
      _put(await _ready(await db()), 'all', jsonEncode(s.toJson()));

  static String chatKey(String chatId) => 'chat:$chatId';
  static String barKey(String chatId) => 'bar:$chatId';

  @override
  Future<bool?> chatAuto(String chatId) async {
    final v = await _get(await _ready(await chatDb(chatId)), chatKey(chatId));
    return v == null ? null : v == '1';
  }

  @override
  Future<void> setChatAuto(String chatId, bool? on) async => _put(
    await _ready(await chatDb(chatId)),
    chatKey(chatId),
    on == null ? null : (on ? '1' : '0'),
  );

  @override
  Future<bool> barHidden(String chatId) async =>
      await _get(await _ready(await chatDb(chatId)), barKey(chatId)) == '1';

  @override
  Future<void> setBarHidden(String chatId, bool hidden) async => _put(
    await _ready(await chatDb(chatId)),
    barKey(chatId),
    hidden ? '1' : null,
  );

  @override
  Future<Map<String, KeptTranslation>> kept(String chatId) async {
    final d = await _ready(await chatDb(chatId));
    return {
      for (final r in await d.query(
        'translate_kept',
        where: 'chat = ?',
        whereArgs: [chatId],
      ))
        r['uid'] as String: KeptTranslation(
          r['src'] as String,
          r['way'] as String,
          r['body'] as String,
        ),
    };
  }

  // only for a message the chat's database holds with these very words, so
  // its triggers take it and an edit made meanwhile leaves nothing
  @override
  Future<void> keep(
    String chatId,
    String uid,
    KeptTranslation t,
    String words,
  ) async {
    final d = await _ready(await chatDb(chatId));
    await d.rawInsert(
      'INSERT OR REPLACE INTO translate_kept (uid, chat, src, way, body) '
      'SELECT ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM messages WHERE '
      'msg_uid = ? AND plaintext = ?)',
      [uid, chatId, t.src, t.way, t.text, uid, words],
    );
  }

  @override
  Future<void> unkeep(String chatId, String uid) async {
    final d = await _ready(await chatDb(chatId));
    await d.delete('translate_kept', where: 'uid = ?', whereArgs: [uid]);
  }

  // each container keeps the count it last dropped for, so a vault that
  // was shut catches up when it opens
  @override
  Future<void> dropKept(int offs) async {
    for (final d in await open()) {
      await _ready(d);
      await d.transaction((t) async {
        final r = await t.query(
          'translate_prefs',
          columns: ['v'],
          where: 'k = ?',
          whereArgs: ['offs'],
        );
        final had = r.isEmpty ? 0 : int.tryParse('${r.first['v']}') ?? 0;
        if (had >= offs) return;
        await t.delete('translate_kept');
        await t.insert('translate_prefs', {
          'k': 'offs',
          'v': '$offs',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }
  }
}

// a chat deleted with its contact row kept: its switch, its bar and its
// kept translations go. no table yet means nothing was ever set
Future<void> forgetChatTranslate(
  Future<Database> Function() db,
  String chatId,
) async {
  try {
    await (await db()).delete(
      'translate_kept',
      where: 'chat = ?',
      whereArgs: [chatId],
    );
  } catch (_) {}
  try {
    await (await db()).delete(
      'translate_prefs',
      where: 'k IN (?, ?)',
      whereArgs: [
        DbTranslateStore.chatKey(chatId),
        DbTranslateStore.barKey(chatId),
      ],
    );
  } catch (_) {}
}
