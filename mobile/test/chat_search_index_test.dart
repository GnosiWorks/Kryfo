// SPDX-License-Identifier: GPL-3.0-or-later
// find in one chat: the index of the chat's own database, only this chat's
// rows, in the chat's order; where a jump to a far one loads from; a
// message that is gone is said to be gone. and the hits a screen walks
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_find.dart';
import 'package:kryfo/main.dart' show chatHitsIn, chatStartIn;

import 'sqlite_ffi.dart';

const _now = 1700000000000;

Future<SqliteMem> _rows() async {
  final db = SqliteMem.open()!;
  await db.execute(
    'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, '
    'accepted INTEGER NOT NULL DEFAULT 1, blocked INTEGER NOT NULL DEFAULT 0)',
  );
  await db.execute(
    'CREATE TABLE messages (id INTEGER PRIMARY KEY, msg_uid TEXT, '
    'peer_id TEXT, group_id TEXT, direction TEXT, plaintext TEXT, '
    'sent_at INTEGER, written_at INTEGER, media_path TEXT, file_path TEXT, '
    'file_name TEXT, sticker TEXT, burn_at INTEGER, burn_secs INTEGER, '
    'burn_unseen INTEGER NOT NULL DEFAULT 0)',
  );
  await db.execute(
    "CREATE VIRTUAL TABLE msg_fts USING fts5(body, tokenize = 'unicode61')",
  );
  await db.execute(
    "INSERT INTO contacts VALUES ('ana', 1, 0), ('bo', 1, 0), ('cy', 1, 1)",
  );
  return db;
}

