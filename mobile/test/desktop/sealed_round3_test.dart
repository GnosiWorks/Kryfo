// SPDX-License-Identifier: GPL-3.0-or-later
// the seal's edges: a restore's staging, the folder in memory, the engine's
// own files, moves out to the clear, a sweep finished, the vault's size
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart'
    show forgetLeftoverSweep, sweepBackupLeftovers;
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_paths.dart';
import 'package:kryfo/desktop/desktop_posix.dart' show getuid;
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/sealed_file.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_native.dart';
import 'package:kryfo/desktop/sealed_setup.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'desktop_start_test.dart' show ToyVaultCrypto;
import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String docs, support, run;
  late SealedIO io;

  setUp(() {
    root = Directory.systemTemp.createTempSync('r3');
    docs = p.join(root.path, 'docs');
    support = p.join(root.path, 'support');
    run = p.join(root.path, 'run');
    for (final d in [p.join(docs, 'media'), support, p.join(run, 'tmp')]) {
      Directory(d).createSync(recursive: true);
    }
    final areas =
        SealedAreas(docs: docs, support: support, runtime: p.join(run, 'tmp'))
          ..filesKey = _k(9)
          ..containerKeys[''] = _k(1);
    io = SealedIO(areas, ToyCrypto());
    onDesktop = true;
  });
  tearDown(() {
    onDesktop = false;
    root.deleteSync(recursive: true);
  });

  T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);
  Uint8List raw(String path) => io.rawFile(path).readAsBytesSync();
  bool holds(Uint8List b, String s) =>
      latin1.decode(b, allowInvalid: true).contains(s);

  group('a restore', () {
    test('stages media and the onion key sealed, in both folders', () {
      final a = io.areas;
      expect(a.areaOf(p.join(docs, 'restore_stage', 'media', 'x.jpg')), '*');
      expect(a.areaOf(p.join(docs, 'restore_stage', 'onion.key')), '*');
      expect(a.areaOf(p.join(docs, 'restore_hidden', 'media', 'y')), '*');
      expect(a.areaOf(p.join(docs, 'restore_stage', 'halo.db')), isNull);
      expect(a.areaOf(p.join(docs, 'onion.key')), '*');
      sealed(() {
        final f = File(p.join(docs, 'restore_stage', 'media', 'x.jpg'));
        f.parent.createSync(recursive: true);
        f.writeAsStringSync('a restored photo');
        File(
          p.join(docs, 'restore_stage', 'onion.key'),
        ).writeAsStringSync('onionkey');
        // landing: the stage's key lands on docs/onion.key, sealed still
        File(
          p.join(docs, 'restore_stage', 'onion.key'),
        ).renameSync(p.join(docs, 'onion.key'));
        expect(File(p.join(docs, 'onion.key')).readAsStringSync(), 'onionkey');
      });
      expect(
        holds(raw(p.join(docs, 'restore_stage', 'media', 'x.jpg')), 'photo'),
        isFalse,
      );
      expect(holds(raw(p.join(docs, 'onion.key')), 'onionkey'), isFalse);
    });

    test('cut short, what it staged is shredded at the next start', () async {
      PathProviderPlatform.instance = DesktopPaths(root.path);
      final staged = p.join(docs, 'restore_stage', 'media', 'x.jpg');
      final hidden = p.join(docs, 'restore_hidden', 'media', 'y.jpg');
      await sealed(() async {
        for (final f in [staged, hidden]) {
          File(f)
            ..parent.createSync(recursive: true)
            ..writeAsStringSync('half a restore');
        }
        forgetLeftoverSweep();
        await sweepBackupLeftovers();
      });
      expect(Directory(p.join(docs, 'restore_stage')).existsSync(), isFalse);
      expect(Directory(p.join(docs, 'restore_hidden')).existsSync(), isFalse);
    });
  });

  group('the folder in memory', () {
    test('one found is taken only when it is ours, 0700 and no link', () {
      final base = p.join(root.path, 'xdg');
      Directory(base).createSync();
      final env = {'XDG_RUNTIME_DIR': base};
      final uid = getuid();
      // none there: made, and taken
      expect(desktopRuntimeDir(env: env, uid: uid), p.join(base, 'kryfo'));
      // someone else's: a new one by chance beside it
      final other = desktopRuntimeDir(
        env: env,
        uid: uid,
        owner: (d) => d.endsWith('/kryfo') ? uid + 1 : uid,
      );
      expect(other, isNot(p.join(base, 'kryfo')));
      expect(p.basename(other!), startsWith('kryfo-'));
      // a link in its place
      Directory(p.join(base, 'kryfo')).deleteSync();
      Link(p.join(base, 'kryfo')).createSync(root.path);
      final linked = desktopRuntimeDir(env: env, uid: uid);
      expect(linked, isNot(p.join(base, 'kryfo')));
      expect(
        FileSystemEntity.typeSync(linked!, followLinks: false),
        FileSystemEntityType.directory,
      );
      expect(FileStat.statSync(linked).mode & 511, 448);
    });
  });

  group('the engine\'s files', () {
    late DesktopVault vault;
    late EngineFiles ef;
    setUp(() async {
      vault = DesktopVault(
        p.join(root.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create('four random words here');
      ef = EngineFiles(docs: docs, support: support, runtime: run);
    });

    test('an older layout is moved in: names and key off the disk', () async {
      io
          .rawFile(p.join(docs, 'nostr_seen_0123456789abcdef'))
          .writeAsStringSync('ids');
      io
          .rawFile(p.join(docs, 'nostr_last_0123456789abcdef'))
          .writeAsStringSync('1700');
      await vault.write(kOnionEntry, base64.encode([1, 2, 3]));
      Link(p.join(docs, 'onion.key')).createSync(p.join(run, 'onion.key'));
      await sealed(() => ef.prepare(vault));
      final names = io
          .rawDirectory(docs)
          .listSync()
          .map((e) => p.basename(e.path));
      expect(names.where((n) => n.startsWith('nostr_')), isEmpty);
      expect(vault.read(kOnionEntry), isNull);
      sealed(() {
        expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), [1, 2, 3]);
        expect(
          File(
            p.join(ef.dir, 'nostr_last_0123456789abcdef'),
          ).readAsStringSync(),
          '1700',
        );
      });
      expect(holds(raw(p.join(support, 'engine.state')), 'nostr_'), isFalse);
      expect(
        FileSystemEntity.typeSync(p.join(ef.dir, 'tor'), followLinks: false),
        FileSystemEntityType.link,
      );
    });

    test('the onion key is in memory only while the engine reads it', () async {
      await sealed(() async {
        await ef.prepare(vault);
        File(p.join(docs, 'onion.key')).writeAsBytesSync([7, 7]);
        late List<int> seen;
        final r = await ef.start((dir) async {
          seen = rawFileAccess(
            () => File(p.join(dir, 'onion.key')).readAsBytesSync(),
          );
          return 'abc.onion';
        });
        expect(r, 'abc.onion');
        expect(seen, [7, 7]);
        expect(
          rawFileAccess(() => File(p.join(ef.dir, 'onion.key')).existsSync()),
          isFalse,
        );
        // an error: the key stays for the engine's own retry
        await ef.start((_) async => 'error: no tor');
        expect(
          rawFileAccess(() => File(p.join(ef.dir, 'onion.key')).existsSync()),
          isTrue,
        );
        ef.clearMemory();
        expect(
          rawFileAccess(() => File(p.join(ef.dir, 'onion.key')).existsSync()),
          isFalse,
        );
      });
    });

    test('a key the engine made is kept sealed', () async {
      await sealed(() async {
        await ef.prepare(vault);
        await ef.start((dir) async {
          rawFileAccess(
            () => File(p.join(dir, 'onion.key')).writeAsBytesSync([5, 6]),
          );
          return 'new.onion';
        });
        expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), [5, 6]);
      });
      expect(isSealedHead(raw(p.join(docs, 'onion.key'))), isTrue);
    });

    test('the marks come back next start from their sealed copy', () async {
      await sealed(() async {
        await ef.prepare(vault);
        rawFileAccess(
          () => File(p.join(ef.dir, 'nostr_seen_aa')).writeAsStringSync('e1'),
        );
        ef.detach();
        rawFileAccess(() => Directory(ef.dir).deleteSync(recursive: true));
        await ef.prepare(vault);
        expect(
          rawFileAccess(
            () => File(p.join(ef.dir, 'nostr_seen_aa')).readAsStringSync(),
          ),
          'e1',
        );
      });
    });

    test('memory\'s temporary files go zeroed at a start', () {
      final t = File(p.join(run, 'tmp', 'take.wav'))
        ..writeAsStringSync('RIFF a take');
      ef.clearMemory();
      expect(t.existsSync(), isFalse);
      expect(Directory(p.join(run, 'tmp')).existsSync(), isTrue);
    });
  });

  group('moves', () {
    test('a sealed file does not move out to the disk in the clear', () {
      sealed(() {
        final a = p.join(docs, 'media', 'm');
        File(a).writeAsStringSync('stay sealed');
        expect(
          () => File(a).copySync(p.join(root.path, 'out')),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          () => File(a).renameSync(p.join(root.path, 'out')),
          throwsA(isA<FileSystemException>()),
        );
        expect(File(a).existsSync(), isTrue);
        // into memory, and by a save that asks: yes
        File(a).copySync(p.join(run, 'tmp', 'm'));
        plainOutAllowed(() => File(a).copySync(p.join(root.path, 'saved')));
        expect(
          File(p.join(root.path, 'saved')).readAsStringSync(),
          'stay sealed',
        );
      });
    });
  });

  group('the sweep', () {
    test('a copy with a bad chunk inside never stands in', () {
      final a = p.join(docs, 'media', 'big');
      sealed(() {
        File('$a.sealing').writeAsBytesSync(List.filled(3 * chunkPlain, 1));
      });
      final b = raw('$a.sealing')..[sealedHead + chunkStored + 50] ^= 1;
      io.rawFile('$a.sealing').writeAsBytesSync(b);
      io.rawFile(a).writeAsStringSync('the plain one');
      sealed(() => sealPlainUnder(p.join(docs, 'media')));
      sealed(() => expect(File(a).readAsStringSync(), 'the plain one'));
    });

    test('once finished, a plain file in a sealed place is damage', () {
      final a = p.join(docs, 'media', 'put');
      io.rawFile(a).writeAsStringSync('slipped in');
      sealed(() => expect(File(a).readAsStringSync(), 'slipped in'));
      io.areas.swept.add('');
      sealed(
        () => expect(
          () => File(a).readAsStringSync(),
          throwsA(isA<SealedDamaged>()),
        ),
      );
    });
  });

  test('a failed native write leaves nothing sealed in place', () async {
    final out = p.join(docs, 'media', 'vn.wav');
    await sealed(
      () => nativeFilesSealed<String>(io.areas, const [], [out], (_, o) async {
        rawFileAccess(() => File(o.single).writeAsStringSync('half'));
        return 'error: stopped';
      }, (r) => r.startsWith('ok ')),
    );
    expect(io.rawFile(out).existsSync(), isFalse);
  });

  test('a restore\'s key from the vault goes when its container closes', () {
    final keys = ContainerKeys(io.areas);
    io.areas.containerKeys['_k2'] = _k(4);
    final held = io.areas.containerKeys['_k2']!;
    keys.closed('2', '_k2');
    expect(io.areas.containerKeys, isNot(contains('_k2')));
    expect(held.every((b) => b == 0), isTrue);
  });

  test('the vault file grows only in whole steps', () async {
    final v = DesktopVault(p.join(root.path, 'v.kv'), crypto: ToyVaultCrypto());
    await v.create('four random words here');
    expect(File(p.join(root.path, 'v.kv')).lengthSync(), kVaultBucket);
    await v.write('a', 'x' * 20000);
    expect(File(p.join(root.path, 'v.kv')).lengthSync(), 2 * kVaultBucket);
    await v.write('a', 'y');
    expect(File(p.join(root.path, 'v.kv')).lengthSync(), kVaultBucket);
    final w = DesktopVault(p.join(root.path, 'v.kv'), crypto: ToyVaultCrypto());
    expect(await w.open('four random words here'), isTrue);
    expect(w.read('a'), 'y');
    expect(unpadded(padded([1, 2, 3], 54)), [1, 2, 3]);
  });
}
