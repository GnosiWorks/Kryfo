// the mp4 stripper never deletes a box: it renames to 'free' and zeroes in
// place, so the file keeps its length and the chunk offsets stay true. a
// synthetic file is enough to prove it - the walker only reads box headers.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/mp4_strip.dart';

Uint8List box(String type, List<int> payload) {
  final b = BytesBuilder();
  final size = 8 + payload.length;
  b.add([size >> 24, (size >> 16) & 0xff, (size >> 8) & 0xff, size & 0xff]);
  b.add(type.codeUnits);
  b.add(payload);
  return b.toBytes();
}

// version + flags, then creation and modification stamps
List<int> full(int version, List<int> stamps, [List<int> rest = const []]) =>
    [version, 0, 0, 0, ...stamps, ...rest];

Uint8List sample() {
  final b = BytesBuilder();
  b.add(box('ftyp', 'isom'.codeUnits + [0, 0, 2, 0] + 'isom'.codeUnits));
  final mvhd = box('mvhd', full(0, [1, 2, 3, 4, 5, 6, 7, 8], List.filled(88, 9)));
  final xyz = box('©xyz', [0, 11, 0x15, 0xc7] + '+48.13+011.5/'.codeUnits);
  final udta = box('udta', xyz);
  final tkhd = box('tkhd', full(1, List.filled(16, 0xab), List.filled(76, 1)));
  final mdhd = box('mdhd', full(0, [0, 0, 0, 0, 0, 0, 0, 0], List.filled(12, 2)));
  final mdia = box('mdia', mdhd);
  final trak = box('trak', Uint8List.fromList(tkhd + mdia));
  final meta = box('meta', full(0, [], 'ilst-goes-here'.codeUnits));
  final uuid = box('uuid', List.filled(16, 0x77) + 'xmp'.codeUnits);
  b.add(box('moov', Uint8List.fromList(mvhd + udta + trak + meta + uuid)));
  b.add(box('mdat', 'the actual picture bytes'.codeUnits));
  return b.toBytes();
}

Future<File> write(Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('mp4strip');
  final f = File('${dir.path}/clip.mp4');
  await f.writeAsBytes(bytes);
  return f;
}

void main() {
  test('counts what the sample carries', () async {
    final f = await write(sample());
    // udta, meta, uuid, and non-zero stamps in mvhd and tkhd; mdhd is zero
    expect(await mp4MetadataCount(f.path), 5);
  });

  test('strips in place, same length, mdat untouched, nothing left', () async {
    final src = sample();
    final f = await write(src);
    expect(await stripMp4Metadata(f.path), true);
    final out = await f.readAsBytes();
    expect(out.length, src.length);
    expect(await mp4MetadataCount(f.path), 0);
    final s = String.fromCharCodes(out);
    expect(s.contains('+48.13'), false);
    expect(s.contains('ilst'), false);
    expect(s.contains('xmp'), false);
    expect(s.contains('the actual picture bytes'), true);
    expect(s.contains('udta'), false);
    expect(s.contains('uuid'), false);
    // the renamed boxes read as free where they stood
    expect('free'.allMatches(s).length, 3);
  });

  test('a file that is not an mp4 comes back null', () async {
    final f = await write(Uint8List.fromList(List.filled(300, 0x42)));
    expect(await stripMp4Metadata(f.path), null);
    expect(await mp4MetadataCount(f.path), null);
  });

  test('a box running past the end comes back null', () async {
    final src = sample();
    final f = await write(src.sublist(0, src.length - 10));
    expect(await stripMp4Metadata(f.path), null);
  });

  test('stray bytes after the last box are not vouched for', () async {
    final f = await write(Uint8List.fromList(sample() + [1, 2, 3]));
    expect(await mp4MetadataCount(f.path), null);
  });
}
