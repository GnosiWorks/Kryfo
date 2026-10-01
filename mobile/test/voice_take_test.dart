// SPDX-License-Identifier: GPL-3.0-or-later
// a voice note's recording is the voice before any disguise. it is read
// once and gone from the cache the moment it is, in a group as in a chat,
// and not left for the next start to find
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/picked.dart';

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

  test('the group chat sends from the take and keeps no copy of it', () {
    final body = bodyOf(
      sourceOf('lib/screens/group_chat_screen.dart'),
      'Future<void> _sendGroupVoice(',
    );
    expect(body, contains('await takeRecording(srcPath)'));
    expect(body, isNot(contains('readAsBytes')));
  });
}
