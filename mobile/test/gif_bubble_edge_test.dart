// SPDX-License-Identifier: GPL-3.0-or-later
// a gif in a chat sits where a photo would: ours flush with our other
// bubbles' edge, theirs flush with theirs, the picture filling its rounded
// clip, landscape, portrait or square, with a reply or a reaction, in 1:1
// chats and groups, left to right and right to left
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/gifs/gif_picture.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/burn_fade.dart' show BurnFade;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-slow-river';
const _group = 'g1';
const _anna = 'thumb-behave-boring';

// a one-frame gif of [w] by [h] in two colours, banded so a crop shows.
// a clear code before every second pixel keeps every code three bits
Uint8List gifOf(int w, int h, {int a = 0xd97706, int b = 0x7c3aed}) {
  final out = BytesBuilder();
  void u16(int v) => out.add([v & 0xff, v >> 8]);
  out.add('GIF89a'.codeUnits);
  u16(w);
  u16(h);
  out.add([0x80, 0, 0]);
  for (final c in [a, b]) {
    out.add([(c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff]);
  }
  out.addByte(0x2c);
  u16(0);
  u16(0);
  u16(w);
  u16(h);
  out.add([0, 2]);
  final bytes = <int>[];
  var acc = 0, bits = 0;
  void code(int c) {
    acc |= c << bits;
    bits += 3;
    while (bits >= 8) {
      bytes.add(acc & 0xff);
      acc >>= 8;
      bits -= 8;
    }
  }

  for (var i = 0; i < w * h; i++) {
    if (i.isEven) code(4);
    final y = i ~/ w, x = i % w;
    code(((x ~/ 20) + (y ~/ 20)).isEven ? 0 : 1);
  }
  code(5);
  if (bits > 0) bytes.add(acc & 0xff);
  for (var i = 0; i < bytes.length; i += 255) {
    final end = i + 255 < bytes.length ? i + 255 : bytes.length;
    out.addByte(end - i);
    out.add(bytes.sublist(i, end));
  }
  out.add([0, 0x3b]);
  return out.toBytes();
}

class _Db extends DevTestDb {
  _Db(super.mem);

  final reactions = <String, List<MapEntry<String, String>>>{};
  String? atmosphere;

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
  Future<bool> isMuted(String haloId) async => false;
  @override
  Future<bool> isVerified(String haloId) async => false;
  @override
  Future<bool> keyChanged(String haloId) async => false;
  @override
  Future<String?> getAtmosphere(String peerId) async => atmosphere;
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
  }) async => _thread(peerId);
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
  ) async => {
    for (final u in msgUids)
      if (reactions[u] case final r?) u: List.of(r),
  };
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
}

// one group, its rows as given
class _GroupDb implements HaloDb {
  _GroupDb(this.rows);
  final List<Map<String, Object?>> rows;
  final reactions = <String, List<MapEntry<String, String>>>{};

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Friends',
    'is_admin': 1,
  };
  @override
  Future<bool> groupExists(String groupId) async => true;
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['me', _anna];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => [...rows];
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
  ) async => {
    for (final u in msgUids)
      if (reactions[u] case final r?) u: List.of(r),
  };
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
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: true, delivered: true);
  @override
  Future<Map<String, Object?>?> getContact(String haloId) async => {
    'halo_id': haloId,
    'nickname': haloId == _anna ? 'Anna' : null,
    'xpub': 'ab' * 32,
    'accepted': 1,
  };
  @override
  Future<bool> isVerified(String haloId) async => false;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

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

// the gifs a chat shows, by name: ours, and one of theirs
const shapes = {
  'wide': (200, 112),
  'tall': (200, 356),
  'square': (200, 200),
  'theirs': (200, 150),
};

// files are read and decoded outside the test's clock
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 15; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder pictureOf(String path) =>
    find.byWidgetPredicate((w) => w is ChatPicture && w.path == path);

Rect rectOf(WidgetTester t, Finder f) {
  final box = t.renderObject<RenderBox>(f);
  return box.localToGlobal(Offset.zero) & box.size;
}

