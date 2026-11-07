// SPDX-License-Identifier: GPL-3.0-or-later
// on a linked device the composer stands in a chat with a 0.6 contact whose
// devices reach this one; one none of whose devices opened to this one yet
// gets the phone's line saying why (waiting for their app, or no word from
// them in a while), and the composer once a pair of theirs opens. an older
// Kryfo always gets its own line. each line fits a narrow window with a
// long name
import 'dart:io';

import 'package:flutter/material.dart' show Locale, Size, TextField, ValueKey;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/devices/device_state.dart' show linkedDevicesForTest;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        appState,
        deviceQuietForTest,
        deviceReachesForTest,
        kDeviceQuietAfter,
        linkedRoleForTest,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest,
        AppStateMessages,
        AppStateRoute,
        AppStateRefresh;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'signal_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'calm-grey-heron';
const _name = 'Heron';

void main() {
  late MemDb mem;
  late Directory docs;
  var reaches = false;

  setUpAll(() async {
    final me = testKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = testKeyPair();
    final them = SignalSession();
    await them.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await processPeerBundle(_peer, await makePreKeyBundleB64(them));
  });

  Future<void> setUpWith(
    String caps, {
    String name = _name,
    int? lastIn,
  }) async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('linked_composer_gate');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    useLibrary();
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'nickname': name,
      'caps': caps,
    });
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'hello',
      // an hour ago unless said
      'sent_at': lastIn ?? DateTime.now().millisecondsSinceEpoch - 3600000,
    });
    final db = SayHiDb(mem, HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    linkedDevicesForTest = true;
    linkedRoleForTest = true;
    deviceReachesForTest = (p) async => p == _peer && reaches;
  }

  tearDown(() {
    deviceReachesForTest = null;
    deviceQuietForTest = null;
    linkedRoleForTest = false;
    linkedDevicesForTest = null;
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(
    WidgetTester t, {
    String name = _name,
    Size size = const Size(1000, 1800),
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    await devOpen(
      t,
      ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub:
            'abababababababababababababababababababababababababababababababab',
        avatarSeed: _peer,
        nickname: name,
      ),
      size: size,
      locale: locale,
      scale: scale,
    );
    await settle(t);
  }

  final composer = find.byKey(const ValueKey('bar_composer'));
  final phoneOnly = find.byKey(const ValueKey('bar_phone_only'));

  testWidgets('a 0.6 contact whose device reaches this one: the composer, '
      'no phone line', (t) async {
    await setUpWith('dv,pq,ty');
    reaches = true;
    await open(t);
    expect(composer, findsOneWidget);
    expect(phoneOnly, findsNothing);
    expect(find.text(l10n.chatDeviceWaitingForApp(_name)), findsNothing);
    expect(find.byType(TextField), findsWidgets);
    await devClose(t);
  });

  testWidgets('a 0.6 contact none of whose devices opened to this one yet: '
      'the line waits for their app, then the composer once their pair opens, '
      'with no message of theirs', (t) async {
    await setUpWith('dv,pq,ty');
    reaches = false;
    await open(t);
    expect(phoneOnly, findsOneWidget);
    expect(find.text(l10n.chatDeviceWaitingForApp(_name)), findsOneWidget);
    // their app took my list and started the pair: the chat reads it again
    reaches = true;
    appState.chatChanged(_peer);
    await settle(t);
    expect(phoneOnly, findsNothing);
    expect(composer, findsOneWidget);
    await devClose(t);
  });

  testWidgets('a 0.6 contact whose newest message here is weeks old: the line '
      'says they have not written in a while', (t) async {
    final weeks = DateTime.now()
        .subtract(kDeviceQuietAfter + const Duration(days: 1))
        .millisecondsSinceEpoch;
    await setUpWith('dv,pq,ty', lastIn: weeks);
    reaches = false;
    await open(t);
    expect(find.text(l10n.chatDeviceQuietAWhile(_name)), findsOneWidget);
    expect(find.text(l10n.chatDeviceWaitingForApp(_name)), findsNothing);
    await devClose(t);
  });

  for (final (what, caps, quiet) in [
    ('older Kryfo', 'pq,ty', false),
    ('waiting', 'dv,pq,ty', false),
    ('quiet', 'dv,pq,ty', true),
  ]) {
    for (final loc in const ['en', 'de', 'ru', 'vi']) {
      testWidgets('the $what line fits a narrow window with a long name '
          '($loc)', (t) async {
        const long = 'Maximiliana Konstantinopoulou-Wetherby';
        await setUpWith(caps, name: long);
        reaches = false;
        deviceQuietForTest = (_) => quiet;
        await open(
          t,
          name: long,
          size: const Size(640, 1280),
          locale: Locale(loc),
          scale: 1.3,
        );
        expect(t.takeException(), isNull);
        expect(phoneOnly, findsOneWidget);
        // the name cut to 22 letters and an ellipsis
        final cut = '${long.substring(0, 22)}\u2026';
        final line = caps.contains('dv')
            ? quiet
                  ? l10n.chatDeviceQuietAWhile(cut)
                  : l10n.chatDeviceWaitingForApp(cut)
            : l10n.chatDeviceOlderKryfo(cut);
        expect(find.text(line), findsOneWidget);
        // the whole line shows inside the window, wrapped, nothing cut
        expect(t.getSize(phoneOnly).width, lessThanOrEqualTo(320));
        final text = t.getRect(find.text(line));
        expect(text.left, greaterThanOrEqualTo(0));
        expect(text.right, lessThanOrEqualTo(320));
        expect(text.bottom, lessThanOrEqualTo(640));
        await devClose(t);
      });
    }
  }

  testWidgets('an older Kryfo: the phone line whatever the sessions', (
    t,
  ) async {
    await setUpWith('pq,ty');
    reaches = true;
    await open(t);
    expect(find.text(l10n.chatDeviceOlderKryfo(_name)), findsOneWidget);
    expect(composer, findsNothing);
    await devClose(t);
  });
}
