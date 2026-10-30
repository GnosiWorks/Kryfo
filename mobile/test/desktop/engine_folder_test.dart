// SPDX-License-Identifier: GPL-3.0-or-later
// the engine's folder: every start goes through the desktop's seam, the
// phone's start is untouched, and a folder an engine started in docs left
// heals at the next start
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/sealed_format.dart' show isSealedHead;
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_setup.dart';
import 'package:path/path.dart' as p;

import 'desktop_start_test.dart' show ToyVaultCrypto;
import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

Map<String, String> _sources() => {
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      p.relative(f.path, from: 'lib'): f.readAsStringSync(),
};

void main() {
  group('every engine start', () {
    test('goes through startEngineIn', () {
      // a start past it puts the onion key and the marks plain in docs
      final call = RegExp(
        r'\b(_startListenerOnIsolate|startListenerBg|startListener)\(',
      );
      final def = RegExp(
        r'(String|Future<String>) (_startListenerOnIsolate|startListenerBg|startListener)\(String dataDir\)',
      );
      final found = <String>[];
      for (final MapEntry(key: f, value: src) in _sources().entries) {
        for (final line in const LineSplitter().convert(src)) {
          if (!call.hasMatch(line) || def.hasMatch(line)) continue;
          found.add('$f: ${line.trim()}');
        }
      }
      // the one forward, inside startListenerBg itself
      expect(found, ['app/engine.dart: _startListenerOnIsolate(dataDir);']);
    });

    test('the boot, the watchdog and the dev screen hand it docs', () {
      final src = _sources();
      expect(
        'startEngineIn(docsDir.path, engine.startListenerBg)'
            .allMatches(src['app/state_boot.dart']!)
            .length,
        2,
      );
      expect(
        src['app/dev_screen.dart'],
        contains('startEngineIn(docsDir.path, _startListenerOnIsolate)'),
      );
    });
  });

  group('the phone', () {
    test('starts the engine in docs, as before', () async {
      expect(onDesktop, isFalse);
      expect(engineStarter, isNull);
      expect(engineDirOf, isNull);
      final seen = <String>[];
      final r = await startEngineIn('/data/user/0/app/docs', (dir) async {
        seen.add(dir);
        return 'abc.onion';
      });
      expect(r, 'abc.onion');
      expect(seen, ['/data/user/0/app/docs']);
      expect(engineDir('/data/user/0/app/docs'), '/data/user/0/app/docs');
    });

    test('never runs the desktop start that sets the seam', () {
      final src = _sources();
      final starts = [
        for (final e in src.entries)
          if (RegExp(r'\bstartDesktop\(').hasMatch(e.value)) e.key,
      ]..sort();
      // main.dart is the phone's target, main_desktop.dart the desktop's
      expect(starts, ['desktop/desktop_start.dart', 'main_desktop.dart']);
      final sets = [
        for (final e in src.entries)
          if (RegExp(r'\b(engineStarter|engineDirOf) = ').hasMatch(e.value))
            e.key,
      ];
      expect(sets, ['desktop/desktop_start.dart']);
    });
  });

  group('a folder an engine started in docs left', () {
    late Directory root;
    late String docs, support, run;
    late SealedIO io;
    late DesktopVault vault;
    late Uint8List onion;
    const id = '0123456789abcdef';

    setUp(() async {
      root = Directory.systemTemp.createTempSync('engfolder');
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
      areas.swept.addAll(['', '*']);
      io = SealedIO(areas, ToyCrypto());
      vault = DesktopVault(
        p.join(root.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create('four random words here');
      onDesktop = true;
      final r = Random(7);
      onion = Uint8List.fromList(List.generate(64, (_) => r.nextInt(256)));
      // what the go engine writes in its data dir, here docs
      void put(String name, List<int> b) =>
          io.rawFile(p.join(docs, name)).writeAsBytesSync(b);
      put('onion.key', onion);
      put('nostr_seen_$id', utf8.encode('e1\ne2\n'));
      put('nostr_last_$id', utf8.encode('1700000000'));
      put('nostr_last_$id.b', utf8.encode('1700000001'));
      put('nostr_heard_$id', utf8.encode('h1 1700000000\n'));
      put('nostr_topup', [1, 2, 3, 4]);
      put('engine-debug.log', utf8.encode('halo: listening on abc.onion'));
      io.rawFile(p.join(docs, 'tor', 'state'))
        ..createSync(recursive: true)
        ..writeAsStringSync('guards');
      // an earlier start of the same build kept older marks sealed
      IOOverrides.runWithIOOverrides(
        () => writeMarkState(p.join(support, 'engine.state'), {
          'nostr_last_$id': base64.encode(utf8.encode('1600000000')),
          'nostr_last_fedcba9876543210': base64.encode(
            utf8.encode('1650000000'),
          ),
        }),
        io,
      );
    });
    tearDown(() {
      onDesktop = false;
      root.deleteSync(recursive: true);
    });

    T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);
    Uint8List raw(String path) => io.rawFile(path).readAsBytesSync();
    String rawText(String path) => latin1.decode(raw(path));

    // the engine as bridge.go reads its key: 64 bytes, else a new one
    Future<String> Function(String) engine(List<Uint8List> used) =>
        (dir) async {
          final f = io.rawFile(p.join(dir, 'onion.key'));
          var k = f.existsSync() ? f.readAsBytesSync() : Uint8List(0);
          if (k.length != 64) {
            final r = Random();
            k = Uint8List.fromList(List.generate(64, (_) => r.nextInt(256)));
            f.writeAsBytesSync(k);
          }
          used.add(Uint8List.fromList(k));
          return 'abc.onion';
        };

    Future<void> startOnce(List<Uint8List> used) async {
      final ef = EngineFiles(docs: docs, support: support, runtime: run);
      await sealed(() async {
        await ef.prepare(vault);
        await ef.start(engine(used));
        ef.detach();
      });
    }

    test('keeps its onion key, sealed', () async {
      final used = <Uint8List>[];
      await startOnce(used);
      await startOnce(used);
      expect(used, [onion, onion]);
      final key = p.join(docs, 'onion.key');
      expect(isSealedHead(raw(key)), isTrue);
      expect(io.rawFile('$key.new').existsSync(), isFalse);
      sealed(() => expect(File(key).readAsBytesSync(), onion));
      final plain = latin1.decode(onion);
      for (final f in io.rawDirectory(root.path).listSync(recursive: true)) {
        if (f is File) expect(rawText(f.path).contains(plain), isFalse);
      }
    });

    test('its marks move in, the newer ones from docs', () async {
      final ef = EngineFiles(docs: docs, support: support, runtime: run);
      await sealed(() => ef.prepare(vault));
      final names = io
          .rawDirectory(docs)
          .listSync()
          .map((e) => p.basename(e.path))
          .toSet();
      expect(names, {'onion.key', 'media', 'tor'});
      String mark(String n) =>
          utf8.decode(raw(p.join(ef.dir, n)), allowMalformed: true);
      expect(mark('nostr_seen_$id'), 'e1\ne2\n');
      expect(mark('nostr_last_$id'), '1700000000');
      expect(mark('nostr_last_$id.b'), '1700000001');
      expect(mark('nostr_heard_$id'), 'h1 1700000000\n');
      expect(mark('nostr_last_fedcba9876543210'), '1650000000');
      expect(raw(p.join(ef.dir, 'nostr_topup')), [1, 2, 3, 4]);
      expect(
        rawText(p.join(support, 'engine.state')).contains('nostr_'),
        isFalse,
      );
      expect(
        io.rawFile(p.join(ef.dir, 'tor', 'state')).readAsStringSync(),
        'guards',
      );
      expect(Link(p.join(ef.dir, 'tor')).targetSync(), p.join(docs, 'tor'));
    });

    test('a second start changes nothing the first one made', () async {
      final used = <Uint8List>[];
      await startOnce(used);
      final key = raw(p.join(docs, 'onion.key'));
      final state = raw(p.join(support, 'engine.state'));
      Set<String> listing() => io
          .rawDirectory(root.path)
          .listSync(recursive: true, followLinks: false)
          .map((e) => p.relative(e.path, from: root.path))
          .where((n) => !n.startsWith('vault'))
          .toSet();
      final before = listing();
      await sealed(
        () => EngineFiles(
          docs: docs,
          support: support,
          runtime: run,
        ).prepare(vault),
      );
      expect(raw(p.join(docs, 'onion.key')), key);
      expect(raw(p.join(support, 'engine.state')), state);
      expect(listing(), before);
    });
  });

  group('a plain key sealed where it lies', () {
    late Directory root;
    late String docs, support, run, key;
    late SealedIO io;
    late DesktopVault vault;
    late EngineFiles ef;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('engkey');
      docs = p.join(root.path, 'docs');
      support = p.join(root.path, 'support');
      run = p.join(root.path, 'run');
      for (final d in [docs, support, p.join(run, 'tmp')]) {
        Directory(d).createSync(recursive: true);
      }
      final areas = SealedAreas(
        docs: docs,
        support: support,
        runtime: p.join(run, 'tmp'),
      )..filesKey = _k(9);
      io = SealedIO(areas, ToyCrypto());
      vault = DesktopVault(
        p.join(root.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create('four random words here');
      ef = EngineFiles(docs: docs, support: support, runtime: run);
      key = p.join(docs, 'onion.key');
      onDesktop = true;
    });
    tearDown(() {
      onDesktop = false;
      root.deleteSync(recursive: true);
    });

    T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);

    test('a seal cut short after the zeroing is picked up', () async {
      // the copy was whole and the plain bytes zeroed, the rename not done
      sealed(() => File('$key.new').writeAsBytesSync([4, 2]));
      io.rawFile(key).writeAsBytesSync(Uint8List(64));
      await sealed(() => ef.prepare(vault));
      expect(io.rawFile('$key.new').existsSync(), isFalse);
      sealed(() => expect(File(key).readAsBytesSync(), [4, 2]));
    });

    test('a copy cut short is made again from the plain key', () async {
      sealed(() => File('$key.new').writeAsBytesSync(List.filled(9000, 3)));
      final cut = io.rawFile('$key.new').readAsBytesSync();
      io.rawFile('$key.new').writeAsBytesSync(cut.sublist(0, cut.length - 40));
      io.rawFile(key).writeAsBytesSync([8, 8, 8]);
      await sealed(() => ef.prepare(vault));
      expect(io.rawFile('$key.new').existsSync(), isFalse);
      sealed(() => expect(File(key).readAsBytesSync(), [8, 8, 8]));
    });

    test(
      'the plain bytes are zeroed before the sealed copy takes the name',
      () async {
        io.rawFile(key).writeAsBytesSync(utf8.encode('ED25519-V3:secret'));
        // a hard link sees the inode the plain bytes lay in
        final seen = p.join(root.path, 'seen');
        final r = Process.runSync('ln', [key, seen]);
        expect(r.exitCode, 0);
        await sealed(() => ef.prepare(vault));
        expect(io.rawFile(seen).readAsBytesSync(), Uint8List(17));
        expect(isSealedHead(io.rawFile(key).readAsBytesSync()), isTrue);
      },
    );
  });
}
