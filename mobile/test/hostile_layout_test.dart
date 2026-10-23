// a stranger's video with a hundred thousand top level boxes beside a
// hundred thousand chunks: each box and each chunk is looked up by halves,
// so the read and the clean take moments, not minutes.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/mp4_strip.dart';

import 'meta_fixtures.dart';

const _fast = Timeout(Duration(seconds: 5));

List<int> _head(String type, int body) => [...be32(8 + body), ...t(type)];

// [ftyp][m boxes of [pad]][moov][mdat]: one video track whose n one byte
// samples sit two bytes apart, in one mdat or in an mdat each
Uint8List _movie(
  int n,
  int m,
  String pad, {
  required bool fixed,
  bool mdatEach = false,
}) {
  final ftyp = box('ftyp', [...t('isom'), ...be32(0), ...t('isom')]);
  final pads = BytesBuilder(copy: false);
  for (var i = 0; i < m; i++) {
    pads.add(_head(pad, 0));
  }
  final padBytes = pads.toBytes();
  // the k-th sample, counted from the first mdat's payload
  int sampleAt(int base, int k) => mdatEach ? base + 9 * k : base + 2 * k;
  List<int> moovFor(int base) {
    final stco = BytesBuilder(copy: false)
      ..add(_head('stco', 8 + 4 * n))
      ..add([0, 0, 0, 0, ...be32(n)]);
    for (var k = 0; k < n; k++) {
      stco.add(be32(sampleAt(base, k)));
    }
    final List<int> stsz;
    if (fixed) {
      stsz = full('stsz', 0, [...be32(1), ...be32(n)]);
    } else {
      final b = BytesBuilder(copy: false)
        ..add(_head('stsz', 12 + 4 * n))
        ..add([0, 0, 0, 0, ...be32(0), ...be32(n)]);
      for (var k = 0; k < n; k++) {
        b.add(be32(1));
      }
      stsz = b.toBytes();
    }
    return box('moov', [
      ...full('mvhd', 0, List.filled(96, 0)),
      ...box('trak', [
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
              ...full('stsd', 0, [
                ...be32(1),
                ...box('avc1', List.filled(8, 0)),
              ]),
              ...stsz,
              ...full('stsc', 0, [
                ...be32(1),
                ...be32(1),
                ...be32(1),
                ...be32(1),
              ]),
              ...stco.toBytes(),
            ]),
          ]),
        ]),
      ]),
    ]);
  }

  final base = ftyp.length + padBytes.length + moovFor(0).length + 8;
  final out = BytesBuilder(copy: false)
    ..add(ftyp)
    ..add(padBytes)
    ..add(moovFor(base));
  if (mdatEach) {
    for (var k = 0; k < n; k++) {
      out.add([..._head('mdat', 1), 7]);
    }
  } else {
    out
      ..add(_head('mdat', 2 * n))
      ..add(Uint8List(2 * n)..fillRange(0, 2 * n, 7));
  }
  return out.toBytes();
}

Future<MetaStatus> _read(Uint8List b) =>
    Isolate.run(() => readMetaStrict(MemorySource(b)).status);

// cleaned in a file of its own; the bytes after the clean
Future<Uint8List?> _strip(Uint8List b) async {
  final dir = await Directory.systemTemp.createTemp('layout');
  try {
    final f = File('${dir.path}/v.mp4')..writeAsBytesSync(b);
    if (await stripMp4Metadata(f.path) != true) return null;
    return f.readAsBytesSync();
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  const n = 100000;

  test('one size chunks behind many free boxes', () async {
    final b = _movie(n, n, 'free', fixed: true);
    expect(await _read(b), MetaStatus.nothing);
    final out = await _strip(b);
    expect(out, isNotNull);
    // every sample byte kept as it was
    expect(out!.sublist(b.length - 2 * n), b.sublist(b.length - 2 * n));
  }, timeout: _fast);

  test('many unknown boxes and many kept samples', () async {
    final b = _movie(n, n, 'junk', fixed: false);
    final out = await _strip(b);
    expect(out, isNotNull);
    // each sample byte kept, the unused byte after it zeroed
    final data = out!.sublist(b.length - 2 * n);
    for (var k = 0; k < n; k++) {
      if (data[2 * k] != 7 || data[2 * k + 1] != 0) fail('byte ${2 * k}');
    }
    expect(await _read(out), MetaStatus.nothing);
  }, timeout: _fast);

  test('a sample in each of many mdats', () async {
    final b = _movie(n, 0, 'free', fixed: false, mdatEach: true);
    expect(await _read(b), MetaStatus.nothing);
    final out = await _strip(b);
    expect(out, b);
  }, timeout: _fast);
}
