// SPDX-License-Identifier: GPL-3.0-or-later
// a contact's supporter badge on their page: the tier they share, with its
// glyph, read out by name. none when they share none, a plain supporter for
// a tier this phone does not know, and it follows their next message while
// the page is open. the page's rows are kept in maps
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, appState, useDatabasesForTest, AppStateMessages;
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
  Future<bool> isBlocked(String haloId) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemDb mem;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.contacts = [];
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
    m.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      (c) async => null,
    );
  });

  Future<void> open(
    WidgetTester t,
    String? badge, {
    Locale locale = const Locale('en'),
    double scale = 1,
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
      'blocked': 0,
      'supporter_badge': badge,
    });
    final db = _Rows(mem);
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(
          t.view,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: app(
          const ContactScreen(haloId: _peer, avatarSeed: _peer, peerXPub: ''),
          locale: locale,
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  for (final (tier, glyph, label) in [
    ('supporter', '●', () => l10n.donateTierSupporter),
    ('patron', '◆', () => l10n.donateTierPatron),
    ('guardian', '✦', () => l10n.donateTierGuardian),
  ]) {
    testWidgets('a $tier shows the tier on their page', (t) async {
      final semantics = t.ensureSemantics();
      await open(t, tier);
      expect(find.text('$glyph ${label()}'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(label()))),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(RegExp(glyph)), findsNothing);
      semantics.dispose();
      await close(t);
    });
  }

  testWidgets('no badge shared, no badge shown', (t) async {
    await open(t, null);
    expect(find.textContaining(l10n.donateTierGuardian), findsNothing);
    expect(find.text(l10n.chatSupporter), findsNothing);
    await close(t);
  });

  testWidgets('a plain accepted contact has no status line', (t) async {
    await open(t, null);
    for (final s in [
      'Added by hand',
      l10n.contactStatusBlocked,
      l10n.contactStatusKeysVerifiedInPerson,
      l10n.contactStatusWaitingInRequests,
    ]) {
      expect(find.text(s), findsNothing);
    }
    await close(t);
  });

  testWidgets('a tier from a newer app reads as a supporter', (t) async {
    await open(t, 'founder');
    expect(find.text(l10n.chatSupporter), findsOneWidget);
    await close(t);
  });

  testWidgets('it follows their next message while the page is open', (
    t,
  ) async {
    await open(t, null);
    expect(find.textContaining(l10n.donateTierPatron), findsNothing);
    await mem.update('contacts', {'supporter_badge': 'patron'});
    appState.chatChanged(_peer);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('◆ ${l10n.donateTierPatron}'), findsOneWidget);
    // turned off on their phone: absent on their next message
    await mem.update('contacts', {'supporter_badge': null});
    appState.chatChanged(_peer);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining(l10n.donateTierPatron), findsNothing);
    await close(t);
  });

  for (final lang in ['de', 'ar']) {
    testWidgets('it fits in $lang at a large font', (t) async {
      setL10nLocale(Locale(lang));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await open(t, 'guardian', locale: Locale(lang), scale: 2.0);
      expect(t.takeException(), isNull);
      expect(find.text('✦ ${l10n.donateTierGuardian}'), findsOneWidget);
      await close(t);
    });
  }
}
