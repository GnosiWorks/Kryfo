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
    setUp(() => db = MemDb());

    Future<void> came(
      String peer, {
      required bool op,
      int? at,
      bool msg = true,
    }) => takePeerOpus(db, peer, carried: op, counts: msg, written: at);

    test('none known is wav', () async {
      expect(await peerPlaysOpus(db, 'calm-orbit'), isFalse);
      expect(await allPlayOpus(db, const []), isFalse);
    });

    test('a phone that said so is sent opus', () async {
      await came('calm-orbit', op: true, at: 10);
      expect(await peerPlaysOpus(db, 'calm-orbit'), isTrue);
      expect(await peerPlaysOpus(db, 'other-one'), isFalse);
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

    test('a group goes opus only when every member plays it', () async {
      await came('a', op: true, at: 1);
      await came('b', op: true, at: 1);
      expect(await allPlayOpus(db, ['a', 'b']), isTrue);
      expect(await allPlayOpus(db, ['a', 'b', 'c']), isFalse);
      await came('b', op: false, at: 2);
      expect(await allPlayOpus(db, ['a', 'b']), isFalse);
    });

    final sql = RealSqlite.open();
    test(
      'a contact deleted takes its row along',
      () async {
        final s = sql!;
        s.run('CREATE TABLE contacts (halo_id TEXT PRIMARY KEY)');
        s.run("INSERT INTO contacts VALUES ('calm-orbit')");
        await voiceOpusTable(RealExecutor(s));
        await voiceOpusTable(RealExecutor(s));
        s.run("INSERT INTO voice_opus VALUES ('calm-orbit', 10)");
        s.run("DELETE FROM contacts WHERE halo_id = 'calm-orbit'");
        expect(s.run('SELECT * FROM voice_opus'), isEmpty);
      },
      skip: sql == null ? 'no sqlite library here' : null,
    );
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
      voiceOggForTest = (from, to) async {
        expect(from, wav);
        File(to).writeAsBytesSync(_note);
        return 'ok 3400 ${_note.length}';
      };
      final (path, name) = await voiceForWire(wav, opus: true);
      expect((path, name), ('${tmp.path}/vn_u1.ogg', 'voice.ogg'));
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
