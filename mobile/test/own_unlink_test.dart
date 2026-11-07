// SPDX-License-Identifier: GPL-3.0-or-later
// removing linked devices: the phone signs its list without
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
import 'package:kryfo/devices/device_store.dart' show applyDevRows;
import 'package:kryfo/devices/linked_lock.dart' show LinkedEnd, LinkedLock;
import 'package:kryfo/devices/own_devices.dart'
    show DeviceKind, DeviceUse, deviceUseOf;
import 'package:kryfo/devices/own_sync.dart' show OwnApply, OwnSync;
import 'package:kryfo/devices/own_unlink.dart';
import 'package:kryfo/heal.dart'
    show
        kRestoreCutPref,
        kVaultRestoreCutMeta,
        restoreCutsLinkedDevices,
        restoreCutsVaultDevices,
        vaultMadeAfterRestore;
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart' show bundleBlock;
import 'package:kryfo/main.dart'
    show
        HaloDb,
        deviceOpenAt,
        deviceReceiveForTest,
        deviceSendForTest,
        deviceStateForTest,
        devAddedForTest,
        devForgetForTest,
        devMineOf,
        bootDevices,
        deviceReceive,
        deviceUnlinked,
        linkedEndResetForTest,
        linkedLockForTest,
        linkedRoleForTest,
        linkedStandingForTest,
        linkedTickForTest,
        linkedWipeForTest,
        linkedLock,
        useDatabasesForTest,
        vaultCutWaitsForTest,
        vaultRestoreCutForTest;
import 'package:kryfo/session.dart' show Session;
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
  final openers = <String>[];
  bool up = true;
  @override
  Future<String> send(int ident, String arg, String cipher) async {
    sent.add(_Sent(arg, cipher));
    return up ? 'ok' : 'error: down';
  }

  @override
  Future<String> sendOpener(int ident, String arg, String cipher) {
    openers.add(arg);
    return send(ident, arg, cipher);
  }
}

class _Listen implements DeviceListen {
  final on = <String>[];
  final off = <String>[];
  @override
  void listen(int ident, String arg) => on.add(arg);
  @override
  void unlisten(int ident, String arg) => off.add(arg);
  @override
  Future<String> seed(int ident, String arg, String seedHex) async => 'ok';
}

// a send loop killed at one step of a removal: the app stopped there
class _Killed extends DeviceSend {
  _Killed({
    required super.state,
    required super.db,
    required super.sessions,
    required super.wire,
    super.clock,
    required this.at,
  });
  final String at;

  @override
  Future<void> listsChanged(
    List<({int ident, int version, List<int> added, bool removed})> changes,
  ) async {
    if (at == 'push') throw StateError('killed');
    return super.listsChanged(changes);
  }

  @override
  Future<bool> farewell({
    required DevMe me,
    required int device,
    required String pin,
    required int reg,
    required String frame,
    bool once = false,
  }) async {
    if (at == 'farewell') throw StateError('killed');
    return super.farewell(
      me: me,
      device: device,
      pin: pin,
      reg: reg,
      frame: frame,
      once: once,
    );
  }
}

