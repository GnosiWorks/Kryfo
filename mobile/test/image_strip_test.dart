// hand-built minimal files in the shapes the stripper walks: identifying
// bytes go, picture bytes stay put, and an unreadable file comes back null.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/image_strip.dart';

List<int> be32(int v) => [
  (v >> 24) & 255,
  (v >> 16) & 255,
  (v >> 8) & 255,
  v & 255,
];
List<int> be16(int v) => [(v >> 8) & 255, v & 255];
List<int> le32(int v) => [
  v & 255,
  (v >> 8) & 255,
  (v >> 16) & 255,
  (v >> 24) & 255,
];
List<int> t(String s) => latin1.encode(s);

List<int> pngChunk(String type, List<int> data) => [
  ...be32(data.length),
  ...t(type),
  ...data,
  0, 0, 0, 0, // the crc is not read
];
const pngSig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

List<int> riffChunk(String type, List<int> data) => [
  ...t(type),
  ...le32(data.length),
  ...data,
  if (data.length.isOdd) 0,
];
Uint8List webp(List<List<int>> chunks) {
  final body = [for (final c in chunks) ...c];
  return Uint8List.fromList([
    ...t('RIFF'),
    ...le32(4 + body.length),
    ...t('WEBP'),
    ...body,
  ]);
}

List<int> box(String type, List<int> body) => [
  ...be32(8 + body.length),
  ...t(type),
  ...body,
];
List<int> full(String type, int version, List<int> body) =>
    box(type, [version, 0, 0, 0, ...body]);
List<int> infe(int id, String type, {String mime = ''}) => full('infe', 2, [
  ...be16(id),
  ...be16(0),
  ...t(type),
  0, // empty name
  if (type == 'mime') ...[...t(mime), 0],
]);

bool has(Uint8List hay, String needle) =>
    latin1.decode(hay, allowInvalid: true).contains(needle);

// a heif whose exif item (id 2) and xmp item (id 3) sit in mdat
Uint8List heif({int ilocVersion = 1, bool dropIlocForExif = false}) {
  final ftyp = box('ftyp', [
    ...t('heic'),
    ...be32(0),
    ...t('mif1'),
    ...t('heic'),
  ]);
  const exif = 'GPS 37.9838N 23.7275E';
  const xmp = '<x:xmpmeta>Redmi Note</x:xmpmeta>';
  const pic = 'PICTUREPICTUREPICTURE';
  final iinf = full('iinf', 0, [
    ...be16(3),
    ...infe(1, 'hvc1'),
    ...infe(2, 'Exif'),
    ...infe(3, 'mime', mime: 'application/rdf+xml'),
  ]);
  List<int> ilocWith(int picAt, int exifAt, int xmpAt) {
    List<int> item(int id, int at, int len) => [
      ...be16(id),
      if (ilocVersion > 0) ...be16(0), // construction method 0
      ...be16(0), // data reference
      ...be16(1), // one extent. base offset size is 0
      ...be32(at),
      ...be32(len),
    ];
    final items = [
      item(1, picAt, pic.length),
      if (!dropIlocForExif) item(2, exifAt, exif.length),
      item(3, xmpAt, xmp.length),
    ];
    return full('iloc', ilocVersion, [
      0x44, 0x00, // offset 4, length 4, base 0, index 0
      ...be16(items.length),
      for (final i in items) ...i,
    ]);
  }

  // laid out once to learn where mdat lands, then for real
  List<int> build(int picAt, int exifAt, int xmpAt) => [
    ...ftyp,
    ...full('meta', 0, [...iinf, ...ilocWith(picAt, exifAt, xmpAt)]),
    ...box('mdat', [...t(pic), ...t(exif), ...t(xmp)]),
  ];
  final probe = build(0, 0, 0);
  final mdatBody = probe.length - (pic.length + exif.length + xmp.length);
  return Uint8List.fromList(
    build(mdatBody, mdatBody + pic.length, mdatBody + pic.length + exif.length),
  );
}

