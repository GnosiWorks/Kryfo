// SPDX-License-Identifier: GPL-3.0-or-later
// photos, videos and files shared from another app, as home takes them:
// one photo or video asks "Send to a chat" or "Check this photo", files and
// several go straight to the chat picker. the pin comes first, a decoy shows
// only its own chats, hidden ones only with their vault open, nothing is
// copied before a chat is picked, one over the limit is said and never
// copied, and every copy goes once done with. android is a stand-in
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show DevRow, devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateFiles,
        AppStateRefresh,
        AppStateRoute;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/media_send_screen.dart';
import 'package:kryfo/screens/photo_knows_screen.dart';
import 'package:kryfo/screens/share_files_sheet.dart'
    show copyIdleLimit, sharePeekLimit;
import 'package:kryfo/session.dart';
import 'package:kryfo/picture_convert.dart' show kConvertMost;
import 'package:kryfo/share_files.dart';
import 'package:kryfo/tools/tools_bridge.dart' show PickedFile;
import 'package:kryfo/widgets/media_bubbles.dart'
    show fileTooBigLine, humanFileSize;
import 'package:kryfo/picked.dart' show PickedMedia;
import 'package:kryfo/screens/dev_about_sheet.dart' show DevForwardTile;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _amber = 'amber-long-thread';
const _cedar = 'cedar-quiet-fox';
const _hidden = 'hidden-moss-lake';
const _decoyOne = 'paper-dull-kite';

// a 1x1 png: kept as it is on its way to the preview
final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0xf8,
  0xcf,
  0xc0,
  0xf0,
  0x1f,
  0x00,
  0x05,
  0x00,
  0x01,
  0xff,
  0x89,
  0x99,
  0x3d,
  0x1d,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

class _Db extends DevTestDb {
  _Db(super.mem, [super.container]);

