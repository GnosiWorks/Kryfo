// SPDX-License-Identifier: GPL-3.0-or-later
// a zip's glance is read from its central directory only, with caps, and
// what comes over the wire is bounded field by field. malformed zips of
// every kind give a bounded glance or none, never a throw
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/zip_glance.dart';

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile.string(e.key, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

// where the end record starts
int _eocd(Uint8List b) {
  for (var i = b.length - 22; i >= 0; i--) {
    if (b[i] == 0x50 && b[i + 1] == 0x4b && b[i + 2] == 5 && b[i + 3] == 6) {
      return i;
    }
  }
  throw StateError('no end record');
}

int _u32(Uint8List b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);
void _put16(Uint8List b, int o, int v) {
  b[o] = v & 0xff;
  b[o + 1] = (v >> 8) & 0xff;
}

void _put32(Uint8List b, int o, int v) {
  _put16(b, o, v & 0xffff);
  _put16(b, o + 2, (v >> 16) & 0xffff);
}

// every central header's offset
List<int> _headers(Uint8List b) {
  final e = _eocd(b);
  var o = _u32(b, e + 16);
  final out = <int>[];
  while (o + 46 <= e && _u32(b, o) == 0x02014b50) {
    out.add(o);
    o +=
        46 +
        (b[o + 28] | (b[o + 29] << 8)) +
        (b[o + 30] | (b[o + 31] << 8)) +
        (b[o + 32] | (b[o + 33] << 8));
  }
  return out;
}

void _bounded(ZipGlance? g) {
  if (g == null) return;
  expect(g.count, inInclusiveRange(0, 10000000));
  expect(g.top.length, lessThanOrEqualTo(kZipRowsMost));
  for (final t in g.top) {
    expect(t.name.runes.length, lessThanOrEqualTo(kZipNameMost));
    expect(t.name, isNot(contains('/')));
    expect(t.name.contains(RegExp('[\u0000-\u001f\u202a-\u202e]')), isFalse);
  }
  if (g.unpacked case final u?) expect(u, inInclusiveRange(0, 1 << 50));
  expect(g.more, greaterThanOrEqualTo(0));
}

void main() {
  test(
    'the first entries, folders with their counts, the rest summed',
    () async {
      final g = (await zipGlanceOfBytes(
        _zip({
          'route.gpx': 'x' * 10,
          'photos/1.jpg': 'a' * 100,
          'photos/2.jpg': 'b' * 100,
          'photos/deep/3.jpg': 'c' * 100,
          'notes.txt': 'n' * 5,
          'docs/plan.pdf': 'p' * 50,
          'extra.md': 'm',
        }),
      ))!;
      expect(g.count, 7);
      expect(g.unpacked, 10 + 300 + 5 + 50 + 1);
      expect(g.top, const [
        ZipTop('route.gpx', -1),
        ZipTop('photos', 3),
        ZipTop('notes.txt', -1),
        ZipTop('docs', 1),
      ]);
      expect(g.more, 1);
      expect(g.locked, isFalse);
    },
  );

  test('names lose controls and direction marks; no way up or out', () async {
    final g = (await zipGlanceOfBytes(
      _zip({
        'in\u202egpj.exe': 'x',
        '../../etc/passwd': 'y',
        '/abs/file': 'z',
        '${'long' * 20}.txt': 'w',
      }),
    ))!;
    _bounded(g);
    expect(g.top.first.name, 'ingpj.exe');
    expect(g.top[1], const ZipTop('etc', 1));
    expect(g.top[2], const ZipTop('abs', 1));
    expect(g.top[3].name.runes.length, kZipNameMost);
    expect(g.top[3].name, endsWith('\u2026'));
  });

  test('a password on any entry marks it protected', () async {
    final b = _zip({'a.txt': 'x', 'b.txt': 'y'});
    final h = _headers(b);
    _put16(b, h[1] + 8, b[h[1] + 8] | 1);
    final g = (await zipGlanceOfBytes(b))!;
    expect(g.locked, isTrue);
    expect(ZipGlance.fromWire(g.toWire())!.locked, isTrue);
  });

  test('a bomb: sizes are never trusted past their clamp', () async {
    final b = _zip({for (var i = 0; i < 50; i++) 'f$i.bin': 'x'});
    for (final h in _headers(b)) {
      _put32(b, h + 24, 0xfffffffe);
    }
    final g = (await zipGlanceOfBytes(b))!;
    _bounded(g);
    expect(g.unpacked, 50 * 0xfffffffe);
  });

  test(
    'a count it cannot have: bounded, and no size it did not read',
    () async {
      final b = _zip({'a.txt': 'x', 'b.txt': 'y'});
      final e = _eocd(b);
      _put16(b, e + 8, 0xfffe);
      _put16(b, e + 10, 0xfffe);
      final g = (await zipGlanceOfBytes(b))!;
      _bounded(g);
      expect(g.count, 0xfffe);
      expect(g.unpacked, isNull);
    },
  );

  test('more than 2000 entries: it stops at 2000 and says how many', () async {
    final g = (await zipGlanceOfBytes(
      _zip({for (var i = 0; i < 2100; i++) 'f$i': ''}),
    ))!;
    expect(g.count, 2100);
    expect(g.unpacked, isNull);
  });

  test('a directory past 256 KB is read only so far', () async {
    final g = (await zipGlanceOfBytes(
      _zip({for (var i = 0; i < 1200; i++) '${'n' * 250}$i': ''}),
    ))!;
    _bounded(g);
    expect(g.count, 1200);
    expect(g.unpacked, isNull);
  });

  test('truncated anywhere: none or a bounded glance, never a throw', () async {
    final b = _zip({
      'a.txt': 'hello',
      'dir/b.txt': 'world',
      'c.bin': 'x' * 300,
    });
    for (var n = 0; n < b.length; n += 3) {
      _bounded(await zipGlanceOfBytes(Uint8List.sublistView(b, 0, n)));
      _bounded(await zipGlanceOfBytes(Uint8List.sublistView(b, n)));
    }
    expect(await zipGlanceOfBytes(Uint8List(0)), isNull);
    expect(await zipGlanceOfBytes(utf8.encode('not a zip at all, no')), isNull);
  });

  test('a directory that overlaps its end record, or points past the file, '
      'is none', () async {
    final b = _zip({'a.txt': 'x', 'b.txt': 'y'});
    final e = _eocd(b);
    final over = Uint8List.fromList(b);
    _put32(over, e + 12, _u32(b, e + 12) + 40);
    expect(await zipGlanceOfBytes(over), isNull);
    final past = Uint8List.fromList(b);
    _put32(past, e + 16, b.length + 100);
    expect(await zipGlanceOfBytes(past), isNull);
    final into = Uint8List.fromList(b);
    _put32(into, e + 16, e);
    _put32(into, e + 12, 22);
    _bounded(await zipGlanceOfBytes(into));
  });

  test('zip64: a broken locator is none, a sane record is read', () async {
    final b = _zip({'a.txt': 'x', 'big/b.txt': 'y'});
    final e = _eocd(b);
    final dirAt = _u32(b, e + 16);
    final dirSize = _u32(b, e + 12);
    // marked zip64 with no locator
    final bare = Uint8List.fromList(b);
    _put16(bare, e + 10, 0xffff);
    expect(await zipGlanceOfBytes(bare), isNull);
    // a real zip64 end record and locator between the directory and the end
    final rec = Uint8List(56);
    _put32(rec, 0, 0x06064b50);
    _put32(rec, 32, 2);
    _put32(rec, 40, dirSize);
    _put32(rec, 48, dirAt);
    final loc = Uint8List(20);
    _put32(loc, 0, 0x07064b50);
    _put32(loc, 8, e);
    final end = Uint8List.fromList(b.sublist(e));
    _put16(end, 10, 0xffff);
    _put32(end, 12, 0xffffffff);
    _put32(end, 16, 0xffffffff);
    final z64 = Uint8List.fromList([
      ...b.sublist(0, e),
      ...rec,
      ...loc,
      ...end,
    ]);
    final g = (await zipGlanceOfBytes(z64))!;
    expect(g.count, 2);
    expect(g.top, const [ZipTop('a.txt', -1), ZipTop('big', 1)]);
    // its record pointing past the end
    final bad = Uint8List.fromList(z64);
    _put32(bad, e + 56 + 8, z64.length);
    expect(await zipGlanceOfBytes(bad), isNull);
  });

  test('random damage never throws and stays bounded', () async {
    final b = _zip({
      'a.txt': 'hello',
      'photos/x.jpg': 'y' * 40,
      'notes/one.md': 'z',
    });
    final r = math.Random(7);
    for (var i = 0; i < 1500; i++) {
      final m = Uint8List.fromList(b);
      for (var k = 0; k < 1 + r.nextInt(8); k++) {
        m[r.nextInt(m.length)] = r.nextInt(256);
      }
      _bounded(await zipGlanceOfBytes(m));
    }
  });

  test('what comes over the wire is bounded field by field', () {
    expect(ZipGlance.fromWire(null), isNull);
    expect(ZipGlance.fromWire('x'), isNull);
    expect(ZipGlance.fromWire({'n': -1, 't': []}), isNull);
    expect(ZipGlance.fromWire({'n': 1 << 40, 't': []}), isNull);
    expect(ZipGlance.fromWire({'n': 3}), isNull);
    final g = ZipGlance.fromWire({
      'n': 9,
      'u': 1 << 60,
      't': [
        ['../../etc/\u202epasswd', -1],
        ['ok', 4],
        ['bad', -7],
        [42, 1],
        ['x' * 500, 2],
        'junk',
        ['five', 1],
        ['six', 1],
      ],
      'p': 'yes',
    })!;
    _bounded(g);
    expect(g.unpacked, isNull);
    expect(g.locked, isFalse);
    // only the first four rows are looked at; the bad ones among them drop
    expect(g.top.map((t) => t.name).toList(), ['etc', 'ok']);
    final long = ZipGlance.fromWire({
      'n': 1,
      't': [
        ['x' * 500, -1],
      ],
    })!;
    expect(long.top.single.name.runes.length, kZipNameMost);
  });

  test('the summary rides the message and comes back the same; a frame '
      'without it has none', () async {
    final g = (await zipGlanceOfBytes(_zip({'a.txt': 'x', 'd/b.txt': 'y'})))!;
    final w = await wrapMessage(
      '',
      msgUid: 'u1',
      fileName: 'f.zip',
      zipGlance: g,
    );
    expect(unwrapMessage(w).zipGlance, g);
    expect(jsonEncode(g.toWire()).length, lessThan(1024));
    final plain = await wrapMessage('', msgUid: 'u2', fileName: 'f.zip');
    expect(unwrapMessage(plain).zipGlance, isNull);
    expect(zipGlanced('Trip.ZIP'), isTrue);
    expect(zipGlanced('trip.tar'), isFalse);
  });
}
