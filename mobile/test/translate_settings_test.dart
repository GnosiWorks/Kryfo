// SPDX-License-Identifier: GPL-3.0-or-later
// translation's settings and each chat's switch: kept in the identity's
// database, read back the same, off unless set, and a chat's row goes with
// its contact. there is no download host to set
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/settings.dart';

import 'sqlite_ffi.dart';

void main() {
  test('defaults: no auto, wi-fi only', () {
    const s = TranslateSettings();
    expect(s.autoDefault, isFalse);
    expect(s.wifiOnly, isTrue);
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
    );
    final back = TranslateSettings.fromJson(jsonEncode(s.toJson()));
    expect(back.mine, s.mine);
    expect(back.target, 'en');
    expect(back.autoDefault, isTrue);
    expect(back.wifiOnly, isFalse);
  });

  test('a host kept by an older build is not read, nor written back', () {
    final s = TranslateSettings.fromJson(
      '{"wifi":false,"host":"https://mirror.example/m/"}',
    );
    expect(s.wifiOnly, isFalse);
    expect(s.toJson().containsKey('host'), isFalse);
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
    // downloads wait for wi-fi until the person allows mobile data
    expect((await store.load()).wifiOnly, isTrue);
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
    expect(await store.barHidden('calm-grey-heron'), isFalse);
    await store.setBarHidden('calm-grey-heron', true);
    await store.setBarHidden('quick-red-fox', true);
    expect(await store.barHidden('calm-grey-heron'), isTrue);

    await db.delete(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: ['calm-grey-heron'],
    );
    expect(await store.chatAuto('calm-grey-heron'), isNull);
    expect(await store.chatAuto('quick-red-fox'), isFalse);
    // the bar's flag goes with the contact too
    expect(await store.barHidden('calm-grey-heron'), isFalse);
    expect(await store.barHidden('quick-red-fox'), isTrue);
    // the settings stay
    expect((await store.load()).autoDefault, isTrue);
    await db.close();
  }, skip: skip);
}
