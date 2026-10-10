// SPDX-License-Identifier: GPL-3.0-or-later
// a request's line above the thread never pushes the composer off: on the
// smallest phone at a big font with the keyboard up it tightens, and past
// its share of the room it scrolls. drawn in the test font, which is wider
// and taller than the app's, so what fits here fits on a phone
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
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stickers/sticker_pack.dart' show StickerLibrary;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';

const _peer = 'amber-new-river';

// their key changed since too: two lines above the thread
class _Changed extends SayHiDb {
  _Changed(super.mem);
  bool changed = false;
  @override
  Future<bool> keyChanged(String haloId) async => changed;
}

void main() {
  late MemDb mem;
  late _Changed db;
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
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('request_fit');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    StickerLibrary.use(StickerLibrary(const []));
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
    });
    // a first message gone, nothing back: the request's line shows
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'out',
      'plaintext': 'hello from the cafe',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': 'first-1',
      'sent': 1,
    });
    db = _Changed(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    StickerLibrary.use(null);
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
    setL10nLocale(const Locale('en'));
  });

  testWidgets('on a 360x640 screen at 1.5x text with the keyboard up, the '
      'request line and the composer fit, in every language', (t) async {
    t.view.physicalSize = const Size(720, 1280);
    t.view.devicePixelRatio = 2;
    t.view.viewInsets = const FakeViewPadding(bottom: 560);
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    for (final (locale, changed) in [
      for (final l in AppLocalizations.supportedLocales) (l, false),
      // with a second line above the thread, the lines scroll in their share
      (const Locale('de'), true),
      (const Locale('en'), true),
    ]) {
      db.changed = changed;
      setL10nLocale(locale);
      await t.pumpWidget(
        devApp(
          const ChatScreen(
            peerHaloId: _peer,
            peerOnion: '',
            peerXPub: '',
            avatarSeed: _peer,
          ),
          locale: locale,
          scale: 1.5,
        ),
      );
      for (var i = 0; i < 6; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(l10n.chatMessageRequest), findsOneWidget);
      // tight: what they need to do on one line
      expect(
        t.widget<Text>(find.text(l10n.chatTheyNeedToAccept)).maxLines,
        1,
        reason: '$locale',
      );
      if (changed) {
        expect(find.text(l10n.chatSecurityCodeChanged), findsOneWidget);
      }
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      // the composer is whole, above the keyboard
      expect(
        t.getRect(field).bottom,
        lessThanOrEqualTo(360),
        reason: '$locale $changed',
      );
      expect(t.takeException(), isNull, reason: '$locale $changed');
      await devClose(t);
    }
  });
}
