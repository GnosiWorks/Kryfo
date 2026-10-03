// SPDX-License-Identifier: GPL-3.0-or-later
// a message nothing says any more goes from every arb file with the code
// that said it. android's own words (android*) are read by
// tool/arb_android.py, not by the app
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// older ones still waiting for their own change
const _known = {
  'chatSendPhoto',
  'chatAddACaption',
  'homeArchivedChats',
  'pinsSetAWipePin',
  'pinsSetADecoyPin',
  'settingsOnNextStart',
  'settingsOffNextStart',
  'searchOpen',
};

void main() {
  test('every message in app_en.arb is said somewhere', () {
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final code = StringBuffer();
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final name = f.uri.pathSegments.last;
      if (name.startsWith('app_localizations')) continue;
      code.writeln(f.readAsStringSync());
    }
    final said = code.toString();
    final dead = [
      for (final k in en.keys)
        if (!k.startsWith('@') &&
            !k.startsWith('android') &&
            !_known.contains(k) &&
            !RegExp('\\b$k\\b').hasMatch(said))
          k,
    ];
    expect(dead, isEmpty);
  });
}
