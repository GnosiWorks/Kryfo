// SPDX-License-Identifier: GPL-3.0-or-later
// a picture copied on a computer comes off the clipboard as a png or a dib.
// a dib is made rgba here, top down, for every depth a copy uses, and a png
// in memory; a png goes as it is. the runner reads it in memory only, and
// not while words are on the clipboard too
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/clip_picture.dart';

// a dib: its header ([head] bytes), [extra] (masks, colours), then [rows]
Uint8List _dib({
  required int w,
  required int h,
  required int bpp,
  int comp = 0,
  int head = 40,
  int used = 0,
  List<int> masks = const [],
  List<int> extra = const [],
  required List<int> rows,
}) {
  final b = BytesBuilder();
  final d = ByteData(head);
  d.setUint32(0, head, Endian.little);
  d.setInt32(4, w, Endian.little);
  d.setInt32(8, h, Endian.little);
  d.setUint16(12, 1, Endian.little);
  d.setUint16(14, bpp, Endian.little);
  d.setUint32(16, comp, Endian.little);
  d.setUint32(32, used, Endian.little);
  for (final (i, m) in masks.indexed) {
    if (head >= 40 + (i + 1) * 4) d.setUint32(40 + i * 4, m, Endian.little);
  }
  b.add(d.buffer.asUint8List());
  b.add(extra);
  b.add(rows);
  return b.toBytes();
}

List<int> _u32(int v) => [v & 255, v >> 8 & 255, v >> 16 & 255, v >> 24 & 255];

