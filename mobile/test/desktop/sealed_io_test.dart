// SPDX-License-Identifier: GPL-3.0-or-later
// the seam every desktop reader goes through: dart's own file api reads the
// plaintext, the disk holds none
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:kryfo/desktop/sealed_io.dart';
import 'package:path/path.dart' as p;

import '../host_engine.dart';
import 'sealed_file_test.dart' show ToyCrypto;

Uint8List _k(int b) => Uint8List.fromList(List.filled(32, b));

void main() {
  final engine = loadHostEngine();
  late Directory root;
  late SealedIO io;
  late String docs, support;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sio');
    docs = p.join(root.path, 'docs');
    support = p.join(root.path, 'support');
    for (final d in ['media', 'media_k2', 'wallpapers', 'tmp']) {
      Directory(p.join(docs, d)).createSync(recursive: true);
    }
    Directory(p.join(support, 'translate')).createSync(recursive: true);
    final areas = SealedAreas(docs: docs, support: support)
      ..filesKey = _k(9)
      ..containerKeys[''] = _k(1)
      ..containerKeys['_k2'] = _k(2);
    io = SealedIO(areas, ToyCrypto());
  });
  tearDown(() => root.deleteSync(recursive: true));

  T sealed<T>(T Function() f) => IOOverrides.runWithIOOverrides(f, io);
  Uint8List rawBytes(String path) => io.rawFile(path).readAsBytesSync();
  bool holds(Uint8List raw, String text) =>
      latin1.decode(raw, allowInvalid: true).contains(text);

  test('what is written reads back, and the disk holds none of it', () async {
    final path = p.join(docs, 'media', 'in_ab.jpg');
    await sealed(() async {
      await File(path).writeAsBytes(utf8.encode('meet at the north gate'));
      expect(await File(path).readAsString(), 'meet at the north gate');
      expect(await File(path).length(), 22);
      expect(File(path), isA<SealedFile>());
    });
    expect(holds(rawBytes(path), 'north gate'), isFalse);
    expect(isSealedHead(rawBytes(path)), isTrue);
  });

  test('only kryfo\'s places are sealed', () {
    final a = io.areas;
    expect(a.areaOf(p.join(docs, 'media', 'x')), '');
    expect(a.areaOf(p.join(docs, 'wallpapers_k3', 'x')), '_k3');
    expect(a.areaOf(p.join(support, 'backup_stage', 'media', 'x')), '*');
    // sqlite's files, the engine's, the models and the folders themselves
    expect(a.areaOf(p.join(docs, 'halo.db')), isNull);
    expect(a.areaOf(p.join(support, 'backup_stage', 'halo.db-wal')), isNull);
    expect(a.areaOf(p.join(docs, 'onion.key')), isNull);
    expect(a.areaOf(p.join(docs, 'tor', 'state')), isNull);
    expect(a.areaOf(p.join(docs, 'media')), isNull);
    expect(a.areaOf(p.join(support, 'translate', 'm.bin')), isNull);
    expect(a.areaOf(p.join(root.path, 'elsewhere')), isNull);
    expect(a.areaOf(p.join(docs, 'media_v', 'x')), isNull);
  });

  test('a locked container reads nothing', () {
    io.areas.containerKeys.remove('_k2');
    sealed(() {
      expect(
        () => File(p.join(docs, 'media_k2', 'x')).writeAsBytesSync([1]),
        throwsA(isA<SealedLocked>()),
      );
    });
  });

  test('a move in one container keeps the bytes, across them seals again', () {
    sealed(() {
      final a = p.join(docs, 'media', 'a');
      File(a).writeAsBytesSync(List.generate(100000, (i) => i & 255));
      final before = rawBytes(a);
      final b = p.join(docs, 'wallpapers', 'b');
      File(a).renameSync(b);
      expect(rawBytes(b), before);
      final c = p.join(docs, 'media_k2', 'c');
      File(b).renameSync(c);
      expect(File(b).existsSync(), isFalse);
      expect(rawBytes(c), isNot(before));
      expect(File(c).readAsBytesSync(), List.generate(100000, (i) => i & 255));
    });
  });

  test('a file brought in from outside is sealed, and its plain copy goes', () {
    final outside = p.join(docs, 'tmp', 'vn.wav');
    File(outside).writeAsStringSync('RIFF the voice');
    sealed(() {
      final into = p.join(docs, 'media', 'vn.wav');
      File(outside).renameSync(into);
      expect(File(outside).existsSync(), isFalse);
      expect(File(into).readAsStringSync(), 'RIFF the voice');
    });
    expect(holds(rawBytes(p.join(docs, 'media', 'vn.wav')), 'voice'), isFalse);
  });

  test('a listing hands files that read through the seam', () async {
    await sealed(() async {
      File(p.join(docs, 'media', 'l')).writeAsStringSync('listed');
      final found = await Directory(p.join(docs, 'media')).list().toList();
      final f = found.whereType<File>().single;
      expect(f, isA<SealedFile>());
      expect(f.readAsStringSync(), 'listed');
      expect(
        Directory(p.join(docs, 'media')).listSync().single,
        isA<SealedFile>(),
      );
    });
  });

  test('random access through open and setPosition', () async {
    await sealed(() async {
      final path = p.join(docs, 'media', 'r');
      final f = await File(path).open(mode: FileMode.write);
      await f.writeFrom(List.filled(200000, 1));
      await f.setPosition(4);
      await f.writeFrom([9, 9]);
      await f.close();
      final g = File(path).openSync(mode: FileMode.append);
      expect(g.positionSync(), 200000);
      g.writeFromSync([7]);
      g.closeSync();
      final r = File(path).openSync();
      r.setPositionSync(3);
      expect(r.readSync(4), [1, 9, 9, 1]);
      r.setPositionSync(200000);
      expect(r.readSync(4), [7]);
      r.closeSync();
    });
  });

  test('the shred sees the disk as it is', () {
    final path = p.join(docs, 'media', 's');
    sealed(() => File(path).writeAsStringSync('x'));
    final raw = IOOverrides.runWithIOOverrides(
      () => rawFileAccess(() => File(path).lengthSync()),
      io,
    );
    expect(raw, storedLength(1));
  });

  test('a plain file left in a sealed place still reads', () {
    final path = p.join(docs, 'media', 'old.jpg');
    io.rawFile(path).writeAsStringSync('plain before');
    sealed(() => expect(File(path).readAsStringSync(), 'plain before'));
  });

  test('an isolate reads through the same seal', () async {
    final path = p.join(docs, 'media', 'iso');
    await sealed(() async {
      File(path).writeAsStringSync('from the main one');
      IOOverrides.global = io;
      try {
        final got = await runSealed(() => File(path).readAsStringSync());
        expect(got, 'from the main one');
      } finally {
        IOOverrides.global = null;
      }
    });
  });

  test(
    '50 MB streams through without its whole in memory',
    () async {
      io = SealedIO(io.areas, const EngineChunkCrypto());
      final a = p.join(docs, 'media', 'big');
      final b = p.join(docs, 'media_k2', 'big');
      final block = Uint8List.fromList(
        List.generate(1 << 20, (i) => i * 7 & 255),
      );
      await sealed(() async {
        final before = ProcessInfo.currentRss;
        final sink = File(a).openWrite();
        for (var i = 0; i < 50; i++) {
          sink.add(block);
          await Future<void>.delayed(Duration.zero);
        }
        await sink.close();
        expect(File(a).lengthSync(), 50 << 20);
        await File(a).openRead().pipe(File(b).openWrite());
        final out = _Digests();
        final hs = sha256.startChunkedConversion(out);
        for (var i = 0; i < 50; i++) {
          hs.add(block);
        }
        hs.close();
        final want = out.got.single;
        final got = await sha256.bind(File(b).openRead()).first;
        expect(got, want);
        // a whole copy would add 50 MB or more at once
        expect(ProcessInfo.currentRss - before, lessThan(40 << 20));
      });
      expect(io.rawFile(b).lengthSync(), storedLength(50 << 20));
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: engine ? false : 'no host engine',
  );

  testWidgets('a picture reads through the seam', (t) async {
    final path = p.join(docs, 'media', 'px.png');
    // a 1x1 png
    final png = base64.decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    await t.runAsync(() async {
      sealed(() => File(path).writeAsBytesSync(png));
    });
    expect(isSealedHead(rawBytes(path)), isTrue);
    // FileImage reads a File of another type with readAsBytes, never by
    // its path in the engine: the seam's file is one of those
    final f = sealed(() => File(path));
    expect(f.runtimeType == File, isFalse);
    expect(FileImage(f).file, same(f));
    await t.runAsync(() async {
      final codec = await ui.instantiateImageCodec(await f.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1);
    });
  });
}

class _Digests implements Sink<Digest> {
  final got = <Digest>[];
  @override
  void add(Digest d) => got.add(d);
  @override
  void close() {}
}
