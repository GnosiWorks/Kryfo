// SPDX-License-Identifier: GPL-3.0-or-later
// a phone coming from 0.6.0 has every older device table and none of the
// developer inbox's: the open makes them, or a removal of a contact and
// a held answer would reach for a table that is not there
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_store.dart'
    show deviceTables, deviceTablesAtOpen;

import 'sqlite_ffi.dart';

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  for (final t in ['own_answers_held', 'own_answers_seen']) {
    test('a 0.6.0 file gets $t at its next open', () async {
      final s = SqliteMem.open()!;
      await appSchemaOn(s);
      Future<void> add(d, String sql) async {
        try {
          await d.execute(sql);
        } catch (_) {
          // a column the schema has already
        }
      }

      await deviceTables(s, add);
      // as 0.6.0 left it, every other table there
      await s.execute('DROP TABLE $t');
      await deviceTablesAtOpen(s, add);
      final r = await s.rawQuery(
        'SELECT name FROM sqlite_master WHERE name = ?',
        [t],
      );
      expect(r, isNotEmpty);
      await s.close();
    }, skip: skip);
  }
}
