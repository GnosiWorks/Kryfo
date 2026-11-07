// SPDX-License-Identifier: GPL-3.0-or-later
// linked devices, the send loop: one message from ana's
// phone to bob's phone and two devices and to ana's own desk, all on one
// gift wrap size, each on its own device pair; a copy that fails goes again
// alone; receipts from two devices count once; a device with no session
// waits and its phone is asked once a day; a list push hands no bundle
// twice across a crash; additions spread, removals at once. a contact
// without the devices word and no device of mine get today's single copy,
// and with the switch off nothing here runs. host shim and host engine,
// containers in one process
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
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/own_sync.dart' show ownHash;
import 'package:kryfo/identities.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        HaloEngine,
        devMineOf,
        pushPairSeeds,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/typing.dart';
import 'package:kryfo/wire_pad.dart'
    show kPqOpenerSeal, kSealSizes, padSeal, padSealOpener, unpad, utf8Length;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'device_sessions_test.dart' show wrapOf;
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

// a device of an identity: its own store and sessions
class _Dev {
  _Dev(this.id, this.store) : ds = DeviceSessions(store, linked: true);
  final int id;
  final SignalSession store;
  final DeviceSessions ds;
  Uint8List get key => store.identity.public;
  int get reg => store.registrationId;
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
  // device -> how many sends to refuse
  final fail = <int, int>{};
  String _go(int ident, String arg, String cipher, bool opener) {
    final s = _Sent(ident, arg, cipher, opener);
    final n = fail[s.device] ?? 0;
    if (n > 0) {
      fail[s.device] = n - 1;
      return 'error: relay';
    }
    sent.add(s);
    return 'ok';
  }

  @override
  Future<String> send(int ident, String arg, String cipher) async =>
      _go(ident, arg, cipher, false);
  @override
  Future<String> sendOpener(int ident, String arg, String cipher) async =>
      _go(ident, arg, cipher, true);
}

(int, Uint8List) _wireOf(String w) {
  final b = base64Decode(w);
  return (b[0], Uint8List.sublistView(b, 1));
}

Map<String, dynamic> _json(String frame) =>
    jsonDecode(frame.substring('halo/1:'.length)) as Map<String, dynamic>;

