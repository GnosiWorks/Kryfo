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
const _count = 100000;
const _mid = 50000;
const _late = 99990;

class _Db extends DevTestDb {
  _Db(super.mem);

  // what each load asked for, and the most rows one load handed back
  final asks = <String>[];
  int most = 0;

  // a long chat, made once: row i is at index i - 1
  static final _rows = [
    for (var i = 1; i <= _count; i++)
      {
        'id': i,
        'rowid': i,
        'peer_id': _peer,
        'direction': i.isEven ? 'out' : 'in',
        'plaintext': switch (i) {
          5 => 'the old pelican story',
          _mid => 'a pelican again',
          _late => 'pelican, last one',
          _ => 'line $i',
        },
        'msg_uid': 'u$i',
        'sent': 1,
        'sent_at': _base + i,
        'written_at': _base + i,
        if (i == _count - 5) 'reply_to': 'u5',
        if (i == _count - 4) 'reply_to': 'gone',
      },
  ];

  List<Map<String, Object?>> _slice(String ask, int from, int to) {
    final a = from.clamp(0, _count);
    final b = to.clamp(a, _count);
    asks.add(ask);
    if (b - a > most) most = b - a;
    return _rows.sublist(a, b);
  }

  List<Map<String, Object?>> get _thread => _rows;

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
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _slice('all', 0, _count);

  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    final end = (beforeRowid ?? _count + 1) - 1;
    return _slice('page', end - limit, end);
  }

  @override
  Future<List<Map<String, Object?>>> messagesFrom(
    String peerId, {
    required int rowid,
    int? at,
  }) async => _slice('from $rowid', rowid - 1, _count);

  @override
  Future<List<Map<String, Object?>>> messagesBetween(
    String peerId, {
    required int fromId,
    required int fromAt,
    required int toId,
    required int toAt,
  }) async => _slice('between $fromId $toId', fromId - 1, toId);

  @override
  Future<List<Map<String, Object?>>> messagesAfterAt(
    String peerId, {
    required int id,
    required int at,
    int limit = 60,
  }) async => _slice('after $id', id, id + limit);

  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => _slice('since $afterRowid', afterRowid, _count);

  @override
  Future<Map<String, Object?>?> messageIn(String peerId, String msgUid) async {
    final i = int.tryParse(msgUid.substring(1));
    return i == null || i < 1 || i > _count ? null : _rows[i - 1];
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
    if (id < 1 || id > _count) return null;
    final from = id - before < 1 ? 1 : id - before;
    return (id: from, at: _base + from);
  }

  @override
  Future<ChatHit?> chatEndBelow(
    int id, {
    String? peerId,
    String? groupId,
    int after = 60,
  }) async {
    if (id + after >= _count) return null;
    return (id: id + after, at: _base + id + after);
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

  testWidgets('a word over a 100k-row chat, a window around each far one', (
    t,
  ) async {
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
    await frames(t, 80);
    expect(find.textContaining('2 of 3', findRichText: true), findsOneWidget);
    // row 50000 came in with thirty above it and sixty below, not the
    // fifty thousand down to the newest
    expect(db.asks, contains('between 49970 50060'));
    expect(db.most, lessThanOrEqualTo(100));
    expect(db.asks, isNot(contains('all')));
    expect(
      find.textContaining('a pelican again', findRichText: true),
      findsOneWidget,
    );
    await t.tap(find.bySemanticsLabel(l10n.chatPreviousMatch));
    await frames(t, 80);
    expect(find.textContaining('1 of 3', findRichText: true), findsOneWidget);
    expect(db.asks, contains('between 1 65'));
    expect(find.text('line 6'), findsWidgets);
    // no load handed back more than a window's worth
    expect(db.most, lessThanOrEqualTo(100));
    // the arrow down goes back to the newest page, the window let go
    await t.tap(find.bySemanticsLabel(l10n.chatJumpToTheNewest));
    await frames(t);
    expect(find.text('line 99999'), findsOneWidget);
    expect(db.most, lessThanOrEqualTo(100));
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
    expect(db.asks, contains('between 1 65'));
    expect(db.most, lessThanOrEqualTo(100));
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
