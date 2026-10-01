// SPDX-License-Identifier: GPL-3.0-or-later
// the group screen keeps ghost mode where the 1:1 chats keep it, so the
// flame is as it was left, and closes once its group is gone from here,
// even under its info when this phone was taken out
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/group_chat_screen.dart' show closeGoneGroup;

final _src = File('lib/screens/group_chat_screen.dart').readAsStringSync();

String _body(String from, String to) {
  final a = _src.indexOf(from);
  expect(a, isNonNegative, reason: from);
  final b = _src.indexOf(to, a + from.length);
  expect(b, greaterThan(a), reason: to);
  return _src.substring(a, b);
}

void main() {
  test('ghost mode is read when the screen opens', () {
    final init = _body('void initState()', 'void dispose()');
    expect(init, contains('appState.loadGhostPref()'));
    expect(init, contains('_ghost = p.\$1'));
    expect(init, contains('_burnSeconds = p.\$2'));
  });

  test('a toggle and a picked burn time are kept', () {
    final toggle = _body('onToggleGhost: () {', '},');
    expect(toggle, contains('appState.saveGhostPref(_ghost, _burnSeconds)'));
    // a picked time turns timed messages on, and is kept so
    final pick = _body('_burnSeconds = opt.\$1;', 'Navigator');
    expect(pick, contains('_ghost = true;'));
    expect(pick, contains('appState.saveGhostPref(true, opt.\$1)'));
  });

  group('a group gone from here', () {
    Future<(NavigatorState, Route<dynamic>)> stack(
      WidgetTester t,
      int above,
    ) async {
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(navigatorKey: key, home: const Text('home')),
      );
      final nav = key.currentState!;
      final group = MaterialPageRoute<void>(builder: (_) => const Text('g'));
      nav.push(group);
      for (var i = 0; i < above; i++) {
        nav.push(MaterialPageRoute<void>(builder: (_) => Text('info $i')));
      }
      await t.pumpAndSettle();
      return (nav, group);
    }

    testWidgets('in front, its screen closes, room or not', (t) async {
      final (nav, group) = await stack(t, 0);
      expect(closeGoneGroup(nav, group, removed: false), isTrue);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('taken out under its info, both close', (t) async {
      final (nav, group) = await stack(t, 2);
      expect(closeGoneGroup(nav, group, removed: true), isTrue);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(group.isActive, isFalse);
    });

    testWidgets('a leave from its info closes nothing here', (t) async {
      final (nav, group) = await stack(t, 1);
      expect(closeGoneGroup(nav, group, removed: false), isFalse);
      await t.pumpAndSettle();
      expect(find.text('info 0'), findsOneWidget);
      expect(group.isActive, isTrue);
    });
  });
}
