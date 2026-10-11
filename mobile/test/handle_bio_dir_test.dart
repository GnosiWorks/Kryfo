// SPDX-License-Identifier: GPL-3.0-or-later
// the handle is latin left to right in every language, the line about you
// runs the way it is written
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/handle_screen.dart';
import 'package:kryfo/theme.dart';

Widget _app(Locale locale) => MaterialApp(
  theme: buildHaloTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const HandleScreen(),
);

void main() {
  tearDown(() => setL10nLocale(const Locale('en')));

  TextField field(WidgetTester t, int i) =>
      t.widget<TextField>(find.byType(TextField).at(i));

  // the direction the field lays its text out in
  TextDirection drawn(WidgetTester t, int i) => t
      .state<EditableTextState>(
        find.descendant(
          of: find.byType(TextField).at(i),
          matching: find.byType(EditableText),
        ),
      )
      .renderEditable
      .textDirection;

  for (final loc in const [Locale('ar'), Locale('fa')]) {
    testWidgets('${loc.languageCode}: the bio runs right to left, the handle '
        'does not', (t) async {
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      setL10nLocale(loc);
      await t.pumpWidget(_app(loc));
      await t.pump(const Duration(milliseconds: 600));
      expect(field(t, 0).textDirection, TextDirection.ltr);
      // empty, the bio keeps the screen's direction
      expect(drawn(t, 1), TextDirection.rtl);
      await t.enterText(find.byType(TextField).at(1), 'سلام دنیا');
      await t.pump();
      expect(drawn(t, 1), TextDirection.rtl);
      expect(drawn(t, 0), TextDirection.ltr);
    });
  }

  testWidgets('a bio written in persian runs right to left on an english '
      'screen', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const Locale('en')));
    await t.pump(const Duration(milliseconds: 600));
    expect(drawn(t, 1), TextDirection.ltr);
    await t.enterText(find.byType(TextField).at(1), 'سلام دنیا');
    await t.pump();
    expect(drawn(t, 1), TextDirection.rtl);
  });
}
