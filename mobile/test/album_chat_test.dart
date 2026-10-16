// SPDX-License-Identifier: GPL-3.0-or-later
// an album in a 1:1 chat: its rows, however they came, are one bubble in
// album order; one still on its way holds its place; the time shows once;
// and ours is taken back whole, each item unsent so a phone without albums
// drops them all. the chat's own screen over rows kept in maps
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart' show AlbumTag;
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/album_grid.dart';
import 'package:kryfo/widgets/shots_line.dart';
import 'package:kryfo/widgets/video_bubble.dart' show VideoBubble;
import 'package:kryfo/widgets/message_menu.dart' show MessageMenuCard;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-album-maker';
const _id = '00aa11bb22cc33dd';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAIAAAA7ljmRAAAAEElEQVR4nGP4Oo8bjhhwcgCFmhNpSPXr6AAAAABJRU5ErkJggg==',
);

class _Db extends DevTestDb {
  _Db(super.mem);

  final deleted = <String>[];
  final frames = <String>[];

  // the chat's screenshot block, as its row holds it
  var shots = const ChatShots();
  @override
  Future<ChatShots> shotsOf(String peer) async => shots;

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

  List<Map<String, Object?>> _thread(String peer) {
    int at(Map<String, Object?> r) => (r['written_at'] ?? r['sent_at']) as int;
    return [
      for (final r in mem.rows('messages'))
        if (r['peer_id'] == peer && r['group_id'] == null)
          {...r, 'rowid': r['id']},
    ]..sort((a, b) {
      final c = at(a).compareTo(at(b));
      return c != 0 ? c : (a['id'] as int).compareTo(b['id'] as int);
    });
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
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => beforeRowid == null ? _thread(peerId) : [];
  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [
    for (final r in _thread(peerId))
      if ((r['id'] as int) > afterRowid) r,
  ];
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
  Future<bool> isSent(String msgUid) async => _row(msgUid)?['sent'] == 1;
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: _row(msgUid)?['sent'] == 1, delivered: true);
  @override
  Future<void> deleteMessage(String msgUid) async {
    deleted.add(msgUid);
    await mem.delete('messages', where: 'msg_uid = ?', whereArgs: [msgUid]);
  }

  @override
  Future<void> queueFrame(
    String msgUid,
    String kind,
    String peerId,
    String body,
  ) async => frames.add('$kind $msgUid');
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
  final base = DateTime.now().millisecondsSinceEpoch - 3600000;

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
    useEngineForTest(_Engine());
    lockState.openForTest();
    docs = Directory.systemTemp.createTempSync('album_chat');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    _mock('halo/platform', (_) async => null);
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
    _mock('halo/platform', null);
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

