// SPDX-License-Identifier: GPL-3.0-or-later
// a face or a group's tile on its way from the chat list to the chat's
// header keeps the page's text style: the letters in it never show the
// app's fallback style, red with a yellow double underline
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/main.dart'
    show
        GroupPreview,
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/motion.dart' show haloRoute;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'wren-oak-lamp';
const _group = 'g1';

class _Db extends DevTestDb {
  _Db(super.mem);

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  bool _flag(String id, String col) => _contact(id)?[col] == 1;

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _contact(haloId);
  @override
  Future<bool> isAccepted(String haloId) async => _flag(haloId, 'accepted');
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _flag(peerId, 'back_paired');
  @override
  Future<bool> isBlocked(String haloId) async => _flag(haloId, 'blocked');
  @override
  Future<bool> isMuted(String haloId) async => _flag(haloId, 'muted');
  @override
  Future<bool> isVerified(String haloId) async => _flag(haloId, 'verified');
  @override
  Future<bool> keyChanged(String haloId) async => false;
  @override
  Future<String?> getAtmosphere(String peerId) async => null;
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      0;
  @override
  Future<int> countMessagesTo(String peerId) async => 0;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {}
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async => [];
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  // the group, as its chat reads it
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Hikers',
    'is_admin': 1,
  };
  @override
  Future<bool> groupExists(String groupId) async => true;
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['me', _peer];
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
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => {};
  @override
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
}

// the relay: nothing is answered
class _Engine implements HaloEngine {
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(String peerXPubHex) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

// the style text gets with no Material above it
bool _fallback(TextStyle? s) =>
    s?.decoration == TextDecoration.underline &&
    s?.decorationStyle == TextDecorationStyle.double;

// every run of text on screen now that fell back
List<String> _fellBack(WidgetTester t) {
  final out = <String>[];
  for (final r in t.widgetList<RichText>(find.byType(RichText))) {
    r.text.visitChildren((span) {
      if (span is TextSpan && _fallback(span.style)) {
        out.add(span.toPlainText());
      }
      return true;
    });
  }
  return out;
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
    useEngineForTest(_Engine());
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('hero_text');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
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
    });
    final db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Widget home() => Builder(
    builder: (context) => HomeScreen(
      haloId: 'neon-tiger-saturn',
      contacts: appState.contacts,
      groups: const [
        GroupSummary(groupId: _group, name: 'Hikers', memberCount: 3),
      ],
      onAddContact: () {},
      onNewGroup: () {},
      onNewRoom: () {},
      onOpenDev: () {},
      onOpenSettingsDirect: () {},
      onOpenChat: (id) => Navigator.push(
        context,
        haloRoute(
          ChatScreen(
            peerHaloId: id,
            peerOnion: '',
            peerXPub: 'ab' * 32,
            avatarSeed: id,
          ),
        ),
      ),
      onOpenGroup: (id) =>
          Navigator.push(context, haloRoute(GroupChatScreen(groupId: id))),
    ),
  );

  testWidgets('a face on its way to the chat keeps its letters plain', (
    t,
  ) async {
    await devOpen(t, home());
    expect(_fellBack(t), isEmpty);
    await t.tap(find.text(_peer));
    await t.pump();
    await t.pump(const Duration(milliseconds: 140));
    // halfway: only the flying copy of the face is on screen
    expect(find.text('W'), findsOneWidget);
    expect(_fellBack(t), isEmpty);
    await t.pump(const Duration(seconds: 1));
    await devClose(t);
  });

  testWidgets('a group\'s tile on its way to the chat keeps its letter plain', (
    t,
  ) async {
    await devOpen(t, home());
    // the chat knows its name from the list before its own load
    appState.groups = [
      GroupPreview(
        groupId: _group,
        name: 'Hikers',
        memberCount: 3,
        isAdmin: true,
        createdAt: DateTime(2026),
      ),
    ];
    addTearDown(() => appState.groups = []);
    await t.tap(find.text('Hikers'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 140));
    expect(find.text('H'), findsOneWidget);
    expect(_fellBack(t), isEmpty);
    await t.pump(const Duration(seconds: 1));
    await devClose(t);
  });
}
