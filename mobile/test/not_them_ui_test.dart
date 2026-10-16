// SPDX-License-Identifier: GPL-3.0-or-later
// "this isn't them" as seen: the button, its question, the Blocked page,
// small phones, languages and reduced motion. real database methods over
// rows in maps
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/key_number.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show HaloDb, appState, kNameAsk, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/blocked_screen.dart';
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'narrow_settings.dart' show loadAppFonts;
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'train-ball-cliff';
final _key = 'ab' * 32;

// the database's own methods, over the same rows
class _Real extends HaloDb {
  _Real(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

class _Db extends SayHiDb {
  _Db(super.mem) : real = _Real(mem);
  final _Real real;
  String? held = _key;
  @override
  Future<String?> heldKey(String haloId) async => held;
  @override
  Future<List<String>> removeAndBlockKey(String haloId, String keyHex) =>
      real.removeAndBlockKey(haloId, keyHex);
  @override
  Future<bool> tombed(String name) => real.tombed(name);
  @override
  Future<void> dropSeats(String haloId, String keyHex) =>
      real.dropSeats(haloId, keyHex);
  @override
  Future<bool> keyBlocked(String keyHex) => real.keyBlocked(keyHex);
  @override
  Future<List<({String x, int at})>> blockedKeys() => real.blockedKeys();
  @override
  Future<void> unblockKey(String keyHex) => real.unblockKey(keyHex);
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => const [];
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
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('not_them_ui');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    mem = MemDb();
    await devChatTables(mem, now: 1);
  });

