// SPDX-License-Identifier: GPL-3.0-or-later
// a restore puts back what a backup is made of and nothing else: the
// database, the onion key, the files under media/ and wallpapers/, and
// under vault/ the hidden chats' own. any other name in a file stays out of
// the phone's folders, a decoy restore included, and of the prefs only the
// ones a backup carries are taken. the files are real ones in a scratch
// folder, the cipher a stand-in
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/backup_stream.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart' show kSessionsRestoredPref;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _Cipher implements ChunkCipher {
  @override
  Uint8List seal(int index, int type, Uint8List plain) =>
      Uint8List.fromList([index & 255, type, ...plain.map((b) => b ^ 7)]);
  @override
  Uint8List? open(int index, int type, Uint8List sealed) {
    if (sealed.length < 2 || sealed[0] != (index & 255) || sealed[1] != type) {
      return null;
    }
    return Uint8List.fromList(sealed.sublist(2).map((b) => b ^ 7).toList());
  }
}

class _Decoy implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.decoy;
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

class _Everyday implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<void> retire() async {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

class _Engine implements HaloEngine {
  final restored = <String>[];
  @override
  String restoreIdentity(String ed, String x) {
    restored.add(ed);
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('the engine was asked for ${i.memberName}');
}

// any engine call fails the test: the decoy's account is only its own files
class _NoEngine implements HaloEngine {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('the engine was asked for ${i.memberName}');
}

// what a file might carry beside what a backup is made of
const _kept = ['halo.db', 'onion.key', 'media/a.jpg', 'wallpapers/w/b.jpg'];
const _stray = [
  'halo_d.db',
  'media_d/x.jpg',
  'tor/state',
  'nostr_seen_0011223344556677',
  'loose',
  'vault/other.db',
  'vault/tor/state',
  'media',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('restore_names');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => p.join(root.path, 'docs'),
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => root.deleteSync(recursive: true));

  // a backup file holding [names], each file its own name as bytes
  Future<String> file(List<String> names) async {
    final src = p.join(root.path, 'src');
    final entries = <Map<String, dynamic>>[];
    for (final n in names) {
      final f = File(p.join(src, n.replaceAll('/', '__')))
        ..createSync(recursive: true)
        ..writeAsStringSync(n);
      entries.add({'name': n, 'size': f.lengthSync()});
    }
    final out = p.join(root.path, 'x.kryfo');
    await writeBackup(
      outPath: out,
      salt: Uint8List(16),
      cipher: _Cipher(),
      manifest: {
        'v': kBackupVersion,
        'files': entries,
        'dbPassphrase': "x'${'4d' * 32}'",
      },
      root: '',
      source: (n) => p.join(src, n.replaceAll('/', '__')),
    );
    return out;
  }

  List<String> under(String dir) => [
    for (final e in Directory(dir).listSync(recursive: true))
      if (e is File) p.relative(e.path, from: dir),
  ]..sort();

  test('the names a restore puts back', () {
    for (final n in [..._kept, 'vault/halo_v.db', 'vault/media/c.jpg']) {
      expect(restorableName(n), isTrue, reason: n);
    }
    for (final n in [..._stray, 'vault/onion.key', '../x', 'media/../x']) {
      expect(restorableName(n), isFalse, reason: n);
    }
  });

  test('a restore lands the known names and nothing else', () async {
    final out = await file([..._kept, ..._stray]);
    final land = p.join(root.path, 'land');
    Directory(land).createSync();
    await unpackBackup(out, _Cipher(), root: land);
    expect(under(land), [..._kept]..sort());
  });

  test('a decoy restore lands the known names on its own and skips the '
      'rest', () async {
    final docs = p.join(root.path, 'docs');
    final from = p.join(root.path, 'restore_d');
    Directory(docs).createSync(recursive: true);
    Directory(from).createSync();
    final out = await file([..._kept, ..._stray]);
    final manifest = await unpackBackup(out, _Cipher(), root: from);
    final decoy = _Decoy();
    useDatabasesForTest(decoy, Session(decoy));
    await landQuietRestore(from, docs, manifest);
    expect(under(docs), [
      'halo_d.db',
      'media_d/a.jpg',
      'onion_d.key',
      'wallpapers_d/w/b.jpg',
    ]);
  });

