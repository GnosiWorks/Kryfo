// SPDX-License-Identifier: GPL-3.0-or-later
// any file can go: the picker shows every kind, one over the limit is
// refused with its size and the limit in words, a renamed video is still
// cleaned, and a big file of a kind that is not cleaned says it goes as it
// is. the menus offer a save for every file, and no share for an app
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/file_drop.dart' show kOldFileBytes;
import 'package:kryfo/file_kind.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/media_resend.dart' show kMaxFileSlices;
import 'package:kryfo/widgets/media_bubbles.dart' show fileTooBigLine;

import 'source_body.dart';

void main() {
  const screens = {
    'lib/screens/chat_screen.dart': (
      'Future<void> _showAttachSheet(',
      'Future<_Ready?> _readyFile(',
    ),
    'lib/screens/group_chat_screen.dart': (
      'Future<void> _showAttachSheet(',
      'Future<_GReady?> _readyGroupFile(',
    ),
  };

  test('the picker shows every kind of file', () {
    // both chats pick through the sending sheet
    final pick = bodyOf(
      sourceOf('lib/recent_files.dart'),
      'Future<List<SendPick>> filePicksForSheet(',
    );
    expect(pick, contains('FilePicker.pickFiles(type: FileType.any)'));
    expect(pick, isNot(contains('allowedExtensions')));
    screens.forEach((file, sig) {
      expect(
        bodyOf(sourceOf(file), sig.$1),
        contains('pickFiles: filePicksForSheet'),
        reason: file,
      );
    });
  });

  test('a file over the limit is refused with both sizes', () {
    screens.forEach((file, sig) {
      final send = bodyOf(sourceOf(file), sig.$2);
      // the chat's own limit: 15 mb while a phone in it is on a version
      // before the files service
      expect(send, contains('final most = await appState.fileLimitFor'));
      final over = send.indexOf('if (!fileFits(size, most)) {');
      expect(over, greaterThan(0), reason: file);
      final refusal = send.substring(over, send.indexOf('return', over));
      expect(
        refusal,
        contains('showHaloToast(context, fileTooBigLine(size, most))'),
        reason: file,
      );
      // before anything is copied
      expect(over, lessThan(send.indexOf('newMsgUid()')), reason: file);
      expect(send, isNot(contains('8 * 1024 * 1024')), reason: file);
    });
  });

  test('50 mb goes, one byte more does not, and 15 to an older phone', () {
    expect(kMaxFileBytes, 50 * 1024 * 1024);
    expect(fileFits(50 * 1024 * 1024), isTrue);
    expect(fileFits(50 * 1024 * 1024 + 1), isFalse);
    expect(fileFits(1), isTrue);
    expect(fileFits(15 * 1024 * 1024, 15 * 1024 * 1024), isTrue);
    expect(fileFits(15 * 1024 * 1024 + 1, 15 * 1024 * 1024), isFalse);
  });

  test('the limit reads as a person would say it', () {
    expect(
      fileTooBigLine(60 * 1024 * 1024),
      'This file is 60.0 MB. Files can be up to 50.0 MB.',
    );
    // just over reads in whole kb, so the two numbers never match
    expect(
      fileTooBigLine(50 * 1024 * 1024 + 1),
      'This file is 51,201 KB. Files can be up to 51,200 KB.',
    );
    expect(
      fileTooBigLine(50 * 1024 * 1024 + 60 * 1024),
      'This file is 50.1 MB. Files can be up to 50.0 MB.',
    );
    // a chat with a phone not yet updated says what it waits on
    const old = 15 * 1024 * 1024;
    expect(
      fileTooBigLine(20 * 1024 * 1024, old),
      'This file is 20.0 MB. This chat takes files up to 15.0 MB until '
      'everyone in it updates Kryfo.',
    );
    expect(
      fileTooBigLine(old + 40 * 1024, old),
      'This file is 15,400 KB. This chat takes files up to 15,360 KB until '
      'everyone in it updates Kryfo.',
    );
  });

  test('a camera clip has the same limit as a file', () {
    final cam = sourceOf('lib/screens/camera_screen.dart');
    expect(cam, isNot(contains('8 * 1024 * 1024')));
    expect('!fileFits(_clipBytes)'.allMatches(cam), hasLength(2));
    expect(l10n.cameraTooLongForA, 'Too long for a message · 50 MB max');
  });

  test('a video is cleaned by its bytes as well as its name', () {
    screens.forEach((file, sig) {
      final send = bodyOf(
        sourceOf(file),
        sig.$2,
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        send,
        contains('await copyForSend(src, dest.path, name: name, raw: raw);'),
        reason: file,
      );
    });
    final one = sourceOf(
      'lib/clean_media.dart',
    ).replaceAll(RegExp(r'\s+'), ' ');
    expect(
      one,
      contains(
        'if (!raw && (videoNameNeedsStrip(name) || '
        'await bytesSayIsoVideo(path))) {',
      ),
    );
  });

  test('a picture the lane cannot clean is never asked about: it is drawn '
      'again or goes as it is (copyForSend)', () {
    screens.forEach((file, sig) {
      final send = bodyOf(sourceOf(file), sig.$2);
      expect(
        send,
        contains('readFileFactsFresh(src, name))?.raw'),
        reason: file,
      );
      expect(send, contains('copyForSend(src, dest.path'), reason: file);
      expect(send, isNot(contains('showConfirmSheet')), reason: file);
    });
    final chat = sourceOf('lib/screens/chat_screen.dart');
    final sheet = bodyOf(chat, 'Future<bool> _confirmBigSend(');
    expect(sheet, contains('if (bytes < kBigSendBytes) return true;'));
    expect(sheet, isNot(contains('raw')));
  });

  test('a big file the lane does not clean says it goes as it is', () {
    final chat = sourceOf('lib/screens/chat_screen.dart');
    final send = bodyOf(chat, 'Future<_Ready?> _readyFile(');
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
      contains('fileCard(msg.filePath,msg.fileName,isOut,shape:shape,'),
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

  test('a receiver keeps no file bigger than any kryfo sends', () {
    // the largest file that goes in slices of 12288 bytes, with room to
    // spare: one past it goes through the files service or not at all
    expect((kOldFileBytes + 12287) ~/ 12288, 1280);
    expect(kMaxFileSlices, greaterThanOrEqualTo(1280));
    expect(kMaxFileSlices, lessThan(1400));
    final recv = sourceOf('lib/app/state.dart');
    final at = recv.indexOf(
      'if (total > (voiceSlices ? kMaxVoiceSlices : kMaxFileSlices)) {',
    );
    expect(at, greaterThan(0));
    // before a slice is kept
    expect(at, lessThan(recv.indexOf('await db.putMediaChunk(', at - 4000)));
    expect(recv.substring(at, recv.indexOf('}', at)), contains('return to;'));
  });
}
