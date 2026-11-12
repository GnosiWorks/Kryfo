// a stranger's heic with tens of thousands of extents, boxes and items:
// every overlap and every reference is looked up by halves or in an index
// built once, so the clean and the read take moments, not minutes.
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/heif_clean.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/heif_items.dart';
import 'package:kryfo/meta/iso.dart' show firstOf, isoBoxes;
import 'package:kryfo/meta/meta_reader.dart';

import 'meta_fixtures.dart';

// about a second each alone; a quadratic walk at these sizes takes minutes,
// so the bound holds under a loaded full suite too
const _fast = Timeout(Duration(seconds: 30));

List<int> _head(String type, int body) => [...be32(8 + body), ...t(type)];

// a heic whose primary has n one byte extents two apart and whose exif
// item has m more; [before] boxes ahead of mdat, [after] behind it
Uint8List _heic(int n, int m, {int before = 0, int after = 0}) {
  final ftyp = box('ftyp', [
    ...t('heic'),
    ...be32(0),
    ...t('mif1'),
    ...t('heic'),
  ]);
  List<int> junk(int k) => [for (var i = 0; i < k; i++) ..._head('junk', 0)];
  List<int> metaFor(int body) {
    final loc = BytesBuilder(copy: false)
      ..add([1, 0, 0, 0, 0x44, 0x00, ...be16(2)])
      ..add([...be16(1), ...be16(0), ...be16(0), ...be16(n)]);
    for (var k = 0; k < n; k++) {
      loc.add([...be32(body + 2 * k), ...be32(1)]);
    }
    loc.add([...be16(2), ...be16(0), ...be16(0), ...be16(m)]);
    for (var k = 0; k < m; k++) {
      loc.add([...be32(body + 2 * n + 2 * k), ...be32(1)]);
    }
    final l = loc.toBytes();
    return full('meta', 0, [
      ...full('hdlr', 0, [...be32(0), ...t('pict'), ...List.filled(13, 0)]),
      ...full('pitm', 0, be16(1)),
      ...full('iinf', 0, [...be16(2), ...infe(1, 'hvc1'), ...infe(2, 'Exif')]),
      ..._head('iloc', l.length),
      ...l,
    ]);
  }

  final pads = junk(before);
  final body = ftyp.length + metaFor(0).length + pads.length + 8;
  final size = 2 * n + 2 * m;
  return (BytesBuilder(copy: false)
        ..add(ftyp)
        ..add(metaFor(body))
        ..add(pads)
        ..add(_head('mdat', size))
        ..add(Uint8List(size)..fillRange(0, size, 7))
        ..add(junk(after)))
      .toBytes();
}

Future<Uint8List?> _clean(Uint8List b) => Isolate.run(() => cleanHeif(b));

// the primary's bytes kept, every other mdat byte zeroed
void _picture(Uint8List out, int at, int n, int m) {
  for (var k = 0; k < 2 * n + 2 * m; k++) {
    final want = k < 2 * n && k.isEven ? 7 : 0;
    if (out[at + k] != want) fail('byte $k is ${out[at + k]}');
  }
}

int _mdat(Uint8List b, int size) => b.length - size;

// item 1 the picture; items 2 to n + 1 alpha planes, each the alpha of the
// one before, listed last first, all sharing one auxC property
Uint8List _alphaChain(int n) {
  const urn = 'urn:mpeg:mpegB:cicp:systems:auxiliary:alpha';
  List<int> build(int at) => [
    ...box('ftyp', [...t('heic'), ...be32(0), ...t('mif1'), ...t('heic')]),
    ...full('meta', 0, [
      ...full('hdlr', 0, [...be32(0), ...t('pict'), ...List.filled(13, 0)]),
      ...full('pitm', 0, be16(1)),
      ...full('iinf', 0, [
        ...be16(n + 1),
        for (var k = 1; k <= n + 1; k++) ...infe(k, 'hvc1'),
      ]),
      ...full('iref', 0, [
        for (var k = n + 1; k >= 2; k--)
          ...box('auxl', [...be16(k), ...be16(1), ...be16(k - 1)]),
      ]),
      ...box('iprp', [
        ...box('ipco', [
          ...full('auxC', 0, [...t(urn), 0]),
        ]),
        ...full('ipma', 0, [
          ...be32(n),
          for (var k = 2; k <= n + 1; k++) ...[...be16(k), 1, 1],
        ]),
      ]),
      ...full('iloc', 1, [
        0x44,
        0x00,
        ...be16(1),
        ...[...be16(1), ...be16(0), ...be16(0), ...be16(1)],
        ...[...be32(at), ...be32(3)],
      ]),
    ]),
    ...box('mdat', [1, 2, 3]),
  ];
  final probe = build(0);
  return Uint8List.fromList(build(probe.length - 3));
}

