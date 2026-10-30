// SPDX-License-Identifier: GPL-3.0-or-later
// older vaults, the engine's folder kept right, its marks' copies, memory
// folders left behind
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_paths.dart';
import 'package:kryfo/desktop/desktop_posix.dart' show getuid;
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_setup.dart';
import 'package:path/path.dart' as p;

import 'desktop_start_test.dart' show ToyVaultCrypto;
import 'sealed_file_test.dart' show ToyCrypto;

const _pass = 'four random words here';

// a vault file as version 1 (no cost byte), 2 (no padding) or 3 wrote it
Future<Uint8List> oldVaultFile(int version, Map<String, String> m) async {
  final c = ToyVaultCrypto();
  final salt = Uint8List.fromList(List.generate(16, (i) => i));
  final fresh = Uint8List.fromList(List.generate(32, (i) => 100 + i));
  final key = (await c.keyOf(_pass, salt, 15))!;
  final fk = Uint8List.fromList(Hmac(sha256, key).convert(fresh).bytes);
  final body = utf8.encode(jsonEncode(m));
  // version 3 padded the body so the file filled whole steps
  final sealed = c.seal(
    fk,
    version >= 3
        ? padded(body, 4 + 1 + 1 + 16 + 32 + 16)
        : Uint8List.fromList(body),
  );
  return Uint8List.fromList([
    0x4b,
    0x52,
    0x59,
    0x56,
    version,
    if (version >= 2) 15,
    ...salt,
    ...fresh,
    ...sealed,
  ]);
}

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('r4'));
  tearDown(() {
    onDesktop = false;
    root.deleteSync(recursive: true);
  });

  group('the vault', () {
    for (final v in [1, 2, 3]) {
      test(
        'a version $v file opens and is written again as today\'s',
        () async {
          final path = p.join(root.path, 'v$v.kv');
          File(path).writeAsBytesSync(await oldVaultFile(v, {'db': 'key $v'}));
          final vault = DesktopVault(path, crypto: ToyVaultCrypto());
          expect(await vault.open(_pass), isTrue);
          expect(vault.read('db'), 'key $v');
          final now = File(path).readAsBytesSync();
          expect(now[4], 4);
          // the passphrase slot's cost, after magic, version, id, count,
          // kind and length
          expect(now[25], kVaultLogN);
          expect(now.length % kVaultBucket, 0);
          final again = DesktopVault(path, crypto: ToyVaultCrypto());
          expect(await again.open(_pass), isTrue);
          expect(again.read('db'), 'key $v');
        },
      );
    }

    test('a wrong passphrase is that, another version says so', () async {
      final path = p.join(root.path, 'x.kv');
      File(path).writeAsBytesSync(await oldVaultFile(2, {'a': 'b'}));
      final vault = DesktopVault(path, crypto: ToyVaultCrypto());
      expect(await vault.open('not this one at all'), isFalse);
      expect(vault.madeByOtherVersion, isFalse);
      final b = File(path).readAsBytesSync()..[4] = 9;
      File(path).writeAsBytesSync(b);
      expect(await vault.open(_pass), isFalse);
      expect(vault.madeByOtherVersion, isTrue);
      File(path).writeAsBytesSync([1, 2, 3, 4, 5, 6]);
      expect(await vault.open(_pass), isFalse);
      expect(vault.madeByOtherVersion, isTrue);
    });
  });

  group('the engine\'s folder', () {
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
      await vault.create(_pass);
      ef = EngineFiles(docs: docs, support: support, runtime: run);
      onDesktop = true;
    });
    T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);

    test('engine/tor is a link to docs/tor, whatever stood there', () async {
      final at = p.join(run, 'engine', 'tor');
      Directory(at).createSync(recursive: true);
      File(p.join(at, 'state')).writeAsStringSync('x');
      await sealed(() => ef.prepare(vault));
      expect(Link(at).targetSync(), p.join(docs, 'tor'));
      Link(at).updateSync(root.path);
      await sealed(() => ef.prepare(vault));
      expect(Link(at).targetSync(), p.join(docs, 'tor'));
    });

    test(
      'a key the engine wrote is sealed on the minute, kept for it',
      () async {
        await sealed(() async {
          await ef.prepare(vault);
          rawFileAccess(
            () => File(p.join(ef.dir, 'onion.key')).writeAsBytesSync([9, 9]),
          );
          ef.sealNewKey();
          expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), [9, 9]);
          expect(
            rawFileAccess(() => File(p.join(ef.dir, 'onion.key')).existsSync()),
            isTrue,
          );
        });
        expect(
          isSealedHead(io.rawFile(p.join(docs, 'onion.key')).readAsBytesSync()),
          isTrue,
        );
      },
    );

    test(
      'an old plain key is sealed in its place, nothing left beside',
      () async {
        io.rawFile(p.join(docs, 'onion.key')).writeAsBytesSync([4, 5, 6]);
        await sealed(() => ef.prepare(vault));
        final raw = io.rawFile(p.join(docs, 'onion.key')).readAsBytesSync();
        expect(isSealedHead(raw), isTrue);
        expect(File(p.join(docs, 'onion.key.new')).existsSync(), isFalse);
        sealed(
          () => expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), [
            4,
            5,
            6,
          ]),
        );
      },
    );

    test('a cut newest copy of the marks falls back to the one before', () {
      final st = p.join(support, 'engine.state');
      sealed(() {
        writeMarkState(st, {'nostr_last_aa': base64.encode(utf8.encode('1'))});
        writeMarkState(st, {'nostr_last_aa': base64.encode(utf8.encode('2'))});
        // the newest cut off in the middle of its last line
        final full = File(st).readAsStringSync();
        File(st).writeAsStringSync(full.substring(0, full.length - 3));
        expect(
          utf8.decode(base64.decode(readMarkState(st)!['nostr_last_aa']!)),
          '1',
        );
      });
    });

    test('with neither copy, the anchors in the vault are the floor', () async {
      await sealed(() async {
        await ef.prepare(vault);
        rawFileAccess(() {
          File(p.join(ef.dir, 'nostr_last_aa')).writeAsStringSync('1700');
          File(p.join(ef.dir, 'nostr_seen_aa')).writeAsStringSync('ids');
        });
        await ef.keepMarksOff(vault);
        // both copies broken
        final st = p.join(support, 'engine.state');
        File(st).writeAsStringSync('{"nost');
        File('$st.old').writeAsStringSync('{"nost');
        rawFileAccess(() => Directory(ef.dir).deleteSync(recursive: true));
        await ef.prepare(vault);
        expect(
          rawFileAccess(
            () => File(p.join(ef.dir, 'nostr_last_aa')).readAsStringSync(),
          ),
          '1700',
        );
        expect(
          rawFileAccess(
            () => File(p.join(ef.dir, 'nostr_seen_aa')).existsSync(),
          ),
          isFalse,
        );
      });
    });

    test(
      'with no folder in memory a sealed file never goes out in the clear',
      () {
        final a = SealedAreas(docs: docs, support: support);
        expect(a.plainOutAllowed(p.join(root.path, 'tmp', 'x')), isFalse);
        expect(a.plainOutAllowed('/proc/self/fd/3'), isTrue);
      },
    );
  });

  test(
    'memory folders a run before made by chance go, this data folder\'s only',
    () {
      final base = p.join(root.path, 'xdg');
      Directory(base).createSync();
      final uid = getuid();
      final tag = runtimeTag(root.path);
      final stale = Directory(p.join(base, 'kryfo-$tag-ab12CD'))..createSync();
      File(p.join(stale.path, 'take.wav')).writeAsStringSync('RIFF');
      final older = Directory(p.join(base, 'kryfo-ab12CD'))..createSync();
      final keep = Directory(p.join(base, 'kryfo-$tag-zz99ZZ'))..createSync();
      final theirs = Directory(p.join(base, 'kryfo-$tag-qq11QQ'))..createSync();
      final another = Directory(
        p.join(base, 'kryfo-${runtimeTag('/elsewhere')}-ab12CD'),
      )..createSync();
      final fixed = Directory(p.join(base, 'kryfo-$tag'))..createSync();
      sweepOldRuntimeDirs(
        keep.path,
        env: {'XDG_RUNTIME_DIR': base},
        uid: uid,
        root: root.path,
        owner: (d) => d == theirs.path ? uid + 1 : uid,
      );
      expect(stale.existsSync(), isFalse);
      expect(older.existsSync(), isFalse);
      expect(keep.existsSync(), isTrue);
      expect(theirs.existsSync(), isTrue);
      expect(another.existsSync(), isTrue);
      expect(fixed.existsSync(), isTrue);
    },
  );
}
