// SPDX-License-Identifier: GPL-3.0-or-later
// the real group screen: translate under their bubble and in its menu, none
// on ours, the group's own always switch. the translator is a stand-in
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/translate_bubble.dart';
import 'package:kryfo/widgets/menu_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;
import 'translate_fakes.dart';

const _group = 'g1';
const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';
const _ours = 'see you at the station then';

Finder rich(String s) => find.textContaining(s, findRichText: true);

// one group, paged as the phone's database pages it
class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[];
  // pages fetched above the newest one
  int olderPages = 0;

  // a message from amber, or ours
  void said(String text, {bool ours = false}) {
    final id = rows.length + 1;
    rows.add({
      'rowid': id,
      'id': id,
      'peer_id': ours ? 'me' : 'amber',
      'group_id': _group,
      'direction': ours ? 'out' : 'in',
      'plaintext': text,
      'msg_uid': 'uid$id',
      'sent': 1,
      'sent_at': DateTime.now()
          .subtract(Duration(minutes: 10 - id))
          .millisecondsSinceEpoch,
    });
  }

  @override
  HaloContainer get container => HaloContainer.everyday;

  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Friends',
    'is_admin': 0,
  };
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['amber'];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    if (beforeRowid != null) olderPages++;
    final older = [
      for (final r in rows)
        if (beforeRowid == null || (r['rowid'] as int) < beforeRowid) r,
    ];
    return older.sublist(older.length > limit ? older.length - limit : 0);
  }

  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [...rows];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [
    for (final r in rows)
      if ((r['rowid'] as int) > afterRowid) r,
  ];
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
  Future<bool> isAccepted(String haloId) async => true;
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: true, delivered: true);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Fakes f;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // the menu opens only over an unlocked app
    lockState.openForTest();
    f = fakeHub(installed: true, words: {_zh: _en});
    TranslationHub.instance = f.hub;
  });

  tearDown(() => TranslationHub.instance = null);

  Future<void> settle(WidgetTester t, [int beats = 8]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester t) async {
    phone(t);
    final db = _GroupDb()
      ..said(_zh)
      ..said(_ours, ours: true);
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    // the composer's recorder
    const rec = MethodChannel('com.llfbandit.record/messages');
    m.setMockMethodCallHandler(rec, (_) async => null);
    addTearDown(() {
      m.setMockMethodCallHandler(SystemChannels.platform, null);
      m.setMockMethodCallHandler(rec, null);
    });
    await t.pumpWidget(app(const GroupChatScreen(groupId: _group)));
    await settle(t, 20);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  Future<void> openMenu(WidgetTester t, String text) async {
    await t.longPress(rich(text).first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(MenuBackdrop), findsOneWidget);
  }

  testWidgets('theirs in chinese offers translate; ours does not', (t) async {
    await open(t);
    expect(rich(_zh), findsOneWidget);
    expect(rich(_ours), findsOneWidget);
    // one line, under theirs
    expect(rich(l10n.translateAction), findsOneWidget);
    final theirs = find.byWidgetPredicate(
      (w) => w is TranslatedBody && w.text == _zh,
    );
    expect(
      find.descendant(of: theirs, matching: rich(l10n.translateAction)),
      findsOneWidget,
    );
    await t.tap(rich(l10n.translateAction));
    await settle(t);
    expect(rich(_en), findsOneWidget);
    expect(rich(_zh), findsNothing);
    expect(rich(l10n.translateFrom(l10n.translateLangZh)), findsOneWidget);
    // the group's own chat in the hub, by the message's uid
    expect(t.widget<TranslatedBody>(theirs).chat!.chatId, _group);
    await t.tap(rich(l10n.translateShowOriginal));
    await settle(t);
    expect(rich(_zh), findsOneWidget);
    expect(rich(_en), findsNothing);
    await close(t);
  });

  testWidgets('the long-press menu: translate, always this chat, never', (
    t,
  ) async {
    await open(t);
    await openMenu(t, _zh);
    expect(find.text(l10n.translateAction), findsOneWidget);
    expect(find.text(l10n.translateAlwaysChat), findsOneWidget);
    expect(find.text(l10n.translateBarNever(langName('zh'))), findsOneWidget);
    await t.tap(find.text(l10n.translateAction));
    await settle(t);
    expect(rich(_en), findsOneWidget);

    await openMenu(t, _en);
    expect(find.text(l10n.translateShowOriginal), findsOneWidget);
    await t.tap(find.text(l10n.translateAlwaysChat));
    await settle(t);
    expect(await f.store.chatAuto(_group), isTrue);

    await openMenu(t, _en);
    await t.tap(find.text(l10n.translateBarNever(langName('zh'))));
    await settle(t);
    expect(f.store.settings.never, ['zh']);

    // ours has none of them
    await openMenu(t, _ours);
    expect(find.text(l10n.translateAction), findsNothing);
    expect(find.text(l10n.translateAlwaysChat), findsNothing);
    await close(t);
  });

  testWidgets('a group set to translate shows it translated', (t) async {
    await f.store.setChatAuto(_group, true);
    await open(t);
    expect(rich(_en), findsOneWidget);
    expect(rich(l10n.translateShowOriginal), findsOneWidget);
    await close(t);
  });

  testWidgets('translation off: nothing in the group says it exists', (
    t,
  ) async {
    TranslationHub.instance = null;
    await open(t);
    expect(rich(_zh), findsOneWidget);
    for (final w in t.widgetList<TranslatedBody>(find.byType(TranslatedBody))) {
      expect(w.chat, isNull);
    }
    expect(rich(l10n.translateAction), findsNothing);
    await openMenu(t, _zh);
    expect(find.text(l10n.translateAction), findsNothing);
    expect(find.text(l10n.translateAlwaysChat), findsNothing);
    await close(t);
  });
}
