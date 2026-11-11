// SPDX-License-Identifier: GPL-3.0-or-later
// two databases from a phone on the 0.5.3 release (fixtures/upgrade_053/
// phone): two test identities made there for this, each holding a chat with
// the other, read out of their own backups and stored without the cipher.
// this version reads both identities as they were, shows the safety number
// the phone showed, and carries the chat on in both directions with both
// phones updated. one phone still on 0.5.3's own library against one on
// this version is tool/peer053
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show unpad;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'signal_ls/shim_lib.dart' show shim, needsShim;
import 'sqlite_channel.dart';

const _fixtures = 'test/fixtures/upgrade_053/phone';

final _expected =
    jsonDecode(File('$_fixtures/expected.json').readAsStringSync())
        as Map<String, dynamic>;
final _a = _expected['a'] as String;
final _b = _expected['b'] as String;

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

String _hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

// one phone of the two
abstract class _Side {
  Future<String> seal(String peer, String text);
  Future<String> read(String peer, String wire);
}

class _Shim implements _Side {
  _Shim(this.s);
  final SignalSession s;

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

  setUp(() async {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('upgrade_053_phone');
    // phone a as the everyday file, phone b as the decoy: two files with
    // their own keys side by side, the host's sqlite asks for no cipher
    File('$_fixtures/a.db').copySync(p.join(docs.path, 'halo.db'));
    File('$_fixtures/b.db').copySync(p.join(docs.path, 'halo_d.db'));
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'not asked for',
      'halo.d.key': 'not asked for',
    });
    SharedPreferences.setMockInitialValues({});
    useDevKeysForTest(null);
    // as the app's start finds them: the names before the numbers move
    await moveToNumberedNames(docs.path);
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

  HaloDb dbOf(String who) => who == _a ? HaloDb() : HaloDb(HaloContainer.decoy);

  // [who]'s keys: the private half from its own file, the public half as
  // the other phone holds it
  Future<({Uint8List pub, Uint8List priv})> keysOf(String who) async {
    final id = await dbOf(who).loadIdentity();
    final other = await dbOf(who == _a ? _b : _a).getContact(who);
    return (pub: _hex(other!['xpub'] as String), priv: _hex(id!['x_priv']!));
  }

  Future<Database> raw(String who) async {
    final d = await dbOf(who).open();
    opened.add(d);
    return d;
  }

  Future<_Side> onShim(String who) async {
    final k = await keysOf(who);
    final s = SignalSession(shim);
    await s.bootstrap(
      database: await raw(who),
      xPubBytes: k.pub,
      xPrivBytes: k.priv,
    );
    // the chat held is the classic session 0.5.3 made
    expect((await s.sessionInfo(who == _a ? _b : _a))!.version, 3);
    return _Shim(s);
  }

  test('the files are the ones the phone wrote', () async {
    if (skip()) return;
    for (final f in ['a.db', 'b.db']) {
      final d = await openDatabase(
        p.absolute('$_fixtures/$f'),
        readOnly: true,
        singleInstance: false,
      );
      expect(await d.getVersion(), 85, reason: f);
      expect(
        await d.query('sessions', columns: ['address']),
        hasLength(1),
        reason: f,
      );
      await d.close();
    }
    final msgs = await (await raw(
      _a,
    )).query('messages', columns: ['direction', 'plaintext'], orderBy: 'id');
    expect([
      for (final r in msgs) [r['direction'], r['plaintext']],
    ], _expected['a_messages']);
  });

  test(
    'each identity reads back and is the key the other phone holds',
    () async {
      if (skip()) return;
      for (final (me, them) in [(_a, _b), (_b, _a)]) {
        final id = await dbOf(me).loadIdentity();
        expect(id!['id'], me);
        expect(id['x_priv'], hasLength(64));
        expect(id['ed_priv'], isNotEmpty);
        final c = await dbOf(them).getContact(me);
        expect(c!['verified'], 1, reason: '$them verified $me');
        expect(c['verified_key'], c['xpub']);
        // the store's identity on that private key is the contact's key
        final s = await onShim(me) as _Shim;
        expect(_hexOf(s.s.identity.public), '05${c['xpub']}');
      }
    },
    skip: needsShim,
  );

  test('the shim derives the same identity keys', () async {
    if (skip()) return;
    for (final (me, them) in [(_a, _b), (_b, _a)]) {
      final id = await dbOf(me).loadIdentity();
      final c = await dbOf(them).getContact(me);
      final i = shim!.identityFromPrivate(_hex(id!['x_priv']!));
      expect(_hexOf(i.public), '05${c!['xpub']}');
    }
  }, skip: needsShim);

  test('both phones show the safety number they showed on 0.5.3', () async {
    if (skip()) return;
    final a = await keysOf(_a);
    final b = await keysOf(_b);
    expect(haloSafetyNumber(_hexOf(a.pub), _hexOf(b.pub)), _expected['safety']);
    expect(haloSafetyNumber(_hexOf(b.pub), _hexOf(a.pub)), _expected['safety']);
    // and the key each session runs on is the one the number is made of
    for (final (me, them, k) in [(_a, _b, b), (_b, _a, a)]) {
      final s = await onShim(me) as _Shim;
      final info = (await s.s.sessionInfo(them))!;
      expect(_hexOf(info.remoteIdentity!), '05${_hexOf(k.pub)}', reason: me);
      expect(info.version, 3);
    }
  }, skip: needsShim);

  Future<void> chat(_Side a, _Side b) async {
    for (var i = 0; i < 3; i++) {
      expect(await b.read(_a, await a.seal(_b, 'a $i')), 'a $i');
      expect(await a.read(_b, await b.seal(_a, 'b $i')), 'b $i');
    }
    // two in a row each way, then the answers
    final a1 = await a.seal(_b, 'a again');
    final a2 = await a.seal(_b, 'and again');
    expect(await b.read(_a, a2), 'and again');
    expect(await b.read(_a, a1), 'a again');
    expect(await a.read(_b, await b.seal(_a, 'got both')), 'got both');
  }

  test('the chat goes on with both phones on the shim', () async {
    if (skip()) return;
    await chat(await onShim(_a), await onShim(_b));
  }, skip: needsShim);
}
