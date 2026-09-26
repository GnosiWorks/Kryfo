import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/tools/geo.dart';

void main() {
  final world = GeoWorld.parse(File('assets/geo/world.bin').readAsBytesSync());
  final places = GeoPlaces.parse(
    Uint8List.fromList(
      gzip.decode(File('assets/geo/places.bin.gz').readAsBytesSync()),
    ),
  );

  test('the bundle stays inside its budget', () {
    final total =
        File('assets/geo/world.bin').lengthSync() +
        File('assets/geo/places.bin.gz').lengthSync();
    expect(total < 2 * 1024 * 1024, true);
    expect(world.countries.length > 170, true);
    expect(places.all.length > 25000, true);
  });

  test('a point lands in its country', () {
    expect(world.at(52.48113, 13.43529)!.country.code, 'DE');
    expect(world.at(37.9838, 23.7275)!.country.code, 'GR');
    expect(world.at(-33.87, 151.21)!.country.code, 'AU');
    expect(world.at(48.85, 2.35)!.country.code, 'FR');
    expect(world.at(-29.6, 28.2)!.country.code, 'LS');
    expect(world.at(0, -30), null);
  });

  test('finds the nearest town, none mid ocean', () {
    final berlin = places.nearest(52.48113, 13.43529)!;
    expect(berlin.place.country, 'DE');
    expect(berlin.km < 10, true);
    expect(places.nearest(37.9838, 23.7275)!.place.country, 'GR');
    expect(places.nearest(0, -30), null);
    expect(places.nearest(-16.5, 179.99)?.place.country, 'FJ');
  });

  test('the view keeps the point inside', () {
    for (final p in [
      [52.48, 13.43],
      [64.1, -21.9],
      [-54.8, -68.3],
      [61.0, 100.0],
      [1.35, 103.8],
      [89.0, 10.0],
    ]) {
      final hit = world.at(p[0], p[1]);
      final v = viewFor(p[0], p[1], hit?.ring, 1.4);
      expect(v.west < p[1] && v.east > p[1], true, reason: '$p');
      expect(v.south < p[0] && v.north > p[0], true, reason: '$p');
      expect(v.south >= -90 && v.north <= 90, true, reason: '$p');
    }
  });

  test('the biggest towns in view are spread out', () {
    final got = places.biggestIn(5, 16, 47, 55, count: 4, apart: 1.5);
    expect(got.length, 4);
    expect(got.first.name, 'Berlin');
  });

  test('formats coordinates with hemisphere letters', () {
    expect(coordsLine(52.48113, 13.43529), '52.48113° N · 13.43529° E');
    expect(coordsLine(-33.5, -70.25), '33.50000° S · 70.25000° W');
  });

  test('refuses a cut or foreign file', () {
    expect(
      () => GeoWorld.parse(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(() => GeoPlaces.parse(Uint8List(20)), throwsFormatException);
  });
}