// what the reader makes of [b], read in an isolate of its own
Future<(MetaStatus, int, int)> _read(Uint8List b) => Isolate.run(() {
  final r = readMetaStrict(MemorySource(b));
  return (r.status, r.extraPictures, r.smallCopies);
});

void main() {
  const n = 60000;

  test('many picture extents and many exif ones', () async {
    final b = _heic(n, n);
    final out = await _clean(b);
    expect(out, isNotNull);
    expect(out!.length, b.length);
    _picture(out, _mdat(b, 4 * n), n, n);
  }, timeout: _fast);

  test('many picture extents and many boxes before mdat', () async {
    final b = _heic(n, 1, before: n);
    final out = await _clean(b);
    expect(out, isNotNull);
    expect(out!.length, b.length);
    _picture(out, _mdat(b, 2 * n + 2), n, 1);
  }, timeout: _fast);

  test('many boxes behind the picture are cut', () async {
    const junk = 100000;
    final b = _heic(1, 1, after: junk);
    final out = await _clean(b);
    expect(out, isNotNull);
    expect(out!.length, b.length - 8 * junk);
    _picture(out, out.length - 4, 1, 1);
  }, timeout: _fast);

  group('references', () {
    const n = 30000;

    test('a long chain of grids is the picture', () async {
      const chain = 60000;
      final b = heifOf(
        [
          for (var i = 1; i < chain; i++) HeifPart(i, 'grid', const [9]),
          const HeifPart(chain, 'hvc1', [1, 2, 3]),
        ],
        refs: [
          for (var i = 1; i < chain; i++) ('dimg', i, [i + 1]),
        ],
      );
      final out = await _clean(b);
      expect(out, isNotNull);
      expect(out!.sublist(out.length - 3), [1, 2, 3]);
    }, timeout: _fast);

    test('a long chain of alpha planes is kept', () async {
      const chain = 60000;
      final b = _alphaChain(chain);
      final (cleaned, kept) = await Isolate.run(() {
        final s = MemorySource(b);
        final top = isoBoxes(s, 0, b.length, [0]);
        final m = readHeifMeta(s, firstOf(top, 'meta')!, [0]);
        return (cleanHeif(b) != null, heifPictureItems(s, m).length);
      });
      expect(cleaned, isTrue);
      expect(kept, chain + 1);
    }, timeout: _fast);

    test('a long chain of grids beside the picture', () async {
      final b = heifOf(
        [
          const HeifPart(1, 'hvc1', [1, 2, 3]),
          for (var i = 2; i <= n; i++) HeifPart(i, 'grid', const [9]),
          const HeifPart(n + 1, 'hvc1', [4, 5, 6]),
        ],
        refs: [
          for (var i = 2; i <= n; i++) ('dimg', i, [i + 1]),
        ],
      );
      final (status, others, _) = await _read(b);
      expect(status, MetaStatus.found);
      expect(others, n);
      expect(await _clean(b), isNotNull);
    }, timeout: _fast);

    test('many thumbnails of the picture', () async {
      final b = heifOf(
        [
          const HeifPart(1, 'hvc1', [1, 2, 3]),
          for (var i = 2; i <= n + 1; i++) HeifPart(i, 'hvc1', const [9]),
        ],
        refs: [
          for (var i = 2; i <= n + 1; i++) ('thmb', i, [1]),
        ],
      );
      final (status, _, small) = await _read(b);
      expect(status, MetaStatus.found);
      expect(small, n);
    }, timeout: _fast);
  });
}
