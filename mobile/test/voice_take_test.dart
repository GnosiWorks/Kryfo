// SPDX-License-Identifier: GPL-3.0-or-later
// a voice note's recording is the voice before any disguise. as recorded it
// is moved where the message keeps it, never read whole; disguised, it is
// shredded once the disguise is there, in a group as in a chat, and not
// left for the next start to find. one cancelled, held back, cut off by the
// chat closing or left by a crash is shredded too
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show sweepVoiceLeftovers;
import 'package:kryfo/picked.dart';

import 'shred_twin.dart';
import 'source_body.dart';

// [secs] of a voiced tone, as the recorder writes it
Uint8List _wav(double secs) {
  const rate = 16000;
  final n = (secs * rate).round();
  final b = ByteData(44 + n * 2);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    var v = 0.0;
    for (var h = 1; h <= 5; h++) {
      v += math.sin(2 * math.pi * 150 * h * i / rate) / h;
    }
    b.setInt16(44 + i * 2, (4000 * v).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  late Directory tmp;
  late Directory twins;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('voice_take');
    twins = Directory.systemTemp.createTempSync('voice_twins');
  });
  tearDown(() {
    tmp.deleteSync(recursive: true);
    twins.deleteSync(recursive: true);
  });

  test('as recorded, the take is moved where it is kept', () async {
    final bytes = Uint8List.fromList(List.generate(4096, (i) => i & 255));
    final f = File('${tmp.path}/vn_1757693091000.wav')..writeAsBytesSync(bytes);
    final dest = '${tmp.path}/kept.wav';
    expect(await placeVoice(f.path, dest, disguise: false), isTrue);
    expect(File(dest).readAsBytesSync(), bytes);
    expect(f.existsSync(), isFalse);
  });

  test('no take, nothing to send', () async {
    final dest = '${tmp.path}/kept.wav';
    for (final disguise in [false, true]) {
      expect(
        await placeVoice('${tmp.path}/vn_none.wav', dest, disguise: disguise),
        isFalse,
      );
      expect(File(dest).existsSync(), isFalse);
    }
  });

  test('disguised, the take is zeroed, not just unlinked', () async {
    final take = _wav(0.6);
    final f = File('${tmp.path}/vn_1757693091001.wav')..writeAsBytesSync(take);
    final twin = twinOf(f.path, twins);
    final dest = '${tmp.path}/kept.wav';
    expect(await placeVoice(f.path, dest, disguise: true), isTrue);
    final kept = File(dest).readAsBytesSync();
    expect(kept.length, take.length);
    expect(kept.sublist(0, 44), take.sublist(0, 44));
    expect(kept.sublist(44), isNot(take.sublist(44)));
    expect(f.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
    // nothing else of it is left
    expect(tmp.listSync().map((e) => e.path), [dest]);
  });

  test('a disguise made already goes, and the take is zeroed', () async {
    final f = File('${tmp.path}/vn_1757693091002.wav')
      ..writeAsBytesSync(_wav(0.4));
    final made = Uint8List.fromList(List.filled(3000, 9));
    final m = File('${tmp.path}/vn_1757693091002_m.wav')
      ..writeAsBytesSync(made);
    final twin = twinOf(f.path, twins);
    final dest = '${tmp.path}/kept.wav';
    expect(
      await placeVoice(f.path, dest, disguise: true, masked: m.path),
      isTrue,
    );
    expect(File(dest).readAsBytesSync(), made);
    expect(m.existsSync(), isFalse);
    expect(f.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
  });

  test('as recorded after all, the disguise made for it is shredded', () async {
    final take = _wav(0.4);
    final f = File('${tmp.path}/vn_1757693091003.wav')..writeAsBytesSync(take);
    final m = File('${tmp.path}/vn_1757693091003_m.wav')
      ..writeAsBytesSync(List.filled(3000, 9));
    final twin = twinOf(m.path, twins);
    final dest = '${tmp.path}/kept.wav';
    expect(
      await placeVoice(f.path, dest, disguise: false, masked: m.path),
      isTrue,
    );
    expect(File(dest).readAsBytesSync(), take);
    expect(m.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
  });

  test('a take that cannot be disguised never goes as recorded', () async {
    final f = File('${tmp.path}/vn_1757693091004.wav')
      ..writeAsBytesSync(List.filled(4096, 7));
    final twin = twinOf(f.path, twins);
    final dest = '${tmp.path}/kept.wav';
    expect(await placeVoice(f.path, dest, disguise: true), isFalse);
    expect(File(dest).existsSync(), isFalse);
    expect(f.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
    expect(tmp.listSync(), isEmpty);
  });

  test('the one-to-one chat sends from the take the same way', () {
    final src = sourceOf('lib/screens/chat_screen.dart');
    final send = bodyOf(src, 'Future<void> _sendVoice(');
    expect(send, contains('await placeVoice('));
    expect(send, isNot(contains('readAsBytes')));
    expect(send, isNot(contains('writeAsBytes')));
    expect(send, isNot(contains('.delete(')));
    // a send a request holds back shreds it too, with its disguise
    expect(send, contains('dropTake(srcPath, take.masked)'));
    // and the mic shreds a cancelled one itself
    final mic = sourceOf('lib/widgets/voice_mic.dart');
    final end = bodyOf(mic, 'Future<void> _end(');
    expect(end, contains('if (take != null) await shredFile(take);'));
    expect(end, isNot(contains('.delete(')));
  });

  test('the preview never reads the take whole', () {
    final mic = sourceOf('lib/widgets/voice_mic.dart');
    for (final sig in [
      'Future<void> _toPreview(',
      'Future<String?> _makeMask(',
    ]) {
      final body = bodyOf(mic, sig);
      expect(body, isNot(contains('readAsBytes')), reason: sig);
      expect(body, isNot(contains('wavPeaks(')), reason: sig);
    }
    expect(mic, isNot(contains('maskWav(')));
  });

  test('a take still recording when the chat goes is shredded', () {
    for (final f in ['lib/widgets/voice_mic.dart']) {
      final src = sourceOf(f);
      final mic = src.substring(src.indexOf('HoldToTalkMicState extends'));
      final dispose = bodyOf(mic, 'void dispose(');
      expect(dispose, contains('final take = _path;'), reason: f);
      expect(dispose, contains('shredFile(take)'), reason: f);
      // a take handed on is the sender's to shred, not dispose's: it is
      // let go before the stop is awaited, so a dispose meanwhile cannot
      // shred it under the sender
      final end = bodyOf(mic, 'Future<void> _end(');
      expect(end.indexOf('_path = null;'), greaterThan(0), reason: f);
      expect(
        end.indexOf('_path = null;'),
        lessThan(end.indexOf('await _rec.stop()')),
        reason: f,
      );
    }
  });

  test('a take a crash left is shredded at the next start', () async {
    final f = File('${tmp.path}/vn_1757693091002.wav')
      ..writeAsBytesSync(List.filled(4096, 7));
    final twin = twinOf(f.path, twins);
    await sweepVoiceLeftovers(tmp);
    expect(f.existsSync(), isFalse);
    expect(zeroed(twin), isTrue);
  });

  test('the group chat sends from the take and keeps no copy of it', () {
    final body = bodyOf(
      sourceOf('lib/screens/group_chat_screen.dart'),
      'Future<void> _sendGroupVoice(',
    );
    expect(body, contains('await placeVoice('));
    expect(body, isNot(contains('readAsBytes')));
    expect(body, isNot(contains('writeAsBytes')));
    // one that will not go is shredded with its disguise
    final on = bodyOf(
      sourceOf('lib/screens/group_chat_screen.dart'),
      'void _onVoice(',
    );
    expect('dropTake(take.path, take.masked)'.allMatches(on), hasLength(2));
  });

  test(
    'a note that will not go: its take and its disguise are zeroed',
    () async {
      final f = File('${tmp.path}/vn_1757693091005.wav')
        ..writeAsBytesSync(List.filled(4096, 7));
      final m = File('${tmp.path}/vn_1757693091005_m.wav')
        ..writeAsBytesSync(List.filled(4096, 8));
      final twin = twinOf(f.path, twins);
      final mtwin = twinOf(m.path, twins);
      await dropTake(f.path, m.path);
      expect(tmp.listSync(), isEmpty);
      expect(zeroed(twin), isTrue);
      expect(zeroed(mtwin), isTrue);
    },
  );
}
