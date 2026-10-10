// SPDX-License-Identifier: GPL-3.0-or-later
// a voice note's recording is the voice before any disguise. it is read
// once and shredded from the cache the moment it is, in a group as in a
// chat, and not left for the next start to find. one cancelled, held back,
// cut off by the chat closing or left by a crash is shredded too
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show sweepVoiceLeftovers;
import 'package:kryfo/picked.dart';

import 'shred_twin.dart';
import 'source_body.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('voice_take'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('the take is read, then gone', () async {
    final f = File('${tmp.path}/vn_1757693091000.wav')
      ..writeAsBytesSync(List.generate(4096, (i) => i & 255));
    final bytes = await takeRecording(f.path);
    expect(bytes, Uint8List.fromList(List.generate(4096, (i) => i & 255)));
    expect(f.existsSync(), isFalse);
  });

  test('no take, nothing to send', () async {
    expect(await takeRecording('${tmp.path}/vn_none.wav'), isNull);
  });

  test('the take is zeroed, not just unlinked', () async {
    final twins = Directory.systemTemp.createTempSync('voice_twins');
    addTearDown(() => twins.deleteSync(recursive: true));
    final f = File('${tmp.path}/vn_1757693091001.wav')
      ..writeAsBytesSync(List.filled(4096, 7));
    final twin = twinOf(f.path, twins);
    await takeRecording(f.path);
    expect(zeroed(twin), isTrue);
  });

  test('the one-to-one chat sends from the take the same way', () {
    final src = sourceOf('lib/screens/chat_screen.dart');
    final send = bodyOf(src, 'Future<void> _sendVoice(');
    expect(send, contains('await takeRecording(srcPath)'));
    expect(send, isNot(contains('readAsBytes')));
    expect(send, isNot(contains('.delete(')));
    // a send a request holds back, and a cancel, shred it too
    expect(send, contains('shredFile(srcPath)'));
    final done = bodyOf(src, 'void _onVoiceComplete(');
    expect(done, contains('shredFile(path)'));
    expect(done, isNot(contains('.delete(')));
  });

  test('a take still recording when the chat goes is shredded', () {
    for (final f in [
      'lib/screens/chat_screen.dart',
      'lib/widgets/media_bubbles.dart',
    ]) {
      final src = sourceOf(f);
      final mic = src.substring(src.indexOf('HoldToTalkMicState extends'));
      final dispose = bodyOf(mic, 'void dispose(');
      expect(dispose, contains('final take = _path;'), reason: f);
      expect(dispose, contains('shredFile(take)'), reason: f);
      // a take handed on is the sender's to shred, not dispose's
      final end = bodyOf(mic, 'Future<void> _end(');
      expect(
        end.indexOf('_path = null;'),
        lessThan(end.indexOf('widget.onComplete(take')),
        reason: f,
      );
    }
  });

  test('a take a crash left is shredded at the next start', () async {
    final twins = Directory.systemTemp.createTempSync('voice_twins');
    addTearDown(() => twins.deleteSync(recursive: true));
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
    expect(body, contains('await takeRecording(srcPath)'));
    expect(body, isNot(contains('readAsBytes')));
  });
}
