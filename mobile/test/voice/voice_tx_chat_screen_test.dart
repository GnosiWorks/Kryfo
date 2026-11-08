// SPDX-License-Identifier: GPL-3.0-or-later
// the real chat screen: "See transcription" under a voice note, theirs and
// ours, the words in the bubble once tapped, copied from its menu as a
// text's would be, and gone with the note when it burns. none of it with
// the switch off. the transcriber is a stand-in
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        AppStateMessages,
        AppStateRefresh,
        AppStateRoute,
        appState,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/voice/transcript_store.dart';
import 'package:kryfo/voice/ui/transcript_line.dart';
import 'package:kryfo/voice/voice_transcripts.dart';
import 'package:kryfo/widgets/menu_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dev_chat_fakes.dart';
import '../mem_db.dart';
import '../say_hi_fakes.dart';
import '../sticker_test_util.dart';
import 'voice_tx_fakes.dart';

const _peer = 'calm-grey-heron';
const _heard = 'see you at the station at three';

Finder _rich(String s) => find.textContaining(s, findRichText: true);

// the link under one note
Finder _link(String uid) => find.descendant(
  of: find.byWidgetPredicate((w) => w is VoiceTranscript && w.uid == uid),
  matching: _rich(l10n.voiceSeeTranscription),
);

// a burn takes the row out of the database too
class _Db extends SayHiDb {
  _Db(super.mem, [super.container]);
  @override
  Future<void> deleteMessage(String msgUid, {String? from}) async =>
      mem.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
}

void main() {
  late Directory docs;
  late MemDb m;
  late VoiceFakes v;
  final copied = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('voice_tx_chat');
    mockChannel('plugins.flutter.io/path_provider', (_) async => docs.path);
    mockChannel('com.llfbandit.record/messages', (_) async => null);
    // a voice bubble reads its length with a player this host has not
    mockChannel('com.ryanheise.just_audio.methods', (c) async {
      if (c.method == 'init') return Completer<Object?>().future;
      return <String, Object?>{};
    });
    copied.clear();
    useLibrary();
    final note = File('${docs.path}/in.wav')
      ..writeAsBytesSync(List.filled(4096, 7));
    final ours = File('${docs.path}/out.wav')
      ..writeAsBytesSync(List.filled(4096, 7));
    m = MemDb();
    await devChatTables(m, now: 1);
    await m.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
    });
    await m.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'listen to this',
      'msg_uid': 't-first',
      'sent_at': 1,
    });
    await m.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': '',
      'msg_uid': 'v-in',
      'sent_at': 2,
      'file_path': note.path,
      'file_name': 'voice.wav',
    });
    await m.insert('messages', {
      'peer_id': _peer,
      'direction': 'out',
      'plaintext': '',
      'msg_uid': 'v-out',
      'sent_at': 3,
      'delivered': 1,
      'file_path': ours.path,
      'file_name': 'voice.wav',
    });
    final db = _Db(m, HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    v = fakeVoiceHub();
    v.runner.auto = true;
    v.runner.words[note.path] = (_heard, 'en');
    VoiceTranscripts.instance = v.hub;
  });

  tearDown(() {
    VoiceTranscripts.instance = null;
    mockChannel('plugins.flutter.io/path_provider', null);
    mockChannel('com.llfbandit.record/messages', null);
    mockChannel('com.ryanheise.just_audio.methods', null);
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

  Future<void> open(WidgetTester t) async {
    await devOpen(
      t,
      const ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'abab',
        avatarSeed: _peer,
      ),
    );
    // the copy goes through the platform's own sensitive clipboard
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      (c) async {
        if (c.method == 'copySensitive') {
          copied.add((c.arguments as Map)['text'] as String);
          return true;
        }
        return null;
      },
    );
    await settle(t);
  }

  testWidgets('under theirs and ours; tapped, the words show and are kept', (
    t,
  ) async {
    await open(t);
    expect(_rich(l10n.voiceSeeTranscription), findsNWidgets(2));
    await t.tap(_link('v-in'));
    await settle(t);
    expect(find.text(_heard), findsOneWidget);
    expect(find.text(l10n.voiceHideTranscription), findsOneWidget);
    expect(_link('v-out'), findsOneWidget);
    final kept = await v.store.kept(_peer);
    expect(kept.keys, ['v-in']);
    expect(kept['v-in']!.text, _heard);
    await devClose(t);
  });

  testWidgets('its menu copies the words while they show', (t) async {
    await open(t);
    await t.tap(_link('v-in'));
    await settle(t);
    await t.longPress(find.text(_heard));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(MenuBackdrop), findsOneWidget);
    await t.tap(find.text(l10n.commonCopy));
    await settle(t);
    expect(copied, [_heard]);
    await devClose(t);
  });

  testWidgets('a note that goes takes its words with it', (t) async {
    await open(t);
    await t.tap(_link('v-in'));
    await settle(t);
    expect(find.text(_heard), findsOneWidget);
    // unsent from their side, or burned: the row goes
    await m.delete('messages', where: 'msg_uid = ?', whereArgs: ['v-in']);
    appState.chatChanged(_peer);
    await settle(t, 10);
    expect(find.text(_heard), findsNothing);
    expect(await v.store.kept(_peer), isEmpty);
    await devClose(t);
  });

  testWidgets('switched off: no link at all', (t) async {
    VoiceTranscripts.instance = null;
    expect(voiceTranscriptsIfOn(), isNull);
    await open(t);
    expect(_rich(l10n.voiceSeeTranscription), findsNothing);
    await devClose(t);
  });

  testWidgets('turned off in settings: the link goes', (t) async {
    await open(t);
    expect(_rich(l10n.voiceSeeTranscription), findsNWidgets(2));
    await v.hub.setOn(false);
    await settle(t);
    expect(_rich(l10n.voiceSeeTranscription), findsNothing);
    expect(v.store, isA<MemoryVoiceTxStore>());
    await devClose(t);
  });
}
