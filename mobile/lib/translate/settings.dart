// SPDX-License-Identifier: GPL-3.0-or-later
// translation's settings and each chat's auto-translate switch. they say
// which languages a person reads, so they are kept in the identity's
// encrypted database, never in plain preferences.
import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

class TranslateSettings {
  // languages read besides the app's own, as tags of kLanguageNames
  final List<String> mine;
  // what to translate into: '' for the app's language
  final String target;
  // a chat nobody set translates on its own
  final bool autoDefault;
  // model downloads wait for wi-fi
  final bool wifiOnly;
  // a mirror for the models, '' for the manifest's own host
  final String host;

  const TranslateSettings({
    this.mine = const [],
    this.target = '',
    this.autoDefault = false,
    this.wifiOnly = true,
    this.host = '',
  });

  TranslateSettings copyWith({
    List<String>? mine,
    String? target,
    bool? autoDefault,
    bool? wifiOnly,
    String? host,
  }) => TranslateSettings(
    mine: mine ?? this.mine,
    target: target ?? this.target,
    autoDefault: autoDefault ?? this.autoDefault,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    host: host ?? this.host,
  );

  Map<String, Object?> toJson() => {
    'mine': mine,
    'target': target,
    'auto': autoDefault,
    'wifi': wifiOnly,
    'host': host,
  };

  static TranslateSettings fromJson(String? s) {
    if (s == null) return const TranslateSettings();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return TranslateSettings(
        mine: [for (final l in (j['mine'] as List? ?? const [])) l as String],
        target: j['target'] as String? ?? '',
        autoDefault: j['auto'] as bool? ?? false,
        wifiOnly: j['wifi'] as bool? ?? true,
        host: j['host'] as String? ?? '',
      );
    } catch (_) {
      return const TranslateSettings();
    }
  }
}

// a mirror has to be https, a host and a path, nothing else: what the
// engine's manifest takes. '' is the default host
bool hostOk(String s) {
  if (s.isEmpty) return true;
  final u = Uri.tryParse(s);
  return u != null &&
      u.scheme == 'https' &&
      u.host.isNotEmpty &&
      u.userInfo.isEmpty &&
      !u.hasQuery &&
      !u.hasFragment;
}

abstract class TranslateStore {
  Future<TranslateSettings> load();
  Future<void> save(TranslateSettings s);
  // null when the chat was never set: the default applies
  Future<bool?> chatAuto(String chatId);
  Future<void> setChatAuto(String chatId, bool? on);
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
}

// one small table, made when first used. a chat's row goes with its contact
class DbTranslateStore implements TranslateStore {
  // the identity's database, and the one a chat lives in (a hidden chat's
  // is the vault's)
  final Future<Database> Function() db;
  final Future<Database> Function(String chatId) chatDb;
  DbTranslateStore(this.db, {Future<Database> Function(String)? chatDb})
    : chatDb = chatDb ?? ((_) => db());

  static Future<Database> _ready(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS translate_prefs (
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL
      )
    ''');
    await d.execute(
      'CREATE TRIGGER IF NOT EXISTS translate_prefs_follow AFTER DELETE ON '
      "contacts BEGIN DELETE FROM translate_prefs WHERE k = 'chat:' || "
      'old.halo_id; END',
    );
    return d;
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

  @override
  Future<bool?> chatAuto(String chatId) async {
    final v = await _get(await _ready(await chatDb(chatId)), 'chat:$chatId');
    return v == null ? null : v == '1';
  }

  @override
  Future<void> setChatAuto(String chatId, bool? on) async => _put(
    await _ready(await chatDb(chatId)),
    'chat:$chatId',
    on == null ? null : (on ? '1' : '0'),
  );
}
