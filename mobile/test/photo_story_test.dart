import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/tools/geo.dart';
import 'package:kryfo/tools/photo_story.dart';

import 'meta_fixtures.dart';

void main() {
  final world = GeoWorld.parse(File('assets/geo/world.bin').readAsBytesSync());
  final places = GeoPlaces.parse(
    Uint8List.fromList(
      gzip.decode(File('assets/geo/places.bin.gz').readAsBytesSync()),
    ),
  );
  MetaReport read(Uint8List b) => readMeta(MemorySource(b));

  test('a camera photo in athens', () {
    final s = storyOf(
      read(jpeg(tiff: cameraTiff())),
      world: world,
      places: places,
    );
    expect(s.head, 'Accurate to about 5 metres.');
    expect(s.tail, 'Enough to find the door.');
    expect(s.rows.first.kind, StoryRowKind.place);
    expect(s.rows.first.title.startsWith('Near '), true);
    expect(s.rows.first.title.endsWith(', Greece'), true);
    final device = s.rows.firstWhere((r) => r.kind == StoryRowKind.device);
    expect(device.title, 'Samsung SM-A536B');
    expect(deviceName('Canon', 'Canon EOS 80D'), 'Canon EOS 80D');
    expect(deviceName(null, 'Redmi 14C'), 'Redmi 14C');
    expect(device.mono, 'f/2.0 · 1/120 s');
    final time = s.rows.firstWhere((r) => r.kind == StoryRowKind.time);
    expect(time.title, 'Thursday, 17 September 2026 18:09');
    expect(time.sub, 'To the second, with the time zone');
    expect(s.rows.last.kind, StoryRowKind.more);
    expect(s.canClean, true);
    expect(s.everything.any((l) => l.startsWith('Location: 37.97')), true);
  });

  test('without the map data it still names what it can', () {
    final s = storyOf(read(jpeg(tiff: cameraTiff())));
    expect(s.rows.first.title, 'Far from any town');
  });

  test('a clean file says so and offers nothing', () {
    final s = storyOf(read(heif()));
    expect(s.head, 'This one knows nothing.');
    expect(s.rows, isEmpty);
    expect(s.canClean, false);
  });

  test('a cut file is not called clean', () {
    final whole = jpeg(tiff: cameraTiff());
    final s = storyOf(read(whole.sublist(0, whole.length - 3)));
    expect(s.head, 'This file is damaged or cut short.');
    expect(s.canClean, false);
  });

  test('a location android blanked is named as hidden, never as absent', () {
    final r = MetaReport()
      ..kind = MetaKind.jpeg
      ..status = MetaStatus.found
      ..gpsBlank = true
      ..model = 'SM-A125F';
    final s = storyOf(r);
    expect(s.head, 'Android hid the location.');
    expect(s.rows.first.kind, StoryRowKind.hidden);
    expect(s.head.contains('No location'), false);
  });

  test('far from a town, and the open sea', () {
    expect(
      placeLine(const GpsFix(0, -30, from: 't'), world, places),
      'Far from any town',
    );
    final sahara = placeLine(
      const GpsFix(23.5, 10.0, from: 't'),
      world,
      places,
    );
    expect(sahara == 'Algeria' || sahara.startsWith('About '), true);
  });
}
