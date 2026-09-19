// SPDX-License-Identifier: GPL-3.0-or-later
//
// the Open file button decides its handler at build time from whether the
// password field is empty. the field's listener only rebuilt when it had an
// error to clear, so the button was built once against an empty field, kept
// a null handler, and never came alive: on the phone it looked enabled,
// reported itself clickable, and did nothing at all with any password.
//
// this is the shape of that bug, guarded on the real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/open_locked_screen.dart';
import 'package:kryfo/tools/tools_bridge.dart';

Widget host(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(360, 720)),
    child: child,
  ),
);

const _file = PickedFile(
  uri: 'content://test/locked.age',
  name: 'locked.age',
  size: 1234,
  mime: 'application/octet-stream',
);

// every GestureDetector the screen builds, so we can ask whether the one
// wrapping "Open file" actually has a handler.
bool _openFileIsLive(WidgetTester t) {
  final label = find.text('Open file');
  if (label.evaluate().isEmpty) return false;
  final gestures = find.ancestor(
    of: label,
    matching: find.byType(GestureDetector),
  );
  for (final g in t.widgetList<GestureDetector>(gestures)) {
    if (g.onTap != null) return true;
  }
  return false;
}

void main() {
  testWidgets('Open file is dead until something is typed, then alive', (
    t,
  ) async {
    await t.pumpWidget(host(const OpenLockedScreen(file: _file)));
    await t.pump(const Duration(milliseconds: 50));

    expect(
      _openFileIsLive(t),
      isFalse,
      reason: 'with no password there is nothing to try',
    );

    await t.enterText(find.byType(TextField).first, 'correct horse battery');
    await t.pump();

    expect(
      _openFileIsLive(t),
      isTrue,
      reason:
          'typing a password must rebuild the button with a handler - '
          'without that rebuild it stays dead however much is typed',
    );
  });

  testWidgets('clearing the field puts it back to dead', (t) async {
    await t.pumpWidget(host(const OpenLockedScreen(file: _file)));
    await t.pump(const Duration(milliseconds: 50));

    await t.enterText(find.byType(TextField).first, 'something');
    await t.pump();
    expect(_openFileIsLive(t), isTrue);

    await t.enterText(find.byType(TextField).first, '');
    await t.pump();
    expect(
      _openFileIsLive(t),
      isFalse,
      reason: 'an empty field offers nothing to open',
    );
  });
}