// what an own sync applies: nothing here
class _NoApply implements OwnApply {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
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
  late TestKeyPair deskKp;
  late String bob;
  late Uint8List b5Key;
  late DeviceSessions b5;
  late SessionRemote bobRemote;
  late Uint8List bobList;
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
    final deskKp = testKeyPair();
    final desk = await testStore(keys: deskKp);
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
    final bobList = _list(bobId, bobStore.registrationId, 7000, [
      (dev: 5, key: b5.s.identity.public, reg: b5.s.registrationId),
    ]);
    await ds.session(db, 'accept', {
      'identity': devHex(bobStore.identity.public),
      'list': base64Encode(bobList),
    }, bobRemote);
    final w = _Phone(db, ana, anaId, desk, ds)
      ..deskKp = deskKp
      ..bob = devHex(bobStore.identity.public)
      ..b5Key = b5.s.identity.public
      ..b5 = b5
      ..bobRemote = bobRemote
      ..bobList = bobList;
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
    // the last word went to the desk's own pair and its opener address, the
    // same bytes, and opens there to my list without it, signed above the
    // one it holds
    final last = w.wire.sent.where((s) => s.arg.startsWith('${w.anaX}/4/1.'));
    expect(last, hasLength(2));
    expect(last.first.cipher, last.last.cipher);
    expect(w.wire.openers, contains(last.first.arg));
    final (t, b) = _wireOf(last.first.cipher);
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
    // the relay took it, and it is kept to go again
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 1);
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
    expect(w.wire.sent.last.cipher, tried.first.cipher);
    expect(w.wire.sent.last.arg, tried.first.arg);
    // taken, and still handed again now and then: a relay that dropped it
    // or a device that missed it gets a later copy
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 1);
    int words() => w.wire.sent.where((s) => s.arg.contains('/4/1.')).length;
    final n = words();
    final openers = w.wire.openers.length;
    // the next copy in the second half of two minutes, never sooner
    w.clock += const Duration(seconds: 59).inMilliseconds;
    await w.settle();
    expect(words(), n);
    w.clock += const Duration(minutes: 2).inMilliseconds;
    await w.settle();
    expect(words(), n + 2);
    expect(w.wire.openers, hasLength(openers + 1));
    expect(w.wire.sent.last.cipher, tried.first.cipher);
    // a day on, once more on both; past two weeks it is let go
    w.clock += _day;
    await w.settle();
    expect(words(), n + 4);
    expect(w.wire.openers, hasLength(openers + 2));
    w.clock += 14 * _day;
    await w.settle();
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 0);
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
    // wiped already: its last word goes until a relay takes it, never again
    await w.settle();
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 0);
    int words() => w.wire.sent.where((s) => s.arg.contains('/4/1.')).length;
    final n = words();
    expect(n, greaterThan(0));
    w.clock += _day;
    await w.settle();
    expect(words(), n);
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

  const bobPeer = 'bob-quiet-river';
  DevMe meOf(_Phone w) =>
      (ident: kMainIdent, identity: w.ana.identity.public, device: 1);
  DevContact bobOf(_Phone w) =>
      (peer: bobPeer, identity: w.bob, devices: true, phoneClassic: false);

  // my phone's receiving side with bob as a contact: what goes to his
  // phone, and what a held opener shows once it opens
  ({DeviceReceive r, List<String> toBob, List<DevCopyIn> shown}) withBob(
    _Phone w,
  ) {
    final toBob = <String>[];
    final shown = <DevCopyIn>[];
    final r = DeviceReceive(
      state: w.ds,
      db: () async => w.db,
      sessions: (_) async => w.anaDs,
      send: w.send,
      listener: w.listen,
      open: deviceOpenAt,
      me: (_) async => meOf(w),
      contact: (_, id) async => id == w.bob ? (me: meOf(w), c: bobOf(w)) : null,
      phone: (_, _, f) async {
        toBob.add(f);
        return true;
      },
      sign: (_, body) async =>
          shim!.sign(w.anaId, LsSigContext.deviceList, body),
      shown: (got) async => shown.add(got),
      clock: () => w.clock,
    );
    return (r: r, toBob: toBob, shown: shown);
  }

  // the list pushes due, the phone's copy kept as its frame
  Future<List<String>> pushNow(_Phone w, {String? also}) async {
    final sent = <String>[];
    await w.send.pushes(
      contact: (_, id) async {
        if (id == w.bob) return (me: meOf(w), c: bobOf(w));
        if (id == also) {
          return (
            me: meOf(w),
            c: (
              peer: 'carol-far-hill',
              identity: id,
              devices: true,
              phoneClassic: false,
            ),
          );
        }
        return null;
      },
      phone: (_, _) =>
          (measure: (f) async => f.length, seal: (f, _) async => f),
      send: (_, _, cipher) async {
        sent.add(cipher);
        return true;
      },
    );
    return sent;
  }

  OwnUnlink killedAt(_Phone w, String at) => OwnUnlink(
    state: w.ds,
    db: () async => w.db,
    send: _Killed(
      state: w.ds,
      db: () async => w.db,
      sessions: (_) async => w.anaDs,
      wire: w.wire,
      clock: () => w.clock,
      at: at,
    ),
    recv: w.recv,
    me: (_) async => meOf(w),
    sign: (_, body) async => shim!.sign(w.anaId, LsSigContext.deviceList, body),
    clock: () => w.clock,
  );

  Future<Uint8List> currentList(_Phone w) async => base64Decode(
    (await w.ds.call(w.db, 'current', {'ident': kMainIdent}))['list'] as String,
  );

  test('a removal killed after my list was kept is finished at the next '
      'start: every contact gets it, and nothing is signed twice', () async {
    if (skip()) return;
    final w = await phone();
    await expectLater(
      killedAt(w, 'push').remove(['u4'], why: kGoneRemoved),
      throwsStateError,
    );
    final kept = await currentList(w);
    expect(_devicesIn(kept), 1);
    // owed, not gone: no contact has the list yet
    var row = (await w.db.query('own_devices')).single;
    expect(row['removed_at'], isNull);
    expect(row['gone_why'], kGoneRemoved);
    expect(await w.count('SELECT COUNT(*) FROM dev_pushes'), 0);
    // the next start
    expect(await w.unlink.removeUnused(), ['u4']);
    expect(await currentList(w), kept);
    final push = (await w.db.query('dev_pushes')).single;
    expect(push['peer'], w.bob);
    expect(push['kind'], 'remove');
    expect(push['version'], listVersionOf(kept));
    row = (await w.db.query('own_devices')).single;
    expect(row['removed_at'], w.clock);
    expect(row['notice'], 0);
    expect(await w.anaDs.has(kOwnDevices, 4), isFalse);
    expect(await w.count('SELECT COUNT(*) FROM own_device_keys'), 0);
    expect(
      await w.count(
        "SELECT COUNT(*) FROM signal_meta WHERE k LIKE 'own_remove_owed:%'",
      ),
      0,
    );
  });

  test('a removal killed before its last word went is finished by removing '
      'it again, with the list it signed then', () async {
    if (skip()) return;
    final w = await phone();
    await expectLater(
      killedAt(w, 'farewell').remove(['u4'], why: kGoneRemoved),
      throwsStateError,
    );
    final owed =
        jsonDecode(
              (await w.db.query(
                    'signal_meta',
                    where: 'k = ?',
                    whereArgs: ['${kRemoveOwedMeta}0'],
                  )).single['v']
                  as String,
            )
            as Map;
    expect(owed['ids'], [4]);
    // not kept yet: the desk is still listed
    expect(_devicesIn(await currentList(w)), 2);
    expect(await w.unlink.remove(['u4'], why: kGoneRemoved), ['u4']);
    // the same bytes as signed before: never a second list at one version
    expect(await currentList(w), base64Decode(owed['w'] as String));
    expect(await w.count('SELECT COUNT(*) FROM dev_farewell'), 1);
    expect((await w.db.query('dev_pushes')).single['kind'], 'remove');
    expect((await w.db.query('own_devices')).single['removed_at'], w.clock);
  });

  test(
    'a removal whose phone side cannot sign marks nothing removed: the '
    'device stays owed, never shown as gone while contacts trust it',
    () async {
      if (skip()) return;
      final w = await phone();
      final none = OwnUnlink(
        state: w.ds,
        db: () async => w.db,
        send: w.send,
        recv: w.recv,
        me: (_) async => null,
        sign: (_, _) async => throw StateError('no signing here'),
        clock: () => w.clock,
      );
      expect(await none.remove(['u4'], why: kGoneRemoved), isEmpty);
      final row = (await w.db.query('own_devices')).single;
      expect(row['removed_at'], isNull);
      expect(row['gone_why'], kGoneRemoved);
      expect(await w.count('SELECT COUNT(*) FROM own_device_keys'), 1);
      expect(_devicesIn(await currentList(w)), 2);
      // and the next start finishes it
      expect(await w.unlink.removeUnused(), ['u4']);
    },
  );

  test('my other devices get my list after a removal until each answers, '
      'past the week a copy is kept', () async {
    if (skip()) return;
    final w = await phone();
    final lib = shim!;
    final lap = DeviceSessions(await testStore(), linked: true);
    final lapKey = devHex(lap.s.identity.public);
    await w.ds.ownMine(
      w.db,
      kMainIdent,
      _list(w.anaId, w.ana.registrationId, 4001, [
        (dev: 4, key: w.desk.identity.public, reg: w.desk.registrationId),
        (dev: 6, key: lap.s.identity.public, reg: lap.s.registrationId),
      ]),
    );
    await addOwnDevice(
      w.db,
      uid: 'u6',
      name: 'Lap',
      kind: DeviceKind.computer,
      linkedAt: DateTime.fromMillisecondsSinceEpoch(w.clock),
      keys: [
        (ident: kMainIdent, dev: 6, key: lapKey, reg: lap.s.registrationId),
      ],
    );
    await openLinkNotices(w.db);
    await lap.build(
      kOwnDevices,
      1,
      lib.parseDeviceBundle(await _phoneKdb1(w.ana), w.ana.identity.public),
      w.ana.identity.public,
      w.ana.registrationId,
    );
    await w.anaDs.build(
      kOwnDevices,
      6,
      lib.parseDeviceBundle(await lap.makeBundle(6), w.ana.identity.public),
      lap.s.identity.public,
      lap.s.registrationId,
    );
    await w.unlink.remove(['u4'], why: kGoneRemoved);
    await w.settle();
    final row = (await w.db.query('dev_out', where: 'device = 6')).single;
    final u = row['uid'] as String;
    expect(u, 'dl:${listVersionOf(await currentList(w))}');
    expect(row['receipt'], 1);
    expect(row['keep'], 1);
    // the laptop away for longer than a copy is kept: still owed, and sent
    // again every few days
    final went = w.wire.sent.where((x) => x.arg.contains('/6/1.')).length;
    w.clock += 8 * _day;
    await w.settle();
    expect(await w.count('SELECT COUNT(*) FROM dev_out WHERE device = 6'), 1);
    expect(
      w.wire.sent.where((x) => x.arg.contains('/6/1.')).length,
      greaterThan(went),
    );
    // its answer ends it
    await w.recv.receive(
      '${w.anaX}/6/1/opn',
      await lap.seal(
        kOwnDevices,
        1,
        _seeded(_frame({'dr': u})),
        w.ana.identity.public,
      ),
    );
    expect(await w.count('SELECT COUNT(*) FROM dev_out WHERE device = 6'), 0);
  });

  test('a removal push ends only when their phone says it holds the list: '
      'an older message of theirs does not, and it goes again with longer '
      'gaps meanwhile', () async {
    if (skip()) return;
    final w = await phone();
    final b = withBob(w);
    await w.unlink.remove(['u4'], why: kGoneRemoved);
    final v = listVersionOf(await currentList(w));
    final t0 = w.clock;
    expect(await pushNow(w), hasLength(1));
    // a message of theirs opened after it went, written before
    await w.send.heard(kMainIdent, w.bob, w.clock + 1);
    expect(await w.count('SELECT COUNT(*) FROM dev_pushes'), 1);
    // again after a day, two, then four
    w.clock = t0 + _day + 1;
    expect(await pushNow(w), hasLength(1));
    w.clock = t0 + 2 * _day - 1;
    expect(await pushNow(w), isEmpty);
    w.clock = t0 + 2 * _day + 2;
    expect(await pushNow(w), hasLength(1));
    w.clock = t0 + 3 * _day + 3;
    expect(await pushNow(w), isEmpty);
    w.clock = t0 + 4 * _day + 5;
    expect(await pushNow(w), hasLength(1));
    // their phone holds an older one: still owed
    await b.r.takePhone(kMainIdent, w.bob, _frame({'dy': v - 1}), w.bobRemote);
    expect(await w.count('SELECT COUNT(*) FROM dev_pushes'), 1);
    await b.r.takePhone(kMainIdent, w.bob, _frame({'dy': v}), w.bobRemote);
    expect(await w.count('SELECT COUNT(*) FROM dev_pushes'), 0);
  });

  test('a removal no phone ever answers is let go after two months', () async {
    if (skip()) return;
    final w = await phone();
    await w.unlink.remove(['u4'], why: kGoneRemoved);
    expect(await pushNow(w), hasLength(1));
    w.clock += 59 * _day;
    await pushNow(w);
    expect(await w.count('SELECT COUNT(*) FROM dev_pushes'), 1);
    w.clock += 2 * _day;
    await pushNow(w);
    expect(await w.count('SELECT COUNT(*) FROM dev_pushes'), 0);
  });

  test('a contact I deleted gets no removal and no list: one owed a removal '
      'gets nothing more, the delete itself sends nothing, and a request\'s '
      'list waits for the accept', () async {
    if (skip()) return;
    final w = await phone();
    final carolStore = await testStore();
    final carol = devHex(carolStore.identity.public);
    const carolId = 'carol-far-hill';
    await w.db.insert('contacts', {
      'halo_id': carolId,
      'onion': '',
      'xpub': carol.substring(2),
      'first_seen': 0,
      'last_seen': 0,
      'ident': kMainIdent,
      'ikey': carol,
      'caps': 'dv,pq,ty',
      'accepted': 1,
    });
    // a mark an earlier build left at a delete brings no one back
    await w.db.insert('dev_marks', {
      'ident': kMainIdent,
      'peer': carol,
      'kind': 'deleted_reader',
      'key': '',
      'at': w.clock,
    });
    await w.unlink.remove(['u4'], why: kGoneRemoved);
    Future<Set<String>> owed() async => {
      for (final r in await w.db.query('dev_pushes')) r['peer'] as String,
    };
    expect(await owed(), {w.bob, carol});
    // carol is deleted with the removal still owed to her
    final home = opened.first;
    useDatabasesForTest(home, Session(home));
    deviceSendForTest(w.send);
    deviceReceiveForTest(w.recv);
    addTearDown(() {
      deviceSendForTest(null);
      deviceReceiveForTest(null);
    });
    await w.settle();
    final wired = w.wire.sent.length;
    await devForgetForTest(carolId);
    await w.db.update(
      'contacts',
      {'accepted': 0, 'archived': 1},
      where: 'halo_id = ?',
      whereArgs: [carolId],
    );
    expect(w.wire.sent, hasLength(wired));
    // no mark of her is written, and none is left
    expect(
      await w.count('SELECT COUNT(*) FROM dev_marks WHERE peer = ?', [carol]),
      0,
    );
    expect(await owed(), {w.bob});
    // the send loop, with whom each phone's copy went to
    Future<List<String>> pushTo() async {
      final to = <String>[];
      await w.send.pushes(
        contact: (_, id) async => (
          me: meOf(w),
          c: id == w.bob
              ? bobOf(w)
              : (
                  peer: carolId,
                  identity: id,
                  devices: true,
                  phoneClassic: false,
                ),
        ),
        phone: (_, _) =>
            (measure: (f) async => f.length, seal: (f, _) async => f),
        send: (_, c, _) async {
          to.add(c.peer);
          return true;
        },
      );
      return to;
    }

    expect(await pushTo(), [bobPeer]);
    expect(await owed(), {w.bob});
    // the next change of my list: bob alone
    await w.send.listsChanged([
      (ident: kMainIdent, version: 9000, added: const [], removed: true),
      (ident: kMainIdent, version: 9001, added: const [7], removed: false),
    ]);
    expect(await owed(), {w.bob});
    // owed while she was a contact, deleted with no forget run: the send
    // loop drops the removal, and a list for a request waits for the accept
    await w.db.update(
      'contacts',
      {'accepted': 1},
      where: 'halo_id = ?',
      whereArgs: [carolId],
    );
    await w.send.listsChanged([
      (ident: kMainIdent, version: 9002, added: const [7], removed: true),
    ]);
    expect(
      (await w.db.query(
        'dev_pushes',
        columns: ['kind'],
        where: 'peer = ?',
        whereArgs: [carol],
      )).map((r) => r['kind']).toSet(),
      {'remove', 'add'},
    );
    await w.db.update(
      'contacts',
      {'accepted': 0},
      where: 'halo_id = ?',
      whereArgs: [carolId],
    );
    w.clock += _day;
    expect(await pushTo(), isNot(contains(carolId)));
    expect(
      (await w.db.query(
        'dev_pushes',
        columns: ['kind', 'sent_at'],
        where: 'peer = ?',
        whereArgs: [carol],
      )).map((r) => (r['kind'], r['sent_at'])).toList(),
      [('add', 0)],
    );
    // deleted again, then added back: my list as it is now goes to her at
    // once, so her phone stops copying to a device I removed meanwhile
    await devForgetForTest(carolId);
    expect(await owed(), isNot(contains(carol)));
    await w.db.update(
      'contacts',
      {'accepted': 1, 'archived': 0},
      where: 'halo_id = ?',
      whereArgs: [carolId],
    );
    await devAddedForTest(carolId);
    final mine = await w.db.query(
      'dev_lists',
      columns: ['version'],
      where: "ident = ? AND owner = 'me'",
      whereArgs: [kMainIdent],
    );
    expect(
      (await w.db.query(
        'dev_pushes',
        columns: ['kind', 'version'],
        where: 'peer = ?',
        whereArgs: [carol],
      )).map((r) => (r['kind'], r['version'])).toList(),
      [('add', mine.single['version'])],
    );
    // it goes once her phone is heard again
    w.clock += _day;
    expect(await pushTo(), isNot(contains(carolId)));
    await w.ds.session(w.db, 'opened', {
      'ident': kMainIdent,
      'identity': carol,
      'device': 1,
      'pq': true,
    }, SessionRemote.opened(carolStore.identity.public));
    w.clock += _day;
    expect(await pushTo(), contains(carolId));
  });

  // what a restore leaves of bob's devices once [cut] ran on the store that
  // holds them: only his phone let in and copied to until it sends his list
  Future<void> staleUntilTheirPhone(
    Future<void> Function(Database d) cut,
  ) async {
    final w = await phone();
    final lib = shim!;
    await cut(w.db);
    expect(await staleList(w.db, kMainIdent, w.bob), isTrue);
    final b = withBob(w);
    // asked for, once a day
    await b.r.askStale();
    await b.r.askStale();
    expect(b.toBob.where((f) => _json(f)['dw'] == 1), hasLength(1));
    // bob's computer, still on the list the backup held, opens to my phone
    await w.b5.build(
      'ana',
      1,
      lib.parseDeviceBundle(await _phoneKdb1(w.ana), w.ana.identity.public),
      w.ana.identity.public,
      w.ana.registrationId,
    );
    final opener = await w.b5.seal(
      'ana',
      1,
      _seeded(_frame({'u': 'b-1', 'm': 'from bob\'s computer'})),
      w.ana.identity.public,
    );
    final bobX = w.bob.substring(2);
    expect(await b.r.receive('$bobX/5/1/opn', opener), isNull);
    expect(await w.count('SELECT COUNT(*) FROM dev_held_openers'), 1);
    // nothing of mine goes to it meanwhile
    final burst = await w.send.burst(
      meOf(w),
      bobOf(w),
      _frame({'u': 'a-1', 'm': 'hi bob'}),
      force: true,
      ownCopy: false,
    );
    expect(burst?.copies ?? 0, 0);
    // his phone sends the list it holds: current again, answered with the
    // version, and the opener that waited opens
    await b.r.takePhone(
      kMainIdent,
      w.bob,
      _frame({'u': 'dl:7000', 'dl': base64Encode(w.bobList)}),
      w.bobRemote,
    );
    expect(await staleList(w.db, kMainIdent, w.bob), isFalse);
    expect(b.toBob.map((f) => _json(f)['dy']), contains(7000));
    expect(b.shown.single.frame, contains('from bob'));
  }

  test('a restore leaves the contacts\' lists stale: their devices are not '
      'let in or copied to until their phone sends the list again, which '
      'is answered and asked for', () async {
    if (skip()) return;
    await staleUntilTheirPhone(restoreCutsLinkedDevices);
  });

  test('the vault\'s cut after a restore leaves its contacts\' lists stale '
      'the same way', () async {
    if (skip()) return;
    await staleUntilTheirPhone((d) async {
      expect(await restoreCutsVaultDevices(d, 5000), isTrue);
    });
  });

  test('a restore cuts the hidden contacts\' devices at the vault\'s first '
      'open, in the vault alone and once a restore; a vault made after one '
      'is not cut', () async {
    if (sql == null) {
      markTestSkipped('no sqlite on this host');
      return;
    }
    final everyday = await open();
    final vh = HaloDb.withKey(HaloContainer.vault, _keyFile['vault']!);
    opened.add(vh);
    final v = await vh.open();
    Future<void> seed(Database d, String peer, String key) async {
      for (final dev in [1, 5]) {
        await d.insert('sessions', {
          'ident': kMainIdent,
          'address': peer,
          'device_id': dev,
          'record': Uint8List(4),
        });
      }
      await d.insert('pairs', {
        'ident': kMainIdent,
        'peer': key,
        'their_device': 1,
        'my_device': 1,
        'conv': 3,
      });
      await d.insert('pairs', {
        'ident': kMainIdent,
        'peer': key,
        'their_device': 5,
        'my_device': 1,
        'conv': 4,
        'seed': Uint8List(32),
      });
      await d.insert('dev_lists', {
        'ident': kMainIdent,
        'owner': key,
        'version': 7,
        'wire': Uint8List(8),
      });
      await d.insert('dev_proven', {
        'ident': kMainIdent,
        'peer': key,
        'key': 'k5',
      });
      await d.insert('dev_pq', {'ident': kMainIdent, 'peer': key});
      await d.insert('dev_pushes', {
        'ident': kMainIdent,
        'peer': key,
        'version': 7,
        'kind': 'remove',
        'due_at': 1,
      });
      await d.insert('dev_held_openers', {
        'ident': kMainIdent,
        'peer': key,
        'device': 5,
        'cipher': Uint8List(4),
        'came_at': 1,
      });
      await d.insert('dev_marks', {
        'ident': kMainIdent,
        'peer': key,
        'kind': 'mine',
        'key': '7',
        'at': 1,
      });
    }

    const hid = 'hid-far-shore';
    final hidKey = '05${'ab' * 32}';
    await seed(v, hid, hidKey);
    await seed(everyday, 'eve-near-field', '05${'cd' * 32}');
    await everyday.insert('dev_lists', {
      'ident': kMainIdent,
      'owner': 'me',
      'version': 4000,
      'wire': Uint8List(8),
    });
    Future<String> dump(Database d) async {
      final out = StringBuffer();
      for (final t in await d.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      )) {
        final n = t['name'] as String;
        if (n.startsWith('sqlite_')) continue;
        out.writeln('$n ${await d.rawQuery('SELECT * FROM "$n" ORDER BY 1')}');
      }
      return out.toString();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kRestoreCutPref, 5000);
    Map<String, Object?> prefsNow() => {
      for (final k in prefs.getKeys()) k: prefs.get(k),
    };
    final was = await dump(everyday);
    final wasPrefs = prefsNow();
    Future<List<int>> devs() async => [
      for (final r in await v.query(
        'sessions',
        columns: ['device_id'],
        orderBy: 'device_id',
      ))
        r['device_id'] as int,
    ];
    Future<int> n(String t) async =>
        (await v.rawQuery('SELECT COUNT(*) AS n FROM $t')).first['n'] as int;

    expect(await restoreCutsVaultDevices(v, 5000), isTrue);
    expect(await devs(), [1]);
    expect(
      (await v.query(
        'pairs',
      )).map((r) => (r['their_device'], r['my_device'])).toList(),
      [(1, 1)],
    );
    // the lists, proofs and pq marks stay; each list is stale
    expect(await n('dev_lists'), 1);
    expect(await n('dev_proven'), 1);
    expect(await n('dev_pq'), 1);
    expect(await n('dev_pushes'), 0);
    expect(await n('dev_held_openers'), 0);
    expect(
      (await v.query('dev_marks')).map((r) => (r['peer'], r['kind'])).toList(),
      [(hidKey, kStaleList)],
    );
    expect(await staleList(v, kMainIdent, hidKey), isTrue);
    expect(
      (await v.query(
        'vault_meta',
        where: 'k = ?',
        whereArgs: [kVaultRestoreCutMeta],
      )).single['v'],
      '5000',
    );
    expect(
      await v.query(
        'signal_meta',
        where: 'k = ?',
        whereArgs: [kRestoreListOwedMeta],
      ),
      isEmpty,
    );
    // nothing on the everyday side moved
    expect(await dump(everyday), was);
    expect(prefsNow(), wasPrefs);
    // once a restore: a session made since stays
    Future<void> session6() => v.insert('sessions', {
      'ident': kMainIdent,
      'address': hid,
      'device_id': 6,
      'record': Uint8List(4),
    });
    await session6();
    expect(await restoreCutsVaultDevices(v, 5000), isFalse);
    expect(await restoreCutsVaultDevices(v, null), isFalse);
    expect(await devs(), [1, 6]);
    // the next restore cuts it again
    expect(await restoreCutsVaultDevices(v, 6000), isTrue);
    expect(await devs(), [1]);
    // a vault made after a restore holds nothing of it
    await prefs.setInt(kRestoreCutPref, 7000);
    await vaultMadeAfterRestore(v);
    await session6();
    expect(await restoreCutsVaultDevices(v, 7000), isFalse);
    expect(await devs(), [1, 6]);
    // at the open: the last restore's cut, then nothing more
    await prefs.setInt(kRestoreCutPref, 8000);
    await vaultRestoreCutForTest(vh);
    expect(vaultCutWaitsForTest, isFalse);
    expect(await devs(), [1]);
    await session6();
    await vaultRestoreCutForTest(vh);
    expect(await devs(), [1, 6]);
    expect(await dump(everyday), isNot(contains(hidKey)));
  });

  test('a vault whose restore cut fails keeps its devices\' side off until '
      'an open where it ran', () async {
    if (sql == null) {
      markTestSkipped('no sqlite on this host');
      return;
    }
    final vh = HaloDb.withKey(HaloContainer.vault, _keyFile['vault']!);
    opened.add(vh);
    final v = await vh.open();
    await v.execute('DROP TABLE vault_meta');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kRestoreCutPref, 5000);
    await vaultRestoreCutForTest(vh);
    expect(vaultCutWaitsForTest, isTrue);
    await v.execute('CREATE TABLE vault_meta (k TEXT PRIMARY KEY, v TEXT)');
    await vaultRestoreCutForTest(vh);
    expect(vaultCutWaitsForTest, isFalse);
  });

  test('my phone\'s bundle goes to each device of a contact with my list, '
      'once a day a device, and to a device that asks for it', () async {
    if (skip()) return;
    final w = await phone();
    final lib = shim!;
    final b = withBob(w);
    Future<List<String>> phoneBundlesTo5() async {
      final out = <String>[];
      for (final r in await w.db.query('dev_out', where: 'device = 5')) {
        final plain = r['plain'] as String?;
        if (plain == null) continue;
        for (final x in (_json(plain)['db'] as List? ?? const [])) {
          final kdb1 = base64Decode(x as String);
          // a KDB1 of device 1, on my identity
          if (kdb1[9] == 1) out.add(x);
        }
      }
      return out;
    }

    await w.send.devicesShown(kMainIdent, w.bob);
    w.clock += 11 * 60000;
    await pushNow(w);
    final first = await phoneBundlesTo5();
    expect(first, hasLength(1));
    final block = lib.parseDeviceBundle(
      base64Decode(first.single),
      w.ana.identity.public,
    );
    expect(block, isNotNull);
    // the same day again: no second one
    await w.db.delete('dev_out');
    await w.send.listTaken(kMainIdent, w.bob, 1 << 62);
    await w.send.devicesShown(kMainIdent, w.bob);
    w.clock += 11 * 60000;
    await pushNow(w);
    expect(await phoneBundlesTo5(), isEmpty);
    // a device of theirs asks: answered once a day
    await b.r.takePhone(
      kMainIdent,
      w.bob,
      _frame({
        'dq': [1],
      }),
      w.bobRemote,
    );
    await b.r.takePhone(
      kMainIdent,
      w.bob,
      _frame({
        'dq': [1],
      }),
      w.bobRemote,
    );
    final answers = [
      for (final f in b.toBob)
        if (_json(f)['db'] is List) _json(f)['db'] as List,
    ];
    expect(answers, hasLength(1));
    expect(base64Decode(answers.single.single as String)[9], 1);
  });

  test('a linked device answers its phone\'s list, notes it heard its phone, '
      'and copies to my other devices only while it heard it lately', () async {
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
    var now = 1_780_000_000_000;
    final send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      wire: wire,
      clock: () => now,
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
      clock: () => now,
    );
    final sync = OwnSync(
      state: ds,
      db: () async => db,
      send: send,
      me: (_) async => me,
      apply: _NoApply(),
      clock: () => now,
    );
    Future<List<int>> others() async => [
      for (final p in await sync.others(kMainIdent)) p.id,
    ];
    // never heard since a link of before: the phone alone
    expect(await others(), [1]);
    final list = _list(anaId, ana.registrationId, 4100, [deskE, lapE]);
    await recv.receive(
      '${devHex(ana.identity.public).substring(2)}/1/4/opn',
      await phoneDs.seal(
        kOwnDevices,
        4,
        _seeded(
          _frame({'u': 'dl:${listVersionOf(list)}', 'dl': base64Encode(list)}),
        ),
        deskStore.identity.public,
      ),
    );
    expect(await others(), [1, 6]);
    // answered: the phone sends it no more
    for (var i = 0; i < 4; i++) {
      await send.pump();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final words = <Map<String, dynamic>>[];
    for (final x in wire.sent) {
      final (t, b) = _wireOf(x.cipher);
      try {
        words.add(
          _json(
            unpad(
              utf8.decode(
                await phoneDs.open(
                  kOwnDevices,
                  4,
                  t,
                  b,
                  deskStore.identity.public,
                  reg: deskStore.registrationId,
                ),
              ),
            ),
          ),
        );
      } on Object {
        // not one for the phone
      }
    }
    expect(words.map((j) => j['dr']), contains('dl:4100'));
    // two weeks and a day without a word from the phone: the phone alone
    now += const Duration(days: 15).inMilliseconds;
    expect(await others(), [1]);
    expect(await ownPhoneFresh(db, now), isFalse);
  });

  test('a linked device watches its phone\'s opener address always and '
      'wipes on its phone\'s list without it there; a forged, replayed or '
      'older list does nothing, and a removal taken stays owed', () async {
    if (skip()) return;
    final lib = shim!;
    final home = HaloDb(HaloContainer.everyday);
    opened.add(home);
    final db = await home.open();
    useDatabasesForTest(home, Session(home));
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
    linkedRoleForTest = true;
    addTearDown(() => linkedRoleForTest = false);
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
    expect(await ownListHeld(db, kMainIdent), isTrue);
    expect(await linkedStandingForTest(), isNull);
    final deskDs = DeviceSessions(deskStore, linked: true);
    final phoneDs = DeviceSessions(ana);
    await phoneDs.build(
      kOwnDevices,
      4,
      lib.parseDeviceBundle(await deskDs.makeBundle(4), ana.identity.public),
      deskStore.identity.public,
      deskStore.registrationId,
    );
    final send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      wire: _Wire(),
    );
    pumps.add(send);
    final listen = _Listen();
    final me = (ident: kMainIdent, identity: ana.identity.public, device: 4);
    final recv = DeviceReceive(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      send: send,
      listener: listen,
      open: deviceOpenAt,
      me: (_) async => me,
      contact: (_, _) async => null,
      phone: (_, _, _) async => false,
      sign: (_, _) async => throw StateError('a linked device never signs'),
    );
    var wiped = 0;
    recv.ownRemoved = (_) async => wiped++;
    final anaX = devHex(ana.identity.public).substring(2);
    final opener = '$anaX/1/4';
    Future<String> sealed(Uint8List list) async => phoneDs.seal(
      kOwnDevices,
      4,
      _seeded(
        _frame({'u': 'dl:${listVersionOf(list)}', 'dl': base64Encode(list)}),
      ),
      deskStore.identity.public,
    );
    // the phone's first word, then one on the seeded pair: heard, and its
    // opener address still watched
    await recv.receive(
      '$opener/opn',
      await sealed(_list(anaId, ana.registrationId, 4001, [deskE, lapE])),
    );
    await recv.receive(
      opener,
      await sealed(_list(anaId, ana.registrationId, 4002, [deskE, lapE])),
    );
    expect(listen.off, isNot(contains(opener)));
    listen.on.clear();
    await recv.listenAll();
    expect(listen.on, contains(opener));
    // my phone's list with a signature not its own, and a stranger's
    final stranger = lib.identityFromPrivate(
      testKeyPair().privateKey.serialize(),
    );
    final real = _list(anaId, ana.registrationId, 4100, const []);
    final forged = Uint8List.fromList(real)..[real.length - 1] ^= 1;
    await recv.receive('$opener/opn', await sealed(forged));
    await recv.receive(
      '$opener/opn',
      await sealed(_list(stranger, 9, 4100, const [])),
    );
    // an old list without it, replayed, and one at the held version
    await recv.receive(
      '$opener/opn',
      await sealed(_list(anaId, ana.registrationId, 3999, const [])),
    );
    await recv.receive(
      '$opener/opn',
      await sealed(_list(anaId, ana.registrationId, 4002, const [])),
    );
    expect(wiped, 0);
    expect(await ownListHeld(db, kMainIdent), isTrue);
    expect(await linkedStandingForTest(), isNull);
    // my phone's list without it, on the opener address: it wipes once,
    // and a relay's copy of the same bytes again opens nothing
    final last = await sealed(real);
    await recv.receive('$opener/opn', last);
    expect(wiped, 1);
    await recv.receive('$opener/opn', last);
    expect(wiped, 1);
    // the list went with it: a wipe cut short ends it at the next check
    expect(await ownListHeld(db, kMainIdent), isFalse);
    expect(await linkedStandingForTest(), LinkedEnd.removed);
  });

  test('a linked device shows when it last heard its phone, and a phone '
      'shows a computer it linked as used then', () async {
    if (skip()) return;
    final db = await open();
    final at = DateTime(2026, 11, 7, 12);
    await ownPhoneHeard(db, at.millisecondsSinceEpoch);
    final mine = await StoredOwnDevices(
      db: db,
      thisName: 'This computer',
      thisKind: DeviceKind.computer,
      phoneName: 'Your phone',
    ).load();
    final phoneRow = mine.singleWhere((d) => d.id == 'phone');
    expect(phoneRow.lastUsed, at);
    expect(deviceUseOf(phoneRow.lastUsed, at), DeviceUse.today);
    await addOwnDevice(
      db,
      uid: 'u9',
      name: 'Computer',
      kind: DeviceKind.computer,
      linkedAt: at,
      heardAt: at,
      keys: const [],
    );
    final row = (await db.query('own_devices', where: "uid = 'u9'")).single;
    expect(row['heard_at'], at.millisecondsSinceEpoch);
  });

  test('end to end: a computer linked on the engine\'s rows stays through a '
      'restart and a tick; removed while offline, its phone hands the last '
      'word again by its steps, the one copy that comes days later wipes it, '
      'and a removal taken before a kill wipes it at the next start', () async {
    if (skip()) return;
    final lib = shim!;
    final w = await phone();
    final anaHex = devHex(w.ana.identity.public);
    final shimPath = KryfoSignal.loadedFrom!;
    Future<void> loadOn(Database db) async => DeviceState(
      DeviceEngine(),
    ).load(db, await devMineOf(db, lib), shimPath: shimPath);

    final phoneList = await currentList(w);
    // the computer's own container, placed as a link places it
    final deskHome = HaloDb(HaloContainer.decoy);
    opened.add(deskHome);
    final deskDb = await deskHome.open();
    await putMainIdentity(deskDb, w.deskKp.privateKey.serialize());
    final deskState = DeviceState(DeviceEngine());
    await deskState.load(deskDb, [
      (
        ident: kMainIdent,
        identity: w.ana.identity.public,
        key: w.desk.identity.public,
        dev: 4,
      ),
    ], shimPath: shimPath);
    // the rows the engine gives for my phone's list, written by the join
    List<dynamic> linkRows = const [];
    try {
      await deskDb.transaction((t) async {
        final j = await deskState.session(t, 'own_set', {
          'ident': kMainIdent,
          'identity': anaHex,
          'list': base64Encode(phoneList),
        }, SessionRemote.opened(w.ana.identity.public));
        linkRows = j['rows'] as List;
        throw StateError('kept for the join');
      });
    } on StateError {
      // rolled back: the join writes them
    }
    expect(linkRows, isNotEmpty);
    await joinedRows(
      deskDb,
      identity: w.ana.identity.public,
      device: 4,
      rows: linkRows,
      stream: Uint8List(32),
    );
    useDatabasesForTest(deskHome, Session(deskHome));
    linkedRoleForTest = true;
    final lockDir = Directory('${docs.path}/lock')..createSync();
    final keys = <String, String>{};
    linkedLockForTest = LinkedLock(
      dir: () async => lockDir.path,
      readKey: (k) async => keys[k],
      writeKey: (k, v) async => keys[k] = v,
    );
    await linkedLock.start();
    var wipes = 0;
    linkedWipeForTest = () async => wipes++;
    linkedEndResetForTest();
    addTearDown(() {
      linkedRoleForTest = false;
      linkedWipeForTest = null;
      linkedLockForTest = null;
      linkedEndResetForTest();
    });
    expect(await linkedStandingForTest(), isNull);
    // a restart and a tick: nothing ends
    await bootDevices();
    await linkedTickForTest();
    expect(wipes, 0);
    expect(deviceUnlinked.value, isNull);

    // the computer is offline: its phone removes it
    await loadOn(w.db);
    final t0 = w.clock;
    expect(await w.unlink.remove(['u4'], why: kGoneRemoved), ['u4']);
    final removal = await currentList(w);
    int words() => w.wire.sent.where((s) => s.arg.contains('/4/1.')).length;
    final hands = <int>[];
    final openers = <int>[];
    var seen = words(), seenOpeners = w.wire.openers.length;
    Future<void> step(Duration by) async {
      w.clock += by.inMilliseconds;
      await w.send.pump();
      if (words() > seen) hands.add(w.clock - t0);
      if (w.wire.openers.length > seenOpeners) openers.add(w.clock - t0);
      seen = words();
      seenOpeners = w.wire.openers.length;
    }

    await step(Duration.zero);
    while (w.clock - t0 < const Duration(hours: 1).inMilliseconds) {
      await step(const Duration(seconds: 30));
    }
    while (w.clock - t0 < _day) {
      await step(const Duration(minutes: 10));
    }
    while (w.clock - t0 < 3 * _day) {
      await step(const Duration(hours: 1));
    }
    // every wait drawn from the second half of its step, and the opener
    // address only for the first day
    expect(hands.first, 0);
    for (var i = 1; i < hands.length; i++) {
      final age = Duration(milliseconds: hands[i - 1]);
      final most = farewellAgainAfter(age).inMilliseconds;
      final gap = hands[i] - hands[i - 1];
      // the loop's own tick where the copy came
      final at = hands[i];
      final tick = at <= const Duration(hours: 1).inMilliseconds
          ? 30000
          : at <= _day + 600000
          ? 600000
          : 3600000;
      expect(gap, greaterThanOrEqualTo(most ~/ 2), reason: 'gap $i');
      expect(gap, lessThanOrEqualTo(most + tick), reason: 'gap $i');
    }
    expect(hands.where((h) => h <= 2 * 60000).length, inInclusiveRange(2, 3));
    expect(hands.where((h) => h < 15 * 60000).length, inInclusiveRange(6, 12));
    expect(hands.where((h) => h > 2 * _day), isNotEmpty);
    // the opener address with every hand: after the first day, once a day
    expect(openers, hands);
    final late = [
      for (final h in openers)
        if (h > _day + 600000) h,
    ];
    expect(late, isNotEmpty);
    for (var i = 1; i < late.length; i++) {
      expect(late[i] - late[i - 1], greaterThanOrEqualTo(_day ~/ 2));
      expect(late[i] - late[i - 1], lessThanOrEqualTo(_day + 3600000));
    }
    // every copy the same bytes
    final copies = {
      for (final x in w.wire.sent)
        if (x.arg.contains('/4/1.')) x.cipher,
    };
    expect(copies, hasLength(1));

    // a kill: the computer takes my list without it and stops before the
    // wipe. its next start wipes it
    await loadOn(deskDb);
    await expectLater(
      deskState.session(deskDb, 'own_set', {
        'ident': kMainIdent,
        'identity': anaHex,
        'list': base64Encode(removal),
      }, SessionRemote.opened(w.ana.identity.public)),
      throwsA(isA<DevRefused>().having((e) => e.why, 'why', 'removed')),
    );
    expect(await linkedStandingForTest(), LinkedEnd.removed);
    await bootDevices();
    expect(wipes, 1);
    expect(deviceUnlinked.value, LinkedEnd.removed);

    // as linked again, then online: the early copies and every one on the
    // seeded pair are lost (its seeds went apart), the one of day three
    // comes on the opener address, and the wipe runs at once
    linkedEndResetForTest();
    await deskDb.transaction((t) => applyDevRows(t, linkRows));
    await bootDevices();
    expect(wipes, 1);
    final recv = DeviceReceive(
      state: deskState,
      db: () async => deskDb,
      sessions: (_) async => w.deskDs,
      send: DeviceSend(
        state: deskState,
        db: () async => deskDb,
        sessions: (_) async => w.deskDs,
        wire: _Wire(),
      ),
      listener: _Listen(),
      open: deviceOpenAt,
      me: (_) async =>
          (ident: kMainIdent, identity: w.ana.identity.public, device: 4),
      contact: (_, _) async => null,
      phone: (_, _, _) async => false,
      sign: (_, _) async => throw StateError('a linked device never signs'),
    );
    recv.ownRemoved = deviceReceive!.ownRemoved;
    final day3 = w.wire.sent.lastWhere((s) => s.arg.contains('/4/1.'));
    expect(day3.arg, w.wire.openers.last);
    await recv.receive('${anaHex.substring(2)}/1/4/opn', day3.cipher);
    expect(wipes, 2);
    expect(deviceUnlinked.value, LinkedEnd.removed);
    expect(await linkedStandingForTest(), LinkedEnd.removed);
  });

  test('a linked device counts its time in touch with a relay without a '
      'word from its phone; 30 days of it end it, a word starts it again, '
      'time offline counts nothing', () async {
    if (skip()) return;
    final w = await phone();
    final u = w.unlink;
    expect(await u.quietTick(online: true), isFalse);
    w.clock += const Duration(minutes: 5).inMilliseconds;
    expect(await u.quietTick(online: true), isFalse);
    expect(await devMeta(w.db, kPhoneQuietMeta), '300000');
    // a day offline, then a gap the tick caps
    w.clock += _day;
    expect(await u.quietTick(online: false), isFalse);
    w.clock += _day;
    expect(await u.quietTick(online: true), isFalse);
    w.clock += _day;
    expect(await u.quietTick(online: true), isFalse);
    expect(await devMeta(w.db, kPhoneQuietMeta), '${300000 + 15 * 60000}');
    await putDevMeta(
      w.db,
      kPhoneQuietMeta,
      '${kUnusedOnline.inMilliseconds - 60000}',
    );
    w.clock += const Duration(minutes: 5).inMilliseconds;
    expect(await u.quietTick(online: true), isTrue);
    await ownPhoneHeard(w.db, w.clock);
    w.clock += const Duration(minutes: 5).inMilliseconds;
    expect(await u.quietTick(online: true), isFalse);
  });

  test('only a relay that answers counts as online, never a network '
      'alone', () {
    expect(relaysAnswer(null), isFalse);
    expect(relaysAnswer([]), isFalse);
    // a network and relays configured, none answering
    expect(
      relaysAnswer([
        {'url': 'wss://a', 'fails': 0, 'up': false},
        {'url': 'wss://b', 'fails': 3},
      ]),
      isFalse,
    );
    expect(
      relaysAnswer([
        {'url': 'wss://a', 'up': false},
        {'url': 'wss://b', 'up': true},
      ]),
      isTrue,
    );
    expect(relayContactSince(null, 10), isFalse);
    expect(relayContactSince(9, 10), isFalse);
    expect(relayContactSince(10, 10), isTrue);
    expect(relayContactSince(5, null), isTrue);
  });
}
