// SPDX-License-Identifier: GPL-3.0-or-later
// removing linked devices (step 7 job 9): the phone signs its list without
// the device, its last word (that list) is sealed on its session before the
// session goes and handed to the relay until it takes it, and the device
// loses every way back in here (session, pool, copies, seeds, history copy,
// keys) while every contact that reads lists gets the removal at once. my
// phone's list without this device wipes a linked device; a device that
// says it unlinked itself is removed; the phone's own time online removes
// one not used for 30 days of it, never one the phone was offline for; a
// chat's end waits for a device past the month an op is kept; a restore
// cuts every device off before the first seal and lists the phone alone.
// nothing from the decoy. host shim and host engine
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/device_sessions.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devices/device_receive.dart';
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/own_device_store.dart';
import 'package:kryfo/devices/own_devices.dart' show DeviceKind;
import 'package:kryfo/devices/own_unlink.dart';
import 'package:kryfo/heal.dart' show restoreCutsLinkedDevices;
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart' show bundleBlock;
import 'package:kryfo/main.dart'
    show HaloDb, deviceOpenAt, deviceStateForTest, devMineOf;
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show unpad;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'host_engine.dart';
import 'signal_kit.dart';
import 'signal_ls/shim_lib.dart' show shim;
import 'sqlite_channel.dart';

final _keyFile =
    (jsonDecode(File('test/fixtures/upgrade_053/keys.json').readAsStringSync())
            as Map)
        .cast<String, String>();

final bool _engine = loadHostEngine();

const _day = Duration.millisecondsPerDay;

// a KDL2 list as the phone signs it: the phone first, then each device
Uint8List _list(
  LsIdentity id,
  int reg,
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

  entry(1, id.public, reg, 1);
  for (final d in devices) {
    entry(d.dev, d.key, d.reg, 0);
  }
  final body = b.toBytes();
  return Uint8List.fromList([
    ...body,
    ...shim!.sign(id, LsSigContext.deviceList, body),
  ]);
}

class _Sent {
  _Sent(this.arg, this.cipher);
  final String arg;
  final String cipher;
}

class _Wire implements DeviceWire {
  final sent = <_Sent>[];
  bool up = true;
  @override
  Future<String> send(int ident, String arg, String cipher) async {
    sent.add(_Sent(arg, cipher));
    return up ? 'ok' : 'error: down';
  }

  @override
  Future<String> sendOpener(int ident, String arg, String cipher) =>
      send(ident, arg, cipher);
}

class _Listen implements DeviceListen {
  final off = <String>[];
  @override
  void listen(int ident, String arg) {}
  @override
  void unlisten(int ident, String arg) => off.add(arg);
  @override
  Future<String> seed(int ident, String arg, String seedHex) async => 'ok';
}

Map<String, dynamic> _json(String frame) =>
    jsonDecode(frame.substring('halo/1:'.length)) as Map<String, dynamic>;

(int, Uint8List) _wireOf(String w) {
  final b = base64Decode(w);
  return (b[0], Uint8List.sublistView(b, 1));
}

// a KDB1 of [s] as a phone (device 1), on its session prekey and a pool
// kyber key, as a device of mine builds its own session from
Future<Uint8List> _phoneKdb1(SignalSession s) async {
  final ids = await s.sessionPreKeysForUse();
  final spk = s.lib.preKeyPublic(
    kLsSigned,
    (await s.signedPreKeyStore.load(ids.signedId))!,
  );
  final kyber = s.lib.preKeyPublic(
    kLsKyber,
    (await s.kyberPreKeyStore.load(await s.makePoolKyber()))!,
  );
  return Uint8List.fromList([
    ...ascii.encode('KDB1'),
    1,
    ...bundleBlock(registrationId: s.registrationId, spk: spk, kyber: kyber),
  ]);
}

String _frame(Map<String, Object?> j) => 'halo/1:${jsonEncode(j)}';

String _seeded(String f) {
  final j = _json(f);
  j['as'] = List.filled(32, '22').join();
  return _frame(j);
}

int _devicesIn(Uint8List wire) => wire[45];

