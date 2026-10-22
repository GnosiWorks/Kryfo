// a heic or avif keeps the items its picture is drawn from, byte for byte
// where they were, and loses every other item with its bytes. the meta box
// is written again at its old size, so nothing after it moves.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/heif_clean.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/heif_items.dart';
import 'package:kryfo/meta/iso.dart' show isoBoxes;
import 'package:kryfo/meta/meta_reader.dart';

import 'meta_fixtures.dart';

const _pic = HeifPart(1, 'hvc1', [1, 2, 3, 4, 5, 6, 7, 8]);

MetaReport _read(Uint8List b) => readMeta(MemorySource(b));

HeifMeta _meta(Uint8List b) {
  final s = MemorySource(b);
  final top = isoBoxes(s, 0, b.length, [0]);
  return readHeifMeta(s, top.firstWhere((x) => x.type == 'meta'), [0]);
}

// the bytes of [id] in [b]
List<int> _bytes(Uint8List b, int id) {
  final m = _meta(b);
  return [for (final (x, y) in m.fileRanges(id)!) ...b.sublist(x, y)];
}

bool _has(Uint8List b, String s) => latin1.decode(b).contains(s);

void main() {
  test('only the picture is left, and nothing moved', () {
    final src = heifOf(
      [
        _pic,
        HeifPart(2, 'Exif', [...be32(0), ...t('MM GPS 37.98N')]),
        HeifPart(
          3,
          'mime',
          t('<x:xmpmeta>Pixel 8</x:xmpmeta>'),
          mime: 'application/rdf+xml',
        ),
        const HeifPart(4, 'hvc1', [9, 9, 9]),
        const HeifPart(5, 'hvc1', [
          8,
          8,
        ], aux: 'urn:com:apple:photo:2018:aux:depth'),
        const HeifPart(6, 'hvc1', [
          7,
          7,
        ], aux: 'urn:com:apple:photo:2019:aux:portraiteffectsmatte'),
        const HeifPart(7, 'hvc1', [6, 6, 6, 6]),
      ],
      refs: [
        ('cdsc', 2, [1]),
        ('cdsc', 3, [1]),
        ('thmb', 4, [1]),
        ('auxl', 5, [1]),
        ('auxl', 6, [1]),
      ],
    );
    final before = _read(src);
    expect(before.smallCopies, 1);
    expect(before.depthMap, true);
    expect(before.portraitMatte, true);
    expect(before.extraPictures, 1);

    final out = cleanHeif(src)!;
    expect(out.length, src.length);
    expect(_read(out).status, MetaStatus.nothing);
    expect(_bytes(out, 1), _pic.bytes);
    // the picture sits where it sat
    final at = _meta(src).fileRanges(1)!.first.$1;
    expect(_meta(out).fileRanges(1)!.first.$1, at);
    expect(_meta(out).items.keys, [1]);
    expect(_has(out, 'GPS'), false);
    expect(_has(out, 'Pixel 8'), false);
    expect(_has(out, 'depth'), false);
    // the depth map, matte, thumbnail and second picture bytes are zero
    final mdat = latin1.decode(out).indexOf('mdat') + 4;
    expect(out.sublist(mdat + 8).every((x) => x == 0), true);
  });

  test('an alpha plane stays, its property numbered anew', () {
    final src = heifOf(
      [
        _pic,
        const HeifPart(2, 'av01', [
          5,
          6,
        ], aux: 'urn:com:apple:photo:2018:aux:depth'),
        const HeifPart(3, 'av01', [
          7,
          8,
        ], aux: 'urn:mpeg:mpegB:cicp:systems:auxiliary:alpha'),
      ],
      refs: [
        ('auxl', 2, [1]),
        ('auxl', 3, [1]),
      ],
      brand: 'avif',
    );
    final out = cleanHeif(src)!;
    final m = _meta(out);
    expect(m.items.keys.toSet(), {1, 3});
    expect(m.props.length, 1);
    expect(
      m.auxType(MemorySource(out), 3),
      'urn:mpeg:mpegB:cicp:systems:auxiliary:alpha',
    );
    expect(_bytes(out, 3), [7, 8]);
    expect(_read(out).status, MetaStatus.nothing);
  });

  test('a grid keeps its tiles', () {
    final src = heifOf(
      [
        const HeifPart(1, 'grid', [0, 0, 0, 0, 0, 1, 0, 1]),
        const HeifPart(2, 'hvc1', [1, 1, 1]),
        const HeifPart(3, 'hvc1', [2, 2, 2]),
        const HeifPart(4, 'hvc1', [3, 3]),
      ],
      refs: [
        ('dimg', 1, [2, 3]),
        ('thmb', 4, [1]),
      ],
    );
    final out = cleanHeif(src)!;
    expect(_meta(out).items.keys.toSet(), {1, 2, 3});
    expect(_meta(out).refsOf('dimg').single.to, [2, 3]);
    expect(_bytes(out, 2), [1, 1, 1]);
    expect(_bytes(out, 3), [2, 2, 2]);
    expect(_read(out).status, MetaStatus.nothing);
  });

  test('an iso gain map goes, and the brand that promised it', () {
    final src = heifOf(
      [
        _pic,
        const HeifPart(2, 'av01', [5, 6]),
        const HeifPart(3, 'tmap', [0, 1, 2]),
      ],
      refs: [
        ('dimg', 3, [1, 2]),
      ],
      brand: 'avif',
      brands: ['tmap'],
    );
    expect(_read(src).hdrLayer, true);
    final out = cleanHeif(src)!;
    expect(_meta(out).items.keys, [1]);
    expect(_has(out.sublist(0, 32), 'tmap'), false);
    expect(_read(out).status, MetaStatus.nothing);
  });

  test('old bytes in mdat and a clip after it go', () {
    final src = heifOf(
      [_pic],
      mdatTail: t('old exif'),
      after: box('mpvd', [...box('ftyp', t('mp42')), ...t('a clip')]),
    );
    final out = cleanHeif(src)!;
    expect(_has(out, 'old exif'), false);
    expect(_has(out, 'mpvd'), false);
    expect(_bytes(out, 1), _pic.bytes);
    expect(_read(out).status, MetaStatus.nothing);
  });

  test('a clean file comes back as it was', () {
    final once = cleanHeif(heifOf([_pic]))!;
    expect(identical(cleanHeif(once), once), true);
  });

  test('what cannot be rebuilt is refused', () {
    // no primary item named
    final src = heifOf([_pic], primary: 9);
    expect(cleanHeif(src), null);
    // a compact heif
    final mini = Uint8List.fromList([
      ...box('ftyp', [...t('mif3'), ...be32(0), ...t('mif3')]),
      ...box('mini', List.filled(20, 1)),
    ]);
    expect(cleanHeif(mini), null);
    // cut short
    final whole = heifOf([_pic]);
    expect(cleanHeif(whole.sublist(0, whole.length - 3)), null);
  });

  test('a second meta box is found and goes', () {
    final src = heifOf([
      _pic,
    ], after: full('meta', 0, [...box('free', t('GPS 37.98N 23.72E'))]));
    expect(_read(src).status, MetaStatus.found);
    final out = cleanHeif(src)!;
    expect(_has(out, 'GPS'), false);
    expect(_read(out).status, MetaStatus.nothing);
    expect(_bytes(out, 1), _pic.bytes);
  });

  test('a description and dates on the picture go, its size stays', () {
    final ispe = full('ispe', 0, [...be32(64), ...be32(48)]);
    final src = heifOf([
      HeifPart(
        1,
        'hvc1',
        const [1, 2, 3, 4],
        props: [
          (ispe, false),
          (
            full('udes', 0, [...t('en'), 0, ...t('Our street'), 0, 0, 0]),
            false,
          ),
          (full('crtt', 0, be32(0x5f5e1000)), false),
          (full('mdft', 0, be32(0x5f5e1000)), false),
        ],
      ),
    ]);
    expect(_read(src).status, MetaStatus.found);
    final out = cleanHeif(src)!;
    expect(_has(out, 'Our street'), false);
    final m = _meta(out);
    expect(m.props.map((p) => p.type), ['ispe']);
    expect(m.assoc[1]!.single.index, 1);
    expect(_read(out).status, MetaStatus.nothing);
  });

  test(
    'an unknown property marked essential is not dropped, it is refused',
    () {
      final src = heifOf([
        HeifPart(
          1,
          'hvc1',
          const [1, 2, 3, 4],
          props: [
            (full('zzzz', 0, [1, 2, 3]), true),
          ],
        ),
      ]);
      expect(cleanHeif(src), null);
    },
  );

  test('a tone map primary leaves its base as the picture', () {
    final src = heifOf(
      [
        _pic,
        const HeifPart(2, 'av01', [5, 6]),
        const HeifPart(3, 'tmap', [0, 1, 2]),
      ],
      refs: [
        ('dimg', 3, [1, 2]),
      ],
      primary: 3,
      brand: 'avif',
      brands: ['tmap'],
    );
    expect(_read(src).hdrLayer, true);
    final out = cleanHeif(src)!;
    final m = _meta(out);
    expect(m.primary, 1);
    expect(m.items.keys, [1]);
    expect(_bytes(out, 1), _pic.bytes);
    expect(_read(out).status, MetaStatus.nothing);
  });
}
