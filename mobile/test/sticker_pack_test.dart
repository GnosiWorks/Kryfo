// SPDX-License-Identifier: GPL-3.0-or-later
// the committed pack: what it holds, how big each sticker is, that it was
// built from the art and anim.txt as they are now, and that its display
// lists and tracks hold together.
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_player.dart';

import 'sticker_test_util.dart';

const _limit = 64 * 1024;

void main() {
  final bytes = File(packFile).readAsBytesSync();
  final pack = loadPack();

  test('the pack names 29 stickers, each with an emoji', () {
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'KSTK');
    expect(bytes[4], 1);
    expect(pack.name, 'fokia');
    expect(pack.version, 1);
    expect(pack.ids, [for (var i = 1; i <= 29; i++) i]);
    for (final id in pack.ids) {
      final s = pack.sticker(id)!;
      expect(s.id, id);
      expect(s.since, 1);
      expect(s.emoji.runes, isNotEmpty, reason: 'sticker $id');
      expect(s.emoji.contains(RegExp(r'[a-zA-Z0-9]')), false);
    }
  });

  test('every sticker is under 64 kb', () {
    var biggest = (0, 0);
    final over = <String>[];
    for (final id in pack.ids) {
      final n = pack.blob(id)!.lengthInBytes;
      if (n > biggest.$2) biggest = (id, n);
      if (n > _limit) over.add('sticker $id is $n bytes');
    }
    // ignore: avoid_print
    print('biggest sticker: ${biggest.$1} at ${biggest.$2} bytes');
    expect(over, isEmpty);
  });

  test('the pack was built from the art and anim.txt as they are', () {
    final svgs =
        Directory('$artDir/svg')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.svg'))
            .toList()
          ..sort(
            (a, b) =>
                a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
          );
    expect(svgs, hasLength(29));
    final all = BytesBuilder(copy: false);
    for (final f in svgs) {
      all.add(f.readAsBytesSync());
    }
    all.add(File('$artDir/anim.txt').readAsBytesSync());
    final hash = sha256.convert(all.takeBytes()).bytes.sublist(0, 16);
    expect(
      pack.sourceHash,
      hash,
      reason: 'the art or anim.txt changed: run tool/pack_stickers.py',
    );
  });

  test('display lists balance and every index is in range', () {
    // the reader refuses anything else; every sticker reads
    for (final id in pack.ids) {
      expect(pack.sticker(id), isNotNull, reason: 'sticker $id');
    }
  });

  test('every sticker draws its white outline first, under the art', () {
    for (final id in pack.ids) {
      final s = pack.sticker(id)!;
      final first = <int>[];
      for (var i = 0; i < s.ops.length && first.length < 2; i++) {
        if (s.ops[i] >> 13 == opDraw) first.add(s.ops[++i]);
      }
      final a = s.paints[first[0]], b = s.paints[first[1]];
      // a soft rim at half alpha, then the outline itself
      expect(a.color.toARGB32() & 0xFFFFFF, 0xFFFFFF, reason: 'sticker $id');
      expect(s.paintAlpha[first[0]], 128, reason: 'sticker $id');
      expect(b.color.toARGB32(), 0xFFFFFFFF, reason: 'sticker $id');
    }
  });

  test('tracks start and end at rest, inside a 2 to 3 second loop', () {
    const rest = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0];
    for (final id in pack.ids) {
      final s = pack.sticker(id)!;
      if (s.tracks.isEmpty) {
        expect(s.loopMs, 0, reason: 'a still has no loop');
        continue;
      }
      expect(s.loopMs, inInclusiveRange(2000, 3000), reason: 'sticker $id');
      for (final k in s.tracks) {
        expect(k.times.first, 0, reason: 'sticker $id');
        expect(k.times.last, lessThanOrEqualTo(s.loopMs));
        expect(k.values.first, rest[k.prop], reason: 'sticker $id');
        expect(k.values.last, rest[k.prop], reason: 'sticker $id');
        for (var i = 1; i < k.times.length; i++) {
          expect(k.times[i], greaterThan(k.times[i - 1]));
        }
      }
    }
  });

  test('lids are hidden at rest and only move to blink', () {
    for (final id in pack.playable) {
      final s = pack.sticker(id)!;
      final hidden = [
        for (var n = 0; n < s.nodeCount; n++)
          if (s.hiddenAtRest(n)) n,
      ];
      for (final n in hidden) {
        final props = {
          for (final k in s.tracks)
            if (k.node == n) k.prop,
        };
        expect(props, {propY}, reason: 'sticker $id node $n');
      }
      // hi blinks lid-less eyes: two lids made each; encrypted lowers the
      // art's own lids and makes the two lower ones
      if (id == 1) expect(hidden, hasLength(4));
      if (id == 17) expect(hidden, hasLength(2));
      if (id == 2 || id == 4 || id == 19) expect(hidden, isEmpty);
    }
  });

  test('a still has no nodes to walk', () {
    for (final id in pack.ids) {
      final s = pack.sticker(id)!;
      final v = evaluateSticker(s, 0);
      for (var n = 0; n < s.nodeCount; n++) {
        expect(nodeAtRest(v, n), true, reason: 'sticker $id node $n');
      }
    }
  });

  test('a damaged pack is refused, not half read', () {
    final cut = Uint8List.fromList(bytes.sublist(0, 40));
    expect(
      () => StickerPack.parse(ByteData.sublistView(cut)),
      throwsA(isA<StickerFormatError>()),
    );
    final bad = Uint8List.fromList(bytes)..[0] = 0x58;
    expect(
      () => StickerPack.parse(ByteData.sublistView(bad)),
      throwsA(isA<StickerFormatError>()),
    );
  });

  test('a damaged sticker reads as missing, and the rest still read', () {
    final b = Uint8List.fromList(bytes);
    final d = ByteData.sublistView(b);
    // the index: after the header, the name and the palette
    var at = 24;
    at += 1 + b[at];
    at += 1 + b[at] * 4;
    expect(d.getUint16(at, Endian.little), 29);
    // sticker 1's blob cut to 12 bytes
    expect(d.getUint16(at + 2, Endian.little), 1);
    d.setUint32(at + 2 + 6, 12, Endian.little);
    final p = StickerPack.parse(d);
    expect(p.sticker(1), isNull);
    expect(p.sticker(2), isNotNull);
  });
}