class _Phone {
  _Phone(this.db, this.ana, this.anaId, this.desk, this.ds);
  final Database db;
  final SignalSession ana;
  final LsIdentity anaId;
  final SignalSession desk;
  final DeviceState ds;
  final wire = _Wire();
  final listen = _Listen();
  int clock = 1_780_000_000_000;
  late DeviceSend send;
  late DeviceReceive recv;
  late DeviceSessions anaDs;
  late DeviceSessions deskDs;
  late OwnUnlink unlink;
  late String bob;
  late Uint8List b5Key;
  final ended = <String>[];
  final left = <(int, String, String)>[];
  bool sends = true;

  String get anaX => devHex(ana.identity.public).substring(2);
  String get deskKey => devHex(desk.identity.public);
  String deskTag({bool opener = false}) => '$anaX/4/1${opener ? '/opn' : ''}';

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await send.pump();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<int> count(String sql, [List<Object?> args = const []]) async =>
      (await db.rawQuery(sql, args)).first.values.first as int;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  final opened = <HaloDb>[];
  final pumps = <DeviceSend>[];

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('own_unlink');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': _keyFile['everyday']!,
      'halo.d.key': _keyFile['decoy']!,
    });
    SharedPreferences.setMockInitialValues({});
    useDevKeysForTest(null);
    linkedDevicesForTest = false;
  });

  tearDown(() async {
    for (final p in pumps) {
      await p.pump();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    pumps.clear();
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
    if (sql == null) {
      markTestSkipped('no sqlite on this host');
      return true;
    }
    if (shim == null || !_engine) {
      markTestSkipped(
        'needs the host engine (tool/host_engine.sh) and the shim',
      );
      return true;
    }
    return false;
  }

  Future<Database> open() async {
    final d = HaloDb(HaloContainer.everyday);
    opened.add(d);
    return d.open();
  }

  // ana's phone with her desk (4) linked both ways and its row, bob who
  // reads lists with his computer (5) on his list
  Future<_Phone> phone() async {
    final lib = shim!;
    final db = await open();
    final anaKp = testKeyPair();
    final ana = await testStore(keys: anaKp);
    final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
    await putMainIdentity(db, anaKp.privateKey.serialize());
    final desk = await testStore();
    final bobKp = testKeyPair();
    final bobStore = await testStore(keys: bobKp);
    final bobId = lib.identityFromPrivate(bobKp.privateKey.serialize());
    await db.insert('contacts', {
      'halo_id': 'bob-quiet-river',
      'onion': '',
      'xpub': devHex(bobStore.identity.public.sublist(1)),
      'first_seen': 0,
      'last_seen': 0,
      'ident': kMainIdent,
      'ikey': devHex(bobStore.identity.public),
      'caps': 'dv,pq,ty',
      'accepted': 1,
    });
    final ds = DeviceState(DeviceEngine());
    await ds.load(
      db,
      await devMineOf(db, lib),
      shimPath: KryfoSignal.loadedFrom!,
    );
    linkedDevicesForTest = true;
    deviceStateForTest(ds);
    await ds.ownMine(
      db,
      kMainIdent,
      _list(anaId, ana.registrationId, 4000, [
        (dev: 4, key: desk.identity.public, reg: desk.registrationId),
      ]),
    );
    final b5 = DeviceSessions(await testStore(), linked: true);
    final bobRemote = SessionRemote.opened(bobStore.identity.public);
    await ds.session(db, 'opened', {
      'ident': kMainIdent,
      'identity': devHex(bobStore.identity.public),
      'device': 1,
      'pq': true,
    }, bobRemote);
    await ds.session(db, 'accept', {
      'identity': devHex(bobStore.identity.public),
      'list': base64Encode(
        _list(bobId, bobStore.registrationId, 7000, [
          (dev: 5, key: b5.s.identity.public, reg: b5.s.registrationId),
        ]),
      ),
    }, bobRemote);
    final w = _Phone(db, ana, anaId, desk, ds)
      ..bob = devHex(bobStore.identity.public)
      ..b5Key = b5.s.identity.public;
    final anaDs = w.anaDs = DeviceSessions(ana);
    w.deskDs = DeviceSessions(desk, linked: true);
    // both ways: the desk built its session from my phone's bundle, my
    // phone its own from the desk's
    await w.deskDs.build(
      kOwnDevices,
      1,
      lib.parseDeviceBundle(await _phoneKdb1(ana), ana.identity.public),
      ana.identity.public,
      ana.registrationId,
    );
    await anaDs.build(
      kOwnDevices,
      4,
      lib.parseDeviceBundle(await w.deskDs.makeBundle(4), ana.identity.public),
      desk.identity.public,
      desk.registrationId,
    );
    w.send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => anaDs,
      wire: w.wire,
      clock: () => w.clock,
      random: Random(5),
    );
    pumps.add(w.send);
    final me = (ident: kMainIdent, identity: ana.identity.public, device: 1);
    w.recv = DeviceReceive(
      state: ds,
      db: () async => db,
      sessions: (_) async => anaDs,
      send: w.send,
      listener: w.listen,
      open: deviceOpenAt,
      me: (_) async => me,
      contact: (_, _) async => null,
      phone: (_, _, _) async => false,
      sign: (_, body) async => lib.sign(anaId, LsSigContext.deviceList, body),
      clock: () => w.clock,
    );
    w.unlink = OwnUnlink(
      state: ds,
      db: () async => db,
      send: w.send,
      recv: w.recv,
      me: (_) async => me,
      sign: (_, body) async => lib.sign(anaId, LsSigContext.deviceList, body),
      historyEnd: (uid) async => w.ended.add(uid),
      allowed: () => w.sends,
      clock: () => w.clock,
    );
    w.recv.ownLeft = (ident, device, key, why) async {
      w.left.add((device, key, why));
      await w.unlink.left(ident, device, key);
    };
    await addOwnDevice(
      db,
      uid: 'u4',
      name: 'Desk',
      kind: DeviceKind.computer,
      linkedAt: DateTime.fromMillisecondsSinceEpoch(w.clock),
      keys: [
        (ident: kMainIdent, dev: 4, key: w.deskKey, reg: desk.registrationId),
      ],
    );
    await openLinkNotices(db);
    return w;
  }

  test('a removal signs my list without the device, seals its last word on '
      'its session before that goes, and leaves it no way back in', () async {
    if (skip()) return;
    final w = await phone();
    // an own op owed to the desk, and bundles of it pooled
    await w.send.toOne(
      ident: kMainIdent,
      identity: devHex(w.ana.identity.public),
      device: 4,
      addr: kOwnDevices,
      pin: w.deskKey,
      reg: w.desk.registrationId,
      frame: _frame({
        'u': 'os:1:1',
        'os': {'n': 1, 'k': 'read', 'c': 'p:bob-quiet-river'},
      }),
      own: true,
      receipt: true,
    );
    await w.ds.call(w.db, 'pool_put', {
      'ident': kMainIdent,
      'device': 4,
      'once': [base64Encode(await w.deskDs.makeBundle(4))],
      'last': base64Encode(await w.deskDs.lastResortBundle(4)),
      'made': w.clock,
      'now': w.clock,
    });
    await w.settle();
    w.wire.sent.clear();
    expect(await w.unlink.remove(['u4'], why: kGoneRemoved), ['u4']);
    await w.settle();
    expect(w.ended, ['u4']);
    // the last word went to the desk's own pair, and opens there to my list
    // without it, signed above the one it holds
    final last = w.wire.sent.where((s) => s.arg.startsWith('${w.anaX}/4/1.'));
    expect(last, hasLength(1));
    final (t, b) = _wireOf(last.single.cipher);
    final plain = await w.deskDs.open(
      kOwnDevices,
      1,
      t,
      b,
      w.ana.identity.public,
      reg: w.ana.registrationId,
    );
    final j = _json(unpad(utf8.decode(plain)));
    final list = base64Decode(j['dl'] as String);
    expect(listVersionOf(list), greaterThan(4000));
    expect(_devicesIn(list), 1);
    expect(j['u'], 'dl:${listVersionOf(list)}');
    // nothing of the desk is let in, or held here
    await expectLater(
      w.ds.session(w.db, 'opened', {
        'ident': kMainIdent,
        'identity': devHex(w.ana.identity.public),
        'device': 4,
      }, SessionRemote.opened(w.desk.identity.public)),
      throwsA(isA<DevRefused>().having((e) => e.why, 'why', 'not_listed')),
    );
    expect(await w.anaDs.has(kOwnDevices, 4), isFalse);
    expect(await w.count('SELECT COUNT(*) FROM dev_out WHERE device = 4'), 0);
    expect(
      await w.count('SELECT COUNT(*) FROM pairs WHERE their_device = 4'),
      0,
    );
    expect(await w.count('SELECT COUNT(*) FROM dev_pool WHERE device = 4'), 0);
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 0);
    expect(await w.count('SELECT COUNT(*) FROM own_device_keys'), 0);
    expect(w.listen.off, contains('${w.anaX}/4/1'));
    final row = (await w.db.query('own_devices')).single;
    expect(row['removed_at'], w.clock);
    expect(row['gone_why'], kGoneRemoved);
    // removed here: no notice here
    expect(row['notice'], 0);
    // every contact that reads lists gets it at once
    final push = await w.db.query('dev_pushes');
    expect(push.single['peer'], w.bob);
    expect(push.single['kind'], 'remove');
    expect(push.single['due_at'], lessThanOrEqualTo(w.clock));
    // removed again: nothing more
    expect(await w.unlink.remove(['u4'], why: kGoneRemoved), isEmpty);
  });

  test('a last word the relay does not take goes again until it does, and '
      'not past two weeks', () async {
    if (skip()) return;
    final w = await phone();
    w.wire.up = false;
    await w.unlink.remove(['u4'], why: kGoneRemoved);
    await w.settle();
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 1);
    final tried = w.wire.sent.where((s) => s.arg.contains('/4/1.')).toList();
    expect(tried, isNotEmpty);
    // the same sealed word, later, on the address the engine still has
    w.wire.up = true;
    w.clock += const Duration(minutes: 1).inMilliseconds;
    await w.settle();
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 0);
    expect(w.wire.sent.last.cipher, tried.first.cipher);
    expect(w.wire.sent.last.arg, tried.first.arg);
  });

  test('a last word the relay never takes is let go after two weeks, and '
      'its address with it', () async {
    if (skip()) return;
    final w = await phone();
    w.wire.up = false;
    await w.unlink.remove(['u4'], why: kGoneRemoved);
    await w.settle();
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 1);
    w.clock += 15 * _day;
    await w.settle();
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 0);
  });

  test('the phone\'s own time online counts: a phone offline a month keeps '
      'the device, a gap counts a tick at most, a word of use starts again, '
      'and 30 days of it remove the device with the notice', () async {
    if (skip()) return;
    final w = await phone();
    Future<int> online() async =>
        (await w.db.query('own_devices')).single['heard_online_ms'] as int;
    await w.unlink.tick(online: true);
    // the phone off or offline for a month
    for (var i = 0; i < 31; i++) {
      w.clock += _day;
      expect(await w.unlink.tick(online: false), isEmpty);
    }
    expect(await online(), 0);
    expect(await w.unlink.removeUnused(), isEmpty);
    // back online: a long gap counts one tick's most
    await w.unlink.tick(online: true);
    w.clock += 3 * _day;
    await w.unlink.tick(online: true);
    expect(await online(), kOnlineTickMost.inMilliseconds);
    // the device said a person uses it
    await ownDeviceHeard(
      w.db,
      ident: kMainIdent,
      dev: 4,
      key: w.deskKey,
      at: w.clock,
    );
    expect(await online(), 0);
    // nearly 30 days of time online since
    await w.db.update('own_devices', {
      'heard_online_ms':
          kUnusedOnline.inMilliseconds - kOnlineTickMost.inMilliseconds,
    });
    w.clock += const Duration(minutes: 10).inMilliseconds;
    expect(await w.unlink.tick(online: true), isEmpty);
    // the decoy open: it waits
    w.sends = false;
    w.clock += const Duration(minutes: 10).inMilliseconds;
    expect(await w.unlink.tick(online: true), ['u4']);
    expect(await w.unlink.removeUnused(), isEmpty);
    expect((await w.db.query('own_devices')).single['removed_at'], isNull);
    w.sends = true;
    expect(await w.unlink.removeUnused(), ['u4']);
    final row = (await w.db.query('own_devices')).single;
    expect(row['gone_why'], kGoneUnused);
    expect(row['notice'], 2);
    final n = await readLinkNotices(w.db);
    expect(n.single.why, kGoneUnused);
    expect(n.single.name, 'Desk');
    await openLinkNotices(w.db);
    expect(await readLinkNotices(w.db), isEmpty);
  });

  test('a device of mine that says it unlinked itself is removed with the '
      'notice; a word it may not say is not taken', () async {
    if (skip()) return;
    final w = await phone();
    Future<void> take(Map<String, Object?> j) async => w.recv.receive(
      w.deskTag(opener: true),
      await w.deskDs.seal(
        kOwnDevices,
        1,
        _seeded(_frame(j)),
        w.ana.identity.public,
      ),
    );
    await take({
      'u': 'ou:4',
      'ou': {'w': 'erase everything'},
    });
    expect(w.left, isEmpty);
    // the decoy open as it comes: kept for the everyday side's next tick
    w.sends = false;
    await take({
      'u': 'ou:4',
      'ou': {'w': 'unused'},
    });
    expect(w.left, [(4, w.deskKey, 'unused')]);
    expect((await w.db.query('own_devices')).single['removed_at'], isNull);
    expect(await w.unlink.removeUnused(), isEmpty);
    w.sends = true;
    expect(await w.unlink.tick(online: false), isEmpty);
    expect(await w.unlink.unusedNow(w.db), ['u4']);
    expect(await w.unlink.removeUnused(), ['u4']);
    final row = (await w.db.query('own_devices')).single;
    expect(row['gone_why'], kGoneItself);
    expect(row['notice'], 2);
    expect(await w.anaDs.has(kOwnDevices, 4), isFalse);
  });

  test('my phone\'s list without this device wipes it; an older list, one '
      'that still names it, or a stranger\'s does not; one that drops '
      'another device of mine tells it', () async {
    if (skip()) return;
    final lib = shim!;
    final db = await open();
    final anaKp = testKeyPair();
    final ana = await testStore(keys: anaKp);
    final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
    final deskKp = testKeyPair();
    final deskStore = await testStore(keys: deskKp);
    final lap = await testStore();
    await putMainIdentity(db, deskKp.privateKey.serialize());
    await db.update('identities', {
      'ident_pub': ana.identity.public,
      'dev_id': 4,
    });
    final ds = DeviceState(DeviceEngine());
    await ds.load(
      db,
      await devMineOf(db, lib),
      shimPath: KryfoSignal.loadedFrom!,
    );
    linkedDevicesForTest = true;
    deviceStateForTest(ds);
    final deskE = (
      dev: 4,
      key: deskStore.identity.public,
      reg: deskStore.registrationId,
    );
    final lapE = (dev: 6, key: lap.identity.public, reg: lap.registrationId);
    await ds.session(db, 'own_set', {
      'ident': kMainIdent,
      'identity': devHex(ana.identity.public),
      'list': base64Encode(
        _list(anaId, ana.registrationId, 4000, [deskE, lapE]),
      ),
    }, SessionRemote.opened(ana.identity.public));
    final deskDs = DeviceSessions(deskStore, linked: true);
    final phoneDs = DeviceSessions(ana);
    await phoneDs.build(
      kOwnDevices,
      4,
      lib.parseDeviceBundle(await deskDs.makeBundle(4), ana.identity.public),
      deskStore.identity.public,
      deskStore.registrationId,
    );
    final wire = _Wire();
    final send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      wire: wire,
    );
    pumps.add(send);
    final me = (ident: kMainIdent, identity: ana.identity.public, device: 4);
    final recv = DeviceReceive(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      send: send,
      listener: _Listen(),
      open: deviceOpenAt,
      me: (_) async => me,
      contact: (_, _) async => null,
      phone: (_, _, _) async => false,
      sign: (_, _) async => throw StateError('a linked device never signs'),
    );
    var wiped = 0;
    final gone = <int>[];
    final left = <String>[];
    recv.ownRemoved = (_) async => wiped++;
    recv.ownLeft = (_, _, _, why) async => left.add(why);
    recv.ownGoneHere = (_, g) async => gone.addAll(g.map((e) => e.id));
    final tag = '${devHex(ana.identity.public).substring(2)}/1/4/opn';
    Future<void> take(Uint8List list) async => recv.receive(
      tag,
      await phoneDs.seal(
        kOwnDevices,
        4,
        _seeded(
          _frame({'u': 'dl:${listVersionOf(list)}', 'dl': base64Encode(list)}),
        ),
        deskStore.identity.public,
      ),
    );
    // older, without it: a rollback, never a wipe
    await take(_list(anaId, ana.registrationId, 3999, [lapE]));
    // a stranger's, without it
    final stranger = lib.identityFromPrivate(
      testKeyPair().privateKey.serialize(),
    );
    await take(_list(stranger, 9, 4100, [lapE]));
    // newer, still naming it, the laptop gone
    await take(_list(anaId, ana.registrationId, 4100, [deskE]));
    expect(wiped, 0);
    expect(gone, [6]);
    // a device's last word is the phone's to take, never a device's
    await recv.receive(
      tag,
      await phoneDs.seal(
        kOwnDevices,
        4,
        _seeded(
          _frame({
            'u': 'ou:1',
            'ou': {'w': 'unused'},
          }),
        ),
        deskStore.identity.public,
      ),
    );
    expect(left, isEmpty);
    // newer, without it
    await take(_list(anaId, ana.registrationId, 4200, const []));
    expect(wiped, 1);
  });

  test('a chat\'s end to a device of mine stays past the month an op is '
      'kept, until the device answers or is removed', () async {
    if (skip()) return;
    final w = await phone();
    w.wire.up = false;
    Future<void> op(int n, String k, {bool keep = false}) => w.send.toOne(
      ident: kMainIdent,
      identity: devHex(w.ana.identity.public),
      device: 4,
      addr: kOwnDevices,
      pin: w.deskKey,
      reg: w.desk.registrationId,
      frame: _frame({
        'u': 'os:1:$n',
        'os': {'n': n, 'k': k, 'c': 'p:bob-quiet-river'},
      }),
      own: true,
      receipt: true,
      keep: keep,
    );
    await op(1, 'read');
    await op(2, 'gone', keep: true);
    await w.settle();
    w.clock += 31 * _day;
    await w.settle();
    final left = await w.db.query('dev_out', where: "uid LIKE 'os:%'");
    expect([for (final r in left) r['uid']], ['os:1:2']);
    await w.unlink.remove(['u4'], why: kGoneRemoved);
    expect(await w.count('SELECT COUNT(*) FROM dev_out'), 0);
  });

  test('a restore cuts every device off before the first seal and the next '
      'start lists the phone alone, above what the backup signed', () async {
    if (skip()) return;
    final w = await phone();
    await w.send.toOne(
      ident: kMainIdent,
      identity: devHex(w.ana.identity.public),
      device: 4,
      addr: kOwnDevices,
      pin: w.deskKey,
      reg: w.desk.registrationId,
      frame: _frame({'u': 'x-1', 'm': 'hi'}),
      own: true,
    );
    await w.settle();
    await w.db.insert('sessions', {
      'ident': 0,
      'address': 'bob-quiet-river',
      'device_id': 5,
      'record': Uint8List(4),
    });
    await w.db.insert('sessions', {
      'ident': 0,
      'address': 'bob-quiet-river',
      'device_id': 1,
      'record': Uint8List(4),
    });
    final proofs = await w.count('SELECT COUNT(*) FROM dev_proven');
    await w.db.insert('pairs', {
      'ident': 0,
      'peer': devHex(w.ana.identity.public),
      'their_device': 4,
      'my_device': 1,
      'conv': 4,
      'seed': Uint8List(32),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await restoreCutsLinkedDevices(w.db);
    expect(
      await w.count('SELECT COUNT(*) FROM sessions WHERE device_id >= 2'),
      0,
    );
    expect(
      await w.count('SELECT COUNT(*) FROM sessions WHERE device_id = 1'),
      1,
    );
    expect(
      await w.count('SELECT COUNT(*) FROM pairs WHERE their_device != 1'),
      0,
    );
    for (final t in const [
      'own_devices',
      'own_device_keys',
      'dev_out',
      'dev_openers',
      'dev_quiet',
    ]) {
      expect(await w.count('SELECT COUNT(*) FROM $t'), 0, reason: t);
    }
    // the contacts' lists and proofs stay; my own list waits to be signed
    expect(
      await w.count("SELECT COUNT(*) FROM dev_lists WHERE owner = ?", [w.bob]),
      1,
    );
    expect(await w.count('SELECT COUNT(*) FROM dev_proven'), proofs);
    // the next start: loaded from the rows, my list signed with the phone
    // alone, once
    final ds = DeviceState(DeviceEngine());
    await ds.load(
      w.db,
      await devMineOf(w.db, shim!),
      shimPath: KryfoSignal.loadedFrom!,
    );
    deviceStateForTest(ds);
    Future<Uint8List> sign(int _, Uint8List body) async =>
        shim!.sign(w.anaId, LsSigContext.deviceList, body);
    final changes = await restoredLists(w.db, ds, sign);
    expect(changes.single.removed, isTrue);
    expect(changes.single.version, greaterThan(4000 + (1 << 40)));
    final cur = await ds.call(w.db, 'current', {'ident': kMainIdent});
    expect(cur['devices'], hasLength(1));
    expect(await restoredLists(w.db, ds, sign), isEmpty);
  });

  test('a device another copy of my phone linked shows before anything '
      'else, until the devices page is opened', () async {
    if (skip()) return;
    final w = await phone();
    await w.unlink.remove(['u4'], why: kGoneUnused);
    await w.db.insert('dev_marks', {
      'ident': 0,
      'peer': devHex(w.ana.identity.public),
      'kind': kUnknownDeviceMark,
      'key': '05${'ab' * 32}',
      'at': w.clock,
    });
    final n = await readLinkNotices(w.db);
    expect([for (final x in n) x.why], ['unknown', kGoneUnused]);
    await openLinkNotices(w.db);
    expect(await readLinkNotices(w.db), isEmpty);
    expect(
      await w.count('SELECT COUNT(*) FROM dev_marks WHERE kind = ?', [
        kUnknownDeviceMark,
      ]),
      0,
    );
  });

  test('asking whether a contact is reached spends no silent device\'s '
      'weekly probe: the send after it still rebuilds', () async {
    if (skip()) return;
    final w = await phone();
    final t0 = w.clock;
    await w.ds.call(w.db, 'quiet', {
      'op': 'sent',
      'identity': w.bob,
      'device': 5,
      'key': devHex(w.b5Key),
      'now': t0,
    });
    Future<List<Map>> slots(int now) async => [
      for (final s
          in (await w.ds.call(w.db, 'fanout', {
                'ident': kMainIdent,
                'contact': w.bob,
                'devices': true,
                'phone_classic': false,
                'now': now,
                'no_own': true,
              }))['slots']
              as List)
        if ((s as Map)['device'] == 5) s,
    ];
    // a month silent: marked so by a send
    expect(await slots(t0 + 30 * _day + 1), isEmpty);
    // the week's probe is due; the chat is opened three times first
    w.clock = t0 + 38 * _day;
    const c = (
      peer: 'bob-quiet-river',
      identity: '',
      devices: true,
      phoneClassic: false,
    );
    final me = (ident: kMainIdent, identity: w.ana.identity.public, device: 1);
    for (var i = 0; i < 3; i++) {
      await w.send.reaches(me, (
        peer: c.peer,
        identity: w.bob,
        devices: true,
        phoneClassic: false,
      ));
    }
    final s = await slots(w.clock);
    expect(s, hasLength(1));
    expect(s.single['rebuild'], isTrue);
  });
}
