// the mp4 stripper renames boxes to 'free' and zeroes them in place, so the
// length and chunk offsets hold. tracks other than picture, sound and
// subtitles go whole, with their samples, and so does every mdat byte no
// kept track uses.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/meta/mp4_tracks.dart';
import 'package:kryfo/mp4_strip.dart';

import 'meta_fixtures.dart' as fx;

Uint8List box(String type, List<int> payload) {
  final b = BytesBuilder();
  final size = 8 + payload.length;
  b.add([size >> 24, (size >> 16) & 0xff, (size >> 8) & 0xff, size & 0xff]);
  b.add(type.codeUnits);
  b.add(payload);
  return b.toBytes();
}

List<int> u32(int v) => [v >> 24, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];

// version + flags, then creation and modification stamps
List<int> full(int version, List<int> stamps, [List<int> rest = const []]) => [
  version,
  0,
  0,
  0,
  ...stamps,
  ...rest,
];

List<int> fullBox(String type, List<int> body) =>
    box(type, [0, 0, 0, 0, ...body]);

// a track with one chunk per entry of [chunks]: (offset, sample sizes).
// [fixed] gives every sample one size, as quicktime sound does
List<int> trak(
  int id,
  String handler,
  String format,
  List<(int, List<int>)> chunks, {
  int fixed = 0,
  List<int> tref = const [],
  bool wide = false,
  bool compact = false,
  bool edit = false,
}) {
  final sizes = [for (final c in chunks) ...c.$2];
  final tkhd = box(
    'tkhd',
    full(0, List.filled(8, 0), [...u32(id), ...List.filled(72, 0)]),
  );
  final stsz = compact
      ? fullBox('stz2', [0, 0, 0, 8, ...u32(sizes.length), ...sizes])
      : fixed > 0
      ? fullBox('stsz', [...u32(fixed), ...u32(sizes.length)])
      : fullBox('stsz', [
          ...u32(0),
          ...u32(sizes.length),
          for (final s in sizes) ...u32(s),
        ]);
  final stsc = fullBox('stsc', [
    ...u32(chunks.length),
    for (var k = 0; k < chunks.length; k++) ...[
      ...u32(k + 1),
      ...u32(chunks[k].$2.length),
      ...u32(1),
    ],
  ]);
  final stco = wide
      ? fullBox('co64', [
          ...u32(chunks.length),
          for (final c in chunks) ...[...u32(0), ...u32(c.$1)],
        ])
      : fullBox('stco', [
          ...u32(chunks.length),
          for (final c in chunks) ...u32(c.$1),
        ]);
  final stbl = box('stbl', [
    ...fullBox('stsd', [...u32(1), ...box(format, List.filled(8, 0))]),
    ...stsz,
    ...stsc,
    ...stco,
  ]);
  final hdlr = fullBox('hdlr', [
    ...u32(0),
    ...handler.codeUnits,
    ...List.filled(13, 0),
  ]);
  final mdhd = box(
    'mdhd',
    full(0, [0, 0, 0, 0, 0, 0, 0, 0], List.filled(12, 2)),
  );
  return box('trak', [
    ...tkhd,
    if (tref.isNotEmpty)
      ...box('tref', box('tmcd', [for (final i in tref) ...u32(i)])),
    if (edit)
      ...box(
        'edts',
        fullBox('elst', [...u32(1), ...u32(900), ...u32(0), 0, 1, 0, 0]),
      ),
    ...box('mdia', [...mdhd, ...hdlr, ...box('minf', stbl)]),
  ]);
}

const picture = 'the actual picture bytes';
const gps = 'GPS5 forty-eight north eleven east';
const tc = 'TIME';
const sound = 'sound!';
const stray = 'old bytes nothing points at';

class Clip {
  final Uint8List bytes;
  final int pictureAt;
  final int gpsAt;
  final int strayAt;
  Clip(this.bytes, this.pictureAt, this.gpsAt, this.strayAt);
}

