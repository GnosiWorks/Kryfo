// SPDX-License-Identifier: GPL-3.0-or-later
// every picture drawn from bytes in memory lets go of its decoded copy
// under the lock: each Image.memory in the app sits inside a PicturesGate
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no Image.memory outside a PicturesGate', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('Image.memory(')) continue;
        final above = lines.sublist(i < 8 ? 0 : i - 8, i + 1).join('\n');
        if (!above.contains('PicturesGate(')) bad.add('${f.path}:${i + 1}');
      }
    }
    expect(bad, isEmpty);
  });
}