void main() {
  group('png', () {
    final src = Uint8List.fromList([
      ...pngSig,
      ...pngChunk('IHDR', List.filled(13, 1)),
      ...pngChunk('tEXt', [...t('Author'), 0, ...t('Marios')]),
      ...pngChunk('eXIf', t('GPS 37.98 23.72')),
      ...pngChunk('iCCP', t('srgb')),
      ...pngChunk('IDAT', t('pixels')),
      ...pngChunk('tIME', [7, 234, 9, 18, 0, 0, 0]),
      ...pngChunk('IEND', []),
    ]);
    test('strips text and exif, keeps pixels and colour', () {
      expect(pictureKind(src), PictureKind.png);
      final out = stripPictureBytes(src)!;
      expect(has(out, 'Marios'), false);
      expect(has(out, 'GPS'), false);
      expect(has(out, 'tIME'), false);
      expect(has(out, 'pixels'), true);
      expect(has(out, 'iCCP'), true);
      expect(has(out, 'IEND'), true);
    });
    test('returns a clean file as is', () {
      final clean = stripPictureBytes(src)!;
      expect(identical(stripPictureBytes(clean), clean), true);
    });
    test('strips bytes hidden after IEND', () {
      final tail = Uint8List.fromList([
        ...stripPictureBytes(src)!,
        ...t('secret'),
      ]);
      expect(has(stripPictureBytes(tail)!, 'secret'), false);
    });
    test('a cut file is null', () {
      expect(stripPictureBytes(src.sublist(0, src.length - 6)), null);
    });
  });

  group('webp', () {
    final src = webp([
      riffChunk('VP8X', [0x0C, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      riffChunk('VP8 ', t('pixels!')), // odd length, so it is padded
      riffChunk('EXIF', t('GPS 37.98 23.72')),
      riffChunk('XMP ', t('<xmp>Redmi</xmp>')),
    ]);
    test('strips exif and xmp and clears their flags', () {
      expect(pictureKind(src), PictureKind.webp);
      final out = stripPictureBytes(src)!;
      expect(has(out, 'GPS'), false);
      expect(has(out, 'Redmi'), false);
      expect(has(out, 'pixels!'), true);
      expect(out[20] & 0x0C, 0); // the VP8X flags byte
      // the riff size matches the file
      final size = out[4] | (out[5] << 8) | (out[6] << 16) | (out[7] << 24);
      expect(8 + size, out.length);
      expect(identical(stripPictureBytes(out), out), true);
    });
    test('an oversized riff size is null', () {
      final bad = Uint8List.fromList(src)
        ..[4] = 0xFF
        ..[5] = 0xFF;
      expect(stripPictureBytes(bad), null);
    });
  });

  group('heif', () {
    for (final v in [0, 1]) {
      test('zeroes exif and xmp in place, iloc v$v', () {
        final src = heif(ilocVersion: v);
        expect(pictureKind(src), PictureKind.heif);
        final out = stripPictureBytes(src)!;
        expect(out.length, src.length); // nothing moved
        expect(has(out, 'GPS'), false);
        expect(has(out, 'Redmi'), false);
        expect(has(out, 'PICTUREPICTUREPICTURE'), true);
      });
    }
    test('cuts a vendor box at the tail', () {
      final src = Uint8List.fromList([
        ...heif(),
        ...box('sefd', t('SM-A217F 37.98')),
      ]);
      final out = stripPictureBytes(src)!;
      expect(has(out, 'sefd'), false);
      expect(has(out, 'SM-A217F'), false);
      expect(out.length, heif().length);
      expect(has(out, 'PICTUREPICTUREPICTURE'), true);
    });
    test('strips a vendor box from a clean file', () {
      final clean = stripPictureBytes(heif())!;
      final src = Uint8List.fromList([...clean, ...box('sefd', t('SM-A217F'))]);
      expect(has(stripPictureBytes(src)!, 'SM-A217F'), false);
    });
    test('empties a vendor box in the middle', () {
      final src = Uint8List.fromList([
        ...heif(),
        ...box('sefd', t('SM-A217F')),
        ...box('free', [0, 0]),
      ]);
      final out = stripPictureBytes(src)!;
      expect(out.length, src.length);
      expect(has(out, 'sefd'), false);
      expect(has(out, 'SM-A217F'), false);
      expect(has(out, 'PICTUREPICTUREPICTURE'), true);
    });
    test('a picture inside a vendor box is null', () {
      final whole = heif();
      final at = latin1.decode(whole, allowInvalid: true).indexOf('mdat');
      final src = Uint8List.fromList(whole)..setRange(at, at + 4, t('sefd'));
      expect(stripPictureBytes(src), null);
    });
    test('an unplaced exif item is null', () {
      expect(stripPictureBytes(heif(dropIlocForExif: true)), null);
    });
    test('a box past the file end is null', () {
      final src = heif();
      expect(stripPictureBytes(src.sublist(0, src.length - 5)), null);
    });
  });

  group('gif', () {
    List<int> sub(List<int> d) => [d.length, ...d, 0];
    final src = Uint8List.fromList([
      ...t('GIF89a'), 1, 0, 1, 0, 0x80, 0, 0, // 1x1, a 2-colour palette
      0, 0, 0, 255, 255, 255,
      0x21, 0xFF, 11, ...t('NETSCAPE2.0'), 3, 1, 0, 0, 0, // loop for ever
      0x21, 0xFF, 11, ...t('XMP DataXMP'), ...sub(t('<xmp>Redmi</xmp>')),
      0x21, 0xFE, ...sub(t('made by Marios')),
      0x21, 0xF9, 4, 0, 5, 0, 0, 0, // frame timing
      0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, ...sub([0x44, 0x01]),
      0x3B,
    ]);
    test('strips comments and xmp, keeps loop and frames', () {
      expect(pictureKind(src), PictureKind.gif);
      final out = stripPictureBytes(src)!;
      expect(has(out, 'Redmi'), false);
      expect(has(out, 'Marios'), false);
      expect(has(out, 'NETSCAPE2.0'), true);
      expect(out.last, 0x3B);
      expect(identical(stripPictureBytes(out), out), true);
    });
    test('no trailer is null', () {
      expect(stripPictureBytes(src.sublist(0, src.length - 1)), null);
    });
  });

  test('a jpeg goes through the jpeg stripper', () {
    final src = Uint8List.fromList([
      0xFF, 0xD8, //
      0xFF, 0xE1, ...be16(2 + 8), ...t('Exif'), 0, 0, ...t('GP'),
      0xFF, 0xDA, ...be16(2), 1, 2, 3, //
      0xFF, 0xD9,
    ]);
    expect(pictureKind(src), PictureKind.jpeg);
    final out = stripPictureBytes(src)!;
    expect(has(out, 'Exif'), false);
  });

  test('anything else is left exactly alone', () {
    final pdf = Uint8List.fromList(t('%PDF-1.7 hello'));
    expect(pictureKind(pdf), PictureKind.other);
    expect(identical(stripPictureBytes(pdf), pdf), true);
  });
}