// mdat: picture, gps, timecode, sound, then bytes no track names
Clip sample({bool gpsTrack = true, bool fixedSound = false}) {
  List<int> build(int at) {
    final p = at, g = p + picture.length, t = g + gps.length;
    final s = t + tc.length;
    final mvhd = box(
      'mvhd',
      full(0, [1, 2, 3, 4, 5, 6, 7, 8], List.filled(88, 9)),
    );
    final xyz = box('©xyz', [0, 11, 0x15, 0xc7] + '+48.13+011.5/'.codeUnits);
    final moov = box('moov', [
      ...mvhd,
      ...box('udta', xyz),
      ...trak(
        1,
        'vide',
        'avc1',
        [
          (p, [10, picture.length - 10]),
        ],
        tref: [3],
      ),
      if (gpsTrack)
        ...trak(2, 'meta', 'gpmd', [
          (g, [gps.length]),
        ]),
      ...trak(3, 'tmcd', 'tmcd', [
        (t, [tc.length]),
      ]),
      ...trak(4, 'soun', fixedSound ? 'sowt' : 'mp4a', [
        (s, fixedSound ? [1, 1] : [sound.length]),
      ], fixed: fixedSound ? 1 : 0),
      ...box('meta', [
        0,
        0,
        0,
        0,
        ...fullBox('hdlr', [
          ...u32(0),
          ...'mdir'.codeUnits,
          ...List.filled(12, 0),
        ]),
        ...box('ilst', []),
      ]),
      ...box('uuid', List.filled(16, 0x77) + 'xmp'.codeUnits),
    ]);
    return [
      ...box('ftyp', 'isom'.codeUnits + [0, 0, 2, 0] + 'isom'.codeUnits),
      ...moov,
      ...box('mdat', (picture + gps + tc + sound + stray).codeUnits),
    ];
  }

  final probe = build(0);
  final mdatBody = (picture + gps + tc + sound + stray).length;
  final at = probe.length - mdatBody;
  final b = Uint8List.fromList(build(at));
  return Clip(b, at, at + picture.length, at + mdatBody - stray.length);
}

Future<File> write(Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('mp4strip');
  final f = File('${dir.path}/clip.mp4');
  await f.writeAsBytes(bytes);
  return f;
}

String text(Uint8List b) => String.fromCharCodes(b);

