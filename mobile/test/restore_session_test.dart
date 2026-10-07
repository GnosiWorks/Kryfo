// SPDX-License-Identifier: GPL-3.0-or-later
// a restore lands on the session it began in. the other session may be
// unlocked while the file is still being read, and then the other side's
// hidden chats PIN and database are never touched. the database being
// replaced takes nothing more once the restore lands, so nothing is
// acknowledged into a file gone at the restart. the files are real ones in
// a scratch folder, the cipher a stand-in
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/backup_stream.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart' show kSessionsRestoredPref;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart';

// [first] runs at the first record opened: the moment the file is being
// read and nothing has landed yet
class _Cipher implements ChunkCipher {
  _Cipher([this.first]);
  void Function()? first;

  @override
  Uint8List seal(int index, int type, Uint8List plain) =>
      Uint8List.fromList([index & 255, type, ...plain.map((b) => b ^ 7)]);
  @override
  Uint8List? open(int index, int type, Uint8List sealed) {
    final f = first;
    first = null;
    f?.call();
    if (sealed.length < 2 || sealed[0] != (index & 255) || sealed[1] != type) {
      return null;
    }
    return Uint8List.fromList(sealed.sublist(2).map((b) => b ^ 7).toList());
  }
}

// a container's database as the restore sees it: what was done to it, and
// what its file held at the moment it was retired
class _Db implements HaloDb {
  _Db(this.container, this.file);
  @override
  final HaloContainer container;
  final String file;
  final log = <String>[];

  @override
  Future<void> close() async => log.add('close');
  @override
  Future<void> retire() async =>
      log.add('retire over ${File(file).readAsStringSync()}');
  // a vault over it holds nothing it has to name
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: const <String, bool>{}, groups: const <String>{});
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

class _Engine implements HaloEngine {
  final restored = <String>[];
  // the last step of a landing fails
  var fail = false;
  @override
  String restoreIdentity(String ed, String x) {
    if (fail) throw StateError('no identity');
    restored.add(ed);
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('the engine was asked for ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String docs;
  late _Db live;
  late _Db decoy;
  late _Engine engine;

  String at(String name) => p.join(docs, name);
  void put(String name, String body) => File(at(name))
    ..createSync(recursive: true)
    ..writeAsStringSync(body);
  String? read(String name) =>
      File(at(name)).existsSync() ? File(at(name)).readAsStringSync() : null;

  setUp(() {
    root = Directory.systemTemp.createTempSync('restore_session');
    docs = p.join(root.path, 'docs');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'everyday key',
      'halo.d.key': 'decoy key',
    });
    forgetLeftoverSweep();
    forgetRestoredHidden();
    // both accounts, each with hidden chats of its own
    put('halo.db', 'everyday');
    put('halo_d.db', 'decoy');
    put('halo_v.db', 'everyday hidden');
    put('halo_dv.db', 'decoy hidden');
    live = _Db(HaloContainer.everyday, at('halo.db'));
    decoy = _Db(HaloContainer.decoy, at('halo_d.db'));
    engine = _Engine();
    useEngineForTest(engine);
  });

  tearDown(() {
    restoreCipherForTest = null;
    forgetRestoredHidden();
    root.deleteSync(recursive: true);
  });

  // a v2 file holding a database, an onion key with [onion], and nothing
  // hidden
  Future<String> file({bool onion = false}) async {
    final src = p.join(root.path, 'src');
    File(p.join(src, 'halo.db'))
      ..createSync(recursive: true)
      ..writeAsStringSync('restored');
    File(p.join(src, 'onion.key')).writeAsStringSync('restored key');
    final out = p.join(root.path, 'x.kryfo');
    await writeBackup(
      outPath: out,
      salt: Uint8List(16),
      cipher: _Cipher(),
      manifest: {
        'v': kBackupVersion,
        'files': [
          {'name': 'halo.db', 'size': 8},
          if (onion) {'name': 'onion.key', 'size': 12},
        ],
        'dbPassphrase': "x'${'4d' * 32}'",
        'edPriv': 'ed',
        'xPriv': 'x',
      },
      root: '',
      source: (n) => p.join(src, n),
    );
    return out;
  }

  // every pin of both accounts, the hidden chats' two included
  Future<Lock> pins({required bool inDecoy}) => makeLock({
    PinSlot.app: (appPin, PinKind.everyday),
    PinSlot.decoy: (decoyPin, PinKind.decoy),
    PinSlot.vault: (vaultPin, PinKind.vault),
    PinSlot.decoyVault: (decoyVaultPin, PinKind.vault),
  }, inDecoy: inDecoy);

