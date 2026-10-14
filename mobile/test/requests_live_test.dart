// SPDX-License-Identifier: GPL-3.0-or-later
// the requests screen while it is up: a request that comes in shows on it,
// a request's notification goes back to it rather than stacking a second
// one, and an accept opens the chat, in place of the screen when no one
// else waits
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show appState, claimChat, openChatForHalo, rootNavKey, useDatabasesForTest;
import 'package:kryfo/screens/requests_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _first = 'amber-fox-river';
const _second = 'slow-kite-moss';
const _late = 'quiet-hill-reed';

// the rows, and what the screen reads of a request besides
class _Rows extends ArrivalRows {
  _Rows() : super(HaloContainer.decoy);
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async => [];
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<void> acceptRequest(String haloId) async =>
      people[haloId]!['accepted'] = 1;
  // a read of the list that waits to be let through, when set
  Completer<void>? gate;
  final declined = <String>[];
  @override
  Future<List<Map<String, Object?>>> requestsInbox() async {
    await gate?.future;
    return super.requestsInbox();
  }

  @override
  Future<void> declineRequest(String haloId) async {
    declined.add(haloId);
    await super.declineRequest(haloId);
  }
}

Widget _app() => MaterialApp(
  navigatorKey: rootNavKey,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const RequestsScreen(),
);

Widget _page(String line) => Scaffold(body: Center(child: Text(line)));

void main() {
  late _Rows rows;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    lockState.openForTest();
    rows = _Rows()..person(_first, accepted: 0);
    useDatabasesForTest(rows, Session(rows));
    requestChatRoute = (row) => MaterialPageRoute<void>(
      builder: (_) => _page('chat ${row['halo_id']}'),
    );
  });

  Future<void> frames(WidgetTester t, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> show(WidgetTester t) async {
    t.view.physicalSize = const Size(1000, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    await t.pumpWidget(_app());
    await frames(t);
  }

  Future<void> drain(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  testWidgets('a request that comes in shows on the open screen', (t) async {
    await show(t);
    expect(find.text(_first), findsOne);
    expect(find.text(_late), findsNothing);
    rows.person(_late, accepted: 0);
    await appState.refreshContacts();
    await frames(t);
    expect(find.text(_late), findsOne);
    await drain(t);
  });

  testWidgets('a request notification goes back to the open screen', (t) async {
    await show(t);
    rootNavKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => _page('above')),
    );
    await frames(t);
    claimChat('someone-else-here');
    rows.person(_late, accepted: 0);
    await appState.refreshContacts();
    await openChatForHalo(_late);
    await frames(t);
    expect(find.text('above', skipOffstage: false), findsNothing);
    expect(find.byType(RequestsScreen, skipOffstage: false), findsOne);
    expect(find.text(_late), findsOne);
    // on top already: nothing stacks
    await openChatForHalo(_first);
    await frames(t);
    expect(find.byType(RequestsScreen, skipOffstage: false), findsOne);
    await drain(t);
  });

  testWidgets('accepting the last request opens the chat in its place', (
    t,
  ) async {
    await show(t);
    await t.tap(find.text(l10n.commonAccept).first);
    await frames(t, 12);
    expect(find.text('chat $_first'), findsOne);
    expect(find.byType(RequestsScreen, skipOffstage: false), findsNothing);
    await drain(t);
  });

  testWidgets('accepting one of two opens the chat over the screen', (t) async {
    rows.person(_second, accepted: 0);
    await show(t);
    final card = find.ancestor(
      of: find.text(_first),
      matching: find.byKey(const ValueKey('req_$_first')),
    );
    await t.tap(
      find.descendant(of: card, matching: find.text(l10n.commonAccept)),
    );
    await frames(t, 12);
    expect(find.text('chat $_first'), findsOne);
    rootNavKey.currentState!.pop();
    await frames(t, 12);
    expect(find.byType(RequestsScreen), findsOne);
    expect(find.text(_second), findsOne);
    expect(find.text(_first), findsNothing);
    await drain(t);
  });

  testWidgets('a decline on a card the accept has not cleared yet does '
      'nothing', (t) async {
    rows.person(_second, accepted: 0);
    await show(t);
    final card = find.byKey(const ValueKey('req_$_first'));
    final gate = Completer<void>();
    rows.gate = gate;
    await t.tap(
      find.descendant(of: card, matching: find.text(l10n.commonAccept)),
    );
    await frames(t);
    // the list has not read again: the card is still up
    expect(card, findsOne);
    await t.tap(
      find.descendant(of: card, matching: find.text(l10n.requestsDecline)),
    );
    await frames(t);
    rows.gate = null;
    gate.complete();
    await frames(t, 12);
    expect(rows.declined, isEmpty);
    expect(rows.people[_first]!['accepted'], 1);
    await drain(t);
  });
}
