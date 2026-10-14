// SPDX-License-Identifier: GPL-3.0-or-later
// any file can go: the picker shows every kind, one over the limit is
// refused with its size and the limit in words, a renamed video is still
// cleaned, and a big file of a kind that is not cleaned says it goes as it
// is. the menus offer a save for every file, and no share for an app
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/media_bubbles.dart' show fileTooBigLine;

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
      final over = send.indexOf('if (!fileFits(size)) {');
      expect(over, greaterThan(0), reason: file);
      final refusal = send.substring(over, send.indexOf('return;', over));
      expect(
        refusal,
        contains('showHaloToast(context, fileTooBigLine(size))'),
        reason: file,
      );
      // before anything is copied
      expect(over, lessThan(send.indexOf('newMsgUid()')), reason: file);
      expect(send, isNot(contains('8 * 1024 * 1024')), reason: file);
    });
  });

  test('15 mb goes, one byte more does not', () {
    expect(kMaxFileBytes, 15 * 1024 * 1024);
    expect(fileFits(15 * 1024 * 1024), isTrue);
    expect(fileFits(15 * 1024 * 1024 + 1), isFalse);
    expect(fileFits(1), isTrue);
  });

  test('the limit reads as a person would say it', () {
    expect(
      fileTooBigLine(20 * 1024 * 1024),
      'This file is 20.0 mb. Files can be up to 15.0 mb.',
    );
    // just over reads in whole kb, so the two numbers never match
    expect(
      fileTooBigLine(15 * 1024 * 1024 + 1),
      'This file is 15,361 kb. Files can be up to 15,360 kb.',
    );
    expect(
      fileTooBigLine(15 * 1024 * 1024 + 40 * 1024),
      'This file is 15,400 kb. Files can be up to 15,360 kb.',
    );
    expect(
      fileTooBigLine(15 * 1024 * 1024 + 60 * 1024),
      'This file is 15.1 mb. Files can be up to 15.0 mb.',
    );
  });

  test('a camera clip has the same limit as a file', () {
    final cam = sourceOf('lib/screens/camera_screen.dart');
    expect(cam, isNot(contains('8 * 1024 * 1024')));
    expect('!fileFits(_clipBytes)'.allMatches(cam), hasLength(2));
    expect(l10n.cameraTooLongForA, 'Too long for a message · 15 MB max');
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
      contains('fileCard(msg.filePath,msg.fileName,isOut,shape:shape,)'),
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
