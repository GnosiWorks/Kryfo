// SPDX-License-Identifier: GPL-3.0-or-later
// the accent is chrome only. a status or a warning (offline, connecting, a
// key that changed, a route that needs a look, a scam warning, a plain
// export) wears the warn yellow whatever is picked, the chat header tells
// relay from tor by their own colours, and words drawn in the accent take
// its text tone
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';

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
      'lib/widgets/key_held.dart',
      'lib/widgets/reconnect_valve.dart',
      'lib/widgets/shield_note.dart',
    ]) {
      expect(_accent.hasMatch(_src(f)), isFalse, reason: f);
    }
    expect(_src('lib/widgets/shield_note.dart'), contains('HaloColors.warn'));
    final plain = _between(
      _src('lib/screens/notes_export_screen.dart'),
      'class _Warn extends StatelessWidget',
      '\n}\n',
    );
    expect(_accent.hasMatch(plain), isFalse, reason: 'plain export warning');
    expect(plain, contains('HaloColors.warn'));
    final main = _src('lib/app/gates.dart');
    final pill = _between(
      main,
      '// relay does not go through tor, so tor being off never greys it',
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
    final banners = {
      'developer key moved': _between(
        _src('lib/screens/chat_screen.dart'),
        '// his key moved on: this chat still reads and writes',
        "ValueKey('dev-moved-none')",
      ),
      'needs tor': _between(
        _src('lib/screens/search_screen.dart'),
        "key: const ValueKey('needs-tor'),",
        'onTap: onAdd,',
      ),
      'share warning': _between(
        _src('lib/screens/introduce_sheet.dart'),
        '// the one warning there is.',
        '_GoButton(',
      ),
    };
    banners.forEach((what, src) {
      expect(_accent.hasMatch(src), isFalse, reason: what);
      expect(src, contains('color: HaloColors.warn,'), reason: what);
      expect(src, contains('textColor: HaloColors.warnText'), reason: what);
    });
    final short = _between(
      _src('lib/screens/notes_export_screen.dart'),
      'final color = switch (grade) {',
      'PassGrade.strong',
    );
    expect(_accent.hasMatch(short), isFalse, reason: 'too short hint');
    expect(short, contains('_ when short => HaloColors.warnText'));
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

  test('words on the on colour inside your own bubble take the accent', () {
    final lit = _between(
      _src('lib/widgets/chat_parts.dart'),
      'List<TextSpan> searchLit(',
      'fontWeight: FontWeight.w600,',
    );
    expect(lit, contains('onAmber ? HaloColors.amberOnOn : HaloColors.text'));
    expect(lit, contains('HaloColors.amber.withValues(alpha: kLitMark)'));
    final join = _between(
      _src('lib/widgets/kryfo_link_text.dart'),
      'l10n.kryfoLinkTextJoin2,',
      '),',
    );
    expect(
      join,
      contains('onAmber ? HaloColors.amberOnOn : HaloColors.onAmber'),
    );
  });
}
