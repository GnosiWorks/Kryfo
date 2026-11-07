// SPDX-License-Identifier: GPL-3.0-or-later
// a computer just linked writes to a 0.6 contact at once: the desk opens
// bob's chat and asks ana's phone for his push now, the phone pushes her
// list and a bundle of the desk to bob ahead of its spread, bob's phone
// builds the pair and starts it there and then, the desk answers, and the
// desk's first message opens on bob's phone without bob ever writing
// first. bob's reply reaches ana's phone and her desk. one engine in this
// process: each side's state is loaded from its own rows before it acts,
// as a start would. host shim and host engine
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
import 'package:kryfo/main.dart'
    show HaloDb, deviceOpenAt, deviceStateForTest, devMineOf;
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
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

const _anaChat = 'ana-bright-hill';
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

class _Sent {
  _Sent(this.arg, this.cipher, this.opener);
  final String arg;
  final String cipher;
  final bool opener;
}

class _Wire implements DeviceWire {
  final sent = <_Sent>[];
  @override
  Future<String> send(int ident, String arg, String cipher) async {
    sent.add(_Sent(arg, cipher, false));
    return 'ok';
  }

  @override
  Future<String> sendOpener(int ident, String arg, String cipher) async {
    sent.add(_Sent(arg, cipher, true));
    return 'ok';
  }
}

class _Listen implements DeviceListen {
  final heard = <String>{};
  @override
  void listen(int ident, String arg) => heard.add(arg);
  @override
  void unlisten(int ident, String arg) => heard.remove(arg);
  @override
  Future<String> seed(int ident, String arg, String seedHex) async => 'ok';
}