void main() {
  group('a dib made rgba', () {
    test('24 bits, bottom up, rows padded to four bytes', () {
      // bottom row first: blue, white; then the top: red, green
      final px = dibToRgba(
        _dib(
          w: 2,
          h: 2,
          bpp: 24,
          rows: [
            ...[255, 0, 0, 255, 255, 255, 0, 0],
            ...[0, 0, 255, 0, 255, 0, 0, 0],
          ],
        ),
      )!;
      expect((px.width, px.height), (2, 2));
      expect(px.rgba, [
        ...[255, 0, 0, 255, 0, 255, 0, 255],
        ...[0, 0, 255, 255, 255, 255, 255, 255],
      ]);
    });

    test('32 bits plain, top down: the fourth byte is no alpha', () {
      final px = dibToRgba(
        _dib(w: 1, h: -2, bpp: 32, rows: [10, 20, 30, 0, 40, 50, 60, 7]),
      )!;
      expect(px.rgba, [30, 20, 10, 255, 60, 50, 40, 255]);
    });

    test('a v5 header with an alpha mask keeps its alpha', () {
      final px = dibToRgba(
        _dib(
          w: 2,
          h: 1,
          bpp: 32,
          comp: 3,
          head: 124,
          masks: [0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000],
          rows: [1, 2, 3, 128, 4, 5, 6, 0],
        ),
      )!;
      expect(px.rgba, [3, 2, 1, 128, 6, 5, 4, 0]);
    });

    test('an alpha mask with every alpha zero is an opaque picture', () {
      final px = dibToRgba(
        _dib(
          w: 2,
          h: 1,
          bpp: 32,
          comp: 3,
          head: 124,
          masks: [0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000],
          rows: [1, 2, 3, 0, 4, 5, 6, 0],
        ),
      )!;
      expect(px.rgba, [3, 2, 1, 255, 6, 5, 4, 255]);
    });

    test('masks repeated after a v5 header are passed over', () {
      final px = dibToRgba(
        _dib(
          w: 1,
          h: 1,
          bpp: 32,
          comp: 3,
          head: 124,
          masks: [0x00FF0000, 0x0000FF00, 0x000000FF, 0],
          extra: [..._u32(0x00FF0000), ..._u32(0x0000FF00), ..._u32(0xFF)],
          rows: [9, 8, 7, 0],
        ),
      )!;
      expect(px.rgba, [7, 8, 9, 255]);
    });

    test('16 bits: 555 plain, 565 by masks after a short header', () {
      // white in 555, then pure red
      final plain = dibToRgba(
        _dib(w: 2, h: 1, bpp: 16, rows: [0xFF, 0x7F, 0x00, 0x7C]),
      )!;
      expect(plain.rgba, [255, 255, 255, 255, 255, 0, 0, 255]);
      // pure green in 565, padded to four bytes
      final masked = dibToRgba(
        _dib(
          w: 1,
          h: 1,
          bpp: 16,
          comp: 3,
          extra: [..._u32(0xF800), ..._u32(0x07E0), ..._u32(0x001F)],
          rows: [0xE0, 0x07, 0, 0],
        ),
      )!;
      expect(masked.rgba, [0, 255, 0, 255]);
    });

    test('8, 4 and 1 bits by their colours', () {
      final table = [
        ...[0, 0, 0, 0], // black
        ...[0, 0, 255, 0], // red
      ];
      final eight = dibToRgba(
        _dib(w: 2, h: 1, bpp: 8, used: 2, extra: table, rows: [1, 0, 0, 0]),
      )!;
      expect(eight.rgba, [255, 0, 0, 255, 0, 0, 0, 255]);
      final four = dibToRgba(
        _dib(w: 2, h: 1, bpp: 4, used: 2, extra: table, rows: [0x01, 0, 0, 0]),
      )!;
      expect(four.rgba, [0, 0, 0, 255, 255, 0, 0, 255]);
      final one = dibToRgba(
        _dib(w: 3, h: 1, bpp: 1, extra: table, rows: [0xA0, 0, 0, 0]),
      )!;
      expect(one.rgba, [
        ...[255, 0, 0, 255],
        ...[0, 0, 0, 255],
        ...[255, 0, 0, 255],
      ]);
    });

    test('nothing of a dib that is short, odd or too big', () {
      expect(dibToRgba(Uint8List(12)), isNull);
      // rows missing
      expect(dibToRgba(_dib(w: 4, h: 4, bpp: 24, rows: [1, 2, 3])), isNull);
      expect(dibToRgba(_dib(w: 0, h: 1, bpp: 24, rows: [0, 0, 0, 0])), isNull);
      expect(dibToRgba(_dib(w: 1, h: 0, bpp: 24, rows: [0, 0, 0, 0])), isNull);
      // run length and jpeg dibs are not read
      for (final comp in [1, 2, 4, 5]) {
        expect(
          dibToRgba(_dib(w: 1, h: 1, bpp: 8, comp: comp, rows: [0, 0, 0, 0])),
          isNull,
        );
      }
      expect(dibToRgba(_dib(w: 1, h: 1, bpp: 2, rows: [0, 0, 0, 0])), isNull);
      // past the most pixels, before a byte of it is read
      expect(
        dibToRgba(_dib(w: 1 << 13, h: 1 << 13, bpp: 32, rows: const [])),
        isNull,
      );
      // a colour past the table
      expect(
        dibToRgba(
          _dib(
            w: 1,
            h: 1,
            bpp: 8,
            used: 1,
            extra: [0, 0, 0, 0],
            rows: [5, 0, 0, 0],
          ),
        ),
        isNull,
      );
    });
  });

  group('a png in memory', () {
    testWidgets('a dib becomes a png that reads back the same', (t) async {
      final dib = _dib(
        w: 2,
        h: 2,
        bpp: 24,
        rows: [
          ...[255, 0, 0, 255, 255, 255, 0, 0],
          ...[0, 0, 255, 0, 255, 0, 0, 0],
        ],
      );
      final back = await t.runAsync(() async {
        final png = await pictureOf({'kind': 'dib', 'bytes': dib});
        expect(looksPng(png!), isTrue);
        final codec = await ui.instantiateImageCodec(png);
        final img = (await codec.getNextFrame()).image;
        final raw = await img.toByteData();
        img.dispose();
        codec.dispose();
        return raw!.buffer.asUint8List();
      });
      expect(back, [
        ...[255, 0, 0, 255, 0, 255, 0, 255],
        ...[0, 0, 255, 255, 255, 255, 255, 255],
      ]);
    });

    test('a png goes as it is; anything else is no picture', () async {
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, //
      ]);
      expect(await pictureOf({'kind': 'png', 'bytes': png}), same(png));
      expect(
        await pictureOf({
          'kind': 'png',
          'bytes': Uint8List.fromList([1, 2]),
        }),
        isNull,
      );
      expect(await pictureOf({'kind': 'gif', 'bytes': png}), isNull);
      expect(await pictureOf({'kind': 'png'}), isNull);
      expect(await pictureOf(null), isNull);
      // no runner call here: no picture, nothing thrown
      expect(await clipboardPicture(), isNull);
    });

    test('a link beside a picture gives the picture; a sentence with a link, '
        'or a link alone, gives the words', () async {
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, //
      ]);
      Future<Uint8List?> beside(Object? text) =>
          pictureOf({'kind': 'png', 'bytes': png, 'text': text});
      // firefox's copy image
      expect(await beside('https://example.org/cat.png'), same(png));
      expect(await beside('  http://example.org/a?b=c#d\r\n'), same(png));
      expect(await beside('HTTPS://Example.org/x'), same(png));
      for (final words in [
        'look https://example.org/cat.png',
        'https://example.org/cat.png is nice',
        'https://a.org https://b.org',
        'https://example.org/a\nb',
        'ftp://example.org/cat.png',
        'example.org/cat.png',
        'https://',
        'hi',
        '',
        '   ',
        'https://example.org/${'a' * kLinkMost}',
      ]) {
        expect(await beside(words), isNull, reason: words);
      }
      expect(await beside(3), isNull);
      // a link alone: no picture to win
      expect(await pictureOf({'text': 'https://example.org/cat.png'}), isNull);
      expect(loneLink('https://example.org/cat.png'), isTrue);
      expect(loneLink('a link: https://example.org'), isFalse);
    });
  });

  test('the runner reads the picture in memory, not with words there but a '
      'link, and '
      'writes no file', () {
    final src = File('windows/runner/flutter_window.cpp').readAsStringSync();
    final at = src.indexOf('flutter::EncodableValue ClipboardPicture(');
    expect(at, greaterThan(0));
    final body = src.substring(at, src.indexOf('\n}\n', at));
    expect(
      body.indexOf('IsClipboardFormatAvailable(CF_UNICODETEXT)'),
      lessThan(body.indexOf('OpenClipboard')),
    );
    for (final f in ['L"PNG"', 'CF_DIBV5', 'CF_DIB)']) {
      expect(body, contains(f));
    }
    for (final disk in ['CreateFile', 'GetTempPath', 'fopen', 'ofstream']) {
      expect(body, isNot(contains(disk)));
    }
    expect(body, contains('new (std::nothrow)'));
    expect(src, contains('call.method_name() == "clipPicture"'));
    // words there too: read only when they are a lone link, and handed over
    // for dart to check again
    expect(
      body.indexOf('ClipboardLink(owner, &link)'),
      lessThan(body.indexOf('OpenClipboard')),
    );
    expect(body, contains('EncodableValue("text")'));
    final link = src.substring(
      src.indexOf('bool ClipboardLink('),
      src.indexOf('flutter::EncodableValue ClipboardPicture('),
    );
    for (final f in ['L"http://"', 'L"https://"', 'iswspace', 'kLinkMost']) {
      expect(link, contains(f));
    }
    for (final disk in ['CreateFile', 'GetTempPath', 'fopen', 'ofstream']) {
      expect(link, isNot(contains(disk)));
    }
  });
}
