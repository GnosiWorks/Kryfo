// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, receiving (step 7 job 5): bob's devices write to ana's
// phone on their own device pairs. a copy opens only on its device's
// session and only once the engine admitted it; a device off the list is
// refused at once and its session goes with the list; an opener from a
// device the list does not name yet waits for the list; two openers that
// cross settle on the lower seed and both sides go on; a list older than
// the one held goes back once per version, and my own list handed back
// above mine is signed above it; a bundle ask is answered once a day per
// device; a linked device answers its phone's ask with a batch. with the
// switch off nothing here runs. host shim and host engine, containers in
// one process
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
import 'package:kryfo/identities.dart';
import 'package:kryfo/invites.dart' show bundleBlock;
import 'package:kryfo/main.dart'
    show HaloDb, deviceOpenAt, deviceStateForTest, deviceTagStepDone, devMineOf;
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

const _bobChat = 'bob-quiet-river';

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

// a device of an identity: its own store and sessions
class _Dev {
  _Dev(this.id, this.store) : ds = DeviceSessions(store, linked: true);
  final int id;
  final SignalSession store;
  final DeviceSessions ds;
  Uint8List get key => store.identity.public;
  int get reg => store.registrationId;
  ({int dev, Uint8List key, int reg}) get entry =>
      (dev: id, key: key, reg: reg);
}

class _Sent {
  _Sent(this.ident, this.arg, this.cipher, this.opener);
  final int ident;
  final String arg;
  final String cipher;
  final bool opener;
  int get device => int.parse(arg.split('/')[1]);
}

class _Wire implements DeviceWire {
  final sent = <_Sent>[];
  @override
  Future<String> send(int ident, String arg, String cipher) async {
    sent.add(_Sent(ident, arg, cipher, false));
    return 'ok';
  }

  @override
  Future<String> sendOpener(int ident, String arg, String cipher) async {
    sent.add(_Sent(ident, arg, cipher, true));
    return 'ok';
  }
}

class _Listen implements DeviceListen {
  final heard = <String>{};
  final seeds = <String>[];
  // a listen on a seeded pair takes the place of any seed held, as the
  // engine's subscribe on the same tag does
  @override
  void listen(int ident, String arg) {
    if (arg.contains('.')) {
      final base = arg.split('.').first;
      heard.removeWhere((h) => h.startsWith('$base.'));
    }
    heard.add(arg);
  }

  @override
  void unlisten(int ident, String arg) {
    heard.remove(arg);
    // by tag: every seed of that pair
    if (arg.contains('.')) {
      final base = arg.split('.').first;
      heard.removeWhere((h) => h.startsWith('$base.'));
    }
  }

  @override
  Future<String> seed(int ident, String arg, String seedHex) async {
    seeds.add('$arg.$seedHex');
    return 'ok';
  }
}

(int, Uint8List) _wireOf(String w) {
  final b = base64Decode(w);
  return (b[0], Uint8List.sublistView(b, 1));
}

Map<String, dynamic> _json(String frame) =>
    jsonDecode(frame.substring('halo/1:'.length)) as Map<String, dynamic>;

// a KDB1 of [s] as a phone (device 1, on its identity), on its session
// signed prekey and a pool kyber key, as a contact's device builds from
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

