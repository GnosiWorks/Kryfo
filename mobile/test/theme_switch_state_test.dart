// SPDX-License-Identifier: GPL-3.0-or-later
// a theme or accent switch rebuilds every widget in place (ThemeRefresh):
// the composer keeps its words, caret and focus, and a held or locked voice
// recording goes on through it
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stickers/sticker_pack.dart' show StickerLibrary;
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/theme_refresh.dart';
import 'package:kryfo/widgets/voice_mic.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'pin_flow_fakes.dart' show phone;
import 'say_hi_fakes.dart';

const _peer = 'amber-new-river';
final rev = ValueNotifier(0);

Widget shell(Widget home) => ThemeRefresh(
  revision: rev,
  child: ListenableBuilder(listenable: rev, builder: (_, _) => devApp(home)),
);

Uint8List _wav() {
  const rate = 16000, n = 24000;
  final b = ByteData(44 + n * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = math.sin(2 * math.pi * 150 * i / rate);
    b.setInt16(44 + i * 2, (4000 * v).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

Future<void> flip() async {
  HaloColors.setAccent(HaloAccent.velvet);
  HaloColors.setLight(true);
  rev.value++;
}

void main() {
  late Directory docs;
  tearDown(() {
    HaloColors.setLight(false);
    HaloColors.setAccent(HaloAccent.yellow);
  });

  group('composer', () {
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
      appState.sendModeForTest = 'balanced';
      useEngineForTest(SayHiRelay());
      docs = Directory.systemTemp.createTempSync('tss');
      mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
      mockChannel('com.llfbandit.record/messages', (_) async => null);
      StickerLibrary.use(StickerLibrary(const []));
    });
    tearDown(() {
      StickerLibrary.use(null);
      mockChannel('plugins.flutter.io/path_provider', null);
      mockChannel('com.llfbandit.record/messages', null);
      docs.deleteSync(recursive: true);
    });

    testWidgets('composer text, caret and focus survive a switch', (t) async {
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
      phone(t);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      setL10nLocale(const Locale('en'));
      await t.pumpWidget(
        shell(
          const ChatScreen(
            peerHaloId: _peer,
            peerOnion: '',
            peerXPub: '',
            avatarSeed: _peer,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.enterText(find.byType(TextField), 'half a thought');
      await t.pump();
      final ctrl = t.widget<TextField>(find.byType(TextField)).controller!;
      ctrl.selection = const TextSelection.collapsed(offset: 4);
      final stateBefore = t.state(find.byType(ChatScreen));
      final focusBefore = t
          .state<EditableTextState>(find.byType(EditableText))
          .widget
          .focusNode
          .hasFocus;
      await flip();
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      final ctrl2 = t.widget<TextField>(find.byType(TextField)).controller!;
      expect(identical(t.state(find.byType(ChatScreen)), stateBefore), isTrue);
      expect(ctrl2.text, 'half a thought');
      expect(ctrl2.selection.baseOffset, 4);
      expect(
        t
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        focusBefore,
      );
      // the switch did land
      expect(HaloColors.amber, HaloAccent.velvet.light.accent);
      ctrl2.clear();
      await devClose(t);
    });
  });

  group('voice', () {
    late Directory tmp;
    late List<String> asked;
    String? recording;
    late List<VoiceTake> sent;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('tssv');
      asked = [];
      recording = null;
      sent = [];
      lockState.openForTest();
      _mock('plugins.flutter.io/path_provider', (_) async => tmp.path);
      _mock('com.llfbandit.record/messages', (c) async {
        asked.add(c.method);
        switch (c.method) {
          case 'create':
            final id = (c.arguments as Map)['recorderId'];
            _mock('com.llfbandit.record/events/$id', (_) async => null);
          case 'hasPermission':
            return true;
          case 'start':
            recording = (c.arguments as Map)['path'] as String;
            File(recording!).writeAsBytesSync(_wav());
            return null;
          case 'stop':
            return recording;
        }
        return null;
      });
    });
    tearDown(() {
      _mock('plugins.flutter.io/path_provider', null);
      _mock('com.llfbandit.record/messages', null);
      tmp.deleteSync(recursive: true);
    });

    Future<void> settle(WidgetTester t, {int turns = 20}) async {
      for (var i = 0; i < turns; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    HoldToTalkMicState mic(WidgetTester t) =>
        t.state<HoldToTalkMicState>(find.byType(HoldToTalkMic));

    testWidgets('a held recording goes on through a switch', (t) async {
      t.view.physicalSize = const Size(1000, 1800);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      setL10nLocale(const Locale('en'));
      await t.pumpWidget(
        shell(
          Scaffold(
            body: SafeArea(
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: HoldToTalkMic(disguise: false, onSend: sent.add),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      final g = await t.startGesture(t.getCenter(find.byType(HoldToTalkMic)));
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await t.pump();
      await settle(t);
      expect(mic(t).stage, VoiceStage.holding);
      final before = mic(t);
      await flip();
      await t.pump();
      await settle(t, turns: 5);
      expect(identical(mic(t), before), isTrue);
      expect(mic(t).stage, VoiceStage.holding);
      expect(asked, isNot(contains('stop')));
      // slide up to lock while the new theme is up
      await g.moveBy(const Offset(0, -50));
      await t.pump();
      await g.moveBy(const Offset(0, -50));
      await t.pump();
      expect(mic(t).stage, VoiceStage.locked);
      await g.up();
      await settle(t);
      // and a second switch while locked
      HaloColors.setAccent(HaloAccent.blue);
      HaloColors.setLight(false);
      rev.value++;
      await t.pump();
      await settle(t, turns: 5);
      expect(mic(t).stage, VoiceStage.locked);
      expect(asked, isNot(contains('stop')));
      await t.tap(find.bySemanticsLabel(l10n.commonSend));
      await settle(t);
      expect(sent, hasLength(1));
      expect(sent.single.ms, greaterThanOrEqualTo(400));
      await devClose(t);
      await settle(t);
    });
  });
}
