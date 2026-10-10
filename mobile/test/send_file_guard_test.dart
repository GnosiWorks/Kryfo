// SPDX-License-Identifier: GPL-3.0-or-later
// a file sent from the gallery or the files app is copied into the chat's
// media folder and cleaned there. a copy that cannot be cleaned is not sent
// and is shredded, not just unlinked. an empty file is refused before it
// is copied, and a sender handed one says so instead of reading as sent
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/group_media_send.dart';

import 'source_body.dart';

void main() {
  const screens = {
    'lib/screens/chat_screen.dart': 'Future<void> _sendFileFrom(',
    'lib/screens/group_chat_screen.dart': 'Future<void> _sendGroupFileFrom(',
  };

  test('a copy that cannot be cleaned is shredded', () {
    screens.forEach((file, sig) {
      final body = bodyOf(sourceOf(file), sig);
      expect(body, isNot(contains('.delete(')), reason: file);
      // the video that cannot be walked and the picture that cannot be read
      final video = body.substring(body.indexOf('videoNameNeedsStrip'));
      final picture = body.substring(body.indexOf('stripPictureFileOffUi'));
      expect(
        video.substring(0, video.indexOf('return;')),
        contains('await shredFile(dest.path);'),
        reason: file,
      );
      expect(
        picture.substring(0, picture.indexOf('return;')),
        contains('await shredFile(dest.path);'),
        reason: file,
      );
    });
  });

  test('an empty file is refused as one that cannot be read', () {
    screens.forEach((file, sig) {
      final body = bodyOf(sourceOf(file), sig);
      final empty = body.indexOf('if (size == 0) {');
      expect(empty, greaterThan(0), reason: file);
      final refusal = body.substring(empty, body.indexOf('}', empty));
      expect(refusal, contains('CouldNotReadThat'), reason: file);
      expect(refusal, contains('return;'), reason: file);
      // before anything is copied or counted
      expect(empty, lessThan(body.indexOf('newMsgUid()')), reason: file);
    });
  });

  group('a sender handed an empty file', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('empty_send'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('in a group says so, and offers nobody anything', () async {
      final f = File('${tmp.path}/empty.bin')..writeAsBytesSync([]);
      final offered = <String>[];
      final r = await sendGroupSlices(
        path: f.path,
        msgUid: 'empty1',
        members: ['b', 'c'],
        wrap: (slice, i, total) async => '$i',
        deliver: (m, w) async {
          offered.add(m);
          return true;
        },
        gap: Duration.zero,
        retryPause: Duration.zero,
      );
      expect(r, isNot('ok'));
      expect(r, startsWith('error'));
      expect(offered, isEmpty);
    });

    test('to one person says so before anything goes', () {
      final body = bodyOf(
        sourceOf('lib/media_send.dart'),
        'Future<String> _sendChunkedMediaInner(',
      );
      final count = body.indexOf('total = await mediaSliceCount(path);');
      final empty = body.indexOf("if (total == 0) return 'error: empty';");
      expect(count, greaterThan(0));
      expect(empty, greaterThan(count));
      expect(empty, lessThan(body.indexOf('worker()')));
    });
  });
}
