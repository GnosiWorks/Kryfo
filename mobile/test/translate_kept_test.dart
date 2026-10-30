// SPDX-License-Identifier: GPL-3.0-or-later
// translations kept beside their message in the chat's encrypted database:
// read back with no model asked, gone with the message, its words, its
// chat or its contact, kept in the vault for a hidden chat, never in a
// copy that leaves the phone, and dropped from memory behind the lock
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart' show tidyCopy;
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/settings.dart';

import 'sqlite_ffi.dart';
import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';

KeptTranslation _k(String words, String text) =>
    KeptTranslation(KeptTranslation.hashOf(words), 'zh>en>none', text);

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  Future<SqliteMem> dbWith(
    List<(String chat, String uid, String words)> rows,
  ) async {
    final db = SqliteMem.open()!;
    await appSchemaOn(db);
    final chats = {for (final r in rows) r.$1};
    for (final c in chats) {
      await db.insert('contacts', {
        'halo_id': c,
        'onion': '',
        'xpub': 'ab',
        'first_seen': 1,
        'last_seen': 1,
      });
    }
    for (final (c, uid, words) in rows) {
      await db.insert('messages', {
        'peer_id': c,
        'direction': 'in',
        'plaintext': words,
        'sent_at': 1,
        'msg_uid': uid,
      });
    }
    return db;
  }

  test('kept and read back by chat', () async {
    final db = await dbWith([('heron', 'u1', _zh), ('wren', 'u2', _zh)]);
    final store = DbTranslateStore(() async => db);
    await store.keep('heron', 'u1', _k(_zh, _en), _zh);
    await store.keep('wren', 'u2', _k(_zh, 'other'), _zh);
    final got = await store.kept('heron');
    expect(got.keys, ['u1']);
    expect(got['u1']!.text, _en);
    expect(got['u1']!.src, KeptTranslation.hashOf(_zh));
    expect(got['u1']!.way, 'zh>en>none');
    // the words themselves are not kept, only their hash
    final raw = await db.query('translate_kept');
    expect(raw.any((r) => r.values.contains(_zh)), isFalse);
  }, skip: skip);

  test('nothing is kept for a message the database does not hold', () async {
    final db = await dbWith([('heron', 'u1', _zh)]);
    final store = DbTranslateStore(() async => db);
    await store.keep('heron', 'nope', _k(_zh, _en), _zh);
    expect(await store.kept('heron'), isEmpty);
  }, skip: skip);

  test('gone with its message, however it is deleted', () async {
    final db = await dbWith([('heron', 'u1', _zh), ('heron', 'u2', _zh)]);
    final store = DbTranslateStore(() async => db);
    await store.keep('heron', 'u1', _k(_zh, _en), _zh);
    await store.keep('heron', 'u2', _k(_zh, _en), _zh);
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: ['u1']);
    expect((await store.kept('heron')).keys, ['u2']);
  }, skip: skip);

  test('gone when its words are edited', () async {
    final db = await dbWith([('heron', 'u1', _zh)]);
    final store = DbTranslateStore(() async => db);
    await store.keep('heron', 'u1', _k(_zh, _en), _zh);
    // a change that leaves the words is not an edit
    await db.update('messages', {'delivered': 1});
    expect((await store.kept('heron')).keys, ['u1']);
    await db.update('messages', {'plaintext': '我们后天见'});
    expect(await store.kept('heron'), isEmpty);
  }, skip: skip);

  test('gone with the chat and with the contact', () async {
    final db = await dbWith([('heron', 'u1', _zh), ('wren', 'u2', _zh)]);
    final store = DbTranslateStore(() async => db);
    await store.keep('heron', 'u1', _k(_zh, _en), _zh);
    await store.keep('wren', 'u2', _k(_zh, _en), _zh);
    // a chat deleted with its contact row kept
    await forgetChatTranslate(() async => db, 'heron');
    expect(await store.kept('heron'), isEmpty);
    expect((await store.kept('wren')).keys, ['u2']);
    // the contact itself: the trigger takes it, before its messages go
    await db.delete('contacts', where: 'halo_id = ?', whereArgs: ['wren']);
    expect(await store.kept('wren'), isEmpty);
  }, skip: skip);

  test('a hidden chat keeps its translations in the vault only', () async {
    final primary = await dbWith([('heron', 'u1', _zh)]);
    final vault = await dbWith([('wren', 'v1', _zh)]);
    var open = true;
    final store = DbTranslateStore(
      () async => primary,
      chatDb: (id) async => id == 'wren' && open ? vault : primary,
    );
    await store.keep('wren', 'v1', _k(_zh, _en), _zh);
    expect((await store.kept('wren')).keys, ['v1']);
    expect(await DbTranslateStore(() async => primary).kept('wren'), isEmpty);
    // the vault shut: the everyday side has nothing of it
    open = false;
    expect(await store.kept('wren'), isEmpty);
  }, skip: skip);

  test('a copy that leaves the phone carries none, and still works', () async {
    final db = await dbWith([('heron', 'u1', _zh), ('heron', 'u2', _zh)]);
    final store = DbTranslateStore(() async => db);
    await store.keep('heron', 'u1', _k(_zh, _en), _zh);
    await tidyCopy(db);
    expect(await db.query('translate_kept'), isEmpty);
    // its triggers still find their table: deletes and edits go through
    await db.delete('messages', where: 'msg_uid = ?', whereArgs: ['u1']);
    await db.update('messages', {'plaintext': 'x'});
    expect(await db.query('messages'), hasLength(1));
  }, skip: skip);

  test('an edit landing while it was made leaves nothing kept', () async {
    final db = await dbWith([('heron', 'u1', '我们后天在车站见吧')]);
    final store = DbTranslateStore(() async => db);
    // made from the words before the edit, kept after it
    await store.keep('heron', 'u1', _k(_zh, _en), _zh);
    expect(await store.kept('heron'), isEmpty);
    // the words are only checked, never written
    expect(
      (await db.query('translate_kept')).any((r) => r.values.contains(_zh)),
      isFalse,
    );
  }, skip: skip);

  test('the tables are set up once per open database', () async {
    final db = await dbWith([('heron', 'u1', _zh)]);
    final store = DbTranslateStore(() async => db);
    await store.keep('heron', 'u1', _k(_zh, _en), _zh);
    await db.execute('DROP INDEX translate_kept_chat');
    await store.kept('heron');
    await store.unkeep('heron', 'u1');
    final idx = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE name = 'translate_kept_chat'",
    );
    expect(idx, isEmpty);
  }, skip: skip);

  test('the table comes with its triggers or not at all', () async {
    // a database with no messages table: a trigger cannot be made
    final db = SqliteMem.open()!;
    await db.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, onion TEXT)',
    );
    final store = DbTranslateStore(() async => db);
    await expectLater(store.kept('heron'), throwsA(anything));
    final made = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name LIKE 'translate_%'",
    );
    expect(made, isEmpty);
    // and it is tried again, not remembered as done
    await db.execute(
      'CREATE TABLE messages (msg_uid TEXT, plaintext TEXT, peer_id TEXT)',
    );
    expect(await store.kept('heron'), isEmpty);
  }, skip: skip);

  group('in a chat', () {
    test('made once, read back the next time with no model asked', () async {
      final f = fakeHub(installed: true, words: {_zh: _en});
      await f.hub.ready();
      final a = ChatTranslation(f.hub, 'heron');
      await Future<void>.delayed(Duration.zero);
      await a.toggle('u1', _zh);
      expect(a.of('u1', _zh).text, _en);
      expect(f.store.keptRows['heron']!['u1']!.text, _en);
      a.dispose();
      final asked = f.translator.asked.length;
      // the pack gone since: the kept one still shows
      await f.backend.remove('zh');
      await f.hub.downloads.refresh('zh');
      final b = ChatTranslation(f.hub, 'heron');
      addTearDown(b.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(await b.toggle('u1', _zh), isNull);
      expect(b.shown('u1', _zh), isTrue);
      expect(b.of('u1', _zh).text, _en);
      expect(f.translator.asked.length, asked);
    });

    test('a chat that always translates shows kept ones at once', () async {
      final f = fakeHub(installed: true, words: {_zh: _en});
      await f.hub.ready();
      f.store.keptRows['heron'] = {'u1': _k(_zh, _en)};
      await f.hub.setChatAuto('heron', true);
      await f.backend.remove('zh');
      await f.hub.downloads.refresh('zh');
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      c.of('u1', _zh);
      c.autoFor('u1', _zh);
      expect(c.shown('u1', _zh), isTrue);
      expect(f.translator.asked, isEmpty);
    });

    test('one kept for other words is dropped, not shown', () async {
      final f = fakeHub(installed: true);
      await f.hub.ready();
      f.store.keptRows['heron'] = {'u1': _k('旧的话我们明天见', 'old words')};
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.of('u1', _zh).text, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(f.store.keptRows['heron'], isEmpty);
    });

    test('one kept for another direction waits, unused', () async {
      final f = fakeHub(installed: true);
      await f.hub.ready();
      f.store.keptRows['heron'] = {
        'u1': KeptTranslation(KeptTranslation.hashOf(_zh), 'zh>de>none', 'x'),
      };
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.of('u1', _zh).text, isNull);
    });

    test('a message that burns takes its kept translation along', () async {
      final f = fakeHub(installed: true, words: {_zh: _en});
      await f.hub.ready();
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      await c.toggle('u1', _zh);
      expect(f.store.keptRows['heron'], contains('u1'));
      c.forget('u1', _zh);
      await Future<void>.delayed(Duration.zero);
      expect(f.store.keptRows['heron'], isNot(contains('u1')));
    });

    test('one with no uid yet is never kept', () async {
      final f = fakeHub(installed: true, words: {_zh: _en});
      await f.hub.ready();
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      final key = trKeyOf(null, 1700000000000);
      await c.toggle(key, _zh);
      expect(c.shown(key, _zh), isTrue);
      expect(f.store.keptRows['heron'] ?? const {}, isEmpty);
      expect(trKeyOf('abc', 1), 'abc');
    });

    test(
      'the lock: nothing held in memory, read again once it opens',
      () async {
        final f = fakeHub(installed: true, words: {_zh: _en});
        await f.hub.ready();
        f.store.keptRows['heron'] = {'u1': _k(_zh, _en)};
        final c = ChatTranslation(f.hub, 'heron');
        addTearDown(c.dispose);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(c.of('u1', _zh).text, _en);
        f.hub.lockedOut();
        expect(c.of('u1', _zh).text, isNull);
        expect(c.offer(_zh), isNull);
        f.hub.unlocked();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(c.of('u1', _zh).text, _en);
      },
    );

    test('translation off: kept ones are not read', () async {
      final store = _Reads(const TranslateSettings(on: false));
      final f = fakeHub(installed: true, words: {_zh: _en}, store: store);
      await f.hub.ready();
      store.keptRows['heron'] = {'u1': _k(_zh, _en)};
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      f.hub.lockedOut();
      f.hub.unlocked();
      await Future<void>.delayed(Duration.zero);
      expect(store.reads, 0);
      expect(c.of('u1', _zh).text, isNull);
    });
  });
}

// counts the reads of kept translations
class _Reads extends MemoryTranslateStore {
  _Reads(super.settings);
  int reads = 0;
  @override
  Future<Map<String, KeptTranslation>> kept(String chatId) {
    reads++;
    return super.kept(chatId);
  }
}
