// what the reader names beside the picture, kind by kind: content
// credentials, labels and prompts, small copies, depth, hdr layers, extra
// pictures, the samsung trailer, heif items, video tracks and left over
// bytes. built files; the real ones are checked against the corpus list.
import 'dart:convert';
import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';

import 'meta_fixtures.dart';

MetaReport read(List<int> b) => readMeta(MemorySource(Uint8List.fromList(b)));

const _gpsJson =
    '{"EXIF:GPSLatitude":"43.1520939","EXIF:GPSLongitude":"-77.5805328"}';

String _xmp(String inner) =>
    '<x:xmpmeta><rdf:RDF><rdf:Description $inner/></rdf:RDF></x:xmpmeta>';

List<int> _xmpSeg(String x) =>
    seg(0xE1, [...t('http://ns.adobe.com/xap/1.0/'), 0, ...t(x)]);

const pic = HeifPart(1, 'hvc1', [1, 2, 3, 4]);

List<int> pngWith(List<int> chunks) => [
  ...pngSig,
  ...pngChunk('IHDR', List.filled(13, 1)),
  ...chunks,
  ...pngChunk('IDAT', t('pixels')),
  ...pngChunk('IEND', []),
];

void main() {
  group('content credentials', () {
    test('jpeg app11 reads as credentials with who made it', () {
      final r = read(jpegWith(app11(jumbf())));
      expect(r.credentials, true);
      expect(r.madeWith, 'Truepic Lens');
      expect(r.extra, isEmpty);
    });

    test('a place inside the credentials is a place', () {
      final r = read(jpegWith(app11(jumbf(extra: _gpsJson))));
      expect(r.gps!.lat, closeTo(43.1520939, 1e-6));
      expect(r.gps!.lon, closeTo(-77.5805328, 1e-6));
      expect(r.gps!.from, 'credentials');
    });

    test('a declared source type is read from credentials and xmp', () {
      final r = read(
        jpegWith(
          app11(jumbf(extra: 'http://cv.iptc.org/trainedAlgorithmicMedia')),
        ),
      );
      expect(r.syntheticLabel, true);
      final x = read(
        jpegWith(
          _xmpSeg(
            _xmp(
              'Iptc4xmpExt:DigitalSourceType="http://cv.iptc.org/newscodes/digitalsourcetype/compositeWithTrainedAlgorithmicMedia"',
            ),
          ),
        ),
      );
      expect(x.syntheticLabel, true);
      expect(read(jpegWith(_xmpSeg(_xmp('a="b"')))).syntheticLabel, false);
    });

    test('webp C2PA chunk reads as credentials', () {
      final body = [
        ...riffChunk('VP8 ', t('pixels!')),
        ...riffChunk('C2PA', jumbf()),
      ];
      final w = [...t('RIFF'), ...le32(4 + body.length), ...t('WEBP'), ...body];
      final r = read(w);
      expect(r.credentials, true);
      expect(r.extra, isEmpty);
    });
  });

  group('png text', () {
    test('prompt and settings keys are named', () {
      final r = read(
        pngWith([
          ...pngChunk('tEXt', [
            ...t('parameters'),
            0,
            ...t('a cat, steps: 20'),
          ]),
          ...pngChunk('tEXt', [...t('workflow'), 0, ...t('{"nodes":[]}')]),
          ...pngChunk('tEXt', [...t('Title'), 0, ...t('holiday')]),
        ]),
      );
      expect(r.syntheticPrompt, ['parameters', 'workflow']);
      expect(r.textKeys.length, 3);
    });

    test('exif kept as hex text is read through', () {
      final tiff = cameraTiff();
      final hex = tiff.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final lines = [
        for (var i = 0; i < hex.length; i += 72)
          hex.substring(i, i + 72 < hex.length ? i + 72 : hex.length),
      ];
      final text =
          '\nexif\n${tiff.length.toString().padLeft(8)}\n${lines.join('\n')}\n';
      final z = ZLibEncoder().convert(latin1.encode(text));
      final r = read(
        pngWith([
          ...pngChunk('zTXt', [...t('Raw profile type exif'), 0, 0, ...z]),
        ]),
      );
      expect(r.make, 'samsung');
      expect(r.gps, isNotNull);
    });
  });

  group('jpeg', () {
    test('jfif and jfxx thumbnails are small copies', () {
      final jfifThumb = seg(0xE0, [
        ...t('JFIF'), 0, 1, 2, 0, 0, 1, 0, 1, 2, 2, //
        ...List.filled(12, 9),
      ]);
      expect(read(jpegWith(jfifThumb)).smallCopies, 1);
      final bare = seg(0xE0, [...t('JFIF'), 0, 1, 2, 0, 0, 1, 0, 1, 0, 0]);
      expect(read(jpegWith(bare)).status, MetaStatus.nothing);
      final jfxx = seg(0xE0, [...t('JFXX'), 0, 0x10, 0xFF, 0xD8, 0xFF, 0xD9]);
      expect(read(jpegWith([...bare, ...jfxx])).smallCopies, 1);
    });

    test('a photoshop thumbnail is a small copy', () {
      final res = [...t('8BIM'), ...be16(0x040C), 0, 0, ...be32(4), 1, 2, 3, 4];
      final r = read(jpegWith(seg(0xED, [...t('Photoshop 3.0'), 0, ...res])));
      expect(r.iptc, true);
      expect(r.smallCopies, 1);
    });

    test('adobe app14 is part of the picture', () {
      final a = seg(0xEE, [...t('Adobe'), 0, 100, 0, 0, 0, 0, 1]);
      expect(read(jpegWith(a)).status, MetaStatus.nothing);
    });

    test('an hdr layer is not a motion clip', () {
      // ultra hdr lists its gain map in the same container as a motion
      // photo lists its clip
      final x = _xmp(
        'xmlns:Container="http://ns.google.com/photos/1.0/container/" '
        'hdrgm:Version="1.0"><Container:Directory><rdf:Seq><rdf:li '
        'Item:Semantic="Primary"/><rdf:li Item:Semantic="GainMap" '
        'Item:Length="1234"/></rdf:Seq></Container:Directory></rdf:Description',
      );
      final r = read(jpegWith(_xmpSeg(x)));
      expect(r.hdrLayer, true);
      expect(r.embeddedVideo, false);
      final m = read(
        jpegWith(
          _xmpSeg(
            _xmp('GCamera:MotionPhoto="1" GCamera:MotionPhotoVersion="1"'),
          ),
        ),
      );
      expect(m.embeddedVideo, true);
    });

    test('photo sphere, depth and the photo before the blur', () {
      final r = read(
        jpegWith(
          _xmpSeg(
            _xmp(
              'GPano:ProjectionType="equirectangular" GDepth:Format="RangeInverse" GImage:Mime="image/jpeg"',
            ),
          ),
        ),
      );
      expect(r.sphere, true);
      expect(r.depthMap, true);
      expect(r.beforeBlur, true);
    });

    test('xmp names the device, the software and the edits', () {
      final r = read(
        jpegWith(
          _xmpSeg(
            _xmp(
              'tiff:Make="Google" tiff:Model="Pixel 8" xmp:CreatorTool="GIMP 2.10" '
              'xmpMM:OriginalDocumentID="xmp.did:5d64"',
            ),
          ),
        ),
      );
      expect(r.make, 'Google');
      expect(r.model, 'Pixel 8');
      expect(r.software, 'GIMP 2.10');
      expect(r.editHistory, true);
    });

    test('an mpf index names the extra pictures, not the hdr layer', () {
      List<int> mpf(int n) {
        // little endian tiff: one entry, 0xB001, the number of images
        return seg(0xE2, [
          ...t('MPF'), 0, //
          0x49, 0x49, 0x2A, 0x00, ...le32(8),
          ...le16(1), ...le16(0xB001), ...le16(4), ...le32(1), ...le32(n),
          ...le32(0),
        ]);
      }

      expect(read(jpegWith(mpf(3))).extraPictures, 2);
      final hdr = _xmpSeg(_xmp('hdrgm:Version="1.0"'));
      expect(read(jpegWith([...hdr, ...mpf(2)])).extraPictures, 0);
    });

    test('a samsung trailer gives its blocks and the network country', () {
      final r = read(
        jpegWith(
          const [],
          trailer: sefTrailer([
            ('Image_UTC_Data', t('1761134000123')),
            ('MCC_Data', t('262')),
          ]),
        ),
      );
      expect(r.networkCountry, '262');
      expect(r.sefEntries, ['Image_UTC_Data', 'MCC_Data']);
      expect(r.trailingBytes, greaterThan(0));
    });

    test('an apple maker note gives the live photo id', () {
      const id = 'A1B2C3D4-0000-1111-2222-333344445555';
      final note = [
        ...t('Apple iOS'), 0, 0, 1, ...t('MM'), //
        ...be16(1),
        ...be16(0x0011), ...be16(2), ...be32(id.length + 1), ...be32(32),
        ...be32(0),
        ...t(id), 0,
      ];
      final b = TiffBuilder();
      final tiff = b.build(
        ifd0: [b.ascii(0x010F, 'Apple')],
        exif: [b.undefined(0x927C, note)],
      );
      expect(read(jpeg(tiff: tiff)).liveId, id);
    });
  });

  group('heif', () {
    test('thumbnail, depth, matte and a second picture are named', () {
      final r = read(
        heifOf(
          [
            pic,
            const HeifPart(2, 'hvc1', [5, 6]),
            const HeifPart(3, 'hvc1', [
              7,
              8,
            ], aux: 'urn:com:apple:photo:2018:aux:depth'),
            const HeifPart(4, 'hvc1', [
              9,
              9,
            ], aux: 'urn:com:apple:photo:2019:aux:semanticskinmatte'),
            const HeifPart(5, 'hvc1', [8, 7]),
          ],
          refs: [
            ('thmb', 2, [1]),
            ('auxl', 3, [1]),
            ('auxl', 4, [1]),
          ],
        ),
      );
      expect(r.status, MetaStatus.found);
      expect(r.smallCopies, 1);
      expect(r.depthMap, true);
      expect(r.portraitMatte, true);
      expect(r.extraPictures, 1);
    });

    test('an alpha plane is part of the picture', () {
      final r = read(
        heifOf(
          [
            pic,
            const HeifPart(2, 'av01', [
              5,
              6,
            ], aux: 'urn:mpeg:mpegB:cicp:systems:auxiliary:alpha'),
          ],
          refs: [
            ('auxl', 2, [1]),
          ],
          brand: 'avif',
        ),
      );
      expect(r.status, MetaStatus.nothing);
    });

    test('gain maps, apple and iso, are the hdr layer', () {
      final apple = read(
        heifOf(
          [
            pic,
            const HeifPart(2, 'hvc1', [
              5,
              6,
            ], aux: 'urn:com:apple:photo:2020:aux:hdrgainmap'),
          ],
          refs: [
            ('auxl', 2, [1]),
          ],
        ),
      );
      expect(apple.hdrLayer, true);
      expect(apple.extraPictures, 0);
      final iso = read(
        heifOf(
          [
            pic,
            const HeifPart(2, 'av01', [5, 6]),
            const HeifPart(3, 'tmap', [0, 0]),
          ],
          refs: [
            ('dimg', 3, [1, 2]),
          ],
          brand: 'avif',
        ),
      );
      expect(iso.hdrLayer, true);
      expect(iso.extraPictures, 0);
    });

    test('mdat bytes no item uses are left over', () {
      final r = read(heifOf([pic], mdatTail: t('old exif')));
      expect(r.leftoverBytes, 8);
      expect(
        read(heifOf([pic], mdatTail: [0, 0, 0])).status,
        MetaStatus.nothing,
      );
    });

    test('a motion clip box is a motion clip', () {
      expect(
        read(heifOf([pic], after: box('mpvd', [1, 2, 3]))).embeddedVideo,
        true,
      );
    });

    test('a compact heif is not passed as read', () {
      final b = [
        ...box('ftyp', [...t('mif3'), ...be32(0), ...t('mif3'), ...t('avif')]),
        ...box('mini', List.filled(20, 1)),
      ];
      expect(read(b).status, MetaStatus.unreadable);
    });
  });

  group('video', () {
    test('free space with old bytes is left over', () {
      final b = [...mp4(), ...box('free', t('old place'))];
      expect(read(b).leftoverBytes, 9);
      expect(
        read([
          ...mp4(),
          ...box('free', [0, 0]),
        ]).status,
        MetaStatus.nothing,
      );
    });

    test('a named handler is found', () {
      expect(read(mp4(handlerName: 'Core Media Video')).handlerNames, true);
      expect(read(mp4()).handlerNames, false);
    });

    test('an unknown top level box is found', () {
      final r = read([...mp4(), ...box('junk', t('x'))]);
      expect(r.extra, ['junk box']);
    });
  });
}
