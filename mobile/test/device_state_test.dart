// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, db 95: the tables come to every file (a 0.5.3 phone's,
// one at 94, one at a later number without them, a new one), and the
// engine's state goes into them and comes back from them after a restart
// with the shim checking every list. a message that opens from a contact's
// phone tells the engine through the session layer, and only with the
// switch on
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/own_devices.dart' show kLinkedDevicesOn;
import 'package:kryfo/identities.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        HaloEngine,
        devMineOf,
        deviceStateForTest,
        processPeerBundle,
        signalDecrypt,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'host_engine.dart';
import 'mem_db.dart';
import 'signal_kit.dart';
import 'signal_ls/shim_lib.dart' show shim;
import 'sqlite_channel.dart';

const _fixtures = 'test/fixtures/upgrade_053';
const _files = ['halo.db', 'halo_d.db', 'halo_v.db', 'peers.db'];
const _devTables = [
  'dev_lists',
  'dev_proven',
  'dev_pq',
  'dev_quiet',
  'dev_pool',
  'dev_held_openers',
  'dev_pushes',
  'own_devices',
  'own_device_keys',
  'dev_out',
  'dev_marks',
];
// what a 0.5.3 phone and every step since hold, counted before and after
const _kept = [
  'contacts',
  'messages',
  'groups',
  'group_members',
  'sessions',
  'prekeys',
  'signed_prekeys',
  'peer_identities',
  'identities',
  'pairs',
];

final _keyFile =
    (jsonDecode(File('$_fixtures/keys.json').readAsStringSync()) as Map)
        .cast<String, String>();

final bool _engine = loadHostEngine();

Future<bool> _has(Database db, String table) async => (await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
  [table],
)).isNotEmpty;

Future<Map<String, int>> _counts(Database db) async => {
  for (final t in _kept)
    if (await _has(db, t))
      t: Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $t'))!,
};

Future<Set<String>> _cols(Database db, String table) async => {
  for (final c in await db.rawQuery("PRAGMA table_info('$table')"))
    c['name'] as String,
};

// a KDL2 list as the phone signs it: the phone first, then each device
Uint8List _list(
  LsIdentity id,
  int version,
  List<({int dev, Uint8List key, int reg})> devices,
) {
  final b = BytesBuilder()
    ..add(ascii.encode('KDL2'))
    ..add(id.public);
  final v = ByteData(8)..setUint64(0, version);
  b
    ..add(v.buffer.asUint8List())
    ..addByte(devices.length + 1);
  void entry(int dev, Uint8List key, int reg, int flags) {
    final r = ByteData(4)..setUint32(0, reg);
    b
      ..addByte(dev)
      ..add(key)
      ..add(r.buffer.asUint8List())
      ..addByte(flags);
  }

  entry(1, id.public, 1111, 1);
  for (final d in devices) {
    entry(d.dev, d.key, d.reg, 0);
  }
  final body = b.toBytes();
  return Uint8List.fromList([
    ...body,
    ...shim!.sign(id, LsSigContext.deviceList, body),
  ]);
}

