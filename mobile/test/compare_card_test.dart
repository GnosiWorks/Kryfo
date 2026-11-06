// SPDX-License-Identifier: GPL-3.0-or-later
// someone added by a code or a link, or taken in from a request: their chat
// asks nothing. the first visit to their page asks once for the safety
// number, a plain card with one tap to it, which asks for all of it. the
// page's own button reaches it after that. the flag that it was asked sits
// on the side the contact lives on, the vault for a hidden one
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        appState,
        kNameAsk,
        kNameLater,
        kNameSays,
        kNameShown,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateRefresh;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/contact_screen.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'amber-calm-river';

// the chat's rows, with the name's flags written as the app writes them
class _Db extends SayHiDb {
  _Db(super.mem);
  @override
  Future<void> setNameCheck(String haloId, int flags) => mem.update(
    'contacts',
    {'name_check': flags},
    where: 'halo_id = ?',
    whereArgs: [haloId],
  );
  // the key held for them, none before anything came
  String? held = 'ab' * 32;
  @override
  Future<String?> heldKey(String haloId) async => held;
}

// a contact page's rows over maps, without what its lists read
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
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
}

void main() {
  late MemDb mem;
  late Directory docs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('compare_card');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    mem = MemDb();
    await devChatTables(mem, now: 1);
  });

  tearDown(() {
    StickerLibrary.use(null);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> person({
    required int flags,
    int accepted = 1,
    int verified = 0,
  }) async {
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': accepted,
      'back_paired': 1,
      'verified': verified,
      'name_check': flags,
    });
    final db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  }

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester t, {bool still = false}) async {
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: '',
        avatarSeed: _peer,
      ),
      still: still,
    );
    await settle(t);
  }

  int flagsNow() =>
      mem
              .rows('contacts')
              .firstWhere((r) => r['halo_id'] == _peer)['name_check']
          as int;

  testWidgets('added by a code or a link: the chat asks for nothing, '
      'whatever the flags say', (t) async {
    for (final flags in [
      kNameAsk,
      kNameAsk | kNameSays,
      kNameAsk | kNameLater,
    ]) {
      await mem.delete('contacts');
      await person(flags: flags);
      await open(t);
      expect(find.text(l10n.chatCompareTitle), findsNothing);
      expect(find.text(l10n.chatCompareLater), findsNothing);
      expect(find.text(l10n.chatCompareNow), findsNothing);
      expect(find.text('Not checked'), findsNothing);
      // and the chat writes nothing to them
      expect(flagsNow(), flags);
      await devClose(t);
    }
  });

  // their contact row and its key, on [db]'s side
  Future<void> row(
    MemDb db, {
    required int flags,
    int verified = 0,
    bool key = true,
  }) async {
    await db.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': '',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'verified': verified,
      // a mark holds only for the key it was set on
      if (verified == 1) 'verified_key': '07' * 32,
      'name_check': flags,
    });
    if (key) {
      await db.insert('peer_identities', {
        'address': _peer,
        'identity_key': Uint8List.fromList([5, ...List.filled(32, 7)]),
      });
    }
  }

  Future<void> page(WidgetTester t, {bool still = false}) async {
    await devOpen(
      t,
      const ContactScreen(haloId: _peer, avatarSeed: _peer, peerXPub: ''),
      still: still,
    );
    await settle(t);
  }

  int flagsIn(MemDb db) =>
      db.rows('contacts').firstWhere((r) => r['halo_id'] == _peer)['name_check']
          as int;

  Future<MemDb> everyday({required int flags, int verified = 0}) async {
    final live = MemDb();
    await row(live, flags: flags, verified: verified);
    final db = _Rows(live);
    useDatabasesForTest(db, Session(db));
    return live;
  }

  testWidgets('the first visit to their page asks once, and the next one '
      'leaves the number under the page', (t) async {
    final live = await everyday(flags: kNameAsk | kNameSays);
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsOneWidget);
    expect(find.text(l10n.chatCompareLine(_peer)), findsOneWidget);
    expect(flagsIn(live), kNameAsk | kNameSays | kNameShown);
    await devClose(t);
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    expect(find.text(l10n.contactVerifyKeys), findsOneWidget);
    await t.tap(find.text(l10n.contactVerifyKeys));
    await settle(t);
    expect(find.byType(KeyVerificationScreen), findsOneWidget);
    await devClose(t);
  });

  testWidgets('compare opens the safety number, later puts the card '
      'away', (t) async {
    await everyday(flags: kNameAsk);
    await page(t);
    await t.tap(find.text(l10n.chatCompareNow));
    await settle(t);
    expect(find.byType(KeyVerificationScreen), findsOneWidget);
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(t);
    // still the same visit: the card stays until put away
    expect(find.text(l10n.chatCompareTitle), findsOneWidget);
    await t.tap(find.text(l10n.chatCompareLater));
    await settle(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('a card asked on a chat by an older build is asked once on '
      'the page too', (t) async {
    final live = await everyday(flags: kNameAsk | kNameLater);
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsOneWidget);
    expect(flagsIn(live), kNameAsk | kNameLater | kNameShown);
    await devClose(t);
  });

  testWidgets('no key held, verified or put away for good: no card and '
      'nothing written', (t) async {
    final live = MemDb();
    await row(live, flags: kNameAsk, key: false);
    final db = _Rows(live);
    useDatabasesForTest(db, Session(db));
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    expect(flagsIn(live), kNameAsk);
    await devClose(t);
    final v = await everyday(flags: kNameAsk, verified: 1);
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    expect(flagsIn(v), kNameAsk);
    await devClose(t);
    final none = await everyday(flags: kNameSays);
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    expect(flagsIn(none), kNameSays);
    await devClose(t);
  });

  testWidgets('a hidden contact keeps the flag in the vault', (t) async {
    final live = MemDb();
    final hidden = MemDb();
    await row(hidden, flags: kNameAsk);
    final primary = _Rows(live);
    useDatabasesForTest(
      primary,
      await Session.withVault(primary, _Rows(hidden)),
    );
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsOneWidget);
    expect(flagsIn(hidden), kNameAsk | kNameShown);
    expect(live.rows('contacts'), isEmpty);
    await devClose(t);
    await page(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('the card eases in, and with reduced motion it is there at '
      'once', (t) async {
    for (final still in [false, true]) {
      await everyday(flags: kNameAsk);
      await devOpen(
        t,
        const ContactScreen(haloId: _peer, avatarSeed: _peer, peerXPub: ''),
        still: still,
      );
      final card = find.text(l10n.chatCompareTitle);
      for (var i = 0; i < 40 && card.evaluate().isEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await t.pump();
      }
      expect(card, findsOneWidget);
      expect(
        find.ancestor(of: card, matching: find.byType(AnimatedSize)),
        still ? findsNothing : findsWidgets,
      );
      await devClose(t);
    }
  });

  test('the safety number page asks for the whole number', () {
    expect(l10n.keyVerificationCompareAll('Ana'), contains('12'));
    final src = File(
      'lib/screens/key_verification_screen.dart',
    ).readAsStringSync();
    expect(src, contains('l10n.keyVerificationCompareAll('));
  });
}
