// SPDX-License-Identifier: GPL-3.0-or-later
// a voice note's recording is the voice before any disguise. as recorded it
// is moved where the message keeps it, never read whole; disguised, it is
// shredded once the disguise is there, in a group as in a chat, and not
// left for the next start to find. one cancelled, held back, cut off by the
// chat closing or left by a crash is shredded too
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, sweepVoiceLeftovers;
import 'package:kryfo/picked.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';
import 'shred_twin.dart';
import 'source_body.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

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
    // a send a request holds back shreds it too, with its disguise, one
    // still being made stopped first
    expect(send, contains('dropTake(srcPath, masked ?? take.masked)'));
    expect(send, contains('making?.cancel()'));
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
      '_Masking _startMask(',
      'Future<String?> _run(',
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

  test('disguised on the way out, the media folder only ever sees the '
      'note whole', () async {
    final take = File('${tmp.path}/vn_1757693091006.wav')
      ..writeAsBytesSync(_wav(150));
    final media = Directory('${tmp.path}/media')..createSync();
    final dest = '${media.path}/vn_u.wav';
    final seen = <String>{};
    final watch = Timer.periodic(const Duration(milliseconds: 2), (_) {
      for (final e in media.listSync()) {
        seen.add(e.uri.pathSegments.last);
      }
    });
    final placed = placeVoice(take.path, dest, disguise: true);
    expect(await placed, isTrue);
    watch.cancel();
    // a crash on the way leaves its pieces where the start sweeps
    expect(seen.difference({'vn_u.wav'}), isEmpty);
    expect(media.listSync().map((e) => e.path), [dest]);
    expect(tmp.listSync().whereType<File>(), isEmpty);
    expect(sendPathOf(take.path), '${tmp.path}/vn_1757693091006_s.wav');
  });

  group('a note of ours never written down', () {
    late Directory docs;
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      docs = Directory('${tmp.path}/docs')..createSync();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => docs.path,
          );
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );

    test(
      'goes from the media folder an hour on, and nothing else does',
      () async {
        final db = _Rows(MemDb());
        final media = await db.container.mediaDir();
        final now = DateTime(2026, 10, 15, 12);
        final old = now.subtract(const Duration(hours: 2));
        File f(String name, {DateTime? at}) => File('${media.path}/$name')
          ..writeAsBytesSync(List.filled(4096, 7))
          ..setLastModifiedSync(at ?? old);
        final kept = f('vn_kept.wav');
        final byPath = f('vn_other.wav');
        final unkept = f('vn_lost.wav');
        final side = f('vn_lost_f.wav');
        final fresh = f('vn_new.wav', at: now);
        final photo = f('p_lost.jpg');
        await db.mem.insert('messages', {
          'peer_id': 'x',
          'direction': 'out',
          'plaintext': '',
          'sent_at': 1,
          'msg_uid': 'kept',
          'file_path': kept.path,
        });
        await db.mem.insert('messages', {
          'peer_id': 'x',
          'direction': 'out',
          'plaintext': '',
          'sent_at': 2,
          'msg_uid': 'moved',
          'file_path': byPath.path,
        });
        final twin = twinOf(unkept.path, twins);
        await db.sweepUnkeptVoice(now: now);
        expect(unkept.existsSync(), isFalse);
        expect(zeroed(twin), isTrue);
        expect(side.existsSync(), isFalse);
        for (final k in [kept, byPath, fresh, photo]) {
          expect(k.existsSync(), isTrue, reason: k.path);
        }
      },
    );
  });

  test('a send keeps going once the chat is left, never past the '
      'lock', () {
    final send = bodyOf(
      sourceOf('lib/screens/chat_screen.dart'),
      'Future<void> _sendVoice(',
    );
    final group = bodyOf(
      sourceOf('lib/screens/group_chat_screen.dart'),
      'Future<void> _sendGroupVoice(',
    );
    for (final body in [send, group]) {
      expect(body, contains('lockGuard.closeOnLock('));
      expect(body, contains('if (locked)'));
      expect(body, isNot(contains('if (!mounted) return shredFile(')));
      // the media folder is asked inside a guard that drops the take
      final at = body.indexOf('mediaDirOf(');
      final placed = body.indexOf('await placeVoice(');
      final caught = body.indexOf('} catch', at);
      expect(caught, inExclusiveRange(at, placed));
      expect(body.substring(caught, placed), contains('dropTake('));
      // every setState once the note is placed asks for mounted first
      for (
        var i = body.indexOf('setState(', placed);
        i > 0;
        i = body.indexOf('setState(', i + 1)
      ) {
        expect(
          body.substring(i - 60, i),
          contains('mounted'),
          reason: body.substring(i - 60, i + 20),
        );
      }
    }
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
