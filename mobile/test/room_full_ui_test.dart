// SPDX-License-Identifier: GPL-3.0-or-later
// a room whose creator found no seat says it is full, where the wait or a
// room that does not answer would be, with the same two ways on
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/room_join.dart';

Widget _host(Widget child, {bool still = false}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: c!,
  ),
  home: Scaffold(body: child),
);

int get _now => DateTime.now().millisecondsSinceEpoch;

void main() {
  for (final still in [false, true]) {
    testWidgets('full: it says so, and try again or leave (still: $still)', (
      t,
    ) async {
      var tries = 0;
      var leaves = 0;
      await t.pumpWidget(
        _host(
          RoomJoinPanel(
            name: 'Friday',
            joiningAt: _now,
            full: true,
            onTryAgain: () => tries++,
            onLeave: () => leaves++,
          ),
          still: still,
        ),
      );
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.roomJoinFull), findsOneWidget);
      expect(find.text(l10n.roomJoinFullLine), findsOneWidget);
      expect(find.text(l10n.roomJoinNoAnswer), findsNothing);
      expect(find.text(l10n.roomJoinWaitingFor('Friday')), findsNothing);
      await t.tap(find.text(l10n.commonTryAgain));
      await t.tap(find.text(l10n.groupInfoLeave));
      expect((tries, leaves), (1, 1));
      // nothing keeps moving once it has come to rest
      await t.pump(const Duration(seconds: 1));
      expect(t.hasRunningAnimations, isFalse);
    });
  }

  testWidgets('a knock again is waiting again', (t) async {
    Widget panel(bool full) => _host(
      RoomJoinPanel(
        name: 'Friday',
        joiningAt: _now,
        full: full,
        onTryAgain: () {},
        onLeave: () {},
      ),
      still: true,
    );
    await t.pumpWidget(panel(true));
    await t.pump(const Duration(seconds: 1));
    await t.pumpWidget(panel(false));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.roomJoinWaitingFor('Friday')), findsOneWidget);
    expect(find.text(l10n.roomJoinFull), findsNothing);
  });

  testWidgets('the line says full, waiting or not answering', (t) async {
    await t.pumpWidget(_host(RoomJoinLine(joiningAt: _now, full: true)));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.roomJoinFullShort), findsOneWidget);
    await t.pumpWidget(_host(RoomJoinLine(joiningAt: _now)));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.roomJoinWaitingToJoin), findsOneWidget);
    await t.pumpWidget(_host(RoomJoinLine(joiningAt: _now - 600000)));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.roomJoinNotAnswering), findsOneWidget);
  });
}