  test('a restore begun in the decoy and finished after the everyday PIN '
      'leaves the everyday account alone', () async {
    final lock = await pins(inDecoy: true);
    useDatabasesForTest(live, Session(decoy));
    restoreCipherForTest = () => _Cipher(() {
      // the lock went up and the everyday PIN went in
      useDatabasesForTest(live, Session(live));
      lock.state.inDecoy = false;
    });
    await restoreBackupFile(await file(), 'pass', lock: lock.state);

    // the everyday hidden chats still open with their PIN
    expect(lock.entries.keys, contains('${PinSlot.vault}'));
    expect((lock.entries['${PinSlot.vault}'] as Map)['p'], vaultPin);
    expect(lock.entries.keys, isNot(contains('${PinSlot.decoyVault}')));
    expect(read('halo_v.db'), 'everyday hidden');
    expect(read('halo_dv.db'), isNull);
    // the decoy's database closed, the everyday one never
    expect(decoy.log, ['close']);
    expect(live.log, isEmpty);
    expect(read('halo.db'), 'everyday');
    expect(read('halo_d.db'), 'restored');
    expect(engine.restored, isEmpty);
    // the everyday sessions are not the ones that came back
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(kSessionsRestoredPref), isFalse);
  });

  test('a restore begun in the everyday app and finished in the decoy '
      'leaves the decoy alone', () async {
    final lock = await pins(inDecoy: false);
    useDatabasesForTest(live, Session(live));
    restoreCipherForTest = () => _Cipher(() {
      useDatabasesForTest(live, Session(decoy));
      lock.state.inDecoy = true;
    });
    await restoreBackupFile(await file(), 'pass', lock: lock.state);

    expect((lock.entries['${PinSlot.decoyVault}'] as Map)['p'], decoyVaultPin);
    expect(lock.entries.keys, isNot(contains('${PinSlot.vault}')));
    expect(read('halo_dv.db'), 'decoy hidden');
    expect(read('halo_v.db'), isNull);
    expect(decoy.log, isEmpty);
    expect(read('halo_d.db'), 'decoy');
    expect(read('halo.db'), 'restored');
    expect(engine.restored, ['ed']);
    // the next start marks the sessions the file brought back
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kSessionsRestoredPref), isTrue);
  });

  test('the everyday database takes nothing more once a restore lands on '
      'it', () async {
    final lock = await pins(inDecoy: false);
    useDatabasesForTest(live, Session(live));
    restoreCipherForTest = _Cipher.new;
    // a log of the old database, left by a write in flight
    put('halo.db-journal', 'old log');
    await restoreBackupFile(await file(), 'pass', lock: lock.state);
    // retired while its own file was still there, before the new one came
    expect(live.log, ['retire over everyday']);
    expect(read('halo.db'), 'restored');
    expect(read('halo.db-journal'), isNull);
    expect(Directory(at('restore_stage')).existsSync(), isFalse);
  });

  test('an everyday restore with hidden chats open retires them before '
      'their file goes', () async {
    final lock = await pins(inDecoy: false);
    final vault = _Db(HaloContainer.vault, at('halo_v.db'));
    useDatabasesForTest(live, await Session.withVault(live, vault));
    restoreCipherForTest = _Cipher.new;
    await restoreBackupFile(await file(), 'pass', lock: lock.state);
    // an arrival for a hidden chat has nowhere to be kept and acknowledged
    expect(vault.log, ['retire over everyday hidden']);
    expect(read('halo_v.db'), isNull);
    expect(live.log, ['retire over everyday']);
    expect(lock.entries.keys, isNot(contains('${PinSlot.vault}')));
  });

  test('a restore begun in the decoy leaves the everyday hidden chats open '
      'when they are what is open by then', () async {
    final lock = await pins(inDecoy: true);
    final vault = _Db(HaloContainer.vault, at('halo_v.db'));
    final everyday = await Session.withVault(live, vault);
    useDatabasesForTest(live, Session(decoy));
    restoreCipherForTest = () => _Cipher(() {
      // the everyday PIN went in, then the hidden chats one
      useDatabasesForTest(live, everyday);
      lock.state.inDecoy = false;
    });
    await restoreBackupFile(await file(), 'pass', lock: lock.state);
    expect(vault.log, isEmpty);
    expect(read('halo_v.db'), 'everyday hidden');
  });

  test('a landing that fails once the database is retired says the app has '
      'to close', () async {
    final lock = await pins(inDecoy: false);
    useDatabasesForTest(live, Session(live));
    restoreCipherForTest = _Cipher.new;
    // a folder where the onion key goes: the file cannot land on it
    put('onion.key/x', 'held');
    await expectLater(
      restoreBackupFile(await file(onion: true), 'pass', lock: lock.state),
      throwsA(
        isA<RestoreError>().having(
          (e) => e.why,
          'why',
          RestoreFailure.cutShort,
        ),
      ),
    );
    expect(live.log, ['retire over everyday']);
    expect(Directory(at('restore_stage')).existsSync(), isFalse);
  });

  test('an old text file whose landing fails says the app has to '
      'close', () async {
    final lock = await pins(inDecoy: false);
    useDatabasesForTest(live, Session(live));
    engine.fail = true;
    await expectLater(
      landV1Payload(
        {
          'v': 1,
          'db': base64Encode(utf8.encode('old file')),
          'dbPassphrase': "x'${'4e' * 32}'",
          'edPriv': 'ed',
          'xPriv': 'x',
        },
        own: live,
        lock: lock.state,
      ),
      throwsA(
        isA<RestoreError>().having(
          (e) => e.why,
          'why',
          RestoreFailure.cutShort,
        ),
      ),
    );
    expect(live.log, ['retire over everyday']);
  });

  test('a restore that fails before landing leaves the database open and '
      'the phone as it was', () async {
    final lock = await pins(inDecoy: false);
    useDatabasesForTest(live, Session(live));
    final path = await file();
    // a record changed on the way: the file is not whole
    final bytes = File(path).readAsBytesSync();
    bytes[bytes.length - 3] ^= 1;
    File(path).writeAsBytesSync(bytes);
    restoreCipherForTest = _Cipher.new;
    await expectLater(
      restoreBackupFile(path, 'pass', lock: lock.state),
      throwsA(isA<RestoreError>()),
    );
    expect(live.log, isEmpty);
    expect(read('halo.db'), 'everyday');
    expect(lock.entries.keys, contains('${PinSlot.vault}'));
    expect(Directory(at('restore_stage')).existsSync(), isFalse);
  });

  test('an old text file begun in the decoy lands in the decoy whatever '
      'is open by then', () async {
    final lock = await pins(inDecoy: false);
    // the session switched while the file was being opened
    useDatabasesForTest(live, Session(live));
    String b64(String s) => base64Encode(utf8.encode(s));
    await landV1Payload(
      {
        'v': 1,
        'db': b64('old file'),
        'dbPassphrase': "x'${'4e' * 32}'",
        'edPriv': 'ed',
        'xPriv': 'x',
      },
      own: decoy,
      lock: lock.state,
    );
    expect(read('halo.db'), 'everyday');
    expect(read('halo_d.db'), 'old file');
    expect(read('halo_v.db'), 'everyday hidden');
    expect(lock.entries.keys, contains('${PinSlot.vault}'));
    expect(live.log, isEmpty);
    expect(decoy.log, ['close']);
    expect(engine.restored, isEmpty);
  });

  test('an old text file in the everyday app retires the database before '
      'writing over it, and clears only the everyday hidden chats', () async {
    final lock = await pins(inDecoy: true);
    useDatabasesForTest(live, Session(decoy));
    await landV1Payload(
      {
        'v': 1,
        'db': base64Encode(utf8.encode('old file')),
        'dbPassphrase': "x'${'4e' * 32}'",
        'edPriv': 'ed',
        'xPriv': 'x',
      },
      own: live,
      lock: lock.state,
    );
    expect(live.log, ['retire over everyday']);
    expect(read('halo.db'), 'old file');
    expect(lock.entries.keys, isNot(contains('${PinSlot.vault}')));
    expect((lock.entries['${PinSlot.decoyVault}'] as Map)['p'], decoyVaultPin);
    expect(read('halo_dv.db'), 'decoy hidden');
  });

  test('hidden chats a restore brought are sealed into its own vault, '
      'whichever session is open', () async {
    final lock = await pins(inDecoy: false);
    restoredHiddenForTest(vaultKey, into: HaloContainer.decoyVault);
    expect(await sealRestoredHidden(lock.state, '864200'), isTrue);
    final e = lock.entries['${PinSlot.decoyVault}'] as Map;
    expect(e['p'], '864200');
    expect(e['c'], HaloContainer.decoyVault.id);
    expect((lock.entries['${PinSlot.vault}'] as Map)['p'], vaultPin);
  });

  test('a retired database never opens again', () async {
    final d = HaloDb();
    await d.retire();
    await expectLater(d.open(), throwsStateError);
  });
}