  tearDown(() {
    StickerLibrary.use(null);
    HaloColors.setLight(false);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Future<_Db> person({int verified = 0}) async {
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': _key,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'verified': verified,
      'name_check': kNameAsk,
    });
    final db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    return db;
  }

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  const chat = ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub: '',
    avatarSeed: _peer,
  );

  final number = KeyVerificationScreen(
    peerHaloId: _peer,
    peerName: _peer,
    myXpub: 'cd' * 32,
    peerXpub: _key,
  );

  bool gone() => !mem.rows('contacts').any((r) => r['halo_id'] == _peer);
  List<Object?> blocked() => [for (final r in mem.rows('blocked_keys')) r['x']];

  // the sheet's yes, or its cancel
  Future<void> answer(WidgetTester t, {required bool yes}) async {
    expect(find.text(l10n.notThemSheetTitle), findsOneWidget);
    expect(find.text(l10n.notThemSheetLine), findsOneWidget);
    await t.tap(find.text(yes ? l10n.notThemRemove : l10n.commonCancel));
    await settle(t, 10);
  }

  testWidgets('on the compare card, numbers different opens the safety '
      'number with this isn\'t them up, and its yes takes them off this phone '
      'and blocks the key', (t) async {
    await person();
    await devOpen(t, chat);
    await settle(t);
    expect(find.text(l10n.notThemButton), findsNothing);
    await t.tap(find.text(l10n.notThemNumbersDiffer));
    await settle(t);
    expect(find.byType(KeyVerificationScreen), findsOneWidget);
    expect(find.text(l10n.notThemLine), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.notThemButton), findsOneWidget);
    await t.tap(find.text(l10n.notThemButton));
    await settle(t);
    await answer(t, yes: true);
    expect(gone(), isTrue);
    expect(blocked(), [_key]);
    expect(mem.rows('name_tombs').map((r) => r['name']), [_peer]);
    expect(find.text(l10n.notThemDone), findsOneWidget);
    expect(find.byType(KeyVerificationScreen), findsNothing);
    await devClose(t);
  });

  testWidgets('under the safety number the same, and the page goes', (t) async {
    await person();
    await devOpen(t, chat);
    await settle(t);
    await t.tap(find.text(l10n.chatVerify));
    await settle(t);
    expect(find.byType(KeyVerificationScreen), findsOneWidget);
    await t.tap(find.text(l10n.notThemNumbersDiffer).last);
    await settle(t);
    await t.tap(find.text(l10n.notThemButton).last);
    await settle(t);
    await answer(t, yes: true);
    expect(gone(), isTrue);
    expect(blocked(), [_key]);
    expect(find.byType(KeyVerificationScreen), findsNothing);
    await devClose(t);
  });

  testWidgets('cancel leaves them and their key as they were', (t) async {
    await person();
    await devOpen(t, number);
    await settle(t);
    await t.tap(find.text(l10n.notThemNumbersDiffer));
    await settle(t);
    await t.tap(find.text(l10n.notThemButton));
    await settle(t);
    await answer(t, yes: false);
    expect(gone(), isFalse);
    expect(blocked(), isEmpty);
    expect(find.text(l10n.notThemButton), findsOneWidget);
    await devClose(t);
  });

  testWidgets('their key moved while the sheet was up: nothing goes, and '
      'the new number is asked for', (t) async {
    final db = await person();
    await devOpen(t, number);
    await settle(t);
    await t.tap(find.text(l10n.notThemNumbersDiffer));
    await settle(t);
    await t.tap(find.text(l10n.notThemButton));
    await settle(t);
    db.held = 'ef' * 32;
    await answer(t, yes: true);
    expect(gone(), isFalse);
    expect(blocked(), isEmpty);
    expect(find.text(l10n.keyVerificationKeyMoved), findsOneWidget);
    await devClose(t);
  });

  testWidgets('a verified number shows none of it', (t) async {
    await person(verified: 1);
    await devOpen(t, number);
    await settle(t);
    expect(find.text(l10n.keyVerificationVerified), findsOneWidget);
    expect(find.text(l10n.notThemNumbersDiffer), findsNothing);
    await devClose(t);
  });

  testWidgets('no key yet, no number: none of it either', (t) async {
    final db = await person();
    db.held = null;
    await devOpen(t, number);
    await settle(t);
    expect(find.text(l10n.notThemNumbersDiffer), findsNothing);
    await devClose(t);
  });

  testWidgets('finger-sized, and with reduced motion it opens at once', (
    t,
  ) async {
    await person();
    await devOpen(t, number, still: true);
    await settle(t);
    final ask = find
        .ancestor(
          of: find.text(l10n.notThemNumbersDiffer),
          matching: find.byType(ConstrainedBox),
        )
        .first;
    expect(t.getSize(ask).height, greaterThanOrEqualTo(44));
    await t.tap(find.text(l10n.notThemNumbersDiffer));
    await t.pump();
    // at once, on the next frame
    expect(find.text(l10n.notThemButton), findsOneWidget);
    final button = find
        .ancestor(
          of: find.text(l10n.notThemButton),
          matching: find.byType(Container),
        )
        .first;
    expect(t.getSize(button).height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel(l10n.notThemButton), findsOneWidget);
    await devClose(t);
  });

  testWidgets('the Blocked page shows the key by its number, and unblocks '
      'it', (t) async {
    await person();
    await mem.insert('blocked_keys', {'x': 'cd' * 32, 'at': 1});
    await devOpen(t, const BlockedScreen());
    await settle(t);
    expect(find.text(l10n.blockedKey), findsOneWidget);
    final n = keyNumber([for (var i = 0; i < 32; i++) 0xcd])!;
    expect(find.text(n), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('${l10n.pairCodeKeyNumber} $n')),
      findsOneWidget,
    );
    expect(find.text(l10n.blockedNoOneIsBlocked), findsNothing);
    await t.tap(find.text(l10n.commonUnblock));
    await settle(t, 10);
    expect(mem.rows('blocked_keys'), isEmpty);
    expect(find.text(l10n.blockedNoOneIsBlocked), findsOneWidget);
    await devClose(t);
  });

  // a small phone, in each language asked, light and dark, the panel open:
  // nothing runs off the edge. with KRYFO_SHOTS set, each is kept as a png
  final shots = Platform.environment['KRYFO_SHOTS'];
  for (final lang in ['en', 'de', 'ru', 'ar', 'fa', 'vi']) {
    for (final light in [false, true]) {
      for (final (name, page) in [('number', number), ('card', chat)]) {
        testWidgets('$name fits 360 wide: $lang, ${light ? 'light' : 'dark'}', (
          t,
        ) async {
          await t.runAsync(loadAppFonts);
          HaloColors.setLight(light);
          await person();
          await devOpen(
            t,
            RepaintBoundary(child: page),
            locale: Locale(lang),
            size: const Size(1080, 2340),
            ratio: 3,
          );
          await settle(t);
          if (name == 'number') {
            await t.tap(find.text(l10n.notThemNumbersDiffer));
            await settle(t);
            expect(find.text(l10n.notThemButton), findsOneWidget);
          } else {
            expect(find.text(l10n.notThemNumbersDiffer), findsOneWidget);
          }
          expect(t.takeException(), isNull);
          if (shots != null) {
            final b = t.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            await t.runAsync(() async {
              final img = await b.toImage(pixelRatio: 1.5);
              final png = await img.toByteData(format: ui.ImageByteFormat.png);
              Directory(shots).createSync(recursive: true);
              File(
                '$shots/${name}_${lang}_${light ? 'light' : 'dark'}.png',
              ).writeAsBytesSync(png!.buffer.asUint8List());
            });
          }
          await devClose(t);
        });
      }
    }
  }
}