Future<String> _openOn(
  _Dev d,
  String peer,
  SignalSession from,
  String w,
) async {
  final (type, body) = _wireOf(w);
  final p = await d.ds.open(
    peer,
    1,
    type,
    body,
    from.identity.public,
    reg: from.registrationId,
  );
  return unpad(utf8.decode(p));
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
    docs = Directory.systemTemp.createTempSync('device_send');
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
    sql?.uninstall();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip({bool engine = true}) {
    if (sql == null) {
      markTestSkipped('no sqlite on this host');
      return true;
    }
    if (engine && (shim == null || !_engine)) {
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

  test('the switch is on in this build: the devices word goes out; off, '
      'as only a test turns it, none', () {
    linkedDevicesForTest = null;
    expect(linkedDevicesOn, isTrue);
    expect(myCaps, [...kMyCaps, kCapDevices]);
    expect(capsFromWire(['ty', kCapDevices]), ['ty', kCapDevices]);
    linkedDevicesForTest = false;
    expect(identical(myCaps, kMyCaps), isTrue);
    expect(myCaps, isNot(contains(kCapDevices)));
    expect(capsFromWire(['ty', kCapDevices]), ['ty']);
  });

  // ana's phone, her desk (9), bob's phone and devices 5 and 17, and cat on
  // 0.5.x (no devices word). ana's engine state holds bob's list and, with
  // [desk], her own naming the desk
  Future<
    ({
      Database db,
      SignalSession ana,
      LsIdentity anaId,
      DeviceSessions anaDs,
      _Dev desk,
      SignalSession bob,
      LsIdentity bobId,
      List<_Dev> bobs,
      SignalSession cat,
      DeviceState ds,
      DevMe me,
      DevContact toBob,
      DevContact toCat,
      _Wire wire,
      DeviceSend send,
      int Function() now,
      void Function(Duration) wait,
      bool hasDesk,
    })
  >
  world({bool desk = true, bool bobSessions = true}) async {
    final lib = shim!;
    final db = await open();
    final anaKp = testKeyPair();
    final bobKp = testKeyPair();
    final ana = await testStore(keys: anaKp);
    final bob = await testStore(keys: bobKp);
    final cat = await testStore();
    final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
    final bobId = lib.identityFromPrivate(bobKp.privateKey.serialize());
    await putMainIdentity(db, anaKp.privateKey.serialize());
    for (final (peer, key, caps) in [
      ('bob-quiet-river', bob.identity.public, 'dv,pq,ty'),
      ('cat-slow-hill', cat.identity.public, 'pq,ty'),
    ]) {
      await db.insert('contacts', {
        'halo_id': peer,
        'onion': '',
        'xpub': devHex(key.sublist(1)),
        'first_seen': 0,
        'last_seen': 0,
        'ident': kMainIdent,
        'ikey': devHex(key),
        'caps': caps,
        'accepted': 1,
      });
    }
    final deskDev = _Dev(9, await testStore());
    final bobs = [
      for (final id in [5, 17]) _Dev(id, await testStore()),
    ];
    // the phones' sessions, as a first contact leaves them
    await ana.processBundle(
      'bob-quiet-river',
      lsBundleOf(ana.lib, await bob.makeBundleB64()),
    );
    await ana.processBundle(
      'cat-slow-hill',
      lsBundleOf(ana.lib, await cat.makeBundleB64()),
    );
    final anaDs = DeviceSessions(ana);
    for (final d in bobSessions ? bobs : const <_Dev>[]) {
      await anaDs.build(
        'bob-quiet-river',
        d.id,
        ana.lib.parseDeviceBundle(
          await d.ds.makeBundle(d.id),
          bob.identity.public,
        ),
        d.key,
        d.reg,
      );
    }
    final ds = DeviceState(DeviceEngine());
    await ds.load(
      db,
      await devMineOf(db, lib),
      shimPath: KryfoSignal.loadedFrom!,
    );
    if (desk) {
      await anaDs.build(
        kOwnDevices,
        9,
        ana.lib.parseDeviceBundle(
          await deskDev.ds.makeBundle(9),
          ana.identity.public,
        ),
        deskDev.key,
        deskDev.reg,
      );
      await ds.ownMine(
        db,
        kMainIdent,
        _list(anaId, ana.registrationId, 4000, [
          (dev: 9, key: deskDev.key, reg: deskDev.reg),
        ]),
      );
    }
    await ds.session(db, 'accept', {
      'identity': devHex(bob.identity.public),
      'list': base64Encode(
        _list(bobId, bob.registrationId, 7000, [
          for (final d in bobs) (dev: d.id, key: d.key, reg: d.reg),
        ]),
      ),
    }, SessionRemote.opened(bob.identity.public));
    await ds.session(db, 'opened', {
      'ident': kMainIdent,
      'identity': devHex(bob.identity.public),
      'device': 1,
      'pq': true,
    }, SessionRemote.opened(bob.identity.public));
    var clock = 1_780_000_000_000;
    final wire = _Wire();
    final send = DeviceSend(
      state: ds,
      db: () async => db,
      sessions: (_) async => anaDs,
      wire: wire,
      clock: () => clock,
      random: Random(7),
    );
    return (
      db: db,
      ana: ana,
      anaId: anaId,
      anaDs: anaDs,
      desk: deskDev,
      bob: bob,
      bobId: bobId,
      bobs: bobs,
      cat: cat,
      ds: ds,
      me: (ident: kMainIdent, identity: ana.identity.public, device: 1),
      toBob: (
        peer: 'bob-quiet-river',
        identity: devHex(bob.identity.public),
        devices: true,
        phoneClassic: false,
      ),
      toCat: (
        peer: 'cat-slow-hill',
        identity: devHex(cat.identity.public),
        devices: false,
        phoneClassic: false,
      ),
      wire: wire,
      send: send,
      now: () => clock,
      wait: (Duration d) => clock += d.inMilliseconds,
      hasDesk: desk,
    );
  }

  DevPhone phoneOf(SignalSession ss, String peer) => (
    measure: (f) => ss.sealSize(peer, f),
    seal: (f, n) => ss.encryptTo(peer, f, size: n),
  );

  // the hand-offs a burst starts without waiting
  Future<void> settle(_Wire w, int n) async {
    for (var i = 0; i < 400 && w.sent.length < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  // bob's phone and devices, and ana's desk, answer a first message: every
  // session after it is a plain one
  Future<void> answerAll(dynamic w) async {
    const first = 'halo/1:{"u":"u-zero","m":"hi","w":0}';
    final r = await (w.send as DeviceSend).burst(
      w.me as DevMe,
      w.toBob as DevContact,
      first,
      phone: phoneOf(w.ana as SignalSession, 'bob-quiet-river'),
    );
    final wire = w.wire as _Wire;
    final devs = [
      ...(w.bobs as List<_Dev>),
      if (w.hasDesk as bool) w.desk as _Dev,
    ];
    await settle(wire, devs.length);
    final ana = w.ana as SignalSession;
    final bob = w.bob as SignalSession;
    final anaDs = w.anaDs as DeviceSessions;
    final (t, b) = _wireOf(r!.phone!);
    await bob.open('ana-words', t, b);
    final back = _wireOf(await bob.encryptTo('ana-words', 'halo/1:{}'));
    await ana.open('bob-quiet-river', back.$1, back.$2);
    for (final d in devs) {
      final own = identical(d, w.desk);
      final s = wire.sent.lastWhere((s) => s.device == d.id);
      await _openOn(d, own ? kOwnDevices : 'ana', ana, s.cipher);
      final a = _wireOf(
        await d.ds.seal(
          own ? kOwnDevices : 'ana',
          1,
          'halo/1:{}',
          ana.identity.public,
        ),
      );
      await anaDs.open(
        own ? kOwnDevices : 'bob-quiet-river',
        d.id,
        a.$1,
        a.$2,
        d.key,
        reg: d.reg,
      );
    }
    for (final d in w.bobs as List<_Dev>) {
      await (w.send as DeviceSend).receipt(
        kMainIdent,
        (w.toBob as DevContact).identity,
        d.id,
        'u-zero',
      );
    }
    wire.sent.clear();
  }

  const frame = 'halo/1:{"u":"u-one","m":"hello","w":1}';

  test('one message reaches every device of bob and ana\'s desk, each on its '
      'own device pair, all on one gift wrap size', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world();
    final r = await w.send.burst(
      w.me,
      w.toBob,
      frame,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    expect(r, isNotNull);
    final phone = r!.phone!;
    expect(r.copies, 3);
    await settle(w.wire, 3);
    expect({for (final s in w.wire.sent) s.device}, {5, 17, 9});
    // one gift wrap for the phone's copy and every device's
    final wraps = {
      wrapOf(phone.length),
      for (final s in w.wire.sent) wrapOf(s.cipher.length),
    };
    expect(
      wraps,
      hasLength(1),
      reason:
          'sizes ${[phone.length, for (final s in w.wire.sent) s.cipher.length]}',
    );

    // bob's phone reads the frame as sent, filled to the burst
    final (t, b) = _wireOf(phone);
    final bp = await w.bob.open('ana-words', t, b);
    expect(unpad(utf8.decode(bp)), frame);
    // every copy a first one: openers, so the burst is at the second size
    expect(t, kLsPreKey);
    expect(r.size, kSealSizes[1]);
    expect(utf8Length(utf8.decode(bp)), kPqOpenerSeal);
    // each device on its own pair: its first copy to the opener address
    // with the pair's seed in it
    final pairs = await w.db.query('pairs', where: 'their_device != 1');
    expect(pairs, hasLength(3));
    for (final d in [...w.bobs, w.desk]) {
      final s = w.wire.sent.singleWhere((s) => s.device == d.id);
      expect(s.opener, isTrue);
      final own = d == w.desk;
      final peerX = own
          ? devHex(w.ana.identity.public.sublist(1))
          : devHex(w.bob.identity.public.sublist(1));
      final seed =
          pairs.singleWhere((p) => p['their_device'] == d.id)['seed']
              as List<int>;
      expect(s.arg, '$peerX/${d.id}/1.${devHex(seed)}');
      final text = await _openOn(d, own ? kOwnDevices : 'ana', w.ana, s.cipher);
      final j = _json(text);
      expect(j['as'], devHex(seed));
      if (own) {
        // the own copy's uid names its frame, its chat by kryfo id
        expect(j['u'], 'oc:${ownHash(frame)}');
        expect((j['oc'] as Map)['f'], frame);
        expect((j['oc'] as Map)['c'], 'p:${w.toBob.peer}');
      } else {
        expect(j['u'], 'u-one');
        expect(j['m'], 'hello');
      }
    }
    // owed to bob's devices until their receipts, and the desk's own copy
    // until the desk answers it
    final out = await w.db.query('dev_out', orderBy: 'device');
    expect([for (final o in out) o['device']], [5, 9, 17]);
    expect({for (final o in out) o['state']}, {'sent'});
    // L1: the desk's row is kept under the uid the desk answers, and that
    // answer ends it
    expect(out[1]['uid'], 'oc:${ownHash(frame)}');
    await w.send.receipt(
      kMainIdent,
      devHex(w.ana.identity.public),
      9,
      'oc:${ownHash(frame)}',
    );
    expect(
      [
        for (final o in await w.db.query('dev_out', orderBy: 'device'))
          o['device'],
      ],
      [5, 17],
    );
    // each counts from its hand-off as unanswered
    final quiet = await w.db.query('dev_quiet');
    expect({for (final q in quiet) q['device']}, {5, 17, 9});
  });

  test('M5 a send that must reach them keeps nothing when no device of '
      'theirs holds a session with this one, the own copy included', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world(bobSessions: false);
    expect(await w.send.reaches(w.me, w.toBob), isFalse);
    final r = await w.send.burst(
      w.me,
      w.toBob,
      frame,
      force: true,
      mustReach: true,
    );
    expect(r?.copies ?? 0, 0);
    expect(await w.db.query('dev_out'), isEmpty);
  });

  test('M5 with a session of one of their devices it goes', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w2 = await world();
    expect(await w2.send.reaches(w2.me, w2.toBob), isTrue);
    final r2 = await w2.send.burst(
      w2.me,
      w2.toBob,
      frame,
      force: true,
      mustReach: true,
    );
    expect(r2!.copies, greaterThan(0));
    await settle(w2.wire, r2.copies);
  });

  test('a contact without the devices word and no device of mine get '
      'today\'s single copy; with the switch off nothing runs', () async {
    if (skip()) return;
    final w = await world(desk: false);
    final before = await w.db.query('dev_quiet');
    // off: not even the engine is asked
    expect(
      await w.send.burst(w.me, w.toBob, frame, phone: phoneOf(w.ana, 'x')),
      isNull,
    );
    linkedDevicesForTest = true;
    expect(
      await w.send.burst(
        w.me,
        w.toCat,
        frame,
        phone: phoneOf(w.ana, 'cat-slow-hill'),
      ),
      isNull,
    );
    expect(w.wire.sent, isEmpty);
    expect(await w.db.query('dev_out'), isEmpty);
    expect(await w.db.query('dev_quiet'), before);
    // the caller then seals as today: the frame filled to its own size
    final today = await w.ana.encryptTo('cat-slow-hill', frame);
    final (t, b) = _wireOf(today);
    final p = utf8.decode(await w.cat.open('ana-words', t, b));
    expect(unpad(p), frame);
    // a fresh session's first seal: the opener, filled as today
    expect(p, padSealOpener(frame));
  });

  test('with a desk of mine, cat on 0.5.x still gets one copy on its '
      'session that reads as today\'s frame, and no device word', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world();
    final r = await w.send.burst(
      w.me,
      w.toCat,
      frame,
      phone: phoneOf(w.ana, 'cat-slow-hill'),
    );
    expect(r?.copies, 1);
    await settle(w.wire, 1);
    expect([for (final s in w.wire.sent) s.device], [9]);
    final (t, b) = _wireOf(r!.phone!);
    final p = unpad(utf8.decode(await w.cat.open('ana-words', t, b)));
    expect(p, frame);
    expect(wrapOf(r.phone!.length), wrapOf(w.wire.sent.single.cipher.length));
  });

  test('a copy the relay failed goes again alone, the same wire to the '
      'same address; receipts from two devices count once', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world(desk: false);
    w.wire.fail[17] = 1;
    await w.send.burst(
      w.me,
      w.toBob,
      frame,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    await settle(w.wire, 1);
    expect([for (final s in w.wire.sent) s.device], [5]);
    final row = (await w.db.query('dev_out', where: 'device = 17')).single;
    expect(row['state'], 'go');
    expect(row['tries'], 1);
    final sealed = row['wire'] as String;
    // not before its time
    await w.send.pump();
    expect(w.wire.sent, hasLength(1));
    w.wait(const Duration(seconds: 31));
    await w.send.pump();
    expect([for (final s in w.wire.sent) s.device], [5, 17]);
    expect(w.wire.sent.last.cipher, sealed);
    expect(w.wire.sent.last.opener, isTrue);
    // a retry of the phone's copy makes no second device copy
    await w.send.burst(
      w.me,
      w.toBob,
      frame,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    await settle(w.wire, 3);
    expect(w.wire.sent, hasLength(2));
    // no receipt in six hours: each goes again, to the opener address
    // still: the same wire, the pair's first copy
    w.wait(const Duration(hours: 6, minutes: 1));
    await w.send.pump();
    expect(w.wire.sent, hasLength(4));
    expect(
      await w.send.receipt(kMainIdent, w.toBob.identity, 5, 'u-one'),
      isTrue,
    );
    expect(
      await w.send.receipt(kMainIdent, w.toBob.identity, 17, 'u-one'),
      isFalse,
    );
    expect(await w.db.query('dev_out'), isEmpty);
  });

  test('a device with no session waits, its phone is asked once a day, and '
      'the copy goes on its burst size once the session comes', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world(desk: false);
    final late = _Dev(40, await testStore());
    await w.ds.session(w.db, 'accept', {
      'identity': w.toBob.identity,
      'list': base64Encode(
        _list(w.bobId, w.bob.registrationId, 7001, [
          for (final d in [...w.bobs, late])
            (dev: d.id, key: d.key, reg: d.reg),
        ]),
      ),
    }, SessionRemote.opened(w.bob.identity.public));
    final r = await w.send.burst(
      w.me,
      w.toBob,
      frame,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    await settle(w.wire, 2);
    final (t, b) = _wireOf(r!.phone!);
    final j = _json(unpad(utf8.decode(await w.bob.open('ana-words', t, b))));
    expect(j['dq'], [40]);
    final row = (await w.db.query('dev_out', where: 'device = 40')).single;
    expect(row['state'], 'wait');
    expect(row['next_at'], 0);
    // the same day: no second ask
    w.wait(const Duration(hours: 2));
    const second = 'halo/1:{"u":"u-two","m":"again","w":2}';
    final r2 = await w.send.burst(
      w.me,
      w.toBob,
      second,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    final (t2, b2) = _wireOf(r2!.phone!);
    final j2 = _json(unpad(utf8.decode(await w.bob.open('ana-words', t2, b2))));
    expect(j2.containsKey('dq'), isFalse);
    // the bundle comes: the first copy goes, at its size
    await w.anaDs.build(
      'bob-quiet-river',
      40,
      w.ana.lib.parseDeviceBundle(
        await late.ds.makeBundle(40),
        w.bob.identity.public,
      ),
      late.key,
      late.reg,
    );
    await w.send.sessionCame(kMainIdent, w.toBob.identity, 40);
    final n = w.wire.sent.length;
    await w.send.pump();
    final went = w.wire.sent.sublist(n).where((s) => s.device == 40).toList();
    expect(went, hasLength(2));
    expect(went.first.opener, isTrue);
    expect(wrapOf(went.first.cipher.length), wrapOf(r.phone!.length));
    final text = await _openOn(late, 'ana', w.ana, went.first.cipher);
    expect(_json(text)['u'], 'u-one');
  });

  test('after the answers, a message whose own copy is longer lifts every '
      'copy, the phone\'s too, to one gift wrap', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world();
    await answerAll(w);
    final text = 'halo/1:{"u":"u-mid","m":"${'y' * 770}","w":4}';
    // alone, the phone's copy would take the first size
    expect(utf8Length(padSeal(text)), kSealSizes[0]);
    final r = await w.send.burst(
      w.me,
      w.toBob,
      text,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    expect(r!.size, kSealSizes[1]);
    await settle(w.wire, 3);
    expect(w.wire.sent, hasLength(3));
    final wraps = {
      wrapOf(r.phone!.length),
      for (final s in w.wire.sent) wrapOf(s.cipher.length),
    };
    expect(wraps, hasLength(1));
    for (final s in w.wire.sent) {
      expect(isOpener(s.cipher), isFalse);
      expect(s.opener, isFalse);
    }
    final (t, b) = _wireOf(r.phone!);
    final p = utf8.decode(await w.bob.open('ana-words', t, b));
    expect(unpad(p), text);
    expect(utf8Length(p), kSealSizes[1]);
  });

  test(
    'a long message to devices that never answered: each gets a small '
    'starter alone, and the message once it answers, on the burst size',
    () async {
      if (skip()) return;
      linkedDevicesForTest = true;
      final w = await world(desk: false);
      // bob's phone answered before; his devices did not
      final (t0, b0) = _wireOf(
        await w.ana.encryptTo('bob-quiet-river', 'halo/1:{}'),
      );
      await w.bob.open('ana-words', t0, b0);
      final (t1, b1) = _wireOf(await w.bob.encryptTo('ana-words', 'halo/1:{}'));
      await w.ana.open('bob-quiet-river', t1, b1);
      final long = 'halo/1:{"u":"u-long","m":"${'x' * 1500}","w":3}';
      final r = await w.send.burst(
        w.me,
        w.toBob,
        long,
        phone: phoneOf(w.ana, 'bob-quiet-river'),
      );
      expect(r!.size, kSealSizes[1]);
      await settle(w.wire, 2);
      expect(w.wire.sent, hasLength(2));
      for (final d in w.bobs) {
        final st = w.wire.sent.singleWhere((s) => s.device == d.id);
        expect(st.opener, isTrue);
        expect(isOpener(st.cipher), isTrue);
        final j = _json(await _openOn(d, 'ana', w.ana, st.cipher));
        expect(j.keys.toSet(), {'as'});
        final a = _wireOf(
          await d.ds.seal('ana', 1, 'halo/1:{}', w.ana.identity.public),
        );
        await w.anaDs.open(
          'bob-quiet-river',
          d.id,
          a.$1,
          a.$2,
          d.key,
          reg: d.reg,
        );
      }
      final waiting = await w.db.query('dev_out', where: "uid = 'u-long'");
      expect({for (final o in waiting) o['state']}, {'wait'});
      w.wait(const Duration(seconds: 31));
      await w.send.pump();
      final went = w.wire.sent.sublist(2);
      expect({for (final s in went) s.device}, {5, 17});
      for (final s in went) {
        expect(isOpener(s.cipher), isFalse);
        expect(s.opener, isFalse);
        expect(wrapOf(s.cipher.length), wrapOf(r.phone!.length));
        final d = w.bobs.singleWhere((d) => d.id == s.device);
        expect(
          _json(await _openOn(d, 'ana', w.ana, s.cipher))['m'],
          'x' * 1500,
        );
      }
    },
  );

  test('a list push: bob\'s every device gets my list and its own bundle of '
      'my desk, and a crash after the pool take hands none twice', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world();
    // they answered before: a list with bundles is no opener's size
    await answerAll(w);
    // the desk's batch in the phone's pool
    final once = [for (var i = 0; i < 5; i++) await w.desk.ds.makeBundle(9)];
    await w.ds.call(w.db, 'pool_put', {
      'ident': kMainIdent,
      'device': 9,
      'once': [for (final b in once) base64Encode(b)],
      'last': base64Encode(await w.desk.ds.lastResortBundle(9)),
      'made': w.now(),
      'now': w.now(),
    });
    await w.send.devicesShown(kMainIdent, w.toBob.identity);
    final push = (await w.db.query('dev_pushes')).single;
    expect(push['devs'], '9');
    w.wait(const Duration(minutes: 11));

    Future<({DevMe me, DevContact c})?> who(int ident, String id) async =>
        id == w.toBob.identity ? (me: w.me, c: w.toBob) : null;
    // the crash: the phone's seal dies after the bundles were taken
    var crash = true;
    final phones = <String>[];
    DevPhone phone(DevMe me, DevContact c) => (
      measure: (f) => w.ana.sealSize(c.peer, f),
      seal: (f, n) async {
        if (crash) throw StateError('crash');
        return w.ana.encryptTo(c.peer, f, size: n);
      },
    );
    Future<bool> sendPhone(DevMe me, DevContact c, String cipher) async {
      phones.add(cipher);
      return true;
    }

    await w.send.pushes(contact: who, phone: phone, send: sendPhone);
    expect(w.wire.sent, isEmpty);
    expect(phones, isEmpty);
    final spent = {
      for (final r in await w.db.query('dev_pool', where: 'kdb1 IS NULL'))
        r['kyber_id'] as int,
    };
    expect(spent, hasLength(3), reason: 'one for each of bob\'s devices');
    // the start again, from the rows
    final again = DeviceState(DeviceEngine());
    await again.load(
      w.db,
      await devMineOf(w.db, shim!),
      shimPath: KryfoSignal.loadedFrom!,
    );
    final send2 = DeviceSend(
      state: again,
      db: () async => w.db,
      sessions: (_) async => w.anaDs,
      wire: w.wire,
      clock: w.now,
      random: Random(8),
    );
    crash = false;
    // past the failed push's wait
    w.wait(const Duration(minutes: 1));
    await send2.pushes(contact: who, phone: phone, send: sendPhone);
    await settle(w.wire, 2);
    expect(phones, hasLength(1));
    expect({for (final s in w.wire.sent) s.device}, {5, 17});
    final handed = <int>{};
    Future<void> takes(String text) async {
      final j = _json(text);
      expect(base64Decode(j['dl'] as String), isNotEmpty);
      final dbs = (j['db'] as List).cast<String>();
      expect(dbs, hasLength(1));
      final bl = w.bob.lib.parseDeviceBundle(
        base64Decode(dbs.single),
        w.ana.identity.public,
      );
      expect(bl.deviceId, 9);
      final k = bl.bundle.kyberPreKeyId;
      // the ones taken before the crash, kept on the push: none new
      expect(spent, contains(k));
      expect(handed.add(k), isTrue, reason: 'one bundle to two devices');
    }

    final (t, b) = _wireOf(phones.single);
    await takes(unpad(utf8.decode(await w.bob.open('ana-words', t, b))));
    for (final d in w.bobs) {
      final s = w.wire.sent.singleWhere((s) => s.device == d.id);
      await takes(await _openOn(d, 'ana', w.ana, s.cipher));
    }
    expect({
      for (final r in await w.db.query('dev_pool', where: 'kdb1 IS NULL'))
        r['kyber_id'] as int,
    }, spent);
    final sent = (await w.db.query('dev_pushes')).single;
    expect(sent['sent_at'], w.now());
    // bob answers after it: the push is done
    await w.send.heard(kMainIdent, w.toBob.identity, w.now() + 1);
    expect(await w.db.query('dev_pushes'), isEmpty);
    // the pool ran low: the desk is asked for more, once
    final ask = (await w.db.query('dev_out', where: "uid LIKE 'dn:%'")).single;
    expect(ask['device'], 9);
    final askedAt = ask['at'];
    final n = w.wire.sent.length;
    await send2.pump();
    await settle(w.wire, n + 1);
    final went = w.wire.sent.sublist(n).single;
    expect(went.device, 9);
    final dn =
        _json(await _openOn(w.desk, kOwnDevices, w.ana, went.cipher))['dn']
            as Map;
    // asked when two were left
    expect(dn['n'], 6);
    expect(dn['a'], askedAt);
    // and kept, for its answer's 'da'
    expect((await w.db.query('dev_asks')).single['asked_at'], askedAt);
  });

  test(
    'a copy that waited for its session in an 847 burst sends the pair\'s '
    'starter once the session comes, and goes itself after the answer',
    () async {
      if (skip()) return;
      linkedDevicesForTest = true;
      final w = await world(desk: false);
      await answerAll(w);
      final late = _Dev(40, await testStore());
      await w.ds.session(w.db, 'accept', {
        'identity': w.toBob.identity,
        'list': base64Encode(
          _list(w.bobId, w.bob.registrationId, 7001, [
            for (final d in [...w.bobs, late])
              (dev: d.id, key: d.key, reg: d.reg),
          ]),
        ),
      }, SessionRemote.opened(w.bob.identity.public));
      final r = await w.send.burst(
        w.me,
        w.toBob,
        frame,
        phone: phoneOf(w.ana, 'bob-quiet-river'),
      );
      expect(r!.size, kSealSizes[0]);
      await settle(w.wire, 2);
      await w.anaDs.build(
        'bob-quiet-river',
        40,
        w.ana.lib.parseDeviceBundle(
          await late.ds.makeBundle(40),
          w.bob.identity.public,
        ),
        late.key,
        late.reg,
      );
      await w.send.sessionCame(kMainIdent, w.toBob.identity, 40);
      var n = w.wire.sent.length;
      await w.send.pump();
      await settle(w.wire, n + 1);
      final st = w.wire.sent.sublist(n).single;
      expect(st.device, 40);
      expect(st.opener, isTrue);
      expect(isOpener(st.cipher), isTrue);
      expect(_json(await _openOn(late, 'ana', w.ana, st.cipher)).keys.toSet(), {
        'as',
      });
      final waits = (await w.db.query(
        'dev_out',
        where: "uid = 'u-one' AND device = 40",
      )).single;
      expect(waits['state'], 'wait');
      // it answers: the copy goes, a plain message on the seeded pair
      final a = _wireOf(
        await late.ds.seal('ana', 1, 'halo/1:{}', w.ana.identity.public),
      );
      await w.anaDs.open(
        'bob-quiet-river',
        40,
        a.$1,
        a.$2,
        late.key,
        reg: late.reg,
      );
      w.wait(const Duration(minutes: 11));
      n = w.wire.sent.length;
      await w.send.pump();
      await settle(w.wire, n + 1);
      final went = w.wire.sent.sublist(n).single;
      expect(went.device, 40);
      expect(went.opener, isFalse);
      expect(isOpener(went.cipher), isFalse);
      expect(wrapOf(went.cipher.length), wrapOf(r.phone!.length));
      expect(
        _json(await _openOn(late, 'ana', w.ana, went.cipher))['u'],
        'u-one',
      );
    },
  );

  test('a push whose phone copy fails spends no new bundle and sends its '
      'devices nothing more; it waits longer each time', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world();
    await answerAll(w);
    final once = [for (var i = 0; i < 6; i++) await w.desk.ds.makeBundle(9)];
    await w.ds.call(w.db, 'pool_put', {
      'ident': kMainIdent,
      'device': 9,
      'once': [for (final b in once) base64Encode(b)],
      'last': base64Encode(await w.desk.ds.lastResortBundle(9)),
      'made': w.now(),
      'now': w.now(),
    });
    await w.send.devicesShown(kMainIdent, w.toBob.identity);
    w.wait(const Duration(minutes: 11));
    var ok = false;
    final tries = <String>[];
    Future<void> push() => w.send.pushes(
      contact: (i, id) async =>
          id == w.toBob.identity ? (me: w.me, c: w.toBob) : null,
      phone: (me, c) => phoneOf(w.ana, c.peer),
      send: (me, c, cipher) async {
        tries.add(cipher);
        return ok;
      },
    );
    Future<Set<int>> spent() async => {
      for (final r in await w.db.query('dev_pool', where: 'kdb1 IS NULL'))
        r['kyber_id'] as int,
    };
    await push();
    await settle(w.wire, 2);
    final first = await spent();
    expect(first, hasLength(3));
    expect({for (final s in w.wire.sent) s.device}, {5, 17});
    final wraps = w.wire.sent.length;
    // 20 s on: not due yet; 40 s: once more, the phone's copy alone
    for (final step in [20, 20, 20]) {
      w.wait(Duration(seconds: step));
      await push();
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(tries, hasLength(2));
    expect(await spent(), first);
    expect(w.wire.sent, hasLength(wraps));
    final row = (await w.db.query('dev_pushes')).single;
    expect(row['tries'], 2);
    expect(row['next_at'] as int, greaterThan(w.now()));
    // it goes: the bundles it took the first time, nothing more
    ok = true;
    w.wait(const Duration(minutes: 3));
    await push();
    expect(tries, hasLength(3));
    expect(await spent(), first);
    expect(w.wire.sent, hasLength(wraps));
    final (t, b) = _wireOf(tries.last);
    final j = _json(unpad(utf8.decode(await w.bob.open('ana-words', t, b))));
    final k = w.bob.lib
        .parseDeviceBundle(
          base64Decode((j['db'] as List).single as String),
          w.ana.identity.public,
        )
        .bundle
        .kyberPreKeyId;
    expect(first, contains(k));
    final done = (await w.db.query('dev_pushes')).single;
    expect(done['sent_at'], w.now());
    expect(done['bundles'], '');
  });

  test('a list\'s copy to each device goes again until that device\'s '
      'receipt, and a device of theirs listed after the bundles were taken '
      'gets one of its own on the retry', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world();
    await answerAll(w);
    await w.ds.call(w.db, 'pool_put', {
      'ident': kMainIdent,
      'device': 9,
      'once': [
        for (var i = 0; i < 6; i++) base64Encode(await w.desk.ds.makeBundle(9)),
      ],
      'last': base64Encode(await w.desk.ds.lastResortBundle(9)),
      'made': w.now(),
      'now': w.now(),
    });
    await w.send.devicesShown(kMainIdent, w.toBob.identity);
    w.wait(const Duration(minutes: 11));
    var ok = false;
    final phones = <String>[];
    Future<void> push() => w.send.pushes(
      contact: (i, id) async =>
          id == w.toBob.identity ? (me: w.me, c: w.toBob) : null,
      phone: (me, c) => phoneOf(w.ana, c.peer),
      send: (me, c, cipher) async {
        phones.add(cipher);
        return ok;
      },
    );
    Future<Set<int>> spent() async => {
      for (final r in await w.db.query('dev_pool', where: 'kdb1 IS NULL'))
        r['kyber_id'] as int,
    };
    await push();
    await settle(w.wire, 2);
    final first = await spent();
    expect({for (final s in w.wire.sent) s.device}, {5, 17});
    final owed = await w.db.query('dev_out', where: "uid LIKE 'dl:%'");
    expect({for (final r in owed) r['device']}, {5, 17});
    expect({for (final r in owed) r['uid']}, {'dl:4000'});
    expect({for (final r in owed) r['state']}, {'sent'});
    String dlTo(int dev) =>
        w.wire.sent.firstWhere((s) => s.device == dev).cipher;
    final dl5 = dlTo(5);
    final dl17 = dlTo(17);
    // bob links device 40 before the push goes, and it answers
    final late = _Dev(40, await testStore());
    await w.ds.session(w.db, 'accept', {
      'identity': w.toBob.identity,
      'list': base64Encode(
        _list(w.bobId, w.bob.registrationId, 7001, [
          for (final d in [...w.bobs, late])
            (dev: d.id, key: d.key, reg: d.reg),
        ]),
      ),
    }, SessionRemote.opened(w.bob.identity.public));
    await w.anaDs.build(
      'bob-quiet-river',
      40,
      w.ana.lib.parseDeviceBundle(
        await late.ds.makeBundle(40),
        w.bob.identity.public,
      ),
      late.key,
      late.reg,
    );
    // a message to bob opens the pair to 40, which answers
    final k0 = w.wire.sent.length;
    await w.send.burst(w.me, w.toBob, 'halo/1:{"u":"u-late","m":"hi"}');
    await settle(w.wire, k0 + 3);
    final hello = w.wire.sent.sublist(k0).singleWhere((s) => s.device == 40);
    expect(hello.opener, isTrue);
    await _openOn(late, 'ana', w.ana, hello.cipher);
    final a = _wireOf(
      await late.ds.seal('ana', 1, 'halo/1:{}', w.ana.identity.public),
    );
    await w.anaDs.open(
      'bob-quiet-river',
      40,
      a.$1,
      a.$2,
      late.key,
      reg: late.reg,
    );
    ok = true;
    w.wait(const Duration(minutes: 3));
    final n = w.wire.sent.length;
    await push();
    await settle(w.wire, n + 1);
    // 5 and 17 are owed already: only 40, with a bundle of its own
    final went = w.wire.sent.sublist(n);
    expect([for (final s in went) s.device], [40]);
    final j = _json(await _openOn(late, 'ana', w.ana, went.single.cipher));
    expect(j['u'], 'dl:4000');
    // a bundle of my device, and one of my phone with the list's first send
    final dbs = [for (final x in j['db'] as List) base64Decode(x as String)];
    expect([for (final b in dbs) b[9]]..sort(), [1, 9]);
    final k = w.bob.lib
        .parseDeviceBundle(
          dbs.singleWhere((b) => b[9] == 9),
          w.ana.identity.public,
        )
        .bundle
        .kyberPreKeyId;
    expect(first, isNot(contains(k)));
    expect(await spent(), {...first, k});
    // 5's receipt ends its copy; 17's goes again six hours on, the same wire
    await w.send.receipt(kMainIdent, w.toBob.identity, 5, 'dl:4000');
    w.wait(const Duration(hours: 6, minutes: 1));
    final m = w.wire.sent.length;
    await w.send.pump();
    await settle(w.wire, m + 1);
    final again = w.wire.sent.sublist(m);
    // (the other copies still owed, the message to 40 and the desk's ask
    // for more bundles, may go in the same pump)
    final ciphers = {for (final s in again) s.cipher};
    expect(ciphers, contains(dl17));
    expect(ciphers, isNot(contains(dl5)));
  });

  test('a device session held on another key misses the message alone: the '
      'phone and the other devices still get theirs', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world(desk: false);
    final other = _Dev(5, await testStore());
    await w.anaDs.build(
      'bob-quiet-river',
      5,
      w.ana.lib.parseDeviceBundle(
        await other.ds.makeBundle(5),
        w.bob.identity.public,
      ),
      other.key,
      other.reg,
    );
    final r = await w.send.burst(
      w.me,
      w.toBob,
      frame,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    expect(r?.phone, isNotNull);
    await settle(w.wire, 1);
    expect([for (final s in w.wire.sent) s.device], [17]);
    expect(await w.db.query('dev_out', where: 'device = 5'), isEmpty);
  });

  test('a device id back on a new key gets a new seed and an opener of its '
      'own; a dropped device takes its seed along', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world(desk: false);
    await w.send.burst(
      w.me,
      w.toBob,
      frame,
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    await settle(w.wire, 2);
    Future<List<int>?> seedOf(int dev) async {
      final r = await w.db.query('pairs', where: 'their_device = $dev');
      return r.isEmpty ? null : r.single['seed'] as List<int>;
    }

    final s1 = await seedOf(5);
    expect(s1, isNotNull);
    final neu = _Dev(5, await testStore());
    await w.ds.session(w.db, 'accept', {
      'identity': w.toBob.identity,
      'list': base64Encode(
        _list(w.bobId, w.bob.registrationId, 7001, [
          (dev: 5, key: neu.key, reg: neu.reg),
          (dev: 17, key: w.bobs[1].key, reg: w.bobs[1].reg),
        ]),
      ),
    }, SessionRemote.opened(w.bob.identity.public));
    await w.anaDs.build(
      'bob-quiet-river',
      5,
      w.ana.lib.parseDeviceBundle(
        await neu.ds.makeBundle(5),
        w.bob.identity.public,
      ),
      neu.key,
      neu.reg,
    );
    final n = w.wire.sent.length;
    await w.send.burst(
      w.me,
      w.toBob,
      'halo/1:{"u":"u-two","m":"again","w":2}',
      phone: phoneOf(w.ana, 'bob-quiet-river'),
    );
    await settle(w.wire, n + 2);
    final s2 = await seedOf(5);
    expect(s2, isNot(s1));
    final rec = (await w.db.query(
      'dev_openers',
      where: 'their_device = 5',
    )).single;
    expect(rec['key'], devHex(neu.key));
    final to5 = w.wire.sent.sublist(n).singleWhere((s) => s.device == 5);
    expect(to5.opener, isTrue);
    expect(
      _json(await _openOn(neu, 'ana', w.ana, to5.cipher))['as'],
      devHex(s2!),
    );
    await w.send.dropDevice(kMainIdent, w.toBob.identity, 5);
    expect(await seedOf(5), isNull);
    expect(await w.db.query('dev_openers', where: 'their_device = 5'), isEmpty);
    expect(await seedOf(17), isNotNull);
  });

  test('an offline phone\'s backlog of additions still goes a pass at a '
      'time', () async {
    if (skip(engine: false)) return;
    if (shim == null) {
      markTestSkipped('needs the shim');
      return;
    }
    linkedDevicesForTest = true;
    final db = await open();
    for (var i = 0; i < 20; i++) {
      await db.insert('contacts', {
        'halo_id': 'c$i',
        'onion': '',
        'xpub': '',
        'first_seen': 0,
        'last_seen': 0,
        'ident': kMainIdent,
        'ikey': '05${i.toRadixString(16).padLeft(64, '0')}',
        'caps': 'dv,pq',
        'accepted': 1,
      });
    }
    var clock = 1_780_000_000_000;
    final store = await testStore();
    final send = DeviceSend(
      state: DeviceState(_PhoneOnly()),
      db: () async => db,
      sessions: (_) async => DeviceSessions(store),
      wire: _Wire(),
      clock: () => clock,
      random: Random(5),
    );
    await send.listsChanged([
      (ident: kMainIdent, version: 10, added: [9], removed: false),
    ]);
    final went = <String>[];
    Future<void> push() => send.pushes(
      contact: (i, id) async => (
        me: (ident: i, identity: Uint8List(33), device: 1),
        c: (peer: 'p-$id', identity: id, devices: true, phoneClassic: false),
      ),
      phone: (me, c) =>
          (measure: (f) async => kSealSizes[0], seal: (f, n) async => 'sealed'),
      send: (me, c, cipher) async {
        went.add(c.identity);
        return true;
      },
    );
    // the phone was off through the whole spread
    clock += const Duration(hours: 6).inMilliseconds;
    await push();
    expect(went, hasLength(kPushPerPass));
    await push();
    expect(went, hasLength(kPushPerPass));
    clock += (kPushGapMost + const Duration(minutes: 2)).inMilliseconds;
    await push();
    expect(went, hasLength(2 * kPushPerPass));
    clock += (kPushGapMost + const Duration(minutes: 2)).inMilliseconds;
    await push();
    expect(went.toSet(), hasLength(20));
  });

  test('a device of mine asks for a contact\'s push now: it goes on the next '
      'pump ahead of the spread; one owed none goes again once a day; a '
      'contact who does not read lists, or is blocked, gets none', () async {
    if (skip(engine: false)) return;
    if (shim == null) {
      markTestSkipped('needs the shim');
      return;
    }
    linkedDevicesForTest = true;
    final db = await open();
    String key(int i) => '05${i.toRadixString(16).padLeft(64, '0')}';
    for (var i = 0; i < 20; i++) {
      await db.insert('contacts', {
        'halo_id': 'c$i',
        'onion': '',
        'xpub': '',
        'first_seen': 0,
        'last_seen': 0,
        'ident': kMainIdent,
        'ikey': key(i),
        'caps': i == 19 ? 'pq' : 'dv,pq',
        'blocked': i == 18 ? 1 : 0,
        'accepted': 1,
      });
    }
    // my list names a desk, 9
    await db.insert('dev_lists', {
      'ident': kMainIdent,
      'owner': 'me',
      'version': 10,
      'wire': Uint8List(1),
    });
    var clock = 1_780_000_000_000;
    final store = await testStore();
    final send = DeviceSend(
      state: DeviceState(_PhoneOnly(desk: true)),
      db: () async => db,
      sessions: (_) async => DeviceSessions(store),
      wire: _Wire(),
      clock: () => clock,
      random: Random(5),
    );
    await send.listsChanged([
      (ident: kMainIdent, version: 10, added: [9], removed: false),
    ]);
    final went = <String>[];
    Future<void> push() => send.pushes(
      contact: (i, id) async => (
        me: (ident: i, identity: Uint8List(33), device: 1),
        c: (peer: 'p-$id', identity: id, devices: true, phoneClassic: false),
      ),
      phone: (me, c) =>
          (measure: (f) async => kSealSizes[0], seal: (f, n) async => 'sealed'),
      send: (me, c, cipher) async {
        went.add(c.identity);
        return true;
      },
    );
    // the last of the spread
    final rows = await db.query('dev_pushes', orderBy: 'due_at');
    final last = rows.last['peer'] as String;
    expect(
      (rows.last['due_at'] as int) - clock,
      greaterThan(kPushGapLeast.inMilliseconds),
    );
    expect(await send.pushNow(kMainIdent, last), isTrue);
    await push();
    expect(went, [last]);
    // the first pass comes when it is due, without the one gone
    clock += const Duration(minutes: 7).inMilliseconds;
    await push();
    expect(went, hasLength(kPushPerPass + 1));
    // sent and answered: none owed. asked again, it goes again, once a day
    await send.listTaken(kMainIdent, last, 10);
    expect(await send.pushNow(kMainIdent, last), isTrue);
    await push();
    expect(went.where((p) => p == last), hasLength(2));
    await send.listTaken(kMainIdent, last, 10);
    expect(await send.pushNow(kMainIdent, last), isFalse);
    clock += const Duration(days: 1, minutes: 1).inMilliseconds;
    expect(await send.pushNow(kMainIdent, last), isTrue);
    // no list reader, a blocked contact, someone else: nothing
    expect(await send.pushNow(kMainIdent, key(19)), isFalse);
    expect(await send.pushNow(kMainIdent, key(18)), isFalse);
    expect(await send.pushNow(kMainIdent, key(77)), isFalse);
  });

  test('a batch carries its make time, and one that answers the phone\'s ask '
      'ages from the ask: a device clock far behind loses none', () async {
    if (skip()) return;
    linkedDevicesForTest = true;
    final w = await world();
    const day = 24 * 60 * 60 * 1000;
    final behind = w.now() - 20 * day;
    // [kept]: the ask the phone made and kept; [da]: what the batch echoes
    Future<int> taken({int? kept, int? da}) async {
      if (kept != null) {
        await w.db.insert('dev_asks', {
          'ident': kMainIdent,
          'device': 9,
          'asked_at': kept,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final once = await w.desk.ds.makeBundle(9);
      final last = await w.desk.ds.lastResortBundle(9);
      final f = ownBatchFrame(
        once: [once],
        last: last,
        made: behind,
        asked: da,
      );
      final args = await w.send.batchArgs(_json(f), kMainIdent, 9);
      expect(args, isNotNull);
      await w.ds.call(w.db, 'pool_put', args!);
      final j = await w.ds.call(w.db, 'pool_take', {
        'ident': kMainIdent,
        'device': 9,
        'now': w.now(),
      });
      final bl = w.bob.lib.parseDeviceBundle(
        base64Decode(j['kdb1'] as String),
        w.ana.identity.public,
      );
      final oneTime = w.bob.lib.parseDeviceBundle(once, w.ana.identity.public);
      return bl.bundle.kyberPreKeyId == oneTime.bundle.kyberPreKeyId ? 1 : 0;
    }

    // unasked, a batch made 20 days ago is old: only the last resort goes
    expect(await taken(), 0);
    w.wait(const Duration(minutes: 1));
    // a batch that names an ask the phone never made: its make time alone
    expect(await taken(da: w.now() - 60000), 0);
    // one that names the kept ask: young
    final ask = w.now() - 60000;
    expect(await taken(kept: ask, da: ask), 1);
    // the same ask a second time: taken once only
    expect(await taken(da: ask), 0);
    // another than the kept one
    expect(await taken(kept: ask, da: ask + 1), 0);
    // no make time: no batch
    expect(ownBatchArgs({'db': <String>[]}, kMainIdent, 9, w.now()), isNull);
  });

  test('a device pair\'s seed never reaches the engine as the identity '
      'pair\'s, and only with the switch on', () async {
    if (skip(engine: false)) return;
    final live = HaloDb();
    opened.add(live);
    final db = await live.open();
    useDatabasesForTest(live, Session(live));
    final seen = <(String, String)>[];
    useEngineForTest(_SeedEngine(seen));
    final peer = '05${'ab' * 32}';
    final s1 = Uint8List.fromList(List.filled(32, 1));
    final s5 = Uint8List.fromList(List.filled(32, 5));
    for (final (dev, seed) in [(1, s1), (5, s5)]) {
      await db.insert('pairs', {
        'ident': kMainIdent,
        'peer': peer,
        'their_device': dev,
        'my_device': 1,
        'conv': 4,
        'seed': seed,
      });
    }
    await pushPairSeeds();
    expect(seen, [('ab' * 32, devHex(s1))]);
    seen.clear();
    linkedDevicesForTest = true;
    await pushPairSeeds();
    expect(seen.toSet(), {
      ('ab' * 32, devHex(s1)),
      ('${'ab' * 32}/5/1', devHex(s5)),
    });
  });

  test('additions spread, eight contacts a pass at most, both identities in '
      'one random order; removals at once', () async {
    if (skip(engine: false)) return;
    linkedDevicesForTest = true;
    final db = await open();
    for (var i = 0; i < 20; i++) {
      await db.insert('contacts', {
        'halo_id': 'c$i',
        'onion': '',
        'xpub': '',
        'first_seen': 0,
        'last_seen': 0,
        'ident': i.isEven ? 1 : 2,
        'ikey': '05${i.toRadixString(16).padLeft(64, '0')}',
        'caps': i == 19 ? 'pq' : 'dv,pq',
        'accepted': 1,
      });
    }
    const t0 = 1_780_000_000_000;
    final send = DeviceSend(
      state: DeviceState(_NoEngine()),
      db: () async => db,
      sessions: (_) async => throw StateError('no sessions'),
      wire: _Wire(),
      clock: () => t0,
      random: Random(3),
    );
    await send.listsChanged([
      (ident: 1, version: 10, added: [9], removed: false),
      (ident: 2, version: 20, added: [9], removed: true),
    ]);
    final rows = await db.query('dev_pushes', orderBy: 'due_at');
    final removes = rows.where((r) => r['kind'] == 'remove').toList();
    final adds = rows.where((r) => r['kind'] == 'add').toList();
    // c19 does not read lists
    expect(removes, hasLength(9));
    expect({for (final r in removes) r['due_at']}, {t0});
    expect(adds, hasLength(19));
    final passes = <List<Map<String, Object?>>>[];
    for (var i = 0; i < adds.length; i += kPushPerPass) {
      passes.add(adds.sublist(i, min(i + kPushPerPass, adds.length)));
    }
    expect(passes, hasLength(3));
    for (var i = 1; i < passes.length; i++) {
      final gap =
          (passes[i].first['due_at'] as int) -
          (passes[i - 1].first['due_at'] as int);
      expect(gap, greaterThanOrEqualTo(kPushGapLeast.inMilliseconds - 60000));
    }
    final order = [for (final r in adds) r['ident']];
    expect(order.toSet(), {1, 2});
    final grouped = [...order]..sort();
    expect(order, isNot(grouped), reason: 'one identity after the other');
  });
}

class _SeedEngine implements HaloEngine {
  _SeedEngine(this.seen);
  final List<(String, String)> seen;
  @override
  Future<String> pairSeed(int ident, String peer, String seedHex) async {
    seen.add((peer, seedHex));
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

// an engine whose contacts have their phones alone, and my list too (with
// [desk], my list names a desk, 9)
class _PhoneOnly implements DeviceEngine {
  _PhoneOnly({this.desk = false});
  final bool desk;
  @override
  String call(String op, Map<String, Object?> args) => switch (op) {
    'current' => jsonEncode({
      'rows': [],
      'list': base64Encode([...ascii.encode('KDL2'), 5, ...List.filled(32, 7)]),
      'devices': [
        {'id': 1, 'phone': true},
        if (desk && args['ident'] != null) {'id': 9},
      ],
    }),
    'fanout' => jsonEncode({
      'rows': [],
      'slots': [
        {
          'identity': args['contact'],
          'device': 1,
          'key': args['contact'],
          'reg': 0,
        },
      ],
    }),
    _ => jsonEncode({'rows': [], 'err': 'no_bundle'}),
  };

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

class _NoEngine implements DeviceEngine {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}
