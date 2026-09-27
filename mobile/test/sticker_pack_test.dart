// SPDX-License-Identifier: GPL-3.0-or-later
// the committed packs: what each holds, how big each sticker is, that it was
// built from the art and anim.txt as they are now, and that its display
// lists and tracks hold together.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_player.dart';
import 'package:kryfo/stickers/sticker_wire.dart' show isOneEmoji;

import 'sticker_test_util.dart';

const _limit = 64 * 1024;

void main() {
  group('fokia', () {
    _packTests(
      fokiaFiles,
      ids: [for (var i = 1; i <= 29; i++) i],
      title: 'Fokia',
      // no title in its anim.txt: the file from before titles
      format: 1,
    );
    _fokiaTests();
  });
  group('fokia remix', () {
    _packTests(
      remixFiles,
      ids: [for (var i = 30; i <= 47; i++) i],
      title: 'Fokia Remix',
      format: 2,
    );
  });

  test('the app ships both, fokia first', () {
    expect(kStickerAssets, [fokiaFiles.file, remixFiles.file]);
    final lib = useLibrary();
    expect([for (final p in lib.packs) p.name], ['fokia', 'fokiaremix']);
    expect(lib.sticker(const StickerRef('fokiaremix', 36))!.emoji, '🎻');
    expect(lib.sticker(const StickerRef('fokia', 36)), isNull);
    expect(lib.sticker(const StickerRef('fokiaremix', 1)), isNull);
    // no id is in both, so a recent or a quote never reads as the other
    final a = lib.pack('fokia')!.ids.toSet();
    expect(a.intersection(lib.pack('fokiaremix')!.ids.toSet()), isEmpty);
  });

  test('each pack loads once, and one that fails leaves the other', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final asked = <String>[];
    var broken = <String>{};
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      m,
    ) async {
      final key = utf8.decode(
        m!.buffer.asUint8List(m.offsetInBytes, m.lengthInBytes),
      );
      asked.add(key);
      if (broken.any(key.endsWith)) return null;
      return ByteData.sublistView(File(key).readAsBytesSync());
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );
    StickerLibrary.use(null);

    broken = {'fokia.kst', 'fokiaremix.kst'};
    await expectLater(
      StickerLibrary.load(),
      throwsA(isA<StickerFormatError>()),
    );
    expect(StickerLibrary.ready, isNull);

    broken = {'fokiaremix.kst'};
    final one = await StickerLibrary.load();
    expect([for (final p in one.packs) p.name], ['fokia']);
    expect(StickerLibrary.ready, one);

    // the next load tries the missing one again, and keeps the other
    broken = {};
    asked.clear();
    final both = await StickerLibrary.load();
    expect([for (final p in both.packs) p.name], ['fokia', 'fokiaremix']);
    expect(identical(both.pack('fokia'), one.pack('fokia')), true);
    expect(asked, [remixFiles.file]);
    asked.clear();
    expect(await StickerLibrary.load(), both);
    expect(asked, isEmpty);
  });
}

void _packTests(
  PackFiles f, {
  required List<int> ids,
  required String title,
  required int format,
}) {
  final bytes = File(f.file).readAsBytesSync();
  final pack = loadPack(f);

  test('the pack names ${ids.length} stickers, each with an emoji', () {
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'KSTK');
    expect(bytes[4], format);
    expect(pack.name, f.name);
    expect(pack.title, title);
    expect(pack.version, 1);
    expect(pack.ids, ids);
    for (final id in pack.ids) {
      final s = pack.sticker(id)!;
      expect(s.id, id);
      expect(s.since, 1);
      expect(s.emoji.runes, isNotEmpty, reason: 'sticker $id');
      expect(s.emoji.contains(RegExp(r'[a-zA-Z0-9]')), false);
      expect(isOneEmoji(s.emoji), true, reason: 'sticker $id');
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

  test('the pack matches the art and anim.txt', () {
    final svgs =
        Directory('${f.art}/svg')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.svg'))
            .toList()
          ..sort(
            (a, b) =>
                a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
          );
    expect(svgs, hasLength(ids.length));
    final all = BytesBuilder(copy: false);
    for (final svg in svgs) {
      all.add(svg.readAsBytesSync());
    }
    all.add(File('${f.art}/anim.txt').readAsBytesSync());
    final hash = sha256.convert(all.takeBytes()).bytes.sublist(0, 16);
    expect(
      pack.sourceHash,
      hash,
      reason: 'the art or anim.txt changed: run ${f.tool}',
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
        // alpha rests at 1, or at 0 on a part the svg hides
        final r = k.prop == propAlpha ? s.restAlpha[k.node] : rest[k.prop];
        expect(r, anyOf(0, 1), reason: 'sticker $id');
        expect(k.values.first, r, reason: 'sticker $id');
        expect(k.values.last, r, reason: 'sticker $id');
        for (var i = 1; i < k.times.length; i++) {
          expect(k.times[i], greaterThan(k.times[i - 1]));
        }
      }
    }
  });

  test('the picker offers what moves, or every still of a pack with none', () {
    final moving = pack.playable;
    expect(pack.offered, moving.isEmpty ? pack.ids : moving);
    expect(pack.offered, isNotEmpty);
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

  test('a damaged sticker reads as missing, and the rest still read', () {
    final b = Uint8List.fromList(bytes);
    final d = ByteData.sublistView(b);
    // the index: after the header, the name, the title and the palette
    var at = 24;
    at += 1 + b[at];
    if (format == 2) at += 1 + b[at];
    at += 1 + b[at] * 4;
    expect(d.getUint16(at, Endian.little), ids.length);
    // the first sticker's blob cut to 12 bytes
    expect(d.getUint16(at + 2, Endian.little), ids[0]);
    d.setUint32(at + 2 + 6, 12, Endian.little);
    final p = StickerPack.parse(d);
    expect(p.sticker(ids[0]), isNull);
    expect(p.sticker(ids[1]), isNotNull);
  });
}

// what only pack 1 has: its lids, and the damage tests on its bytes
void _fokiaTests() {
  final bytes = File(fokiaFiles.file).readAsBytesSync();
  final pack = loadPack();

  test('hi, encrypted and the shut-eyed ones have the lids they need', () {
    for (final id in pack.playable) {
      final s = pack.sticker(id)!;
      final hidden = [
        for (var n = 0; n < s.nodeCount; n++)
          if (s.hiddenAtRest(n)) n,
      ];
      // hi blinks lid-less eyes: two lids made each; encrypted lowers the
      // art's own lids and makes the two lower ones
      if (id == 1) expect(hidden, hasLength(4));
      if (id == 17) expect(hidden, hasLength(2));
      if (id == 2 || id == 4 || id == 19) expect(hidden, isEmpty);
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

  test('a pack from a newer format is refused', () {
    final b = Uint8List.fromList(bytes)..[4] = 3;
    expect(
      () => StickerPack.parse(ByteData.sublistView(b)),
      throwsA(isA<StickerFormatError>()),
    );
  });
}
