// SPDX-License-Identifier: GPL-3.0-or-later
// the lows after round four: an older vault that cannot be written again,
// a restore's key against a pending one, the marks' writers, cut lines
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_setup.dart';
import 'package:path/path.dart' as p;

import 'desktop_round4_test.dart' show oldVaultFile;
import 'desktop_start_test.dart' show ToyVaultCrypto;
import 'sealed_file_test.dart' show ToyCrypto;

class _FullDisk implements VaultDisk {
  @override
  void replace(String path, Uint8List bytes) => throw const FileSystemException(
    'write failed',
    'vault.kv.new',
    OSError('No space left on device', 28),
  );
}

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('lows'));
  tearDown(() {
    onDesktop = false;
    root.deleteSync(recursive: true);
  });

  test(
    'an older vault that cannot be written again keeps nothing open',
    () async {
      final path = p.join(root.path, 'v.kv');
      File(path).writeAsBytesSync(await oldVaultFile(2, {'db': 'k'}));
      final v = DesktopVault(path, crypto: ToyVaultCrypto(), disk: _FullDisk());
      await expectLater(
        v.open('four random words here'),
        throwsA(isA<FileSystemException>()),
      );
      expect(v.isOpen, isFalse);
      expect(() => v.read('db'), throwsA(isA<VaultLocked>()));
      // the file is as it was
      expect(File(path).readAsBytesSync()[4], 2);
    },
  );

  group('the engine\'s files', () {
    late String docs, support, run;
    late SealedIO io;
    late DesktopVault vault;
    late EngineFiles ef;
    setUp(() async {
      docs = p.join(root.path, 'docs');
      support = p.join(root.path, 'support');
      run = p.join(root.path, 'run');
      for (final d in [docs, support, run]) {
        Directory(d).createSync(recursive: true);
      }
      io = SealedIO(
        SealedAreas(docs: docs, support: support, runtime: p.join(run, 'tmp'))
          ..filesKey = Uint8List(32),
        ToyCrypto(),
      );
      vault = DesktopVault(
        p.join(root.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create('four random words here');
      ef = EngineFiles(docs: docs, support: support, runtime: run);
      onDesktop = true;
    });
    T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);

    test(
      'a restore\'s key is never overwritten by the one handed before',
      () async {
        await sealed(() async {
          await ef.prepare(vault);
          File(p.join(docs, 'onion.key')).writeAsBytesSync([1, 1]);
          // the start fails: the handed key stays in the engine's folder
          await ef.start((_) async => 'error: no tor');
          // a restore lands a new key meanwhile
          File(p.join(docs, 'onion.key')).writeAsBytesSync([2, 2]);
          ef.sealNewKey();
          expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), [2, 2]);
          // a key the engine itself made is sealed
          rawFileAccess(
            () => File(p.join(ef.dir, 'onion.key')).writeAsBytesSync([3, 3]),
          );
          ef.sealNewKey();
          expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), [3, 3]);
        });
      },
    );

    test('the minute and the exit write through their own temporary files', () {
      final st = p.join(support, 'engine.state');
      sealed(() {
        Directory(p.join(run, 'engine')).createSync(recursive: true);
        rawFileAccess(
          () => File(
            p.join(run, 'engine', 'nostr_last_ab'),
          ).writeAsStringSync('9'),
        );
        // one writer's file left half written does not stop the other
        File('$st.tick').writeAsStringSync('{"half');
        keepMarksIn(p.join(run, 'engine'), st, writer: 'exit');
        expect(readMarkState(st)!.keys, ['nostr_last_ab']);
        expect(File('$st.exit').existsSync(), isFalse);
      });
    });
  });

  test('a cut last line never reaches the engine', () {
    Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
    expect(
      utf8.decode(wholeLines('nostr_seen_ab', b('aaa\nbbb\nccc'))),
      'aaa\nbbb\n',
    );
    expect(
      utf8.decode(wholeLines('nostr_seen_ab', b('aaa\nbbb\n'))),
      'aaa\nbbb\n',
    );
    expect(utf8.decode(wholeLines('nostr_heard_ab', b('half'))), '');
    expect(utf8.decode(wholeLines('nostr_last_ab', b('1700'))), '1700');
  });
}
