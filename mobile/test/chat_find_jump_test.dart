// SPDX-License-Identifier: GPL-3.0-or-later
// a 1:1 chat finds a word over the whole chat, not only the page it holds:
// "1 of 3" from the index, the far one brought in from a little above it
// (never the whole thread), a quote that points far up jumps there, and one
// that is gone says so
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        ChatHit,
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateRefresh;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-slow-river';
const _base = 1700000000000;

class _Db extends DevTestDb {
  _Db(super.mem);

  // what a load asked for: the whole thread, or from a row
  final asks = <String>[];

  List<Map<String, Object?>> get _thread => [
    for (final r in mem.rows('messages'))
      if (r['peer_id'] == _peer && r['group_id'] == null)
        {...r, 'rowid': r['id'], 'written_at': r['sent_at']},
  ]..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _contact(haloId);
  @override
  Future<bool> isAccepted(String haloId) async => true;
  @override
  Future<bool> isBackPaired(String peerId) async => true;
  @override
  Future<bool> isBlocked(String haloId) async => false;
  @override
  Future<bool> isMuted(String haloId) async => false;
  @override
  Future<bool> isVerified(String haloId) async => false;
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
      _thread.length;
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
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    asks.add('all');
    return _thread;
  }

  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    final all = [
      for (final r in _thread)
        if (beforeRowid == null || (r['id'] as int) < beforeRowid) r,
    ];
    return all.sublist(all.length > limit ? all.length - limit : 0);
  }

  @override
  Future<List<Map<String, Object?>>> messagesFrom(
    String peerId, {
    required int rowid,
    int? at,
  }) async {
    asks.add('from $rowid');
    return [
      for (final r in _thread)
        if ((r['id'] as int) >= rowid) r,
    ];
  }

  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [
    for (final r in _thread)
      if ((r['id'] as int) > afterRowid) r,
  ];
  @override
  Future<Map<String, Object?>?> messageIn(String peerId, String msgUid) async {
    for (final r in _thread) {
      if (r['msg_uid'] == msgUid) return r;
    }
    return null;
  }

  @override
  Future<List<ChatHit>> chatHits(
    String match, {
    String? peerId,
    String? groupId,
    bool wordsOnly = false,
  }) async {
    final word = match.replaceAll(RegExp(r'["*]'), '');
    return [
      for (final r in _thread)
        if ((r['plaintext'] as String).toLowerCase().contains(word))
          (id: r['id'] as int, at: r['sent_at'] as int),
    ];
  }

  @override
  Future<ChatHit?> chatStartAbove(
    int id, {
    String? peerId,
    String? groupId,
    int before = 30,
  }) async {
    final ids = [for (final r in _thread) r['id'] as int];
    final at = ids.indexOf(id);
    if (at < 0) return null;
    final from = ids[at - before < 0 ? 0 : at - before];
    return (id: from, at: _base + from);
  }

  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<bool> messageExists(String msgUid) async => true;
}

class _Engine implements HaloEngine {
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(int ident, String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(int ident, String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

void main() {
  late _Db db;
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
    docs = Directory.systemTemp.createTempSync('chat_find');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    final mem = MemDb();
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
    // 300 lines; the word is in the 5th, the 150th and the 290th
    for (var i = 1; i <= 300; i++) {
      await mem.insert('messages', {
        'id': i,
        'peer_id': _peer,
        'direction': i.isEven ? 'out' : 'in',
        'plaintext': switch (i) {
          5 => 'the old pelican story',
          150 => 'a pelican again',
          290 => 'pelican, last one',
          9 => 'quoting nothing',
          _ => 'line $i',
        },
        'msg_uid': 'u$i',
        'sent': 1,
        'sent_at': _base + i,
        if (i == 295) 'reply_to': 'u5',
        if (i == 296) 'reply_to': 'gone',
      });
    }
    db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Widget chat() => const ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub:
        'abababababababababababababababababababababababababababababababab',
    avatarSeed: _peer,
  );

  Future<void> frames(WidgetTester t, [int n = 40]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 30));
    }
  }

  testWidgets('a word over the whole chat, the far one brought in', (t) async {
    await t.pumpWidget(devApp(chat()));
    await frames(t);
    // row 5 is far above the page held
    expect(find.text('line 6'), findsNothing);
    await t.tap(find.byTooltip(l10n.chatSearchThisChat));
    await frames(t, 20);
    await t.enterText(find.byType(TextField).first, 'pelican');
    await frames(t);
    // all three, the page holds one
    expect(find.textContaining('3 of 3', findRichText: true), findsOneWidget);
    await t.tap(find.bySemanticsLabel(l10n.chatPreviousMatch));
    await frames(t);
    expect(find.textContaining('2 of 3', findRichText: true), findsOneWidget);
    // row 150 came in with thirty above it, and the thread down from there
    expect(db.asks, contains('from 120'));
    expect(db.asks, isNot(contains('all')));
    expect(
      find.textContaining('a pelican again', findRichText: true),
      findsOneWidget,
    );
    await t.tap(find.bySemanticsLabel(l10n.chatPreviousMatch));
    await frames(t);
    expect(find.textContaining('1 of 3', findRichText: true), findsOneWidget);
    expect(db.asks, contains('from 1'));
    expect(find.text('line 6'), findsWidgets);
    expect(t.takeException(), isNull);
    await frames(t, 120);
  });

  testWidgets('a quote far up reads its words and jumps there', (t) async {
    await t.pumpWidget(devApp(chat()));
    await frames(t);
    final quote = find.textContaining('the old pelican', findRichText: true);
    expect(find.textContaining('line 6', findRichText: true), findsNothing);
    expect(quote, findsOneWidget);
    await t.tap(quote);
    await frames(t);
    expect(db.asks, contains('from 1'));
    // the quote reads the far one's words, and the thread is there now
    expect(find.textContaining('line 6', findRichText: true), findsWidgets);
    expect(t.takeException(), isNull);
    await frames(t, 120);
  });

  testWidgets('a quote of one that is gone says so', (t) async {
    await t.pumpWidget(devApp(chat()));
    await frames(t);
    final gone = find.textContaining(
      l10n.chatMessageUnavailable,
      findRichText: true,
    );
    expect(gone, findsOneWidget);
    await t.tap(gone);
    await frames(t, 20);
    expect(find.text(l10n.chatMessageGone), findsOneWidget);
    await frames(t, 120);
  });
}
