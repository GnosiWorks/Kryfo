// SPDX-License-Identifier: GPL-3.0-or-later
// choosing chats to hide: round checks that fill on a spring, the count on
// the button, a way to hide nothing, the chosen rows leaving towards the
// start side, a failed move that keeps the list, and reduced motion.
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/hide_picker.dart';

import 'pin_flow_fakes.dart';

class _Picker {
  _Picker({this.fail = false});
  final bool fail;
  final hid = <(List<String>, List<String>)>[];
  final done = <int>[];

  Widget widget({List<HideChoice>? chats, String? line = 'line'}) => Scaffold(
    body: SafeArea(
      child: HidePicker(
        chats: chats ?? someChats(),
        line: line,
        onHide: (people, groups) async {
          hid.add((people, groups));
          if (fail) throw StateError('move cut short');
          return people.length + groups.length;
        },
        onDone: done.add,
      ),
    ),
  );
}

// how far the check inside a row has filled
double _fill(WidgetTester t, String name) {
  final row = find.ancestor(of: find.text(name), matching: find.byType(Row));
  final scale = find.descendant(
    of: row.first,
    matching: find.byType(Transform),
  );
  // the x scale: a scale of 0 keeps z at 1
  return t.widget<Transform>(scale.last).transform.storage[0];
}

// where a row sits across, against where it sat
double _dx(WidgetTester t, String name) => t.getTopLeft(find.text(name)).dx;

void main() {
  tearDown(() => setL10nLocale(const Locale('en')));

  testWidgets('a check fills on a spring and the count rides the button', (
    t,
  ) async {
    phone(t);
    final h = t.ensureSemantics();
    final p = _Picker();
    await t.pumpWidget(app(p.widget()));
    await t.pumpAndSettle();
    expect(find.text(l10n.flowVaultPickButton(0)), findsOneWidget);
    expect(_fill(t, 'Hana'), 0);
    await t.tap(find.text('Hana'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    final mid = _fill(t, 'Hana');
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    // the house spring settles well under 300 ms
    await t.pump(const Duration(milliseconds: 260));
    expect(_fill(t, 'Hana'), closeTo(1, 0.01));
    await t.pumpAndSettle();
    expect(find.text(l10n.flowVaultPickButton(1)), findsOneWidget);
    expect(
      t.getSemantics(find.text('Hana')).flagsCollection.isChecked,
      CheckedState.isTrue,
    );
    await t.tap(find.text('Saturday hike'));
    await t.pumpAndSettle();
    expect(find.text(l10n.flowVaultPickButton(2)), findsOneWidget);
    await t.tap(find.text('Hana'));
    await t.pumpAndSettle();
    expect(_fill(t, 'Hana'), 0);
    expect(find.text(l10n.flowVaultPickButton(1)), findsOneWidget);
    expect(
      t.getSemantics(find.text('Hana')).flagsCollection.isChecked,
      CheckedState.isFalse,
    );
    h.dispose();
  });

  testWidgets('nothing chosen hides nothing', (t) async {
    phone(t);
    final p = _Picker();
    await t.pumpWidget(app(p.widget()));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.flowVaultPickButton(0)));
    await t.pumpAndSettle();
    expect(p.hid, isEmpty);
    expect(p.done, [0]);
  });

  testWidgets('the chosen rows leave towards the start, then it is done', (
    t,
  ) async {
    phone(t);
    final p = _Picker();
    await t.pumpWidget(app(p.widget()));
    await t.pumpAndSettle();
    await t.tap(find.text('Saturday hike'));
    await t.tap(find.text('Hana'));
    await t.pumpAndSettle();
    final at = _dx(t, 'Hana');
    final stays = _dx(t, 'Vic');
    await t.tap(find.text(l10n.flowVaultPickButton(2)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(_dx(t, 'Hana'), lessThan(at));
    expect(_dx(t, 'Vic'), stays);
    expect(p.done, isEmpty);
    await t.pumpAndSettle();
    expect(p.hid.single.$1, ['hidden-wreck-tone']);
    expect(p.hid.single.$2, ['g2hidden0001']);
    expect(p.done, [2]);
  });

  testWidgets('a move that fails keeps the list and says so', (t) async {
    phone(t);
    final p = _Picker(fail: true);
    await t.pumpWidget(app(p.widget()));
    await t.pumpAndSettle();
    await t.tap(find.text('Vic'));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.flowVaultPickButton(1)));
    await t.pumpAndSettle();
    expect(find.text(l10n.flowNotSet), findsOneWidget);
    expect(find.text('Vic'), findsOneWidget);
    expect(p.done, isEmpty);
    expect(find.text(l10n.flowVaultPickButton(1)), findsOneWidget);
  });

  testWidgets('with no chats it says so, and can still go on', (t) async {
    phone(t);
    final p = _Picker();
    await t.pumpWidget(app(p.widget(chats: const [])));
    await t.pumpAndSettle();
    expect(find.text(l10n.flowVaultPickEmpty), findsOneWidget);
    await t.tap(find.text(l10n.flowVaultPickButton(0)));
    expect(p.done, [0]);
  });

  testWidgets('reduced motion: checks and leaving rows do not move', (t) async {
    phone(t);
    final p = _Picker();
    await t.pumpWidget(app(p.widget(), still: true));
    await t.pumpAndSettle();
    Future<void> still() async {
      await t.pump(Duration.zero);
      await t.pump(Duration.zero);
      expect(t.binding.hasScheduledFrame, isFalse);
    }

    await t.tap(find.text('Hana'));
    await still();
    expect(_fill(t, 'Hana'), 1);
    expect(find.text(l10n.flowVaultPickButton(1)), findsOneWidget);
    await t.tap(find.text(l10n.flowVaultPickButton(1)));
    await still();
    expect(p.done, [1]);
  });

  testWidgets('right to left: the chosen rows leave towards the right', (
    t,
  ) async {
    phone(t);
    setL10nLocale(const Locale('ar'));
    final p = _Picker();
    await t.pumpWidget(app(p.widget(), locale: const Locale('ar')));
    await t.pumpAndSettle();
    expect(find.text(l10n.flowVaultPickTitle), findsOneWidget);
    await t.tap(find.text('Hana'));
    await t.pumpAndSettle();
    expect(find.text(l10n.flowVaultPickButton(1)), findsOneWidget);
    final at = _dx(t, 'Hana');
    await t.tap(find.text(l10n.flowVaultPickButton(1)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(_dx(t, 'Hana'), greaterThan(at));
    await t.pumpAndSettle();
    expect(p.done, [1]);
  });
}
