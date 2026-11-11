// SPDX-License-Identifier: GPL-3.0-or-later
// a taken handle comes with one free name like it, asked of the registry
// before it is shown; a tap on it puts it in the field
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_claim.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/handle_screen.dart' show HandleAvailability;

void main() {
  setUp(() => setL10nLocale(const Locale('en')));
  tearDown(() => handleCheckForTest = null);

  test('the names offered fit the rule and are not the one typed', () {
    final r = Random(7);
    for (final h in ['abc', 'mario', 'a_very_long_name_xx1']) {
      for (var i = 0; i < 50; i++) {
        final c = handleCandidates(h, r);
        expect(c, isNotEmpty);
        for (final x in c) {
          expect(handleShape.hasMatch(x), isTrue, reason: x);
          expect(x, isNot(h));
          expect(x.startsWith(h.substring(0, min(h.length, 15))), isTrue);
        }
      }
    }
  });

  Future<void> answered(WidgetTester t) async {
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('taken: the first free name, only once the registry said so', (
    t,
  ) async {
    final asked = <String>[];
    var frees = 0;
    handleCheckForTest = (h) async {
      asked.add(h);
      if (h == 'mario') return 'taken';
      // the first offered is taken too, the next is free
      return frees++ == 0 ? 'taken' : 'free';
    };
    final ctrl = TextEditingController(text: 'mario');
    final c = HandleClaimer(ctrl);
    c.onTyped('mario');
    await answered(t);
    expect(c.state, 'taken');
    expect(asked.first, 'mario');
    expect(asked, hasLength(3));
    expect(c.suggestion, asked.last);
    // a tap puts it in the field, and it is checked as typed
    c.useSuggestion();
    expect(ctrl.text, asked[2]);
    expect(c.suggestion, isNull);
    await answered(t);
    expect(c.state, 'free');
    c.dispose();
  });

  testWidgets('none offered when the registry cannot be reached', (t) async {
    handleCheckForTest = (h) async =>
        h == 'mario' ? 'taken' : 'error: bad answer from the registry';
    final c = HandleClaimer(TextEditingController(text: 'mario'));
    c.onTyped('mario');
    await answered(t);
    expect(c.state, 'taken');
    expect(c.suggestion, isNull);
    c.dispose();
  });

  testWidgets('typed on meanwhile: nothing offered for the old name', (
    t,
  ) async {
    final ctrl = TextEditingController(text: 'mario');
    late HandleClaimer c;
    handleCheckForTest = (h) async {
      if (h == 'mario') return 'taken';
      // the person types on while the registry is asked
      ctrl.text = 'marion';
      return 'free';
    };
    c = HandleClaimer(ctrl);
    c.onTyped('mario');
    await answered(t);
    expect(c.suggestion, isNull);
    c.dispose();
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('the offer shows under "taken" and a tap uses it '
        '(${scale}x)', (t) async {
      var used = 0;
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: HandleAvailability(
                state: 'taken',
                suggestion: 'mario_42',
                onSuggestion: () => used++,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text(l10n.handleAlreadyTaken), findsOneWidget);
      await t.tap(find.text(l10n.handleSuggestFree('mario_42')));
      expect(used, 1);
      expect(t.takeException(), isNull);
    });
  }
}
