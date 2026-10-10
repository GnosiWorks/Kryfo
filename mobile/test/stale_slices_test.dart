// SPDX-License-Identifier: GPL-3.0-or-later
// a file can come again in another number of slices under the same id: a
// photo an older version left unsent is cleaned before it goes, and its
// bytes change. what was held of the old bytes no longer fits and goes, so
// the new file is never counted, or put together, out of both. the
// database rules against rows kept in maps
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'source_body.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _c = 'contact-we-know';

void main() {
  test('slices of another total go when the file comes again', () async {
    final db = _Rows(MemDb());
    for (var i = 0; i < 3; i++) {
      expect(await db.putMediaChunk('m', i, 'old$i', 4, null, from: _c), i + 1);
    }
    // cleaned, one slice shorter: the first new slice is all there is
    expect(await db.putMediaChunk('m', 0, 'new0', 3, null, from: _c), 1);
    expect(await db.putMediaChunk('m', 1, 'new1', 3, null, from: _c), 2);
    expect(await db.mediaChunkSlice('m', 2), isNull);
    expect(await db.putMediaChunk('m', 2, 'new2', 3, null, from: _c), 3);
    expect(
      [for (var i = 0; i < 3; i++) await db.mediaChunkSlice('m', i)],
      ['new0', 'new1', 'new2'],
    );
  });

  test(
    'slices of the same total stay, and a slice sent again counts once',
    () async {
      final db = _Rows(MemDb());
      await db.putMediaChunk('m', 0, 'a', 3, null, from: _c);
      await db.putMediaChunk('m', 1, 'b', 3, null, from: _c);
      expect(await db.putMediaChunk('m', 1, 'b', 3, null, from: _c), 2);
      // another file's slices are its own
      await db.putMediaChunk('n', 0, 'x', 9, null, from: _c);
      expect(await db.putMediaChunk('m', 2, 'c', 3, null, from: _c), 3);
      expect(await db.mediaChunkSlice('n', 0), 'x');
    },
  );

  test('what is asked for again follows the latest total', () {
    final body = bodyOf(
      sourceOf('lib/main.dart'),
      'Future<void> noteMediaWant(',
    );
    expect(body, contains("'total = excluded.total, '"));
  });
}