// what the eye sees of a gif: the frame drawn, and the clip around it
({Rect drawn, Rect clip, BorderRadiusGeometry radius}) gifOn(
  WidgetTester t,
  String path,
) {
  final pic = pictureOf(path);
  expect(pic, findsOneWidget, reason: path);
  final raw = find.descendant(of: pic, matching: find.byType(RawImage)).first;
  // decoded, so the frame has its own size to keep
  expect(t.widget<RawImage>(raw).image, isNotNull, reason: path);
  expect(find.descendant(of: pic, matching: find.byType(GifBadge)), findsOne);
  final drawn = rectOf(t, raw);
  final clipF = find.ancestor(of: pic, matching: find.byType(ClipRRect)).first;
  return (
    drawn: drawn,
    clip: rectOf(t, clipF),
    radius: t.widget<ClipRRect>(clipF).borderRadius,
  );
}

void expectRect(Rect a, Rect b, String why) {
  for (final (x, y, side) in [
    (a.left, b.left, 'left'),
    (a.top, b.top, 'top'),
    (a.right, b.right, 'right'),
    (a.bottom, b.bottom, 'bottom'),
  ]) {
    expect(x, closeTo(y, 0.5), reason: '$why: $side');
  }
}

void main() {
  late Directory tmp;
  final paths = <String, String>{};

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    lockState.openForTest();
    tmp = Directory.systemTemp.createTempSync('gif_edge');
    _mock('plugins.flutter.io/path_provider', (_) async => tmp.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    for (final MapEntry(key: name, value: (w, h)) in shapes.entries) {
      // saved as a photo is, under a picture name
      final f = File('${tmp.path}/$name.jpg')..writeAsBytesSync(gifOf(w, h));
      paths[name] = f.path;
    }
  });

  tearDown(() {
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    tmp.deleteSync(recursive: true);
  });

  group('a 1:1 chat', () {
    Future<_Db> world() async {
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
      final now = DateTime.now().millisecondsSinceEpoch;
      var at = now - 900000;
      Future<void> row(Map<String, Object?> r) => mem.insert('messages', {
        'peer_id': _peer,
        'sent_at': at += 1000,
        ...r,
      });
      await row({
        'direction': 'in',
        'plaintext': 'look at this',
        'msg_uid': 'u-quoted',
      });
      await row({
        'direction': 'in',
        'plaintext': 'are you there',
        'msg_uid': 'u-in',
      });
      await row({
        'direction': 'in',
        'plaintext': '',
        'msg_uid': 'u-theirs',
        'media_path': paths['theirs'],
      });
      await row({
        'direction': 'out',
        'plaintext': 'on my way',
        'msg_uid': 'u-out',
        'sent': 1,
        'delivered': 1,
      });
      for (final name in ['wide', 'tall', 'square']) {
        await row({
          'direction': 'out',
          'plaintext': '',
          'msg_uid': 'u-$name',
          'media_path': paths[name],
          'sent': 1,
          'delivered': 1,
          if (name == 'square') 'reply_to': 'u-quoted',
        });
      }
      await row({
        'direction': 'out',
        'plaintext': 'see you',
        'msg_uid': 'u-last',
        'sent': 1,
        'delivered': 1,
      });
      final db = _Db(mem);
      db.reactions['u-wide'] = [const MapEntry(_peer, '❤️')];
      db.reactions['u-theirs'] = [const MapEntry('', '😂')];
      useDatabasesForTest(db, Session(db));
      await appState.refreshContacts();
      return db;
    }

    Widget chat() => const ChatScreen(
      peerHaloId: _peer,
      peerOnion: '',
      peerXPub:
          'abababababababababababababababababababababababababababababababab',
      avatarSeed: _peer,
    );

    for (final (locale, rtl) in [
      (const Locale('en'), false),
      (const Locale('ar'), true),
      (const Locale('fa'), true),
    ]) {
      for (final still in [false, true]) {
        testWidgets('our gifs meet our edge, theirs theirs, '
            '${locale.languageCode}${still ? ', still' : ''}', (t) async {
          await world();
          for (final p in paths.values) {
            await t.runAsync(() => isGifFile(p));
          }
          await devOpen(
            t,
            chat(),
            still: still,
            locale: locale,
            size: const Size(720, 3600),
          );
          await settle(t);
          final ours = rectOf(
            t,
            find
                .ancestor(
                  of: find.textContaining('on my way', findRichText: true),
                  matching: find.byType(BurnFade),
                )
                .first,
          );
          final theirs = rectOf(
            t,
            find
                .ancestor(
                  of: find.textContaining('are you there', findRichText: true),
                  matching: find.byType(BurnFade),
                )
                .first,
          );
          for (final name in shapes.keys) {
            final g = gifOn(t, paths[name]!);
            final mine = name != 'theirs';
            final edge = mine ? ours : theirs;
            // ours ends where our bubbles end: the right, or the left in rtl
            if (mine != rtl) {
              expect(g.drawn.right, closeTo(edge.right, 0.5), reason: name);
            } else {
              expect(g.drawn.left, closeTo(edge.left, 0.5), reason: name);
            }
            // the frame fills its clip, so every corner is the rounded one
            expectRect(g.drawn, g.clip, name);
            final r = g.radius.resolve(
              rtl ? TextDirection.rtl : TextDirection.ltr,
            );
            for (final c in [
              r.topLeft,
              r.topRight,
              r.bottomLeft,
              r.bottomRight,
            ]) {
              expect(c.x, greaterThan(0), reason: '$name corner');
            }
            // as wide as a photo there
            expect(g.drawn.width, closeTo(360 * 0.78, 0.5), reason: name);
          }
          // no line under a gif of ours
          expect(find.text('Sent inside your message'), findsNothing);
          await devClose(t);
        });
      }
    }
  });

  group('a group', () {
    Map<String, Object?> row(
      int rowid,
      String dir,
      String text, {
      String? media,
      String? reply,
    }) => {
      'rowid': rowid,
      'id': rowid,
      'peer_id': dir == 'out' ? 'me' : _anna,
      'group_id': _group,
      'direction': dir,
      'plaintext': text,
      'msg_uid': 'uid-$rowid',
      'sent': 1,
      'media_path': ?media,
      'reply_to': ?reply,
      'sent_at': DateTime.now()
          .subtract(Duration(minutes: 30 - rowid))
          .millisecondsSinceEpoch,
    };

    for (final (locale, rtl) in [
      (const Locale('en'), false),
      (const Locale('ar'), true),
    ]) {
      testWidgets('our gifs meet our edge, theirs theirs, '
          '${locale.languageCode}', (t) async {
        final db = _GroupDb([
          row(1, 'in', 'look at this'),
          row(2, 'in', 'are you there'),
          row(3, 'in', '', media: paths['theirs']),
          row(4, 'out', 'on my way'),
          row(5, 'out', '', media: paths['wide']),
          row(6, 'out', '', media: paths['tall']),
          row(7, 'out', '', media: paths['square'], reply: 'uid-1'),
          row(8, 'out', 'see you'),
        ]);
        db.reactions['uid-5'] = [const MapEntry(_anna, '❤️')];
        useDatabasesForTest(db, Session(db));
        appState.setRouteOKForTest(true);
        appState.setTorStatusForTest(TorStatus.reachable);
        addTearDown(() => appState.setTorStatusForTest(TorStatus.off));
        for (final p in paths.values) {
          await t.runAsync(() => isGifFile(p));
        }
        await devOpen(
          t,
          const GroupChatScreen(groupId: _group),
          locale: locale,
          size: const Size(720, 3600),
        );
        await settle(t);
        Rect bubble(String text) => rectOf(
          t,
          find
              .ancestor(
                of: find.textContaining(text, findRichText: true),
                matching: find.byType(Container),
              )
              .first,
        );
        final ours = bubble('on my way');
        final theirs = bubble('are you there');
        for (final name in shapes.keys) {
          final g = gifOn(t, paths[name]!);
          final mine = name != 'theirs';
          final edge = mine ? ours : theirs;
          if (mine != rtl) {
            expect(g.drawn.right, closeTo(edge.right, 0.5), reason: name);
          } else {
            expect(g.drawn.left, closeTo(edge.left, 0.5), reason: name);
          }
          expectRect(g.drawn, g.clip, name);
        }
        expect(find.text(l10n.gifSentInside), findsNothing);
        await devClose(t);
      });
    }
  });
}