  // the people a vault holds, when this is one
  Set<String> holds = const {};
  // each message saved, by the name of the file it carries
  final saved = <String?>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #saveMessage) {
      saved.add(i.namedArguments[#fileName] as String?);
      return Future<void>.value();
    }
    return super.noSuchMethod(i);
  }

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
  void nostrSubscribeBg(int ident, String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(int ident, String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString());
    throw UnimplementedError('engine: ${i.memberName}');
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

// android's side of the tools channel: the share, and copies in made in
// a tools_in folder of their own as the real one makes them
class _Android {
  _Android(this.cache);
  final Directory cache;
  Map<String, Object?>? files;
  final dropped = <String>[];
  final seen = <String>[];
  final copied = <String>[];
  final copies = <String>[];
  var cancels = 0;
  var hangPeek = false;

  Future<Object?> call(MethodCall c) async {
    final a = c.arguments is Map ? c.arguments as Map : const {};
    switch (c.method) {
      case 'takeSharedFiles':
        if (hangPeek) return Completer<Object?>().future;
        final f = files;
        return f == null ? null : Map<String, Object?>.of(f);
      case 'seenSharedFiles':
        seen.add('${a['id']}:${a['where']}');
        if (files?['id'] == a['id']) files!['seen'] = a['where'];
        return true;
      case 'dropSharedFiles':
        dropped.add(a['id'] as String);
        if (files?['id'] == a['id']) files = null;
        return true;
      case 'cancelCopy':
        cancels++;
        return true;
      case 'copyIn':
        final uri = a['uri'] as String;
        copied.add(uri);
        // a provider that never answers
        if (uri.contains('hang')) return Completer<Object?>().future;
        final dir = Directory(
          p.join(cache.path, 'tools_in', 'c${copies.length}'),
        )..createSync(recursive: true);
        final name = uri.endsWith('.pdf') ? 'a.pdf' : 'p.png';
        final f = File(p.join(dir.path, name))
          ..writeAsBytesSync(uri.endsWith('.pdf') ? _pdfBytes : _png);
        copies.add(f.path);
        return f.path;
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
    String id,
    List<Map<String, Object?>> items,
  ) async {
    files = {'id': id, 'items': items};
    await say(t, 'sharedFiles');
  }

  // every copy in is gone again
  bool allGone() => copies.every((c) => !File(c).existsSync());
}

Map<String, Object?> _photo([int n = 1]) => {
  'uri': 'content://media/external/images/$n',
  'mime': 'image/png',
  'name': 'p$n.png',
  'size': _png.length,
};

final _pdfBytes = Uint8List.fromList(
  '%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n'.codeUnits,
);

Map<String, Object?> _pdf({int? size}) => {
  'uri': 'content://downloads/1/a.pdf',
  'mime': 'application/pdf',
  'name': 'a.pdf',
  'size': size ?? _png.length,
};

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
    docs = Directory.systemTemp.createTempSync('share_files');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    android = _Android(docs);
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

  Future<void> settle(WidgetTester t, [int beats = 8]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> home(WidgetTester t) async {
    await devOpen(t, devHome());
    await settle(t, 3);
  }

  Finder offered(String id) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(id));

  Future<void> pick(WidgetTester t, String id) async {
    await t.tap(offered(id));
    await settle(t, 60);
  }

  Future<void> letGo(WidgetTester t) async {
    await t.tapAt(const Offset(20, 20));
    await settle(t);
  }

  void nothingSent() {
    expect(mem.rows('messages'), isEmpty);
    expect(db.saved, isEmpty);
    expect(engine.calls.where((c) => c.toLowerCase().contains('send')), []);
  }

  testWidgets('one photo: send it to a chat, through the send preview', (
    t,
  ) async {
    await home(t);
    await android.share(t, 'f1', [_photo()]);
    await settle(t);
    expect(find.text(l10n.toolsSendToAChat), findsOneWidget);
    expect(find.text(l10n.shareCheckPhoto), findsOneWidget);
    expect(android.seen, ['f1:everyday']);
    // nothing copied before a chat is picked
    expect(android.copied, isEmpty);
    await t.tap(find.text(l10n.toolsSendToAChat));
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    expect(android.copied, isEmpty);
    await pick(t, _cedar);
    expect(android.copied, ['content://media/external/images/1']);
    // copied in: the uri is let go
    expect(android.dropped, ['f1']);
    expect(find.byType(ChatScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(MediaSendScreen), findsOneWidget);
    nothingSent();
    // backed out of the preview: nothing goes, the copy neither stays
    await t.tap(find.byTooltip(l10n.commonBack).last);
    await settle(t);
    expect(find.byType(MediaSendScreen), findsNothing);
    nothingSent();
    expect(android.allGone(), isTrue);
    await devClose(t);
  });

  testWidgets('one photo: check it, and no chat is offered', (t) async {
    await home(t);
    await android.share(t, 'f2', [_photo()]);
    await settle(t);
    await t.tap(find.text(l10n.shareCheckPhoto));
    await settle(t);
    expect(find.byType(PhotoKnowsScreen), findsOneWidget);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(android.dropped, ['f2']);
    await devClose(t);
  });

  testWidgets('a video is asked about as a video', (t) async {
    await home(t);
    await android.share(t, 'f3', [
      {
        'uri': 'content://media/external/video/1',
        'mime': 'video/mp4',
        'name': 'v.mp4',
        'size': 100,
      },
    ]);
    await settle(t);
    expect(find.text(l10n.shareCheckVideo), findsOneWidget);
    await letGo(t);
    expect(android.dropped, ['f3']);
    expect(android.copied, isEmpty);
    await devClose(t);
  });

  testWidgets('a file and several photos go straight to the chat picker', (
    t,
  ) async {
    await home(t);
    await android.share(t, 'f4', [_pdf()]);
    await settle(t);
    expect(find.text(l10n.shareCheckPhoto), findsNothing);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await letGo(t);
    expect(android.dropped, ['f4']);

    await android.share(t, 'f5', [_photo(1), _photo(2)]);
    await settle(t);
    expect(find.text(l10n.shareCheckPhoto), findsNothing);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await pick(t, _amber);
    expect(android.copied, hasLength(2));
    expect(find.byType(MediaSendScreen), findsOneWidget);
    await t.tap(find.byTooltip(l10n.commonBack).last);
    await settle(t);
    nothingSent();
    expect(android.allGone(), isTrue);
    await devClose(t);
  });

  testWidgets('a photo and a pdf: backing out of the preview sends neither', (
    t,
  ) async {
    await home(t);
    await android.share(t, 'f20', [_photo(), _pdf()]);
    await settle(t);
    await pick(t, _amber);
    expect(find.byType(MediaSendScreen), findsOneWidget);
    await t.tap(find.byTooltip(l10n.commonBack).last);
    await settle(t, 20);
    // no question about the files either: the share ended there
    expect(find.text(l10n.shareSendFiles(1)), findsNothing);
    nothingSent();
    expect(android.copies, hasLength(2));
    expect(android.allGone(), isTrue);
    await devClose(t);
  });

  testWidgets('a pdf is asked about, then sent, and its copy goes', (t) async {
    await home(t);
    await android.share(t, 'f21', [_pdf()]);
    await settle(t);
    await pick(t, _amber);
    expect(find.text(l10n.shareSendFiles(1)), findsOneWidget);
    expect(find.text('a.pdf'), findsOneWidget);
    nothingSent();
    await t.tap(find.text(l10n.chatSendIt));
    await settle(t, 100);
    expect(db.saved, ['a.pdf']);
    expect(android.allGone(), isTrue);
    await devClose(t);
  });

  testWidgets('a pdf asked about and cancelled sends nothing', (t) async {
    await home(t);
    await android.share(t, 'f22', [_pdf()]);
    await settle(t);
    await pick(t, _amber);
    await t.tap(find.text(l10n.commonCancel));
    await settle(t, 20);
    nothingSent();
    expect(android.allGone(), isTrue);
    await devClose(t);
  });

  testWidgets('a copy that hangs can be stopped, and the next share works', (
    t,
  ) async {
    await home(t);
    await android.share(t, 'f23', [
      {
        'uri': 'content://hang/1',
        'mime': 'application/pdf',
        'name': 'h.pdf',
        'size': 10,
      },
    ]);
    await settle(t);
    await t.tap(offered(_amber));
    await settle(t, 10);
    expect(find.text(l10n.photoKnowsReadingTheFile), findsOneWidget);
    await t.tap(find.text(l10n.commonCancel));
    await settle(t, 10);
    expect(android.cancels, greaterThan(0));
    expect(find.text(l10n.photoKnowsReadingTheFile), findsNothing);
    expect(find.byType(ChatScreen), findsNothing);
    expect(android.dropped, contains('f23'));

    await android.share(t, 'f24', [_pdf()]);
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await letGo(t);
    await devClose(t);
  });

  testWidgets('a copy that stopped moving says so', (t) async {
    copyIdleLimit = const Duration(seconds: 2);
    addTearDown(() => copyIdleLimit = const Duration(seconds: 45));
    await home(t);
    await android.share(t, 'f40', [
      {
        'uri': 'content://hang/2',
        'mime': 'application/pdf',
        'name': 'h.pdf',
        'size': 10,
      },
    ]);
    await settle(t);
    await t.tap(offered(_amber));
    await settle(t, 30);
    expect(android.cancels, greaterThan(0));
    expect(find.text(l10n.chatCouldNotReadThat), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    nothingSent();
    await settle(t, 40);
    await devClose(t);
  });

  testWidgets('a look android never answers ends, and the next one works', (
    t,
  ) async {
    sharePeekLimit = const Duration(milliseconds: 300);
    addTearDown(() => sharePeekLimit = const Duration(seconds: 10));
    await home(t);
    android.hangPeek = true;
    await android.share(t, 'f25', [_pdf()]);
    await settle(t, 10);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    android.hangPeek = false;
    await android.share(t, 'f26', [_pdf()]);
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await letGo(t);
    await devClose(t);
  });

  testWidgets('a lock while the preview is up shreds every copy of it', (
    t,
  ) async {
    lockState.openForTest(enabled: true);
    await home(t);
    await android.share(t, 'f27', [_photo(), _pdf()]);
    await settle(t);
    await pick(t, _amber);
    expect(find.byType(MediaSendScreen), findsOneWidget);
    expect(SharedInbox.takenCount, 2);
    lockState.lock();
    await settle(t, 60);
    expect(android.allGone(), isTrue);
    expect(SharedInbox.takenCount, 0);
    nothingSent();
    await devClose(t);
  });

  testWidgets('a lock while the chat picker is up drops the share', (t) async {
    lockState.openForTest(enabled: true);
    await home(t);
    await android.share(t, 'f29', [_pdf()]);
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    lockState.lock();
    await settle(t);
    lockState.openForTest(enabled: true);
    lockGuard.lifted();
    await settle(t);
    // nothing of the share is waiting behind the pin
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(offered(_amber), findsNothing);
    expect(android.dropped, ['f29']);
    expect(android.copied, isEmpty);
    nothingSent();
    await devClose(t);
  });

  testWidgets('one over the limit is said and never copied', (t) async {
    final most = await appState.fileLimitFor(_amber);
    await home(t);
    await android.share(t, 'f6', [_pdf(size: most + 1)]);
    await settle(t);
    await t.tap(offered(_amber));
    await settle(t, 6);
    // said at once, before any copy
    expect(find.text(fileTooBigLine(most + 1, most)), findsOneWidget);
    expect(android.copied, isEmpty);
    expect(find.byType(ChatScreen), findsNothing);
    expect(android.dropped, ['f6']);
    await settle(t, 40);
    await devClose(t);
  });

  testWidgets('the pin comes first, and nothing of the share before it', (
    t,
  ) async {
    lockState.openForTest(enabled: true);
    lockState.lock();
    await home(t);
    await android.share(t, 'f7', [_photo()]);
    await settle(t);
    expect(find.text(l10n.toolsSendToAChat), findsNothing);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(android.seen, isEmpty);
    lockState.openForTest(enabled: true);
    lockGuard.lifted();
    await settle(t);
    expect(find.text(l10n.toolsSendToAChat), findsOneWidget);
    await letGo(t);
    await devClose(t);
  });

  testWidgets('left before the pin, the share is let go', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    lockState.openForTest(enabled: true);
    lockState.lock();
    await home(t);
    await android.share(t, 'f8', [_pdf()]);
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(t, 2);
    expect(android.dropped, ['f8']);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    lockState.openForTest(enabled: true);
    lockGuard.lifted();
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(android.copied, isEmpty);
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
    await android.share(t, 'f9', [_pdf()]);
    await settle(t);
    expect(offered(_hidden), findsOneWidget);
    await letGo(t);
    await devClose(t);

    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
    await home(t);
    await android.share(t, 'f10', [_pdf()]);
    await settle(t);
    expect(offered(_amber), findsOneWidget);
    expect(offered(_hidden), findsNothing);
    await letGo(t);
    await devClose(t);
  });

  testWidgets('a decoy offers its own chats, and nothing the everyday side '
      'was shown', (t) async {
    await home(t);
    await android.share(t, 'f11', [_pdf()]);
    await settle(t);
    expect(find.text(l10n.shareChooseChat), findsOneWidget);
    await devClose(t);
    expect(android.files?['seen'], 'everyday');

    final decoyMem = MemDb(except: {'devchat'});
    await devChatTables(decoyMem, now: 1);
    await _contact(decoyMem, _decoyOne);
    final decoy = _Db(decoyMem, HaloContainer.decoy);
    useDatabasesForTest(db, Session(decoy));
    lockState.inDecoy = true;
    await appState.refreshContacts();
    await home(t);
    expect(find.text(l10n.shareChooseChat), findsNothing);
    expect(android.dropped, ['f11']);

    await android.share(t, 'f12', [_pdf()]);
    await settle(t);
    expect(offered(_decoyOne), findsOneWidget);
    expect(offered(_amber), findsNothing);
    expect(offered(_cedar), findsNothing);
    expect(android.seen.last, 'f12:decoy');
    await letGo(t);
    await devClose(t);
  });

  testWidgets('a photo over the file limit is still copied, to be shrunk '
      'as a gallery pick is', (t) async {
    final most = await appState.fileLimitFor(_amber);
    await home(t);
    await android.share(t, 'f30', [
      {..._photo(), 'size': most + 1},
    ]);
    await settle(t);
    await t.tap(find.text(l10n.toolsSendToAChat));
    await settle(t);
    await pick(t, _amber);
    expect(android.copied, hasLength(1));
    expect(find.byType(MediaSendScreen), findsOneWidget);
    await t.tap(find.byTooltip(l10n.commonBack).last);
    await settle(t, 20);
    expect(android.allGone(), isTrue);
    await devClose(t);
  });

  test('a shared photo is copied no bigger than the shrink takes', () {
    // a bigger one would sit in memory whole, only to be refused there
    expect(kSharedPhotoMost, lessThanOrEqualTo(kConvertMost));
    final photo = PickedFile(
      uri: 'content://x/1',
      name: 'p.png',
      mime: 'image/png',
      size: 1,
    );
    expect(copyMostOf(photo, 1 << 40), kConvertMost);
  });

  testWidgets('a photo too big to read at all is said and never copied', (
    t,
  ) async {
    await home(t);
    await android.share(t, 'f31', [
      {..._photo(), 'size': kSharedPhotoMost + 1},
    ]);
    await settle(t);
    await t.tap(find.text(l10n.toolsSendToAChat));
    await settle(t);
    await t.tap(offered(_amber));
    await settle(t, 6);
    expect(
      find.text(
        l10n.sharePhotoTooBig(
          humanFileSize(kSharedPhotoMost + 1),
          humanFileSize(kSharedPhotoMost),
        ),
      ),
      findsOneWidget,
    );
    expect(android.copied, isEmpty);
    await settle(t, 40);
    await devClose(t);
  });

  testWidgets('an audio file and a text file go to a chat as files', (t) async {
    await home(t);
    await android.share(t, 'f32', [
      {
        'uri': 'content://downloads/2/song.mp3',
        'mime': 'audio/mpeg',
        'name': 'song.mp3',
        'size': 10,
      },
      {
        'uri': 'content://downloads/3/notes.txt',
        'mime': 'text/plain',
        'name': 'notes.txt',
        'size': 10,
      },
    ]);
    await settle(t);
    expect(find.text(l10n.shareCheckPhoto), findsNothing);
    await pick(t, _amber);
    // no preview: both are asked about as files
    expect(find.byType(MediaSendScreen), findsNothing);
    expect(find.text(l10n.shareSendFiles(2)), findsOneWidget);
    expect(find.text('song.mp3'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    await t.tap(find.text(l10n.commonCancel));
    // two copies to shred, a few disk turns each
    await settle(t, 60);
    nothingSent();
    expect(android.allGone(), isTrue);
    await devClose(t);
  });

  testWidgets('the developer chat is offered on the everyday side and in a '
      'decoy as its own row, never in a vault', (t) async {
    const dev = DevRow(keyId: 'k1', chatId: 'dev:k1', started: true);
    Finder devTile() => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(DevForwardTile),
    );
    appState.devRow = dev;
    await home(t);
    await android.share(t, 'f33', [_pdf()]);
    await settle(t);
    expect(devTile(), findsOneWidget);
    await letGo(t);
    await devClose(t);

    // the decoy's row is its own chat, read from its own database
    final decoyMem = MemDb(except: {'devchat'});
    await devChatTables(decoyMem, now: 1);
    await _contact(decoyMem, _decoyOne);
    useDatabasesForTest(db, Session(_Db(decoyMem, HaloContainer.decoy)));
    lockState.inDecoy = true;
    await appState.refreshContacts();
    appState.devRow = dev;
    await home(t);
    await android.share(t, 'f34', [_pdf()]);
    await settle(t);
    expect(offered(_decoyOne), findsOneWidget);
    expect(devTile(), findsOneWidget);
    await letGo(t);
    await devClose(t);
    lockState.inDecoy = false;

    final vaultMem = MemDb(except: {'devchat'});
    await devChatTables(vaultMem, now: 1);
    await _contact(vaultMem, _hidden, seen: 5);
    final vault = _Db(vaultMem, HaloContainer.vault)..holds = {_hidden};
    useDatabasesForTest(db, await Session.withVault(db, vault));
    lockState.inVault = true;
    addTearDown(() => lockState.inVault = false);
    await appState.refreshContacts();
    appState.devRow = dev;
    await home(t);
    await android.share(t, 'f35', [_pdf()]);
    await settle(t);
    expect(offered(_hidden), findsOneWidget);
    expect(find.byType(DevForwardTile), findsNothing);
    await letGo(t);
    await devClose(t);
    appState.devRow = null;
  });

  test('a photo still over the limit once shrunk stays out', () {
    final small = PickedMedia.photo(Uint8List(10));
    final big = PickedMedia.photo(Uint8List(11));
    final r = photosWithin([small, big], 10);
    expect(r.fit, [small]);
    expect(r.over, 11);
  });

  test('the kind each item goes as', () {
    expect(sharedKindOf('image/jpeg', 'x'), SharedKind.photo);
    expect(sharedKindOf('image/heic', null), SharedKind.photo);
    expect(sharedKindOf('image/svg+xml', 'a.svg'), SharedKind.file);
    expect(sharedKindOf('video/mp4', null), SharedKind.video);
    expect(sharedKindOf('application/pdf', 'a.pdf'), SharedKind.file);
    expect(sharedKindOf(null, 'clip.MOV'), SharedKind.video);
    expect(sharedKindOf('application/octet-stream', 'p.jpg'), SharedKind.photo);
    expect(sharedKindOf(null, 'a.zip'), SharedKind.file);
    expect(sharedKindOf('audio/mpeg', 'a.mp3'), SharedKind.file);
    expect(sharedKindOf('text/plain', 'a.txt'), SharedKind.file);
  });

  test('over the limit is told apart before any copy', () {
    const a = PickedFile(uri: 'content://a', size: 10);
    const b = PickedFile(uri: 'content://b', size: 11);
    const c = PickedFile(uri: 'content://c');
    final s = sortBySize([a, b, c], 10);
    expect(s.fit, [a, c]);
    expect(s.over, b);
  });

  test('a lock lets go of what waited for a chat, and only tools copies '
      'are shredded', () async {
    final dir = Directory(p.join(docs.path, 'tools_in', 'x'))
      ..createSync(recursive: true);
    final f = File(p.join(dir.path, 'p.png'))..writeAsBytesSync(_png);
    final mine = File(p.join(docs.path, 'mine.png'))..writeAsBytesSync(_png);
    lockState.openForTest(enabled: true);
    SharedInbox.handOff('everyday|$_amber', [
      SharedCopy(f.path, name: 'p.png'),
      SharedCopy(mine.path, name: 'mine.png'),
    ]);
    expect(SharedInbox.waits('everyday|$_amber'), isTrue);
    lockState.lock();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(SharedInbox.waits('everyday|$_amber'), isFalse);
    expect(dir.existsSync(), isFalse);
    expect(mine.existsSync(), isTrue);
  });
}