  test('an old text file restored in a decoy lands in the decoy and leaves '
      'the everyday account as it was', () async {
    final docs = p.join(root.path, 'docs');
    File(p.join(docs, 'halo.db'))
      ..createSync(recursive: true)
      ..writeAsStringSync('everyday');
    File(p.join(docs, 'onion.key')).writeAsStringSync('everyday onion');
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'everyday key',
      'onboarding_done': 'true',
      'my_handle': 'mine',
    });
    final decoy = _Decoy();
    useDatabasesForTest(decoy, Session(decoy));
    useEngineForTest(_NoEngine());
    String b64(String s) => base64Encode(utf8.encode(s));
    await landV1Payload({
      'v': 1,
      'db': b64('old file'),
      'dbPassphrase': "x'${'4e' * 32}'",
      'onionKey': b64('old onion'),
      'edPriv': 'ed',
      'xPriv': 'x',
      'onboardingDone': 'true',
      'secure': {'my_handle': 'someone'},
    });
    expect(File(p.join(docs, 'halo.db')).readAsStringSync(), 'everyday');
    expect(
      File(p.join(docs, 'onion.key')).readAsStringSync(),
      'everyday onion',
    );
    expect(File(p.join(docs, 'halo_d.db')).readAsStringSync(), 'old file');
    expect(File(p.join(docs, 'onion_d.key')).readAsStringSync(), 'old onion');
    const store = FlutterSecureStorage();
    expect(await store.read(key: 'halo.db.passphrase'), 'everyday key');
    expect(await store.read(key: 'halo.d.key'), "x'${'4e' * 32}'");
    expect(await store.read(key: 'my_handle'), 'mine');
    // the everyday sessions are not the ones that came back
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(kSessionsRestoredPref), isFalse);
    // nothing staged is left behind
    expect(Directory(p.join(docs, 'restore_d')).existsSync(), isFalse);
  });

  test('an old text file restored in the everyday app takes the phone off '
      'the moved screen', () async {
    SharedPreferences.setMockInitialValues({'moved.at': 5});
    final day = _Everyday();
    useDatabasesForTest(day, Session(day));
    final e = _Engine();
    useEngineForTest(e);
    Directory(p.join(root.path, 'docs')).createSync(recursive: true);
    await landV1Payload({
      'v': 1,
      'db': base64Encode(utf8.encode('old file')),
      'dbPassphrase': "x'${'4e' * 32}'",
      'edPriv': 'ed',
      'xPriv': 'x',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('moved.at'), isFalse);
    // and the next start marks the sessions the file brought back
    expect(prefs.getBool(kSessionsRestoredPref), isTrue);
    expect(e.restored, ['ed']);
    expect(
      File(p.join(root.path, 'docs', 'halo.db')).readAsStringSync(),
      'old file',
    );
  });

  test('a file that says setup was done restores as done, whatever word '
      'an older decoy backup used', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final day = _Everyday();
    useDatabasesForTest(day, Session(day));
    useEngineForTest(_Engine());
    Directory(p.join(root.path, 'docs')).createSync(recursive: true);
    await landV1Payload({
      'v': 1,
      'db': base64Encode(utf8.encode('old file')),
      'dbPassphrase': "x'${'4e' * 32}'",
      'edPriv': 'ed',
      'xPriv': 'x',
      'onboardingDone': '1',
    });
    const store = FlutterSecureStorage();
    expect(await store.read(key: 'onboarding_done'), 'true');
    expect(onboardingAfterRestore('true'), 'true');
    expect(onboardingAfterRestore(null), isNull);
    expect(onboardingAfterRestore(''), isNull);
  });

  test('the face and the supporter badge go with the identity', () async {
    expect(kIdentitySecureKeys, contains('my_avatar'));
    final plan = identitySecurePlan({'my_avatar': '17'});
    expect(plan.write, {'my_avatar': '17'});
    await restorePrefs({
      'supporter_tier': 'supporter',
      'supporter_receipt_payload': 'payload',
      'supporter_receipt_sig': 'sig',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('supporter_tier'), 'supporter');
    expect(prefs.getString('supporter_receipt_payload'), 'payload');
    expect(prefs.getString('supporter_receipt_sig'), 'sig');
  });

  test('of the prefs a file carries only the known ones are taken', () async {
    await restorePrefs({
      'onboarding.complete': true,
      'moved.at': 5,
      'd.send_mode': 'direct',
      'hb.last': 9,
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'onboarding.complete'});
    expect(prefs.getBool('onboarding.complete'), isTrue);
  });
}
