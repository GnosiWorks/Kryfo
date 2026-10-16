// SPDX-License-Identifier: GPL-3.0-or-later
// a 1:1 chat shows its messages where they were written, at the time they
// were written, under that day. one that came late is not stuck at the
// bottom: a jump lands on it in its place, the new messages line sits
// above it there, and one written before the pages held comes in with
// its own page as the reader scrolls up, once, between its neighbours.
// the chat's own screen over rows kept in maps
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/dates.dart' show hourMinute;
import 'package:kryfo/album.dart' show AlbumTag;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/row_anchor.dart' show RowAnchor;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        makePreKeyBundleB64,
        openChatForNotif,
        processPeerBundle,
        rootNavKey,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/chat_parts.dart'
    show JumpDownButton, UnreadDivider;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-long-thread';

class _Db extends DevTestDb {
  _Db(super.mem);

  // pages fetched above the newest one
  int olderPages = 0;

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  Map<String, Object?>? _row(String uid) {
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == uid) return r;
    }
    return null;
  }

  List<Map<String, Object?>> _thread(String peer) => [
    for (final r in mem.rows('messages'))
      if (r['peer_id'] == peer && r['group_id'] == null)
        {...r, 'rowid': r['id']},
  ];

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
  // verified under a key they no longer hold
  bool held = false;
  @override
  Future<bool> keyHeld(String haloId) async => held;
  @override
  Future<String?> getAtmosphere(String peerId) async => null;
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      _thread(peerId).where((r) => r['direction'] == 'in').length;
  @override
  Future<int> countMessagesTo(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'out').length;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {}
  // the order the phone's database gives: by when written, then as they
  // came
  static int _at(Map<String, Object?> r) =>
      (r['written_at'] ?? r['sent_at']) as int;
  static int _cmp(Map<String, Object?> a, Map<String, Object?> b) {
    final c = _at(a).compareTo(_at(b));
    return c != 0 ? c : (a['id'] as int).compareTo(b['id'] as int);
  }

  List<Map<String, Object?>> _ordered(String peer) => _thread(peer)..sort(_cmp);

  // whole threads read
  int wholeLoads = 0;
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    wholeLoads++;
    return _ordered(peerId);
  }

  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async {
    if (beforeRowid != null) olderPages++;
    final all = _ordered(peerId);
    final top = beforeRowid == null
        ? null
        : {
            'id': beforeRowid,
            'sent_at':
                beforeAt ?? _at(all.firstWhere((r) => r['id'] == beforeRowid)),
          };
    final older = [
      for (final r in all)
        if (top == null || _cmp(r, top) < 0) r,
    ];
    return older.sublist(older.length > limit ? older.length - limit : 0);
  }

  @override
  Future<List<Map<String, Object?>>> messagesFrom(
    String peerId, {
    required int rowid,
    int? at,
  }) async {
    final all = _ordered(peerId);
    final from = {
      'id': rowid,
      'sent_at': at ?? _at(all.firstWhere((r) => r['id'] == rowid)),
    };
    return [
      for (final r in all)
        if (_cmp(r, from) >= 0) r,
    ];
  }

  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [
    for (final r in _thread(peerId))
      if ((r['id'] as int) > afterRowid) r,
  ];
  // the tag this chat's notifications go under
  @override
  Future<String?> notifChatOf(String tag) async => tag == 'tag1' ? _peer : null;
  // notification 7 rang for late7, as this container kept it
  @override
  Future<String?> ringOf(int id, String chat) async =>
      id == 7 && chat == _peer ? 'late7' : null;
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
  Future<bool> messageExists(String msgUid) async => _row(msgUid) != null;
  @override
  Future<void> setPowNonce(String msgUid, int nonce) async {}
  @override
  Future<int?> powNonceOf(String msgUid) async => null;
  @override
  Future<void> markSent(String msgUid) => mem.update(
    'messages',
    {'sent': 1},
    where: 'msg_uid = ?',
    whereArgs: [msgUid],
  );
  @override
  Future<bool> isSent(String msgUid) async => _row(msgUid)?['sent'] == 1;
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: _row(msgUid)?['sent'] == 1, delivered: false);

  @override
  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    int? sentAt,
    int? writtenAt,
    bool viaDev = false,
    AlbumTag? album,
  }) async {
    await mem.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'sent': sent,
    });
  }
}

