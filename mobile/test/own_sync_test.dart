// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, own-device sync: what one device of mine
// sends my others rides their own sessions alone. a copy of mine is taken
// once, as sent, and only when its uid names its frame; a state op goes
// in its device's order, a late or replayed one never undoes a newer; a
// forward comes from my phone alone; a linked device asks its phone only
// what a device may; a device's daily word reaches its phone; every own
// frame is answered and a state op goes again until it is, past the week
// a copy is kept; an own word from a contact's device is never taken.
// with the switch off nothing here runs. host shim and host engine
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
import 'package:kryfo/devices/own_sync.dart';
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
  int get device => int.parse(arg.split('/')[1]);
}

class _Wire implements DeviceWire {
  final sent = <_Sent>[];
  @override
  Future<String> send(int ident, String arg, String cipher) async {
    sent.add(_Sent(arg, cipher));
    return 'ok';
  }

  @override
  Future<String> sendOpener(int ident, String arg, String cipher) async {
    sent.add(_Sent(arg, cipher));
    return 'ok';
  }
}

class _Listen implements DeviceListen {
  @override
  void listen(int ident, String arg) {}
  @override
  void unlisten(int ident, String arg) {}
  @override
  Future<String> seed(int ident, String arg, String seedHex) async => 'ok';
}

// what the app would do with each own frame: noted
class _Apply implements OwnApply {
  final copies = <(OwnChat, String, List<String>)>[];
  final forwards = <(String, String, int)>[];
  final ops = <(OwnChat?, String, int)>[];
  final beats = <int>[];

  @override
  Future<bool> copy(
    int ident,
    OwnChat chat,
    String frame, {
    List<String> notReached = const [],
  }) async {
    copies.add((chat, frame, notReached));
    return true;
  }

  @override
  Future<bool> forward(int ident, String sender, String frame, int came) async {
    forwards.add((sender, frame, came));
    return true;
  }

  @override
  Future<bool> op(
    int ident,
    OwnChat? chat,
    String kind,
    Map<String, dynamic> a,
  ) async {
    ops.add((chat, kind, a['n'] as int));
    return true;
  }

  @override
  Future<void> heard(int ident, int device, String key, int at) async =>
      beats.add(device);
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

// the pair's seed, as the first frames of a pair carry it
String _seeded(String f) {
  final j = _json(f);
  j['as'] = List.filled(32, '22').join();
  return _frame(j);
}

// an own op as a device of mine seals it
String _op(int device, int n, String kind, String chat, [Map? more]) => _frame({
  'u': 'os:$device:$n',
  'os': {'n': n, 'k': kind, 'c': chat, ...?more},
});

// an own copy, its uid naming its frame
String _oc(String chat, String f, {List<String>? n}) => _frame({
  'u': 'oc:${ownHash(f)}',
  'oc': {'i': 0, 'c': chat, 'f': f, 'n': ?n},
});

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
    docs = Directory.systemTemp.createTempSync('own_sync');
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
    // what a test left pumping ends before its database closes
    for (final p in pumps) {
      await p.pump();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await p.pump();
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

  // ana's desk (device 4), linked: its own key on row 0, ana's identity
  // beside it, ana's list naming it held. ana's phone holds a session to it
  Future<_Desk> desk() async {
    final lib = shim!;
    final db = await open();
    final anaKp = testKeyPair();
    final ana = await testStore(keys: anaKp);
    final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
    final deskKp = testKeyPair();
    final deskStore = await testStore(keys: deskKp);
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
    await ds.session(db, 'own_set', {
      'ident': kMainIdent,
      'identity': devHex(ana.identity.public),
      'list': base64Encode(
        _list(anaId, ana.registrationId, 4000, [
          (
            dev: 4,
            key: deskStore.identity.public,
            reg: deskStore.registrationId,
          ),
        ]),
      ),
    }, SessionRemote.opened(ana.identity.public));
    final w = _Desk(db: db, ana: ana, deskStore: deskStore, ds: ds)
      ..anaPriv = anaKp.privateKey.serialize();
    final deskDs = DeviceSessions(deskStore, linked: true);
    w.send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      wire: w.wire,
      clock: () => w.clock,
      random: Random(3),
    );
    pumps.add(w.send);
    final me = (ident: kMainIdent, identity: ana.identity.public, device: 4);
    w.recv = DeviceReceive(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      send: w.send,
      listener: _Listen(),
      open: deviceOpenAt,
      me: (_) async => me,
      contact: (_, _) async => null,
      phone: (_, _, _) async => false,
      sign: (_, _) async => throw StateError('a linked device never signs'),
      clock: () => w.clock,
    );
    w.own = OwnSync(
      state: ds,
      db: () async => db,
      send: w.send,
      me: (_) async => me,
      apply: w.apply,
      clock: () => w.clock,
    );
    w.recv.ownSync = w.own;
    w.phoneDs = DeviceSessions(ana);
    await w.phoneDs.build(
      kOwnDevices,
      4,
      lib.parseDeviceBundle(await deskDs.makeBundle(4), ana.identity.public),
      deskStore.identity.public,
      deskStore.registrationId,
    );
    w.deskDs = deskDs;
    return w;
  }

