// SPDX-License-Identifier: GPL-3.0-or-later
// no device of mine is ever added without its notice: one function writes
// the row and the notice together, nothing else in the app writes the
// table, and the notice stays until the devices page is opened
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_store.dart';
import 'package:kryfo/devices/own_device_store.dart';
import 'package:kryfo/devices/own_devices.dart';
import 'package:kryfo/key_number.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'sqlite_channel.dart';

// a write into the devices tables, in any form the app could put it
final _writes = RegExp(
  r'''(insert|update|replace)\w*\(\s*['"](own_devices|own_device_keys)['"]|INSERT\s+(OR\s+\w+\s+)?INTO\s+(own_devices|own_device_keys)''',
  caseSensitive: false,
);

void main() {
  test(
    'only the one function writes a device of mine, and with its notice',
    () {
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in _writes.allMatches(f.readAsStringSync())) {
          hits.add('${p.relative(f.path, from: 'lib')}: ${m[0]}');
        }
      }
      // the store itself, and its rename (a name, never a new row) and the
      // notice it clears
      expect(
        hits.every((h) => h.startsWith('devices/own_device_store.dart')),
        isTrue,
        reason: hits.join('\n'),
      );
      final src = File('lib/devices/own_device_store.dart').readAsStringSync();
      final add = src.substring(src.indexOf('Future<void> addOwnDevice('));
      final body = add.substring(0, add.indexOf('\n}\n'));
      expect(body, contains("'notice': 1"));
      expect(
        RegExp(r"insert\(\s*'own_devices'").allMatches(src).length,
        1,
        reason: 'one insert of a device, in addOwnDevice',
      );
      // the scan catches what it is for
      expect(_writes.hasMatch("db.insert('own_devices', {})"), isTrue);
      expect(
        _writes.hasMatch('INSERT OR REPLACE INTO own_device_keys'),
        isTrue,
      );
    },
  );

  group('on a database', () {
    SqliteChannel? sql;
    late Directory dir;
    late Database db;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      sql = SqliteChannel.install();
      dir = Directory.systemTemp.createTempSync('link_notice');
      if (sql == null) return;
      db = await openDatabase(p.join(dir.path, 'n.db'));
      await db.execute(
        'CREATE TABLE identities (id INTEGER PRIMARY KEY, x_priv BLOB)',
      );
      await deviceTables(db, (d, s) async {
        try {
          await d.execute(s);
        } catch (_) {}
      });
    });

    tearDown(() async {
      if (sql != null) await db.close();
      sql?.uninstall();
      dir.deleteSync(recursive: true);
    });

    test('a device added says so until the page is opened', () async {
      if (sql == null) return;
      final key = '05${'ab' * 32}';
      await db.transaction(
        (tx) => addOwnDevice(
          tx,
          uid: 'u1',
          name: 'Desk',
          kind: DeviceKind.computer,
          linkedAt: DateTime(2026, 10, 30, 9),
          keys: [(ident: 0, dev: 9, key: key, reg: 77)],
          stream: Uint8List(32),
        ),
      );
      final n = await readLinkNotices(db);
      expect(n.single.name, 'Desk');
      expect(linkNotices.value.single.uid, 'u1');
      // still there after a restart: it lives in the row
      expect((await readLinkNotices(db)).length, 1);
      final src = StoredOwnDevices(db: db, thisName: 'This phone');
      final all = await src.load();
      expect(all.first.thisDevice, isTrue);
      final desk = all.last;
      expect(desk.name, 'Desk');
      expect(desk.code, keyNumberGroups([0x05, ...List.filled(32, 0xab)]));
      expect(src.canLink, isFalse, reason: 'no link without a way to link');
      await src.opened();
      expect(linkNotices.value, isEmpty);
      expect(await readLinkNotices(db), isEmpty);
      // a rename keeps it a single device, and brings no notice back
      await src.rename('u1', 'Work');
      expect((await src.load()).last.name, 'Work');
      expect(await readLinkNotices(db), isEmpty);
    });

    test('the same device twice is refused, its notice with it', () async {
      if (sql == null) return;
      Future<void> add() => db.transaction(
        (tx) => addOwnDevice(
          tx,
          uid: 'u1',
          name: 'Desk',
          kind: DeviceKind.computer,
          linkedAt: DateTime(2026, 10, 30),
          keys: const [],
        ),
      );
      await add();
      await expectLater(add(), throwsA(anything));
      expect((await readLinkNotices(db)).length, 1);
    });

    test(
      'a linked device lists itself and its phone, and links nothing',
      () async {
        if (sql == null) return;
        final src = StoredOwnDevices(
          db: db,
          thisName: 'This computer',
          thisKind: DeviceKind.computer,
          phoneName: 'Your phone',
          link: (code, h) => throw StateError('never'),
        );
        final all = await src.load();
        expect(all.map((d) => d.name), ['This computer', 'Your phone']);
        expect(all[1].isPhone, isTrue);
        expect(src.canLink, isFalse);
      },
    );
  });
}
