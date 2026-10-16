// SPDX-License-Identifier: GPL-3.0-or-later
// a backup made by 0.5.0 comes back on this version. the two files were
// written by 0.5.0's own writer and cipher (fixtures/upgrade_050,
// make_050_backups.sh), one without the hidden chats and one made with
// them open. each goes in through the real restore, the engine's own cipher
// included, onto a phone of this version with an account of its own: what
// 0.5.0 had comes back, the database opens at 82, the sessions go on, the
// settings the file carries apply and the ones it predates keep the phone's
// own or their defaults. a wrong passphrase leaves the phone as it was.
// without the engine built for this computer (tool/host_engine.sh) these
// say so and skip
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/secure_store.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'host_engine.dart';
import 'pin_flow_fakes.dart' show MemEngine, NoBio, StillClock;
import 'sqlite_channel.dart';

const _fixtures = 'test/fixtures/upgrade_050';
const _pass = 'test backup 050';
const _me = 'quiet-maple-harbor';
const _alice = 'amber-otter-lake';
const _hush = 'hush-pine-rill';
const _zed = 'zinc-quail-shore';
const _appPin = '1234';
const _hiddenPin = '246810';

final _keys =
    (jsonDecode(File('$_fixtures/keys.json').readAsStringSync()) as Map)
        .cast<String, String>();

class _Engine implements HaloEngine {
  final restored = <(String, String)>[];
  var held = 0;
  @override
  String restoreIdentity(String ed, String x) {
    restored.add((ed, x));
    return _me;
  }

  @override
  Future<String> wipeHold() async {
    held++;
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) => 'ok';
}

// every row of every table, by the columns it had in 0.5.0
Future<Map<String, List<String>>> _rows(
  DatabaseExecutor db, {
  Map<String, Set<String>>? only,
}) async {
  final out = <String, List<String>>{};
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  for (final t in tables) {
    final name = t['name'] as String;
    if (only != null && !only.containsKey(name)) continue;
    final cols = only?[name];
    out[name] = [
      for (final r in await db.rawQuery('SELECT * FROM "$name"'))
        jsonEncode({
          for (final e in r.entries)
            if (cols == null || cols.contains(e.key))
              e.key: e.value is Uint8List
                  ? base64Encode(e.value as Uint8List)
                  : e.value,
        }),
    ]..sort();
  }
  return out;
}

Future<(Map<String, List<String>>, Map<String, Set<String>>)> _old(
  String file,
) async {
  final db = await openDatabase(
    p.absolute('$_fixtures/$file'),
    readOnly: true,
    singleInstance: false,
  );
  try {
    final rows = await _rows(db);
    return (
      rows,
      {
        for (final t in rows.keys)
          t: {
            for (final c in await db.rawQuery("PRAGMA table_info('$t')"))
              c['name'] as String,
          },
      },
    );
  } finally {
    await db.close();
  }
}

String _unmark(String row) {
  final r = jsonDecode(row) as Map<String, Object?>;
  if (r['halo_id'] == _zed) r['verified'] = 0;
  return jsonEncode(r);
}

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