  // ana's phone with her desk (4) on her list: the desk holds a session to
  // the phone, built from its KDB1
  Future<_Phone> phone() async {
    final lib = shim!;
    final db = await open();
    final anaKp = testKeyPair();
    final ana = await testStore(keys: anaKp);
    final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
    await putMainIdentity(db, anaKp.privateKey.serialize());
    final deskStore = await testStore();
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
        (dev: 4, key: deskStore.identity.public, reg: deskStore.registrationId),
      ]),
    );
    // bob's list names his computer (5), taken from his phone
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
    final w = _Phone(db: db, ana: ana, deskStore: deskStore, ds: ds);
    w.bob = bobStore;
    w.b5 = b5;
    final anaDs = DeviceSessions(ana);
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
      listener: _Listen(),
      open: deviceOpenAt,
      me: (_) async => me,
      contact: (ident, identity) async =>
          identity == devHex(bobStore.identity.public)
          ? (
              me: me,
              c: (
                peer: 'bob-quiet-river',
                identity: identity,
                devices: true,
                phoneClassic: false,
              ),
            )
          : null,
      phone: (_, _, _) async => false,
      sign: (_, body) async => lib.sign(anaId, LsSigContext.deviceList, body),
      clock: () => w.clock,
    );
    w.own = OwnSync(
      state: ds,
      db: () async => db,
      send: w.send,
      me: (_) async => me,
      apply: w.apply,
      clock: () => w.clock,
    );
    w.recv.ownSync = w.own;
    w.deskDs = DeviceSessions(deskStore, linked: true);
    await w.deskDs.build(
      kOwnDevices,
      1,
      lib.parseDeviceBundle(await _phoneKdb1(ana), ana.identity.public),
      ana.identity.public,
      ana.registrationId,
    );
    return w;
  }

  test('an own copy from my phone is taken once, as sent, and answered; one '
      'whose uid does not name its frame is not taken', () async {
    if (skip()) return;
    final w = await desk();
    const msg = 'halo/1:{"u":"u-1","m":"from my phone","w":5}';
    final oc = _oc('p:bob-quiet-river', msg);
    final c1 = await w.seal(oc);
    expect(await w.recv.receive(w.tag(opener: true), c1), isNull);
    expect(w.apply.copies, hasLength(1));
    expect(w.apply.copies.single.$1, (id: 'bob-quiet-river', group: false));
    expect(w.apply.copies.single.$2, msg);
    // answered on its session, the uid back
    await w.settle(1);
    final back = await w.openBack(w.wire.sent.last);
    expect(back['dr'], 'oc:${ownHash(msg)}');
    // the same wire again opens to nothing (libsignal keeps it once)
    expect(await w.recv.receive(w.tag(opener: true), c1), isNull);
    expect(w.apply.copies, hasLength(1));
    // a copy whose uid names another frame
    final forged = _frame({
      'u': 'oc:${ownHash(msg)}',
      'oc': {'i': 0, 'c': 'p:bob-quiet-river', 'f': '$msg '},
    });
    await w.recv.receive(w.tag(opener: true), await w.seal(forged));
    expect(w.apply.copies, hasLength(1));
    // and one too long to be any frame that went
    final big = 'halo/1:{"u":"u-2","m":"${'x' * kOwnFrameMost}"}';
    await w.recv.receive(w.tag(opener: true), await w.seal(_oc('p:b', big)));
    expect(w.apply.copies, hasLength(1));
  });

  test('state ops go in their device\'s order: a late one, or the same '
      'counter again, never undoes a newer', () async {
    if (skip()) return;
    final w = await desk();
    Future<void> take(String f) async =>
        w.recv.receive(w.tag(opener: true), await w.seal(f));
    await take(_op(1, 5, 'contact', 'p:bob', {'r': {}}));
    await take(_op(1, 4, 'gone', 'p:bob'));
    await take(_op(1, 5, 'gone', 'p:bob'));
    expect(w.apply.ops.map((o) => (o.$2, o.$3)), [('contact', 5)]);
    // another chat, and another kind's order, go on their own
    await take(_op(1, 4, 'contact', 'p:cat', {'r': {}}));
    await take(_op(1, 3, 'read', 'p:bob'));
    await take(_op(1, 6, 'gone', 'p:bob'));
    expect(w.apply.ops.map((o) => (o.$2, o.$3)), [
      ('contact', 5),
      ('contact', 4),
      ('read', 3),
      ('gone', 6),
    ]);
    // a uid that does not name its counter, an op no one knows, a chat
    // that is no chat: none taken
    await take(
      _frame({
        'u': 'os:1:9',
        'os': {'n': 8, 'k': 'gone', 'c': 'p:bob'},
      }),
    );
    await take(_op(1, 10, 'wipe', 'p:bob'));
    await take(_op(1, 11, 'gone', 'x:bob'));
    expect(w.apply.ops, hasLength(4));
  });

  test('a forward comes from my phone alone, and when it came is never '
      'later than now', () async {
    if (skip()) return;
    final w = await desk();
    const f = 'halo/1:{"u":"u-ana","m":"from an older Kryfo"}';
    String of(int t) => _frame({
      'u': 'of:${ownHash('cat-old-oak\n$f')}',
      'of': {'h': 'cat-old-oak', 't': t, 'f': f},
    });
    await w.recv.receive(w.tag(opener: true), await w.seal(of(w.clock - 50)));
    await w.recv.receive(
      w.tag(opener: true),
      await w.seal(of(w.clock + 9e9.toInt())),
    );
    expect(w.apply.forwards.map((x) => (x.$1, x.$2, x.$3)), [
      ('cat-old-oak', f, w.clock - 50),
      ('cat-old-oak', f, w.clock),
    ]);
  });

  test('my phone takes from a linked device only what a device may send, '
      'never a forward, and hears its daily word', () async {
    if (skip()) return;
    final w = await phone();
    Future<void> take(String f) async =>
        w.recv.receive(w.deskTag(opener: true), await w.seal(f));
    await take(_op(4, 1, 'read', 'p:bob-quiet-river'));
    await take(_op(4, 2, 'group', 'g:g1', {'r': {}, 'm': []}));
    await take(_op(4, 3, 'profile', 'p:x'));
    await take(_op(4, 4, 'gone', 'p:bob-quiet-river'));
    // M6: a whole chat's end or clear from a device stays on it
    await take(_op(4, 5, 'clear', 'p:bob-quiet-river', {'t': 1}));
    await take(
      _op(4, 6, 'del', 'p:bob-quiet-river', {
        'u': ['u-1'],
      }),
    );
    expect(w.apply.ops.map((o) => o.$2), ['read', 'del']);
    const f = 'halo/1:{"u":"u-x","m":"made up"}';
    await take(
      _frame({
        'u': 'of:${ownHash('bob-quiet-river\n$f')}',
        'of': {'h': 'bob-quiet-river', 't': 1, 'f': f},
      }),
    );
    expect(w.apply.forwards, isEmpty);
    await take(
      _frame({
        'u': 'ob:4:1',
        'ob': {'t': 1},
      }),
    );
    expect(w.apply.beats, [4]);
    // a group frame of mine it sent, with the members it could not reach
    const g = 'halo/1:{"u":"u-g","m":"hi all","g":"g1"}';
    await take(_oc('g:g1', g, n: ['hidden-one', 'old-one']));
    expect(w.apply.copies.single.$3, ['hidden-one', 'old-one']);
  });

  test('an own word from a contact\'s device is never taken', () async {
    if (skip()) return;
    final w = await phone();
    final lib = shim!;
    // bob's computer holds a session to ana's phone, as a list push gives
    await w.b5.build(
      'ana',
      1,
      lib.parseDeviceBundle(await _phoneKdb1(w.ana), w.ana.identity.public),
      w.ana.identity.public,
      w.ana.registrationId,
    );
    final f = _frame({
      'u': 'u-b',
      'm': 'from bob\'s computer',
      'oc': {'i': 0, 'c': 'p:bob-quiet-river', 'f': 'halo/1:{"u":"u-x"}'},
      'os': {'n': 1, 'k': 'gone', 'c': 'p:bob-quiet-river'},
      'of': {'h': 'cat', 't': 1, 'f': 'halo/1:{}'},
    });
    final c = await w.b5.seal('ana', 1, f, w.ana.identity.public);
    final bobX = devHex(w.bob.identity.public).substring(2);
    final got = await w.recv.receive('$bobX/5/1/opn', c);
    // his words reach the chat, none of the own ones; the own door never
    // heard them
    expect(got, isNotNull);
    final j = _json(got!.frame);
    expect(j['m'], 'from bob\'s computer');
    expect(j.keys.toSet().intersection(kOwnWords), isEmpty);
    expect(w.apply.copies, isEmpty);
    expect(w.apply.ops, isEmpty);
    expect(w.apply.forwards, isEmpty);
  });

  test('a state op waits for its receipt and goes again past the week a '
      'copy is kept; the receipt ends it', () async {
    if (skip()) return;
    final w = await phone();
    // the desk spoke first: the phone holds its session and seed
    await w.recv.receive(
      w.deskTag(opener: true),
      await w.seal(_op(4, 1, 'read', 'p:bob-quiet-river')),
    );
    await w.settle(1);
    w.wire.sent.clear();
    expect(
      await w.own.op(kMainIdent, 'gone', (id: 'bob', group: false), const {}),
      isTrue,
    );
    expect(
      await w.own.copy(kMainIdent, (
        id: 'bob',
        group: false,
      ), 'halo/1:{"u":"u-c","m":"c"}'),
      isTrue,
    );
    await w.settle(2);
    await w.send.pump();
    Future<List<String>> owed() async => [
      for (final r in await w.db.query('dev_out', where: 'device = 4'))
        r['uid'] as String,
    ];
    expect((await owed()).toSet(), {
      'os:1:1',
      'oc:${ownHash('halo/1:{"u":"u-c","m":"c"}')}',
    });
    final rows = await w.db.query('dev_out', where: 'device = 4');
    expect(
      rows.every((r) => r['receipt'] == 1 && r['state'] == 'sent'),
      isTrue,
    );
    // eight days on, the copy is let go, the op still goes again
    w.clock += const Duration(days: 8).inMilliseconds;
    final before = w.wire.sent.length;
    await w.send.pump();
    expect(await owed(), ['os:1:1']);
    expect(w.wire.sent.length, greaterThan(before));
    // the desk answers it: nothing more is owed
    await w.recv.receive(
      w.deskTag(opener: true),
      await w.seal(_frame({'dr': 'os:1:1'})),
    );
    expect(await owed(), isEmpty);
  });

  test('L5 a state op to a device that never answers is let go after '
      'kOwnOpKept', () async {
    if (skip()) return;
    final w = await phone();
    await w.recv.receive(
      w.deskTag(opener: true),
      await w.seal(_op(4, 1, 'read', 'p:bob-quiet-river')),
    );
    await w.settle(1);
    expect(
      await w.own.op(kMainIdent, 'read', (id: 'bob', group: false), const {}),
      isTrue,
    );
    await w.settle(2);
    Future<List<String>> owed() async => [
      for (final r in await w.db.query('dev_out', where: 'device = 4'))
        r['uid'] as String,
    ];
    w.clock += const Duration(days: 29).inMilliseconds;
    await w.send.pump();
    expect(await owed(), ['os:1:1']);
    w.clock += const Duration(days: 2).inMilliseconds;
    await w.send.pump();
    expect(await owed(), isEmpty);
  });

  test('op counters go on across a restart, and an op is never one a '
      'device may not send', () async {
    if (skip()) return;
    final w = await desk();
    final me = (ident: kMainIdent, identity: w.ana.identity.public, device: 4);
    OwnSync fresh() => OwnSync(
      state: w.ds,
      db: () async => w.db,
      send: w.send,
      me: (_) async => me,
      apply: w.apply,
      clock: () => w.clock,
    );
    final a = fresh();
    expect(
      await a.op(kMainIdent, 'read', (id: 'bob', group: false), {}),
      isTrue,
    );
    // a linked device never sends its phone a group or my profile
    expect(
      await a.op(kMainIdent, 'group', (id: 'g', group: true), {}),
      isFalse,
    );
    expect(await a.op(kMainIdent, 'profile', null, {}), isFalse);
    // nor a forward
    expect(await a.forward(kMainIdent, 'bob', 'halo/1:{}', 1), isFalse);
    final b = fresh();
    expect(
      await b.op(kMainIdent, 'del', (id: 'bob', group: false), {'u': []}),
      isTrue,
    );
    final uids = [
      for (final r in await w.db.query(
        'dev_out',
        where: 'device = 1',
        orderBy: 'at',
      ))
        r['uid'] as String,
    ];
    expect(uids, containsAll(['os:4:1', 'os:4:2']));
  });

  test(
    'a linked device tells its phone it is in use at most once a day',
    () async {
      if (skip()) return;
      final w = await desk();
      expect(await w.own.beat(kMainIdent), isTrue);
      expect(await w.own.beat(kMainIdent), isFalse);
      w.clock += const Duration(hours: 23).inMilliseconds;
      expect(await w.own.beat(kMainIdent), isFalse);
      w.clock += const Duration(hours: 2).inMilliseconds;
      expect(await w.own.beat(kMainIdent), isTrue);
      final beats = [
        for (final r in await w.db.query('dev_out', where: 'device = 1'))
          if ((r['uid'] as String).startsWith('ob:')) r,
      ];
      expect(beats, hasLength(2));
    },
  );

  test('my list naming a device of mine this one has no row of tells the '
      'app, never naming this device or the phone', () async {
    if (skip()) return;
    final w = await desk();
    final told = <List<int>>[];
    w.recv.ownAdded = (ident, added) async =>
        told.add([for (final e in added) e.id]);
    final lib = shim!;
    final anaId = lib.identityFromPrivate(w.anaPriv);
    final six = await testStore();
    final list = _list(anaId, w.ana.registrationId, 4100, [
      (
        dev: 4,
        key: w.deskStore.identity.public,
        reg: w.deskStore.registrationId,
      ),
      (dev: 6, key: six.identity.public, reg: six.registrationId),
    ]);
    await w.recv.receive(
      w.tag(opener: true),
      await w.seal(_frame({'dl': base64Encode(list)})),
    );
    expect(told, [
      [6],
    ]);
  });

  test('with the switch off nothing is sent or taken', () async {
    if (skip()) return;
    final w = await desk();
    final c = await w.seal(_oc('p:bob', 'halo/1:{"u":"u","m":"m"}'));
    linkedDevicesForTest = false;
    expect(
      await w.own.op(kMainIdent, 'read', (id: 'b', group: false), {}),
      isFalse,
    );
    expect(await w.own.beat(kMainIdent), isFalse);
    await w.own.take(
      (ident: kMainIdent, identity: w.ana.identity.public, device: 4),
      (id: 1, key: devHex(w.ana.identity.public), reg: 0),
      _json(_oc('p:bob', 'halo/1:{"u":"u","m":"m"}')),
    );
    expect(await w.recv.receive(w.tag(opener: true), c), isNull);
    expect(w.apply.copies, isEmpty);
    expect(await w.db.query('dev_out'), isEmpty);
  });

  group('the own copy a send makes', () {
    test('a 1:1 message, or my word on one, as sent', () {
      const f = 'halo/1:{"u":"u-1","m":"hi","w":3}';
      final oc = _json(ownCopyOf(0, 'bob', f)!);
      expect(oc['u'], 'oc:${ownHash(f)}');
      expect(oc['oc'], {'i': 0, 'c': 'p:bob', 'f': f});
      const ed = 'halo/1:{"ed":{"u":"u-1","m":"hey"},"w":4}';
      expect(ownCopyOf(0, 'bob', ed), isNotNull);
      const r = 'halo/1:{"r":{"u":"u-1","e":"x"},"w":4}';
      expect(ownCopyOf(0, 'bob', r), isNotNull);
    });

    test('never a group\'s, a receipt, typing, a list or a chat with '
        'screenshots blocked', () {
      for (final f in [
        'halo/1:{"u":"u-1","m":"hi","g":"g1"}',
        'halo/1:{"dr":"u-1"}',
        'halo/1:{"ty":1}',
        'halo/1:{"u":"dl:5","dl":"x"}',
        'halo/1:{"u":"u-1","m":"hi","ss":{"o":1}}',
        'halo/1:{"cp":["dv"]}',
        'halo/1:{"u":"u-1","m":"${'x' * kOwnFrameMost}"}',
      ]) {
        expect(ownCopyOf(0, 'bob', f), isNull, reason: f);
      }
    });
  });
}

