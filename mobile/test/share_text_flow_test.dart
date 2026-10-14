// SPDX-License-Identifier: GPL-3.0-or-later
// words shared from another app, as home takes them: the forward picker,
// then the chat's composer, never a send. a draft there stays with the
// words under it, an open chat takes them in place, the pin comes first,
// hidden chats show only with their vault open and a decoy only its own.
// a photo still goes to the cleaner. android is a stand-in on its channel
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/back_on_top.dart' show pageRoutes;
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        currentChatPeer,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/clean_screen.dart';
import 'package:kryfo/screens/share_sheet.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart' show buildHaloTheme;
import 'package:kryfo/voice_live.dart';
import 'package:kryfo/widgets/key_held.dart' show KeyHeldCard, KeyHeldMark;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _amber = 'amber-long-thread';
const _cedar = 'cedar-quiet-fox';
const _hidden = 'hidden-moss-lake';
const _decoyOne = 'paper-dull-kite';

class _Db extends DevTestDb {
  _Db(super.mem, [super.container]);

  // the people a vault holds, when this is one
  Set<String> holds = const {};
  Set<String> held = const {};

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
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
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: {for (final h in holds) h: true}, groups: <String>{});
  @override
  Future<Set<String>> heldPeers() async => held;
  @override
  Future<bool> keyHeld(String haloId) async => held.contains(haloId);
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
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => const [];
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
  Future<List<Map<String, Object?>>> loadGroups() async => const [];
  @override
  Future<List<Map<String, Object?>>> requestsInbox() async => const [];
}

// nothing may be sent: every call the engine gets is kept
class _Engine implements HaloEngine {
  final calls = <String>[];
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString());
    throw UnimplementedError('engine: ${i.memberName}');
  }
}

// android's side of the tools channel
class _Android {
  Map<String, Object?>? text;
  Map<String, Object?>? image;
  final dropped = <String>[];
  final seen = <String>[];

  Future<Object?> call(MethodCall c) async {
    final a = c.arguments is Map ? c.arguments as Map : const {};
    switch (c.method) {
      case 'takeSharedText':
        final t = text;
        return t == null ? null : Map<String, Object?>.of(t);
      case 'seenSharedText':
        seen.add('${a['id']}:${a['where']}');
        if (text?['id'] == a['id']) text!['seen'] = a['where'];
        return true;
      case 'dropSharedText':
        dropped.add(a['id'] as String);
        if (text?['id'] == a['id']) text = null;
        return true;
      case 'takeShared':
        final i = image;
        image = null;
        return i;
    }
    return null;
  }

  Future<void> say(WidgetTester t, String method) =>
      t.binding.defaultBinaryMessenger.handlePlatformMessage(
        'halo/tools',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        (_) {},
      );