String _hex32(int b) =>
    List.filled(32, b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  final opened = <HaloDb>[];

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('device_receive');
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

  // ana's phone, bob's phone and his devices 5 and 17 (listed at 7000), and
  // device 9 of his that no list names yet. ana's own list names her desk
  // (4) when [desk]. bob's devices hold sessions to ana's phone, built from
  // its KDB1, as a list push would hand them out
  Future<_World> world({
    bool desk = false,
    String gate = 'open',
    Future<Uint8List> Function(int ident, Uint8List body)? sign,
  }) async {
    final lib = shim!;
    final db = await open();
    final anaKp = testKeyPair();
    final bobKp = testKeyPair();
    final ana = await testStore(keys: anaKp);
    final bob = await testStore(keys: bobKp);
    final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
    final bobId = lib.identityFromPrivate(bobKp.privateKey.serialize());
    await putMainIdentity(db, anaKp.privateKey.serialize());
    await db.insert('contacts', {
      'halo_id': _bobChat,
      'onion': '',
      'xpub': devHex(bob.identity.public.sublist(1)),
      'first_seen': 0,
      'last_seen': 0,
      'ident': kMainIdent,
      'ikey': devHex(bob.identity.public),
      'caps': 'dv,pq,ty',
      'accepted': 1,
    });
    final b5 = _Dev(5, await testStore());
    final b17 = _Dev(17, await testStore());
    final b9 = _Dev(9, await testStore());
    final deskDev = _Dev(4, await testStore());
    for (final d in [b5, b17, b9]) {
      await d.ds.build(
        'ana',
        1,
        lib.parseDeviceBundle(await _phoneKdb1(ana), ana.identity.public),
        ana.identity.public,
        ana.registrationId,
      );
    }
    final anaDs = DeviceSessions(ana);
    final ds = DeviceState(DeviceEngine());
    await ds.load(
      db,
      await devMineOf(db, lib),
      shimPath: KryfoSignal.loadedFrom!,
    );
    linkedDevicesForTest = true;
    deviceStateForTest(ds);
    if (desk) {
      await ds.ownMine(
        db,
        kMainIdent,
        _list(anaId, ana.registrationId, 4000, [deskDev.entry]),
      );
    }
    final bobRemote = SessionRemote.opened(bob.identity.public);
    await ds.session(db, 'opened', {
      'ident': kMainIdent,
      'identity': devHex(bob.identity.public),
      'device': 1,
      'pq': true,
    }, bobRemote);
    await ds.session(db, 'accept', {
      'identity': devHex(bob.identity.public),
      'list': base64Encode(
        _list(bobId, bob.registrationId, 7000, [b5.entry, b17.entry]),
      ),
    }, bobRemote);
    final w = _World(
      db: db,
      ana: ana,
      anaId: anaId,
      anaDs: anaDs,
      bob: bob,
      bobId: bobId,
      bobRemote: bobRemote,
      b5: b5,
      b17: b17,
      b9: b9,
      desk: deskDev,
      ds: ds,
    );
    w.send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => anaDs,
      wire: w.wire,
      listen: w.listen.listen,
      clock: () => w.clock,
      random: Random(7),
    );
    final me = (ident: kMainIdent, identity: ana.identity.public, device: 1);
    final toBob = (
      peer: _bobChat,
      identity: devHex(bob.identity.public),
      devices: true,
      phoneClassic: false,
    );
    w.me = me;
    w.toBob = toBob;
    w.recv = DeviceReceive(
      state: ds,
      db: () async => db,
      sessions: (_) async => anaDs,
      send: w.send,
      listener: w.listen,
      open: deviceOpenAt,
      me: (_) async => me,
      contact: (ident, identity) async =>
          identity == toBob.identity && gate == 'open'
          ? (me: me, c: toBob)
          : null,
      blockedChat: (ident, identity) async =>
          identity == toBob.identity && gate == 'blocked'
          ? (me: me, c: toBob)
          : null,
      phone: (me, c, frame) async {
        w.toPhone.add(frame);
        return true;
      },
      sign:
          sign ??
          (_, body) async => lib.sign(anaId, LsSigContext.deviceList, body),
      shown: (c) async => w.shown.add(c),
      clock: () => w.clock,
    );
    w.recv.alarms.listen(w.alarms.add);
    return w;
  }

  test(
    'a device opener opens only once the engine admits it, its seed '
    'and session kept, its words for the chat without the device ones',
    () async {
      if (skip()) return;
      final w = await world();
      final c = await w.b5.ds.seal(
        'ana',
        1,
        'halo/1:${jsonEncode({
          'u': 'm-1',
          'm': 'from the desk',
          'as': _hex32(0x11),
          'o': 'desk.onion',
          'cp': ['ty'],
        })}',
        w.ana.identity.public,
      );
      expect(_wireOf(c).$1, kLsPreKey);
      final got = await w.recv.receive(w.tag(w.b5, opener: true), c);
      expect(got, isNotNull);
      expect(got!.peer, _bobChat);
      final j = _json(got.frame);
      expect(j['m'], 'from the desk');
      expect(j['u'], 'm-1');
      // the device's own onion, caps and seed never reach the chat
      for (final k in ['as', 'o', 'cp']) {
        expect(j.containsKey(k), isFalse, reason: k);
      }
      expect(await w.anaDs.has(_bobChat, 5), isTrue);
      final pair = await w.db.query('pairs', where: 'their_device = 5');
      expect(devHex(pair.single['seed'] as List<int>), _hex32(0x11));
      final rec = await w.db.query('dev_openers', where: 'their_device = 5');
      expect(rec.single['key'], devHex(w.b5.key));
      expect(rec.single['at'], 0);
      expect(w.listen.seeds, ['${w.bobX}/5/1.${_hex32(0x11)}']);
      expect(w.listen.heard, contains('${w.bobX}/5/1.${_hex32(0x11)}'));
      // the same opener again opens nothing
      expect(await w.recv.receive(w.tag(w.b5, opener: true), c), isNull);
    },
  );

  test('a copy the engine turns down is wiped and nothing of it is kept, '
      'and the opener opens later once admitted', () async {
    if (skip()) return;
    final w = await world();
    final c = await w.b5.ds.seal(
      'ana',
      1,
      'halo/1:{"u":"m-2","m":"held back"}',
      w.ana.identity.public,
    );
    final (type, body) = _wireOf(c);
    Uint8List? seen;
    await expectLater(
      w.anaDs
          .open(
            _bobChat,
            5,
            type,
            body,
            w.b5.key,
            reg: w.b5.reg,
            admit: (r, rec, {required opener, required reg}) async {
              expect(opener, isTrue);
              expect(reg, w.b5.reg);
              throw const DevRefused('not_listed', {});
            },
          )
          .then((p) => seen = p),
      throwsA(isA<DevRefused>()),
    );
    expect(seen, isNull);
    expect(await w.anaDs.has(_bobChat, 5), isFalse);
    // its keys stay unspent: admitted, it opens
    final got = await w.recv.receive(w.tag(w.b5, opener: true), c);
    expect(_json(got!.frame)['m'], 'held back');
  });

  test(
    'a device off the new list is refused at once: its session, copies '
    'and listens go with the list, and what it sends after shows nothing',
    () async {
      if (skip()) return;
      final w = await world();
      final hello = await w.b17.ds.seal(
        'ana',
        1,
        'halo/1:{"u":"m-3","m":"hi from 17"}',
        w.ana.identity.public,
      );
      expect(
        await w.recv.receive(w.tag(w.b17, opener: true), hello),
        isNotNull,
      );
      expect(await w.anaDs.has(_bobChat, 17), isTrue);
      await w.db.insert('dev_out', {
        'uid': 'u-owed',
        'ident': kMainIdent,
        'peer': w.toBob.identity,
        'device': 17,
        'at': w.clock,
        'plain': 'halo/1:{}',
        'state': 'wait',
      });
      w.listen.heard.add('${w.bobX}/17/1');
      // bob's phone sends the list without 17
      final v1 = _list(w.bobId, w.bob.registrationId, 7001, [w.b5.entry]);
      final only = await w.recv.takePhone(
        kMainIdent,
        w.toBob.identity,
        'halo/1:${jsonEncode({'u': 'dl:7001', 'dl': base64Encode(v1)})}',
        w.bobRemote,
      );
      expect(only, isTrue);
      expect(await w.anaDs.has(_bobChat, 17), isFalse);
      expect(await w.db.query('dev_out', where: 'device = 17'), isEmpty);
      expect(w.listen.heard.where((h) => h.contains('/17/')), isEmpty);
      // 5 is listed and not heard from: its opener address is listened on
      expect(w.listen.heard, contains('${w.bobX}/5/1'));
      final after = await w.b17.ds.seal(
        'ana',
        1,
        'halo/1:{"u":"m-4","m":"still here"}',
        w.ana.identity.public,
      );
      expect(await w.recv.receive(w.tag(w.b17, opener: true), after), isNull);
      expect(await w.anaDs.has(_bobChat, 17), isFalse);
      expect(w.shown, isEmpty);
    },
  );

  test('an opener from a device no list names yet waits for the list, '
      'then opens and shows', () async {
    if (skip()) return;
    final w = await world();
    final c = await w.b9.ds.seal(
      'ana',
      1,
      'halo/1:{"u":"m-5","m":"before my list"}',
      w.ana.identity.public,
    );
    expect(await w.recv.receive(w.tag(w.b9, opener: true), c), isNull);
    expect(await w.db.query('dev_held_openers'), hasLength(1));
    expect(await w.anaDs.has(_bobChat, 9), isFalse);
    // the same line again is held once
    expect(await w.recv.receive(w.tag(w.b9, opener: true), c), isNull);
    expect(await w.db.query('dev_held_openers'), hasLength(1));
    final v1 = _list(w.bobId, w.bob.registrationId, 7001, [
      w.b5.entry,
      w.b9.entry,
      w.b17.entry,
    ]);
    await w.recv.takePhone(
      kMainIdent,
      w.toBob.identity,
      'halo/1:${jsonEncode({'dl': base64Encode(v1)})}',
      w.bobRemote,
    );
    expect(w.shown, hasLength(1));
    expect(w.shown.single.peer, _bobChat);
    expect(_json(w.shown.single.frame)['m'], 'before my list');
    expect(await w.db.query('dev_held_openers'), isEmpty);
    expect(await w.anaDs.has(_bobChat, 9), isTrue);
  });

  for (final lower in [true, false]) {
    test(
      'two openers that cross settle on the lower seed '
      '(${lower ? 'theirs' : 'mine'}) and both sides read each other',
      () async {
        if (skip()) return;
        final w = await world();
        // ana's phone opens to 5 from its KDB1, as a push hands it out
        await w.anaDs.build(
          _bobChat,
          5,
          w.ana.lib.parseDeviceBundle(
            await w.b5.ds.makeBundle(5),
            w.bob.identity.public,
          ),
          w.b5.key,
          w.b5.reg,
        );
        final b = await w.send.burst(
          w.me,
          w.toBob,
          'halo/1:{"u":"m-a","m":"from ana"}',
        );
        expect(b, isNotNull);
        await w.settle(1);
        final mine = w.wire.sent.single;
        expect(mine.opener, isTrue);
        final mySeed = mine.arg.split('.').last;
        final theirSeed = _hex32(lower ? 0x00 : 0xff);
        // 5 opened to ana's phone at the same time, with a seed of its own
        final theirs = await w.b5.ds.seal(
          'ana',
          1,
          'halo/1:${jsonEncode({'u': 'm-b', 'm': 'from 5', 'as': theirSeed})}',
          w.ana.identity.public,
        );
        final got = await w.recv.receive(w.tag(w.b5, opener: true), theirs);
        expect(_json(got!.frame)['m'], 'from 5');
        final seed = devHex(
          (await w.db.query('pairs', where: 'their_device = 5')).single['seed']
              as List<int>,
        );
        expect(seed, lower ? theirSeed : mySeed);
        expect(w.listen.seeds, lower ? ['${w.bobX}/5/1.$theirSeed'] : isEmpty);
        if (lower) {
          expect(w.listen.heard, contains('${w.bobX}/5/1.$theirSeed'));
          expect(w.listen.heard, isNot(contains('${w.bobX}/5/1.$mySeed')));
        }
        // 5 reads ana's crossed opener too, then each side's next is read
        final (t1, b1) = _wireOf(mine.cipher);
        final p1 = await w.b5.ds.open(
          'ana',
          1,
          t1,
          b1,
          w.ana.identity.public,
          reg: w.ana.registrationId,
        );
        expect(_json(unpad(utf8.decode(p1)))['m'], 'from ana');
        final next = await w.b5.ds.seal(
          'ana',
          1,
          'halo/1:{"u":"m-c","m":"settled"}',
          w.ana.identity.public,
        );
        final got2 = await w.recv.receive(w.tag(w.b5), next);
        expect(_json(got2!.frame)['m'], 'settled');
        // heard on the seeded pair: its opener address is let go
        expect(w.listen.heard, isNot(contains('${w.bobX}/5/1')));
        final back = await w.anaDs.seal(
          _bobChat,
          5,
          'halo/1:{"u":"m-d","m":"and back"}',
          w.b5.key,
        );
        final (t2, b2) = _wireOf(back);
        expect(t2, kLsWhisper);
        final p2 = await w.b5.ds.open(
          'ana',
          1,
          t2,
          b2,
          w.ana.identity.public,
          reg: w.ana.registrationId,
        );
        expect(_json(unpad(utf8.decode(p2)))['m'], 'and back');
      },
    );
  }

  test('a list older than the one held goes back to their phone once per '
      'version refused', () async {
    if (skip()) return;
    final w = await world();
    Future<void> older(int v) => w.recv.takePhone(
      kMainIdent,
      w.toBob.identity,
      'halo/1:${jsonEncode({
        'dl': base64Encode(_list(w.bobId, w.bob.registrationId, v, [w.b5.entry])),
      })}',
      w.bobRemote,
    );
    await older(6990);
    expect(w.toPhone, hasLength(1));
    final dh = _json(w.toPhone.single)['dh'] as String;
    final held = base64Decode(dh);
    expect(ByteData.sublistView(held, 37, 45).getUint64(0), 7000);
    await older(6990);
    expect(w.toPhone, hasLength(1));
    await older(6980);
    expect(w.toPhone, hasLength(2));
  });

  test(
    'my own list handed back above mine is signed above it, goes to every '
    'contact at once, and each device it names that I do not is told',
    () async {
      if (skip()) return;
      final w = await world(desk: true);
      final laptop = await testStore();
      final above = _list(w.anaId, w.ana.registrationId, 4100, [
        w.desk.entry,
        (dev: 6, key: laptop.identity.public, reg: laptop.registrationId),
      ]);
      final only = await w.recv.takePhone(
        kMainIdent,
        w.toBob.identity,
        'halo/1:${jsonEncode({'dh': base64Encode(above)})}',
        w.bobRemote,
      );
      expect(only, isTrue);
      final cur = await w.ds.call(w.db, 'current', {'ident': kMainIdent});
      final wire = base64Decode(cur['list'] as String);
      expect(
        ByteData.sublistView(wire, 37, 45).getUint64(0),
        greaterThan(4100),
      );
      expect([for (final e in cur['devices'] as List) e['id']], [1, 4]);
      expect(w.alarms.single.kind, 'unknown_device');
      expect(w.alarms.single.key, devHex(laptop.identity.public));
      final pushes = await w.db.query('dev_pushes');
      expect(pushes.single['kind'], 'remove');
      expect(pushes.single['peer'], w.toBob.identity);
      expect(pushes.single['due_at'], w.clock);
      // the same hand back again changes nothing
      await w.recv.takePhone(
        kMainIdent,
        w.toBob.identity,
        'halo/1:${jsonEncode({'dh': base64Encode(above)})}',
        w.bobRemote,
      );
      final again = await w.ds.call(w.db, 'current', {'ident': kMainIdent});
      expect(again['list'], cur['list']);
    },
  );

  test('a bundle ask is answered once a day per device for the contact, '
      'whichever device of theirs asks', () async {
    if (skip()) return;
    final w = await world(desk: true);
    await w.ds.call(w.db, 'pool_put', {
      'ident': kMainIdent,
      'device': 4,
      'once': [
        for (var i = 0; i < 4; i++) base64Encode(await w.desk.ds.makeBundle(4)),
      ],
      'last': base64Encode(await w.desk.ds.lastResortBundle(4)),
      'made': w.clock,
      'now': w.clock,
    });
    Future<void> ask() => w.recv.takePhone(
      kMainIdent,
      w.toBob.identity,
      'halo/1:{"dq":[4]}',
      w.bobRemote,
    );
    await ask();
    expect(w.toPhone, hasLength(1));
    final db = _json(w.toPhone.single)['db'] as List;
    expect(db, hasLength(1));
    // a KDB1 of the desk, its id and key
    final blk = w.ana.lib.parseDeviceBundle(
      base64Decode(db.single as String),
      w.ana.identity.public,
    );
    expect(blk.deviceId, 4);
    await ask();
    expect(w.toPhone, hasLength(1));
    // their device 5 asking the same day gets nothing more either
    final c = await w.b5.ds.seal(
      'ana',
      1,
      'halo/1:{"dq":[4]}',
      w.ana.identity.public,
    );
    expect(await w.recv.receive(w.tag(w.b5, opener: true), c), isNull);
    expect(w.toPhone, hasLength(1));
    expect(await w.db.query('dev_out'), isEmpty);
    w.clock += const Duration(days: 1).inMilliseconds;
    await ask();
    expect(w.toPhone, hasLength(2));
  });

  test('a pushed bundle builds the session its copies waited for', () async {
    if (skip()) return;
    final w = await world();
    await w.db.insert('dev_out', {
      'uid': 'u-wait',
      'ident': kMainIdent,
      'peer': w.toBob.identity,
      'device': 9,
      'at': w.clock,
      'plain': 'halo/1:{"u":"u-wait","m":"waited"}',
      'state': 'wait',
      'next_at': 0,
    });
    final v1 = _list(w.bobId, w.bob.registrationId, 7001, [
      w.b5.entry,
      w.b9.entry,
      w.b17.entry,
    ]);
    await w.recv.takePhone(
      kMainIdent,
      w.toBob.identity,
      'halo/1:${jsonEncode({
        'dl': base64Encode(v1),
        'db': [base64Encode(await w.b9.ds.makeBundle(9))],
      })}',
      w.bobRemote,
    );
    expect(await w.anaDs.has(_bobChat, 9), isTrue);
    final row = (await w.db.query('dev_out')).single;
    expect(row['next_at'], w.clock);
    // a bundle of a device the list does not name builds nothing
    final stray = _Dev(33, await testStore());
    await w.recv.takePhone(
      kMainIdent,
      w.toBob.identity,
      'halo/1:${jsonEncode({
        'db': [base64Encode(await stray.ds.makeBundle(33))],
      })}',
      w.bobRemote,
    );
    expect(await w.anaDs.has(_bobChat, 33), isFalse);
  });

  test('receipts from two devices: the first counts, the second shows '
      'nothing', () async {
    if (skip()) return;
    final w = await world();
    for (final d in [w.b5, w.b17]) {
      final c = await d.ds.seal(
        'ana',
        1,
        'halo/1:{"dr":"m-out"}',
        w.ana.identity.public,
      );
      final got = await w.recv.receive(w.tag(d, opener: true), c);
      if (identical(d, w.b5)) {
        expect(_json(got!.frame)['dr'], 'm-out');
      } else {
        expect(got, isNull);
      }
    }
  });

  test('a linked device answers its phone\'s ask with a batch the phone '
      'ages from the ask', () async {
    if (skip()) return;
    final lib = shim!;
    final db = await open();
    final anaKp = testKeyPair();
    final ana = await testStore(keys: anaKp);
    final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
    final deskKp = testKeyPair();
    final deskStore = await testStore(keys: deskKp);
    // the desk: its own key on row 0, the account's identity beside it
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
    final ownList = _list(anaId, ana.registrationId, 4000, [
      (dev: 4, key: deskStore.identity.public, reg: deskStore.registrationId),
    ]);
    await ds.session(db, 'own_set', {
      'ident': kMainIdent,
      'identity': devHex(ana.identity.public),
      'list': base64Encode(ownList),
    }, SessionRemote.opened(ana.identity.public));
    var clock = 1_780_000_000_000;
    final wire = _Wire();
    final deskDs = DeviceSessions(deskStore, linked: true);
    final send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => deskDs,
      wire: wire,
      clock: () => clock,
      random: Random(3),
    );
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
      clock: () => clock,
    );
    // the phone opens its own session to the desk and asks for 3
    final phoneDs = DeviceSessions(ana);
    await phoneDs.build(
      kOwnDevices,
      4,
      lib.parseDeviceBundle(await deskDs.makeBundle(4), ana.identity.public),
      deskStore.identity.public,
      deskStore.registrationId,
    );
    final askedAt = clock - 5000;
    final ask = await phoneDs.seal(
      kOwnDevices,
      4,
      'halo/1:${jsonEncode({
        'dn': {'n': 3, 'a': askedAt},
        'as': _hex32(0x22),
      })}',
      deskStore.identity.public,
    );
    final anaX = devHex(ana.identity.public).substring(2);
    expect(await recv.receive('$anaX/1/4/opn', ask), isNull);
    for (var i = 0; i < 200 && wire.sent.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final back = wire.sent.single;
    expect(back.arg, '$anaX/1/4.${_hex32(0x22)}');
    final (t, b) = _wireOf(back.cipher);
    final plain = await phoneDs.open(
      kOwnDevices,
      4,
      t,
      b,
      deskStore.identity.public,
      reg: deskStore.registrationId,
    );
    final j = _json(unpad(utf8.decode(plain)));
    expect(j['db'], hasLength(3));
    expect(j['dz'], isA<String>());
    expect(j['dk'], clock);
    expect(j['da'], askedAt);
  });

  test('a blocked contact\'s device is opened and left to the block: its words '
      'for the chat come, nothing of it is taken or answered', () async {
    if (skip()) return;
    final w = await world(desk: true, gate: 'blocked');
    final c = await w.b5.ds.seal(
      'ana',
      1,
      'halo/1:${jsonEncode({
        'u': 'm-blk',
        'm': 'while blocked',
        'as': _hex32(0x33),
        'dq': [4],
      })}',
      w.ana.identity.public,
    );
    final got = await w.recv.receive(w.tag(w.b5, opener: true), c);
    expect(got!.peer, _bobChat);
    final j = _json(got.frame);
    expect(j['u'], 'm-blk');
    expect(j.containsKey('dq'), isFalse);
    expect(j.containsKey('as'), isFalse);
    expect(w.toPhone, isEmpty);
    expect(await w.db.query('pairs'), isEmpty);
    expect(w.listen.seeds, isEmpty);
    // an opener of theirs no list names is not held for them either
    final early = await w.b9.ds.seal(
      'ana',
      1,
      'halo/1:{"u":"m-blk9","m":"x"}',
      w.ana.identity.public,
    );
    expect(await w.recv.receive(w.tag(w.b9, opener: true), early), isNull);
    expect(await w.db.query('dev_held_openers'), isEmpty);
  });

  test('a hidden contact\'s device line (not on the everyday side) opens '
      'nothing and keeps nothing', () async {
    if (skip()) return;
    final w = await world(gate: 'hidden');
    for (final d in [w.b5, w.b9]) {
      final c = await d.ds.seal(
        'ana',
        1,
        'halo/1:{"u":"m-hid","m":"hidden"}',
        w.ana.identity.public,
      );
      expect(await w.recv.receive(w.tag(d, opener: true), c), isNull);
      expect(await w.anaDs.has(_bobChat, d.id), isFalse);
    }
    expect(await w.db.query('dev_held_openers'), isEmpty);
    expect(await w.db.query('pairs'), isEmpty);
    expect(await w.db.query('dev_marks'), isEmpty);
  });

  test('a held opener keeps its first time across retries: a list that '
      'still does not name it does not start its 7 days again', () async {
    if (skip()) return;
    final w = await world();
    final c = await w.b9.ds.seal(
      'ana',
      1,
      'halo/1:{"u":"m-early","m":"early"}',
      w.ana.identity.public,
    );
    final came = w.clock;
    expect(await w.recv.receive(w.tag(w.b9, opener: true), c), isNull);
    w.clock += const Duration(days: 3).inMilliseconds;
    final v1 = _list(w.bobId, w.bob.registrationId, 7001, [w.b5.entry]);
    await w.recv.takePhone(
      kMainIdent,
      w.toBob.identity,
      'halo/1:${jsonEncode({'dl': base64Encode(v1)})}',
      w.bobRemote,
    );
    final row = (await w.db.query('dev_held_openers')).single;
    expect(row['came_at'], came);
    // past its 7 days from the first time, a retry lets it go
    w.clock += const Duration(days: 5).inMilliseconds;
    final v2 = _list(w.bobId, w.bob.registrationId, 7002, [w.b5.entry]);
    await w.recv.takePhone(
      kMainIdent,
      w.toBob.identity,
      'halo/1:${jsonEncode({'dl': base64Encode(v2)})}',
      w.bobRemote,
    );
    expect(await w.db.query('dev_held_openers'), isEmpty);
  });

  test('a forgotten contact\'s device pairs are heard on no more and their '
      'marks go', () async {
    if (skip()) return;
    final w = await world();
    final c = await w.b5.ds.seal(
      'ana',
      1,
      'halo/1:${jsonEncode({'u': 'm-f', 'm': 'x', 'as': _hex32(0x44)})}',
      w.ana.identity.public,
    );
    await w.recv.receive(w.tag(w.b5, opener: true), c);
    await w.recv.listenAll();
    expect(w.listen.heard.where((h) => h.startsWith(w.bobX)), isNotEmpty);
    await w.db.insert('dev_marks', {
      'ident': kMainIdent,
      'peer': w.toBob.identity,
      'kind': 'alarm:claim',
      'key': '',
      'at': w.clock,
    });
    await w.recv.forget(kMainIdent, w.toBob.identity);
    expect(w.listen.heard.where((h) => h.startsWith(w.bobX)), isEmpty);
    expect(await w.db.query('dev_marks'), isEmpty);
  });

  test('a throw in the device words after the open keeps the copy\'s words '
      'for the chat', () async {
    if (skip()) return;
    final w = await world(
      desk: true,
      sign: (_, _) async => throw StateError('the signer is gone'),
    );
    final above = _list(w.anaId, w.ana.registrationId, 4100, [w.desk.entry]);
    final c = await w.b5.ds.seal(
      'ana',
      1,
      'halo/1:${jsonEncode({'u': 'm-keep', 'm': 'kept all the same', 'dh': base64Encode(above)})}',
      w.ana.identity.public,
    );
    final got = await w.recv.receive(w.tag(w.b5, opener: true), c);
    expect(_json(got!.frame)['m'], 'kept all the same');
    expect(await w.anaDs.has(_bobChat, 5), isTrue);
  });

  test('the listens and unlistens of one tag run in the order asked', () async {
    final order = <String>[];
    Future<String> step(String name, int ms) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      order.add(name);
      return 'ok';
    }

    const x =
        'aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11';
    final slow = deviceTagStepDone(0, '$x/5/1.00', () => step('unlisten', 60));
    final fast = deviceTagStepDone(0, '$x/5/1.ff', () => step('listen', 1));
    // another tag (the opener address) is not held up by them
    final other = deviceTagStepDone(0, '$x/5/1', () => step('opener', 1));
    await Future.wait([slow, fast, other]);
    expect(order, ['opener', 'unlisten', 'listen']);
  });

  test('with the switch off nothing is opened, taken or listened on', () async {
    if (skip()) return;
    final w = await world();
    final c = await w.b5.ds.seal(
      'ana',
      1,
      'halo/1:{"u":"m-off","m":"off"}',
      w.ana.identity.public,
    );
    linkedDevicesForTest = false;
    expect(await w.recv.receive(w.tag(w.b5, opener: true), c), isNull);
    expect(await w.anaDs.has(_bobChat, 5), isFalse);
    final v1 = _list(w.bobId, w.bob.registrationId, 7001, [w.b5.entry]);
    expect(
      await w.recv.takePhone(
        kMainIdent,
        w.toBob.identity,
        'halo/1:${jsonEncode({'dl': base64Encode(v1)})}',
        w.bobRemote,
      ),
      isFalse,
    );
    await w.recv.listenAll();
    expect(w.listen.heard, isEmpty);
    linkedDevicesForTest = true;
    final cur = await w.ds.call(w.db, 'current', {
      'identity': w.toBob.identity,
    });
    expect([for (final e in cur['devices'] as List) e['id']], [1, 5, 17]);
    expect(deviceTagOf('${w.bobX}/5/1/opn'), isNotNull);
    expect(deviceTagOf(w.bobX), isNull);
  });
}

class _World {
  _World({
    required this.db,
    required this.ana,
    required this.anaId,
    required this.anaDs,
    required this.bob,
    required this.bobId,
    required this.bobRemote,
    required this.b5,
    required this.b17,
    required this.b9,
    required this.desk,
    required this.ds,
  });
  final Database db;
  final SignalSession ana;
  final LsIdentity anaId;
  final DeviceSessions anaDs;
  final SignalSession bob;
  final LsIdentity bobId;
  final SessionRemote bobRemote;
  final _Dev b5;
  final _Dev b17;
  final _Dev b9;
  final _Dev desk;
  final DeviceState ds;
  final wire = _Wire();
  final listen = _Listen();
  final toPhone = <String>[];
  final shown = <DevCopyIn>[];
  final alarms = <DevAlarm>[];
  int clock = 1_780_000_000_000;
  late DeviceSend send;
  late DeviceReceive recv;
  late DevMe me;
  late DevContact toBob;

  String get bobX => devHex(bob.identity.public).substring(2);

  String tag(_Dev d, {bool opener = false}) =>
      '$bobX/${d.id}/1${opener ? '/opn' : ''}';

  Future<void> settle(int n) async {
    for (var i = 0; i < 400 && wire.sent.length < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
