// SPDX-License-Identifier: GPL-3.0-or-later
// any file can go: the picker shows every kind, one over the limit is
// refused with its size and the limit in words, a renamed video is still
// cleaned, and a big file of a kind that is not cleaned says it goes as it
// is. the menus offer a save for every file, and no share for an app
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/media_bubbles.dart' show humanFileSize;

import 'source_body.dart';

void main() {
  const screens = {
    'lib/screens/chat_screen.dart': (
      'Future<void> _pickAndSendFile(',
      'Future<void> _sendFileFrom(',
    ),
    'lib/screens/group_chat_screen.dart': (
      'Future<void> _pickGroupFile(',
      'Future<void> _sendGroupFileFrom(',
    ),
  };

  test('the picker shows every kind of file', () {
    screens.forEach((file, sig) {
      final pick = bodyOf(sourceOf(file), sig.$1);
      expect(
        pick,
        contains('FilePicker.pickFile(type: FileType.any)'),
        reason: file,
      );
      expect(pick, isNot(contains('allowedExtensions')), reason: file);
    });
  });

  test('a file over the limit is refused with both sizes', () {
    screens.forEach((file, sig) {
      final send = bodyOf(sourceOf(file), sig.$2);
      final over = send.indexOf('if (size > kMaxFileBytes) {');
      expect(over, greaterThan(0), reason: file);
      final refusal = send.substring(over, send.indexOf('return;', over));
      expect(
        refusal,
        contains(
          'l10n.fileTooBig(humanFileSize(size), humanFileSize(kMaxFileBytes))',
        ),
        reason: file,
      );
      // before anything is copied
      expect(over, lessThan(send.indexOf('newMsgUid()')), reason: file);
      expect(send, isNot(contains('8 * 1024 * 1024')), reason: file);
    });
  });

  test('the limit reads as a person would say it', () {
    expect(kMaxFileBytes, 8 * 1024 * 1024);
    expect(
      l10n.fileTooBig(
        humanFileSize(9 * 1024 * 1024),
        humanFileSize(kMaxFileBytes),
      ),
      'This file is 9.0 mb. Files can be up to 8.0 mb.',
    );
  });

  test('a video is cleaned by its bytes as well as its name', () {
    screens.forEach((file, sig) {
      final send = bodyOf(sourceOf(file), sig.$2);
      expect(
        send,
        contains(
          'if (videoNameNeedsStrip(name) || await bytesSayIsoVideo(dest.path)) {',
        ),
        reason: file,
      );
    });
  });

  test('a big file the lane does not clean says it goes as it is', () {
    final chat = sourceOf('lib/screens/chat_screen.dart');
    final send = bodyOf(chat, 'Future<void> _sendFileFrom(');
    expect(send, contains('asItIs: !await sendLaneCleans(src, name)'));
    final sheet = bodyOf(chat, 'Future<bool> _confirmBigSend(');
    expect(sheet, contains('l10n.fileGoesAsItIs'));
  });

  test('every file can be saved, and an app is never shared', () {
    for (final file in screens.keys) {
      final src = sourceOf(file);
      expect(src, contains('label: l10n.fileSaveToDevice'), reason: file);
      expect(src, contains('saveReceivedFile('), reason: file);
      final share = src.substring(
        src.indexOf('label: l10n.commonShare'),
        src.indexOf('shareFileOut(', src.indexOf('label: l10n.commonShare')),
      );
      expect(share, contains('knownInstaller('), reason: file);
    }
  });

  test('both chats draw a file with the one card', () {
    expect(
      sourceOf('lib/screens/chat_screen.dart').replaceAll(RegExp(r'\s+'), ''),
      contains('fileCard(msg.filePath,msg.fileName,isOut,)'),
    );
    expect(
      sourceOf('lib/screens/chat_screen.dart'),
      isNot(contains('Widget _fileCard(')),
    );
    expect(
      sourceOf('lib/screens/group_chat_screen.dart'),
      contains('fileCard('),
    );
  });
}