void main() {
  test('counts what the sample carries', () async {
    final f = await write(sample().bytes);
    // the reader's findings: udta with a place, meta, uuid, stamps, the gps
    // and timecode tracks, and mdat bytes no kept track uses
    expect(await mp4MetadataCount(f.path), greaterThan(5));
  });

  test('strips in place and keeps the picture and sound', () async {
    final src = sample();
    final f = await write(src.bytes);
    expect(await stripMp4Metadata(f.path), true);
    final out = await f.readAsBytes();
    expect(out.length, src.bytes.length);
    expect(await mp4MetadataCount(f.path), 0);
    final s = text(out);
    expect(s.contains('+48.13'), false);
    expect(s.contains('ilst'), false);
    expect(s.contains('xmp'), false);
    expect(s.contains('udta'), false);
    expect(s.contains('uuid'), false);
    // the picture and sound samples, byte for byte where they stood
    expect(
      text(out.sublist(src.pictureAt, src.pictureAt + picture.length)),
      picture,
    );
    expect(s.contains(sound), true);
  });

  test('a gps track goes with its samples', () async {
    final src = sample();
    expect(text(src.bytes).contains(gps), true);
    final f = await write(src.bytes);
    expect(await stripMp4Metadata(f.path), true);
    final out = await f.readAsBytes();
    expect(
      out.sublist(src.gpsAt, src.gpsAt + gps.length).every((b) => b == 0),
      true,
    );
    expect(text(out).contains('gpmd'), false);
    expect(text(out).contains('GPS5'), false);
    final lay = readMp4Layout(MemorySource(out));
    expect(lay.tracks.map((t) => t.handler), ['vide', 'soun']);
  });

  test('timecode goes and the reference to it with it', () async {
    final f = await write(sample().bytes);
    await stripMp4Metadata(f.path);
    final out = await f.readAsBytes();
    expect(text(out).contains(tc), false);
    expect(text(out).contains('tref'), true);
    expect(text(out).contains('tmcd'), false);
  });

  test('mdat bytes no kept track uses are zeroed', () async {
    final src = sample(gpsTrack: false);
    final f = await write(src.bytes);
    expect(await stripMp4Metadata(f.path), true);
    final out = await f.readAsBytes();
    expect(
      out.sublist(src.strayAt, src.strayAt + stray.length).every((b) => b == 0),
      true,
    );
  });

  test('quicktime sound counted in frames keeps its whole chunk', () async {
    // two samples of size 1 stand for a chunk the full sound fills
    final src = sample(fixedSound: true);
    final f = await write(src.bytes);
    expect(await stripMp4Metadata(f.path), true);
    final out = text(await f.readAsBytes());
    expect(out.contains(sound + stray), true);
  });

  test('the reader finds the gps track and calls the copy clean', () async {
    final src = sample();
    final before = readMeta(MemorySource(src.bytes));
    expect(before.why, null);
    expect(before.extraTracks, 1);
    expect(before.timecode, true);
    expect(before.leftoverBytes, greaterThan(0));
    final f = await write(src.bytes);
    await stripMp4Metadata(f.path);
    final after = readMeta(MemorySource(await f.readAsBytes()));
    expect(after.status, MetaStatus.nothing);
  });

  test('a track fragment of a dropped track goes too', () async {
    // a fragmented file: moov holds no samples, each moof names its track
    List<int> traf(int id, int dataAt, int len) => box('traf', [
      // default-base-is-moof
      ...box('tfhd', [0, 2, 0, 0, ...u32(id)]),
      ...box('trun', [0, 0, 2, 1, ...u32(1), ...u32(dataAt), ...u32(len)]),
    ]);
    List<int> emptyTrak(int id, String h, String f) => trak(id, h, f, const []);
    List<int> build(int moofAt) {
      final mvex = box('mvex', [
        ...fullBox('trex', [
          ...u32(1),
          ...u32(1),
          ...u32(0),
          ...u32(0),
          ...u32(0),
        ]),
        ...fullBox('trex', [
          ...u32(2),
          ...u32(1),
          ...u32(0),
          ...u32(0),
          ...u32(0),
        ]),
      ]);
      final moov = box('moov', [
        ...box('mvhd', full(0, List.filled(8, 0), List.filled(88, 0))),
        ...emptyTrak(1, 'vide', 'avc1'),
        ...emptyTrak(2, 'meta', 'gpmd'),
        ...mvex,
      ]);
      final head = [
        ...box('ftyp', 'iso6'.codeUnits + [0, 0, 2, 0] + 'iso6'.codeUnits),
        ...moov,
      ];
      // data offsets count from the start of the moof
      List<int> moof(int dataStart) => box('moof', [
        ...fullBox('mfhd', u32(1)),
        ...traf(1, dataStart, picture.length),
        ...traf(2, dataStart + picture.length, gps.length),
      ]);
      final probe = moof(0);
      final dataStart = probe.length + 8;
      return [
        ...head,
        ...moof(dataStart),
        ...box('mdat', (picture + gps).codeUnits),
      ];
    }

    final b = Uint8List.fromList(build(0));
    final before = readMeta(MemorySource(b));
    expect(before.extraTracks, 1);
    final f = await write(b);
    expect(await stripMp4Metadata(f.path), true);
    final out = await f.readAsBytes();
    expect(text(out).contains(picture), true);
    expect(text(out).contains(gps), false);
    expect(text(out).contains('gpmd'), false);
    expect(await mp4MetadataCount(f.path), 0);
    final lay = readMp4Layout(MemorySource(out));
    expect(lay.tracks.map((t) => t.handler), ['vide']);
  });

  test('a non-mp4 file comes back null', () async {
    final f = await write(Uint8List.fromList(List.filled(300, 0x42)));
    expect(await stripMp4Metadata(f.path), null);
    expect(await mp4MetadataCount(f.path), null);
  });

  test('a box past the end is null', () async {
    final src = sample().bytes;
    final f = await write(src.sublist(0, src.length - 10));
    expect(await stripMp4Metadata(f.path), null);
  });

  test('a sample table past the file is null', () async {
    final src = sample().bytes;
    // the last chunk offset points far past the end
    final b = Uint8List.fromList(src);
    final i = text(b).lastIndexOf('stco') + 12;
    b.setRange(i, i + 4, u32(0x7ffffff0));
    final f = await write(b);
    expect(await stripMp4Metadata(f.path), null);
    expect(await mp4MetadataCount(f.path), null);
  });

  test('stray bytes after the last box fail', () async {
    final f = await write(Uint8List.fromList(sample().bytes + [1, 2, 3]));
    expect(await mp4MetadataCount(f.path), null);
  });

  group('keep-lists', () {
    Future<Uint8List> strip(List<int> b) async {
      final f = await write(Uint8List.fromList(b));
      expect(await stripMp4Metadata(f.path), true);
      expect(await mp4MetadataCount(f.path), 0);
      return f.readAsBytes();
    }

    test('handler names are blanked', () async {
      final src = fx.mp4(handlerName: 'Core Media Video');
      expect(readMeta(MemorySource(src)).handlerNames, true);
      final out = await strip(src);
      expect(out.length, src.length);
      expect(text(out).contains('Core Media'), false);
      expect(text(out).contains('vide'), true);
    });

    test('free space is zeroed, an unknown box goes', () async {
      final src = [
        ...fx.mp4(),
        ...box('free', 'old place +48.13'.codeUnits),
        ...box('junk', 'who knows'.codeUnits),
        ...box('free', [0, 0]),
      ];
      final out = await strip(src);
      expect(out.length, src.length);
      expect(text(out).contains('+48.13'), false);
      expect(text(out).contains('who knows'), false);
      expect(text(out).contains('framesframesframes'), true);
    });

    test('a box after the last one kept is cut off', () async {
      final clean = fx.mp4();
      final out = await strip([...clean, ...box('junk', 'tail'.codeUnits)]);
      expect(out.length, clean.length);
    });

    test('a samsung trailer after the video is cut off', () async {
      final clean = fx.mp4();
      final src = [
        ...clean,
        ...fx.sefTrailer([('MCC_Data', '262'.codeUnits)]),
      ];
      expect(
        readMeta(MemorySource(Uint8List.fromList(src))).networkCountry,
        '262',
      );
      final out = await strip(src);
      expect(out.length, clean.length);
      expect(text(out).contains('SEFT'), false);
    });

    test('what a track holds besides its media goes', () async {
      final src = sample(gpsTrack: false).bytes;
      // a udta inside the video track, as some cameras write
      final i = text(src).indexOf('mdia') - 4;
      final extra = box('udta', box('©mak', [0, 4, 0, 0, ...'ACME'.codeUnits]));
      final b = Uint8List.fromList([
        ...src.sublist(0, i),
        ...extra,
        ...src.sublist(i),
      ]);
      // the trak and moov grow by it, and the chunk offsets move with mdat
      void grow(String type) {
        final at = text(b).indexOf(type) - 4;
        final n =
            (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
        b.setRange(at, at + 4, u32(n + extra.length));
      }

      grow('moov');
      grow('trak');
      var k = 0;
      while ((k = text(b).indexOf('stco', k)) >= 0) {
        final at = k + 12;
        final o =
            (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
        b.setRange(at, at + 4, u32(o + extra.length));
        k += 4;
      }
      expect(readMeta(MemorySource(b)).make, 'ACME');
      final out = await strip(b);
      expect(text(out).contains('ACME'), false);
      expect(text(out).contains(picture), true);
    });
  });

  test(
    'a second movie box is refused, by the cleaner and the reader',
    () async {
      // only the first moov is played; the second can carry a place
      final second = box(
        'moov',
        box(
          'udta',
          box('©xyz', [0, 11, 0x15, 0xc7] + '+48.13+011.5/'.codeUnits),
        ),
      );
      final b = Uint8List.fromList([...fx.mp4(), ...second]);
      expect(readMeta(MemorySource(b)).status, MetaStatus.unreadable);
      final f = await write(b);
      expect(await stripMp4Metadata(f.path), null);
      expect(await mp4MetadataCount(f.path), null);
    },
  );

  group('table shapes', () {
    // a video track and a gps track, their samples in [mdats] of bytes;
    // [bigHead] writes each mdat with a 64-bit size
    Future<Uint8List> run({
      bool wide = false,
      bool compact = false,
      bool edit = false,
      bool bigHead = false,
      bool split = false,
    }) async {
      List<int> mdat(List<int> body) => bigHead
          ? [
              ...u32(1),
              ...'mdat'.codeUnits,
              ...u32(0),
              ...u32(16 + body.length),
              ...body,
            ]
          : box('mdat', body);
      final first = split
          ? [...picture.codeUnits]
          : [...picture.codeUnits, ...gps.codeUnits];
      final second = split ? [...gps.codeUnits, ...stray.codeUnits] : <int>[];
      final head = bigHead ? 16 : 8;
      List<int> build(int at) {
        final g = split ? at + picture.length + head : at + picture.length;
        return [
          ...box('ftyp', 'isom'.codeUnits + [0, 0, 2, 0] + 'isom'.codeUnits),
          ...box('moov', [
            ...box('mvhd', full(0, List.filled(8, 0), List.filled(88, 0))),
            ...trak(
              1,
              'vide',
              'avc1',
              [
                (at, [10, picture.length - 10]),
              ],
              wide: wide,
              compact: compact,
              edit: edit,
            ),
            ...trak(
              2,
              'meta',
              'gpmd',
              [
                (g, [gps.length]),
              ],
              wide: wide,
              compact: compact,
            ),
          ]),
          ...mdat(first),
          if (split) ...mdat(second),
        ];
      }

      final probe = build(0);
      final tail = (split ? head + second.length : 0) + first.length;
      final b = Uint8List.fromList(build(probe.length - tail));
      expect(readMeta(MemorySource(b)).extraTracks, 1);
      final f = await write(b);
      expect(await stripMp4Metadata(f.path), true);
      expect(await mp4MetadataCount(f.path), 0);
      final out = await f.readAsBytes();
      expect(out.length, b.length);
      expect(text(out).contains(picture), true);
      expect(text(out).contains(gps), false);
      return out;
    }

    test('64-bit chunk offsets', () => run(wide: true));
    test('compact sample sizes', () => run(compact: true));
    test('a 64-bit mdat size', () => run(bigHead: true));
    test('samples in two mdats, old bytes in the second', () async {
      final out = await run(split: true);
      expect(text(out).contains(stray), false);
    });
    test('an edit list stays as it was', () async {
      final out = await run(edit: true);
      final at = text(out).indexOf('elst');
      // past the type, version and flags, the entry count
      expect(out.sublist(at + 12, at + 16), u32(900));
    });
  });
}
