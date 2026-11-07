// SPDX-License-Identifier: GPL-3.0-or-later
// no device of mine is ever added without its notice: one function writes
// the row and the notice together, nothing else in the app writes the
// table, and the notice stays until the devices page is opened
import 'dart:convert';
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
    late String path;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      sql = SqliteChannel.install();
      dir = Directory.systemTemp.createTempSync('link_notice');
      if (sql == null) return;
      path = p.join(dir.path, 'n.db');
      db = await openDatabase(path);
      await db.execute(
        'CREATE TABLE identities (id INTEGER PRIMARY KEY, x_priv BLOB)',
      );
      await db.insert('identities', {'id': 0, 'x_priv': Uint8List(32)});
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
      await db.close();
      linkNotices.value = const [];
      db = await openDatabase(path);
      expect((await readLinkNotices(db)).length, 1);
      expect(linkNotices.value.single.name, 'Desk');
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
      // the same device key under a fresh uid is the same device
      final key = '05${'cd' * 32}';
      Future<void> addKey(String uid) => db.transaction(
        (tx) => addOwnDevice(
          tx,
          uid: uid,
          name: 'Lap',
          kind: DeviceKind.computer,
          linkedAt: DateTime(2026, 10, 30),
          keys: [(ident: 0, dev: 4, key: key, reg: 7)],
        ),
      );
      await addKey('u2');
      await expectLater(addKey('u3'), throwsA(isA<StateError>()));
      expect((await readLinkNotices(db)).length, 2);
      expect(
        await db.query('own_devices', where: 'uid = ?', whereArgs: ['u3']),
        isEmpty,
      );
    });

    test(
      'a new device is linked only once it is written, all at once',
      () async {
        if (sql == null) return;
        await db.execute(
          'CREATE TABLE IF NOT EXISTS signal_meta (k TEXT PRIMARY KEY, v TEXT)',
        );
        // a link that failed wrote nothing: after a restart it boots fresh
        await db.close();
        db = await openDatabase(path);
        expect(await linkedRoleOf(db), isFalse);
        final ident = Uint8List.fromList([5, ...List.filled(32, 0xab)]);
        // a row that does not fit rolls all of it back
        await expectLater(
          joinedRows(
            db,
            identity: ident,
            device: 3,
            rows: [
              {'t': 'no_such_table', 'put': {}},
            ],
            stream: Uint8List(32),
          ),
          throwsA(isA<StateError>()),
        );
        expect(await linkedRoleOf(db), isFalse);
        expect(await db.query('signal_meta'), isEmpty);
        // no list of the phone's among the rows: not linked
        await expectLater(
          joinedRows(
            db,
            identity: ident,
            device: 3,
            rows: const [],
            stream: Uint8List(32),
          ),
          throwsA(isA<StateError>()),
        );
        expect(await linkedRoleOf(db), isFalse);
        expect(await db.query('signal_meta'), isEmpty);
        await joinedRows(
          db,
          identity: ident,
          device: 3,
          rows: [
            {
              't': 'dev_lists',
              'put': {
                'ident': 0,
                'owner': 'me',
                'version': 1,
                'wire': base64Encode([1, 2, 3]),
              },
            },
          ],
          stream: Uint8List.fromList(List.filled(32, 7)),
        );
        await db.close();
        db = await openDatabase(path);
        expect(await linkedRoleOf(db), isTrue);
        final row = (await db.query('identities')).single;
        expect(row['ident_pub'], ident);
        expect(row['dev_id'], 3);
        expect(
          (await db.query(
            'signal_meta',
            where: 'k = ?',
            whereArgs: [kLinkStreamMeta],
          )).single['v'],
          base64Encode(List.filled(32, 7)),
        );
      },
    );

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

    test('a removed computer linked again is a new device: its key on its '
        'own row, the old one gone with its notice', () async {
      if (sql == null) return;
      final oldKey = '05${'ab' * 32}';
      final newKey = '05${'cd' * 32}';
      Future<void> add(String uid, String key, int dev) => db.transaction(
        (tx) => addOwnDevice(
          tx,
          uid: uid,
          name: 'Desk',
          kind: DeviceKind.computer,
          linkedAt: DateTime(2026, 11, 6, 9),
          keys: [(ident: 0, dev: dev, key: key, reg: 77)],
          stream: Uint8List(32),
        ),
      );
      await add('u1', oldKey, 9);
      final src = StoredOwnDevices(db: db, thisName: 'This phone');
      await src.opened();
      await markOwnDevicesGone(
        db,
        ['u1'],
        why: 'removed',
        at: DateTime(2026, 11, 6, 10).millisecondsSinceEpoch,
        notice: true,
      );
      expect(await ownDevicesWithKeys(db, 0, [(id: 9, key: oldKey)]), isEmpty);
      // the same computer, erased and linked again: a fresh key, a fresh
      // id, maybe the old id drawn again
      await add('u2', newKey, 9);
      expect(await ownDevicesWithKeys(db, 0, [(id: 9, key: newKey)]), ['u2']);
      expect(await ownDevicesWithKeys(db, 0, [(id: 9, key: oldKey)]), isEmpty);
      final n = await readLinkNotices(db);
      expect(
        [for (final x in n) (x.uid, x.why)],
        [('u1', 'removed'), ('u2', null)],
      );
      final all = await src.load();
      expect(all.where((d) => !d.thisDevice).length, 1);
      // a removed key linked again (no erase) is taken as a new device too
      await markOwnDevicesGone(
        db,
        ['u2'],
        why: 'removed',
        at: DateTime(2026, 11, 6, 11).millisecondsSinceEpoch,
        notice: true,
      );
      await add('u3', newKey, 12);
      expect(await ownDevicesWithKeys(db, 0, [(id: 12, key: newKey)]), ['u3']);
      await expectLater(add('u4', newKey, 13), throwsA(isA<StateError>()));
    });
  });
}
