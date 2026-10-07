// SPDX-License-Identifier: GPL-3.0-or-later
// the pages around the chat list. an archived chat opens on a tap and comes
// back out on a swipe; a saved message opens the chat it was saved in, a
// group's too, and says so when that chat is gone; a request's answers fit
// in a long language on a small phone; notes wait for their first load and
// a held note can be copied or deleted; a held group or chat opens the
// house menu; a card over the list opens its height and folds away, simply
// there with less movement. the database is a stand-in in memory.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/rooms.dart' show kRoomJoinWait;
import 'package:kryfo/screens/archived_screen.dart';
import 'package:kryfo/screens/chat_door.dart';
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/notes_screen.dart';
import 'package:kryfo/screens/requests_screen.dart';
import 'package:kryfo/screens/saved_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/breathing_ring.dart';
import 'package:kryfo/widgets/message_menu.dart' show MenuSheet;
import 'package:kryfo/widgets/page_head.dart' show HeadLine;
import 'package:kryfo/widgets/room_countdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

// only what these screens ask for; anything else fails on its type
class _Db implements HaloDb {
  List<Map<String, Object?>> people = [];
  List<Map<String, Object?>> requests = [];
  List<Map<String, Object?>> saved = [];
  List<Map<String, Object?>> notes = [];
  List<Map<String, Object?>> groups = [];
  final deleted = <String>[];

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> contacts() async => [...people];
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => [...requests];
  @override
  Future<int> pendingRequestCount() async => requests.length;
  @override
  Future<List<Map<String, Object?>>> requestsInbox() async => [...requests];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<List<Map<String, Object?>>> savedMessages() async => [...saved];
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [...groups];
  @override
  Future<bool> groupExists(String groupId) async =>
      groups.any((g) => g['group_id'] == groupId);
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async =>
      groups.where((g) => g['group_id'] == groupId).firstOrNull;
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      peerId == kNotesPeerId ? [...notes] : [];
  @override
  Future<void> assignUidIfMissing(String peerId, int sentAt, String uid) async {
    notes = [
      for (final n in notes)
        if (n['sent_at'] == sentAt && n['msg_uid'] == null)
          {...n, 'msg_uid': uid}
        else
          n,
    ];
  }

  @override
  Future<void> deleteMessage(String msgUid) async {
    deleted.add(msgUid);
    notes.removeWhere((n) => n['msg_uid'] == msgUid);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

// the transport, as relay mode reads it: every relay failing, or not
class _Engine implements HaloEngine {
  bool relayDown = false;
  @override
  Map<String, dynamic> transportState() => {
    'relays': [
      {'url': 'wss://relay.example', 'fails': relayDown ? 4 : 0},
    ],
  };
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

Map<String, Object?> _person(String id) => {
  'halo_id': id,
  'nickname': null,
  'last_seen': 0,
  'blocked': 0,
  'onion': '',
  'xpub': 'x-$id',
};

final _theme = buildHaloTheme();

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

// what the phone was asked: haptics, the clipboard
final _asked = <MethodCall>[];

void phone(WidgetTester t, {Size size = const Size(500, 900)}) {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  _asked.clear();
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    _asked.add(c);
    return null;
  });
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

// the toast, and the page gone
Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

ContactPreview _chat(String id, {bool archived = false}) =>
    ContactPreview(haloId: id, avatarSeed: id, archived: archived);

Widget _home({
  List<ContactPreview> contacts = const [],
  List<GroupSummary> groups = const [],
}) => HomeScreen(
  haloId: 'neon-tiger-saturn',
  contacts: contacts,
  groups: groups,
  onAddContact: () {},
  onNewGroup: () {},
  onNewRoom: () {},
  onOpenDev: () {},
  onOpenSettingsDirect: () {},
  onOpenChat: (_) {},
  onOpenGroup: (_) {},
);

// how far a card has opened: 1 is all of it
double opened(WidgetTester t, String text) => t
    .widget<SizeTransition>(
      find.ancestor(of: find.text(text), matching: find.byType(SizeTransition)),
    )
    .sizeFactor
    .value;

void main() {
  late _Db db;
  late _Engine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    db = _Db();
    engine = _Engine();
    useDatabasesForTest(db, Session(db));
    useEngineForTest(engine);
    chatPageForTest = ({String? groupId, String? peer, String? uid}) =>
        Scaffold(body: Text('chat $groupId $peer $uid'));
  });

  tearDown(() => chatPageForTest = null);

