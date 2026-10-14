// SPDX-License-Identifier: GPL-3.0-or-later
// a person's page holds the window while their chat blocks, since it shows
// the chat's media, and follows a change made while it is open. someone
// blocked holds nothing and has no switch. the page's rows are kept in
// maps, android's channel a fake
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/screens/contact_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;

const _peer = 'calm-orbit-lantern';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<List<Map<String, Object?>>> mediaFor(String peerId) async => [];
  @override
  Future<int?> firstMessageAt(String peerId) async => null;
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => const {};
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<void> queueFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async {}
  @override
  Future<bool> isBlocked(String haloId) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<bool> told;
  late MemDb mem;

  setUp(() {
    told = [];
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.contacts = [];
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
    m.setMockMethodCallHandler(const MethodChannel('halo/platform'), (c) async {
      if (c.method == 'setSecure') told.add((c.arguments as Map)['on'] as bool);
      return null;
    });
  });

  Future<void> open(
    WidgetTester t, {
    int on = 0,
    int can = 10,
    int blocked = 0,
  }) async {
    phone(t);
    mem = MemDb();
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': '',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'blocked': blocked,
      'shots_on': on,
      'shots_at': on == 1 ? 5 : 0,
      'shots_can': can,
    });
    final db = _Rows(mem);
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(
      app(const ContactScreen(haloId: _peer, avatarSeed: _peer, peerXPub: '')),
    );
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  testWidgets('a chat that blocks holds the page, and lets go as it closes', (
    t,
  ) async {
    await open(t, on: 1);
    expect(told.last, isTrue);
    expect(find.text(l10n.chatShotsBothPhones), findsOneWidget);
    await close(t);
    expect(told.last, isFalse);
  });

  testWidgets('a change made while it is open shows here', (t) async {
    await open(t);
    expect(told.where((on) => on), isEmpty);
    expect(find.text(l10n.chatShotsBlocksBoth), findsOneWidget);
    await t.runAsync(() async {
      await appState.setChatShots(_peer, true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.chatShotsBothPhones), findsOneWidget);
    expect(told.last, isTrue);
    await close(t);
  });

  testWidgets('someone blocked holds nothing and has no switch', (t) async {
    await open(t, on: 1, blocked: 1);
    expect(told.where((on) => on), isEmpty);
    expect(find.text(l10n.chatBlockScreenshots), findsNothing);
    await close(t);
  });
}
