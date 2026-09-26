// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// a top-level or static final keeps the language it was built in after a
// switch, so a message there has to be a getter
void main() {
  test('no top-level or static final holds a message', () {
    final decl = RegExp(
      r'^(?:final|late final|\s+static final|\s+static late final)\s[^;]*?\bl10n\s*\.',
      multiLine: true,
    );
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains(
        '${Platform.pathSeparator}l10n${Platform.pathSeparator}',
      )) {
        continue;
      }
      final s = f.readAsStringSync();
      for (final m in decl.allMatches(s)) {
        bad.add(
          '${f.path}:${'\n'.allMatches(s.substring(0, m.start)).length + 1}',
        );
      }
    }
    expect(bad, isEmpty);
  });
}
