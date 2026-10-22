// a real action camera clip: its gps, accelerometer and gyro readings ride
// in a track of their own (gopro gpmd), beside a timecode track and a
// firmware track. the cleaner drops all three with their samples and keeps
// every byte of the picture and sound. fixture: test/fixtures/SOURCES.md
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/meta/mp4_tracks.dart';
import 'package:kryfo/mp4_strip.dart';
import 'package:kryfo/tools/cleaner.dart';

final _src = File('test/fixtures/gopro_hero5_cut.mp4').readAsBytesSync();

Future<File> _copy() async {
  final dir = await Directory.systemTemp.createTemp('gpstrack');
  return File('${dir.path}/clip.mp4')..writeAsBytesSync(_src);
}

void main() {
  test('the reader finds the gps and motion track', () {
    final r = readMeta(MemorySource(_src));
    expect(r.status, MetaStatus.found);
    expect(r.extraTracks, 2);
    expect(r.timecode, true);
    expect(r.gpsPoints, greaterThan(0));
    expect(r.motionSensors, true);
    expect(r.leftoverBytes, greaterThan(0));
  });

  test('the cleaned copy has no data tracks and reads as nothing', () async {
    final f = await _copy();
    expect(await stripMp4Metadata(f.path), true);
    expect(await mp4MetadataCount(f.path), 0);
    final out = f.readAsBytesSync();
    expect(out.length, _src.length);
    final r = readMeta(MemorySource(out));
    expect(r.status, MetaStatus.nothing);
    expect(r.handlerNames, false);
    expect(r.gpsPoints, 0);
    expect(r.extraTracks, 0);
    expect(r.timecode, false);
    expect(r.motionSensors, false);
    expect(r.leftoverBytes, 0);
    final lay = readMp4Layout(MemorySource(out));
    expect(lay.tracks.map((t) => t.handler), ['vide', 'soun']);
  });

  test('picture and sound samples stay byte for byte', () async {
    final f = await _copy();
    await stripMp4Metadata(f.path);
    final out = f.readAsBytesSync();
    final before = readMp4Layout(MemorySource(_src));
    var kept = 0;
    for (final t in before.tracks.where((t) => t.kept)) {
      for (final (a, b) in t.samples.merged) {
        expect(out.sublist(a, b), _src.sublist(a, b));
        kept += b - a;
      }
    }
    expect(kept, greaterThan(300000));
    // and the gps samples are gone
    final gpmd = before.tracks.firstWhere((t) => t.format == 'gpmd');
    for (final (a, b) in gpmd.samples.merged) {
      expect(out.sublist(a, b).every((x) => x == 0), true);
    }
    expect(_has(out, 'GPS5'), false);
    expect(_has(_src, 'GPS5'), true);
    // the handler and compressor names named the camera
    expect(_has(_src, 'GoPro AVC encoder'), true);
    expect(_has(out, 'GoPro'), false);
  });

  test('the photo tool cleans it and names the location', () async {
    final dir = await Directory.systemTemp.createTemp('gpstool');
    final inPath = '${dir.path}/GOPR0001.MP4';
    File(inPath).writeAsBytesSync(_src);
    final res = await cleanFileHere(inPath, '${dir.path}/out', 'GOPR0001.MP4');
    expect(res.failure, null);
    expect(readFile(res.path!).status, MetaStatus.nothing);
    final lines = removedLines(res.before).map((l) => l.label).toList();
    expect(lines.first, l10n.cleanerLocation);
  });
}

bool _has(Uint8List b, String s) {
  final p = s.codeUnits;
  for (var i = 0; i + p.length <= b.length; i++) {
    var ok = true;
    for (var k = 0; k < p.length; k++) {
      if (b[i + k] != p[k]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}
