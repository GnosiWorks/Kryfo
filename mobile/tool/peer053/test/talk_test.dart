// SPDX-License-Identifier: GPL-3.0-or-later
// a phone still on 0.5.3 and a phone on this version keep talking, both
// ways, on real stores: the 0.5.3 side runs 0.5.3's own signal layer and
// libsignal_protocol_dart 0.8.2 on its file as 0.5.3 left it; this side
// opens its file through the app's schema, every upgrade since 0.5.3, and
// runs the shim. the files are the 0.5.3 fixtures of the app's tests
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart' show DevKey, useDevKeysForTest;
import 'package:kryfo/main.dart' show HaloDb, signalDecrypt, signalStoreTables;
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart' as now;
import 'package:kryfo/wire_pad.dart' show unpad;
import 'package:path/path.dart' as p;
import 'package:peer053/peer053.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../test/sqlite_channel.dart';

const _phone = '../../test/fixtures/upgrade_053/phone';
const _host = '../../test/fixtures/upgrade_053';

final _phoneExpected =
    jsonDecode(File('$_phone/expected.json').readAsStringSync())
        as Map<String, dynamic>;
final _a = _phoneExpected['a'] as String;
final _b = _phoneExpected['b'] as String;

final _hostExpected =
    jsonDecode(File('$_host/expected.json').readAsStringSync())
        as Map<String, dynamic>;
const _me = 'quiet-maple-harbor';
const _alice = 'amber-otter-lake';
const _bob = 'brisk-cedar-moon';
const _dave = 'dusty-heron-vale';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

({Uint8List pub, Uint8List priv}) _keys(Map<String, dynamic> k) =>
    (pub: _hex(k['x_pub'] as String), priv: _hex(k['x_priv'] as String));

// the shim this side runs, as the app's tests find it
final KryfoSignal _lib = () {
  final env = Platform.environment[KryfoSignal.envVar];
  final path = env != null && env.isNotEmpty
      ? env
      : '../../native/kryfo_signal/target/release/libkryfo_signal.so';
  if (!File(path).existsSync()) {
    throw StateError(
      'libkryfo_signal not built: run native/kryfo_signal/build-host.sh',
    );
  }
  return KryfoSignal.open(File(path).absolute.path);
}();

// one side of a chat
abstract class _Side {
  Future<String> seal(String peer, String text);
  Future<String> read(String peer, String wire);
}

class _Old implements _Side {
  _Old(this.p);
  final Phone053 p;
  @override
  Future<String> seal(String peer, String text) => p.seal(peer, text);
  @override
  Future<String> read(String peer, String wire) => p.read(peer, wire);
}

class _New implements _Side {
  _New(this.s);
  final now.SignalSession s;
  @override
  Future<String> seal(String peer, String text) => s.encryptTo(peer, text);
  @override
  Future<String> read(String peer, String wire) async {
    final w = base64Decode(wire);
    final plain = await s.open(peer, w[0], Uint8List.sublistView(w, 1));
    return unpad(utf8.decode(plain));
  }
}

