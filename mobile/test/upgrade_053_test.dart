// SPDX-License-Identifier: GPL-3.0-or-later
// a phone on 0.5.3 takes this version with its identity and every chat
// kept. its files were made by 0.5.3's own code (fixtures/upgrade_053,
// make_053.sh): the identity reads back as it was and is the key the shim
// works with, the safety numbers are the ones 0.5.3 showed, and every
// session held goes on, through the old layer and through the shim, with
// the messages that were on their way when the phone updated
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_session_ls.dart';
import 'package:kryfo/wire_pad.dart' show unpad;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'signal_ls/shim_lib.dart' show shim, needsShim;
import 'sqlite_channel.dart';

const _fixtures = 'test/fixtures/upgrade_053';
const _me = 'quiet-maple-harbor';
const _alice = 'amber-otter-lake';
const _bob = 'brisk-cedar-moon';
const _dave = 'dusty-heron-vale';
// not a contact yet: whatever name the first contact gets
const _stranger = 'first-contact';

final _keyFile =
    (jsonDecode(File('$_fixtures/keys.json').readAsStringSync()) as Map)
        .cast<String, String>();
final _expected =
    jsonDecode(File('$_fixtures/expected.json').readAsStringSync())
        as Map<String, dynamic>;
const _files = ['halo.db', 'halo_d.db', 'halo_v.db', 'peers.db'];

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

String _hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

({Uint8List pub, Uint8List priv}) _keys(Map<String, dynamic> k) =>
    (pub: _hex(k['x_pub'] as String), priv: _hex(k['x_priv'] as String));

// one side of a chat on whichever layer it runs
abstract class _Side {
  Future<String> seal(String peer, String text);
  Future<String> read(String peer, String wire);
}

class _Old implements _Side {
  _Old(this.s);
  final SignalSession s;

  @override
  Future<String> seal(String peer, String text) => s.encryptTo(peer, text);

  @override
  Future<String> read(String peer, String wire) async {
    final w = base64Decode(wire);
    final body = Uint8List.fromList(w.sublist(1));
    final c = SessionCipher(
      s.sessionStore,
      s.preKeyStore,
      s.signedPreKeyStore,
      s.identityStore,
      SignalProtocolAddress(peer, 1),
    );
    final plain = w[0] == CiphertextMessage.prekeyType
        ? await c.decrypt(PreKeySignalMessage(body))
        : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
    return unpad(utf8.decode(plain));
  }
}

class _Shim implements _Side {
  _Shim(this.s);
  final SignalSessionLs s;

  @override
  Future<String> seal(String peer, String text) => s.encryptTo(peer, text);

