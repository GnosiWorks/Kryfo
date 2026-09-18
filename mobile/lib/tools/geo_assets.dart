// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'geo.dart';

class GeoData {
  final GeoWorld world;
  final GeoPlaces places;
  const GeoData(this.world, this.places);
}

Future<GeoData>? _loading;

Future<GeoData> loadGeo() => _loading ??= _load();

Future<GeoData> _load() async {
  try {
    final w = await rootBundle.load('assets/geo/world.bin');
    final p = await rootBundle.load('assets/geo/places.bin.gz');
    final wb = w.buffer.asUint8List(w.offsetInBytes, w.lengthInBytes);
    final pb = p.buffer.asUint8List(p.offsetInBytes, p.lengthInBytes);
    return await Isolate.run(() => _parse(wb, pb));
  } catch (_) {
    _loading = null;
    rethrow;
  }
}

GeoData _parse(Uint8List world, Uint8List places) => GeoData(
  GeoWorld.parse(world),
  GeoPlaces.parse(Uint8List.fromList(gzip.decode(places))),
);
