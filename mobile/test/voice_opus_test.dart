// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes in opus: the names both shapes go by, the length read from
// an ogg's last page, the word that says a phone plays opus, the wav that
// still goes to a phone that has not said so, and the encode's fallback.
// fixtures/voice/note.ogg is 3.4 s the engine's encoder wrote
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/search.dart';
import 'package:kryfo/voice_format.dart';
import 'package:kryfo/voice_length.dart';
import 'package:kryfo/voice_opus.dart';
import 'package:kryfo/widgets/voice_parts.dart';

import 'package:kryfo/main.dart' show opusColumns;

import 'mem_db.dart';
import 'real_sqlite.dart';

final _note = File('test/fixtures/voice/note.ogg').readAsBytesSync();

Uint8List _wav(int frames) {
  final b = ByteData(44 + frames * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + frames * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 16000, Endian.little);
  b.setUint32(28, 32000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, frames * 2, Endian.little);
  return b.buffer.asUint8List();
}

int _lastPage(Uint8List b) {
  for (var at = b.length - 4; at >= 0; at--) {
    if (String.fromCharCodes(b.sublist(at, at + 4)) == 'OggS') return at;
  }
  return -1;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('voice_opus'));
  tearDown(() {
    voiceOggForTest = null;
    voicePeaksForTest = null;
    tmp.deleteSync(recursive: true);
  });

  group('names', () {
    test('a voice note goes by either name, and nothing else is one', () {
      expect(isVoiceName('voice.wav'), isTrue);
      expect(isVoiceName('voice.ogg'), isTrue);
      for (final n in [null, '', 'voice.opus', 'Voice.wav', 'song.ogg']) {
        expect(isVoiceName(n), isFalse, reason: '$n');
      }
    });

    test('the opus copy sits beside the wav', () {
      expect(oggPathOf('/m/vn_u1.wav'), '/m/vn_u1.ogg');
      expect(oggPathOf('/m/vn_u1.WAV'), '/m/vn_u1.ogg');
      expect(oggPathOf('/m/vn_u1'), '/m/vn_u1.ogg');
      expect(isOggPath('/m/vn_u1.ogg'), isTrue);
      expect(isOggPath('/m/vn_u1.wav'), isFalse);
    });

    test('search finds neither shape among files', () {
      final w = kindWhere(SearchKind.files);
      expect(w, contains("NOT IN ('voice.wav', 'voice.ogg')"));
      expect(searchBody({'plaintext': '', 'file_name': 'voice.ogg'}), '');
      expect(searchBody({'plaintext': '', 'file_name': 'voice.wav'}), '');
    });
  });

  group('length', () {
    test('an ogg plays from its pre-skip to its last granule', () {
      final tail = _note.sublist(_note.length - 4096);
      expect(oggOpusMs(_note.sublist(0, 4096), tail), 3400);
      expect(oggOpusMs(_note, _note), 3400);
    });

    test('a file read from its ends, either shape', () async {
      final ogg = File('${tmp.path}/vn_1.ogg')..writeAsBytesSync(_note);
      final wav = File('${tmp.path}/vn_1.wav')..writeAsBytesSync(_wav(16000));
      expect(await oggFileMs(ogg.path), 3400);
      expect(await voiceFileMs(ogg.path), 3400);
      expect(await voiceFileMs(wav.path), 1000);
      expect(await voiceFileMs('${tmp.path}/none.ogg'), isNull);
    });

    test('a last page that claims hours shows at most the mic\'s length', () {
      final b = Uint8List.fromList(_note);
      final last = _lastPage(b);
      ByteData.sublistView(b).setUint32(last + 6, 0xF0000000, Endian.little);
      expect(oggOpusMs(b, b), kOggLongestMs);
      expect(kOggLongestMs, 31 * 60 * 1000);
    });

    test('what is no whole ogg opus has no length', () {
      expect(oggOpusMs(_wav(160), _wav(160)), isNull);
      expect(oggOpusMs(Uint8List(0), Uint8List(0)), isNull);
      // cut inside its last page
      final cut = _note.sublist(0, _note.length - 7);
      expect(oggOpusMs(cut, cut), isNull);
      // an ogg of something else
      final other = Uint8List.fromList(_note);
      other.setRange(28, 36, 'OpusTags'.codeUnits);
      expect(oggOpusMs(other, other), isNull);
    });
  });

  group('the word on the wire', () {
    test('every envelope says this phone plays opus', () async {
      final w = await wrapMessage('hi', msgUid: 'u1');
      expect(w, contains('"op":1'));
      expect(unwrapMessage(w).playsOpus, isTrue);
      final ctl = await wrapMessage('', deliveredUid: 'u1');
      expect(unwrapMessage(ctl).playsOpus, isTrue);
    });

    test('an envelope from 0.5 says nothing of it', () {
      final old = unwrapMessage('halo/1:{"m":"hi","w":5,"u":"u1"}');
      expect(old.playsOpus, isFalse);
      expect(unwrapMessage('plain words').playsOpus, isFalse);
      // only the word itself counts
      expect(
        unwrapMessage('halo/1:{"m":"hi","w":5,"op":"1"}').playsOpus,
        isFalse,
      );
    });
  });

  group('which phones are sent opus', () {
    late MemDb db;
    setUp(() async {
      db = MemDb();
      for (final (id, accepted) in [('calm-orbit', 1), ('a-request', 0)]) {
        await db.insert('contacts', {
          'halo_id': id,
          'onion': '',
          'xpub': 'ab' * 32,
          'first_seen': 1,
          'last_seen': 1,
          'accepted': accepted,
        });
      }
      for (final m in ['me', 'a', 'b', 'c']) {
        await db.insert('group_members', {
          'group_id': 'g1',
          'halo_id': m,
          'joined_at': 1,
        });
      }
    });

    Future<bool> came(
      String peer, {
      required bool op,
      int? at,
      bool msg = true,
    }) => takePeerOpus(db, peer, carried: op, counts: msg, written: at);

    Future<bool> inGroup(String m, {required bool op, int? at}) =>
        takeMemberOpus(db, 'g1', m, carried: op, counts: true, written: at);

    int? col(String table, String id) {
      for (final r in db.rows(table)) {
        if (r['halo_id'] == id) return (r['opus_can'] as num?)?.toInt();
      }
      return null;
    }

    test('none known is wav', () async {
      expect(await peerPlaysOpus(db, 'calm-orbit'), isFalse);
      expect(await peerPlaysOpus(db, 'nobody'), isFalse);
      expect(await groupPlaysOpus(db, 'g1', 'me'), isFalse);
      expect(await groupPlaysOpus(db, 'no-group', 'me'), isFalse);
    });

    test('an accepted contact that said so is sent opus', () async {
      expect(await came('calm-orbit', op: true, at: 10), isTrue);
      expect(await peerPlaysOpus(db, 'calm-orbit'), isTrue);
    });

    test('a stranger or a request leaves nothing anywhere', () async {
      final before = db.dump();
      expect(await came('cold-stranger', op: true, at: 10), isFalse);
      expect(await came('a-request', op: true, at: 10), isFalse);
      expect(await inGroup('not-a-member', op: true, at: 10), isFalse);
      expect(db.dump(), before);
      expect(col('contacts', 'a-request'), 0);
    });

    test('a newer message without the word: the phone went back', () async {
      await came('calm-orbit', op: true, at: 10);
      await came('calm-orbit', op: false, at: 20);
      expect(await peerPlaysOpus(db, 'calm-orbit'), isFalse);
      // an older copy that carried it changes nothing
      await came('calm-orbit', op: true, at: 15);
      expect(await peerPlaysOpus(db, 'calm-orbit'), isFalse);
      await came('calm-orbit', op: true, at: 30);
      expect(await peerPlaysOpus(db, 'calm-orbit'), isTrue);
    });

    test('a frame that is no message of theirs never takes it away', () async {
      await came('calm-orbit', op: true, at: 10);
      await came('calm-orbit', op: false, at: 20, msg: false);
      expect(await peerPlaysOpus(db, 'calm-orbit'), isTrue);
    });

    test('a group goes opus only when every other member plays it', () async {
      await inGroup('a', op: true, at: 1);
      await inGroup('b', op: true, at: 1);
      expect(await groupPlaysOpus(db, 'g1', 'me'), isFalse);
      await inGroup('c', op: true, at: 1);
      // this phone's own row is not asked
      expect(col('group_members', 'me'), 0);
      expect(await groupPlaysOpus(db, 'g1', 'me'), isTrue);
      await inGroup('b', op: false, at: 2);
      expect(await groupPlaysOpus(db, 'g1', 'me'), isFalse);
    });

    test('a member gone takes the word with its row', () async {
      for (final m in ['a', 'b', 'c']) {
        await inGroup(m, op: true, at: 1);
      }
      await db.delete(
        'group_members',
        where: 'group_id = ? AND halo_id = ?',
        whereArgs: ['g1', 'c'],
      );
      expect(col('group_members', 'c'), isNull);
      expect(await groupPlaysOpus(db, 'g1', 'me'), isTrue);
      await db.delete(
        'group_members',
        where: 'group_id = ?',
        whereArgs: ['g1'],
      );
      expect(await groupPlaysOpus(db, 'g1', 'me'), isFalse);
    });

    final sql = RealSqlite.open();
    test(
      'the upgrade to 87 adds the word to contacts and members, once',
      () async {
        final s = sql!;
        s.run('CREATE TABLE contacts (halo_id TEXT PRIMARY KEY)');
        s.run(
          'CREATE TABLE group_members (group_id TEXT NOT NULL, '
          'halo_id TEXT NOT NULL, joined_at INTEGER NOT NULL)',
        );
        s.run("INSERT INTO contacts VALUES ('calm-orbit')");
        s.run("INSERT INTO group_members VALUES ('g1', 'a', 1)");
        await opusColumns(RealExecutor(s));
        // a second run finds them there
        await opusColumns(RealExecutor(s));
        // the system's sqlite hands every value back as text
        expect(s.run('SELECT opus_can FROM contacts').single, {
          'opus_can': '0',
        });
        expect(s.run('SELECT opus_can FROM group_members').single, {
          'opus_can': '0',
        });
      },
      skip: sql == null ? 'no sqlite library here' : null,
    );

    test('the upgrade is in the version steps, and a new install has it', () {
      final src = File('lib/app/database.dart').readAsStringSync();
      final v = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
      expect(int.parse(v), greaterThanOrEqualTo(87));
      expect(src, contains('if (oldV < 87) {'));
      expect(
        RegExp(
          r'CREATE TABLE contacts \([^;]*opus_can INTEGER NOT NULL',
        ).hasMatch(src),
        isTrue,
      );
      expect(
        RegExp(
          r'CREATE TABLE group_members \([^;]*opus_can INTEGER NOT NULL',
        ).hasMatch(src),
        isTrue,
      );
      // no table of its own any more
      expect(
        File('lib/voice_format.dart').readAsStringSync(),
        isNot(contains('CREATE TABLE')),
      );
    });

    test('a vault or the decoy, as it opens, sweeps its unnamed media', () {
      // a wav a stop or a death left, or half an opus copy
      final src = File('lib/app/state_session.dart').readAsStringSync();
      expect(src, contains('await _sweepUnnamedMedia(before, v);'));
      expect(src, contains('await _sweepUnnamedMedia(before, d);'));
      // the decoy's own vault open sweeps the decoy too, as its wallpapers
      final vaultOpen = src.indexOf(
        'await _sweepUnnamedMedia(before, primary, true);',
      );
      expect(vaultOpen, greaterThan(src.indexOf('await settleVault(v);')));
      final boot = File('lib/app/state_boot.dart').readAsStringSync();
      expect(boot, contains('await sweepableMedia('));
    });

    test('the word is taken past the gates, for nobody in the dev chat', () {
      final arr = File('lib/app/state_arrivals.dart').readAsStringSync();
      final take = arr.indexOf('await _takeOpus(');
      expect(
        take,
        greaterThan(arr.indexOf('stranger lock + proof-of-work gate')),
      );
      expect(take, lessThan(arr.indexOf('await db.saveMessage(')));
      expect('await _takeOpus('.allMatches(arr), hasLength(1));
      final voice = File('lib/app/state_voice.dart').readAsStringSync();
      expect(voice, contains('if (isDevId(peer)) return;'));
    });
  });

  group('the encode', () {
    late String wav;
    setUp(() {
      wav = '${tmp.path}/vn_u1.wav';
      File(wav).writeAsBytesSync(_wav(16000));
    });

    test('to an old phone the wav goes as it is, nothing encoded', () async {
      var asked = 0;
      voiceOggForTest = (_, _) async {
        asked++;
        return 'ok 1000 100';
      };
      expect(await voiceForWire(wav, opus: false), (wav, 'voice.wav'));
      expect(asked, 0);
      expect(File(oggPathOf(wav)).existsSync(), isFalse);
    });

    test('to a phone that plays it, the opus copy', () async {
      String? read;
      voiceOggForTest = (from, to) async {
        read = from;
        File(to).writeAsBytesSync(_note);
        return 'ok 3400 ${_note.length}';
      };
      final (path, name) = await voiceForWire(wav, opus: true);
      expect((path, name), ('${tmp.path}/vn_u1.ogg', 'voice.ogg'));
      expect(read, wav);
      expect(File(path).readAsBytesSync(), _note);
      // the wav is the caller's to let go
      expect(File(wav).existsSync(), isTrue);
    });

    test('an encode that fails sends the wav and leaves no ogg', () async {
      for (final fail in <Future<String> Function(String, String)>[
        (_, to) async {
          File(to).writeAsBytesSync(_note.sublist(0, 100));
          return 'error: io';
        },
        (_, to) async {
          File(to).writeAsBytesSync([1, 2, 3]);
          throw StateError('no engine');
        },
        (_, _) async => 'error: rate',
      ]) {
        voiceOggForTest = fail;
        expect(await voiceForWire(wav, opus: true), (wav, 'voice.wav'));
        expect(File(oggPathOf(wav)).existsSync(), isFalse);
      }
    });

    test('one waiting its turn when the lock comes never starts', () async {
      final first = Completer<String>();
      var started = <String>[];
      voiceOggForTest = (from, to) {
        started.add(from);
        return from.endsWith('a.wav') ? first.future : Future.value('ok 1 1');
      };
      var locked = false;
      final a = encodeVoiceOgg('a.wav', '${tmp.path}/a.ogg');
      final b = encodeVoiceOgg(
        'b.wav',
        '${tmp.path}/b.ogg',
        stop: () => locked,
      );
      await Future<void>.delayed(Duration.zero);
      locked = true;
      first.complete('ok 1 1');
      expect(await a, 1);
      expect(await b, isNull);
      expect(started, ['a.wav']);
    });

    test('one under way is told to stop by its path', () async {
      final asked = <String>[];
      voiceStopForTest = asked.add;
      addTearDown(() => voiceStopForTest = null);
      final done = Completer<String>();
      voiceOggForTest = (_, _) => done.future;
      var locked = false;
      final run = encodeVoiceOgg(
        wav,
        '${tmp.path}/vn_u1.ogg',
        stop: () => locked,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(asked, isEmpty);
      locked = true;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(asked, ['${tmp.path}/vn_u1.ogg']);
      done.complete('error: stopped');
      expect(await run, isNull);
      expect(File('${tmp.path}/vn_u1.ogg').existsSync(), isFalse);
    });

    test('encodes take turns', () async {
      final order = <String>[];
      final first = Completer<void>();
      voiceOggForTest = (from, to) async {
        order.add('start $from');
        if (from.endsWith('a.wav')) await first.future;
        order.add('end $from');
        return 'ok 1 1';
      };
      final a = encodeVoiceOgg('a.wav', '${tmp.path}/a.ogg');
      final b = encodeVoiceOgg('b.wav', '${tmp.path}/b.ogg');
      await Future<void>.delayed(Duration.zero);
      expect(order, ['start a.wav']);
      first.complete();
      expect(await a, 1);
      expect(await b, 1);
      expect(order, ['start a.wav', 'end a.wav', 'start b.wav', 'end b.wav']);
    });
  });

  group('the wave of an opus note', () {
    test('what the engine says, read', () {
      final p = peaksOfAnswer(
        '{"ms":3400,"p":[0,0.5,1,${List.filled(27, 0.25).join(',')}]}',
        30,
      )!;
      expect(p.take(3), [0, 0.5, 1]);
      expect(p, hasLength(30));
      expect(peaksOfAnswer('{"ms":1,"p":[1,2]}', 30), isNull);
      expect(peaksOfAnswer('error: not-opus', 30), isNull);
      expect(peaksOfAnswer('{not json', 30), isNull);
      // out of range is held in range
      expect(peaksOfAnswer('{"p":[7,-1]}', 2), [1, 0]);
    });

    test('no engine on this host: no wave, and no throw', () {
      expect(oggPeaks('${tmp.path}/none.ogg', 30), isNull);
    });
  });

  group('a note a player has open', () {
    test('is let go only once no player holds it', () async {
      const path = '/m/vn_u1.wav';
      var free = false;
      await voiceFileFree(path);
      holdVoiceFile(path);
      holdVoiceFile(path);
      unawaited(voiceFileFree(path).then((_) => free = true));
      letVoiceFileGo(path);
      await Future<void>.delayed(Duration.zero);
      expect(free, isFalse);
      letVoiceFileGo(path);
      await Future<void>.delayed(Duration.zero);
      expect(free, isTrue);
    });
  });
}
