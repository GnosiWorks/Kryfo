// SPDX-License-Identifier: GPL-3.0-or-later
// a request filed on an id of its own, because the name it gave is bound
// here to another key, is called by a short name rather than its id, with
// the shield line saying which name it gave. every other request keeps its
// three words. the database is a stand-in
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, unboundIdOf, useDatabasesForTest;
import 'package:kryfo/scam_shield.dart';
import 'package:kryfo/screens/requests_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Db implements HaloDb {
  final requests = <Map<String, Object?>>[];
  final shields = <String, Map<String, Object?>>{};

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> requestsInbox() async => [...requests];
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => [...requests];
  @override
  Future<int> pendingRequestCount() async => requests.length;
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async =>
      shields[haloId];
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async => [];
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

const _amber = 'amber-still-river';

void main() {
  final own = unboundIdOf(List.generate(33, (i) => i));

  test('an id of its own gets the short name, three words stay', () {
    expect(requestTitle(own), l10n.requestsSomeoneNew);
    expect(requestTitle(_amber), _amber);
    expect(requestTitle('0' * 64), '0' * 64);
  });

  testWidgets('the request reads as someone new who says who they are', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final db = _Db();
    final hit = const ShieldHit('other_key', _amber).toJson();
    db.requests.addAll([
      {'halo_id': own, 'nickname': null, 'last_seen': 0, 'blocked': 0},
      {'halo_id': 'slow-kite-moss', 'nickname': null, 'last_seen': 0},
    ]);
    db.shields[own] = {
      'halo_id': own,
      'headline': jsonEncode(hit),
      'lines': jsonEncode([hit]),
      'dismissed': 0,
      'at': 1,
    };
    useDatabasesForTest(db, Session(db));
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RequestsScreen(),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text(own), findsNothing);
    expect(find.text(l10n.requestsSomeoneNew), findsOneWidget);
    expect(find.text(l10n.scamShieldSaysItIs(_amber)), findsOneWidget);
    expect(find.text('slow-kite-moss'), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