Map<String, dynamic> _json(String frame) =>
    jsonDecode(frame.substring('halo/1:'.length)) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  final opened = <HaloDb>[];

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('link_send_now');
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

  Future<void> settle(_Wire w, int n) async {
    for (var i = 0; i < 400 && w.sent.length < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'a computer just linked writes to a 0.6 contact before they ever '
    'wrote to it, and their reply reaches the phone and the computer',
    () async {
      if (sql == null) {
        markTestSkipped('no sqlite on this host');
        return;
      }
      if (shim == null || !_engine) {
        markTestSkipped(
          'needs the host engine (tool/host_engine.sh) and the shim',
        );
        return;
      }
      final lib = shim!;
      final anaKp = testKeyPair();
      final deskKp = testKeyPair();
      final bobKp = testKeyPair();
      final ana = await testStore(keys: anaKp);
      final desk = await testStore(keys: deskKp);
      final bob = await testStore(keys: bobKp);
      final anaId = lib.identityFromPrivate(anaKp.privateKey.serialize());
      final anaHex = devHex(ana.identity.public);
      final bobHex = devHex(bob.identity.public);
      final anaX = anaHex.substring(2);
      final bobX = bobHex.substring(2);
      final anaRemote = SessionRemote.opened(ana.identity.public);
      // ana's list since the link: her phone and the desk (4)
      final anaList = _list(anaId, ana.registrationId, 4000, [
        (dev: 4, key: desk.identity.public, reg: desk.registrationId),
      ]);

      // bob's phone: ana a contact on 0.6, her phone's session from their
      // first contact, no device of his own
      final bobHalo = HaloDb(HaloContainer.everyday);
      opened.add(bobHalo);
      final bobDb = await bobHalo.open();
      await putMainIdentity(bobDb, bobKp.privateKey.serialize());
      await bobDb.insert('contacts', {
        'halo_id': _anaChat,
        'onion': '',
        'xpub': anaX,
        'first_seen': 0,
        'last_seen': 0,
        'ident': kMainIdent,
        'ikey': anaHex,
        'caps': 'dv,pq,ty',
        'accepted': 1,
      });

      // ana's phone: bob a contact on 0.6, their session from first contact
      final anaHalo = HaloDb.withKey(HaloContainer.vault, 'ab' * 32);
      opened.add(anaHalo);
      final anaDb = await anaHalo.open();
      await putMainIdentity(anaDb, anaKp.privateKey.serialize());
      await anaDb.insert('contacts', {
        'halo_id': _bobChat,
        'onion': '',
        'xpub': bobX,
        'first_seen': 0,
        'last_seen': 0,
        'ident': kMainIdent,
        'ikey': bobHex,
        'caps': 'dv,pq,ty',
        'accepted': 1,
      });
      await ana.processBundle(
        _bobChat,
        lsBundleOf(ana.lib, await bob.makeBundleB64()),
      );
      // their first words, so the phones' session is a plain one
      await openWire(bob, _anaChat, await ana.encryptTo(_bobChat, 'halo/1:{}'));
      await openWire(ana, _bobChat, await bob.encryptTo(_anaChat, 'halo/1:{}'));

      // ana's desk: her identity's public key, device 4, bob a contact
      final deskHalo = HaloDb(HaloContainer.decoy);
      opened.add(deskHalo);
      final deskDb = await deskHalo.open();
      await putMainIdentity(deskDb, deskKp.privateKey.serialize());
      await deskDb.update('identities', {
        'ident_pub': ana.identity.public,
        'dev_id': 4,
      });
      await deskDb.insert('contacts', {
        'halo_id': _bobChat,
        'onion': '',
        'xpub': bobX,
        'first_seen': 0,
        'last_seen': 0,
        'ident': kMainIdent,
        'ikey': bobHex,
        'caps': 'dv,pq,ty',
        'accepted': 1,
      });

      final ds = DeviceState(DeviceEngine());
      linkedDevicesForTest = true;
      deviceStateForTest(ds);
      Future<void> as(Database db) async => ds.load(
        db,
        await devMineOf(db, lib),
        shimPath: KryfoSignal.loadedFrom!,
      );

      var clock = 1_780_000_000_000;
      final bobDs = DeviceSessions(bob);
      final bobWire = _Wire();
      final bobListen = _Listen();
      final bobMe = (
        ident: kMainIdent,
        identity: bob.identity.public,
        device: 1,
      );
      final toAna = (
        peer: _anaChat,
        identity: anaHex,
        devices: true,
        phoneClassic: false,
      );
      final bobSend = DeviceSend(
        state: ds,
        db: () async => bobDb,
        sessions: (_) async => bobDs,
        wire: bobWire,
        listen: bobListen.listen,
        clock: () => clock,
        random: Random(11),
      );
      final bobRecv = DeviceReceive(
        state: ds,
        db: () async => bobDb,
        sessions: (_) async => bobDs,
        send: bobSend,
        listener: bobListen,
        open: deviceOpenAt,
        me: (_) async => bobMe,
        contact: (_, identity) async =>
            identity == anaHex ? (me: bobMe, c: toAna) : null,
        phone: (_, _, _) async => true,
        sign: (_, body) async => throw StateError('bob signs no list here'),
        clock: () => clock,
      );

      final deskDs = DeviceSessions(desk, linked: true);
      final deskWire = _Wire();
      final deskListen = _Listen();
      final deskMe = (
        ident: kMainIdent,
        identity: ana.identity.public,
        device: 4,
      );
      final toBob = (
        peer: _bobChat,
        identity: bobHex,
        devices: true,
        phoneClassic: false,
      );
      final deskSend = DeviceSend(
        state: ds,
        db: () async => deskDb,
        sessions: (_) async => deskDs,
        wire: deskWire,
        listen: deskListen.listen,
        clock: () => clock,
        random: Random(12),
      );
      final reached = <String>[];
      final deskRecv = DeviceReceive(
        state: ds,
        db: () async => deskDb,
        sessions: (_) async => deskDs,
        send: deskSend,
        listener: deskListen,
        open: deviceOpenAt,
        me: (_) async => deskMe,
        contact: (_, identity) async =>
            identity == bobHex ? (me: deskMe, c: toBob) : null,
        phone: (_, _, _) async => false,
        sign: (_, _) async => throw StateError('a linked device never signs'),
        clock: () => clock,
      )..opened = reached.add;
      const hello = 'halo/1:{"u":"m-1","m":"hello from the desk","w":1}';

      final anaDs = DeviceSessions(ana);
      final anaWire = _Wire();
      final anaMe = (
        ident: kMainIdent,
        identity: ana.identity.public,
        device: 1,
      );
      final anaSend = DeviceSend(
        state: ds,
        db: () async => anaDb,
        sessions: (_) async => anaDs,
        wire: anaWire,
        clock: () => clock,
        random: Random(13),
      );
      var pushDue = 0;
      final anaRecv = DeviceReceive(
        state: ds,
        db: () async => anaDb,
        sessions: (_) async => anaDs,
        send: anaSend,
        listener: _Listen(),
        open: deviceOpenAt,
        me: (_) async => anaMe,
        contact: (_, identity) async =>
            identity == bobHex ? (me: anaMe, c: toBob) : null,
        phone: (_, _, _) async => true,
        sign: (_, body) async => lib.sign(anaId, LsSigContext.deviceList, body),
        clock: () => clock,
      )..pushDue = () => pushDue++;
      final pushed = <String>[];
      Future<void> phonePushes() => anaSend.pushes(
        contact: (_, identity) async =>
            identity == bobHex ? (me: anaMe, c: toBob) : null,
        phone: (me, c) => (
          measure: (f) => ana.sealSize(c.peer, f),
          seal: (f, n) => ana.encryptTo(c.peer, f, size: n),
        ),
        send: (me, c, cipher) async {
          pushed.add(cipher);
          return true;
        },
      );

      // the link on ana's phone: her list naming the desk, the desk's batch
      // in the pool, the session between the two, and the push to bob owed,
      // late in the spread
      await as(anaDb);
      await ds.ownMine(anaDb, kMainIdent, anaList);
      await ds.session(anaDb, 'opened', {
        'ident': kMainIdent,
        'identity': bobHex,
        'device': 1,
        'pq': true,
      }, SessionRemote.opened(bob.identity.public));
      await ds.call(anaDb, 'pool_put', {
        'ident': kMainIdent,
        'device': 4,
        'once': [
          for (var i = 0; i < 3; i++) base64Encode(await deskDs.makeBundle(4)),
        ],
        'last': base64Encode(await deskDs.lastResortBundle(4)),
        'made': clock,
        'now': clock,
      });
      await anaDs.build(
        kOwnDevices,
        4,
        lib.parseDeviceBundle(await deskDs.makeBundle(4), ana.identity.public),
        desk.identity.public,
        desk.registrationId,
      );
      await anaSend.listsChanged([
        (ident: kMainIdent, version: 4000, added: [4], removed: false),
      ]);
      await anaDb.update('dev_pushes', {
        'due_at': clock + const Duration(hours: 3).inMilliseconds,
      });
      await phonePushes();
      expect(pushed, isEmpty);

      // the desk, just linked: its phone's list, the phone's first word on
      // their own session, and bob's phone listened for
      await as(deskDb);
      await ds.session(deskDb, 'own_set', {
        'ident': kMainIdent,
        'identity': anaHex,
        'list': base64Encode(anaList),
      }, anaRemote);
      final hi = base64Decode(
        await anaDs.seal(kOwnDevices, 4, 'halo/1:{}', desk.identity.public),
      );
      await deskDs.open(
        kOwnDevices,
        1,
        hi[0],
        Uint8List.sublistView(hi, 1),
        ana.identity.public,
        reg: ana.registrationId,
      );
      await deskDb.insert('pairs', {
        'ident': kMainIdent,
        'peer': anaHex,
        'their_device': 1,
        'my_device': 4,
        'conv': 4,
        'seed': Uint8List.fromList(List.filled(32, 0x44)),
      });
      await deskRecv.listenAll();
      expect(deskListen.heard, contains('$bobX/1/4'));
      // nothing of bob's reaches it yet: a send keeps nothing
      expect(await deskSend.reaches(deskMe, toBob), isFalse);
      final before = await deskSend.burst(
        deskMe,
        toBob,
        hello,
        force: true,
        ownCopy: false,
        mustReach: true,
      );
      expect(before!.copies, 0);
      expect(await deskDb.query('dev_out'), isEmpty);
      // the chat's bar asks the phone for bob's push now, once in a while
      expect(await deskRecv.askPush(kMainIdent, bobHex), isTrue);
      expect(await deskRecv.askPush(kMainIdent, bobHex), isFalse);
      await settle(deskWire, 1);
      final ask = deskWire.sent.single;
      expect(ask.arg, '$anaX/1/4.${'44' * 32}');
      deskWire.sent.clear();

      // the phone takes the ask from its desk: bob's push goes now, ahead
      // of the spread
      await as(anaDb);
      expect(await anaRecv.receive('$anaX/4/1', ask.cipher), isNull);
      expect(pushDue, 1);
      await phonePushes();
      expect(pushed, hasLength(1));
      final pushRow = (await anaDb.query('dev_pushes')).single;
      expect(pushRow['sent_at'], clock);

      // bob's phone takes ana's push: her list and a bundle of the desk, on
      // her phone's session. the pair to the desk starts there and then
      await as(bobDb);
      await ds.session(bobDb, 'opened', {
        'ident': kMainIdent,
        'identity': anaHex,
        'device': 1,
        'pq': true,
      }, anaRemote);
      final push = await openWire(bob, _anaChat, pushed.single);
      expect(_json(push)['db'], hasLength(1));
      await bobRecv.takePhone(kMainIdent, anaHex, push, anaRemote);
      expect(await bobDs.has(_anaChat, 4), isTrue);
      await settle(bobWire, 1);
      final starter = bobWire.sent.single;
      expect(starter.opener, isTrue);
      expect(starter.arg, startsWith('$anaX/4/1.'));

      // the desk: the starter opens, says nothing for the chat, is answered
      // at once, and bob is reached
      await as(deskDb);
      expect(await deskRecv.receive('$bobX/1/4/opn', starter.cipher), isNull);
      expect(reached, [_bobChat]);
      expect(await deskDs.has(_bobChat, 1), isTrue);
      expect(await deskSend.reaches(deskMe, toBob), isTrue);
      await settle(deskWire, 1);
      final answer = deskWire.sent.single;
      expect(answer.opener, isFalse);
      final seeded = starter.arg.split('.').last;
      expect(answer.arg, '$bobX/1/4.$seeded');
      expect(deskListen.heard, contains('$bobX/1/4.$seeded'));
      // and the desk writes to bob, the first word between them
      final b = await deskSend.burst(
        deskMe,
        toBob,
        hello,
        force: true,
        ownCopy: false,
        mustReach: true,
      );
      expect(b!.copies, 1);
      await settle(deskWire, 2);
      final first = deskWire.sent.last;
      expect(first.arg, '$bobX/1/4.$seeded');

      // bob's phone: the answer says nothing, the desk's message opens
      await as(bobDb);
      expect(await bobRecv.receive('$anaX/4/1', answer.cipher), isNull);
      final got = await bobRecv.receive('$anaX/4/1', first.cipher);
      expect(got, isNotNull);
      expect(got!.peer, _anaChat);
      expect(_json(got.frame)['m'], 'hello from the desk');

      // bob's reply: one copy to ana's phone on their session, one to the desk
      bobWire.sent.clear();
      clock += 1000;
      const reply = 'halo/1:{"u":"r-1","m":"hi both","w":1}';
      final r = await bobSend.burst(
        bobMe,
        toAna,
        reply,
        phone: (
          measure: (f) => bob.sealSize(_anaChat, f),
          seal: (f, n) => bob.encryptTo(_anaChat, f, size: n),
        ),
      );
      expect(r!.phone, isNotNull);
      final atPhone = await openWire(ana, _bobChat, r.phone!);
      expect(_json(atPhone)['m'], 'hi both');
      await settle(bobWire, 1);
      final toDesk = bobWire.sent.single;
      expect(toDesk.arg, '$anaX/4/1.$seeded');
      expect(toDesk.opener, isFalse);
      await as(deskDb);
      final there = await deskRecv.receive('$bobX/1/4', toDesk.cipher);
      expect(there, isNotNull);
      expect(there!.peer, _bobChat);
      expect(_json(there.frame)['m'], 'hi both');
    },
  );
}
