// SPDX-License-Identifier: GPL-3.0-or-later
// each session keeps its own translation settings and its own kept
// translations, like its other settings: what the everyday side set or
// kept is not seen from the decoy, and back
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/downloads.dart';
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/settings.dart';

import 'sqlite_ffi.dart';
import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  Future<SqliteMem> dbOf(String chat, String uid) async {
    final db = SqliteMem.open()!;
    await appSchemaOn(db);
    await db.insert('contacts', {
      'halo_id': chat,
      'onion': '',
      'xpub': 'ab',
      'first_seen': 1,
      'last_seen': 1,
    });
    await db.insert('messages', {
      'peer_id': chat,
      'direction': 'in',
      'plaintext': _zh,
      'sent_at': 1,
      'msg_uid': uid,
    });
    return db;
  }

  test('settings and kept translations stay with their session', () async {
    final everyday = await dbOf('heron', 'u1');
    final decoy = await dbOf('heron', 'u1');
    var now = 'everyday';
    SqliteMem db() => now == 'everyday' ? everyday : decoy;
    final backend = FakeBackend()..finish('zh');
    final downloads = ModelDownloads(
      backend: backend,
      onWifi: () async => true,
      wifiOnly: () => false,
    );
    final hub = TranslationHub(
      store: DbTranslateStore(() async => db()),
      translator: FakeTranslator(words: {_zh: 'Hello'}),
      downloads: downloads,
      appLang: () => 'en',
      scope: () => now,
    );
    await hub.ready();
    await hub.neverFor('ja');
    await hub.setChatAuto('heron', true);
    final c = ChatTranslation(hub, 'heron');
    await Future<void>.delayed(Duration.zero);
    await c.toggle('u1', _zh);
    expect(c.of('u1', _zh).text, 'Hello');
    c.dispose();
    expect(await DbTranslateStore(() async => everyday).kept('heron'), {
      'u1': isA<KeptTranslation>(),
    });

    // the decoy opens: none of it
    now = 'decoy';
    hub.forgetChats();
    await hub.ready();
    expect(hub.settings.never, isEmpty);
    expect(await hub.chatAuto('heron'), isFalse);
    expect(await hub.kept('heron'), isEmpty);
    final d = ChatTranslation(hub, 'heron');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(d.of('u1', _zh).text, isNull);
    // what the decoy sets stays there
    await hub.setOn(false);
    d.dispose();

    now = 'everyday';
    hub.forgetChats();
    await hub.ready();
    expect(hub.on, isTrue);
    expect(hub.settings.never, ['ja']);
    expect(await hub.chatAuto('heron'), isTrue);
    expect((await hub.kept('heron')).keys, ['u1']);
    expect(await DbTranslateStore(() async => decoy).kept('heron'), isEmpty);
  }, skip: skip);
}
