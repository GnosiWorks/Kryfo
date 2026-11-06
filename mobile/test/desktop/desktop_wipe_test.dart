// SPDX-License-Identifier: GPL-3.0-or-later
// "wipe kryfo from this computer" takes everything: the vault and what the
// account kept for it first, then every database (everyday, hidden chats,
// decoy) let go of and gone, media, the engine's and tor's folders, the
// trace, the start with the computer, the prefs. the next start is a new
// vault and onboarding, never "halo.db has no key here". what windows held
// while the process ran goes at that start. real folders in a scratch
// folder, a real sqlcipher where one is built, the engine a stand-in
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desktop_channels.dart';
import 'package:kryfo/desktop/desktop_db.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_paths.dart';
import 'package:kryfo/desktop/desktop_platform.dart';
import 'package:kryfo/desktop/desktop_prefs.dart';
import 'package:kryfo/desktop/desktop_run.dart';
import 'package:kryfo/desktop/desktop_start.dart' show wipeThrough;
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/desktop_wipe.dart';
import 'package:kryfo/desktop/sealed_setup.dart' show EngineFiles;
import 'package:kryfo/main.dart' show HaloDb, HaloEngine, useEngineForTest;
import 'package:kryfo/secure_store.dart';
import 'package:kryfo/wipe.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'desktop_keys_test.dart' show FakeKeyring;
import 'desktop_start_test.dart' show ToyVaultCrypto;

final _lib = p.absolute('linux/out/libsqlcipher.so.0');

class _Engine implements HaloEngine {
  final calls = <String>[];
  @override
  Future<String> wipeHold() async {
    calls.add('hold');
    return 'ok';
  }

