// SPDX-License-Identifier: GPL-3.0-or-later
// a chat shows its messages in the order they were written, whatever order
// they came in. theirs carry the sender's time, held to what can be true:
// a clock far ahead or far back cannot keep a message under every later
// one, or above the whole chat. pages, the newest row and a reload from a
// row held all follow that order. the database runs on the host's sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, HaloDb, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'sqlite_channel.dart';

const _alice = 'amber-otter-lake';
const _bob = 'brisk-cedar-moon';
const _gid = 'g0a1b2c3d4e5f60718293a4b5c6d7e8f9';
const _min = 60000;
const _day = 86400000;

List<String?> _uids(List<Map<String, Object?>> rows) => [
  for (final r in rows) r['msg_uid'] as String?,
];

// what came in, in the order the chat places it: by the time stored, then
// as it came
List<String?> _placed(List<Map<String, Object?>> rows) {
  final at = [
    for (final (i, r) in rows.indexed) (r['written_at'] as int? ?? 0, i, r),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2 - b.$2);
  return [for (final (_, _, r) in at) r['msg_uid'] as String?];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('msg_order');
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    m.setMockMethodCallHandler(paths, null);
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  group('on the phone', () {
    late _World w;
    setUp(() async => w = await _World.make());

    test('messages that came out of order are placed by when they were '
        'written', () async {
      final t0 = DateTime.now().millisecondsSinceEpoch - 60 * _min;
      // sent one, two, three; the relays hand them over three, one, two
      for (final (uid, at) in [
        ('m3', t0 + 3 * _min),
        ('m1', t0 + _min),
        ('m2', t0 + 2 * _min),
      ]) {
        await w.from(_alice, uid, written: at);
      }
      expect(_uids(w.live.msgs), ['m3', 'm1', 'm2']);
      expect(_placed(w.live.msgs), ['m1', 'm2', 'm3']);
      expect(w.live.msg('m1')!['written_at'], t0 + _min);
    });

    test('a clock far ahead is held to when it came, one far back to the '
        'first contact less the time relays keep a message', () async {
      final first = DateTime.now().millisecondsSinceEpoch - 30 * _day;
      w.live.people[_alice]!['first_seen'] = first;
      final before = DateTime.now().millisecondsSinceEpoch;
      await w.from(_alice, 'ahead', written: before + 365 * _day);
      await w.from(_alice, 'back', written: 1000);
      final after = DateTime.now().millisecondsSinceEpoch;
      // pinned under every later message for a year: held to a minute
      expect(
        w.live.msg('ahead')!['written_at'],
        inInclusiveRange(before + _min, after + _min),
      );
      // above the whole chat since 1970: held to the chat's start
      expect(w.live.msg('back')!['written_at'], first - 14 * _day);
      // a later message still goes under the one from far ahead within
      // the minute, and over the one from far back
      await w.from(_alice, 'next', written: after + 2 * _min);
      expect(_placed(w.live.msgs), ['back', 'ahead', 'next']);
    });
  });

  group('the database', () {
    SqliteChannel? sql;
    late HaloDb db;

    setUp(() async {
      sql = SqliteChannel.install();
      db = HaloDb();
    });

    tearDown(() async {
      if (sql == null) return;
      await db.close();
      sql!.uninstall();
    });

    bool skip() {
      if (sql != null) return false;
      markTestSkipped('no sqlite on this host');
      return true;
    }

    Future<void> came(
      String uid,
      int written, {
      String dir = 'in',
      String peer = _alice,
      String? group,
    }) => db.saveMessage(
      peer,
      dir,
      'text $uid',
      msgUid: uid,
      groupId: group,
      sentAt: dir == 'out' ? written : null,
      writtenAt: dir == 'out' ? null : written,
    );

    test('a chat reads in the order its messages were written, not as they '
        'came', () async {
      if (skip()) return;
      await db.upsertContact(_alice, 'a.onion', 'ab' * 32);
      final t0 = DateTime.now().millisecondsSinceEpoch - 60 * _min;
      await came('c', t0 + 3 * _min);
      await came('a', t0 + _min);
      await came('mine', t0 + 150000, dir: 'out');
      await came('b', t0 + 2 * _min);
      const order = ['a', 'b', 'mine', 'c'];
      expect(_uids(await db.messagesFor(_alice)), order);
      expect(_uids(await db.messagesPage(_alice)), order);
      expect(_uids(await db.messagesPage(_alice, limit: 2)), ['mine', 'c']);
      // the home list shows the newest written, at its own time
      final last = (await db.lastMessages())[_alice]!;
      expect(last['plaintext'], 'text c');
      expect(last['written_at'], t0 + 3 * _min);
      expect(await db.firstMessageAt(_alice), t0 + _min);
    });

    test('pages meet with no gap and no repeat, across rows that share a '
        'time', () async {
      if (skip()) return;
      await db.upsertContact(_alice, 'a.onion', 'ab' * 32);
      await db.upsertContact(_bob, 'b.onion', 'cd' * 32);
      final t0 = DateTime.now().millisecondsSinceEpoch - _day;
      // written times out of the order they came, three of them shared
      const at = [9, 2, 7, 7, 1, 12, 3, 7, 0, 11, 5, 4, 10, 6, 8];
      for (final (i, k) in at.indexed) {
        await came('p$i', t0 + k * _min);
        await came('g$i', t0 + k * _min, peer: _bob, group: _gid);
      }
      for (final (chat, all) in [
        ('1:1', await db.messagesFor(_alice)),
        ('group', await db.loadGroupMessages(_gid)),
      ]) {
        Future<List<Map<String, Object?>>> page(Map<String, Object?>? top) =>
            chat == '1:1'
            ? db.messagesPage(
                _alice,
                beforeRowid: top?['rowid'] as int?,
                beforeAt: top?['written_at'] as int?,
                limit: 4,
              )
            : db.groupMessagesPage(
                _gid,
                beforeRowid: top?['rowid'] as int?,
                beforeAt: top?['written_at'] as int?,
                limit: 4,
              );
        expect(all, hasLength(at.length), reason: chat);
        // each written time no earlier than the one before, ties as they came
        for (var i = 1; i < all.length; i++) {
          final a = all[i - 1], b = all[i];
          expect(
            (a['written_at'] as int) < (b['written_at'] as int) ||
                (a['written_at'] == b['written_at'] &&
                    (a['rowid'] as int) < (b['rowid'] as int)),
            isTrue,
            reason: '$chat at $i',
          );
        }
        // scrolled up page by page from the newest
        final seen = <Map<String, Object?>>[];
        var p = await page(null);
        while (p.isNotEmpty) {
          seen.insertAll(0, p);
          p = await page(p.first);
        }
        expect(_uids(seen), _uids(all), reason: chat);
      }
      // a page asked by its row alone finds that row's time itself
      final all = await db.messagesFor(_alice);
      final mid = all[7];
      expect(
        _uids(await db.messagesPage(_alice, beforeRowid: mid['rowid'] as int)),
        _uids(all.sublist(0, 7)),
      );
      // a reload from a row held brings that row and all after it
      expect(
        _uids(
          await db.messagesFrom(
            _alice,
            rowid: mid['rowid'] as int,
            at: mid['written_at'] as int,
          ),
        ),
        _uids(all.sublist(7)),
      );
    });

    test(
      'a row stored with no time of its own is placed when it came',
      () async {
        if (skip()) return;
        await db.upsertContact(_alice, 'a.onion', 'ab' * 32);
        final raw = await db.open();
        await raw.insert('messages', {
          'peer_id': _alice,
          'direction': 'in',
          'plaintext': 'bare',
          'sent_at': 1234,
          'msg_uid': 'bare',
        });
        final r = await raw.query('messages', where: "msg_uid = 'bare'");
        expect(r.single['written_at'], 1234);
      },
    );
  });
}

// the receive path over stand-ins for the database, signal and the engine
class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_alice, onion: 'o-$_alice', xpub: 'x-$_alice');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<void> from(String who, String uid, {required int written}) async {
    final c = 'c${_n++}';
    io.opens[c] = (
      who,
      await wrapMessage(
        'text $uid',
        msgUid: uid,
        sender: asSender(who),
        writtenAt: written,
      ),
    );
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
