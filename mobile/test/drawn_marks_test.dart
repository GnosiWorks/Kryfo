// SPDX-License-Identifier: GPL-3.0-or-later
// the tick and the tier marks are drawn, not text glyphs: a font without
// the glyph shows an empty box (the 0.6.0 store screenshots did)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/handle_screen.dart';
import 'package:kryfo/supporter.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/chat_parts.dart';
import 'package:kryfo/widgets/tick_mark.dart';
import 'package:kryfo/widgets/tier_mark.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildHaloTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('the sent tick is drawn, with its label kept', (t) async {
    final sem = t.ensureSemantics();
    await t.pumpWidget(
      _host(
        const SentTick(
          delivered: true,
          deliveredLabel: 'Delivered',
          color: Colors.black,
          labelStyle: TextStyle(fontSize: 8.5),
        ),
      ),
    );
    expect(find.byType(TickMark), findsOneWidget);
    expect(find.text('✓'), findsNothing);
    expect(find.bySemanticsLabel('✓'), findsOneWidget);
    // the line box of the 11 px glyph it replaces
    expect(t.getSize(find.byType(TickMark)).height, 11);
    sem.dispose();
  });

  testWidgets('a free name gets the drawn tick before its word', (t) async {
    await t.pumpWidget(_host(const HandleAvailability(state: 'free')));
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(TickMark), findsOneWidget);
    await t.pumpWidget(_host(const HandleAvailability(state: 'taken')));
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(TickMark), findsNothing);
  });

  testWidgets('each tier has a mark, none has none', (t) async {
    for (final tier in SupporterTier.values) {
      await t.pumpWidget(
        _host(TierMark(tier: tier, color: Colors.black, size: 12)),
      );
      expect(
        t.getSize(find.byType(TierMark)),
        tier == SupporterTier.none ? Size.zero : const Size.square(12),
      );
    }
  });

  test('no text glyph stands in for a tick, star or arrow', () {
    // dingbats and geometric shapes our fonts lack, as a literal or escape
    final glyph = RegExp(
      r"'[^'\n]*(\\u27[0-9a-fA-F]{2}|\\u25[c-fC-F][0-9a-fA-F]|[\u2700-\u27bf\u25c0-\u25ff])",
    );
    // the tick's spoken label, emoji reactions (an emoji font draws them),
    // the solana sign (set in jetbrains mono, which has it)
    const allowed = ['semanticLabel', 'kQuickReactions', r"'\u25CE'"];
    final sep = Platform.pathSeparator;
    final bad = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.contains('${sep}l10n$sep'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') &&
                glyph.hasMatch(line) &&
                !allowed.any(line.contains))
              '${f.path}:${i + 1}',
    ];
    expect(bad, isEmpty);
  });
}
