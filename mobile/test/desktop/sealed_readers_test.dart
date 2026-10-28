// SPDX-License-Identifier: GPL-3.0-or-later
// every reader of the desktop's files, through the seal: backups, the
// shred, saves, code outside dart, the start's migration, the numbered
// containers, the onion key
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup_stream.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/desktop/desktop_save.dart';
import 'package:kryfo/desktop/desktop_vault.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:kryfo/desktop/sealed_native.dart';
import 'package:kryfo/desktop/sealed_setup.dart';
import 'package:kryfo/shred.dart';
import 'package:path/path.dart' as p;

import 'desktop_start_test.dart' show ToyVaultCrypto;
import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

// the backups' cipher, plain enough for a test
class _Backup implements ChunkCipher {
  @override
  Uint8List seal(int index, int type, Uint8List plain) =>
      Uint8List.fromList([index & 255, type, ...plain]);
  @override
  Uint8List? open(int index, int type, Uint8List sealed) =>
      sealed[0] == (index & 255) && sealed[1] == type
      ? Uint8List.fromList(sealed.sublist(2))
      : null;
}

void main() {
  late Directory root;
  late String docs, support;
  late SealedIO io;

  setUp(() {
    root = Directory.systemTemp.createTempSync('readers');
    docs = p.join(root.path, 'docs');
    support = p.join(root.path, 'support');
    for (final d in ['media', 'media_k2', 'wallpapers']) {
      Directory(p.join(docs, d)).createSync(recursive: true);
    }
    Directory(support).createSync();
    final areas = SealedAreas(docs: docs, support: support)
      ..filesKey = _k(9)
      ..containerKeys[''] = _k(1)
      ..containerKeys['_k2'] = _k(2);
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

  test('a backup carries the plaintext and brings it back sealed', () async {
    final photo = p.join(docs, 'media', 'in_1.jpg');
    final out = p.join(support, 'backup_stage', 'k.kryfo');
    Directory(p.dirname(out)).createSync(recursive: true);
    await sealed(() async {
      File(photo).writeAsStringSync('the photo of the gate');
      final size = await File(photo).length();
      await writeBackup(
        outPath: out,
        salt: Uint8List(16),
        cipher: _Backup(),
        manifest: {
          'files': [BackupFileEntry('media/in_1.jpg', size).toJson()],
        },
        root: docs,
      );
      final back = p.join(docs, 'media_k2', 'in_1.jpg');
      await extractBackup(out, _Backup(), want: (_) => back);
      expect(File(back).readAsStringSync(), 'the photo of the gate');
    });
    // the backup at rest and the photo restored: neither in the clear
    expect(holds(raw(out), 'gate'), isFalse);
    expect(holds(raw(p.join(docs, 'media_k2', 'in_1.jpg')), 'gate'), isFalse);
  });

  test('the shred overwrites the sealed bytes where they lie', () async {
    final path = p.join(docs, 'media', 'sh');
    sealed(() => File(path).writeAsBytesSync(List.filled(70000, 3)));
    final stored = raw(path).length;
    final seen = <int>[];
    await sealed(() => shredFile(path, probe: seen.add));
    expect(seen.last, stored);
    expect(io.rawFile(path).existsSync(), isFalse);
  });

  test('a save hands out the plaintext', () async {
    final from = p.join(docs, 'media', 'in_2.pdf');
    final to = p.join(root.path, 'out.pdf');
    await sealed(() async {
      File(from).writeAsStringSync('%PDF the contract');
      final r = await DesktopSave(pick: (_) async => to).save(from, 'c.pdf');
      expect(r['state'], 'saved');
    });
    expect(File(to).readAsStringSync(), '%PDF the contract');
  });

  test('code outside dart reads and writes through memory', () async {
    final note = p.join(docs, 'media', 'vn.ogg');
    final wav = p.join(docs, 'media', 'vn.wav');
    await sealed(() async {
      File(note).writeAsStringSync('OggS the note');
      final seen = await nativeFilesSealed<String>(io.areas, [note], [wav], (
        i,
        o,
      ) async {
        expect(i.single, startsWith('/proc/self/fd/'));
        expect(o.single, startsWith('/proc/self/fd/'));
        // as the engine would: by path, past dart's seam
        final got = rawFileAccess(() => File(i.single).readAsStringSync());
        rawFileAccess(() => File(o.single).writeAsStringSync('RIFF out'));
        return got;
      });
      expect(seen, 'OggS the note');
      expect(File(wav).readAsStringSync(), 'RIFF out');
    });
    expect(holds(raw(wav), 'RIFF out'), isFalse);
    // a plain path is passed as it is
    final plainIn = p.join(root.path, 'take.wav');
    File(plainIn).writeAsStringSync('x');
    await sealed(
      () =>
          nativeFilesSealed<void>(io.areas, [plainIn], const [], (i, _) async {
            expect(i.single, plainIn);
          }),
    );
  });

  test('a memory copy is in memory, and gone after', () {
    final path = p.join(docs, 'media', 'm');
    sealed(() {
      File(path).writeAsStringSync('only in memory');
      final m = memCopyOf(path);
      final where = Link(m.path).targetSync();
      expect(where, startsWith('/memfd:'));
      expect(
        rawFileAccess(() => File(m.path).readAsStringSync()),
        'only in memory',
      );
      m.close();
      expect(() => Link(m.path).targetSync(), throwsA(anything));
    });
  });

  test('the start seals what a version before left plain', () {
    final a = p.join(docs, 'media', 'old.jpg');
    final b = p.join(docs, 'media', 'sub', 'old2.bin');
    io.rawFile(a).writeAsStringSync('an old photo');
    io.rawFile(b)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.generate(150000, (i) => i & 255));
    final s = sealed(() => sealPlainUnder(p.join(docs, 'media')));
    expect(s.sealed, 2);
    expect(isSealedHead(raw(a)), isTrue);
    expect(holds(raw(a), 'old photo'), isFalse);
    sealed(() {
      expect(File(a).readAsStringSync(), 'an old photo');
      expect(File(b).readAsBytesSync(), List.generate(150000, (i) => i & 255));
    });
    // a second run finds nothing left
    expect(sealed(() => sealPlainUnder(p.join(docs, 'media'))).sealed, 0);
  });

  test('a migration cut short is picked up', () {
    final a = p.join(docs, 'media', 'cut.jpg');
    sealed(() {
      // a whole sealed copy beside a zeroed original: the copy wins
      File('$a.sealing').writeAsStringSync('the cut one');
      io.rawFile(a).writeAsBytesSync(List.filled(11, 0));
      final s = sealPlainUnder(p.join(docs, 'media'));
      expect(s.resumed, 1);
      expect(File(a).readAsStringSync(), 'the cut one');
      // a broken copy goes, the plain original is sealed again
      io.rawFile('$a.sealing').writeAsStringSync('broken');
      io.rawFile(a).writeAsStringSync('plain again');
      sealPlainUnder(p.join(docs, 'media'));
      expect(File('$a.sealing').existsSync(), isFalse);
      expect(File(a).readAsStringSync(), 'plain again');
    });
  });

  test('every install has the same numbered containers', () {
    makePlaceholders(docs, random: Random(3));
    final names = io
        .rawDirectory(docs)
        .listSync()
        .map((e) => p.basename(e.path))
        .toSet();
    for (final (db, folders) in placeholderSets) {
      expect(names, contains(db));
      expect(names, containsAll(folders));
      expect(File(p.join(docs, db)).lengthSync() % 4096, 0);
    }
    // one that is there is never replaced
    final real = File(p.join(docs, 'k2.db'))..writeAsStringSync('real');
    makePlaceholders(docs);
    expect(real.readAsStringSync(), 'real');
  });

  test('two handles keep a container open until both close', () {
    final keys = ContainerKeys(io.areas);
    io.areas.containerKeys.clear();
    keys.opened('3', '_k3', 'db key');
    keys.opened('3', '_k3', 'db key');
    expect(io.areas.containerKeys['_k3'], mediaKeyOf('db key', '3'));
    keys.closed('3');
    expect(io.areas.containerKeys, contains('_k3'));
    keys.closed('3');
    expect(io.areas.containerKeys, isNot(contains('_k3')));
    expect(mediaKeyOf('db key', '3'), isNot(mediaKeyOf('db key', '4')));
  });

  test(
    'the onion key lives in the vault, the engine reads it from memory',
    () async {
      final run = p.join(root.path, 'run');
      Directory(run).createSync();
      final vault = DesktopVault(
        p.join(root.path, 'vault.kv'),
        crypto: ToyVaultCrypto(),
      );
      await vault.create('four random words here');
      final key = List.generate(64, (i) => i);
      io.rawFile(p.join(docs, 'onion.key')).writeAsBytesSync(key);
      final link = OnionKeyLink(docs: docs, runtime: run, vault: vault);
      await sealed(() => link.place());
      expect(
        FileSystemEntity.typeSync(
          p.join(docs, 'onion.key'),
          followLinks: false,
        ),
        FileSystemEntityType.link,
      );
      expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), key);
      expect(base64.decode(vault.read(kOnionEntry)!), key);
      // the engine makes a new one: it reaches the vault
      final fresh = List.generate(64, (i) => 255 - i);
      File(p.join(run, 'onion.key')).writeAsBytesSync(fresh);
      await sealed(() => link.pull());
      expect(base64.decode(vault.read(kOnionEntry)!), fresh);
      // a new boot: memory is empty, the vault fills it
      File(p.join(run, 'onion.key')).deleteSync();
      await sealed(() => link.place());
      expect(File(p.join(docs, 'onion.key')).readAsBytesSync(), fresh);
      link.destroy();
      expect(File(p.join(run, 'onion.key')).existsSync(), isFalse);
    },
  );
}
