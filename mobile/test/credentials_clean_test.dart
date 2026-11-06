// content credentials and generator tags, on files signed by c2patool
// (fixtures/SOURCES.md), with xmp, iptc, prompt text and a named colour
// profile added the way generators and screens write them
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/image_strip.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/icc.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/tools/cleaner.dart';

import 'meta_fixtures.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/credentials/$name').readAsBytesSync();

const _xmp =
    '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF '
    'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
    '<rdf:Description '
    'xmlns:Iptc4xmpExt="http://iptc.org/std/Iptc4xmpExt/2008-02-29/" '
    'xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'Iptc4xmpExt:DigitalSourceType="http://cv.iptc.org/newscodes/'
    'digitalsourcetype/trainedAlgorithmicMedia" '
    'photoshop:Credit="Made with Imagen" '
    'xmp:CreatorTool="Adobe Firefly">'
    '<dc:creator>Midjourney</dc:creator>'
    '<dc:description>DALL-E prompt, SynthID</dc:description>'
    '</rdf:Description></rdf:RDF></x:xmpmeta>';

const _sd =
    'a cat on a roof\nNegative prompt: blurry\nSteps: 20, Sampler: Euler a, '
    'CFG scale: 7, Seed: 1, Size: 32x32, Model: sd_xl_base_1.0';
const _comfyPrompt = '{"3": {"class_type": "KSampler", "inputs": {"seed": 1}}}';
const _comfyFlow = '{"last_node_id": 9, "nodes": [{"type": "KSampler"}]}';

// what must not be in a cleaned file
const _traces = [
  'jumb',
  'c2pa',
  'C2PA',
  'xmpmeta',
  'trainedAlgorithmic',
  'Image Generator',
  'Imagen',
  'Firefly',
  'Midjourney',
  'DALL-E',
  'SynthID',
  'Negative prompt',
  'KSampler',
  'DELL U2720Q',
  'Studio Display',
  'Calibrated by',
];

List<String> _found(Uint8List b) {
  final s = latin1.decode(b);
  final u = String.fromCharCodes([
    for (var i = 0; i + 1 < b.length; i += 2) b[i] << 8 | b[i + 1],
  ]);
  final u2 = b.length < 2
      ? ''
      : String.fromCharCodes([
          for (var i = 1; i + 1 < b.length; i += 2) b[i] << 8 | b[i + 1],
        ]);
  return [
    for (final x in _traces)
      if (s.contains(x) || u.contains(x) || u2.contains(x)) x,
  ];
}

// a version 2 profile whose text names a screen, with or without the v4
// text type, or a standard one
Uint8List _icc({bool v4 = false, String desc = 'DELL U2720Q'}) {
  List<int> descTag(String s) {
    final a = [...latin1.encode(s), 0];
    return [
      ...t('desc'),
      0,
      0,
      0,
      0,
      ...be32(a.length),
      ...a,
      ...List.filled(4 + 4 + 2 + 1 + 67, 0),
    ];
  }

  List<int> mluc(String s) {
    final u = [
      for (final c in s.codeUnits) ...[c >> 8, c & 255],
    ];
    return [
      ...t('mluc'), 0, 0, 0, 0, ...be32(1), ...be32(12), //
      ...t('en'), ...t('US'), ...be32(u.length), ...be32(28), ...u,
    ];
  }

  List<int> text(String s) => [...t('text'), 0, 0, 0, 0, ...t(s), 0];
  List<int> xyz() => [...t('XYZ '), 0, 0, 0, 0, ...List.filled(12, 1)];
  final tags = <(String, List<int>)>[
    ('desc', v4 ? mluc(desc) : descTag(desc)),
    ('cprt', v4 ? mluc('Calibrated by Mario') : text('Calibrated by Mario')),
    ('dmdd', v4 ? mluc('Studio Display') : descTag('Studio Display')),
    ('wtpt', xyz()),
  ];
  final table = <int>[];
  final data = <int>[];
  var at = 132 + 12 * tags.length;
  for (final (sig, d) in tags) {
    final padded = [...d, ...List.filled((4 - d.length % 4) % 4, 0)];
    table.addAll([...t(sig), ...be32(at), ...be32(d.length)]);
    data.addAll(padded);
    at += padded.length;
  }
  final head = <int>[
    ...be32(at), ...t('lcms'), v4 ? 4 : 2, 0x10, 0, 0, //
    ...t('mntr'), ...t('RGB '), ...t('XYZ '),
    0x07, 0xE6, 0, 11, 0, 6, 0, 9, 0, 30, 0, 0, // 2026-11-06 09:30
    ...t('acsp'), ...t('APPL'), 0, 0, 0, 0, ...t('APPL'), ...t('ae23'),
    ...List.filled(8, 0), 0, 0, 0, 0, // attributes, intent
    0, 0, 0xF6, 0xD6, 0, 1, 0, 0, 0, 0, 0xD3, 0x2D, // d50
    ...t('lcms'), ...List.filled(16, 7), ...List.filled(28, 0),
  ];
  assert(head.length == 128);
  return Uint8List.fromList([...head, ...be32(tags.length), ...table, ...data]);
}

