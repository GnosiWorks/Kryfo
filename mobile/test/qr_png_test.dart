import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/meta/byte_source.dart';
import 'package:kryfo/meta/meta_reader.dart';
import 'package:kryfo/tools/qr_payload.dart';
import 'package:kryfo/tools/qr_png.dart';

void main() {
  testWidgets('the saved png is a png with nothing in it but the picture', (
    tester,
  ) async {
    final g = gridFor('WIFI:T:WPA;S:Home;P:correct horse;;')!;
    final png = await tester.runAsync(
      () => renderQrPng(
        g,
        const ui.Color(0xFF161310),
        const ui.Color(0xFFF5F1EA),
        target: 256,
      ),
    );
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), latin1.encode('PNG'));
    final types = <String>[];
    var i = 8;
    while (i + 8 <= png.length) {
      final n =
          (png[i] << 24) | (png[i + 1] << 16) | (png[i + 2] << 8) | png[i + 3];
      types.add(latin1.decode(png.sublist(i + 4, i + 8)));
      i += 12 + n;
    }
    expect(types.first, 'IHDR');
    expect(types.last, 'IEND');
    expect(
      types.toSet().difference({
        'IHDR',
        'IDAT',
        'IEND',
        'sRGB',
        'gAMA',
        'PLTE',
        'sBIT',
      }),
      isEmpty,
    );
    final text = latin1.decode(png, allowInvalid: true);
    expect(text.contains('correct horse'), false);
    expect(readMeta(MemorySource(png)).status, MetaStatus.nothing);
    final side = (png[16] << 24) | (png[17] << 16) | (png[18] << 8) | png[19];
    expect(side % (g.size + 8), 0);
  });
}