  group('archived', () {
    Widget list(List<String> opened, List<String> back) => framed(
      Scaffold(
        body: ArchivedList(
          archived: [_chat('wren-oak-lamp', archived: true)],
          onOpen: opened.add,
          onUnarchive: back.add,
        ),
      ),
    );

    testWidgets('a tap opens the chat', (t) async {
      phone(t);
      final opened = <String>[], back = <String>[];
      await t.pumpWidget(list(opened, back));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('wren-oak-lamp'));
      await t.pump();
      expect(opened, ['wren-oak-lamp']);
      expect(back, isEmpty);
      await drain(t);
    });

    testWidgets('a swipe toward the start takes it back out', (t) async {
      phone(t);
      final opened = <String>[], back = <String>[];
      await t.pumpWidget(list(opened, back));
      await t.pump(const Duration(seconds: 1));
      await t.drag(find.text('wren-oak-lamp'), const Offset(-400, 0));
      await t.pumpAndSettle();
      expect(back, ['wren-oak-lamp']);
      expect(opened, isEmpty);
      await drain(t);
    });
  });

  group('saved', () {
    testWidgets('a group message names its group and opens the group at it', (
      t,
    ) async {
      phone(t);
      db.groups = [
        {'group_id': 'g1', 'name': 'Hikers'},
      ];
      db.saved = [
        {
          'msg_uid': 'u1',
          'peer_id': 'slow-kite-moss',
          'group_id': 'g1',
          'plaintext': 'bring the map',
          'sent_at': DateTime(2026, 9, 27, 9).millisecondsSinceEpoch,
        },
      ];
      await t.pumpWidget(framed(const SavedScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('slow-kite-moss · Hikers'), findsOneWidget);
      await t.tap(find.text('bring the map'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('chat g1 slow-kite-moss u1'), findsOneWidget);
      await drain(t);
    });

    testWidgets('a chat that is gone says so instead of doing nothing', (
      t,
    ) async {
      phone(t);
      db.saved = [
        {
          'msg_uid': 'u2',
          'peer_id': 'grey-owl-dune',
          'plaintext': 'see you at noon',
          'sent_at': DateTime(2026, 9, 27, 9).millisecondsSinceEpoch,
        },
      ];
      await t.pumpWidget(framed(const SavedScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('see you at noon'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.savedChatGone), findsOneWidget);
      await drain(t);
    });
  });

  group('requests', () {
    testWidgets('the answers fit a long language on a small phone', (t) async {
      phone(t, size: const Size(360, 740));
      db.requests = [_person('amber-fox-river')];
      await t.pumpWidget(
        framed(const RequestsScreen(), locale: const Locale('de')),
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      for (final a in [
        l10n.commonAccept,
        l10n.requestsDecline,
        l10n.commonBlock,
      ]) {
        expect(t.getRect(find.text(a)).right, lessThanOrEqualTo(360 - 16));
      }
      await drain(t);
    });
  });

  group('notes', () {
    Map<String, Object?> note(String text, {String? uid}) => {
      'rowid': 1,
      'plaintext': text,
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': uid,
    };

    testWidgets('nothing shows until they have loaded, then the notes', (
      t,
    ) async {
      phone(t);
      db.notes = [note('buy lemons')];
      await t.pumpWidget(framed(const NotesScreen()));
      expect(find.byType(BreathingRing), findsNothing);
      expect(find.text(l10n.notesAQuietPlace), findsNothing);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('buy lemons'), findsOneWidget);
      expect(find.byType(BreathingRing), findsNothing);
      // the day reads as it does in a chat
      expect(find.text(l10n.chatToday), findsOneWidget);
      await drain(t);
    });

    // the list starts at the bottom: the line is there while older notes
    // run up under the bar, and goes at the top of them
    testWidgets('the bar\'s hairline shows while notes run under it', (
      t,
    ) async {
      phone(t);
      double line() {
        final box = t.widget<Container>(
          find.descendant(
            of: find.byType(HeadLine),
            matching: find.byType(Container),
          ),
        );
        return (box.color ?? const Color(0x00000000)).a;
      }

      db.notes = [
        for (var i = 0; i < 30; i++)
          {...note('note $i', uid: 'n$i'), 'rowid': i},
      ];
      await t.pumpWidget(framed(const NotesScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(line(), greaterThan(0.9));
      await t.fling(find.text('note 29'), const Offset(0, 6000), 4000);
      await t.pumpAndSettle();
      expect(find.text('note 0'), findsOneWidget);
      expect(line(), 0);
      await drain(t);
    });

    testWidgets('a few notes leave the bar plain', (t) async {
      phone(t);
      db.notes = [note('buy lemons', uid: 'n1')];
      await t.pumpWidget(framed(const NotesScreen()));
      await t.pump(const Duration(seconds: 1));
      final box = t.widget<Container>(
        find.descendant(
          of: find.byType(HeadLine),
          matching: find.byType(Container),
        ),
      );
      expect(box.color!.a, 0);
      await drain(t);
    });

    testWidgets('held, a note can be copied', (t) async {
      phone(t);
      db.notes = [note('buy lemons', uid: 'n1')];
      await t.pumpWidget(framed(const NotesScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.longPress(find.text('buy lemons'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(MenuSheet), findsOneWidget);
      await t.tap(find.text(l10n.commonCopy));
      await t.pump(const Duration(milliseconds: 600));
      final copied = _asked.where((c) => c.method == 'Clipboard.setData');
      expect(copied.single.arguments, {'text': 'buy lemons'});
      expect(find.text(l10n.commonCopied), findsOneWidget);
      await drain(t);
    });

    testWidgets('delete asks first, then the note folds away', (t) async {
      phone(t);
      // kept before notes had a uid: it is given one to go
      db.notes = [note('buy lemons')];
      await t.pumpWidget(framed(const NotesScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.longPress(find.text('buy lemons'));
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text(l10n.commonDelete));
      // the menu goes down, then the question comes up
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.notesDeleteThisNote), findsOneWidget);
      expect(db.deleted, isEmpty);
      await t.tap(find.text(l10n.commonDelete).last);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(seconds: 1));
      expect(db.deleted, hasLength(1));
      expect(find.text('buy lemons'), findsNothing);
      expect(find.text(l10n.notesAQuietPlace), findsOneWidget);
      await drain(t);
    });
  });

  group('home', () {
    setUp(() => appState.sendModeForTest = 'balanced');

    testWidgets('a held group opens its menu, and leaving asks first', (
      t,
    ) async {
      phone(t);
      db.groups = [
        {'group_id': 'g1', 'name': 'Hikers', 'is_admin': 0},
      ];
      await t.pumpWidget(
        framed(
          _home(
            groups: const [
              GroupSummary(groupId: 'g1', name: 'Hikers', memberCount: 3),
            ],
          ),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      await t.longPress(find.text('Hikers'));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(MenuSheet), findsOneWidget);
      await t.tap(find.text(l10n.groupInfoLeaveGroup2));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text(l10n.groupInfoLeaveGroup), findsOneWidget);
      expect(find.text(l10n.groupInfoLeaveGroupLine), findsOneWidget);
      await drain(t);
    });

    testWidgets('a room not let in yet says so on its row, with no clock', (
      t,
    ) async {
      phone(t);
      final now = DateTime.now().millisecondsSinceEpoch;
      GroupSummary room(int joiningAt) => GroupSummary(
        groupId: 'r1',
        name: 'Friday',
        memberCount: 2,
        expiresAt: now + 3600000,
        joiningAt: joiningAt,
      );
      await t.pumpWidget(framed(_home(groups: [room(now)])));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.roomJoinWaitingToJoin), findsOneWidget);
      expect(find.byType(RoomCountdown), findsNothing);
      // past the wait it says the room is not answering
      final long = now - kRoomJoinWait.inMilliseconds - 1;
      await t.pumpWidget(framed(_home(groups: [room(long)])));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.roomJoinNotAnswering), findsOneWidget);
      expect(find.text(l10n.roomJoinWaitingToJoin), findsNothing);
      expect(find.byType(RoomCountdown), findsNothing);
      // let in: the clock, as any room
      await t.pumpWidget(
        framed(
          _home(
            groups: [
              GroupSummary(
                groupId: 'r1',
                name: 'Friday',
                memberCount: 2,
                expiresAt: now + 3600000,
              ),
            ],
          ),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(RoomCountdown), findsOneWidget);
      expect(find.text(l10n.roomJoinNotAnswering), findsNothing);
      await drain(t);
    });

    testWidgets('a held chat opens the house menu, delete in its own group', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(_home(contacts: [_chat('wren-oak-lamp')])));
      await t.pump(const Duration(seconds: 1));
      await t.longPress(find.text('wren-oak-lamp'));
      await t.pump(const Duration(milliseconds: 600));
      final menu = t.widget<MenuSheet>(find.byType(MenuSheet));
      expect(menu.groups.last.single.danger, isTrue);
      expect(menu.groups.last.single.label, l10n.homeDeleteChat);
      expect(find.text(l10n.homeMessagesAndContactGone), findsOneWidget);
      await drain(t);
    });

    Future<void> relay(WidgetTester t, {required bool down}) async {
      engine.relayDown = down;
      if (down) {
        // down for long enough that the card is due
        appState.sampleRelayHealth(
          now: DateTime.now().subtract(const Duration(minutes: 3)),
        );
      }
      appState.sampleRelayHealth();
    }

    testWidgets('a card opens its height as it comes and folds as it goes', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(_home()));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.homeOurRelayIsQuiet), findsNothing);
      await relay(t, down: true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      final mid = opened(t, l10n.homeOurRelayIsQuiet);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await t.pump(const Duration(milliseconds: 400));
      expect(opened(t, l10n.homeOurRelayIsQuiet), 1);
      await relay(t, down: false);
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      expect(opened(t, l10n.homeOurRelayIsQuiet), lessThan(1));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.homeOurRelayIsQuiet), findsNothing);
      await drain(t);
    });

    testWidgets('reduced motion: the card is simply there, and gone', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(_home(), still: true));
      await t.pump(const Duration(seconds: 1));
      await relay(t, down: true);
      await t.pump();
      await t.pump();
      expect(opened(t, l10n.homeOurRelayIsQuiet), 1);
      await relay(t, down: false);
      await t.pump();
      await t.pump();
      expect(find.text(l10n.homeOurRelayIsQuiet), findsNothing);
      await drain(t);
    });
  });
}
