// SPDX-License-Identifier: GPL-3.0-or-later
// a phone on 0.5.3 takes this version with its identity and every chat
// kept. its files were made by 0.5.3's own code (fixtures/upgrade_053,
// make_053.sh): the identity reads back as it was and is the key the shim
// works with, the safety numbers are the ones 0.5.3 showed, and every
// session held goes on through the shim, with the messages that were on
// their way when the phone updated. here the far sides run this version
// too; tool/peer053 runs them on 0.5.3's own library
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/identities.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show unpad;
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
const _identTablesForTest = [
  'prekeys',
  'signed_prekeys',
  'sessions',
  'peer_identities',
  'kyber_prekeys',
];

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

String _hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

({Uint8List pub, Uint8List priv}) _keys(Map<String, dynamic> k) =>
    (pub: _hex(k['x_pub'] as String), priv: _hex(k['x_priv'] as String));

// one side of a chat
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

  Future<SignalSession> shimOn(
    Database db,
    ({Uint8List pub, Uint8List priv}) k, {
    String prefix = '',
  }) async {
    final s = SignalSession(shim);
    await s.bootstrap(
      database: db,
      xPubBytes: k.pub,
      xPrivBytes: k.priv,
      prefix: prefix,
    );
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
    final s = await shimOn(await everyday(), _keys(me));
    expect(_hexOf(s.identity.public), '05${me['x_pub']}');
  }, skip: needsShim);

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
    final s = await shimOn(await everyday(), _keys(me));
    for (final peer in [_alice, _bob]) {
      final remote = (await s.sessionIdentity(peer))!;
      final c = await db.getContact(peer);
      expect(_hexOf(remote), '05${c!['xpub']}', reason: peer);
    }
  }, skip: needsShim);

  // the chats as they stood, carried on by [mine] and [hers] for this
  // phone's two identities, the far sides updated too
  Future<void> goesOn(_Side mine, _Side hers) async {
    final pdb = await peers();
    // the far phones' stores, kept here in one file: what 0.6 adds to each
    for (final prefix in ['bob_', 'dave_']) {
      await signalStoreTables(pdb, prefix: prefix);
    }
    final bob = _Shim(
      await shimOn(pdb, _keys(peerKeys['bob_']), prefix: 'bob_'),
    );
    final dave = _Shim(
      await shimOn(pdb, _keys(peerKeys['dave_']), prefix: 'dave_'),
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
    // dave never answered: his phone on this version holds no session the
    // classic opener sent before could open on, nor the next one, which
    // is the same opener again. both refused, nothing kept for him (on
    // 0.5.3 he reads both: tool/peer053)
    final davesPrekeys = Sqflite.firstIntValue(
      await pdb.rawQuery('SELECT COUNT(*) FROM dave_prekeys'),
    );
    await expectLater(
      dave.read(_me, inFlight['me_to_dave']!),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.classic)),
    );
    final next = await mine.seal(_dave, 'hello again');
    expect(base64Decode(next)[0], kLsPreKey);
    await expectLater(
      dave.read(_me, next),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.classic)),
    );
    expect(await dave.s.hasSession(_me), isFalse);
    expect(
      Sqflite.firstIntValue(
        await pdb.rawQuery('SELECT COUNT(*) FROM dave_prekeys'),
      ),
      davesPrekeys,
    );
    // a classic opener from someone new: the shim builds no session from it
    final opener = inFlight['stranger_to_me']!;
    await expectLater(
      mine.read(_stranger, opener),
      throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.classic)),
    );
  }

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
    await goesOn(_Shim(mine), _Shim(hers));
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

  // identity v4 (version 92): the main identity is row 0, from the key and
  // the registration id 0.5.3 kept; every contact is on it, at the
  // addresses of 0.5 (conv 3), and every signal row is its
  group('identity v4', () {
    Future<Map<String, int>> counts(Database db) async => {
      for (final t in const [
        'prekeys',
        'signed_prekeys',
        'sessions',
        'peer_identities',
      ])
        t: Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $t'))!,
    };

    test('row 0 is the key 0.5.3 kept, each container its own', () async {
      if (skip()) return;
      for (final (f, who) in [('halo.db', me), ('halo_d.db', alice)]) {
        final raw = await openDatabase(
          p.absolute('$_fixtures/$f'),
          readOnly: true,
          singleInstance: false,
        );
        final reg = await raw.query(
          'signal_meta',
          where: 'k = ?',
          whereArgs: ['regId'],
        );
        await raw.close();
        final db = await (f == 'halo.db' ? everyday() : decoy());
        expect(await db.getVersion(), 93, reason: f);
        final rows = await identityRows(db);
        expect(rows.map((r) => r.id), [kMainIdent], reason: f);
        final row = rows.single;
        expect(_hexOf(row.xPriv), who['x_priv'], reason: f);
        expect(row.kind, kIdentFace, reason: f);
        expect(row.retiredAt, isNull, reason: f);
        if (reg.isNotEmpty) {
          expect(row.regId, int.parse(reg.single['v'] as String), reason: f);
        }
      }
    });

    test(
      'every contact is on row 0, its key claimed, its pair at conv 3',
      () async {
        if (skip()) return;
        final db = await everyday();
        final contacts = await db.query('contacts');
        expect(contacts, isNotEmpty);
        final keyed = <String>{};
        for (final c in contacts) {
          final id = c['halo_id'] as String;
          expect(c['ident'], kMainIdent, reason: id);
          final want = identityKeyHex(c['xpub'] as String?);
          if (want == null) {
            expect(c['ikey'], isNull, reason: id);
            continue;
          }
          if (keyed.add(want)) expect(c['ikey'], want, reason: id);
          expect(await contactOfKey(db, c['xpub'] as String), isNotNull);
        }
        final pairs = await db.query('pairs');
        expect(pairs.map((r) => r['peer']).toSet(), keyed);
        for (final r in pairs) {
          expect(r['ident'], kMainIdent);
          expect(r['conv'], kConvClassic);
          expect(r['seed'], isNull);
          expect(r['their_device'], 1);
          expect(r['my_device'], 1);
        }
        for (final peer in [_alice, _bob, _dave]) {
          final c = await db.query(
            'contacts',
            where: 'halo_id = ?',
            whereArgs: [peer],
          );
          final pair = await pairOf(
            db,
            kMainIdent,
            identityKeyHex(c.single['xpub'] as String)!,
          );
          expect(pair.conv, kConvClassic, reason: peer);
        }
      },
    );

    test(
      'every signal row is row 0\'s, none lost, the invite keys kept',
      () async {
        if (skip()) return;
        final raw = await openDatabase(
          p.absolute('$_fixtures/halo.db'),
          readOnly: true,
          singleInstance: false,
        );
        final before = await counts(raw);
        final spk = (await raw.query('signed_prekeys', where: 'id = 1')).single;
        final sessions = {
          for (final r in await raw.query('sessions'))
            '${r['address']}/${r['device_id']}': base64Encode(
              r['record'] as List<int>,
            ),
        };
        await raw.close();
        final db = await everyday();
        expect(await counts(db), before);
        for (final t in [
          ..._identTablesForTest,
          'opener_reads',
          'kyber_used',
        ]) {
          expect(await db.query(t, where: 'ident != 0'), isEmpty, reason: t);
        }
        expect({
          for (final r in await db.query('sessions'))
            '${r['address']}/${r['device_id']}': base64Encode(
              r['record'] as List<int>,
            ),
        }, sessions);
        final kept = (await db.query('signed_prekeys', where: 'id = 1')).single;
        expect(kept['record'], spk['record']);
        expect(kept['use'], 'invite');
        expect(kept['invite_id'], '');
        // the first start on it makes the session prekeys, and keeps the
        // invite's
        final mine = await shimOn(db, _keys(me));
        final made = await db.query(
          'signed_prekeys',
          where: 'use = ?',
          whereArgs: ['session'],
        );
        expect(made, hasLength(1));
        expect(made.single['ident'], kMainIdent);
        expect(
          await db.query('kyber_prekeys', where: "use = 'session'"),
          hasLength(1),
        );
        expect(
          (await db.query('signed_prekeys', where: 'id = 1')).single['record'],
          spk['record'],
        );
        expect(mine.registrationId, (await identityRow(db, 0))!.regId);
        // and the chats go on, both ways
        await goesOn(
          _Shim(mine),
          _Shim(await shimOn(await decoy(), _keys(alice))),
        );
      },
      skip: needsShim,
    );
  });
}