  // one item of an album, [i] of [n], written in its order
  Future<void> item(
    int i,
    int n, {
    String dir = 'in',
    String caption = '',
    String id = _id,
    bool secure = false,
    bool sent = true,
    bool delivered = true,
  }) async {
    final f = File('${docs.path}/p_$id$i.png')..writeAsBytesSync(_png);
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': dir,
      'plaintext': caption,
      'sent_at': base + 60000 + i * 1000,
      'written_at': base + 60000 + i * 1000,
      'msg_uid': '$dir-$id-$i',
      'media_path': f.path,
      'sent': sent ? 1 : 0,
      'delivered': delivered ? 1 : 0,
      'secure': secure ? 1 : 0,
      ...AlbumTag(id, n, i).toRow(),
    });
  }

  Future<void> text(String uid, String words, int at) =>
      mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': words,
        'sent_at': at,
        'written_at': at,
        'msg_uid': uid,
        'sent': 1,
      });

  Widget chat() => const ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub:
        'abababababababababababababababababababababababababababababababab',
    avatarSeed: _peer,
  );

  Finder tile(int slot) => find.descendant(
    of: find.byType(AlbumGrid),
    matching: find.byKey(ValueKey(slot)),
  );

  testWidgets('rows that came out of order are one album in its order', (
    t,
  ) async {
    await text('t0', 'before', base);
    // they land three, one, two
    await item(2, 3);
    await item(0, 3, caption: 'our trip');
    await item(1, 3);
    await text('t1', 'after', base + 600000);
    await devOpen(t, chat());
    await settle(t);
    expect(find.byType(AlbumGrid), findsOneWidget);
    final grid = t.widget<AlbumGrid>(find.byType(AlbumGrid));
    expect(
      [for (final x in grid.tiles) x!.path!.split('_').last],
      ['${_id}0.png', '${_id}1.png', '${_id}2.png'],
    );
    // the caption of the first, once, under the album
    expect(find.text('our trip', findRichText: true), findsOneWidget);
    // and between what came before and after it
    final y = t.getCenter(find.byType(AlbumGrid)).dy;
    expect(
      t.getCenter(find.text('before', findRichText: true)).dy,
      lessThan(y),
    );
    expect(
      t.getCenter(find.text('after', findRichText: true)).dy,
      greaterThan(y),
    );
    await devClose(t);
  });

  testWidgets('one still on its way holds its place', (t) async {
    await item(0, 4);
    await item(3, 4);
    await devOpen(t, chat());
    await settle(t);
    final grid = t.widget<AlbumGrid>(find.byType(AlbumGrid));
    expect(grid.tiles.map((x) => x != null), [true, false, false, true]);
    expect(
      find.descendant(
        of: find.byType(AlbumGrid),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNWidgets(2),
    );
    final size = t.getSize(find.byType(AlbumGrid));
    // the rest lands: the same grid, the same size
    await item(1, 4);
    await item(2, 4);
    appState.chatChanged(_peer);
    await settle(t);
    expect(find.byType(AlbumGrid), findsOneWidget);
    expect(t.getSize(find.byType(AlbumGrid)), size);
    expect(
      t.widget<AlbumGrid>(find.byType(AlbumGrid)).tiles.every((x) => x != null),
      isTrue,
    );
    await devClose(t);
  });

  testWidgets('the time shows once for the album', (t) async {
    for (var i = 0; i < 3; i++) {
      await item(i, 3, dir: 'out');
    }
    await devOpen(t, chat());
    await settle(t);
    final grid = t.widget<AlbumGrid>(find.byType(AlbumGrid));
    expect(grid.stamp, isNotNull);
    expect(
      find.descendant(
        of: find.byType(AlbumGrid),
        matching: find.byKey(const ValueKey('stamp')),
      ),
      findsOneWidget,
    );
    await devClose(t);
  });

  testWidgets('ours is taken back whole', (t) async {
    await text('t0', 'keep me', base);
    for (var i = 0; i < 3; i++) {
      await item(i, 3, dir: 'out');
    }
    await devOpen(t, chat());
    await settle(t);
    await t.longPress(tile(1));
    await settle(t, 4);
    await t.tap(find.text(l10n.chatUnsend).last);
    await settle(t, 4);
    // the sheet asks once, for the album
    expect(find.text(l10n.albumUnsendTitle), findsOneWidget);
    await t.tap(find.text(l10n.chatUnsend).last);
    await settle(t, 12);
    final uids = ['out-$_id-0', 'out-$_id-1', 'out-$_id-2'];
    expect(db.deleted, uids);
    expect(db.frames, [for (final u in uids) 'unsend $u']);
    expect(find.byType(AlbumGrid), findsNothing);
    expect(find.text('keep me', findRichText: true), findsOneWidget);
    await devClose(t);
  });

  testWidgets('theirs offers no unsend', (t) async {
    for (var i = 0; i < 2; i++) {
      await item(i, 2);
    }
    await devOpen(t, chat());
    await settle(t);
    await t.longPress(tile(0));
    await settle(t, 4);
    // the menu is up, with no way to take back what they sent
    expect(find.text(l10n.commonSave), findsOneWidget);
    final unsend = find.text(l10n.chatUnsend);
    if (unsend.evaluate().isNotEmpty) {
      await t.tap(unsend.last, warnIfMissed: false);
      await settle(t, 4);
    }
    expect(find.text(l10n.albumUnsendTitle), findsNothing);
    expect(db.deleted, isEmpty);
    await devClose(t);
  });

  // the actions the open menu offers, by label
  List<String> offered(WidgetTester t) => [
    for (final a
        in t.widget<MessageMenuCard>(find.byType(MessageMenuCard)).actions)
      if (a.onTap != null) a.label,
  ];

  testWidgets('theirs, sent protected, is neither saved nor shared', (t) async {
    for (var i = 0; i < 2; i++) {
      await item(i, 2, secure: true);
    }
    await devOpen(t, chat());
    await settle(t);
    await t.longPress(tile(0));
    await settle(t, 4);
    // the menu is up, with what it may offer and nothing that lets it out
    expect(offered(t), contains(l10n.chatPin));
    expect(offered(t), isNot(contains(l10n.commonSave)));
    expect(offered(t), isNot(contains(l10n.commonShare)));
    await devClose(t);
  });

  testWidgets('a video of theirs sent protected is not shared either', (
    t,
  ) async {
    for (final (uid, secure) in [('v-kept', true), ('v-open', false)]) {
      final f = File('${docs.path}/$uid.mp4')..writeAsBytesSync([0, 0, 0, 8]);
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': '',
        'sent_at': base + (secure ? 1000 : 2000),
        'written_at': base + (secure ? 1000 : 2000),
        'msg_uid': uid,
        'file_path': f.path,
        'file_name': 'video_$uid.mp4',
        'sent': 1,
        'secure': secure ? 1 : 0,
      });
    }
    await devOpen(t, chat());
    await settle(t);
    final videos = find.byType(VideoBubble);
    expect(videos, findsNWidgets(2));
    Finder video(String uid) => find.byWidgetPredicate(
      (w) => w is VideoBubble && w.path.endsWith('$uid.mp4'),
    );
    await t.longPress(video('v-kept'));
    await settle(t, 4);
    expect(offered(t), isNot(contains(l10n.commonShare)));
    expect(offered(t), isNot(contains(l10n.commonSave)));
    await t.tapAt(const Offset(4, 300));
    await settle(t, 4);
    await t.longPress(video('v-open'));
    await settle(t, 4);
    expect(offered(t), contains(l10n.commonShare));
    await devClose(t);
  });

  testWidgets('a caption on a later item is the album\'s', (t) async {
    await item(0, 3);
    await item(1, 3);
    await item(2, 3, caption: 'all three');
    await devOpen(t, chat());
    await settle(t);
    expect(find.byType(AlbumGrid), findsOneWidget);
    expect(find.text('all three', findRichText: true), findsOneWidget);
    await devClose(t);
  });

  testWidgets('with its first places missing, what came is drawn and '
      'opens', (t) async {
    await item(2, 4);
    await item(3, 4);
    await devOpen(t, chat());
    await settle(t);
    final grid = t.widget<AlbumGrid>(find.byType(AlbumGrid));
    expect(grid.tiles, hasLength(2));
    expect(grid.tiles.every((x) => x?.path != null), isTrue);
    await devClose(t);
  });

  // the line saying who changed the screenshot block last, as drawn
  ChatShots changed(int when) =>
      ChatShots(can: 10, by: kShotsByThem, when: when, known: true);

  testWidgets('the screenshot line changed right after an album is drawn '
      'under it', (t) async {
    await text('t0', 'before', base);
    for (var i = 0; i < 3; i++) {
      await item(i, 3);
    }
    db.shots = changed(base + 600000);
    await devOpen(t, chat());
    await settle(t);
    expect(find.byType(AlbumGrid), findsOneWidget);
    expect(find.byType(ShotsLine), findsOneWidget);
    expect(
      t.getCenter(find.byType(ShotsLine)).dy,
      greaterThan(t.getCenter(find.byType(AlbumGrid)).dy),
    );
    await devClose(t);
  });

  testWidgets('the screenshot line changed between an album\'s items goes '
      'with the album, once', (t) async {
    await text('t0', 'before', base);
    for (var i = 0; i < 3; i++) {
      await item(i, 3);
    }
    await text('t1', 'after', base + 600000);
    // after the second item was written, before the third
    db.shots = changed(base + 60000 + 1500);
    await devOpen(t, chat());
    await settle(t);
    expect(find.byType(AlbumGrid), findsOneWidget);
    expect(find.byType(ShotsLine), findsOneWidget);
    final y = t.getCenter(find.byType(ShotsLine)).dy;
    expect(
      y,
      greaterThan(t.getCenter(find.text('before', findRichText: true)).dy),
    );
    expect(y, lessThan(t.getCenter(find.byType(AlbumGrid)).dy));
    expect(y, lessThan(t.getCenter(find.text('after', findRichText: true)).dy));
    await devClose(t);
  });
}
