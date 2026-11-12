// SPDX-License-Identifier: GPL-3.0-or-later
// on a computer linked to the developer's phone, a chat of his inbox (filed
// there, or one a message came into through the developer chat) shows in
// place of the composer that his phone answers it; an ordinary chat keeps
// its composer, and on anyone else's computer nothing changes
import 'dart:io';

import 'package:flutter/material.dart'
    show Icons, Locale, Size, TextField, ValueKey;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/devices/device_send.dart';
import 'package:kryfo/devices/device_state.dart';
import 'package:kryfo/devices/own_sync.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        appState,
        devAnswersForTest,
        devInboxForTest,
        ownSyncForTest,
        deviceReachesForTest,
        linkedRoleForTest,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateRefresh;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/widgets/voice_mic.dart' show HoldToTalkMic;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'signal_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'say_hi_fakes.dart';
import 'sticker_test_util.dart';

const _peer = 'calm-grey-heron';

// the chat's rows as the inbox reads them
class _Db extends SayHiDb {
  _Db(super.mem, [super.container]);
  @override
  Future<Database> open() async => mem;
  @override
  Future<bool> hasViaDev(String haloId) async => mem
      .rows('messages')
      .any((r) => r['peer_id'] == haloId && r['via_dev'] == 1);
}

const _name = 'Heron';

class _NoState implements DeviceState {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoSend implements DeviceSend {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoApply implements OwnApply {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// the phone of this computer: what it is handed, noted
class _Phone extends OwnSync {
  _Phone()
    : super(
        state: _NoState(),
        db: () async => throw StateError('no own rows here'),
        send: _NoSend(),
        me: (_) async => null,
        apply: _NoApply(),
      );
  final handed = <String>[];
  @override
  Future<bool> answer(int ident, OwnChat chat, String frame) async {
    handed.add(frame);
    return true;
  }
}

void main() {
  late MemDb mem;
  late Directory docs;

  setUpAll(() async {
    final me = testKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final them = SignalSession();
    final pair = testKeyPair();
    await them.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await processPeerBundle(_peer, await makePreKeyBundleB64(them));
  });

  // a 0.6 contact whose devices reach this one: the composer, unless the
  // chat is his inbox's
  Future<void> setUpWith({String? state, bool viaDev = false}) async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('dev_inbox_desk');
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
      'nickname': _name,
      'caps': 'dv,pq,ty',
    });
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'hello',
      'sent_at': DateTime.now().millisecondsSinceEpoch - 3600000,
      'via_dev': viaDev ? 1 : 0,
    });
    if (state != null) {
      await mem.insert('support_chats', {
        'halo_id': _peer,
        'first_at': 1,
        'state': state,
      });
    }
    final db = _Db(mem, HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    linkedDevicesForTest = true;
    linkedRoleForTest = true;
    deviceReachesForTest = (p) async => p == _peer;
  }

  tearDown(() {
    deviceReachesForTest = null;
    linkedRoleForTest = false;
    linkedDevicesForTest = null;
    devInboxForTest = false;
    devAnswersForTest = false;
    ownSyncForTest(null);
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
    Locale locale = const Locale('en'),
  }) async {
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub:
            'abababababababababababababababababababababababababababababababab',
        avatarSeed: _peer,
        nickname: _name,
      ),
      size: const Size(640, 1280),
      locale: locale,
    );
    await settle(t);
  }

  final composer = find.byKey(const ValueKey('bar_composer'));
  final phoneOnly = find.byKey(const ValueKey('bar_phone_only'));

  for (final (what, state, via) in [
    ('waiting in the inbox', 'open', false),
    ('put away', 'done', false),
    ('moved to Chats', 'out', false),
    ('that came through the developer chat', null, true),
  ]) {
    testWidgets('a chat $what: his phone answers it', (t) async {
      await setUpWith(state: state, viaDev: via);
      devInboxForTest = true;
      await open(t);
      expect(composer, findsNothing);
      expect(phoneOnly, findsOneWidget);
      expect(find.text(l10n.chatInboxAnswerFromPhone), findsOneWidget);
      await devClose(t);
    });
  }

  testWidgets('his phone sends answers: the composer is here, files go from '
      'the phone, and a sent one waits for it', (t) async {
    await setUpWith(state: 'open');
    devInboxForTest = true;
    devAnswersForTest = true;
    final phone = _Phone();
    ownSyncForTest(phone);
    await open(t);
    expect(composer, findsOneWidget);
    expect(phoneOnly, findsNothing);
    expect(find.text(l10n.chatInboxAnswerFromPhone), findsNothing);
    // the mic is gone; attach says where files go
    expect(find.byType(HoldToTalkMic), findsNothing);
    await t.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await settle(t, 2);
    expect(find.text(l10n.chatInboxFilesFromPhone), findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'from my desk');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t, 10);
    expect(phone.handed, hasLength(1));
    expect(phone.handed.single, contains('from my desk'));
    expect(phone.handed.single, isNot(contains('"pw"')));
    expect(find.text(l10n.chatInboxSendsWhenPhoneOnline), findsOneWidget);
    await devClose(t);
  });

  testWidgets('an ordinary chat on his computer keeps its composer', (t) async {
    await setUpWith();
    devInboxForTest = true;
    await open(t);
    expect(composer, findsOneWidget);
    expect(find.text(l10n.chatInboxAnswerFromPhone), findsNothing);
    await devClose(t);
  });

  testWidgets('anyone else\'s computer: no inbox, the composer', (t) async {
    await setUpWith(state: 'open', viaDev: true);
    await open(t);
    expect(composer, findsOneWidget);
    expect(find.text(l10n.chatInboxAnswerFromPhone), findsNothing);
    await devClose(t);
  });

  for (final loc in const ['en', 'de', 'ar', 'zh']) {
    testWidgets('the line fits a narrow window ($loc)', (t) async {
      await setUpWith(state: 'open');
      devInboxForTest = true;
      await open(t, locale: Locale(loc));
      expect(t.takeException(), isNull);
      expect(phoneOnly, findsOneWidget);
      expect(t.getSize(phoneOnly).width, lessThanOrEqualTo(640));
      await devClose(t);
    });
  }
}