class _Engine implements HaloEngine {
  _Engine(this.x);
  final String x;
  @override
  String myXPubkey() => x;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  final opened = <HaloDb>[];

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('device_state');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': _keyFile['everyday']!,
      'halo.d.key': _keyFile['decoy']!,
    });
    SharedPreferences.setMockInitialValues({});
    useDevKeysForTest(null);
    linkedDevicesForTest = false;
    deviceStateForTest(null);
  });

  tearDown(() async {
    for (final d in opened) {
      await d.close();
    }
    opened.clear();
    linkedDevicesForTest = false;
    deviceStateForTest(null);
    sql?.uninstall();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip() {
    if (sql != null) return false;
    markTestSkipped('no sqlite on this host');
    return true;
  }

  Future<Database> open([HaloContainer c = HaloContainer.everyday]) async {
    final d = HaloDb(c);
    opened.add(d);
    return d.open();
  }

  Future<void> closeAll() async {
    for (final d in opened) {
      await d.close();
    }
    opened.clear();
  }

  void copyFixtures() {
    for (final f in _files) {
      File('$_fixtures/$f').copySync(p.join(docs.path, f));
    }
  }

  Future<void> tablesThere(Database db, {String? reason}) async {
    for (final t in _devTables) {
      expect(await _has(db, t), isTrue, reason: '$t $reason');
      expect(
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $t')),
        0,
        reason: '$t $reason',
      );
    }
    expect(await _cols(db, 'identities'), containsAll(['dev_id', 'ident_pub']));
    for (final r in await db.query('identities')) {
      expect(r['dev_id'], 1);
      expect(r['ident_pub'], isNull);
    }
  }

  test('the switch is on in this build; off is a test\'s', () {
    expect(kLinkedDevicesOn, isTrue);
    linkedDevicesForTest = null;
    expect(linkedDevicesOn, isTrue);
    linkedDevicesForTest = false;
    expect(linkedDevicesOn, isFalse);
  });

  group('the tables', () {
    test(
      "a 0.5.3 phone's files open at 96, the tables empty, every row kept",
      () async {
        if (skip()) return;
        copyFixtures();
        for (final (f, c) in [
          ('halo.db', HaloContainer.everyday),
          ('halo_d.db', HaloContainer.decoy),
        ]) {
          final raw = await openDatabase(
            p.absolute('$_fixtures/$f'),
            readOnly: true,
            singleInstance: false,
          );
          final before = await _counts(raw);
          final was = await raw.getVersion();
          await raw.close();
          expect(was, lessThan(95), reason: f);
          final db = await open(c);
          expect(await db.getVersion(), 96, reason: f);
          await tablesThere(db, reason: f);
          final after = await _counts(db);
          for (final t in before.keys) {
            expect(after[t], before[t], reason: '$f $t');
          }
          if (c == HaloContainer.everyday) {
            expect(after['contacts'], greaterThan(0), reason: f);
          }
        }
      },
    );

    test('a file at 94 takes the step to 95 and keeps every row', () async {
      if (skip()) return;
      copyFixtures();
      var db = await open();
      final before = await _counts(db);
      // back to how 94 left it
      for (final t in _devTables) {
        await db.execute('DROP TABLE $t');
      }
      await db.execute('ALTER TABLE identities DROP COLUMN dev_id');
      await db.execute('ALTER TABLE identities DROP COLUMN ident_pub');
      await db.setVersion(94);
      expect(await _cols(db, 'identities'), isNot(contains('dev_id')));
      await closeAll();
      db = await open();
      expect(await db.getVersion(), 96);
      await tablesThere(db, reason: 'from 94');
      expect(await _counts(db), before);
      // and once more changes nothing
      await closeAll();
      db = await open();
      await tablesThere(db, reason: 'again');
      expect(await _counts(db), before);
    });

    // a file that took a later number without them (another branch's
    // build) skips the step, so the tables are made at every open as well
    for (final at in [95, 96]) {
      test('a file at $at without them gets them at open', () async {
        if (skip()) return;
        copyFixtures();
        var db = await open();
        final before = await _counts(db);
        for (final t in _devTables) {
          await db.execute('DROP TABLE $t');
        }
        await db.execute('ALTER TABLE identities DROP COLUMN dev_id');
        await db.setVersion(at);
        await closeAll();
        db = await open();
        await tablesThere(db, reason: 'at open, $at');
        expect(await _counts(db), before);
      });
    }

    test('an open of a whole file writes nothing for them', () async {
      if (skip()) return;
      copyFixtures();
      await open();
      await closeAll();
      final from = sql!.said.length;
      await open();
      expect(
        sql!.said
            .sublist(from)
            .where(
              (s) =>
                  RegExp(r'^(ALTER|CREATE)').hasMatch(s) &&
                  (s.contains('dev_') || s.contains('own_device')),
            ),
        isEmpty,
      );
    });

    test('a new file has them', () async {
      if (skip()) return;
      final db = await open();
      expect(await db.getVersion(), 96);
      await tablesThere(db, reason: 'new');
    });
  });

  group('the engine state', () {
    bool skipEngine() {
      if (skip()) return true;
      if (shim == null || !_engine) {
        markTestSkipped(
          'needs the host engine (tool/host_engine.sh) and the shim',
        );
        return true;
      }
      return false;
    }

    Future<int> count(Database db, String t) async =>
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $t'))!;

    test(
      'rows written, the engine started again from them, the same state',
      () async {
        if (skipEngine()) return;
        final lib = shim!;
        final db = await open();
        final mePriv = testKeyPair().privateKey.serialize();
        await putMainIdentity(db, Uint8List.fromList(mePriv));
        final me = lib.identityFromPrivate(mePriv);
        final bob = lib.identityGenerate();
        final stranger = lib.identityGenerate();
        final desk = lib.identityGenerate().public;
        final bobDesk = lib.identityGenerate().public;
        await db.insert('contacts', {
          'halo_id': 'bob-quiet-river',
          'onion': '',
          'xpub': devHex(bob.public.sublist(1)),
          'first_seen': 0,
          'last_seen': 0,
          'ident': kMainIdent,
          'ikey': devHex(bob.public),
        });
        final meWire = _list(me, 4000, [(dev: 9, key: desk, reg: 2222)]);
        final bobWire = _list(bob, 7000, [(dev: 5, key: bobDesk, reg: 3333)]);
        final mine = await devMineOf(db, lib);
        expect(mine, hasLength(1));
        expect(mine.single.identity, me.public);
        final path = KryfoSignal.loadedFrom!;
        final ds = DeviceState(DeviceEngine());
        await ds.load(db, mine, shimPath: path);
        expect(ds.skipped, 0);
        await ds.ownMine(db, kMainIdent, meWire);
        final took = await ds.session(db, 'accept', {
          'identity': devHex(bob.public),
          'list': base64Encode(bobWire),
        }, SessionRemote.opened(bob.public));
        expect(took['outcome'], 'first');
        await ds.session(db, 'opened', {
          'ident': kMainIdent,
          'identity': devHex(bob.public),
          'device': 1,
          'pq': true,
        }, SessionRemote.opened(bob.public));
        await ds.session(db, 'opened', {
          'ident': kMainIdent,
          'identity': devHex(bob.public),
          'device': 5,
        }, SessionRemote.opened(bobDesk));
        final now = DateTime.now().millisecondsSinceEpoch;
        await ds.call(db, 'quiet', {
          'op': 'sent',
          'identity': devHex(bob.public),
          'device': 5,
          'key': devHex(bobDesk),
          'now': now,
        });
        final rows = {for (final t in kDevTablesForTest) t: await count(db, t)};
        expect(rows, {
          'dev_lists': 2,
          'dev_proven': 1,
          'dev_pq': 1,
          'dev_quiet': 1,
          'dev_pool': 0,
        });
        final stored = (await db.query(
          'dev_lists',
          where: 'owner = ?',
          whereArgs: [devHex(bob.public)],
        )).single;
        expect(stored['wire'], bobWire);
        expect(stored['version'], 7000);

        // a list from a session that does not speak for bob writes nothing
        await expectLater(
          ds.session(db, 'accept', {
            'identity': devHex(bob.public),
            'list': base64Encode(_list(bob, 7100, [])),
          }, SessionRemote.opened(stranger.public)),
          throwsA(isA<DevRefused>().having((e) => e.why, 'why', 'source')),
        );
        // nor one that does not hold
        final broken = Uint8List.fromList(bobWire)..last ^= 1;
        await expectLater(
          ds.session(db, 'accept', {
            'identity': devHex(bob.public),
            'list': base64Encode(broken),
          }, SessionRemote.opened(bob.public)),
          throwsA(isA<DevRefused>().having((e) => e.why, 'why', 'signature')),
        );

        // the restart
        final again = DeviceState(DeviceEngine());
        await again.load(db, await devMineOf(db, lib), shimPath: path);
        expect(again.skipped, 0);
        expect({
          for (final t in kDevTablesForTest) t: await count(db, t),
        }, rows);
        final held = await again.call(db, 'current', {
          'identity': devHex(bob.public),
        });
        expect(base64Decode(held['list'] as String), bobWire);
        final own = await again.call(db, 'current', {'ident': kMainIdent});
        expect(base64Decode(own['list'] as String), meWire);
        await again.call(db, 'admit', {
          'identity': devHex(bob.public),
          'device': 5,
          'remote': devHex(bobDesk),
        });
        // post-quantum stays: a classic phone session is refused
        await expectLater(
          again.call(db, 'fanout', {
            'ident': kMainIdent,
            'contact': devHex(bob.public),
            'devices': true,
            'phone_classic': true,
            'now': now,
          }),
          throwsA(isA<DevRefused>().having((e) => e.why, 'why', 'classic')),
        );
        final fan = await again.call(db, 'fanout', {
          'ident': kMainIdent,
          'contact': devHex(bob.public),
          'devices': true,
          'now': now,
        });
        expect(
          {for (final s in fan['slots'] as List) (s as Map)['device']},
          {1, 5, 9},
        );
      },
    );

    test('a message from a contact\'s phone is told to the engine only with '
        'the switch on, and only for the key its row holds', () async {
      if (skipEngine()) return;
      final lib = shim!;
      final live = HaloDb();
      opened.add(live);
      final db = await live.open();
      useDatabasesForTest(live, Session(live));
      final mePair = testKeyPair();
      final myX = mePair.publicKey.serialize().sublist(1);
      useEngineForTest(_Engine(devHex(myX)));
      await signalSession.bootstrap(
        database: MemDb(),
        xPubBytes: myX,
        xPrivBytes: mePair.privateKey.serialize(),
      );
      await putMainIdentity(db, mePair.privateKey.serialize());
      final themPair = testKeyPair();
      final them = SignalSession();
      await them.bootstrap(
        database: MemDb(),
        xPubBytes: themPair.publicKey.serialize().sublist(1),
        xPrivBytes: themPair.privateKey.serialize(),
      );
      const peer = 'them-quiet-river';
      final key = them.identity.public;
      await db.insert('contacts', {
        'halo_id': peer,
        'onion': '',
        'xpub': devHex(key.sublist(1)),
        'first_seen': 0,
        'last_seen': 0,
        'ident': kMainIdent,
        'ikey': devHex(key),
      });
      await processPeerBundle(
        'my-own-words',
        await signalSession.makeBundleB64(),
        into: them,
      );
      final ds = DeviceState(DeviceEngine());
      await ds.load(
        db,
        await devMineOf(db, lib),
        shimPath: KryfoSignal.loadedFrom!,
      );
      deviceStateForTest(ds);
      Future<int> pq() => count(db, 'dev_pq');

      // off: the message opens, nothing is noted
      expect(
        await signalDecrypt(
          peer,
          await them.encryptTo('my-own-words', 'one'),
          flagKeyChange: true,
        ),
        'one',
      );
      expect(await pq(), 0);
      // on: its post-quantum session is noted for good
      linkedDevicesForTest = true;
      expect(
        await signalDecrypt(
          peer,
          await them.encryptTo('my-own-words', 'two'),
          flagKeyChange: true,
        ),
        'two',
      );
      expect(await pq(), 1);
      final row = (await db.query('dev_pq')).single;
      expect(row['peer'], devHex(key));
      // a row holding another key: the open is not admitted, the message
      // still opens
      await db.delete('dev_pq');
      final other = lib.identityGenerate().public;
      await db.update(
        'contacts',
        {'ikey': devHex(other)},
        where: 'halo_id = ?',
        whereArgs: [peer],
      );
      final fresh = DeviceState(DeviceEngine());
      await fresh.load(
        db,
        await devMineOf(db, lib),
        shimPath: KryfoSignal.loadedFrom!,
      );
      deviceStateForTest(fresh);
      expect(
        await signalDecrypt(
          peer,
          await them.encryptTo('my-own-words', 'three'),
          flagKeyChange: true,
        ),
        'three',
      );
      expect(await pq(), 0);
    });
  });
}

const kDevTablesForTest = [
  'dev_lists',
  'dev_proven',
  'dev_pq',
  'dev_quiet',
  'dev_pool',
];
