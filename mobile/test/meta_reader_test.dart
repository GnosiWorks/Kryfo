import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/image_strip.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/file_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/mp4_strip.dart';

import 'meta_fixtures.dart';

MetaReport read(Uint8List b) => readMetaStrict(MemorySource(b));

void expectAthens(GpsFix? g, String from) {
  expect(g, isNotNull);
  expect(g!.lat, closeTo(37.9755, 0.001));
  expect(g.lon, closeTo(23.7275, 0.001));
  expect(g.from, from);
}

void main() {
  group('jpeg', () {
    for (final le in [true, false]) {
      test('camera exif, ${le ? 'little' : 'big'} endian', () {
        final r = read(jpeg(tiff: cameraTiff(le: le)));
        expect(r.kind, MetaKind.jpeg);
        expect(r.status, MetaStatus.found);
        expectAthens(r.gps, 'exif');
        expect(r.gps!.altitude, closeTo(157, 0.01));
        expect(r.make, 'samsung');
        expect(r.model, 'SM-A536B');
        expect(r.software, 'A536BXXU4');
        expect(r.lens, 'Samsung S5KGW3');
        expect(r.taken, '2026:09:17 18:09:48');
        expect(r.offset, '+03:00');
        expect(r.orientation, 6);
        expect(r.makerNote, true);
        expect(r.thumbnailBytes, 10);
      });
    }

    test('south and west are negative', () {
      final r = read(jpeg(tiff: cameraTiff(south: true)));
      expect(r.gps!.lat, lessThan(0));
    });

    test('xmp, iptc, comment, second image, trailer', () {
      final r = read(
        jpeg(
          xmp: xmpGps,
          iptc: true,
          comment: true,
          mpf: true,
          trailer: t('SEFHxxxxSEFT'),
        ),
      );
      expect(r.status, MetaStatus.found);
      expect(r.xmp, true);
      expectAthens(r.gps, 'xmp');
      expect(r.iptc, true);
      expect(r.comment, true);
      expect(r.secondImage, true);
      expect(r.trailingBytes, 12);
      expect(r.extra, contains('samsung trailer'));
    });

    test('a motion photo is seen', () {
      final r = read(jpeg(trailer: [0, 0, 0, 24, ...t('ftypmp42'), 1, 2, 3]));
      expect(r.embeddedVideo, true);
    });

    test('found nothing is not the same as could not read', () {
      final clean = read(jpeg());
      expect(clean.status, MetaStatus.nothing);
      final cut = read(jpeg(eoi: false));
      expect(cut.status, MetaStatus.unreadable);
      expect(cut.why, isNotNull);
    });

    test('which way up, alone, is nothing', () {
      final r = read(jpeg(tiff: orientationOnlyTiff(6)));
      expect(r.status, MetaStatus.nothing);
      expect(r.orientation, 6);
    });

    test('a blanked location says so', () {
      final tiff = cameraTiff();
      final s = String.fromCharCodes(tiff);
      final at = s.indexOf(String.fromCharCodes([37, 0, 0, 0, 1, 0, 0, 0]));
      expect(at, greaterThan(0));
      final b = Uint8List.fromList(tiff)..fillRange(at, at + 48, 0);
      final r = read(jpeg(tiff: b));
      expect(r.gps, isNull);
      expect(r.gpsBlank, true);
      expect(r.status, MetaStatus.found);
    });
  });

  test('png: exif, xmp, text keys, save time, credentials, trailer', () {
    final r = read(
      png(
        tiff: cameraTiff(),
        xmp: xmpGps,
        text: true,
        time: true,
        credentials: true,
        trailer: [1, 2, 3],
      ),
    );
    expect(r.kind, MetaKind.png);
    expectAthens(r.gps, 'exif');
    expect(r.xmp, true);
    expect(r.textKeys, ['parameters']);
    expect(r.savedTime, true);
    expect(r.credentials, true);
    expect(r.trailingBytes, 3);
    expect(read(png()).status, MetaStatus.nothing);
  });

  test('webp: exif and xmp chunks', () {
    final r = read(webp(tiff: cameraTiff(), xmp: xmpGps));
    expect(r.kind, MetaKind.webp);
    expectAthens(r.gps, 'exif');
    expect(r.xmp, true);
    expect(read(webp()).status, MetaStatus.nothing);
  });

  test('heif: the exif and xmp items', () {
    final r = read(heif(tiff: cameraTiff(), xmp: xmpGps));
    expect(r.kind, MetaKind.heif);
    expectAthens(r.gps, 'exif');
    expect(r.model, 'SM-A536B');
    expect(r.xmp, true);
    expect(read(heif()).status, MetaStatus.nothing);
  });

  group('mp4', () {
    test('place, maker and the creation stamp', () {
      final r = read(mp4(place: true, maker: true, created: 3840000000));
      expect(r.kind, MetaKind.mp4);
      expect(r.gps!.lat, closeTo(37.9838, 1e-6));
      expect(r.gps!.lon, closeTo(23.7275, 1e-6));
      expect(r.make, 'samsung');
      expect(r.created!.year, 2025);
      expect(r.stamps, true);
      expect(r.videoTags.length, 2);
    });

    test('quicktime keys', () {
      final r = read(mp4(keys: true));
      expect(r.gps!.lat, closeTo(-33.8568, 1e-6));
      expect(r.gps!.lon, closeTo(151.2153, 1e-6));
      expect(r.gps!.altitude, closeTo(12, 1e-6));
      expect(r.model, 'iPhone 15');
    });

    test('a uuid box counts, a clean file is nothing', () {
      expect(read(mp4(uuid: true)).status, MetaStatus.found);
      expect(read(mp4()).status, MetaStatus.nothing);
    });
  });

  test('not a picture or a video is unknown, not unreadable', () {
    final r = read(
      Uint8List.fromList(t('%PDF-1.7 just a document, long enough')),
    );
    expect(r.status, MetaStatus.unknown);
  });

  group('what the cleaner leaves', () {
    final loud = {
      'jpeg': jpeg(
        tiff: cameraTiff(),
        xmp: xmpGps,
        iptc: true,
        comment: true,
        mpf: true,
        trailer: t('SEFHxxxxSEFT'),
      ),
      'png': png(
        tiff: cameraTiff(),
        xmp: xmpGps,
        text: true,
        time: true,
        credentials: true,
        trailer: [1, 2, 3],
      ),
      'webp': webp(tiff: cameraTiff(), xmp: xmpGps),
      'heif': heif(tiff: cameraTiff(), xmp: xmpGps),
    };
    loud.forEach((name, bytes) {
      test('$name comes out with nothing the reader can find', () {
        expect(read(bytes).status, MetaStatus.found);
        final out = stripPictureBytes(bytes)!;
        final r = read(out);
        expect(r.status, MetaStatus.nothing, reason: '${r.extra} ${r.why}');
      });
    });

    test('a portrait jpeg keeps its turn and still reads as nothing', () {
      final out = stripPictureBytes(jpeg(tiff: cameraTiff()))!;
      final r = read(out);
      expect(r.status, MetaStatus.nothing);
      expect(r.orientation, 6);
    });

    test('mp4, through a file', () async {
      final d = await Directory.systemTemp.createTemp('meta');
      final f = File('${d.path}/v.mp4');
      await f.writeAsBytes(
        mp4(
          place: true,
          maker: true,
          keys: true,
          created: 3840000000,
          uuid: true,
        ),
      );
      final before = FileSource.open(f.path);
      expect(readMeta(before).status, MetaStatus.found);
      before.close();
      expect(await stripMp4Metadata(f.path), true);
      final after = FileSource.open(f.path);
      final r = readMeta(after);
      after.close();
      expect(
        r.status,
        MetaStatus.nothing,
        reason: '${r.videoTags} ${r.stamps}',
      );
      await d.delete(recursive: true);
    });
  });

  group('hostile input never throws', () {
    final samples = <String, Uint8List>{
      'jpeg': jpeg(tiff: cameraTiff(), xmp: xmpGps, mpf: true, trailer: [1, 2]),
      'png': png(tiff: cameraTiff(), xmp: xmpGps, text: true),
      'webp': webp(tiff: cameraTiff(), xmp: xmpGps),
      'heif': heif(tiff: cameraTiff(), xmp: xmpGps),
      'mp4': mp4(place: true, maker: true, keys: true, created: 5),
    };

    samples.forEach((name, bytes) {
      test('$name cut at every length', () {
        for (var n = 0; n < bytes.length; n++) {
          final r = read(Uint8List.sublistView(bytes, 0, n));
          expect(MetaStatus.values, contains(r.status));
        }
      });

      test('$name with bytes flipped', () {
        final rnd = Random(name.hashCode);
        for (var i = 0; i < 3000; i++) {
          final b = Uint8List.fromList(bytes);
          for (var k = 0; k < 1 + rnd.nextInt(4); k++) {
            b[rnd.nextInt(b.length)] = rnd.nextInt(256);
          }
          read(b);
        }
      });
    });

    test('noise behind each signature', () {
      final rnd = Random(7);
      final heads = [
        [0xFF, 0xD8, 0xFF],
        pngSig,
        [...t('RIFF'), 0, 0, 0, 0, ...t('WEBP')],
        [0, 0, 0, 24, ...t('ftypheic'), 0, 0, 0, 0, ...t('mif1heic')],
        [0, 0, 0, 24, ...t('ftypisom'), 0, 0, 0, 0, ...t('isommp42')],
        t('GIF89a'),
      ];
      for (final h in heads) {
        for (var i = 0; i < 400; i++) {
          final n = rnd.nextInt(600);
          read(
            Uint8List.fromList([
              ...h,
              for (var k = 0; k < n; k++) rnd.nextInt(256),
            ]),
          );
        }
      }
    });

    test('an exif that loops on itself ends', () {
      final tiff = Uint8List.fromList([
        0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, //
        0x01, 0x00,
        0x69, 0x87, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00,
        0x08, 0x00, 0x00, 0x00,
      ]);
      expect(read(jpeg(tiff: tiff)).status, isNot(MetaStatus.unknown));
    });

    test('a box that claims the whole disk is unreadable, not a read', () {
      final b = Uint8List.fromList([
        0,
        0,
        0,
        24,
        ...t('ftypisom'),
        0,
        0,
        0,
        0,
        ...t('isommp42'),
        0,
        0,
        0,
        1,
        ...t('moov'),
        0x7F,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
      ]);
      expect(read(b).status, MetaStatus.unreadable);
    });
  });
}
