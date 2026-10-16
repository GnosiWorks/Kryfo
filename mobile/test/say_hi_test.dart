// SPDX-License-Identifier: GPL-3.0-or-later
// someone added from a link or a code hears nothing until a first message
// lands. their chat opens, and while nothing has gone to them a card says
// so and waves: the pack's waving sticker, or the emoji, once, as the first
// message of a request. the chat's own screen, with real signal over rows
// kept in maps and a relay that answers when told
import 'dart:convert';
import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        appState,
        makePreKeyBundleB64,
        openAddedChatLater,
        processPeerBundle,
        rootNavKey,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart' show grindPow, powBits, verifyPow;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_view.dart' show StickerView;
import 'package:kryfo/theme.dart' show buildHaloTheme;
import 'package:kryfo/widgets/say_hi_card.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show
        CiphertextMessage,
        Curve,
        PreKeySignalMessage,
        SessionCipher,
        SignalMessage,
        SignalProtocolAddress;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'narrow_settings.dart' show loadAppFonts;
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'amber-new-river';

// the app's root navigator, as a link's add pushes onto it
Widget _app({
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  navigatorKey: rootNavKey,
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: const Scaffold(),
);

void main() {
  late SignalSession amber;
  late MemDb mem;
  late SayHiRelay relay;
  late Directory docs;
  late StickerLibrary packs;
  late List<String> ground;

  setUpAll(() async {
    // a line is as wide as on a phone
    await loadAppFonts();
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = Curve.generateKeyPair();
    amber = SignalSession();
    await amber.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    // added from her card: a session, and nothing sent on it
    await processPeerBundle(_peer, await makePreKeyBundleB64(amber));
  });

  // the phone's rows: amber added and nothing between us, unless told
  Future<void> world({
    HaloContainer container = HaloContainer.everyday,
    bool knowsMe = false,
  }) async {
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': knowsMe ? 1 : 0,
    });
    final db = SayHiDb(mem, container);
    if (container.quiet) {
      final everyday = MemDb();
      await devChatTables(everyday);
      useDatabasesForTest(SayHiDb(everyday), Session(db));
    } else {
      useDatabasesForTest(db, Session(db));
    }
    await appState.refreshContacts();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    relay = SayHiRelay();
    useEngineForTest(relay);
    ground = [];
    // the proof of work is ground for real, and noted
    grindPowForTest = (text) {
      ground.add(text);
      return grindPow(text, powBits);
    };
    docs = Directory.systemTemp.createTempSync('say_hi');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    // the mic's recorder is made with the composer and let go with it
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    packs = useLibrary();
    await world();
  });

  tearDown(() {
    grindPowForTest = null;
    StickerLibrary.use(null);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  // what runs off the test's clock (the seal) and the frames after it
  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  ChatScreen chat() => ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub: 'ab' * 32,
    avatarSeed: _peer,
  );

  Future<void> open(
    WidgetTester t, {
    bool still = false,
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    await devOpen(t, chat(), still: still, locale: locale, scale: scale);
    await settle(t);
  }

  // what amber reads of a cipher of ours
  Future<Map<String, dynamic>> ambersRead(String cipher) async {
    final w = base64Decode(cipher);
    final body = Uint8List.fromList(w.sublist(1));
    final c = SessionCipher(
      amber.sessionStore,
      amber.preKeyStore,
      amber.signedPreKeyStore,
      amber.identityStore,
      const SignalProtocolAddress('me-to-amber', 1),
    );
    final plain = w[0] == CiphertextMessage.prekeyType
        ? await c.decrypt(PreKeySignalMessage(body))
        : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
    final s = utf8.decode(plain);
    expect(s, startsWith('halo/1:'));
    return jsonDecode(s.substring(7)) as Map<String, dynamic>;
  }

  List<Map<String, Object?>> outRows() => [
    for (final r in mem.rows('messages'))
      if (r['direction'] == 'out') r,
  ];

  final card = find.byType(SayHiCard);
  // the card's button, in the language of the moment
  Finder wave() => find.text(l10n.chatWave);

  // the waving hand's turn now, 0 at rest
  double handTurn(WidgetTester t) {
    final m = t
        .widget<Transform>(find.byKey(const ValueKey('wave-hand')).first)
        .transform;
    return m.storage[1].abs();
  }

  // the most the card rose and the hand turned while the chat opened
  Future<(double, double)> watchOpening(
    WidgetTester t, {
    bool still = false,
  }) async {
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    setL10nLocale(const Locale('en'));
    await t.pumpWidget(devApp(chat(), still: still));
    var rise = 0.0, turn = 0.0;
    for (var i = 0; i < 50; i++) {
      await t.pump(const Duration(milliseconds: 40));
      if (card.evaluate().isEmpty) continue;
      final r = t.widget<Transform>(find.byKey(const ValueKey('say-hi-rise')));
      rise = max(rise, r.transform.storage[13].abs());
      turn = max(turn, handTurn(t));
    }
    await settle(t);
    return (rise, turn);
  }

  testWidgets('someone added from a link: their chat opens, with the card', (
    t,
  ) async {
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    setL10nLocale(const Locale('en'));
    // the lock is down: what a link opens opens now
    lockState.openForTest();
    await t.pumpWidget(_app());
    // as the add hands it over once the person is in
    openAddedChatLater(_peer);
    await t.pump(const Duration(milliseconds: 500));
    await settle(t);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(card, findsOneWidget);
    expect(find.text(l10n.chatSayHiSoThey), findsOneWidget);
    expect(find.text(l10n.chatTheyWonTKnow), findsOneWidget);
    // the pack's waving sticker, playing in the card
    final hi = wavingSticker(packs)!.$2;
    expect(hi.emoji, kWaveEmoji);
    final drawn = find.descendant(of: card, matching: find.byType(StickerView));
    expect(drawn, findsOneWidget);
    expect(t.widget<StickerView>(drawn).sticker, same(hi));
    await devClose(t);
  });

  testWidgets('the wave sends the waving sticker once, as a request\'s '
      'first message, and the card goes', (t) async {
    final (rise, turn) = await watchOpening(t);
    // it rose in, and the hand waved once on its own
    expect(rise, greaterThan(0));
    expect(turn, greaterThan(0));
    expect(card, findsOneWidget);
    expect(handTurn(t), 0);
    await t.tap(wave());
    // a second tap while the first goes sends nothing more
    await t.tap(wave(), warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    expect(handTurn(t), greaterThan(0), reason: 'the hand did not wave');
    await settle(t);
    expect(relay.ciphers, hasLength(1));
    expect(outRows(), hasLength(1));
    final hi = wavingSticker(packs)!;
    final read = await t.runAsync(() => ambersRead(relay.ciphers.single));
    expect(read!['m'], kWaveEmoji);
    expect(read['st'], '${hi.$1.name}:${hi.$2.id}:${hi.$2.since}');
    // its proof of work, as any first message to someone who has not
    // written back
    expect(ground, [kWaveEmoji]);
    expect(verifyPow(kWaveEmoji, read['pw'] as int, powBits), isTrue);
    expect(card, findsNothing);
    relay.sends.single.complete('ok');
    await settle(t);

    // it is the first of the two a request gets
    await t.enterText(find.byType(TextField).last, 'it is me, from the cafe');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
    expect(relay.ciphers, hasLength(2));
    relay.sends.last.complete('ok');
    await settle(t);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.text(l10n.chatWaitingForThemTo), findsOneWidget);
    expect(card, findsNothing);
    await devClose(t);
  });

  testWidgets('two taps before the next frame wave once, and the sticker '
      'leaves the card for its flight', (t) async {
    final hi = wavingSticker(packs)!.$2;
    final waves = <Rect>[];
    await devOpen(
      t,
      Scaffold(
        body: SayHiCard(sticker: hi, onWave: (from, _) => waves.add(from)),
      ),
    );
    final art = find.byType(StickerView);
    await t.tap(wave());
    await t.tap(art);
    await t.tap(wave());
    expect(waves, hasLength(1));
    // from where the sticker was drawn
    expect(waves.single, t.getRect(art));
    await t.pump();
    expect(
      t
          .widget<Opacity>(
            find.ancestor(of: art, matching: find.byType(Opacity)).first,
          )
          .opacity,
      0,
    );
    await devClose(t);
  });

  testWidgets('with no waving sticker the wave is the emoji, and what is '
      'typed stays', (t) async {
    StickerLibrary.use(StickerLibrary(const []));
    await open(t);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(kWaveEmoji)),
      findsWidgets,
    );
    await t.enterText(find.byType(TextField).last, 'half a thought');
    await t.pump();
    await t.tap(wave());
    await settle(t);
    expect(relay.ciphers, hasLength(1));
    final read = await t.runAsync(() => ambersRead(relay.ciphers.single));
    expect(read!['m'], kWaveEmoji);
    expect(read.containsKey('st'), isFalse);
    expect(ground, [kWaveEmoji]);
    expect(
      t.widget<TextField>(find.byType(TextField).last).controller!.text,
      'half a thought',
    );
    expect(card, findsNothing);
    relay.sends.single.complete('ok');
    await settle(t);
    await devClose(t);
  });

  testWidgets('a typed first message takes the card away too', (t) async {
    await open(t);
    expect(card, findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'hello from the cafe');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
    expect(relay.ciphers, hasLength(1));
    expect(card, findsNothing);
    final read = await t.runAsync(() => ambersRead(relay.ciphers.single));
    expect(read!['m'], 'hello from the cafe');
    relay.sends.single.complete('ok');
    await settle(t);
    await devClose(t);
  });

  testWidgets('opened again, the card is there only while nothing went to '
      'them', (t) async {
    await open(t);
    expect(card, findsOneWidget);
    await devClose(t);
    // something on its way, not yet gone: they will hear, the card is done
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'out',
      'plaintext': 'hi there',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': 'queued-1',
      'sent': 0,
    });
    await open(t);
    expect(card, findsNothing);
    expect(find.text('hi there'), findsOneWidget);
    await devClose(t);
  });

  testWidgets('someone who knows this phone gets no card', (t) async {
    // they wrote once; what they wrote is gone since
    await t.runAsync(() => world(knowsMe: true));
    await open(t);
    expect(card, findsNothing);
    expect(find.text(l10n.chatSayHi), findsOneWidget);
    await devClose(t);
    // one whose words are still here
    await t.runAsync(world);
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'are you there',
      'sent_at': DateTime.now().millisecondsSinceEpoch - 600000,
    });
    await open(t);
    expect(card, findsNothing);
    expect(find.text('are you there'), findsOneWidget);
    await devClose(t);
  });

  testWidgets('in the decoy the card is the same, and the wave stays here '
      'as anything sent there does', (t) async {
    await t.runAsync(() => world(container: HaloContainer.decoy));
    await open(t);
    expect(card, findsOneWidget);
    expect(find.text(l10n.chatSayHiSoThey), findsOneWidget);
    await t.tap(wave());
    await settle(t);
    expect(relay.ciphers, isEmpty);
    expect(ground, isEmpty);
    expect(outRows(), hasLength(1));
    expect(outRows().single['sent'], 0);
    expect(outRows().single['sticker'], isNotNull);
    expect(card, findsNothing);
    await devClose(t);
  });

  testWidgets('reduced motion: the card neither rises, waves '
      'nor lingers', (t) async {
    final (rise, turn) = await watchOpening(t, still: true);
    expect(card, findsOneWidget);
    expect(rise, 0);
    expect(turn, 0);
    await t.tap(wave());
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    // gone in the frame the row came, nothing flew
    expect(card, findsNothing);
    expect(t.takeException(), isNull);
    await settle(t);
    expect(relay.ciphers, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    await devClose(t);
  });

  for (final (code, keyboard) in [
    ('ar', false),
    ('fa', true),
    ('de', true),
    ('en', true),
  ]) {
    testWidgets('on a 360x640 screen at 1.5x text in $code'
        '${keyboard ? ' with the keyboard up' : ''}, the card fits, its '
        'wave is in reach, and the request line after it fits too', (t) async {
      t.view.physicalSize = const Size(720, 1280);
      t.view.devicePixelRatio = 2;
      if (keyboard) {
        t.view.viewInsets = const FakeViewPadding(bottom: 560);
      }
      addTearDown(t.view.reset);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      setL10nLocale(Locale(code));
      await t.pumpWidget(devApp(chat(), locale: Locale(code), scale: 1.5));
      await settle(t);
      expect(card, findsOneWidget);
      expect(find.text(l10n.chatSayHiSoThey), findsOneWidget);
      final dir = Directionality.of(t.element(card));
      expect(
        dir,
        code == 'ar' || code == 'fa' ? TextDirection.rtl : TextDirection.ltr,
      );
      // the button is in reach: scrolled to if the room is short
      await t.ensureVisible(wave());
      await t.pump();
      expect(
        t.getRect(wave()).bottom,
        lessThanOrEqualTo(640 - (keyboard ? 280 : 0)),
      );
      await t.tap(wave());
      await settle(t);
      expect(relay.ciphers, hasLength(1));
      relay.sends.single.complete('ok');
      await settle(t);
      // the request's line has come in above the thread, and all of it fits
      expect(find.text(l10n.chatMessageRequest), findsOneWidget);
      expect(t.takeException(), isNull);
      setL10nLocale(const Locale('en'));
      await devClose(t);
    });
  }
}
