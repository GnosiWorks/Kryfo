// SPDX-License-Identifier: GPL-3.0-or-later
// the fields people write in beyond the composers carry the stuck shift
// guard on their own controller: the chat's search, the edit sheet and a
// passphrase
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/chat_screen.dart' show SearchHead;
import 'package:kryfo/widgets/confirm_sheet.dart' show showInputSheet;
import 'package:kryfo/widgets/secret_field.dart';
import 'package:kryfo/widgets/shift_tap_guard.dart';

import 'dev_chat_fakes.dart' show devApp;

// the one text field on screen sits under a guard on the same controller
void _guarded(WidgetTester t) {
  final field = find.byType(TextField);
  expect(field, findsOneWidget);
  final guard = find.ancestor(of: field, matching: find.byType(ShiftTapGuard));
  expect(guard, findsOneWidget);
  expect(
    t.widget<ShiftTapGuard>(guard).controller,
    same(t.widget<TextField>(field).controller),
  );
}

void main() {
  testWidgets('the chat search field is guarded', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await t.pumpWidget(
      devApp(
        Scaffold(
          body: SearchHead(
            controller: c,
            matchCount: 0,
            matchPos: 0,
            onChanged: (_) {},
            onPrev: () {},
            onNext: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await t.pump();
    _guarded(t);
  });

  testWidgets('the edit message sheet is guarded', (t) async {
    await t.pumpWidget(
      devApp(
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showInputSheet(
                ctx,
                title: 'Edit',
                initial: 'hello there',
                multiline: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    _guarded(t);
    expect(find.text('hello there'), findsOneWidget);
  });

  testWidgets('a passphrase field is guarded', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await t.pumpWidget(
      devApp(
        Scaffold(
          body: SecretField(
            label: 'Passphrase',
            controller: c,
            shown: false,
            onToggle: () {},
          ),
        ),
      ),
    );
    await t.pump();
    _guarded(t);
  });
}