Future<String> _openFrom(SignalSession s, String from, String wire) async {
  final raw = base64Decode(wire);
  final body = Uint8List.fromList(raw.sublist(1));
  final c = SessionCipher(
    s.sessionStore,
    s.preKeyStore,
    s.signedPreKeyStore,
    s.identityStore,
    SignalProtocolAddress(from, 1),
  );
  final plain = raw[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  final engineThere = loadHostEngine();
  SqliteChannel? sql;
  late Directory docs;
  late HaloDb own;
  late LockState lock;
  late _Engine eng;
  late Map<String, List<String>> everydayBefore;
  late Map<String, Set<String>> everydayCols;
  late Map<String, List<String>> hiddenBefore;
  late Map<String, Set<String>> hiddenCols;

  setUpAll(() async {
    sql = SqliteChannel.install();
    if (sql == null) return;
    (everydayBefore, everydayCols) = await _old('halo.db');
    (hiddenBefore, hiddenCols) = await _old('halo_v.db');
    sql!.uninstall();
  });

  // a phone of this version with an account of its own, an app PIN, a
  // connection already set up and relays read up to a point
  setUp(() async {
    sql = SqliteChannel.install();
    docs = Directory.systemTemp.createTempSync('restore_050');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({
      'onboarding_done': 'true',
      'my_handle': 'otherphone',
      'bridge_mode': 'auto',
      'bridge_consent': 'ask',
      'bridge_offer_auto': '0',
      'disguise_on': '1',
    });
    SharedPreferences.setMockInitialValues({});
    eng = _Engine();
    useEngineForTest(eng);
    restoreRunningForTest = false;
    forgetRestoredHidden();
    if (sql == null) return;
    own = HaloDb();
    await own.saveIdentity('other-phone-one', 'aa' * 32, 'bb' * 32);
    useDatabasesForTest(own, Session(own));
    File(p.join(docs.path, 'media', 'own.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    File(p.join(docs.path, 'nostr_last_00aa')).writeAsStringSync('1700000000');
    File(p.join(docs.path, 'nostr_seen_00aa')).writeAsStringSync('x');
    lock = LockState(
      engine: MemEngine(),
      clock: StillClock(),
      bio: NoBio(),
      revealAfter: Duration.zero,
    );
    await lock.load();
    expect(await lock.setupPin(_appPin), isTrue);
  });

  tearDown(() async {
    sql?.uninstall();
    restoreRunningForTest = false;
    forgetRestoredHidden();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  bool skip() {
    if (sql != null && engineThere) return false;
    markTestSkipped(
      sql == null
          ? 'no sqlite on this host'
          : 'no engine for this host: run tool/host_engine.sh',
    );
    return true;
  }

  // a copy, so the file a test reads is never the one committed
  String backup(String name) {
    final to = p.join(docs.path, 'incoming', name);
    File(to).parent.createSync(recursive: true);
    File('$_fixtures/$name').copySync(to);
    return to;
  }

  Future<Map<String, String>> store() => secureStore.readAll();

  test('a look inside says what each file holds', () async {
    if (skip()) return;
    final plain = await inspectBackupFile(backup('everyday.backup'), _pass);
    expect(plain.haloId, _me);
    expect(plain.messages, 19);
    expect(plain.contacts, 6);
    expect(plain.hiddenChats, isNull);
    expect(plain.moved, isFalse);
    final hidden = await inspectBackupFile(backup('hidden.backup'), _pass);
    expect(hidden.haloId, _me);
    expect(hidden.hiddenChats, 1);
  });

  for (final hidden in [false, true]) {
    final name = hidden ? 'hidden.backup' : 'everyday.backup';
    test('$name comes back whole', () async {
      if (skip()) return;
      await restoreBackupFile(backup(name), _pass, own: own, lock: lock);

      // the app closes after a restore and starts again on what landed
      final restart = HaloDb();
      useDatabasesForTest(restart, Session(restart));
      final raw = await restart.open();
      expect(await raw.getVersion(), 82);
      // the engine is handed the identity in the file
      final id = (await restart.loadIdentity())!;
      expect(id['id'], _me);
      expect(eng.restored, [(id['ed_priv'], id['x_priv'])]);
      expect(eng.held, 1);

      // every row 0.5.0 had. a copy without the hidden chats carries
      // nothing of them; one verified under no key loses the mark here
      final after = await _rows(raw, only: everydayCols);
      for (final t in everydayBefore.keys) {
        final scrubbed =
            !hidden &&
            {'hidden_chats', 'vault_meta', 'vault_inbox'}.contains(t);
        expect(
          after[t],
          scrubbed
              ? isEmpty
              : ([for (final r in everydayBefore[t]!) _unmark(r)]..sort()),
          reason: t,
        );
      }
      final alice = (await restart.getContact(_alice))!;
      expect(alice['verified'], 1);
      expect(alice['verified_key'], isNotNull);
      expect(alice['voice_disguise'], isNull);
      expect(await restart.messagesFor(_alice), hasLength(10));
      expect((await restart.rooms()).single['name'], 'Night shift');
      expect((await restart.loadGroups()).length, 2);

      // the files went where they lay, and the phone's own are gone
      expect(File(p.join(docs.path, 'media', 'a-6.jpg')).readAsBytesSync(), [
        0xff,
        0xd8,
        0xff,
        0xd9,
      ]);
      expect(
        File(
          p.join(docs.path, 'wallpapers', 'amber-otter-lake.png'),
        ).existsSync(),
        isTrue,
      );
      expect(File(p.join(docs.path, 'media', 'own.jpg')).existsSync(), isFalse);
      expect(
        File(p.join(docs.path, 'onion.key')).readAsBytesSync(),
        List.generate(64, (i) => i),
      );

      // what the file carries applies
      final s = await store();
      expect(s['halo.db.passphrase'], _keys['everyday']);
      expect(s['onboarding_done'], 'true');
      expect(s['my_handle'], 'quietmaple');
      expect(s['my_handle_name'], 'Quiet');
      expect(s['my_avatar'], '7');
      expect(s['fc_counter'], '3');
      expect(
        jsonDecode(s['peer_fc']!),
        hidden ? {_alice: 2, _hush: 1} : {_alice: 2},
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('supporter_tier'), 'gold');
      expect(prefs.getBool('onboarding.complete'), isTrue);
      expect(prefs.getBool(kSessionsRestoredPref), isTrue);

      // what 0.5.0 never carried keeps the phone's own, or its default
      expect(restoredSettings, isFalse);
      expect(s['bridge_mode'], 'auto');
      expect(s['bridge_consent'], 'ask');
      expect(s['disguise_on'], '1');
      for (final k in ['bridges_on', 'bridge_lines', 'bridge_source']) {
        expect(s.keys, isNot(contains(k)));
      }
      final app = AppState()..onboardingComplete = true;
      expect(await app.firstRunWanted(), isFalse);
      final b = await app.readBridgeSetup(firstStart: false);
      expect(b.choice, BridgeChoice.auto);
      expect(b.offerAuto, isFalse);
      // no catch-up anchor in the file: every address reads its relays whole
      expect(
        docs
            .listSync()
            .map((e) => p.basename(e.path))
            .where(
              (n) => n.startsWith('nostr_last_') || n.startsWith('nostr_seen_'),
            ),
        isEmpty,
      );

      // the hidden chats wait for a PIN of their own, then open with it
      expect(restoredHidden, hidden);
      if (hidden) {
        expect(await sealRestoredHidden(lock, _hiddenPin), isTrue);
        String? key;
        lock.onOutcome = (r, {vaultKey}) async => key = vaultKey;
        expect(await lock.verifyPin(_hiddenPin), PinResult.vault);
        final vault = HaloDb.withKey(HaloContainer.vault, key!);
        final v = await vault.open();
        expect(await v.getVersion(), 82);
        final rows = await _rows(v, only: hiddenCols);
        for (final t in hiddenBefore.keys) {
          expect(rows[t], hiddenBefore[t], reason: 'hidden $t');
        }
        final hush = (await vault.getContact(_hush))!;
        expect(hush['verified'], 1);
        expect(
          [for (final r in await vault.messagesFor(_hush)) r['plaintext']],
          ['only here', 'and back'],
        );
        expect(
          File(p.join(docs.path, 'media_v', 'h-1.jpg')).existsSync(),
          isTrue,
        );
        await vault.close();
      } else {
        expect(File(await HaloContainer.vault.dbPath()).existsSync(), isFalse);
      }
      await restart.close();
    });
  }

  test('the sessions go on after a restore', () async {
    if (skip()) return;
    await restoreBackupFile(
      backup('everyday.backup'),
      _pass,
      own: own,
      lock: lock,
    );
    // the other side: the second identity 0.5.0 kept, opened by this version
    File('$_fixtures/halo_d.db').copySync(p.join(docs.path, 'halo_d.db'));
    await secureStore.write(key: 'halo.d.key', value: _keys['decoy']!);
    final restart = HaloDb();
    useDatabasesForTest(restart, Session(restart));
    final raw = await restart.open();
    final other = HaloDb(HaloContainer.decoy);
    final otherRaw = await other.open();
    final id = (await restart.loadIdentity())!;
    final mine = SignalSession();
    await openSignalStore(
      mine,
      database: raw,
      xPubBytes: _bytes((await peerIdentityHex(otherRaw, _me))!),
      xPrivBytes: _bytes(id['x_priv']!),
    );
    final hersId = (await other.loadIdentity())!;
    final hers = SignalSession();
    await hers.bootstrap(
      database: otherRaw,
      xPubBytes: _bytes((await restart.getContact(_alice))!['xpub'] as String),
      xPrivBytes: _bytes(hersId['x_priv']!),
    );
    // what she sealed on the session the file brought still opens here
    final back = await hers.encryptTo(_me, 'from before the restore');
    expect(await _openFrom(mine, _alice, back), 'from before the restore');
    // a session the file brought is not sealed on again: this side starts
    // afresh from her card, and she opens it
    final card = (await restart.getContact(_alice))!['peer_bundle'] as String;
    final out = await mine.encryptTo(
      _alice,
      'after the restore',
      afresh: () async => preKeyBundleOf(card),
    );
    expect(base64Decode(out)[0], CiphertextMessage.prekeyType);
    expect(await _openFrom(hers, _me, out), 'after the restore');
    await restart.close();
    await other.close();
  });

  for (final name in ['everyday.backup', 'hidden.backup']) {
    test('$name under a wrong passphrase leaves the phone as it was', () async {
      if (skip()) return;
      final path = await own.container.dbPath();
      await own.close();
      final was = File(path).readAsBytesSync();
      final kept = await store();
      await expectLater(
        inspectBackupFile(backup(name), 'not the passphrase'),
        throwsA(
          isA<RestoreError>().having(
            (e) => e.why,
            'why',
            RestoreFailure.wrongPassphrase,
          ),
        ),
      );
      await expectLater(
        restoreBackupFile(
          backup(name),
          'not the passphrase',
          own: own,
          lock: lock,
        ),
        throwsA(
          isA<RestoreError>().having(
            (e) => e.why,
            'why',
            RestoreFailure.wrongPassphrase,
          ),
        ),
      );
      expect(restoreRunning, isFalse);
      expect(File(path).readAsBytesSync(), was);
      expect(await store(), kept);
      expect(eng.restored, isEmpty);
      expect(File(p.join(docs.path, 'media', 'own.jpg')).existsSync(), isTrue);
      expect((await own.loadIdentity())!['id'], 'other-phone-one');
      expect(
        docs.listSync().map((e) => p.basename(e.path)),
        isNot(anyOf(contains('restore_stage'), contains('restore_hidden'))),
      );
    });
  }
}
