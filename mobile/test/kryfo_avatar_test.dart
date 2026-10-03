// SPDX-License-Identifier: GPL-3.0-or-later
// an avatar is a picture. the letters drawn from the id are not a name, and
// a screen reader that announced them would give the contact one
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';

void main() {
  for (final choice in [null, 7]) {
    testWidgets('the avatar says nothing to a screen reader ($choice)', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KryfoAvatar(
                seed: 'guitar-present-kid',
                size: 56,
                choice: choice,
              ),
            ),
          ),
        ),
      );
      if (choice == null) expect(find.text('GPK'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('G')), findsNothing);
      sem.dispose();
    });
  }
}
