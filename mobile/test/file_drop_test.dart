// SPDX-License-Identifier: GPL-3.0-or-later
// files through the files service: the frame a message carries and what it
// refuses, the word a phone says, the limit a chat gets, the group's
// tokens put in member by member, and the fetches kept until a file is in
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_drop.dart';
import 'package:kryfo/file_kind.dart' show fileFits, kMaxFileBytes;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart' show roomFrame;
import 'package:kryfo/widgets/media_bubbles.dart' show fileTooBigLine;

import 'mem_db.dart';

final _id = 'ab' * 16;
final _key = 'cd' * 32;
final _tok = 'ef' * 32;
final _sum = '12' * 32;

Map<String, Object> _wire({
  String h = kDropHost,
  String? i,
  String? k,
  int s = 100000,
  int? c,
  String? t,
  String? d,
}) => {
  'h': h,
  'i': i ?? _id,
  'k': k ?? _key,
  's': s,
  'c': c ?? dropPadChunks((s + kDropChunk - 1) ~/ kDropChunk),
  'd': d ?? _sum,
  't': ?t,
};

void main() {
  group('the frame', () {
    test('goes and comes back as it was', () {
      final f = DropFrame.fromWire(_wire(t: _tok))!;
      expect(f.size, 100000);
      expect(f.chunks, 2);
      expect(f.token, _tok);
      expect(DropFrame.fromWire(f.toWire())!.toWire(), f.toWire());
      // one with no token is no frame: nobody could say got for it
      expect(DropFrame.fromWire(_wire()), isNull);
      expect(f.sum, _sum);
    });

    test('names a host by its key only, never a url', () {
      for (final h in ['https://evil.example', 'f2', '', 'F1']) {
        expect(DropFrame.fromWire(_wire(h: h)), isNull, reason: h);
      }
    });

    test('refuses an id, key, size, count or token out of shape', () {
      final bad = [
        _wire(i: 'AB' * 16, t: _tok),
        _wire(i: '../../etc', t: _tok),
        _wire(k: 'cd' * 31, t: _tok),
        _wire(s: 0, t: _tok),
        _wire(s: kFreeFileBytes + 1, t: _tok),
        _wire(s: 100000, c: 3, t: _tok),
        _wire(s: 18 * kDropChunk, c: 19, t: _tok),
        _wire(t: 'zz' * 32),
        _wire(t: _tok, d: 'ab'),
        {..._wire(t: _tok)}..remove('d'),
      ];
      for (final w in bad) {
        expect(DropFrame.fromWire(w), isNull, reason: '$w');
      }
      expect(DropFrame.fromWire('not a map'), isNull);
    });

    test('the count is padded as the engine and the service pad it', () {
      // engine/filedrop.go and server/files/wire.go: up to 16 as they are,
      // then k * 2^e with k in 8..15
      final want = {1: 1, 16: 16, 17: 18, 31: 32, 33: 36, 100: 104, 800: 832};
      want.forEach((n, p) => expect(dropPadChunks(n), p, reason: '$n'));
      for (var n = 1; n < 3000; n++) {
        final p = dropPadChunks(n);
        expect(p >= n && dropPadChunks(p) == p, isTrue, reason: '$n');
        if (n > 16) expect(p * 8 <= n * 9, isTrue, reason: '$n');
      }
    });

    test('rides in an envelope and every envelope says the word', () async {
      final f = DropFrame.fromWire(_wire(t: _tok))!;
      final w = await wrapMessage(
        'cap',
        msgUid: 'u1',
        fileName: 'a.pdf',
        drop: f,
      );
      final env = unwrapMessage(w);
      expect(env.drop!.toWire(), f.toWire());
      expect(env.fileB64, isNull);
      expect(env.takesDrops, isTrue);
      expect(unwrapMessage(await wrapMessage('hi')).takesDrops, isTrue);
      // a version before says nothing, and only the word itself counts
      expect(unwrapMessage('halo/1:{"m":"hi","w":5}').takesDrops, isFalse);
      expect(
        unwrapMessage('halo/1:{"m":"hi","w":5,"fb":"1"}').takesDrops,
        isFalse,
      );
      expect(unwrapMessage('halo/1:{"m":"hi","bl":{"h":"x"}}').drop, isNull);
    });
  });

  group('what the engine sends back', () {
    test('a send read into the frame and each member\'s token', () {
      final r = jsonEncode({
        'id': _id,
        'key': _key,
        'size': 100000,
        'chunks': 2,
        'sum': _sum,
        'sent': false,
        'tokens': {'alice': _tok, 'bob': 'aa' * 32, 'eve': 'short'},
      });
      final s = dropSentOf(r)!;
      expect(s.frame.id, _id);
      expect(s.frame.sum, _sum);
      expect(s.sent, isFalse);
      expect(s.frameFor('alice').token, _tok);
      expect(s.frameFor('bob').token, 'aa' * 32);
      // a token out of shape is no token
      expect(s.frameFor('eve').token, isNull);
      expect(dropSentOf('error: full'), isNull);
      expect(dropSentOf('{"id":"x"}'), isNull);
    });

    test('the send job names the files host and nothing of the sender', () {
      final j =
          jsonDecode(dropSendJob(path: '/m/f', uid: 'u', members: ['a']))
              as Map;
      expect(j.keys.toSet(), {'path', 'uid', 'members', 'host'});
      expect(j['host'], kDropHost);
    });

    test('a fetch asks with its token and checks the hash; a blind one '
        'has no key', () {
      final f = DropFrame.fromWire(_wire(t: _tok))!;
      final j = jsonDecode(f.fetchJob('/m/x')) as Map;
      expect(j['token'], _tok);
      expect(j['sum'], _sum);
      expect(j['key'], _key);
      final b = jsonDecode(f.fetchJob('/m/x', blind: true)) as Map;
      expect(b['blind'], isTrue);
      expect(b.containsKey('key'), isFalse);
      expect(b['token'], _tok);
    });

    test('each member gets its own token in the one frame', () async {
      final marker = 'tok${'1' * 32}';
      final f = DropFrame.fromWire(_wire(t: _tok))!.withToken(marker);
      final w = await wrapMessage('', msgUid: 'u', drop: f);
      final a = unwrapMessage(withMemberToken(w, marker, _tok));
      expect(a.drop!.token, _tok);
      // no token, no frame: the member gets the message without it
      final none = withMemberToken(w, marker, null);
      expect(none.contains(marker), isFalse);
      expect(unwrapMessage(none).drop, isNull);
      // a token out of shape is left out, never put in
      expect(unwrapMessage(withMemberToken(w, marker, '"}')).drop, isNull);
    });
  });

  group('limits', () {
    test('50 mb to phones that fetch, 15 to the ones before', () {
      expect(fileLimit(drops: true), 50 * 1024 * 1024);
      expect(fileLimit(drops: false), 15 * 1024 * 1024);
      expect(kMaxFileBytes, kFreeFileBytes);
      expect(fileFits(30 << 20), isTrue);
      expect(fileFits(30 << 20, fileLimit(drops: false)), isFalse);
      expect(fileFits(51 << 20), isFalse);
    });

    test('one slice goes as a message, more through the service', () {
      expect(dropFits(12288), isFalse);
      expect(dropFits(12289), isTrue);
      expect(dropFits(kFreeFileBytes), isTrue);
      expect(dropFits(kFreeFileBytes + 1), isFalse);
    });

    test('a full or unreachable service falls back, a refusal does not', () {
      for (final r in [
        'error: full',
        'error: busy',
        'error: limit',
        'error: net',
      ]) {
        expect(dropFallsBack(r), isTrue, reason: r);
      }
      for (final r in ['error: big', 'error: read', 'error: cancelled', 'ok']) {
        expect(dropFallsBack(r), isFalse, reason: r);
      }
      expect(dropTryLater('error: drop full'), isTrue);
      expect(dropTryLater('error: drop busy'), isTrue);
      // past this phone's own day: a toast of its own
      expect(dropTryLater('error: drop limit'), isFalse);
      expect(dropDayDone('error: drop limit'), isTrue);
      expect(dropTryLater('error: drop read'), isFalse);
      expect(dropTryLater('error: full'), isFalse);
    });

    test('the too big line says when the chat waits on an update', () {
      final full = fileTooBigLine(60 << 20);
      final old = fileTooBigLine(20 << 20, fileLimit(drops: false));
      expect(full, isNot(contains('update')));
      expect(old, contains('updates Kryfo'));
      expect(old, contains('15'));
    });
  });

  group('fetches', () {
    late MemDb db;
    setUp(() => db = MemDb());

    Future<bool> note(String uid, String sender, {int at = 1}) => noteFetch(
      db,
      uid: uid,
      sender: sender,
      groupId: null,
      wire: 'halo/1:{}',
      backPair: false,
      size: 10,
      path: '/m/fetch/$uid',
      now: at,
    );

    test('kept once, counted per sender, due when its wait is up', () async {
      expect(await note('u1', 'wren'), isTrue);
      expect(await note('u1', 'wren'), isFalse);
      await note('u2', 'wren');
      await note('u3', 'orbit');
      expect(await fetchesFrom(db, 'wren'), 2);
      expect(await fetchesFrom(db, 'wren', except: 'u1'), 1);
      expect(await fetchesFrom(db, 'nobody'), 0);
      expect((await dueFetches(db, 5)).map((f) => f.uid), ['u1', 'u2', 'u3']);
      await fetchTried(db, 'u1', 1, 5);
      expect((await dueFetches(db, 6)).map((f) => f.uid), ['u2', 'u3']);
      expect(
        (await dueFetches(db, 5 + fetchGap(1))).map((f) => f.uid),
        contains('u1'),
      );
      await fetchState(db, 'u2', kFetchHave);
      expect((await fetchOf(db, 'u2'))!.state, kFetchHave);
      await dropFetchRow(db, 'u2');
      expect(await fetchOf(db, 'u2'), isNull);
    });

    test('the wait doubles to an hour', () {
      expect(fetchGap(0), 30000);
      expect(fetchGap(1), 60000);
      expect(fetchGap(20), 3600000);
    });

    test('a fetch lands in a folder the media sweep does not walk', () async {
      final tmp = Directory.systemTemp.createTempSync('fetch');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final a = await fetchPathIn(tmp);
      final b = await fetchPathIn(tmp);
      expect(a, isNot(b));
      expect(File(a).parent.path, '${tmp.path}/fetch');
      File(a).writeAsStringSync('x');
      File('$a.part').writeAsStringSync('x');
      File('$b.part').writeAsStringSync('x');
      File('$b.open').writeAsStringSync('x');
      final stray = await strayFetchFiles(tmp, {a});
      expect(stray.map((f) => f.path).toSet(), {'$b.part', '$b.open'});
      expect(await strayFetchFiles(Directory('${tmp.path}/none'), {}), isEmpty);
    });
  });

  group('which phones fetch', () {
    late MemDb db;
    setUp(() async {
      db = MemDb();
      await db.insert('contacts', {
        'halo_id': 'calm-orbit',
        'onion': '',
        'xpub': 'ab' * 32,
        'first_seen': 1,
        'last_seen': 1,
        'accepted': 1,
      });
      for (final m in ['me', 'a', 'b']) {
        await db.insert('group_members', {
          'group_id': 'g1',
          'halo_id': m,
          'joined_at': 1,
        });
      }
    });

    test('a contact that said so, and only while it still says so', () async {
      expect(await peerTakesDrops(db, 'calm-orbit'), isFalse);
      await takePeerDrops(
        db,
        'calm-orbit',
        carried: true,
        counts: true,
        written: 10,
      );
      expect(await peerTakesDrops(db, 'calm-orbit'), isTrue);
      await takePeerDrops(
        db,
        'calm-orbit',
        carried: false,
        counts: true,
        written: 20,
      );
      expect(await peerTakesDrops(db, 'calm-orbit'), isFalse);
    });

    test('the word is its own: opus says nothing of files', () async {
      await takePeerDrops(
        db,
        'calm-orbit',
        carried: true,
        counts: true,
        written: 10,
      );
      final r = db.rows('contacts').single;
      expect(r['files_can'], isNot(0));
      expect(r['opus_can'], 0);
    });

    test('a group only when every other member fetches', () async {
      await takeMemberDrops(
        db,
        'g1',
        'a',
        carried: true,
        counts: true,
        written: 1,
      );
      expect(await groupTakesDrops(db, 'g1', 'me'), isFalse);
      await takeMemberDrops(
        db,
        'g1',
        'b',
        carried: true,
        counts: true,
        written: 1,
      );
      expect(await groupTakesDrops(db, 'g1', 'me'), isTrue);
    });
  });

  group('this phone\'s day of big files', () {
    test('counted per day, and a new day starts again', () {
      final now = DateTime.utc(2026, 10, 28, 12);
      var d = dropDayOf(null, now);
      expect((d.bytes, d.files), (0, 0));
      final kept = dropDayAdd(d, 40 << 20);
      d = dropDayOf(kept, now);
      expect((d.bytes, d.files), (40 << 20, 1));
      expect(dropDayFits(d, kDropDayBytes - (40 << 20)), isTrue);
      expect(dropDayFits(d, kDropDayBytes - (40 << 20) + 1), isFalse);
      expect(dropDayOf(kept, now.add(const Duration(days: 1))).bytes, 0);
      expect(dropDayOf('junk', now).bytes, 0);
      final full = dropDayOf('${d.day} 0 $kDropDayFiles', now);
      expect(dropDayFits(full, 1), isFalse);
    });
  });

  group('what comes in has an end', () {
    late MemDb db;
    setUp(() => db = MemDb());

    test('a file is taken once, whatever frame names it', () async {
      expect(await fetchRefused(db, sender: 'wren', fileId: _id), isNull);
      await noteSeen(db, _id, 1000);
      expect(await fetchRefused(db, sender: 'orbit', fileId: _id), isNotNull);
      // and forgotten after the service's week
      await noteSeen(db, 'ff' * 16, 1000 + 9 * 86400000);
      expect(await fetchRefused(db, sender: 'wren', fileId: _id), isNull);
    });

    test('so many coming at once, and so many from one sender', () async {
      for (var i = 0; i < kFetchFromMost; i++) {
        await noteFetch(
          db,
          uid: 'u$i',
          sender: 'wren',
          groupId: null,
          wire: '',
          backPair: false,
          size: 1,
          path: '/p$i',
          now: 1,
        );
      }
      expect(await fetchRefused(db, sender: 'wren', fileId: _id), isNotNull);
      expect(await fetchRefused(db, sender: 'orbit', fileId: _id), isNull);
      for (var i = kFetchFromMost; i < kFetchMost; i++) {
        await noteFetch(
          db,
          uid: 'u$i',
          sender: 's$i',
          groupId: null,
          wire: '',
          backPair: false,
          size: 1,
          path: '/p$i',
          now: 1,
        );
      }
      expect(await fetchRefused(db, sender: 'orbit', fileId: _id), isNotNull);
    });
  });

  group('held while hidden chats are closed', () {
    test('a held file is found by its id, and its name says nothing', () async {
      final tmp = Directory.systemTemp.createTempSync('held');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final p = await heldPathIn(tmp, _id);
      expect(p, isNot(contains(_id)));
      expect(p, startsWith('${tmp.path}/held/'));
      expect(await heldPathIn(tmp, _id), p);
      File('$p.part').writeAsStringSync('sealed');
      final fetch = await fetchPathIn(tmp);
      expect(await takeHeld(tmp, _id, fetch), isTrue);
      expect(File('$fetch.part').readAsStringSync(), 'sealed');
      expect(await takeHeld(tmp, _id, fetch), isFalse);
      File('$p.part').writeAsStringSync('old');
      final later = DateTime.now().add(const Duration(days: 9));
      expect(await staleHeldFiles(tmp, DateTime.now()), isEmpty);
      expect(await staleHeldFiles(tmp, later), hasLength(1));
    });

    test('a frame sealed for hidden chats starts its file coming', () {
      final src = File('lib/app/state_vault.dart').readAsStringSync();
      final seal = src.substring(src.indexOf('Future<void> _sealArrival('));
      expect(seal, contains('if (drop != null) unawaited(_holdDrop(drop));'));
    });
  });

  test('a room frame says nothing of the files service', () async {
    final w = await wrapMessage('hi', msgUid: 'u');
    expect(w, contains('"fb":1'));
    final r = roomFrame(w, 'ab' * 32)!;
    expect(r, isNot(contains('"fb"')));
  });
}