// ---- adding to a real file ----

Uint8List _jpegPlus(Uint8List src, Uint8List icc) {
  final iptc = [
    ...t('Photoshop 3.0'), 0, ...t('8BIM'), 0x04, 0x04, 0, 0, //
    ...be32(25), 0x1C, 2, 120, 0, 20, ...t('Made with Imagen    '), 0,
  ];
  final iccSeg = <int>[];
  // in two pieces, as a big profile is written
  final half = icc.length ~/ 2;
  for (final (n, a, b) in [(1, 0, half), (2, half, icc.length)]) {
    iccSeg.addAll(
      seg(0xE2, [...t('ICC_PROFILE'), 0, n, 2, ...icc.sublist(a, b)]),
    );
  }
  return Uint8List.fromList([
    ...src.sublist(0, 2),
    ...seg(0xE1, [...t('http://ns.adobe.com/xap/1.0/'), 0, ...t(_xmp)]),
    ...seg(0xED, iptc),
    ...iccSeg,
    ...seg(0xFE, t('Midjourney')),
    ...src.sublist(2),
  ]);
}

Uint8List _pngPlus(Uint8List src, Uint8List icc) {
  final end = src.length - 12; // IEND
  return Uint8List.fromList([
    ...src.sublist(0, 33), // signature and IHDR
    ...pngChunk('iCCP', [...t('ICC profile'), 0, 0, ...zlib.encode(icc)]),
    ...src.sublist(33, end),
    ...pngChunk('tEXt', [...t('parameters'), 0, ...t(_sd)]),
    ...pngChunk('tEXt', [...t('prompt'), 0, ...t(_comfyPrompt)]),
    ...pngChunk('tEXt', [...t('workflow'), 0, ...t(_comfyFlow)]),
    ...pngChunk('iTXt', [...t('Description'), 0, 0, 0, 0, 0, ...t('Job ID')]),
    ...pngChunk('iTXt', [...t('XML:com.adobe.xmp'), 0, 0, 0, 0, 0, ...t(_xmp)]),
    ...src.sublist(end),
  ]);
}

Uint8List _webpPlus(Uint8List src, Uint8List icc) {
  // a plain vp8 file: an extended header goes in front, then the profile
  expect(latin1.decode(src.sublist(12, 16)), 'VP8 ');
  final w = (src[26] | src[27] << 8) & 0x3FFF;
  final h = (src[28] | src[29] << 8) & 0x3FFF;
  final body = [
    ...riffChunk('VP8X', [
      0x20 | 0x04, 0, 0, 0, // icc, xmp
      (w - 1) & 255, (w - 1) >> 8, 0, (h - 1) & 255, (h - 1) >> 8, 0,
    ]),
    ...riffChunk('ICCP', icc),
    ...src.sublist(12),
    ...riffChunk('XMP ', t(_xmp)),
  ];
  return Uint8List.fromList([
    ...t('RIFF'),
    ...le32(4 + body.length),
    ...t('WEBP'),
    ...body,
  ]);
}

Uint8List _gifPlus(Uint8List src) {
  final xmp = [...t(_xmp), 1, for (var i = 255; i >= 0; i--) i];
  final text = [
    0x21,
    0x01,
    12,
    ...List.filled(12, 0),
    10,
    ...t('Midjourney'),
    0,
  ];
  return Uint8List.fromList([
    ...src.sublist(0, src.length - 1),
    0x21, 0xFE, 10, ...t('Midjourney'), 0, // comment
    ...text,
    0x21, 0xFF, 11, ...t('XMP DataXMP'), ...xmp, 0,
    0x3B,
  ]);
}

// the c2pa store out of a signed jpeg's app11 segments
Uint8List _store(Uint8List jpeg) {
  final out = BytesBuilder();
  var i = 2;
  while (jpeg[i + 1] != 0xDA) {
    final len = jpeg[i + 2] << 8 | jpeg[i + 3];
    if (jpeg[i + 1] == 0xEB) {
      final body = jpeg.sublist(i + 4, i + 2 + len);
      // the first piece keeps the store's own box header
      out.add(out.isEmpty ? body.sublist(8) : body.sublist(16));
    }
    i += 2 + len;
  }
  return out.toBytes();
}

List<int> _uuid(String hex, List<int> body) => box('uuid', [
  for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ...body,
]);