  Future<void> share(
    WidgetTester t,
    String id, {
    String? words,
    String? subject,
  }) async {
    text = {'id': id, 'text': words, 'subject': subject};
    await say(t, 'sharedText');
  }
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

Future<void> _contact(MemDb mem, String id, {int seen = 1}) =>
    mem.insert('contacts', {
      'halo_id': id,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': seen,
      'accepted': 1,
      'back_paired': 1,
    });

void main() {
  late _Android android;
  late _Engine engine;
  late Directory docs;
  late MemDb mem;
  late _Db db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    engine = _Engine();
    useEngineForTest(engine);
    docs = Directory.systemTemp.createTempSync('share_text');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    android = _Android();
    _mock('halo/tools', android.call);
    lockState.openForTest();
    mem = MemDb(except: {'devchat'});
    await devChatTables(mem, now: 1);
    await _contact(mem, _amber, seen: 3);
    await _contact(mem, _cedar, seen: 2);
    db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    _mock('halo/tools', null);
    lockState.openForTest();
    lockState.inDecoy = false;
    docs.deleteSync(recursive: true);
  });

  // real waits for the chat's reads, frames between them
  Future<void> settle(WidgetTester t, [int beats = 8]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  String composer(WidgetTester t) =>
      t.widget<TextField>(find.byType(TextField).last).controller!.text;

  Future<void> home(WidgetTester t) async {
    await devOpen(t, devHome());
    await settle(t, 3);
  }

  // a row of the picker, not of home's list under it
  Finder offered(String id) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(id));

  Future<void> pick(WidgetTester t, String id) async {
    await t.tap(offered(id));
    await settle(t);
  }

  Future<void> leave(WidgetTester t) async {
    await t.tap(find.byTooltip(l10n.commonBack).last);
    await settle(t);
  }

  void nothingSent() {
    expect(mem.rows('messages'), isEmpty);
    expect(engine.calls.where((c) => c.toLowerCase().contains('send')), []);
  }

  testWidgets('the words land in the chat picked, unsent', (t) async {
    await home(t);
    await android.share(
      t,
      's1',
      subject: 'Café Sperl',
      words: 'https://omaps.app/o4B4pYZsRs',
    );
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    // what lands, shown above the chats
    expect(
      find.text('Café Sperl\nhttps://omaps.app/o4B4pYZsRs'),
      findsOneWidget,
    );
    expect(offered(_amber), findsOneWidget);
    expect(offered(_cedar), findsOneWidget);
    expect(android.seen, ['s1:everyday']);
    await pick(t, _cedar);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(composer(t), 'Café Sperl\nhttps://omaps.app/o4B4pYZsRs');
    expect(android.dropped, ['s1']);
    await settle(t, 20);
    nothingSent();
    await t.enterText(find.byType(TextField).last, '');
    await devClose(t);
  });

  testWidgets('a draft there stays, the words under it', (t) async {
    await home(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChatScreen(
          peerHaloId: _amber,
          peerOnion: '',
          peerXPub: '',
          avatarSeed: _amber,
        ),
      ),
    );
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'half a thought');
    await settle(t, 2);
    await leave(t);
    expect(find.byType(ChatScreen), findsNothing);
    await android.share(t, 's2', words: 'see you at 6');
    await settle(t);
    await pick(t, _amber);
    expect(composer(t), 'half a thought\nsee you at 6');
    await settle(t, 20);
    nothingSent();
    await t.enterText(find.byType(TextField).last, '');
    await devClose(t);
  });

  testWidgets('a chat open when the words come takes them in place', (t) async {
    await home(t);
    final nav = Navigator.of(t.element(find.byType(Scaffold).first));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const ChatScreen(
          peerHaloId: _amber,
          peerOnion: '',
          peerXPub: '',
          avatarSeed: _amber,
        ),
      ),
    );
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'typing still');
    await settle(t, 2);
    final open = t.state(find.byType(ChatScreen));
    await android.share(t, 's3', words: 'a link https://example.org');
    await settle(t);
    // the picker comes up over the chat
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await pick(t, _amber);
    // the same chat, not a second copy that would leave it unclaimed
    expect(t.state(find.byType(ChatScreen)), same(open));
    expect(currentChatPeer, _amber);
    expect(composer(t), 'typing still\na link https://example.org');
    await settle(t, 20);
    nothingSent();
    await t.enterText(find.byType(TextField).last, '');
    await devClose(t);
  });

  testWidgets('let go without a pick, nothing lands', (t) async {
    await home(t);
    await android.share(t, 's4', words: 'not this one');
    await settle(t);
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(find.byType(ChatScreen), findsNothing);
    expect(android.dropped, ['s4']);
    expect(android.text, isNull);
    await devClose(t);
  });

  testWidgets('the pin comes first, and nothing of the words before it', (
    t,
  ) async {
    lockState.openForTest(enabled: true);
    lockState.lock();
    expect(lockGuard.isLocked(), isTrue);
    await home(t);
    await android.share(t, 's5', words: 'secret coordinates 48.2, 16.3');
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(find.textContaining('secret coordinates'), findsNothing);
    expect(android.seen, isEmpty);
    lockState.openForTest(enabled: true);
    lockGuard.lifted();
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    expect(find.text('secret coordinates 48.2, 16.3'), findsOneWidget);
    await pick(t, _amber);
    expect(composer(t), 'secret coordinates 48.2, 16.3');
    nothingSent();
    await t.enterText(find.byType(TextField).last, '');
    await devClose(t);
  });

  testWidgets('left before the pin, the words are let go', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    lockState.openForTest(enabled: true);
    lockState.lock();
    await home(t);
    await android.share(t, 's6', words: 'gone with the leave');
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(t, 2);
    expect(android.dropped, ['s6']);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    lockState.openForTest(enabled: true);
    lockGuard.lifted();
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(find.textContaining('gone with the leave'), findsNothing);
    await devClose(t);
  });

  testWidgets('hidden chats are offered only while their vault is open', (
    t,
  ) async {
    final vaultMem = MemDb(except: {'devchat'});
    await devChatTables(vaultMem, now: 1);
    await _contact(vaultMem, _hidden, seen: 5);
    final vault = _Db(vaultMem, HaloContainer.vault)..holds = {_hidden};
    useDatabasesForTest(db, await Session.withVault(db, vault));
    await appState.refreshContacts();
    await home(t);
    await android.share(t, 's7', words: 'for the vault');
    await settle(t);
    expect(offered(_hidden), findsOneWidget);
    expect(offered(_amber), findsOneWidget);
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await devClose(t);

    // shut: the everyday side alone
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    await home(t);
    await android.share(t, 's8', words: 'for the everyday side');
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    expect(offered(_amber), findsOneWidget);
    expect(offered(_hidden), findsNothing);
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await devClose(t);
  });

  testWidgets('a decoy offers its own chats, and nothing the everyday side '
      'was shown', (t) async {
    // shown on the everyday side, never picked
    await home(t);
    await android.share(t, 's9', words: 'shown on the everyday side');
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await devClose(t);
    expect(android.text?['seen'], 'everyday');

    final decoyMem = MemDb(except: {'devchat'});
    await devChatTables(decoyMem, now: 1);
    await _contact(decoyMem, _decoyOne);
    final decoy = _Db(decoyMem, HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    lockState.inDecoy = true;
    await appState.refreshContacts();
    await home(t);
    // the everyday side's words go, unshown
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(android.dropped, ['s9']);

    await android.share(t, 's10', words: 'from the decoy');
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    expect(offered(_decoyOne), findsOneWidget);
    expect(offered(_amber), findsNothing);
    expect(offered(_cedar), findsNothing);
    expect(android.seen.last, 's10:decoy');
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await devClose(t);
  });

  testWidgets('a held contact is marked and asked about first', (t) async {
    db.held = {_cedar};
    await home(t);
    await android.share(t, 's11', words: 'careful');
    await settle(t);
    expect(find.byType(KeyHeldMark), findsNWidgets(2));
    await pick(t, _cedar);
    expect(find.byType(KeyHeldCard), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    expect(find.byType(ChatScreen), findsNothing);
    expect(android.dropped, ['s11']);
    await devClose(t);
  });

  testWidgets('a photo still goes to the cleaner, and words after it to '
      'the picker', (t) async {
    await home(t);
    android.image = {
      'uri': 'content://media/external/images/1',
      'mime': 'image/jpeg',
      'name': 'p.jpg',
      'size': 10,
    };
    await android.say(t, 'shared');
    await settle(t);
    expect(find.byType(CleanScreen), findsOneWidget);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(android.seen, isEmpty);
    await android.share(t, 's12', words: 'and a link');
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    expect(find.byType(CleanScreen), findsOneWidget);
    expect(android.dropped, ['s12']);
    await devClose(t);
  });

  testWidgets('words land over a cleaner left open, which stays', (t) async {
    await home(t);
    android.image = {
      'uri': 'content://media/external/images/1',
      'mime': 'image/jpeg',
      'name': 'p.jpg',
      'size': 10,
    };
    await android.say(t, 'shared');
    await settle(t);
    expect(find.byType(CleanScreen), findsOneWidget);
    await android.share(t, 's13', words: 'over the cleaner');
    await settle(t);
    await pick(t, _cedar);
    expect(composer(t), 'over the cleaner');
    await t.enterText(find.byType(TextField).last, '');
    await leave(t);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(CleanScreen), findsOneWidget);
    await devClose(t);
  });

  testWidgets('the same chat under another page gets the words in a copy '
      'on top, and keeps them once it shows again', (t) async {
    // the app's navigator tells a page when the one over it goes
    await devOpen(t, devHome());
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [pageRoutes],
        home: devHome(),
      ),
    );
    await settle(t, 3);
    final nav = Navigator.of(t.element(find.byType(Scaffold).first));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const ChatScreen(
          peerHaloId: _amber,
          peerOnion: '',
          peerXPub: '',
          avatarSeed: _amber,
        ),
      ),
    );
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'mine');
    await settle(t, 2);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('page')),
      ),
    );
    await settle(t);
    await android.share(t, 's14', words: 'shared');
    await settle(t);
    await pick(t, _amber);
    // the page between is still there under the copy
    expect(find.text('page', skipOffstage: false), findsOneWidget);
    expect(composer(t), 'mine\nshared');
    await leave(t);
    nav.pop();
    await settle(t);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(composer(t), 'mine\nshared');
    await t.enterText(find.byType(TextField).last, '');
    await devClose(t);
  });

  testWidgets('a voice note being recorded keeps the screen until it ends', (
    t,
  ) async {
    await home(t);
    final stop = recordingUntil(() {});
    addTearDown(stop);
    await android.share(t, 's15', words: 'after the note');
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    stop();
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    // one that starts while the picker is up holds the landing too
    final again = recordingUntil(() {});
    addTearDown(again);
    await pick(t, _cedar);
    expect(find.byType(ChatScreen), findsNothing);
    again();
    await settle(t);
    expect(composer(t), 'after the note');
    await t.enterText(find.byType(TextField).last, '');
    await devClose(t);
  });

  testWidgets('a newer share before the picker is up takes its place', (
    t,
  ) async {
    await home(t);
    await android.share(t, 's16', words: 'the older words');
    // the older one is marked shown, its sheet not built yet
    for (var i = 0; i < 100 && android.seen.isEmpty; i++) {
      await t.pump(Duration.zero);
    }
    expect(android.seen, ['s16:everyday']);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    await android.share(t, 's17', words: 'the newer words');
    await settle(t);
    expect(find.text('the older words'), findsNothing);
    expect(find.text('the newer words'), findsOneWidget);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await pick(t, _cedar);
    expect(composer(t), 'the newer words');
    await t.enterText(find.byType(TextField).last, '');
    await devClose(t);
  });

  testWidgets('a home that goes ends its wait, the words kept for the next', (
    t,
  ) async {
    await home(t);
    late BuildContext ctx;
    await t.pumpWidget(
      devApp(
        Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    var alive = true;
    final texts = ShareTexts();
    android.text = {'id': 's18', 'text': 'kept', 'subject': null};
    var ended = false;
    texts.take(ctx, () => alive).whenComplete(() => ended = true);
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    alive = false;
    texts.dispose();
    await t.pumpWidget(const SizedBox());
    await settle(t, 2);
    expect(ended, isTrue);
    expect(android.dropped, isEmpty);
    expect(android.text?['id'], 's18');
  });

  testWidgets('no one to share with: blocked all, or none yet', (t) async {
    await mem.update('contacts', {'blocked': 1});
    await appState.refreshContacts();
    await home(t);
    await android.share(t, 's19', words: 'nobody');
    await settle(t);
    expect(find.text(l10n.shareNoOne), findsOneWidget);
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await devClose(t);

    final none = MemDb(except: {'devchat'});
    await devChatTables(none, now: 1);
    final empty = _Db(none);
    useDatabasesForTest(empty, Session(empty));
    await appState.refreshContacts();
    await home(t);
    await android.share(t, 's20', words: 'nobody yet');
    await settle(t);
    expect(find.text(l10n.shareNoChats), findsOneWidget);
    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await devClose(t);
  });

  test('a share during the setup is let go once it is done', () async {
    android.text = {'id': 's21', 'text': 'too early', 'subject': null};
    await appState.markOnboardingComplete();
    expect(android.dropped, ['s21']);
    expect(android.text, isNull);
  });
}
