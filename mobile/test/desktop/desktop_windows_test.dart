// SPDX-License-Identifier: GPL-3.0-or-later
// the windows side that runs on any host: the runner's folder word, the
// temporary folder sealed under a key of the run, and its clearing, and
// what a second start finds there
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/desktop/desktop_start.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/sealed_format.dart' show isSealedHead;
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_setup.dart';
import 'package:path/path.dart' as p;

import 'desktop_start_test.dart' show ToyVaultCrypto;
import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

void main() {
  test('the runner\'s folder word', () {
    expect(windowsFolderStop('ok'), isNull);
    expect(windowsFolderStop('locked'), DesktopStop.alreadyOpen);
    expect(windowsFolderStop('owner'), DesktopStop.notYours);
    expect(windowsFolderStop('link'), DesktopStop.notPrivate);
    expect(windowsFolderStop('acl'), DesktopStop.notPrivate);
    // no word: not started by kryfo.exe, so nothing was checked
    expect(windowsFolderStop(null), DesktopStop.notPrivate);
    expect(windowsFolderStop('nofolder'), DesktopStop.notPrivate);
  });

  group('the temporary folder', () {
    late Directory root;
    late String docs, support, tmp;
    late SealedIO io;

    setUp(() {
      root = Directory.systemTemp.createTempSync('win');
      docs = p.join(root.path, 'docs');
      support = p.join(root.path, 'support');
      tmp = p.join(root.path, 'tmp');
      for (final d in [p.join(docs, 'media'), support, tmp]) {
        Directory(d).createSync(recursive: true);
      }
      final areas = SealedAreas(docs: docs, support: support, tmp: tmp)
        ..filesKey = _k(9)
        ..containerKeys[''] = _k(1)
        ..sessionKey = _k(7);
      io = SealedIO(areas, ToyCrypto());
    });
    tearDown(() => root.deleteSync(recursive: true));

    T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);
    bool holds(Uint8List b, String s) =>
        latin1.decode(b, allowInvalid: true).contains(s);

    test('is an area of its own, under the run\'s key', () {
      final a = io.areas;
      expect(a.areaOf(p.join(tmp, 'take.wav')), '~');
      expect(a.areaOf(p.join(tmp, 'deep', 'x')), '~');
      expect(a.keyFor(p.join(tmp, 'take.wav')), _k(7));
      expect(a.areaOf(p.join(root.path, 'vault.kv')), isNull);
      // the engine reads its folder by path: the onion key, its marks
      expect(a.areaOf(p.join(tmp, 'engine')), isNull);
      expect(a.areaOf(p.join(tmp, 'engine', 'onion.key')), isNull);
      expect(a.areaOf(p.join(tmp, 'engines', 'x')), '~');
    });

    test('what dart writes there is sealed on the disk', () {
      final f = p.join(tmp, 'pick.jpg');
      sealed(() => File(f).writeAsStringSync('a picked photo'));
      expect(holds(io.rawFile(f).readAsBytesSync(), 'a picked photo'), isFalse);
      expect(sealed(() => File(f).readAsStringSync()), 'a picked photo');
    });

    test('a move into media seals again under the media key', () {
      final from = p.join(tmp, 'pick.jpg');
      final to = p.join(docs, 'media', 'in_1.jpg');
      sealed(() {
        File(from).writeAsStringSync('a picked photo');
        File(from).renameSync(to);
      });
      expect(io.rawFile(from).existsSync(), isFalse);
      expect(sealed(() => File(to).readAsStringSync()), 'a picked photo');
      final other = SealedIO(
        SealedAreas(docs: docs, support: support, tmp: tmp)
          ..containerKeys[''] = _k(1),
        ToyCrypto(),
      );
      // the media key alone opens it: the run's key is not needed
      expect(
        IOOverrides.runWithIOOverrides(
          () => File(to).readAsStringSync(),
          other,
        ),
        'a picked photo',
      );
    });

    test('without the run\'s key it does not open', () {
      final f = p.join(tmp, 'take.wav');
      sealed(() => File(f).writeAsStringSync('speech'));
      final next = SealedIO(
        SealedAreas(docs: docs, support: support, tmp: tmp)..sessionKey = _k(8),
        ToyCrypto(),
      );
      expect(
        () => IOOverrides.runWithIOOverrides(
          () => File(f).readAsStringSync(),
          next,
        ),
        throwsA(anything),
      );
    });

    test('the key and the folder go to an isolate', () {
      final m = io.areas.toMessage();
      final back = SealedAreas.fromMessage(m);
      expect(back.tmp, tmp);
      expect(back.sessionKey, _k(7));
    });

    test('is cleared at the start, zeroed first', () {
      final f = File(p.join(tmp, 'a', 'left.bin'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(70000, 0x41));
      clearFolder(tmp);
      expect(f.existsSync(), isFalse);
      expect(Directory(tmp).existsSync(), isTrue);
      clearFolder(p.join(root.path, 'none'));
    });

    test('a run\'s key is fresh and 32 bytes', () {
      final a = sessionKey(), b = sessionKey();
      expect(a, hasLength(32));
      expect(a, isNot(b));
    });

    test('a clear keeps tor\'s own folder', () {
      final tor = p.join(tmp, kEngineFolder, 'tor');
      final state = File(p.join(tor, 'state'))
        ..createSync(recursive: true)
        ..writeAsStringSync('guards');
      final mark = File(p.join(tmp, kEngineFolder, 'nostr_seen_aa'))
        ..writeAsStringSync('ids');
      clearFolder(tmp, keep: [tor]);
      expect(state.readAsStringSync(), 'guards');
      expect(mark.existsSync(), isFalse);
    });
  });

  group('a second start', () {
    const pass = 'four random words here';
    late Directory root;
    late String docs, support, tmp;
    late SealedIO io;
    late DesktopVault vault;
    late EngineFiles ef;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('win2');
      docs = p.join(root.path, 'docs');
      support = p.join(root.path, 'support');
      tmp = p.join(root.path, 'tmp');
      for (final d in [docs, support, tmp]) {
        Directory(d).createSync(recursive: true);
      }
      final areas = SealedAreas(docs: docs, support: support, tmp: tmp)
        ..filesKey = _k(9)
        ..sessionKey = _k(7);
      // the first start's sweep was done: a plain file there now is damage
      areas.swept.add('*');
      io = SealedIO(areas, ToyCrypto());
      vault = DesktopVault(
        p.join(root.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create(pass);
      ef = EngineFiles(
        docs: docs,
        support: support,
        runtime: tmp,
        windows: true,
      );
      onDesktop = true;
    });
    tearDown(() {
      onDesktop = false;
      root.deleteSync(recursive: true);
    });

    T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);
    Uint8List raw(String path) => io.rawFile(path).readAsBytesSync();

    test('the vault the first start wrote opens again', () async {
      await vault.write('kryfo.files', 'x');
      vault.close();
      final again = DesktopVault(
        p.join(root.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      expect(await again.open(pass), isTrue);
      expect(again.read('kryfo.files'), 'x');
    });

    test('the boot starts the engine only through the desktop\'s seam', () {
      // a start in docs left the onion key and the marks plain there
      for (final f in ['state_boot.dart', 'dev_screen.dart']) {
        final src = File('lib/app/$f').readAsStringSync();
        expect(src, isNot(contains('_startListenerOnIsolate(docsDir')));
        expect(src, contains('startEngineIn(docsDir.path'));
      }
    });

    test('a plain onion key in docs is sealed where it lies', () async {
      final key = p.join(docs, 'onion.key');
      io.rawFile(key).writeAsBytesSync(utf8.encode('ED25519-V3:secret'));
      await sealed(() => ef.prepare(vault));
      expect(isSealedHead(raw(key)), isTrue);
      expect(latin1.decode(raw(key)).contains('secret'), isFalse);
      expect(io.rawFile('$key.new').existsSync(), isFalse);
      sealed(() {
        expect(utf8.decode(File(key).readAsBytesSync()), 'ED25519-V3:secret');
      });
    });

    test('a seal of the key cut short is picked up', () async {
      final key = p.join(docs, 'onion.key');
      // the copy was whole and the plain bytes zeroed, the rename not done
      sealed(() => File('$key.new').writeAsBytesSync([4, 2]));
      io.rawFile(key).writeAsBytesSync(Uint8List(17));
      await sealed(() => ef.prepare(vault));
      expect(io.rawFile('$key.new').existsSync(), isFalse);
      sealed(() => expect(File(key).readAsBytesSync(), [4, 2]));
    });

    test(
      'a second prepare on what the first one made changes nothing',
      () async {
        final key = p.join(docs, 'onion.key');
        await sealed(() async {
          await ef.prepare(vault);
          // the first run: the engine made its key and marks, the app ended
          await ef.start((dir) async {
            rawFileAccess(() {
              File(p.join(dir, 'onion.key')).writeAsBytesSync([5, 6]);
              File(p.join(dir, 'nostr_last_aa')).writeAsStringSync('1700');
            });
            return 'abc.onion';
          });
          ef.detach();
        });
        final before = raw(key);
        final docsBefore = io.rawDirectory(docs).listSync().map((e) => e.path);
        // the second start clears tmp as kryfo.exe's start does
        clearFolder(tmp, keep: [p.join(ef.dir, 'tor')]);
        await sealed(() => ef.prepare(vault));
        expect(raw(key), before);
        expect(
          io.rawDirectory(docs).listSync().map((e) => e.path).toSet(),
          docsBefore.toSet(),
        );
        sealed(() {
          expect(File(key).readAsBytesSync(), [5, 6]);
          expect(
            File(p.join(ef.dir, 'nostr_last_aa')).readAsStringSync(),
            '1700',
          );
        });
      },
    );

    test('tor\'s folder is a real one, kept, with no link made', () async {
      final at = p.join(ef.dir, 'tor');
      await sealed(() => ef.prepare(vault));
      expect(
        FileSystemEntity.typeSync(at, followLinks: false),
        FileSystemEntityType.directory,
      );
      File(p.join(at, 'state')).writeAsStringSync('guards');
      await sealed(() => ef.prepare(vault));
      expect(File(p.join(at, 'state')).readAsStringSync(), 'guards');
    });

    test('a developer mode link to docs/tor stays, any other goes', () async {
      final at = p.join(ef.dir, 'tor');
      Directory(ef.dir).createSync(recursive: true);
      Directory(p.join(docs, 'tor')).createSync();
      Link(at).createSync(p.join(docs, 'tor'));
      await sealed(() => ef.prepare(vault));
      expect(Link(at).targetSync(), p.join(docs, 'tor'));
      Link(at).updateSync(root.path);
      await sealed(() => ef.prepare(vault));
      expect(
        FileSystemEntity.typeSync(at, followLinks: false),
        FileSystemEntityType.directory,
      );
    });
  });

  test('no lookup in the process on a windows path', () {
    // kryfo.exe's dacl refuses it there: each one is linux's, android's
    // (phone_seal's memfd) or ios's
    final found = <String, int>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final n = 'DynamicLibrary.process()'
          .allMatches(f.readAsStringSync())
          .length;
      if (n > 0) found[p.relative(f.path, from: 'lib')] = n;
    }
    expect(found, {
      'native_libs.dart': 2,
      'desktop/desktop_paths.dart': 2,
      'desktop/desktop_posix.dart': 1,
      'desktop/desktop_audio.dart': 1,
      'desktop/sealed_native.dart': 2,
      'tools/age_ffi.dart': 1,
      'signal_ffi/kryfo_signal.dart': 1,
      'phone_seal.dart': 2,
    });
  });

  test('the engine is found through haloLibrary everywhere', () {
    // a libhalo.so or process() pair of its own would miss halo.dll
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (p.basename(f.path) == 'native_libs.dart') continue;
      expect(
        f.readAsStringSync().contains("DynamicLibrary.open('libhalo.so')"),
        isFalse,
        reason: f.path,
      );
    }
    for (final f in [
      'app/engine.dart',
      'devices/history_ffi.dart',
      'devices/device_state.dart',
      'devices/link_calls.dart',
      'desktop/desktop_vault.dart',
      'desktop/sealed_format.dart',
      'backup.dart',
      'engine_strings.dart',
    ]) {
      expect(
        File(p.join('lib', f)).readAsStringSync(),
        contains('haloLibrary()'),
        reason: f,
      );
    }
  });

  test('the engine gets the signal library by its full path on windows', () {
    // devices load only with a path; besideExe alone leaves none
    final s = File('lib/signal_ffi/kryfo_signal.dart').readAsStringSync();
    expect("besideExe('kryfo_signal.dll')".allMatches(s), isEmpty);
    expect(s, contains('_loadedFrom = besidePath(_windowsName);'));
  });

  test('age reaches libc only off windows', () {
    // its one process() is libc's open and close, both behind a windows return
    final s = File('lib/tools/age_ffi.dart').readAsStringSync();
    final calls = '_libc()'.allMatches(s).length;
    expect(calls, 3); // the definition and its two uses
    expect(s, contains('if (Platform.isWindows) return -1;'));
    expect(s, contains('if (fd < 0 || Platform.isWindows) return;'));
  });
}
