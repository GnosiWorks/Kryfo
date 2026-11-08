// sample tables from a stranger's file: counts that claim billions of
// samples, runs that walk back, tables that ask for gigabytes. each is
// refused at once, never walked, and never read whole.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/mp4_strip.dart';

import 'meta_fixtures.dart';

const _fast = Timeout(Duration(seconds: 5));

// one video track with the tables given, and an mdat of [data]
Uint8List _movie({
  required List<int> stsz,
  required List<int> stsc,
  required List<int> stco,
  List<int> data = const [1, 2, 3, 4],
}) {
  final trak = box('trak', [
    ...full('tkhd', 0, [
      ...List.filled(8, 0),
      ...be32(1),
      ...List.filled(68, 0),
    ]),
    ...box('mdia', [
      ...full('mdhd', 0, List.filled(20, 0)),
      ...full('hdlr', 0, [...be32(0), ...t('vide'), ...List.filled(13, 0)]),
      ...box('minf', [
        ...box('stbl', [
          ...full('stsd', 0, [...be32(1), ...box('avc1', List.filled(8, 0))]),
          ...stsz,
          ...stsc,
          ...stco,
        ]),
      ]),
    ]),
  ]);
  return Uint8List.fromList([
    ...box('ftyp', [...t('isom'), ...be32(0), ...t('isom')]),
    ...box('moov', trak),
    ...box('mdat', data),
  ]);
}

List<int> _stsc(List<(int, int)> runs) => full('stsc', 0, [
  ...be32(runs.length),
  for (final (first, per) in runs) ...[
    ...be32(first),
    ...be32(per),
    ...be32(1),
  ],
]);

List<int> _stco(int chunks) => full('stco', 0, [
  ...be32(chunks),
  for (var k = 0; k < chunks; k++) ...be32(8),
]);

Future<void> _refused(Uint8List b) async {
  expect(readMeta(MemorySource(b)).status, MetaStatus.unreadable);
  final dir = await Directory.systemTemp.createTemp('hostile');
  final f = File('${dir.path}/v.mp4')..writeAsBytesSync(b);
  expect(await stripMp4Metadata(f.path), null);
  await dir.delete(recursive: true);
}

void main() {
  test('one size for four billion samples is not walked', () async {
    await _refused(
      _movie(
        stsz: full('stsz', 0, [...be32(1), ...be32(0xFFFFFFFF)]),
        stsc: _stsc([(1, 0xFFFFFFFF)]),
        stco: _stco(1),
      ),
    );
  }, timeout: _fast);

  test('runs that walk back over the chunks are refused', () async {
    final runs = <(int, int)>[
      for (var k = 0; k < 4000; k++) (k.isEven ? 1 : 4000, 0),
    ];
    await _refused(
      _movie(
        stsz: full('stsz', 0, [...be32(1), ...be32(4000)]),
        stsc: _stsc(runs),
        stco: _stco(4000),
      ),
    );
  }, timeout: _fast);

  test('a chunk said to hold no samples is refused', () async {
    await _refused(
      _movie(
        stsz: full('stsz', 0, [...be32(1), ...be32(2)]),
        stsc: _stsc([(1, 0), (2, 2)]),
        stco: _stco(2),
      ),
    );
  });

  test('a size table past what any phone writes is not read', () async {
    // the box is really this big; it is refused before it is read. built
    // as bytes, since a list of 64 million ints would cost half a gigabyte
    const n = (64 << 20) + 4;
    List<int> head(String type, int body) => [...be32(8 + body), ...t(type)];
    final stszHead = [
      ...head('stsz', 12 + n),
      0,
      0,
      0,
      0,
      ...be32(0),
      ...be32(n ~/ 4),
    ];
    final rest = [
      ..._stsc([(1, 1)]),
      ..._stco(1),
    ];
    final stsd = full('stsd', 0, [
      ...be32(1),
      ...box('avc1', List.filled(8, 0)),
    ]);
    final stbl = stsd.length + stszHead.length + n + rest.length;
    final hdlr = full('hdlr', 0, [
      ...be32(0),
      ...t('vide'),
      ...List.filled(13, 0),
    ]);
    final mdhd = full('mdhd', 0, List.filled(20, 0));
    final minf = 8 + stbl;
    final mdia = mdhd.length + hdlr.length + 8 + minf;
    final tkhd = full('tkhd', 0, [
      ...List.filled(8, 0),
      ...be32(1),
      ...List.filled(68, 0),
    ]);
    final trak = tkhd.length + 8 + mdia;
    final b = BytesBuilder(copy: false)
      ..add(box('ftyp', [...t('isom'), ...be32(0), ...t('isom')]))
      ..add(head('moov', 8 + trak))
      ..add(head('trak', trak))
      ..add(tkhd)
      ..add(head('mdia', mdia))
      ..add(mdhd)
      ..add(hdlr)
      ..add(head('minf', minf))
      ..add(head('stbl', stbl))
      ..add(stsd)
      ..add(stszHead)
      ..add(Uint8List(n))
      ..add(rest)
      ..add(box('mdat', [1, 2, 3, 4]));
    await _refused(b.toBytes());
  }, timeout: _fast);

  test('a fragment run of four billion samples is not walked', () async {
    final moov = box('moov', [
      ...full('mvhd', 0, List.filled(96, 0)),
      ...box('trak', [
        ...full('tkhd', 0, [
          ...List.filled(8, 0),
          ...be32(1),
          ...List.filled(68, 0),
        ]),
        ...box('mdia', [
          ...full('hdlr', 0, [...be32(0), ...t('vide'), ...List.filled(13, 0)]),
        ]),
      ]),
      ...box('mvex', [
        ...full('trex', 0, [
          ...be32(1),
          ...be32(1),
          ...be32(0),
          ...be32(0),
          ...be32(0),
        ]),
      ]),
    ]);
    // a run with no per-sample fields: every sample takes the default size
    final moof = box('moof', [
      ...full('mfhd', 0, be32(1)),
      ...box('traf', [
        ...box('tfhd', [0, 2, 0, 0, ...be32(1)]),
        ...full('trun', 0, be32(0xFFFFFFFF)),
      ]),
    ]);
    await _refused(
      Uint8List.fromList([
        ...box('ftyp', [...t('iso6'), ...be32(0), ...t('iso6')]),
        ...moov,
        ...moof,
        ...box('mdat', [1, 2, 3]),
      ]),
    );
  }, timeout: _fast);
}