Future<(int, int, Uint8List)> _pixels(Uint8List b) async {
  final codec = await ui.instantiateImageCodec(b);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (img.width, img.height, data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('credentials'));
  tearDown(() => tmp.deleteSync(recursive: true));

  final named = _icc();
  final cases = <String, Uint8List Function()>{
    'credentials.jpg': () => _jpegPlus(_fixture('credentials.jpg'), named),
    'credentials.png': () => _pngPlus(_fixture('credentials.png'), named),
    'credentials.webp': () =>
        _webpPlus(_fixture('credentials.webp'), _icc(v4: true)),
    'credentials.gif': () => _gifPlus(_fixture('credentials.gif')),
    'credentials.heic': () => _fixture('credentials.heic'),
    'credentials.avif': () => _fixture('credentials.avif'),
    'c2pa_dashinit.mp4': () => _fixture('c2pa_dashinit.mp4'),
    'gopro with credentials.mp4': () {
      final store = _store(_fixture('credentials.jpg'));
      return Uint8List.fromList([
        ...File('test/fixtures/gopro_hero5_cut.mp4').readAsBytesSync(),
        ..._uuid('d8fec3d61b0e483c92975828877ec481', [0, 0, 0, 0, ...store]),
        ..._uuid('be7acfcb97a942e89c71999491e3afac', t(_xmp)),
      ]);
    },
  };

  test('the signed files are as c2patool wrote them', () {
    for (final e in [
      'credentials.jpg',
      'credentials.png',
      'credentials.webp',
      'credentials.gif',
      'credentials.heic',
      'credentials.avif',
    ]) {
      final r = readMeta(MemorySource(_fixture(e)));
      expect(r.credentials, isTrue, reason: e);
      expect(r.syntheticLabel, isTrue, reason: e);
      expect(_found(_fixture(e)), contains('jumb'), reason: e);
    }
  });

  for (final MapEntry(key: name, value: make) in cases.entries) {
    test('$name: nothing of the credentials or tags is left', () async {
      final src = make();
      final before = readMeta(MemorySource(src));
      expect(before.credentials, isTrue);
      if (!name.endsWith('.mp4')) expect(before.syntheticLabel, isTrue);
      expect(_found(src), isNotEmpty);
      final path = '${tmp.path}/$name';
      File(path).writeAsBytesSync(src);
      final r = await cleanFileHere(path, '${tmp.path}/out', name);
      expect(r.failure, isNull);
      final out = File(r.path!).readAsBytesSync();
      expect(_found(out), isEmpty);
      expect(readFile(r.path!).status, MetaStatus.nothing);
      expect(readMetaStrict(MemorySource(out)).status, MetaStatus.nothing);
      expect(removedLines(r.before), isNotEmpty);
    });
  }

  test('png prompt fields and the synthetic label are found before', () {
    final r = readMeta(MemorySource(cases['credentials.png']!()));
    expect(
      r.syntheticPrompt,
      containsAll(['parameters', 'prompt', 'workflow']),
    );
    expect(r.syntheticPrompt, contains('Description'));
    expect(r.madeWith, 'Image Generator');
  });

  test('gif credentials are read for what they say', () {
    final r = readMeta(MemorySource(_fixture('credentials.gif')));
    expect(r.madeWith, 'Image Generator');
    expect(r.comment, isFalse);
    final plus = readMeta(MemorySource(cases['credentials.gif']!()));
    expect(plus.comment, isTrue);
    expect(plus.xmp, isTrue);
  });

  testWidgets('the cleaned pictures are the same pictures', (tester) async {
    await tester.runAsync(() async {
      for (final n in [
        'credentials.jpg',
        'credentials.png',
        'credentials.webp',
        'credentials.gif',
      ]) {
        final src = cases[n]!();
        final out = stripPictureBytes(src)!;
        final a = await _pixels(src);
        final b = await _pixels(out);
        expect((b.$1, b.$2), (a.$1, a.$2), reason: n);
        expect(b.$3, a.$3, reason: n);
      }
    });
  });

  group('colour profile', () {
    test('a named one is made blank in place, the same size', () {
      for (final v4 in [false, true]) {
        final p = _icc(v4: v4);
        final c = scrubIcc(p);
        expect(identical(c, p), isFalse);
        expect(c.length, p.length);
        expect(_found(c), isEmpty);
        // colour data and the tag table stay
        expect(c.sublist(128, 180), p.sublist(128, 180));
        expect(c.sublist(64, 84), p.sublist(64, 84));
        expect(c.sublist(48, 56), everyElement(0));
        expect(identical(scrubIcc(c), c), isTrue);
        expect(iccNamesSomething(c), isFalse);
      }
    });

    test('a standard one stays as it is', () {
      final p = _icc(desc: 'sRGB IEC61966-2.1');
      expect(identical(scrubIcc(p), p), isTrue);
      final png = _pngPlus(_fixture('credentials.png'), p);
      final r = readMeta(MemorySource(png));
      expect(r.extra, isNot(contains('colour profile name')));
      final out = stripPictureBytes(png)!;
      final s = latin1.decode(out);
      expect(s.contains('iCCP'), isTrue);
    });

    test('one that is not a profile is left alone', () {
      final junk = Uint8List.fromList(List.filled(300, 9));
      expect(identical(scrubIcc(junk), junk), isTrue);
    });

    test('the reader names it, and the clean copy keeps a profile', () {
      for (final n in [
        'credentials.jpg',
        'credentials.png',
        'credentials.webp',
      ]) {
        final src = cases[n]!();
        expect(
          readMeta(MemorySource(src)).extra,
          contains('colour profile name'),
          reason: n,
        );
        final out = stripPictureBytes(src)!;
        final s = latin1.decode(out);
        expect(
          s.contains('ICC_PROFILE') || s.contains('iCCP') || s.contains('ICCP'),
          isTrue,
          reason: n,
        );
      }
    });
  });
}