  @override
  Future<String> read(String peer, String wire) async {
    final w = base64Decode(wire);
    final plain = await s.open(peer, w[0], Uint8List.fromList(w.sublist(1)));
    return unpad(utf8.decode(plain));
  }
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
    docs = Directory.systemTemp.createTempSync('upgrade_053');
    for (final f in _files) {
      File('$_fixtures/$f').copySync(p.join(docs.path, f));
    }
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': _keyFile['everyday']!,
      'halo.d.key': _keyFile['decoy']!,
    });
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

  bool skip() {
    if (sql != null) return false;
    markTestSkipped('no sqlite on this host');
    return true;
  }

  Future<Database> keep(Future<Database> f) async {
    final d = await f;
    opened.add(d);
    return d;
  }

  Future<Database> everyday() => keep(HaloDb().open());
  Future<Database> decoy() => keep(HaloDb(HaloContainer.decoy).open());
  Future<Database> peers() =>
      keep(openDatabase(p.join(docs.path, 'peers.db'), singleInstance: false));

  Future<SignalSession> oldOn(
    Database db,
    ({Uint8List pub, Uint8List priv}) k, {
    String prefix = '',
  }) async {
    final s = SignalSession();
    await s.bootstrap(
      database: db,
      xPubBytes: k.pub,
      xPrivBytes: k.priv,
      prefix: prefix,
    );
    return s;
  }

  Future<SignalSessionLs> shimOn(
    Database db,
    ({Uint8List pub, Uint8List priv}) k,
  ) async {
    final s = SignalSessionLs(shim!);
    await s.bootstrap(database: db, xPubBytes: k.pub, xPrivBytes: k.priv);
    return s;
  }

  final me = _expected['me'] as Map<String, dynamic>;
  final alice = _expected['alice'] as Map<String, dynamic>;
  final peerKeys = (_expected['peers'] as Map).cast<String, dynamic>();
  final inFlight = (_expected['in_flight'] as Map).cast<String, String>();

  test('the files are the ones 0.5.3 wrote', () async {
    if (skip()) return;
    for (final f in ['halo.db', 'halo_d.db', 'peers.db']) {
      final raw = await openDatabase(
        p.absolute('$_fixtures/$f'),
        readOnly: true,
        singleInstance: false,
      );
      if (f != 'peers.db') {
        expect(await raw.getVersion(), _expected['version'], reason: f);
      }
      final sessions = await raw.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name LIKE '%sessions'",
      );
      expect(sessions, isNotEmpty, reason: f);
      await raw.close();
    }
  });

  test('the identity reads back as 0.5.3 kept it', () async {
    if (skip()) return;
    final db = HaloDb();
    final id = await db.loadIdentity();
    expect(id, isNotNull);
    expect(id!['id'], me['id']);
    expect(id['ed_priv'], me['ed_priv']);
    expect(id['x_priv'], me['x_priv']);
    final d = await HaloDb(HaloContainer.decoy).loadIdentity();
    expect(d!['x_priv'], alice['x_priv']);
    expect(d['ed_priv'], alice['ed_priv']);
    // and the signal store on it is that same key
    final s = await oldOn(await everyday(), _keys(me));
    expect(
      _hexOf(s.identityKeyPair.getPublicKey().serialize()),
      '05${me['x_pub']}',
    );
  });

  test('the identity is the key the shim works with', () async {
    if (skip()) return;
    final ls = shim!;
    for (final k in [me, alice]) {
      final i = ls.identityFromPrivate(_hex(k['x_priv'] as String));
      expect(_hexOf(i.public), '05${k['x_pub']}');
    }
    final s = await shimOn(await everyday(), _keys(me));
    expect(_hexOf(s.identity.public), '05${me['x_pub']}');
  }, skip: needsShim);

  test('the safety numbers are the ones 0.5.3 showed', () async {
    if (skip()) return;
    final db = HaloDb();
    final safety = (_expected['safety'] as Map).cast<String, String>();
    expect(safety.keys, containsAll([_alice, _bob, _dave]));
    for (final e in safety.entries) {
      final c = await db.getContact(e.key);
      expect(c, isNotNull, reason: e.key);
      final key = c!['xpub'] as String;
      expect(haloSafetyNumber(me['x_pub'] as String, key), e.value);
    }
    // the key behind each number is the one its session runs on
    final s = await oldOn(await everyday(), _keys(me));
    for (final peer in [_alice, _bob]) {
      final rec = await s.sessionStore.loadSession(
        SignalProtocolAddress(peer, 1),
      );
      final remote = rec.sessionState.getRemoteIdentityKey()!.serialize();
      final c = await db.getContact(peer);
      expect(_hexOf(remote), '05${c!['xpub']}', reason: peer);
    }
  });

  // the chats as they stood, carried on by [mine] and [hers] for this
  // phone's two identities, the far sides still on 0.5.3's library
  Future<void> goesOn(_Side mine, _Side hers, {required bool shimOn}) async {
    final pdb = await peers();
    final bob = _Old(await oldOn(pdb, _keys(peerKeys['bob_']), prefix: 'bob_'));
    final dave = _Old(
      await oldOn(pdb, _keys(peerKeys['dave_']), prefix: 'dave_'),
    );
    // alice and me, both ways
    expect(await hers.read(_me, await mine.seal(_alice, 'after')), 'after');
    expect(
      await mine.read(_alice, await hers.seal(_me, 'and back')),
      'and back',
    );
    // what was on the relay when the phone updated
    expect(
      await mine.read(_bob, inFlight['bob_to_me']!),
      'sent before the update',
    );
    expect(
      await bob.read(_me, inFlight['me_to_bob']!),
      'also before the update',
    );
    expect(
      await bob.read(_me, await mine.seal(_bob, 'still here')),
      'still here',
    );
    expect(await mine.read(_bob, await bob.seal(_me, 'good')), 'good');
    // dave never answered: the opener sent before, and the next one, both
    // read on his side, and his answer here
    expect(
      await dave.read(_me, inFlight['me_to_dave']!),
      'are you there, dave',
    );
    final next = await mine.seal(_dave, 'hello again');
    expect(base64Decode(next)[0], CiphertextMessage.prekeyType);
    expect(await dave.read(_me, next), 'hello again');
    expect(await mine.read(_dave, await dave.seal(_me, 'here')), 'here');
    expect(await mine.read(_dave, await dave.seal(_me, 'now')), 'now');
    // a classic opener from someone new: 0.5.3's library takes it, the
    // shim builds no session from it
    final opener = inFlight['stranger_to_me']!;
    if (shimOn) {
      await expectLater(
        mine.read(_stranger, opener),
        throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.classic)),
      );
    } else {
      expect(
        await mine.read(_stranger, opener),
        'hello, we met at the station',
      );
    }
  }

  test('every session goes on through the old layer', () async {
    if (skip()) return;
    final mine = await oldOn(await everyday(), _keys(me));
    final hers = await oldOn(await decoy(), _keys(alice));
    await goesOn(_Old(mine), _Old(hers), shimOn: false);
  });

  test('every session goes on through the shim', () async {
    if (skip()) return;
    final db = await everyday();
    final mine = await shimOn(db, _keys(me));
    final hers = await shimOn(await decoy(), _keys(alice));
    // the sessions held are the classic ones 0.5.3 made, as they were
    for (final peer in [_alice, _bob, _dave]) {
      final i = await mine.sessionInfo(peer);
      expect(i, isNotNull, reason: peer);
      expect(i!.version, 3, reason: peer);
    }
    final prekeys = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM prekeys'),
    );
    await goesOn(_Shim(mine), _Shim(hers), shimOn: true);
    // the refused opener left nothing: no session, no prekey spent
    expect(await mine.hasSession(_stranger), isFalse);
    expect(
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM prekeys')),
      prekeys,
    );
    // and nothing moved on to the pq ratchet by itself
    for (final peer in [_alice, _bob, _dave]) {
      expect((await mine.sessionInfo(peer))!.version, 3, reason: peer);
    }
  }, skip: needsShim);
}
