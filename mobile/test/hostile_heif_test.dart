// a stranger's heic with tens of thousands of extents, boxes and items:
// every overlap and every reference is looked up by halves or in an index
// built once, so the clean and the read take moments, not minutes.
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/heif_clean.dart';

import 'meta_fixtures.dart';

const _fast = Timeout(Duration(seconds: 5));

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
}