// a few rounds both ways, two in a row each way read out of order, and the
// answers
Future<void> _chat(_Side x, String xName, _Side y, String yName) async {
  for (var i = 0; i < 4; i++) {
    expect(await y.read(xName, await x.seal(yName, 'x $i')), 'x $i');
    expect(await x.read(yName, await y.seal(xName, 'y $i')), 'y $i');
  }
  final x1 = await x.seal(yName, 'x again');
  final x2 = await x.seal(yName, 'and again');
  expect(await y.read(xName, x2), 'and again');
  expect(await y.read(xName, x1), 'x again');
  final y1 = await y.seal(xName, 'y again');
  final y2 = await y.seal(xName, 'and y again');
  expect(await x.read(yName, y2), 'and y again');
  expect(await x.read(yName, y1), 'y again');
  expect(await y.read(xName, await x.seal(yName, 'got both')), 'got both');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  SqliteChannel? sql;
  final opened = <Database>[];

  setUp(() {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('peer053');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    SharedPreferences.setMockInitialValues({});
    useDevKeysForTest(null);
  });

  tearDown(() async {
    for (final d in opened) {
      await d.close();
    }
    opened.clear();
    sql?.uninstall();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<Database> keep(Future<Database> f) async {
    final d = await f;
    opened.add(d);
    return d;
  }

  // a file as 0.5.3 left it, copied in under [name] and opened raw
  Future<Database> raw(String from, String name) {
    File(from).copySync(p.join(docs.path, name));
    return keep(openDatabase(p.join(docs.path, name), singleInstance: false));
  }

  // a file this version opens: its schema run on it first
  Future<Database> updated(String from, HaloContainer c) {
    File(from).copySync(p.join(docs.path, c.dbFile));
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'not asked for',
      kOldDecoyKeyName: 'not asked for',
      kDecoyKeyName: 'not asked for',
    });
    return keep(HaloDb(c).open());
  }

  Future<now.SignalSession> onShim(
    Database db,
    ({Uint8List pub, Uint8List priv}) k, {
    String prefix = '',
  }) async {
    // this version's tables first, as its schema makes them on an update:
    // a file it opened through HaloDb has them already
    await signalStoreTables(db, prefix: prefix);
    final s = now.SignalSession(_lib);
    await s.bootstrap(
      database: db,
      xPubBytes: k.pub,
      xPrivBytes: k.priv,
      prefix: prefix,
    );
    return s;
  }

  // the two phone identities' keys, read from the other side's contact
  Future<({Uint8List pub, Uint8List priv})> phoneKeys(
    Database mine,
    Database theirs,
    String who,
  ) async {
    final id = await mine.query('identity', limit: 1);
    final c = await theirs.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [who],
    );
    return (
      pub: _hex(c.first['xpub'] as String),
      priv: _hex(id.first['x_priv'] as String),
    );
  }

  // a store of a phone made fresh on 0.5.3, its tables as 0.5.3 made them
  Future<Database> fresh053(String name) async {
    final d = await keep(
      openDatabase(p.join(docs.path, name), singleInstance: false),
    );
    await tables053(d);
    await d.execute(
      'CREATE TABLE contacts (halo_id TEXT PRIMARY KEY, verified INTEGER '
      'NOT NULL DEFAULT 0, key_changed INTEGER NOT NULL DEFAULT 0, '
      'verified_key TEXT)',
    );
    return d;
  }

  ({Uint8List pub, Uint8List priv}) freshKeys() {
    final rnd = Random.secure();
    final priv = Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
    priv[0] &= 0xf8;
    priv[31] = (priv[31] & 0x7f) | 0x40;
    return (pub: _lib.identityFromPrivate(priv).public.sublist(1), priv: priv);
  }

  group('two phones from the 0.5.3 release', () {
    test('a on 0.5.3, b on this version: the chat goes on both ways', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final aDb = await raw('$_phone/a.db', 'a053.db');
      final bDb = await updated('$_phone/b.db', HaloContainer.decoy);
      expect(await bDb.getVersion(), HaloDb.schema);
      expect(await aDb.getVersion(), 85);
      final a = await Phone053.open(
        aDb,
        xPub: (await phoneKeys(aDb, bDb, _a)).pub,
        xPriv: (await phoneKeys(aDb, bDb, _a)).priv,
      );
      final b = await onShim(bDb, await phoneKeys(bDb, aDb, _b));
      await _chat(_Old(a), _a, _New(b), _b);
      // still the classic session 0.5.3 made, on both sides
      expect((await b.sessionInfo(_a))!.version, 3);
      expect(await a.sessionVersion(_b), 3);
    });

    test('b on 0.5.3, a on this version: the chat goes on both ways', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final bDb = await raw('$_phone/b.db', 'b053.db');
      final aDb = await updated('$_phone/a.db', HaloContainer.everyday);
      final b = await Phone053.open(
        bDb,
        xPub: (await phoneKeys(bDb, aDb, _b)).pub,
        xPriv: (await phoneKeys(bDb, aDb, _b)).priv,
      );
      final a = await onShim(aDb, await phoneKeys(aDb, bDb, _a));
      await _chat(_New(a), _a, _Old(b), _b);
      await _chat(_Old(b), _b, _New(a), _a);
    });

    test('the app\'s own open on this side, a message in flight across '
        'the update, then both updated', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final aDb = await raw('$_phone/a.db', 'a053.db');
      final b053 = await raw('$_phone/b.db', 'b053.db');
      final ka = await phoneKeys(aDb, b053, _a);
      final kb = await phoneKeys(b053, aDb, _b);
      final a = await Phone053.open(aDb, xPub: ka.pub, xPriv: ka.priv);
      final bOld = await Phone053.open(b053, xPub: kb.pub, xPriv: kb.priv);
      await _chat(_Old(a), _a, _Old(bOld), _b);
      // a writes while b is updating; b's file is the one 0.5.3 left
      final inFlight = await a.seal(_b, 'sent while you updated');
      await b053.close();
      opened.remove(b053);
      File(
        p.join(docs.path, 'b053.db'),
      ).copySync(p.join(docs.path, HaloContainer.everyday.dbFile));
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': 'not asked for',
      });
      final bDb = await keep(HaloDb().open());
      expect(await bDb.getVersion(), HaloDb.schema);
      // the everyday store, as the app opens it, and its own decrypt
      await now.signalSession.bootstrap(
        database: bDb,
        xPubBytes: kb.pub,
        xPrivBytes: kb.priv,
      );
      expect(now.signalSession.lib.buildInfo().libsignal, kLsLibsignal);
      expect(await signalDecrypt(_a, inFlight), 'sent while you updated');
      for (var i = 0; i < 3; i++) {
        final w = await now.signalSession.encryptTo(_a, 'from b $i');
        expect(base64Decode(w)[0], kLsWhisper);
        expect(await a.read(_b, w), 'from b $i');
        expect(await signalDecrypt(_a, await a.seal(_b, 'a $i')), 'a $i');
      }
      // a copy of one already read is dropped, nothing breaks
      final once = await a.seal(_b, 'once');
      expect(await signalDecrypt(_a, once), 'once');
      expect(await signalDecrypt(_a, once), isNull);
      expect(await signalDecrypt(_a, await a.seal(_b, 'next')), 'next');
      // then a updates too: both on this version, the same session
      final aNew = await onShim(
        await updated(p.join(docs.path, 'a053.db'), HaloContainer.decoy),
        ka,
      );
      final w = await now.signalSession.encryptTo(_a, 'both updated');
      expect(await _New(aNew).read(_b, w), 'both updated');
      expect(await signalDecrypt(_a, await aNew.encryptTo(_b, 'yes')), 'yes');
      expect((await aNew.sessionInfo(_b))!.version, 3);
    });

    test('a store this version went on with reads on 0.5.3 again', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final aDb = await raw('$_phone/a.db', 'a053.db');
      final bDb = await updated('$_phone/b.db', HaloContainer.decoy);
      final ka = await phoneKeys(aDb, bDb, _a);
      final kb = await phoneKeys(bDb, aDb, _b);
      final a = await Phone053.open(aDb, xPub: ka.pub, xPriv: ka.priv);
      final b = await onShim(bDb, kb);
      await _chat(_Old(a), _a, _New(b), _b);
      // b goes back to 0.5.3's layer on the same file: the records the
      // shim wrote read there, so going back loses no chat
      final bBack = await Phone053.open(bDb, xPub: kb.pub, xPriv: kb.priv);
      await _chat(_Old(a), _a, _Old(bBack), _b);
    });
  });

  group('the 0.5.3 fixture with its chats in flight', () {
    final me = _hostExpected['me'] as Map<String, dynamic>;
    final alice = _hostExpected['alice'] as Map<String, dynamic>;
    final peerKeys = (_hostExpected['peers'] as Map).cast<String, dynamic>();
    final inFlight = (_hostExpected['in_flight'] as Map).cast<String, String>();

    test('this phone updated, everyone it talks to still on 0.5.3', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final keys =
          (jsonDecode(File('$_host/keys.json').readAsStringSync()) as Map)
              .cast<String, String>();
      File('$_host/halo.db').copySync(p.join(docs.path, 'halo.db'));
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': keys['everyday']!,
      });
      final mineDb = await keep(HaloDb().open());
      expect(await mineDb.getVersion(), HaloDb.schema);
      final mine = _New(await onShim(mineDb, _keys(me)));
      final aliceDb = await raw('$_host/halo_d.db', 'alice053.db');
      final hers = _Old(
        await Phone053.open(
          aliceDb,
          xPub: _keys(alice).pub,
          xPriv: _keys(alice).priv,
        ),
      );
      final pdb = await raw('$_host/peers.db', 'peers053.db');
      Future<_Old> peer(String prefix) async => _Old(
        await Phone053.open(
          pdb,
          xPub: _keys(peerKeys[prefix]).pub,
          xPriv: _keys(peerKeys[prefix]).priv,
          prefix: prefix,
        ),
      );
      final bob = await peer('bob_');
      final dave = await peer('dave_');
      // what was on the relay when the phone updated, both ways
      expect(
        await mine.read(_bob, inFlight['bob_to_me']!),
        'sent before the update',
      );
      expect(
        await bob.read(_me, inFlight['me_to_bob']!),
        'also before the update',
      );
      await _chat(mine, _me, bob, _bob);
      await _chat(mine, _me, hers, _alice);
      // dave never answered: the opener sent before the update, and the
      // next one sealed on the shim, both read on his side, then his answer
      expect(
        await dave.read(_me, inFlight['me_to_dave']!),
        'are you there, dave',
      );
      final next = await mine.seal(_dave, 'hello again');
      expect(base64Decode(next)[0], kLsPreKey);
      expect(await dave.read(_me, next), 'hello again');
      await _chat(dave, _dave, mine, _me);
      // a classic opener from someone new is refused here, nothing kept
      await expectLater(
        mine.read('first-contact', inFlight['stranger_to_me']!),
        throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.classic)),
      );
      final s = (mine).s;
      expect(await s.hasSession('first-contact'), isFalse);
      for (final peer in [_alice, _bob, _dave]) {
        expect((await s.sessionInfo(peer))!.version, 3, reason: peer);
      }
    });
  });

  group('what a 0.5.3 phone does that this version refuses or keeps', () {
    test('a 0.5.3 phone reading this version\'s card builds a classic '
        'session, and its opener is refused here, nothing spent', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final kOld = freshKeys();
      final kNew = freshKeys();
      final old = await Phone053.open(
        await fresh053('old.db'),
        xPub: kOld.pub,
        xPriv: kOld.priv,
      );
      final newDb = await fresh053('new.db');
      final mine = await onShim(newDb, kNew);
      // the old app skips the kyber fields it does not know
      await old.startFrom('new', await mine.makeBundleB64());
      final w = await old.seal('new', 'classic hello');
      final info = _lib.preKeyMessageInfo(base64Decode(w).sublist(1));
      expect(info.version, 3);
      final prekeys = Sqflite.firstIntValue(
        await newDb.rawQuery('SELECT COUNT(*) FROM prekeys'),
      );
      await expectLater(
        _New(mine).read('old', w),
        throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.classic)),
      );
      expect(await mine.hasSession('old'), isFalse);
      expect(await mine.identityStore.getIdentity('old'), isNull);
      expect(
        Sqflite.firstIntValue(
          await newDb.rawQuery('SELECT COUNT(*) FROM prekeys'),
        ),
        prekeys,
      );
      // and this version builds nothing on the 0.5.3 card
      final card = await old.card();
      expect(
        () => now.lsBundleOf(_lib, card),
        throwsA(isA<now.ClassicRefused>()),
      );
    });

    test(
      'an unanswered classic opener goes on after its sender updates',
      () async {
        if (sql == null) return markTestSkipped('no sqlite on this host');
        final ka = freshKeys();
        final kb = freshKeys();
        final aDb = await fresh053('a.db');
        final a053 = await Phone053.open(aDb, xPub: ka.pub, xPriv: ka.priv);
        final b = await Phone053.open(
          await fresh053('b.db'),
          xPub: kb.pub,
          xPriv: kb.priv,
        );
        await a053.startFrom('b', await b.card());
        // a updates before b answers: its next seal is still the opener
        final a = await onShim(aDb, ka);
        final w = await a.encryptTo('b', 'still classic');
        expect(base64Decode(w)[0], kLsPreKey);
        expect(await b.read('a', w), 'still classic');
        await _chat(_Old(b), 'b', _New(a), 'a');
        expect((await a.sessionInfo('b'))!.version, 3);
      },
    );

    test('restore marks 0.5.3 wrote name the same sessions here', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final aDb = await raw('$_phone/a.db', 'a053.db');
      final bDb = await raw('$_phone/b.db', 'b053.db');
      final kb = await phoneKeys(bDb, aDb, _b);
      final old = await Phone053.open(bDb, xPub: kb.pub, xPriv: kb.priv);
      await old.ss.markRestored(from: 42);
      expect(await old.ss.sealsOnRestored(_a), isTrue);
      final before = (await bDb.query(
        'signal_meta',
        where: 'k = ?',
        whereArgs: ['restored_sessions'],
      )).first['v'];
      await signalStoreTables(bDb);
      final b = await onShim(bDb, kb);
      expect(b.hasRestored, isTrue);
      expect(b.restoredFrom, 42);
      expect(await b.sealsOnRestored(_a), isTrue);
      await expectLater(
        b.encryptTo(_a, 'x'),
        throwsA(isA<now.StartingAfresh>()),
      );
      await b.markRestored(from: 42);
      final after = (await bDb.query(
        'signal_meta',
        where: 'k = ?',
        whereArgs: ['restored_sessions'],
      )).first['v'];
      expect(
        (jsonDecode(after as String) as List).toSet(),
        (jsonDecode(before as String) as List).toSet(),
      );
    });

    test('a message this version sealed opens once on 0.5.3', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final aDb = await raw('$_phone/a.db', 'a053.db');
      final bDb = await updated('$_phone/b.db', HaloContainer.decoy);
      final ka = await phoneKeys(aDb, bDb, _a);
      final a = await Phone053.open(aDb, xPub: ka.pub, xPriv: ka.priv);
      final b = await onShim(bDb, await phoneKeys(bDb, aDb, _b));
      final w = await b.encryptTo(_a, 'once');
      expect(await a.read(_b, w), 'once');
      await expectLater(a.read(_b, w), throwsA(anything));
      // a message changed on the way opens on neither side
      final bad = base64Decode(await b.encryptTo(_a, 'changed'));
      bad[bad.length - 1] ^= 1;
      await expectLater(
        a.read(_b, base64Encode(bad)),
        throwsA(isA<Exception>()),
      );
      expect(await a.read(_b, await b.encryptTo(_a, 'after')), 'after');
    });
  });

  group('a dev chat 0.5.3 started, after the update', () {
    String hex(List<int> b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

    test(
      'made by 0.5.3\'s own layer with his key pinned, it goes on both '
      'ways with either phone updated, and his key stays the only one',
      () async {
        if (sql == null) return markTestSkipped('no sqlite on this host');
        const keyId = 'm9';
        const dev = 'dev:$keyId';
        final kDev = freshKeys();
        final kUser = freshKeys();
        final devDb = await fresh053('devphone.db');
        final userDb = await fresh053('user.db');
        await tables053(userDb, prefix: 'dev_');
        // 0.5.3 on both: his phone, and a user's anonymous dev chat store
        final dev053 = await Phone053.open(
          devDb,
          xPub: kDev.pub,
          xPriv: kDev.priv,
        );
        final devKeyBytes = Uint8List.fromList([0x05, ...kDev.pub]);
        pinDevKeyForTest(keyId, devKeyBytes);
        final user053 = await Phone053.initiator(
          userDb,
          xPub: kUser.pub,
          xPriv: kUser.priv,
          prefix: 'dev_',
        );
        final card = await dev053.card();
        await user053.startFrom(dev, card);
        await _chat(_Old(user053), 'user', _Old(dev053), dev);
        // his phone updates first, the user's chat still on 0.5.3
        await signalStoreTables(devDb);
        final devNew = await onShim(devDb, kDev);
        await _chat(_Old(user053), 'user', _New(devNew), dev);
        // then the user's: the same dev_ store, his key pinned as the app pins
        useDevKeysForTest([
          DevKey(
            keyId: keyId,
            threeWords: 'test-dev-words',
            xPub: hex(kDev.pub),
            bundle: card,
            fc: 'ab' * 32,
          ),
        ]);
        addTearDown(() => useDevKeysForTest(null));
        // the user's file through this version's schema, as an update runs it
        await signalStoreTables(userDb, prefix: 'dev_');
        final userNew = now.SignalSession(_lib);
        await userNew.bootstrapInitiator(
          database: userDb,
          xPubBytes: kUser.pub,
          xPrivBytes: kUser.priv,
          prefix: 'dev_',
        );
        expect(userNew.identityStore.pinnedFor(dev), devKeyBytes);
        await _chat(_New(userNew), 'user', _New(devNew), dev);
        expect((await userNew.sessionInfo(dev))!.version, 3);
        // and back to his phone on 0.5.3's layer, the user on this version
        final devBack = await Phone053.open(
          devDb,
          xPub: kDev.pub,
          xPriv: kDev.priv,
        );
        await _chat(_New(userNew), 'user', _Old(devBack), dev);
        // a pinned key that is not his: nothing seals or opens on the chat
        useDevKeysForTest([
          DevKey(
            keyId: keyId,
            threeWords: 'test-dev-words',
            xPub: hex(freshKeys().pub),
            bundle: card,
            fc: 'ab' * 32,
          ),
        ]);
        final before = await userDb.query('dev_sessions');
        await expectLater(
          userNew.encryptTo(dev, 'to someone else'),
          throwsA(isA<LsError>()),
        );
        await expectLater(
          _New(userNew).read(dev, await devBack.seal('user', 'from him')),
          throwsA(isA<LsError>()),
        );
        expect(await userDb.query('dev_sessions'), before);
      },
    );
  });
}