// nothing is sent here
class _Engine implements HaloEngine {
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

void main() {
  late MemDb mem;
  late _Db db;
  late Directory docs;
  // yesterday morning: the thread's first message, two minutes apart after
  final now = DateTime.now();
  final base = DateTime(
    now.year,
    now.month,
    now.day - 1,
    10,
  ).millisecondsSinceEpoch;
  int note(int i) => base + i * 120000;

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

  // [rows] notes, each come as it was written
  Future<void> seed(int rows) async {
    for (var i = 0; i < rows; i++) {
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': i.isEven ? 'in' : 'out',
        'plaintext': 'note $i',
        'sent_at': note(i),
        'written_at': note(i),
        'msg_uid': 'uid$i',
        'sent': 1,
      });
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    docs = Directory.systemTemp.createTempSync('msg_order_screen');
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
    db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
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

  // the thread itself: the one list that grows upward
  ScrollPosition thread(WidgetTester t) => t
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((s) => s.axisDirection == AxisDirection.up)
      .position;

  Widget chat({String? jumpTo}) => ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub: 'ab' * 32,
    avatarSeed: _peer,
    jumpToUid: jumpTo,
  );

  // one from them that comes now, written at [at]
  Future<void> cameLate(String uid, String text, int at) =>
      mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': text,
        'sent_at': DateTime.now().millisecondsSinceEpoch,
        'written_at': at,
        'msg_uid': uid,
        'sent': 1,
      });

  Finder text(String s) => find.text(s, findRichText: true);
  bool seen(String s) => text(s).hitTestable().evaluate().isNotEmpty;
  double y(WidgetTester t, String s) => t.getCenter(text(s)).dy;

  testWidgets('one that came late shows where and when it was written, '
      'and a jump lands on it there', (t) async {
    await seed(40);
    // written between notes 20 and 21, come after all of them
    await cameLate('late', 'late one', note(20) + 60000);
    await devOpen(t, chat());
    await settle(t);
    // not at the bottom under a day of its own
    expect(seen('note 39'), isTrue);
    expect(seen('late one'), isFalse);
    expect(find.text(l10n.chatToday), findsNothing);
    await devClose(t);

    await devOpen(t, chat(jumpTo: 'late'));
    await settle(t, 12);
    expect(seen('late one'), isTrue);
    final mid = t.getSize(find.byType(ChatScreen)).height / 2;
    expect((y(t, 'late one') - mid).abs(), lessThan(200));
    expect(y(t, 'note 20'), lessThan(y(t, 'late one')));
    expect(y(t, 'late one'), lessThan(y(t, 'note 21')));
    // a tap shows its own time, not the time it came
    await t.tap(text('late one'));
    await settle(t, 2);
    final full = find.byKey(const ValueKey('full-date'));
    expect(full, findsOneWidget);
    final at = hourMinute(
      DateTime.fromMillisecondsSinceEpoch(note(20) + 60000),
    );
    expect(
      find.descendant(of: full, matching: find.textContaining(at)),
      findsOneWidget,
    );
    await devClose(t);
  });

  testWidgets('the new messages line sits over the new ones at the end, '
      'never over read ones a late one went up between', (t) async {
    await seed(40);
    // read to the newest, then left
    await devOpen(t, chat());
    await settle(t);
    await devClose(t);
    await cameLate('late2', 'late two', note(37) + 60000);
    await cameLate('fresh', 'fresh one', DateTime.now().millisecondsSinceEpoch);
    await devOpen(t, chat());
    await settle(t, 12);
    expect(y(t, 'note 37'), lessThan(y(t, 'late two')));
    expect(y(t, 'late two'), lessThan(y(t, 'note 38')));
    expect(find.byType(UnreadDivider), findsOneWidget);
    final line = find
        .ancestor(
          of: find.byType(UnreadDivider),
          matching: find.byType(RepaintBoundary),
        )
        .first;
    expect(
      find.descendant(of: line, matching: text('fresh one')),
      findsOneWidget,
    );
    expect(find.descendant(of: line, matching: text('late two')), findsNothing);
    await devClose(t);
  });

  testWidgets('one that came late while reading back goes up the thread, '
      'leaves the place, and is not counted as new below', (t) async {
    await seed(40);
    await devOpen(t, chat());
    await settle(t);
    thread(t).jumpTo(600);
    await settle(t);
    List<int> shown() => [
      for (var i = 0; i < 40; i++)
        if (seen('note $i')) i,
    ];
    final reading = shown();
    final top = y(t, 'note ${reading.first}');
    await cameLate('late4', 'late four', note(38) + 60000);
    appState.chatChanged(_peer);
    await settle(t);
    expect(thread(t).pixels, greaterThan(240));
    expect(t.widget<JumpDownButton>(find.byType(JumpDownButton)).count, 0);
    // the rows read stay where they were
    expect(shown(), reading);
    expect(y(t, 'note ${reading.first}'), moreOrLessEquals(top, epsilon: 1));
    await devClose(t);
  });

  testWidgets('one written before the pages held comes in with its page, '
      'once, between its neighbours', (t) async {
    await seed(150);
    await devOpen(t, chat());
    await settle(t);
    expect(seen('note 149'), isTrue);
    // written in the second page up, come while the newest page is open
    await cameLate('late3', 'late three', note(30) + 60000);
    appState.chatChanged(_peer);
    await settle(t);
    expect(seen('late three'), isFalse);
    expect(thread(t).pixels, 0);
    // up to the top: every page comes in
    for (var i = 0; i < 8; i++) {
      thread(t).jumpTo(thread(t).maxScrollExtent);
      await settle(t);
    }
    expect(db.olderPages, greaterThan(1));
    expect(seen('note 0'), isTrue);
    // down until it is built
    for (var i = 0; i < 40 && text('late three').evaluate().isEmpty; i++) {
      thread(
        t,
      ).jumpTo((thread(t).pixels - 300).clamp(0, thread(t).maxScrollExtent));
      await settle(t, 2);
    }
    expect(text('late three'), findsOneWidget);
    expect(text('note 30'), findsOneWidget);
    expect(text('note 31'), findsOneWidget);
    expect(y(t, 'note 30'), lessThan(y(t, 'late three')));
    expect(y(t, 'late three'), lessThan(y(t, 'note 31')));
    await devClose(t);
  });

  // the line for what came up the thread, as it reads
  Finder line(int n) =>
      find.text(l10n.chatEarlierMessagesArrived(n)).hitTestable();

  testWidgets('an honest reply that came late, half an hour up, shows the '
      'line, and a tap lands on it', (t) async {
    await seed(40);
    await devOpen(t, chat());
    await settle(t);
    expect(line(1), findsNothing);
    // written while this phone was away, half an hour above the bottom
    await cameLate('late5', 'late five', note(24) + 60000);
    appState.chatChanged(_peer);
    await settle(t);
    expect(seen('late five'), isFalse);
    expect(line(1), findsOneWidget);
    await t.tap(line(1));
    await settle(t, 14);
    expect(seen('late five'), isTrue);
    final mid = t.getSize(find.byType(ChatScreen)).height / 2;
    expect((y(t, 'late five') - mid).abs(), lessThan(200));
    expect(line(1), findsNothing);
    await devClose(t);
  });

  testWidgets('one that came while the chat was shut shows the line when '
      'it opens', (t) async {
    await seed(40);
    await devOpen(t, chat());
    await settle(t);
    await devClose(t);
    await cameLate('late6', 'late six', note(24) + 60000);
    await devOpen(t, chat());
    await settle(t);
    expect(line(1), findsOneWidget);
    await devClose(t);
  });

  testWidgets('no line for what lands at the bottom, or just above it', (
    t,
  ) async {
    await seed(40);
    await devOpen(t, chat());
    await settle(t);
    await cameLate(
      'fresh2',
      'fresh two',
      DateTime.now().millisecondsSinceEpoch,
    );
    // a minute before the bottom: the order shows it
    await cameLate('near', 'near one', note(39) - 60000);
    appState.chatChanged(_peer);
    await settle(t);
    expect(seen('fresh two'), isTrue);
    expect(find.byKey(const ValueKey('earlier-chip')), findsNothing);
    await devClose(t);
  });

  testWidgets('a tapped notification opens the chat on the message it rang '
      'for', (t) async {
    lockState.openForTest();
    await seed(40);
    await cameLate('late7', 'late seven', note(24) + 60000);
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox(),
      ),
    );
    // the tap hands back the bare tag and the notification's id
    await t.runAsync(() => openChatForNotif('tag1', 7));
    await settle(t, 16);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(seen('late seven'), isTrue);
    await devClose(t);
  });

  // the newest bubble's time and ticks rest above the line, whatever the
  // keyboard, the direction or the size of the words
  for (final (how, locale, scale, keyboard) in [
    ('', const Locale('en'), 1.0, false),
    (', keyboard up', const Locale('en'), 1.0, true),
    (', right to left', const Locale('ar'), 1.0, false),
    (', large text', const Locale('en'), 2.0, false),
  ]) {
    for (final still in [false, true]) {
      testWidgets('the line never covers the newest bubble\'s time$how'
          '${still ? ', reduced motion' : ''}', (t) async {
        await seed(40);
        await devOpen(t, chat(), locale: locale, scale: scale, still: still);
        if (keyboard) {
          t.view.viewInsets = const FakeViewPadding(bottom: 600);
          addTearDown(t.view.resetViewInsets);
        }
        await settle(t);
        final newest = find
            .descendant(
              of: find.ancestor(
                of: text('note 39'),
                matching: find.byType(RowAnchor),
              ),
              matching: find.byKey(const ValueKey('meta')),
            )
            .first;
        final before = t.getRect(newest);
        await cameLate('late10', 'late ten', note(24) + 60000);
        appState.chatChanged(_peer);
        await settle(t, 10);
        final chip = find.byKey(const ValueKey('earlier-chip'));
        expect(line(1), findsOneWidget);
        final meta = t.getRect(newest);
        expect(meta.overlaps(t.getRect(chip)), isFalse);
        expect(meta.bottom, lessThan(t.getRect(chip).top));
        // the reader at the newest rode up with it
        expect(meta.top, lessThan(before.top));
        expect(thread(t).pixels, 0);
        await devClose(t);
        setL10nLocale(const Locale('en'));
      });
    }
  }

  testWidgets('the line leaves a reader up the thread where they are', (
    t,
  ) async {
    await seed(40);
    await devOpen(t, chat());
    await settle(t);
    thread(t).jumpTo(600);
    await settle(t);
    final reading = [
      for (var i = 0; i < 40; i++)
        if (seen('note $i')) i,
    ];
    final top = y(t, 'note ${reading.first}');
    await cameLate('late11', 'late eleven', note(2) + 60000);
    appState.chatChanged(_peer);
    await settle(t, 10);
    expect(line(1), findsOneWidget);
    expect(y(t, 'note ${reading.first}'), moreOrLessEquals(top, epsilon: 1));
    await devClose(t);
  });

  testWidgets('a message taken back takes its line with it', (t) async {
    await seed(40);
    await devOpen(t, chat());
    await settle(t);
    await cameLate('late8', 'late eight', note(24) + 60000);
    appState.chatChanged(_peer);
    await settle(t);
    expect(line(1), findsOneWidget);
    // unsent by them
    await mem.delete('messages', where: 'msg_uid = ?', whereArgs: ['late8']);
    appState.chatChanged(_peer);
    await settle(t, 10);
    expect(line(1), findsNothing);
    await devClose(t);
  });

  for (final still in [false, true]) {
    testWidgets('a row leaving that the line does not count leaves the '
        'screen unbuilt${still ? ', reduced motion' : ''}', (t) async {
      await seed(40);
      await devOpen(t, chat(), still: still);
      await settle(t);
      await cameLate('late9', 'late nine', note(24) + 60000);
      appState.chatChanged(_peer);
      await settle(t);
      expect(line(1), findsOneWidget);
      // a row on screen, not counted, taken back
      await mem.delete('messages', where: 'msg_uid = ?', whereArgs: ['uid38']);
      appState.chatChanged(_peer);
      await settle(t, 2);
      expect(text('note 38'), findsOneWidget);
      var builds = 0;
      debugOnRebuildDirtyWidget = (e, _) {
        if (e.widget is ChatScreen) builds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      debugOnRebuildDirtyWidget = null;
      expect(builds, lessThan(2));
      await settle(t, 6);
      expect(text('note 38'), findsNothing);
      expect(line(1), findsOneWidget);
      await devClose(t);
    });
  }

  testWidgets('opened on a message in the newest page, the whole thread is '
      'not read', (t) async {
    await seed(150);
    await devOpen(t, chat(jumpTo: 'uid120'));
    await settle(t, 14);
    expect(seen('note 120'), isTrue);
    expect(db.wholeLoads, 0);
    await devClose(t);
    // one further up than the newest page brings the whole thread in
    await devOpen(t, chat(jumpTo: 'uid20'));
    await settle(t, 14);
    expect(seen('note 20'), isTrue);
    expect(db.wholeLoads, greaterThan(0));
    await devClose(t);
  });
}
