// SPDX-License-Identifier: GPL-3.0-or-later
// a file leaves under a name the receiver sees on the bubble, in the
// notification and on the saved copy. a video from the gallery or the
// camera never keeps its own, and a file whose name tells when it was made
// leaves under one made here. the names below are the ones phones, chat
// apps and desktops write
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/sent_name.dart';

import 'source_body.dart';

const _timed = [
  'PXL_20261001_101502123.mp4',
  'PXL_20261001_101502123.MP.jpg',
  'VID_20261001_101502.mp4',
  'IMG_20261001_101502.jpg',
  '20261001_101502.mp4',
  'VID20261001101502.mp4',
  'IMG-20261001-WA0001.jpg',
  'VID-20261001-WA0002.mp4',
  'Screenshot_20261001-101502_Kryfo.jpg',
  'Screenshot 2026-10-01 at 10.15.02.png',
  'photo_2026-10-01_10-15-02.jpg',
  'signal-2026-10-01-101502.jpg',
  'Scan 01.10.2026.pdf',
  'clip_1727712345678.mp4',
  'image_1727712345.png',
  'Scan 12-25-2026.pdf',
  'Scan_12252026.pdf',
  'Scan 25122026.pdf',
  'Recording 1-10-2026.m4a',
  'video-2026-10-1.mp4',
  'IMG_2026_1001_1015.jpg',
  'IMG-261001-WA0001.jpg',
  'Note 2026.1.5.txt',
];

const _plain = [
  'contract.pdf',
  'report final v2.docx',
  'IMG_4512.HEIC',
  'budget 2026.xlsx',
  'song.mp3',
  'notes',
  'invoice 123456.pdf',
  'room 101.pdf',
  'track 01-02.mp3',
  'v1.2.3.zip',
  'DSC01234.JPG',
  'IMG_4512_2.jpg',
];

final _made = RegExp(r'^(photo|video|audio|file)_[0-9a-f]{8}(\.[a-z0-9]+)?$');

void main() {
  test('a name that tells when it was made is replaced, its kind and '
      'extension kept', () {
    for (final n in _timed) {
      expect(nameTellsTime(n), isTrue, reason: n);
      final out = sentFileName(n);
      expect(out, matches(_made), reason: n);
      expect(out, isNot(contains('2026')), reason: n);
      expect(out, isNot(contains('PXL')), reason: n);
      final ext = n.substring(n.lastIndexOf('.') + 1).toLowerCase();
      expect(out, endsWith('.$ext'), reason: n);
    }
    expect(sentFileName('VID_20261001_101502.mp4'), startsWith('video_'));
    expect(sentFileName('IMG_20261001_101502.jpg'), startsWith('photo_'));
    expect(sentFileName('Scan 01.10.2026.pdf'), startsWith('file_'));
  });

  test('a name chosen by hand stays as it is', () {
    for (final n in _plain) {
      expect(nameTellsTime(n), isFalse, reason: n);
      expect(sentFileName(n), n);
    }
  });

  test('a video never leaves under its own name', () {
    expect(madeVideoName('PXL_20261001_101502123.mp4'), matches(_made));
    expect(madeVideoName('holiday.MOV'), startsWith('video_'));
    expect(madeVideoName('holiday.MOV'), endsWith('.mov'));
    expect(madeVideoName(), matches(r'^video_[0-9a-f]{8}\.mp4$'));
    expect(madeVideoName(), isNot(madeVideoName()));
  });

  test('every file send names it here', () {
    final chat = sourceOf('lib/screens/chat_screen.dart');
    final group = sourceOf('lib/screens/group_chat_screen.dart');
    expect(
      bodyOf(chat, 'Future<void> _sendFileFrom('),
      contains('final name = sentFileName(picked);'),
    );
    expect(
      bodyOf(group, 'Future<void> _sendGroupFileFrom('),
      contains('final name = sentFileName(picked);'),
    );
    for (final (src, fn) in [
      (chat, 'Future<void> _pickAndSendVideo('),
      (group, 'Future<void> _pickGroupVideo('),
    ]) {
      final body = bodyOf(src, fn);
      expect(body, contains('madeVideoName(x.name)'), reason: fn);
      expect(body, isNot(contains(', x.name)')), reason: fn);
    }
    for (final src in [chat, group]) {
      expect(src, isNot(contains("'clip_\${")));
    }
  });
}
