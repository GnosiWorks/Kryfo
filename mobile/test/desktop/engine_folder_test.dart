// SPDX-License-Identifier: GPL-3.0-or-later
// the engine's folder: every start goes through the desktop's seam, the
// phone's start is untouched, and a folder an engine started in docs left
// heals at the next start
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart'
    show batchBook, catchUpAnchors, landCatchUpAnchors;
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_posix.dart' as posix;
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

    test('the boot, the watchdog, the address ask and the dev screen hand '
        'it docs', () {
      final src = _sources();
      expect(
        'startEngineIn(docsDir.path, engine.startListenerBg)'
            .allMatches(src['app/state_boot.dart']!)
            .length,
        3,
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
      put('nostr_last_$id.2', utf8.encode('1700000001'));
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
      expect(mark('nostr_last_$id.2'), '1700000001');
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

    test('its marks are sealed before the docs copies are zeroed', () async {
      // the zeroing stops at the first mark, as a cut would
      for (final f in io.rawDirectory(docs).listSync()) {
        if (p.basename(f.path).startsWith('nostr_') &&
            !p.basename(f.path).startsWith('nostr_topup')) {
          expect(Process.runSync('chmod', ['0400', f.path]).exitCode, 0);
        }
      }
      final ef = EngineFiles(docs: docs, support: support, runtime: run);
      await expectLater(
        sealed(() => ef.prepare(vault)),
        throwsA(isA<FileSystemException>()),
      );
      final m = sealed(() => readMarkState(p.join(support, 'engine.state')))!;
      String mark(String n) => utf8.decode(base64.decode(m[n]!));
      expect(mark('nostr_seen_$id'), 'e1\ne2\n');
      expect(mark('nostr_last_$id'), '1700000000');
      expect(mark('nostr_last_$id.2'), '1700000001');
      expect(mark('nostr_heard_$id'), 'h1 1700000000\n');
      expect(mark('nostr_last_fedcba9876543210'), '1650000000');
    });

    test('the second store\'s anchor is kept between runs', () async {
      await startOnce([]);
      // the runtime folder is gone after a restart
      final ef = EngineFiles(docs: docs, support: support, runtime: run);
      io.rawDirectory(ef.dir).deleteSync(recursive: true);
      await sealed(() => ef.prepare(vault));
      expect(
        raw(p.join(ef.dir, 'nostr_last_$id.2')),
        utf8.encode('1700000001'),
      );
      // what the restore writes on its way in is not a mark
      io.rawFile(p.join(ef.dir, 'nostr_last_$id.new')).writeAsStringSync('9');
      final anchors = sealed(
        () => keepMarksIn(ef.dir, p.join(support, 'engine.state')),
      );
      expect(anchors.keys.toSet(), {
        'nostr_last_$id',
        'nostr_last_$id.2',
        'nostr_last_fedcba9876543210',
      });
    });

    test('the batch book is kept between runs, so a start keeps every '
        'batch', () async {
      await startOnce([]);
      final ef = EngineFiles(docs: docs, support: support, runtime: run);
      await sealed(() => ef.prepare(vault));
      // one sealed line, as the engine writes it; a cut line too stays whole
      for (final body in ['c2VhbGVkIGJvb2s\n', 'c2VhbGVkIGJvb2s']) {
        io.rawFile(p.join(ef.dir, 'nostr_book')).writeAsStringSync(body);
        final anchors = sealed(
          () => keepMarksIn(ef.dir, p.join(support, 'engine.state')),
        );
        expect(anchors.keys, isNot(contains('nostr_book')));
        // the runtime folder is gone after a restart
        io.rawDirectory(ef.dir).deleteSync(recursive: true);
        await sealed(() => ef.prepare(vault));
        expect(raw(p.join(ef.dir, 'nostr_book')), utf8.encode(body));
      }
    });

    test('the wrap queue is kept between runs', () async {
      await startOnce([]);
      final ef = EngineFiles(docs: docs, support: support, runtime: run);
      io.rawDirectory(ef.dir).deleteSync(recursive: true);
      await sealed(() => ef.prepare(vault));
      io.rawFile(p.join(ef.dir, 'nostr_topup')).writeAsStringSync('w1\nw2\n');
      sealed(ef.keepMarks);
      expect(rawText(p.join(support, 'engine.state')).contains('w1'), isFalse);
      // the runtime folder is gone after a restart
      io.rawDirectory(ef.dir).deleteSync(recursive: true);
      await sealed(() => ef.prepare(vault));
      expect(rawText(p.join(ef.dir, 'nostr_topup')), 'w1\nw2\n');
    });

    group('in the engine\'s memory (windows)', () {
      late _Memory mem;
      setUp(() => mem = _Memory());
      tearDown(() => engineMemory = null);

      EngineFiles files([_Memory? m]) => EngineFiles(
        docs: docs,
        support: support,
        runtime: run,
        memory: m ?? mem,
        windows: false,
      );

      // the engine as bridge.go reads its key, from memory
      Future<String> Function(String) engineInMemory(List<Uint8List> used) =>
          (dir) async {
            var k = mem.files['onion.key'] ?? Uint8List(0);
            if (k.length != 64) {
              final r = Random();
              k = Uint8List.fromList(List.generate(64, (_) => r.nextInt(256)));
              mem.files['onion.key'] = k;
            }
            used.add(Uint8List.fromList(k));
            return 'abc.onion';
          };

      List<String> onDisk(String dir) => [
        for (final e in io.rawDirectory(dir).listSync(recursive: true))
          if (e is File &&
              (p.basename(e.path) == 'onion.key' ||
                  p.basename(e.path).startsWith('nostr_')))
            p.basename(e.path),
      ];

      test('the key, the marks and the queue never reach the disk', () async {
        final ef = files();
        final used = <Uint8List>[];
        await sealed(() async {
          await ef.prepare(vault);
          await ef.start(engineInMemory(used));
        });
        expect(used, [onion]);
        expect(mem.files.containsKey('onion.key'), isFalse);
        expect(onDisk(ef.dir), isEmpty);
        expect(utf8.decode(mem.files['nostr_seen_$id']!), 'e1\ne2\n');
        expect(utf8.decode(mem.files['nostr_last_$id.2']!), '1700000001');
        expect(mem.files['nostr_topup'], [1, 2, 3, 4]);
        expect(isSealedHead(raw(p.join(docs, 'onion.key'))), isTrue);
      });

      test('what 0.6.0 left plain in the folder is zeroed and goes at the '
          'start', () async {
        final ef = files();
        final plain = {
          'nostr_seen_$id': 'e9\n',
          'nostr_topup': 'q9\n',
          'onion.key': 'plain key',
        };
        for (final e in plain.entries) {
          io.rawFile(p.join(ef.dir, e.key))
            ..createSync(recursive: true)
            ..writeAsStringSync(e.value);
        }
        // a hard link sees the bytes the plain file held
        final seen = p.join(root.path, 'seen');
        expect(
          Process.runSync('ln', [p.join(ef.dir, 'nostr_topup'), seen]).exitCode,
          0,
        );
        io.rawFile(p.join(ef.dir, 'tor', 'state'))
          ..createSync(recursive: true)
          ..writeAsStringSync('guards');
        await sealed(() => ef.prepare(vault));
        expect(onDisk(ef.dir), isEmpty);
        expect(io.rawFile(seen).readAsBytesSync(), Uint8List(3));
        expect(
          io.rawFile(p.join(ef.dir, 'tor', 'state')).readAsStringSync(),
          'guards',
        );
        // the sealed copy's marks came in instead
        expect(utf8.decode(mem.files['nostr_seen_$id']!), 'e1\ne2\n');
      });

      test('a new key the engine made is sealed, its copy dropped', () async {
        io.rawFile(p.join(docs, 'onion.key')).deleteSync();
        final ef = files();
        final used = <Uint8List>[];
        await sealed(() async {
          await ef.prepare(vault);
          await ef.start(engineInMemory(used));
        });
        expect(mem.files.containsKey('onion.key'), isFalse);
        sealed(
          () => expect(
            File(p.join(docs, 'onion.key')).readAsBytesSync(),
            used.single,
          ),
        );
      });

      test('what the engine wrote comes back at the next start, the queue '
          'too', () async {
        final ef = files();
        await sealed(() async {
          await ef.prepare(vault);
          await ef.start(engineInMemory([]));
        });
        mem.files['nostr_topup'] = Uint8List.fromList(utf8.encode('q1\n'));
        mem.files['nostr_seen_$id'] = Uint8List.fromList(utf8.encode('e3\n'));
        mem.files['nostr_book'] = Uint8List.fromList(utf8.encode('Ym9vaw\n'));
        await sealed(() => ef.keepMarksOff(vault));
        sealed(ef.detach);
        expect(mem.files, isEmpty);
        expect(
          rawText(p.join(support, 'engine.state')).contains('q1'),
          isFalse,
        );
        // the next process
        final next = _Memory();
        await sealed(() => files(next).prepare(vault));
        expect(utf8.decode(next.files['nostr_topup']!), 'q1\n');
        expect(utf8.decode(next.files['nostr_seen_$id']!), 'e3\n');
        expect(utf8.decode(next.files['nostr_book']!), 'Ym9vaw\n');
        expect(onDisk(root.path).where((n) => n != 'onion.key'), isEmpty);
      });

      test('a backup reads and a restore lands its anchors there', () async {
        engineMemory = mem;
        mem.files['nostr_last_$id'] = Uint8List.fromList(utf8.encode('17'));
        mem.files['nostr_seen_$id'] = Uint8List.fromList(utf8.encode('e\n'));
        mem.files['nostr_topup'] = Uint8List.fromList(utf8.encode('q\n'));
        mem.files['nostr_book'] = Uint8List.fromList(utf8.encode('Ym9vaw\n'));
        final dir = p.join(run, 'engine');
        expect(await catchUpAnchors(dir), {'nostr_last_$id': 17});
        expect(await batchBook(dir), 'Ym9vaw');
        await landCatchUpAnchors(dir, {
          'nostr_last_fedcba9876543210': 21,
        }, book: 'bmV3');
        expect(mem.files.keys.toSet(), {
          'nostr_last_fedcba9876543210',
          'nostr_book',
        });
        expect(utf8.decode(mem.files['nostr_book']!), 'bmV3\n');
        expect(
          io.rawDirectory(run).listSync(recursive: true).whereType<File>(),
          isEmpty,
        );
      });
    });

    test('the sweep syncs the folder before it zeroes', () {
      final a = p.join(docs, 'media', 'old.jpg');
      io.rawFile(a).writeAsStringSync('an old photo');
      final seen = <String>[];
      folderSync = (d) {
        expect(io.rawFile('$a.sealing').existsSync(), isTrue);
        expect(io.rawFile(a).readAsStringSync(), 'an old photo');
        seen.add(d);
      };
      addTearDown(() => folderSync = posix.syncFolder);
      expect(sealed(() => sealPlainUnder(p.join(docs, 'media'))).sealed, 1);
      expect(seen, [p.join(docs, 'media')]);
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

    Uint8List key64(int seed) {
      final r = Random(seed);
      return Uint8List.fromList(List.generate(64, (_) => r.nextInt(256)));
    }

    test('a newer plain key wins over a whole copy beside it', () async {
      // the copy an older seal left, then a start in docs wrote its own key
      sealed(() => File('$key.new').writeAsBytesSync(key64(1)));
      io.rawFile(key).writeAsBytesSync(key64(2));
      await sealed(() => ef.prepare(vault));
      expect(io.rawFile('$key.new').existsSync(), isFalse);
      sealed(() => expect(File(key).readAsBytesSync(), key64(2)));
    });

    test('a key zeroed in part leaves the copy beside it standing', () async {
      for (final at in [0, 48]) {
        sealed(() => File('$key.new').writeAsBytesSync(key64(1)));
        io.rawFile(key).writeAsBytesSync(key64(1)..fillRange(at, at + 16, 0));
        await sealed(() => ef.prepare(vault));
        expect(io.rawFile('$key.new').existsSync(), isFalse);
        sealed(() => expect(File(key).readAsBytesSync(), key64(1)));
      }
    });

    test('the folder is synced before the plain key is zeroed', () async {
      io.rawFile(key).writeAsBytesSync(key64(3));
      final seen = <String>[];
      folderSync = (d) {
        expect(io.rawFile('$key.new').existsSync(), isTrue);
        expect(io.rawFile(key).readAsBytesSync(), key64(3));
        seen.add(d);
      };
      addTearDown(() => folderSync = posix.syncFolder);
      await sealed(() => ef.prepare(vault));
      expect(seen, [docs]);
      sealed(() => expect(File(key).readAsBytesSync(), key64(3)));
    });
  });
}

class _Memory implements EngineMemory {
  final files = <String, Uint8List>{};

  @override
  void put(String name, Uint8List b) => files[name] = Uint8List.fromList(b);

  @override
  Uint8List? get(String name) {
    final b = files[name];
    return b == null ? null : Uint8List.fromList(b);
  }

  @override
  List<String> names() => files.keys.toList();

  @override
  void drop([String name = '']) {
    for (final n in files.keys.toList()) {
      if (name != '' && n != name) continue;
      final b = files.remove(n)!;
      b.fillRange(0, b.length, 0);
    }
  }
}
