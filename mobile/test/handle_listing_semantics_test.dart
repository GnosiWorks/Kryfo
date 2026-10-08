// SPDX-License-Identifier: GPL-3.0-or-later
// the search card on the handle page with a screen reader: one switch named
// by its title, with its line and the name shown, apart from the handle card
// above it, and a tap through it turns it off.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/handle_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devWorld;
import 'on_screen.dart';

class _Registry implements HaloEngine {
  final asked = <String>[];
  @override
  Future<String> handleListing(String h, bool listed, String name) async {
    asked.add('$h $listed $name');
    return 'ok';
  }

  @override
  String firstContactPk(int counter) => '';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('the engine was asked for ${i.memberName}');
}

Widget _app() => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (ctx) => Center(
      child: TextButton(
        onPressed: () => Navigator.of(
          ctx,
        ).push(MaterialPageRoute<void>(builder: (_) => const HandleScreen())),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _rest(WidgetTester t) async {
  for (var i = 0; i < 2; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('show me in search reads as one switch', (t) async {
    t.view.physicalSize = const Size(1000, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'my_handle': 'wren',
      'my_handle_listed': '1',
      'my_handle_name': 'Wren',
    });
    final reg = _Registry();
    useEngineForTest(reg);
    appState.sendModeForTest = 'balanced';
    await devWorld();
    await appState.loadMyHandle();
    addTearDown(() => appState.setMyHandle(null));
    final sem = t.ensureSemantics();
    await t.pumpWidget(_app());
    await t.tap(find.text('open'));
    await _rest(t);

    SemanticsNode card() => t.getSemantics(find.text(l10n.handleShowInSearch));
    var node = card();
    expect(
      node,
      isSemantics(hasToggledState: true, isToggled: true, hasTapAction: true),
    );
    final said = node.getSemanticsData().label;
    expect(said, startsWith(l10n.handleShowInSearch));
    expect(said, contains(l10n.handleShowInSearchLine));
    expect(said, contains(l10n.handleShownAs('Wren')));
    // its own node, the card's own bounds, apart from the handle above it
    final above = t.getSemantics(find.text(l10n.handleAnyoneWithThisLink));
    expect(above.id, isNot(node.id));
    expect(
      above.getSemanticsData().label,
      isNot(contains(l10n.handleShowInSearch)),
    );
    final drawn = t.getRect(
      find
          .ancestor(
            of: find.text(l10n.handleShowInSearch),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final rect = onScreen(t, node);
    expect(rect.top, moreOrLessEquals(drawn.top, epsilon: 0.5));
    expect(rect.bottom, moreOrLessEquals(drawn.bottom, epsilon: 0.5));

    // off, through the screen reader's tap
    t.semantics.tap(find.semantics.byLabel(RegExp(l10n.handleShowInSearch)));
    await _rest(t);
    expect(reg.asked, ['wren false ']);
    node = card();
    expect(node, isSemantics(hasToggledState: true, isToggled: false));
    expect(
      node.getSemanticsData().label,
      isNot(contains(l10n.handleShownAs('Wren'))),
    );

    // on again asks for the name to show first
    t.semantics.tap(find.semantics.byLabel(RegExp(l10n.handleShowInSearch)));
    await _rest(t);
    expect(find.text(l10n.handleNameInSearch), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    sem.dispose();
  });
}