class _Desk {
  _Desk({
    required this.db,
    required this.ana,
    required this.deskStore,
    required this.ds,
  });
  final Database db;
  final SignalSession ana;
  final SignalSession deskStore;
  final DeviceState ds;
  final wire = _Wire();
  final apply = _Apply();
  int clock = 1_780_000_000_000;
  late DeviceSend send;
  late DeviceReceive recv;
  late OwnSync own;
  late DeviceSessions phoneDs;
  late DeviceSessions deskDs;
  late Uint8List anaPriv;

  String get anaX => devHex(ana.identity.public).substring(2);
  String tag({bool opener = false}) => '$anaX/1/4${opener ? '/opn' : ''}';

  // a frame of my phone's, sealed on its own session with the desk
  Future<String> seal(String f) =>
      phoneDs.seal(kOwnDevices, 4, _seeded(f), deskStore.identity.public);

  // what the desk sent its phone, opened there
  Future<Map<String, dynamic>> openBack(_Sent s) async {
    final (t, b) = _wireOf(s.cipher);
    final plain = await phoneDs.open(
      kOwnDevices,
      4,
      t,
      b,
      deskStore.identity.public,
      reg: deskStore.registrationId,
    );
    return _json(unpad(utf8.decode(plain)));
  }

  Future<void> settle(int n) async {
    for (var i = 0; i < 400 && wire.sent.length < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _Phone {
  _Phone({
    required this.db,
    required this.ana,
    required this.deskStore,
    required this.ds,
  });
  final Database db;
  final SignalSession ana;
  final SignalSession deskStore;
  final DeviceState ds;
  final wire = _Wire();
  final apply = _Apply();
  int clock = 1_780_000_000_000;
  late DeviceSend send;
  late DeviceReceive recv;
  late OwnSync own;
  late DeviceSessions deskDs;
  late SignalSession bob;
  late DeviceSessions b5;

  String get anaX => devHex(ana.identity.public).substring(2);
  String deskTag({bool opener = false}) => '$anaX/4/1${opener ? '/opn' : ''}';

  // a frame of the desk's, sealed on its own session with the phone
  Future<String> seal(String f) =>
      deskDs.seal(kOwnDevices, 1, _seeded(f), ana.identity.public);

  Future<void> settle(int n) async {
    for (var i = 0; i < 400 && wire.sent.length < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
