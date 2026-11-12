// SPDX-License-Identifier: GPL-3.0-or-later
// every picture drawn from bytes in memory or a plain file lets go of its
// decoded copy under the lock: each Image.memory, Image.file and
// Image.network in the app sits inside a PicturesGate
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _drawn = RegExp(r'Image\.(memory|file|network)\(');

void main() {
  test('no Image.memory, file or network outside a PicturesGate', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!_drawn.hasMatch(lines[i])) continue;
        final above = lines.sublist(i < 8 ? 0 : i - 8, i + 1).join('\n');
        if (!above.contains('PicturesGate(')) bad.add('${f.path}:${i + 1}');
      }
    }
    expect(bad, isEmpty);
  });
}
