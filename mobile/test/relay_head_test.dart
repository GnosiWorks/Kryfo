// SPDX-License-Identifier: GPL-3.0-or-later
// relay has one colour, sky: the chat header's route line and the home
// pill, in both themes and across a live theme switch. over tor and direct
// keep text2 in the header
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        themeRevision,
        TorHalo,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stickers/sticker_pack.dart' show StickerLibrary;
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';

const _peer = 'amber-new-river';

const _chat = ChatScreen(
  peerHaloId: _peer,
  peerOnion: '',
  peerXPub: '',
  avatarSeed: _peer,
);

String _line(String mode) => switch (mode) {
  'balanced' => l10n.chatEncryptedViaRelay,
  'fast' => l10n.chatEncryptedDirect,
  _ => l10n.chatEncryptedOverTor,
};

Color? _textColour(WidgetTester t, String mode) =>
    t.widget<Text>(find.text(_line(mode))).style?.color;

Color? _lockColour(WidgetTester t) =>
    t.widget<Icon>(find.byIcon(Icons.lock_outline)).color;

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory docs;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = Curve.generateKeyPair();
    final amber = SignalSession();
    await amber.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await processPeerBundle(_peer, await makePreKeyBundleB64(amber));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('relay_head');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    StickerLibrary.use(StickerLibrary(const []));
    final mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
    });
    final db = SayHiDb(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    HaloColors.setLight(false);
    appState.sendModeForTest = 'balanced';
    StickerLibrary.use(null);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';
    for (final mode in ['balanced', 'private', 'fast']) {
      testWidgets('$theme theme, $mode: the route line colour', (t) async {
        HaloColors.setLight(light);
        appState.sendModeForTest = mode;
        await devOpen(t, _chat);
        await _settle(t);
        if (mode == 'balanced') {
          expect(_textColour(t, mode), HaloColors.sky);
          expect(_lockColour(t), HaloColors.sky);
        } else {
          expect(_textColour(t, mode), HaloColors.text2);
          expect(_lockColour(t), HaloColors.amber);
        }
        await devClose(t);
      });
    }
  }

  test('sky differs between the themes and from text2', () {
    HaloColors.setLight(false);
    final dark = HaloColors.sky;
    expect(dark, isNot(HaloColors.text2));
    HaloColors.setLight(true);
    expect(HaloColors.sky, isNot(dark));
    expect(HaloColors.sky, isNot(HaloColors.text2));
  });

  testWidgets('a live theme switch repaints the relay line', (t) async {
    appState.sendModeForTest = 'balanced';
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    // the app root rebuilds on themeRevision, the open chat is the same
    // const instance throughout
    await t.pumpWidget(
      ListenableBuilder(
        listenable: themeRevision,
        builder: (_, _) => devApp(_chat),
      ),
    );
    await _settle(t);
    expect(_textColour(t, 'balanced'), HaloColors.sky);
    for (final light in [true, false, true]) {
      HaloColors.setLight(light);
      themeRevision.value++;
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(_textColour(t, 'balanced'), HaloColors.sky, reason: '$light');
      expect(_lockColour(t), HaloColors.sky, reason: '$light');
    }
    await devClose(t);
  });

  group('the home pill', () {
    Color? label(WidgetTester t) =>
        t.widget<Text>(find.text(l10n.appViaRelay)).style?.color;

    // the 5px dot in the middle of the ring
    Color? dot(WidgetTester t) => t
        .widgetList<Container>(
          find.descendant(
            of: find.byType(TorHalo),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border == null)
        .color;

    setUp(() {
      appState.sendModeForTest = 'balanced';
      appState.setTorStatusForTest(TorStatus.off);
      appState.noteOnline(true);
    });

    // relay does not ride tor: the pill is sky whether tor is off, coming
    // up or reachable
    for (final light in [false, true]) {
      for (final tor in [
        TorStatus.off,
        TorStatus.starting,
        TorStatus.reachable,
      ]) {
        testWidgets('${light ? 'light' : 'dark'} theme, tor ${tor.name}: '
            'relay is sky', (t) async {
          HaloColors.setLight(light);
          appState.setTorStatusForTest(tor);
          await devOpen(
            t,
            const Center(child: TorHalo(label: true)),
            still: true,
          );
          expect(label(t), HaloColors.sky);
          expect(dot(t), HaloColors.sky);
          await devClose(t);
        });
      }
    }

    testWidgets('a live theme switch repaints it', (t) async {
      await devOpen(t, const Center(child: TorHalo(label: true)), still: true);
      for (final light in [true, false, true]) {
        await appState.setLight(light);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(label(t), HaloColors.sky, reason: '$light');
        expect(dot(t), HaloColors.sky, reason: '$light');
      }
      await devClose(t);
    });
  });
}
