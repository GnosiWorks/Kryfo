// SPDX-License-Identifier: GPL-3.0-or-later
// a tap back into what is being typed moves the caret there, in a chat's
// composer and in a group's, also while flutter's key state still holds a
// shift the keyboard let go of: no selection stretches from the end
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stickers/sticker_pack.dart' show StickerLibrary;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;
import 'say_hi_fakes.dart';

const _peer = 'amber-new-river';
const _group = 'g1';
const _words = 'hello there world';

// a group with nothing in it yet, as the group screen reads it
class _GroupDb implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Friends',
    'is_admin': 0,
  };
  @override
  Future<bool> groupExists(String groupId) async => true;
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['a', 'b'];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => {};
  @override
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

TextEditingController _ctrl(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField)).controller!;

// where the caret sits before [offset], on screen
Offset _at(WidgetTester t, int offset) {
  final re = t
      .state<EditableTextState>(find.byType(EditableText))
      .renderEditable;
  return re.localToGlobal(
    re.getLocalRectForCaret(TextPosition(offset: offset)).center,
  );
}

// typed, then a tap back to the middle with a shift stuck in flutter's
// key state, and a second tap after it
Future<void> _tapBack(WidgetTester t) async {
  await t.enterText(find.byType(TextField), _words);
  await t.pump(const Duration(seconds: 1));
  expect(_ctrl(t).selection, const TextSelection.collapsed(offset: 17));

  await t.sendKeyDownEvent(LogicalKeyboardKey.shiftRight);
  addTearDown(() async {
    if (HardwareKeyboard.instance.isShiftPressed) {
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftRight);
    }
  });
  await t.tapAt(_at(t, 6));
  await t.pump();
  expect(
    _ctrl(t).selection.isCollapsed,
    isTrue,
    reason: '${_ctrl(t).selection}',
  );
  expect(_ctrl(t).selection.baseOffset, 6);

  await t.pump(const Duration(seconds: 1));
  await t.tapAt(_at(t, 11));
  await t.pump();
  expect(
    _ctrl(t).selection.isCollapsed,
    isTrue,
    reason: '${_ctrl(t).selection}',
  );
  expect(_ctrl(t).selection.baseOffset, 11);
  expect(_ctrl(t).text, _words);
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
    appState.sendModeForTest = 'balanced';
    useEngineForTest(SayHiRelay());
    docs = Directory.systemTemp.createTempSync('composer_cursor');
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

  testWidgets('a chat composer moves the caret where it is tapped', (t) async {
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
      devApp(
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
    await _tapBack(t);
    // the draft is left behind with the screen
    _ctrl(t).clear();
    await devClose(t);
  });

  testWidgets('a group composer moves the caret where it is tapped', (t) async {
    phone(t);
    final db = _GroupDb();
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
    await t.pump(const Duration(seconds: 1));
    await _tapBack(t);
    _ctrl(t).clear();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
