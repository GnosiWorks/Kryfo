// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../image_strip.dart';
import '../meta/byte_source.dart';
import '../meta/meta_reader.dart';
import 'qr_payload.dart';

const kQrQuiet = 4;

void paintQr(ui.Canvas canvas, double side, QrGrid g, ui.Color ink) {
  final cell = side / (g.size + kQrQuiet * 2);
  final paint = ui.Paint()
    ..color = ink
    ..isAntiAlias = false;
  for (var r = 0; r < g.size; r++) {
    var c = 0;
    while (c < g.size) {
      if (!g.at(r, c)) {
        c++;
        continue;
      }
      var end = c;
      while (end + 1 < g.size && g.at(r, end + 1)) {
        end++;
      }
      canvas.drawRect(
        ui.Rect.fromLTRB(
          ((c + kQrQuiet) * cell).floorToDouble(),
          ((r + kQrQuiet) * cell).floorToDouble(),
          ((end + 1 + kQrQuiet) * cell).ceilToDouble(),
          ((r + 1 + kQrQuiet) * cell).ceilToDouble(),
        ),
        paint,
      );
      c = end + 1;
    }
  }
}

Future<Uint8List?> renderQrPng(
  QrGrid g,
  ui.Color ink,
  ui.Color paper, {
  int target = 1024,
}) async {
  final cells = g.size + kQrQuiet * 2;
  final side = max(1, target ~/ cells) * cells;
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    ui.Paint()..color = paper,
  );
  paintQr(canvas, side.toDouble(), g, ink);
  final picture = rec.endRecording();
  final image = await picture.toImage(side, side);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) return null;
  final raw = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final clean = stripPictureBytes(raw);
  if (clean == null) return null;
  final after = readMeta(MemorySource(clean));
  if (after.kind != MetaKind.png || after.status != MetaStatus.nothing) {
    return null;
  }
  return clean;
}

Future<String> writeQrPng(Uint8List png, String outRoot) async {
  final rnd = Random.secure();
  final tag = List.generate(
    8,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final dir = Directory('$outRoot/$tag');
  await dir.create(recursive: true);
  final f = File('${dir.path}/qr code.png');
  await f.writeAsBytes(png, flush: true);
  return f.path;
}
