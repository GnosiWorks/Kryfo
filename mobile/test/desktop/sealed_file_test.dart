// SPDX-License-Identifier: GPL-3.0-or-later
// a sealed file read and written at any place, against a plain mirror
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/sealed_file.dart';
import 'package:kryfo/desktop/sealed_format.dart';
import 'package:path/path.dart' as p;

import '../host_engine.dart';

/// a keyed stream and a tag: enough to tell keys and bytes apart
class ToyCrypto implements ChunkCrypto {
  List<int> _stream(Uint8List k, int n) {
    final out = <int>[];
    var i = 0;
    while (out.length < n) {
      out.addAll(Hmac(sha256, k).convert([i >> 8, i & 255]).bytes);
      i++;
    }
    return out.sublist(0, n);
  }

  @override
  Uint8List seal(Uint8List key, Uint8List plain) {
    final s = _stream(key, plain.length);
    final c = [for (var i = 0; i < plain.length; i++) plain[i] ^ s[i]];
    return Uint8List.fromList([
      ...c,
      ...Hmac(sha256, key).convert(c).bytes.take(16),
    ]);
  }

  @override
  Uint8List? open(Uint8List key, Uint8List sealed) {
    final c = sealed.sublist(0, sealed.length - 16);
    final t = Hmac(sha256, key).convert(c).bytes.take(16).toList();
    for (var i = 0; i < 16; i++) {
      if (t[i] != sealed[c.length + i]) return null;
    }
    final s = _stream(key, c.length);
    return Uint8List.fromList([for (var i = 0; i < c.length; i++) c[i] ^ s[i]]);
  }
}

final _key = Uint8List.fromList(List.generate(32, (i) => i));

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('sealed'));
  tearDown(() => dir.deleteSync(recursive: true));

  SealedRandomAccessFile open(
    String path,
    ChunkCrypto c, {
    bool fresh = false,
  }) => SealedRandomAccessFile.over(
    File(path).openSync(mode: fresh ? FileMode.write : FileMode.append),
    path,
    _key,
    c,
    writable: true,
    truncate: fresh,
  );

  for (final (name, crypto) in [
    ('toy', ToyCrypto() as ChunkCrypto),
    ('engine', const EngineChunkCrypto() as ChunkCrypto),
  ]) {
    group(name, () {
      final skip = name == 'engine' && !loadHostEngine()
          ? 'no host engine'
          : false;

      test('random writes and reads match a plain mirror', () {
        final path = p.join(dir.path, 'f');
        final rnd = Random(1);
        var mirror = Uint8List(0);
        var f = open(path, crypto, fresh: true);
        for (var step = 0; step < 300; step++) {
          final at = rnd.nextInt(mirror.length + chunkPlain * 2 + 1);
          switch (rnd.nextInt(4)) {
            case 0 || 1:
              final n = rnd.nextInt(chunkPlain * 2);
              final data = Uint8List.fromList(
                List.generate(n, (_) => rnd.nextInt(256)),
              );
              f.setPositionSync(at);
              f.writeFromSync(data);
              if (at + n > mirror.length) {
                mirror = Uint8List(at + n)..setAll(0, mirror);
              }
              mirror.setAll(at, data);
            case 2:
              final n = rnd.nextInt(chunkPlain * 2);
              f.setPositionSync(at);
              final got = f.readSync(n);
              final want = at >= mirror.length
                  ? <int>[]
                  : mirror.sublist(at, min(at + n, mirror.length));
              expect(got, want, reason: 'step $step');
            default:
              if (rnd.nextInt(10) == 0) {
                final to = rnd.nextInt(mirror.length + 1);
                f.truncateSync(to);
                mirror = Uint8List.fromList(mirror.sublist(0, to));
              } else {
                f.closeSync();
                f = open(path, crypto);
              }
          }
          expect(f.lengthSync(), mirror.length, reason: 'step $step');
        }
        f.closeSync();
        expect(File(path).lengthSync(), storedLength(mirror.length));
        final g = open(path, crypto);
        expect(g.readSync(mirror.length + 10), mirror);
        g.closeSync();
      }, skip: skip);

      test('a cut, a swapped or a changed chunk never opens', () {
        final path = p.join(dir.path, 'g');
        final f = open(path, crypto, fresh: true)
          ..writeFromSync(List.generate(chunkPlain * 3 + 5, (i) => i & 255))
          ..closeSync();
        expect(f.path, path);
        final raw = File(path).readAsBytesSync();
        // the last chunk cut off: the one before was sealed in the middle
        File(
          path,
        ).writeAsBytesSync(raw.sublist(0, sealedHead + chunkStored * 3));
        expect(
          () => open(path, crypto).readSync(10),
          throwsA(isA<SealedDamaged>()),
        );
        // two chunks swapped
        final sw = Uint8List.fromList(raw);
        sw.setRange(
          sealedHead,
          sealedHead + chunkStored,
          raw,
          sealedHead + chunkStored,
        );
        sw.setRange(
          sealedHead + chunkStored,
          sealedHead + 2 * chunkStored,
          raw,
          sealedHead,
        );
        File(path).writeAsBytesSync(sw);
        expect(
          () => open(path, crypto).readSync(10),
          throwsA(isA<SealedDamaged>()),
        );
        // one byte changed
        final ch = Uint8List.fromList(raw)..[sealedHead + 40] ^= 1;
        File(path).writeAsBytesSync(ch);
        expect(
          () => open(path, crypto).readSync(10),
          throwsA(isA<SealedDamaged>()),
        );
        // and the plain bytes appear nowhere
        File(path).writeAsBytesSync(raw);
        expect(open(path, crypto).readSync(4), [0, 1, 2, 3]);
      }, skip: skip);

      test('an empty file and an exact chunk', () {
        final path = p.join(dir.path, 'h');
        open(path, crypto, fresh: true).closeSync();
        expect(File(path).lengthSync(), storedLength(0));
        expect(open(path, crypto).readSync(5), isEmpty);
        open(path, crypto, fresh: true)
          ..writeFromSync(Uint8List(chunkPlain))
          ..closeSync();
        final g = open(path, crypto);
        expect(g.lengthSync(), chunkPlain);
        g
          ..setPositionSync(chunkPlain)
          ..writeFromSync([7])
          ..closeSync();
        final h = open(path, crypto);
        expect(h.lengthSync(), chunkPlain + 1);
        h.setPositionSync(chunkPlain);
        expect(h.readSync(5), [7]);
      }, skip: skip);
    });
  }

  test('the sizes on disk and in plaintext agree', () {
    for (final n in [
      0,
      1,
      chunkPlain - 1,
      chunkPlain,
      chunkPlain + 1,
      5 * chunkPlain + 9,
    ]) {
      expect(plainLength(storedLength(n)), n, reason: '$n');
    }
    expect(plainLength(sealedHead + 10), isNull);
  });
}
