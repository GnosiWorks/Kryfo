// sample tables from a stranger's file: counts that claim billions of
// samples, runs that walk back, tables that ask for gigabytes. each is
// refused at once, never walked, and never read whole.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/mp4_strip.dart';

import 'meta_fixtures.dart';

const _fast = Timeout(Duration(seconds: 5));

Future<void> _refused(Uint8List b) async {
  expect(readMeta(MemorySource(b)).status, MetaStatus.unreadable);
  final dir = await Directory.systemTemp.createTemp('hostile');
  final f = File('${dir.path}/v.mp4')..writeAsBytesSync(b);
  expect(await stripMp4Metadata(f.path), null);
  await dir.delete(recursive: true);
}

void main() {
  test('a fragment run of four billion samples is not walked', () async {
    final moov = box('moov', [
      ...full('mvhd', 0, List.filled(96, 0)),
      ...box('trak', [
        ...full('tkhd', 0, [
          ...List.filled(8, 0),
          ...be32(1),
          ...List.filled(68, 0),
        ]),
        ...box('mdia', [
          ...full('hdlr', 0, [...be32(0), ...t('vide'), ...List.filled(13, 0)]),
        ]),
      ]),
      ...box('mvex', [
        ...full('trex', 0, [
          ...be32(1),
          ...be32(1),
          ...be32(0),
          ...be32(0),
          ...be32(0),
        ]),
      ]),
    ]);
    // a run with no per-sample fields: every sample takes the default size
    final moof = box('moof', [
      ...full('mfhd', 0, be32(1)),
      ...box('traf', [
        ...box('tfhd', [0, 2, 0, 0, ...be32(1)]),
        ...full('trun', 0, be32(0xFFFFFFFF)),
      ]),
    ]);
    await _refused(
      Uint8List.fromList([
        ...box('ftyp', [...t('iso6'), ...be32(0), ...t('iso6')]),
        ...moov,
        ...moof,
        ...box('mdat', [1, 2, 3]),
      ]),
    );
  }, timeout: _fast);
}
