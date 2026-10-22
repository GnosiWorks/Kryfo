// SPDX-License-Identifier: GPL-3.0-or-later
// translation's settings and each chat's switch: kept in the identity's
// database, read back the same, off unless set, and a chat's row goes with
// its contact. a mirror has to be https
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/settings.dart';

import 'sqlite_ffi.dart';

void main() {
  test('defaults: no auto, wi-fi only, the manifest host', () {
    const s = TranslateSettings();
    expect(s.autoDefault, isFalse);
    expect(s.wifiOnly, isTrue);
    expect(s.host, '');
    expect(s.target, '');
    expect(TranslateSettings.fromJson(null).wifiOnly, isTrue);
    expect(TranslateSettings.fromJson('not json').autoDefault, isFalse);
  });

  test('settings go through json unchanged', () {
    const s = TranslateSettings(
      mine: ['de', 'zh'],
      target: 'en',
      autoDefault: true,
      wifiOnly: false,
      host: 'https://mirror.example/m/',
    );
    final back = TranslateSettings.fromJson(jsonEncode(s.toJson()));
    expect(back.mine, s.mine);
    expect(back.target, 'en');
    expect(back.autoDefault, isTrue);
    expect(back.wifiOnly, isFalse);
    expect(back.host, s.host);
  });

  test('a mirror has to be https and nothing more', () {
    expect(hostOk(''), isTrue);
    expect(hostOk('https://mirror.example/models/'), isTrue);
    for (final bad in [
      'http://mirror.example/',
      'mirror.example',
      'https://user:pw@mirror.example/',
      'https://mirror.example/?a=b',
      'https://mirror.example/#x',
      'ftp://mirror.example/',
    ]) {
      expect(hostOk(bad), isFalse, reason: bad);
    }
  });

  test('the memory store: a chat unset is null, set is kept', () async {
    final m = MemoryTranslateStore();
    expect(await m.chatAuto('a'), isNull);
    await m.setChatAuto('a', true);
    expect(await m.chatAuto('a'), isTrue);
    await m.setChatAuto('a', null);
    expect(await m.chatAuto('a'), isNull);
  });

  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test('in the database: settings, chats, and a chat gone with its '
      'contact', () async {
    final db = SqliteMem.open()!;
    await appSchemaOn(db);
    final store = DbTranslateStore(() async => db);
    expect((await store.load()).autoDefault, isFalse);
    await store.save(const TranslateSettings(autoDefault: true, mine: ['de']));
    expect((await store.load()).autoDefault, isTrue);
    expect((await store.load()).mine, ['de']);

    for (final id in ['calm-grey-heron', 'quick-red-fox']) {
      await db.insert('contacts', {
        'halo_id': id,
        'onion': '',
        'xpub': 'ab',
        'first_seen': 1,
        'last_seen': 1,
      });
    }
    expect(await store.chatAuto('calm-grey-heron'), isNull);
    await store.setChatAuto('calm-grey-heron', true);
    await store.setChatAuto('quick-red-fox', false);
    expect(await store.chatAuto('calm-grey-heron'), isTrue);
    expect(await store.chatAuto('quick-red-fox'), isFalse);

    await db.delete(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: ['calm-grey-heron'],
    );
    expect(await store.chatAuto('calm-grey-heron'), isNull);
    expect(await store.chatAuto('quick-red-fox'), isFalse);
    // the settings stay
    expect((await store.load()).autoDefault, isTrue);
    await db.close();
  }, skip: skip);
}