var _id = 0;
Future<int> _add(
  SqliteMem db, {
  String peer = 'ana',
  String? group,
  String dir = 'in',
  String text = 'lunch at noon',
  int? at,
  String? sticker,
  int? burnAt,
  String? media,
}) async {
  final id = ++_id;
  await db.execute(
    'INSERT INTO messages (id, msg_uid, peer_id, group_id, direction, '
    'plaintext, sent_at, written_at, sticker, burn_at, media_path) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      'u$id',
      peer,
      group,
      dir,
      text,
      at ?? id,
      at ?? id,
      sticker,
      burnAt,
      media,
    ],
  );
  await db.execute('INSERT INTO msg_fts (rowid, body) VALUES (?, ?)', [
    id,
    text,
  ]);
  return id;
}

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  group('the index of one chat', () {
    test('only this chat: not another person, not a group', () async {
      final db = await _rows();
      final a1 = await _add(db);
      final a2 = await _add(db, dir: 'out');
      await _add(db, peer: 'bo');
      await _add(db, group: 'g1');
      final hits = await chatHitsIn(db, '"lunch"*', peerId: 'ana');
      expect([for (final h in hits) h.id], [a1, a2]);
      final inGroup = await chatHitsIn(db, '"lunch"*', groupId: 'g1');
      expect(inGroup, hasLength(1));
    }, skip: skip);

    test('in the order the chat shows, not the order rows came', () async {
      final db = await _rows();
      final late = await _add(db, at: 500);
      final early = await _add(db, at: 100);
      final hits = await chatHitsIn(db, '"lunch"*', peerId: 'ana');
      expect([for (final h in hits) h.id], [early, late]);
      expect(hits.first.at, 100);
    }, skip: skip);

    test('no sticker, nothing past its time, no blocked member', () async {
      final db = await _rows();
      final kept = await _add(db, group: 'g');
      await _add(db, group: 'g', sticker: 'p:1');
      await _add(db, group: 'g', burnAt: 5);
      final timed = await _add(
        db,
        group: 'g',
        burnAt: DateTime.now().millisecondsSinceEpoch + 60000,
      );
      await _add(db, group: 'g', peer: 'cy');
      final hits = await chatHitsIn(db, '"lunch"*', groupId: 'g');
      expect([for (final h in hits) h.id], [kept, timed]);
    }, skip: skip);

    test(
      'a request still waiting: words only, never what came with a file',
      () async {
        final db = await _rows();
        final words = await _add(db);
        await _add(db, media: '/m/a.jpg');
        final mine = await _add(db, dir: 'out', media: '/m/b.jpg');
        final hits = await chatHitsIn(
          db,
          '"lunch"*',
          peerId: 'ana',
          wordsOnly: true,
        );
        expect([for (final h in hits) h.id], [words, mine]);
      },
      skip: skip,
    );
  });

  group('a jump to a far one', () {
    test('loads from thirty rows above it, in this chat', () async {
      final db = await _rows();
      final ids = <int>[];
      for (var i = 0; i < 100; i++) {
        ids.add(await _add(db, at: _now + i));
        await _add(db, peer: 'bo', at: _now + i);
      }
      final from = await chatStartIn(db, ids[50], peerId: 'ana');
      expect(from?.id, ids[20]);
      expect(from?.at, _now + 20);
      // near the top, it starts at the first
      expect((await chatStartIn(db, ids[3], peerId: 'ana'))?.id, ids[0]);
    }, skip: skip);

    test('gone, burned or not this chat: nothing to load', () async {
      final db = await _rows();
      final theirs = await _add(db, peer: 'bo');
      final burned = await _add(db, burnAt: 5);
      expect(await chatStartIn(db, theirs, peerId: 'ana'), isNull);
      expect(await chatStartIn(db, burned, peerId: 'ana'), isNull);
      expect(await chatStartIn(db, 9999, peerId: 'ana'), isNull);
      expect(await chatStartIn(db, theirs, groupId: 'g'), isNull);
    }, skip: skip);
  });

  group('the hits a screen walks', () {
    test('the newest first; up is older, wrapping', () async {
      final f = ChatFind();
      await f.look(
        'lunch',
        (_) async => [(id: 1, at: 10), (id: 2, at: 20), (id: 3, at: 30)],
        const [],
      );
      expect(f.count, 3);
      expect(f.shown, 3);
      expect(f.current, 3);
      expect(f.step(-1), 2);
      expect(f.step(-1), 1);
      expect(f.step(-1), 3);
      expect(f.step(1), 1);
    });

    test('rows on screen the index has not taken in yet are found', () async {
      final f = ChatFind();
      await f.look('cafe', (_) async => [(id: 1, at: 10)], [
        (id: 1, at: 10, text: 'café'),
        (id: 5, at: 50, text: 'a CAFÉ crème'),
        (id: 6, at: 60, text: 'tea'),
      ]);
      expect([for (final h in f.hits) h.id], [1, 5]);
    });

    test('an index that fails leaves what is on screen', () async {
      final f = ChatFind();
      await f.look('tea', (_) async => throw StateError('no index'), [
        (id: 6, at: 60, text: 'tea'),
      ]);
      expect(f.current, 6);
    });

    test('a newer question wins over a slower older one', () async {
      final f = ChatFind();
      final slow = f.look('lun', (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return [(id: 1, at: 1)];
      }, const []);
      final fast = await f.look(
        'lunch',
        (_) async => [(id: 2, at: 2)],
        const [],
      );
      expect(fast, isTrue);
      expect(await slow, isFalse);
      expect(f.query, 'lunch');
      expect(f.current, 2);
    });

    test('a gone hit drops out and the place holds', () async {
      final f = ChatFind();
      await f.look(
        'x',
        (_) async => [(id: 1, at: 1), (id: 2, at: 2), (id: 3, at: 3)],
        const [],
      );
      f.step(-1);
      expect(f.current, 2);
      f.drop(1);
      expect(f.current, 2);
      expect(f.count, 2);
      f.drop(3);
      f.drop(2);
      expect(f.current, isNull);
      expect(f.shown, 0);
    });

    test('nothing to look for: no hits, no question asked', () async {
      final f = ChatFind();
      var asked = 0;
      await f.look('  ?? ', (_) async {
        asked++;
        return const [];
      }, const []);
      expect(asked, 0);
      expect(f.count, 0);
    });
  });

  test('a slow line shows only after the wait, and goes when done', () async {
    final seen = <bool>[];
    final line = SlowLine(seen.add, after: const Duration(milliseconds: 30));
    await line.over(() async {});
    expect(seen, isEmpty);
    await line.over(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    expect(seen, [true, false]);
  });
}
