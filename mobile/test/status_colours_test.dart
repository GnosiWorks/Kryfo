// SPDX-License-Identifier: GPL-3.0-or-later
// the accent is chrome only. a status or a warning (offline, connecting, a
// key that changed, a name not checked, a route that needs a look) wears the
// warn yellow whatever is picked, the chat header tells relay from tor by
// their own colours, and words drawn in the accent take its text tone
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/name_check_mark.dart';

final _accent = RegExp(
  r'HaloColors\.(amber|onAmber|amberSoft|amberDeep|amberText)(?![A-Za-z])',
);

String _src(String path) => File(path).readAsStringSync();

// the text between [from] and the first [to] after it
String _between(String src, String from, String to) {
  final a = src.indexOf(from);
  expect(a, greaterThanOrEqualTo(0), reason: from);
  final b = src.indexOf(to, a + from.length);
  expect(b, greaterThan(a), reason: to);
  return src.substring(a, b);
}

// every call's argument list, by its own parentheses
Iterable<String> _calls(String src, RegExp head) sync* {
  for (final m in head.allMatches(src)) {
    var depth = 1;
    var i = m.end;
    while (depth > 0 && i < src.length) {
      final c = src[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      i++;
    }
    yield src.substring(m.end, i);
  }
}

void main() {
  tearDown(() {
    HaloColors.setLight(false);
    HaloColors.setAccent(HaloAccent.yellow);
  });

  test('warning widgets never read the accent', () {
    for (final f in [
      'lib/widgets/name_check_mark.dart',
      'lib/widgets/key_held.dart',
      'lib/widgets/reconnect_valve.dart',
    ]) {
      expect(_accent.hasMatch(_src(f)), isFalse, reason: f);
    }
    final main = _src('lib/main.dart');
    final pill = _between(
      main,
      'const torGreen = Color(0xFF34D399);',
      'final t = _c.value;',
    );
    expect(_accent.hasMatch(pill), isFalse, reason: 'status pill');
    expect(pill, contains('HaloColors.warn'));
    final seen = _between(
      _src('lib/screens/seen_screen.dart'),
      'Color _tint(_Tone t)',
      '};',
    );
    expect(seen, contains('_Tone.warn => HaloColors.warnText'));
    final verify = _between(
      _src('lib/screens/key_verification_screen.dart'),
      'l10n.keyVerificationNewNumber,',
      ')',
    );
    expect(verify, isNot(matches(_accent)));
    final strip = _between(
      _src('lib/screens/home_screen.dart'),
      'Widget _strip(BuildContext context, int n, bool offline) {',
      'final head =',
    );
    expect(_accent.hasMatch(strip), isFalse, reason: 'waiting strip');
  });

  test('the chat header tells relay from tor by their own colours', () {
    final head = _between(
      _src('lib/screens/chat_screen.dart'),
      'Icons.lock_outline,\n                          size: 10,',
      'const SizedBox(width: 4)',
    );
    expect(head, contains('relay ? HaloColors.sky : HaloColors.violet'));
    expect(_accent.hasMatch(head), isFalse);
  });

  test('words drawn in the accent take its text tone', () {
    final bad = <String>[];
    final head = RegExp(r'HaloType\.(?:sans|mono|serif)\(');
    final plain = RegExp(r'HaloColors\.amber(?![A-Za-z])');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/l10n/')) continue;
      for (final args in _calls(f.readAsStringSync(), head)) {
        if (plain.hasMatch(args)) bad.add(f.path);
      }
    }
    expect(bad, isEmpty);
  });

  for (final light in [false, true]) {
    testWidgets('a name not checked wears the warn yellow under any accent, '
        '${light ? 'light' : 'dark'}', (t) async {
      HaloColors.setLight(light);
      for (final a in [HaloAccent.velvet, HaloAccent.blue, HaloAccent.lime]) {
        HaloColors.setAccent(a);
        await t.pumpWidget(
          const MaterialApp(
            home: Material(child: Center(child: NameCheckMark())),
          ),
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          const MaterialApp(
            home: Material(child: Center(child: NameCheckMark())),
          ),
        );
        final icon = t.widget<Icon>(find.byIcon(Icons.help_outline));
        expect(icon.color, HaloColors.warn, reason: a.name);
        expect(icon.color, isNot(HaloColors.amber), reason: a.name);
        final words = t.widget<Text>(find.text(l10n.nameNotChecked));
        expect(words.style!.color, HaloColors.warnText, reason: a.name);
      }
    });
  }
}
