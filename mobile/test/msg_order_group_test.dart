// SPDX-License-Identifier: GPL-3.0-or-later
// a group shows its messages where they were written. one that came late
// goes between its neighbours, and one written before the pages held
// comes in with its own page as the reader scrolls up, not at the bottom
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/dates.dart' show hourMinute;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/chat_parts.dart' show JumpDownButton;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g1';
const _rows = 100;

// one group with a long thread, paged as the phone's database pages it
class _GroupDb implements HaloDb {
  final rows = <Map<String, Object?>>[];
  // pages fetched above the newest one
  int olderPages = 0;

  // one that comes now, written at [at]
  void add(String text, int at) {
    final id = rows.length + 1;
    rows.add({
      'rowid': id,
      'id': id,
      'peer_id': 'amber',
      'group_id': _group,
      'direction': 'in',
      'plaintext': text,
      'msg_uid': 'uid$id',
      'sent': 1,
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'written_at': at,
    });
  }

  // the order the phone's database gives: by when written, then as they
  // came
  static int _cmp(Map<String, Object?> a, Map<String, Object?> b) {
    final c = (a['written_at'] as int).compareTo(b['written_at'] as int);
    return c != 0 ? c : (a['id'] as int).compareTo(b['id'] as int);
  }

  List<Map<String, Object?>> get _ordered => [...rows]..sort(_cmp);

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
    final all = _ordered;
    final top = beforeRowid == null
        ? null
        : {
            'id': beforeRowid,
            'written_at':
                beforeAt ??
                all.firstWhere((r) => r['id'] == beforeRowid)['written_at'],
          };
    final older = [
      for (final r in all)
        if (top == null || _cmp(r, top) < 0) r,
    ];
    return older.sublist(older.length > limit ? older.length - limit : 0);
  }

  // whole threads read
  int wholeLoads = 0;
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async {
    wholeLoads++;
    return _ordered;
  }

  @override
  Future<bool> messageExists(String msgUid) async =>
      rows.any((r) => r['msg_uid'] == msgUid);
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  late _GroupDb db;
  // two minutes apart, from yesterday morning
  final now = DateTime.now();
  final base = DateTime(
    now.year,
    now.month,
    now.day - 1,
    10,
  ).millisecondsSinceEpoch;
  int note(int i) => base + i * 120000;

  Future<void> frames(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(
    WidgetTester t, {
    String? jumpTo,
    bool still = false,
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    phone(t);
    db = _GroupDb();
    for (var i = 0; i < _rows; i++) {
      db.add('note $i', note(i));
    }
    useDatabasesForTest(db, Session(db));
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    setL10nLocale(locale);
    addTearDown(() => setL10nLocale(const Locale('en')));
    await t.pumpWidget(
      app(
        Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: GroupChatScreen(groupId: _group, jumpToUid: jumpTo),
          ),
        ),
        still: still,
        locale: locale,
      ),
    );
    await frames(t, 20);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  ScrollPosition thread(WidgetTester t) => t
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((s) => s.axisDirection == AxisDirection.down)
      .position;

  Finder text(String s) => find.text(s, findRichText: true);
  bool seen(String s) => text(s).hitTestable().evaluate().isNotEmpty;
  double y(WidgetTester t, String s) => t.getCenter(text(s)).dy;

  testWidgets('one that came late goes between its neighbours, and one '
      'written before the pages held comes with its page', (t) async {
    await open(t);
    expect(seen('note 99'), isTrue);
    // written between notes 97 and 98, come now
    db.add('late one', note(97) + 60000);
    // written far up, in a page not held yet
    db.add('late two', note(10) + 60000);
    appState.chatChanged('group:$_group');
    await frames(t, 6);
    expect(seen('late one'), isTrue);
    expect(y(t, 'note 97'), lessThan(y(t, 'late one')));
    expect(y(t, 'late one'), lessThan(y(t, 'note 98')));
    expect(text('late two'), findsNothing);
    // up to the top: the older page comes in, the late one in it
    for (var i = 0; i < 4; i++) {
      thread(t).jumpTo(0);
      await frames(t, 10);
    }
    expect(db.olderPages, greaterThan(0));
    for (var i = 0; i < 40 && text('late two').evaluate().isEmpty; i++) {
      thread(
        t,
      ).jumpTo((thread(t).pixels + 300).clamp(0, thread(t).maxScrollExtent));
      await frames(t, 2);
    }
    expect(text('late two'), findsOneWidget);
    expect(y(t, 'note 10'), lessThan(y(t, 'late two')));
    expect(y(t, 'late two'), lessThan(y(t, 'note 11')));
    await close(t);
  });

  testWidgets('one that came late above a reader leaves them where they '
      'are, and is not counted as new below', (t) async {
    await open(t);
    thread(t).jumpTo(thread(t).maxScrollExtent - 1500);
    await frames(t, 6);
    List<int> shown() => [
      for (var i = 0; i < _rows; i++)
        if (seen('note $i')) i,
    ];
    final reading = shown();
    expect(reading.first, greaterThan(45));
    final top = y(t, 'note ${reading.first}');
    // written just above what is on screen, in the page held
    db.add('late three', note(reading.first - 3) + 60000);
    appState.chatChanged('group:$_group');
    await frames(t, 6);
    expect(shown(), reading);
    expect(y(t, 'note ${reading.first}'), moreOrLessEquals(top, epsilon: 1));
    expect(t.widget<JumpDownButton>(find.byType(JumpDownButton)).count, 0);
    await close(t);
  });

  testWidgets('one that came late well up the thread shows the line, and '
      'a tap lands on it', (t) async {
    await open(t);
    final line = find.text(l10n.chatEarlierMessagesArrived(1)).hitTestable();
    expect(line, findsNothing);
    db.add('late four', note(60) + 60000);
    appState.chatChanged('group:$_group');
    await frames(t, 6);
    expect(seen('late four'), isFalse);
    expect(line, findsOneWidget);
    await t.tap(line);
    await frames(t, 20);
    expect(seen('late four'), isTrue);
    expect(line, findsNothing);
    await close(t);
  });

  testWidgets('a message taken back takes its line with it', (t) async {
    await open(t);
    final line = find.text(l10n.chatEarlierMessagesArrived(1)).hitTestable();
    db.add('late five', note(60) + 60000);
    appState.chatChanged('group:$_group');
    await frames(t, 6);
    expect(line, findsOneWidget);
    db.rows.removeWhere((r) => r['plaintext'] == 'late five');
    appState.chatChanged('group:$_group');
    await frames(t, 10);
    expect(line, findsNothing);
    await close(t);
  });

  for (final still in [false, true]) {
    testWidgets('a row leaving that the line does not count leaves the '
        'screen unbuilt${still ? ', reduced motion' : ''}', (t) async {
      await open(t, still: still);
      final line = find.text(l10n.chatEarlierMessagesArrived(1)).hitTestable();
      db.add('late six', note(60) + 60000);
      appState.chatChanged('group:$_group');
      await frames(t, 6);
      expect(line, findsOneWidget);
      // a row on screen, not counted, taken back
      db.rows.removeWhere((r) => r['plaintext'] == 'note 98');
      appState.chatChanged('group:$_group');
      await frames(t, 2);
      expect(text('note 98'), findsOneWidget);
      var builds = 0;
      debugOnRebuildDirtyWidget = (e, _) {
        if (e.widget is GroupChatScreen) builds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      await frames(t, 5);
      debugOnRebuildDirtyWidget = null;
      expect(builds, lessThan(2));
      await frames(t, 10);
      expect(text('note 98'), findsNothing);
      expect(line, findsOneWidget);
      await close(t);
    });
  }

  // the newest bubble's time rests above the line, whatever the keyboard,
  // the direction or the size of the words
  for (final (how, locale, scale, keyboard) in [
    ('', const Locale('en'), 1.0, false),
    (', keyboard up', const Locale('en'), 1.0, true),
    (', right to left', const Locale('ar'), 1.0, false),
    (', large text', const Locale('en'), 2.0, false),
  ]) {
    for (final still in [false, true]) {
      testWidgets('the line never covers the newest bubble\'s time$how'
          '${still ? ', reduced motion' : ''}', (t) async {
        await open(t, locale: locale, scale: scale, still: still);
        if (keyboard) {
          t.view.viewInsets = const FakeViewPadding(bottom: 900);
          addTearDown(t.view.resetViewInsets);
          await frames(t, 6);
          thread(t).jumpTo(thread(t).maxScrollExtent);
          await frames(t, 2);
        }
        final time = find
            .textContaining(
              hourMinute(DateTime.fromMillisecondsSinceEpoch(note(99))),
              findRichText: true,
            )
            .last;
        final before = t.getRect(time);
        db.add('late seven', note(60) + 60000);
        appState.chatChanged('group:$_group');
        await frames(t, 10);
        final chip = find.byKey(const ValueKey('earlier-chip'));
        expect(
          find.text(l10n.chatEarlierMessagesArrived(1)).hitTestable(),
          findsOneWidget,
        );
        final meta = t.getRect(time);
        expect(meta.overlaps(t.getRect(chip)), isFalse);
        expect(meta.bottom, lessThan(t.getRect(chip).top));
        // the reader at the newest rode up with it
        expect(meta.top, lessThan(before.top));
        expect(
          thread(t).pixels,
          moreOrLessEquals(thread(t).maxScrollExtent, epsilon: 0.01),
        );
        await close(t);
      });
    }
  }

  testWidgets('the line leaves a reader up the thread where they are', (
    t,
  ) async {
    await open(t);
    thread(t).jumpTo(thread(t).maxScrollExtent - 1500);
    await frames(t, 6);
    final reading = [
      for (var i = 0; i < _rows; i++)
        if (seen('note $i')) i,
    ];
    final top = y(t, 'note ${reading.first}');
    // in the page held, above what is on screen
    db.add('late eight', note(math.max(reading.first - 8, 42)) + 60000);
    appState.chatChanged('group:$_group');
    await frames(t, 10);
    expect(
      find.text(l10n.chatEarlierMessagesArrived(1)).hitTestable(),
      findsOneWidget,
    );
    expect(y(t, 'note ${reading.first}'), moreOrLessEquals(top, epsilon: 1));
    await close(t);
  });

  testWidgets('opened on a message in the newest page, the whole thread is '
      'not read', (t) async {
    // uid90 is note 89
    await open(t, jumpTo: 'uid90');
    await frames(t, 10);
    expect(seen('note 89'), isTrue);
    expect(db.wholeLoads, 0);
    await close(t);
  });
}
