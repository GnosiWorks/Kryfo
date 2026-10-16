// SPDX-License-Identifier: GPL-3.0-or-later
// a chat added by a code or a link, or taken in from a request, asks for
// the safety number: a calm card with one tap to the number, which asks for
// all of it. it goes once they are verified. later folds it into one quiet
// line that stays until the number is compared or the line is closed. words
// a request, an introduction or a group gave read as not checked beside the
// name until then. with less movement the card is simply there, and folds
// at once. the chat's own screen over rows kept in maps
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        appState,
        kNameAsk,
        kNameLater,
        kNameSays,
        session,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('added by a code or a link: the chat asks for the safety '
      'number, and one tap opens it', (t) async {
    await person(flags: kNameAsk);
    await open(t);
    expect(find.text(l10n.chatCompareTitle), findsOneWidget);
    expect(find.text(l10n.chatCompareLine(_peer)), findsOneWidget);
    // nothing said about the words: they were given by the link they chose
    expect(find.text('Not checked'), findsNothing);
    await t.tap(find.text(l10n.chatVerify));
    await settle(t);
    expect(find.byType(KeyVerificationScreen), findsOneWidget);
    await devClose(t);
  });

  testWidgets('later folds the card into a quiet line, and the words stay '
      'not checked', (t) async {
    await person(flags: kNameAsk | kNameSays);
    await open(t);
    expect(find.text(l10n.chatCompareTitle), findsOneWidget);
    expect(find.text('Not checked'), findsNothing);
    await t.tap(find.text(l10n.chatCompareLater));
    await settle(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    expect(find.text(l10n.chatCompareFolded), findsOneWidget);
    expect(flagsNow(), kNameAsk | kNameSays | kNameLater);
    expect(find.text('Not checked'), findsNothing);
    await devClose(t);
  });

  testWidgets('the line comes back with the chat, read from the stored '
      'flags', (t) async {
    await person(flags: kNameAsk | kNameSays);
    await open(t);
    await t.tap(find.text(l10n.chatCompareLater));
    await settle(t);
    await devClose(t);
    await open(t);
    expect(find.text(l10n.chatCompareFolded), findsOneWidget);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('stored folded, the chat opens on the line, never the '
      'card', (t) async {
    await person(flags: kNameAsk | kNameLater);
    await open(t);
    expect(find.text(l10n.chatCompareFolded), findsOneWidget);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('compare on the line opens the safety number', (t) async {
    await person(flags: kNameAsk | kNameLater);
    await open(t);
    await t.tap(find.text(l10n.chatCompareNow));
    await settle(t);
    expect(find.byType(KeyVerificationScreen), findsOneWidget);
    await devClose(t);
  });

  testWidgets('the line has finger-sized buttons', (t) async {
    await person(flags: kNameAsk | kNameLater);
    await open(t);
    final compare = t.getSize(
      find
          .ancestor(
            of: find.text(l10n.chatCompareNow),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(compare.height, greaterThanOrEqualTo(44));
    expect(compare.width, greaterThanOrEqualTo(44));
    final x = t.getSize(find.byTooltip(l10n.chatCompareDismiss));
    expect(x.height, greaterThanOrEqualTo(44));
    expect(x.width, greaterThanOrEqualTo(44));
    await devClose(t);
  });

  testWidgets('the x puts it away for good, and the words stay not '
      'checked', (t) async {
    await person(flags: kNameAsk | kNameSays | kNameLater);
    await open(t);
    expect(find.text('Not checked'), findsNothing);
    await t.tap(find.byTooltip(l10n.chatCompareDismiss));
    await settle(t);
    expect(find.text(l10n.chatCompareFolded), findsNothing);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    expect(flagsNow(), kNameSays);
    expect(find.text('Not checked'), findsNothing);
    await devClose(t);
    // and it does not come back with the chat
    await open(t);
    expect(find.text(l10n.chatCompareFolded), findsNothing);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('no key held for them yet: no number, so no card', (t) async {
    await person(flags: kNameAsk);
    (session.primary as _Db).held = null;
    await open(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('verified, there is no card and no mark', (t) async {
    await person(flags: kNameAsk | kNameSays, verified: 1);
    await open(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    expect(find.text('Not checked'), findsNothing);
    await devClose(t);
  });

  testWidgets('the line goes once the number is marked verified', (t) async {
    await person(flags: kNameAsk | kNameLater);
    await open(t);
    expect(find.text(l10n.chatCompareFolded), findsOneWidget);
    await mem.update(
      'contacts',
      {'verified': 1},
      where: 'halo_id = ?',
      whereArgs: [_peer],
    );
    await t.tap(find.text(l10n.chatCompareNow));
    await settle(t);
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(t);
    expect(find.byType(KeyVerificationScreen), findsNothing);
    expect(find.text(l10n.chatCompareFolded), findsNothing);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('a request not taken in yet shows its words as not checked, '
      'and asks for nothing yet', (t) async {
    await person(flags: kNameAsk | kNameSays, accepted: 0);
    await open(t);
    expect(find.text('Not checked'), findsNothing);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  // the card's fold, on the frame it first shows
  Future<double> firstFrame(WidgetTester t, {required bool still}) async {
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
    final card = find.text(l10n.chatCompareTitle);
    for (var i = 0; i < 40 && card.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump();
    }
    expect(card, findsOneWidget);
    return t
        .widget<SizeTransition>(
          find.ancestor(of: card, matching: find.byType(SizeTransition)).first,
        )
        .sizeFactor
        .value;
  }

  testWidgets('the card folds in, and with less movement it is simply '
      'there', (t) async {
    await person(flags: kNameAsk);
    expect(await firstFrame(t, still: false), lessThan(1));
    await settle(t);
    await devClose(t);
    expect(await firstFrame(t, still: true), 1);
    await devClose(t);
  });

  // the card's fade, a frame after later is tapped
  Future<double> foldFrame(WidgetTester t, {required bool still}) async {
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
    await t.tap(find.text(l10n.chatCompareLater));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(find.text(l10n.chatCompareFolded), findsOneWidget);
    final card = find.text(l10n.chatCompareTitle);
    if (card.evaluate().isEmpty) return 0;
    return t
        .widget<FadeTransition>(
          find.ancestor(of: card, matching: find.byType(FadeTransition)).first,
        )
        .opacity
        .value;
  }

  testWidgets('later fades the card into the line', (t) async {
    await person(flags: kNameAsk);
    final fade = await foldFrame(t, still: false);
    expect(fade, greaterThan(0));
    expect(fade, lessThan(1));
    await settle(t);
    expect(find.text(l10n.chatCompareTitle), findsNothing);
    await devClose(t);
  });

  testWidgets('with less movement later swaps the card for the line at '
      'once', (t) async {
    await person(flags: kNameAsk);
    expect(await foldFrame(t, still: true), 0);
    // nothing on its way: no fade, no size moving
    expect(
      find.ancestor(
        of: find.text(l10n.chatCompareFolded),
        matching: find.byType(AnimatedSize),
      ),
      findsNothing,
    );
    final fades = t.widgetList<FadeTransition>(
      find.ancestor(
        of: find.text(l10n.chatCompareFolded),
        matching: find.byType(FadeTransition),
      ),
    );
    for (final f in fades) {
      expect(f.opacity.value, 1);
    }
    await devClose(t);
  });

  test('the safety number page asks for the whole number', () {
    expect(l10n.keyVerificationCompareAll('Ana'), contains('12'));
    final src = File(
      'lib/screens/key_verification_screen.dart',
    ).readAsStringSync();
    expect(src, contains('l10n.keyVerificationCompareAll('));
  });
}