  @override
  Future<String> handleRelease(String h) async {
    calls.add('release $h');
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final there = File(_lib).existsSync();
  late Directory scratch;
  late String root;
  late String run;
  late String autostart;
  late FakeKeyring ring;
  late DesktopDb db;

  String at(String rel) => p.join(root, rel);

  void put(String rel, [String body = 'plain words']) => File(at(rel))
    ..createSync(recursive: true)
    ..writeAsStringSync(body);

  // the app's storage as the desktop start puts it in place
  Future<DesktopVault> vaultIn() async {
    // the start's folder claim makes it
    Directory(root).createSync(recursive: true);
    final v = DesktopVault(at('vault.kv'), crypto: ToyVaultCrypto());
    FlutterSecureStoragePlatform.instance = VaultStorage(v);
    SharedPreferencesStorePlatform.instance = VaultPrefs(v);
    PathProviderPlatform.instance = DesktopPaths(root, runtime: run);
    return v;
  }

  setUpAll(() {
    db = DesktopDb(libraries: there ? [_lib] : const []);
    final m = DesktopMessenger(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      {sqlcipherChannel: (c) => db.call(c.method, c.arguments)},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          sqlcipherChannel,
          (bytes) async => m.send(sqlcipherChannel, bytes),
        );
  });

  setUp(() {
    onDesktop = true;
    scratch = Directory.systemTemp.createTempSync('desk_wipe');
    root = p.join(scratch.path, 'kryfo');
    run = p.join(scratch.path, 'run');
    autostart = p.join(scratch.path, 'autostart');
    ring = FakeKeyring();
    wipeExit = (_) {};
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), null);
    onDesktop = false;
    haloWiping = false;
    desktopWipeKeys = null;
    desktopLetGo = null;
    wipeShred = shredHeld;
    scratch.deleteSync(recursive: true);
  });

  test('a wipe leaves no file, and the next start is onboarding', () async {
    final vault = await vaultIn();
    await vault.createSealed(ring);
    final everyday = HaloDb();
    if (there) {
      // the everyday database open as the app holds it, its key in the vault
      await (await everyday.open()).rawQuery('SELECT 1');
    } else {
      put('docs/halo.db', 'ciphertext');
    }
    await vault.write('onboarding_done', 'true');
    await vault.write('my_handle', 'wren');
    await (await SharedPreferences.getInstance()).setBool('seen', true);
    // what a run leaves on the disk: hidden chats' and the decoy's
    // databases, media, tor, the trace, the engine's marks, a held entry
    for (final f in [
      'docs/halo_k2.db',
      'docs/halo_k2.db-wal',
      'docs/halo_k3.db',
      'docs/media/a.jpg',
      'docs/media_k2/b.jpg',
      'docs/wallpapers/w.jpg',
      'docs/onion.key',
      'docs/tor/state',
      'docs/tor/cached-microdescs',
      'support/engine.state',
      'cache/registry.bin',
      'tmp/native/c.jpg',
      'wipe_held/0011',
      'trace.txt',
      'lock',
    ]) {
      put(f);
    }
    File(p.join(run, 'engine', 'onion.key'))
      ..createSync(recursive: true)
      ..writeAsStringSync('key');
    File(p.join(run, 'tmp', 'take.wav'))
      ..createSync(recursive: true)
      ..writeAsStringSync('voice');
    final start = LinuxStart(autostart, '/opt/kryfo/kryfo');
    expect(await start.set(true), StartAnswer.on);

    final engine = _Engine();
    useEngineForTest(engine);
    final order = <String>[];
    final host = DesktopHost(
      dataDir: root,
      exit: (c) => order.add('exit $c'),
      destroyKeys: () {
        order.add('vault');
        vault.destroy();
      },
    );
    host
      ..forgetKeys = () async {
        order.add('keyring');
        await vault.forgetSystem(ring);
      }
      ..letGo = () async {
        order.add('let go');
        await db.closeAll();
      }
      ..startOff = () async {
        order.add('start off');
        await start.set(false);
      }
      ..engineGone = EngineFiles(
        docs: at('docs'),
        support: at('support'),
        runtime: run,
      ).destroy;
    wipeThrough(host);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('halo/platform'), (
          c,
        ) async {
          if (c.method != 'wipe') return null;
          order.add('files');
          await host.wipe();
          return false;
        });

    await wipeHalo(releaseHandle: true);
    await wipeShredding;

    // keys before any file, the handle given back while the engine held it
    expect(order.take(2), ['vault', 'keyring']);
    expect(order.indexOf('let go'), lessThan(order.indexOf('files')));
    expect(order.last, 'exit 0');
    expect(engine.calls, ['release wren', 'hold']);
    // nothing left: not the folder, not memory's, not the start entry
    expect(Directory(root).existsSync(), isFalse, reason: '${leftIn(root)}');
    expect(Directory(run).existsSync(), isFalse, reason: '${leftIn(run)}');
    expect(leftIn(autostart), isEmpty);
    expect(ring.items, isEmpty);

    // the next start: a folder made again, a new vault, no keys or prefs
    expect(await clearWithoutVault(root), isFalse);
    final again = await vaultIn();
    expect(again.exists, isFalse);
    await again.createSealed(ring);
    expect(await secureStore.read(key: 'onboarding_done'), isNull);
    expect(await secureStore.read(key: 'my_handle'), isNull);
    // no file is left that the new key would not open: the boot makes the
    // everyday database new instead of "halo.db has no key here"
    expect(File(at('docs/halo.db')).existsSync(), isFalse);
    expect(
      await secureStore.read(key: HaloContainer.everyday.keyName!),
      isNull,
    );
  });

  test(
    'what windows held goes at the next start, and nothing opens it',
    () async {
      // a wipe whose process could not delete everything: tor.exe's files,
      // a database, a plain copy. no vault is left
      for (final f in [
        'tmp/engine/tor/cached-microdescs',
        'tmp/engine/tor/lock',
        'tmp/native/c.jpg',
        'docs/halo.db',
        'wipe_held/0011/a.jpg',
      ]) {
        put(f, 'left behind');
      }
      put('lock', '');
      put('trace.txt', 'start windows');
      put('engine-crash.txt', 'panic: a run before');
      final copy = File(at('tmp/native/c.jpg'));
      final twin = p.join(scratch.path, 'twin');
      Process.runSync('ln', [copy.path, twin]);
      expect(await clearWithoutVault(root), isTrue);
      expect(leftIn(root), ['engine-crash.txt', 'lock', 'trace.txt']);
      // the plain copy was zeroed before it went
      expect(File(twin).readAsBytesSync().every((b) => b == 0), isTrue);
      // then the start goes on to onboarding: a new vault, no keys
      final v = await vaultIn();
      expect(v.exists, isFalse);
    },
  );

  test('a folder with its vault is never swept', () async {
    put('vault.kv', 'sealed');
    put('docs/halo.db', 'ciphertext');
    expect(await clearWithoutVault(root), isFalse);
    expect(leftIn(root), ['docs', 'docs/halo.db', 'vault.kv']);
    File(at('vault.kv')).renameSync(at('vault.kv.new'));
    expect(
      await clearWithoutVault(root),
      isFalse,
      reason: 'a write on its way',
    );
  });

  test(
    'the folder goes past what will not, and a link is not followed',
    () async {
      final outside = Directory(p.join(scratch.path, 'mine'))..createSync();
      File(p.join(outside.path, 'keep.txt')).writeAsStringSync('mine');
      put('docs/media/a.jpg');
      Directory(at('docs')).createSync(recursive: true);
      Link(at('docs/tor')).createSync(outside.path);
      put('support/x');
      expect(await clearDataDir(root, patience: Duration.zero), isEmpty);
      expect(Directory(root).existsSync(), isFalse);
      expect(File(p.join(outside.path, 'keep.txt')).existsSync(), isTrue);
    },
  );

  test(
    'the databases let go of their files for the wipe',
    () async {
      final path = p.join(scratch.path, 'a.db');
      final d = await openDatabase(
        path,
        password: 'k',
        version: 1,
        singleInstance: false,
        onCreate: (db, _) => db.execute('CREATE TABLE t (x)'),
      );
      await db.closeAll();
      await expectLater(d.rawQuery('SELECT 1'), throwsA(anything));
    },
    skip: there ? false : 'no sqlcipher built (linux/build-sqlcipher.sh)',
  );
}
