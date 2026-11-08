// SPDX-License-Identifier: GPL-3.0-or-later
// how both chats send what the preview gives back: its bubbles show at
// once and the cleaning follows; the camera's clip goes through the
// preview too; to a stranger before they accept none opens, and the dev
// chat's takes only the slots left;
// a big file is asked about inside the preview, not after it
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/clean_media.dart' show writeMadeCopy;

import 'source_body.dart';

void main() {
  final chat = sourceOf('lib/screens/chat_screen.dart');
  final group = sourceOf('lib/screens/group_chat_screen.dart');

  test('the bubbles show before anything is cleaned', () {
    for (final (src, ready) in [
      (chat, '_readyPhoto('),
      (group, '_readyGroupPhoto('),
    ]) {
      final body = bodyOf(src, 'Future<void> _sendPicked(');
      final shown = body.indexOf('..preparing = true');
      final added = body.indexOf('_messages.addAll(waiting)');
      expect(shown, greaterThan(0));
      expect(added, greaterThan(shown));
      expect(body.indexOf(ready), greaterThan(added));
      // and each ready one is sent on its own bubble
      expect(body, contains('shown: m'));
    }
  });

  test('the camera\'s clip goes through the preview', () {
    for (final (src, fn, direct) in [
      (chat, 'Future<void> _openCamera(', '_sendFileFrom('),
      (group, 'Future<void> _openGroupCamera(', '_sendGroupFileFrom('),
    ]) {
      final body = bodyOf(src, fn);
      expect(body, contains('PickedMedia.video('), reason: fn);
      expect(body, contains('_sendPicked(sent)'), reason: fn);
      expect(body, isNot(contains(direct)), reason: fn);
      // its copy goes however the preview ends, its frame with it
      final finale = body.indexOf('} finally {');
      expect(finale, greaterThan(0), reason: fn);
      expect(body.substring(finale), contains('shredCapture(path)'));
    }
  });

  test('before they accept, no preview to a stranger, the dev chat\'s slots '
      'left', () {
    final body = bodyOf(chat, 'Future<MediaSendResult?> _preview(');
    expect(body, contains('final room = _roomLeft;'));
    expect(body, contains('max: room,'));
    expect(body, contains('if (_mediaWaits || room <= 0)'));
    expect(body, isNot(contains('request:')));
    expect(body, contains('onGone:'));
    expect(
      bodyOf(group, 'Future<MediaSendResult?> _preview('),
      contains('onGone:'),
    );
  });

  test('a big file is asked about in the preview, and not again', () {
    final body = bodyOf(chat, 'Future<MediaSendResult?> _preview(');
    expect(body, contains('beforeSend: _askBig,'));
    expect(bodyOf(chat, 'Future<void> _sendPicked('), contains('asked: true'));
    expect(
      bodyOf(chat, 'Future<_Ready?> _readyFile('),
      contains('if (!asked &&\n        !await _confirmBigSend('),
    );
  });

  test('stopping an album that reached them asks first', () {
    final body = bodyOf(chat, 'Future<void> _stopAlbum(');
    final asked = body.indexOf('_unsendAlbum(run)');
    expect(body, contains('x.delivered'));
    expect(asked, greaterThan(0));
    expect(asked, lessThan(body.indexOf('_takeBackAlbum(run)')));
    expect(
      bodyOf(chat, 'Future<void> _unsendAlbum('),
      contains('showConfirmSheet('),
    );
  });

  test('a row keeps the time its bubble showed, for a resend', () {
    expect(
      bodyOf(chat, 'Future<void> _sendReady('),
      contains('writtenAt: msg.when.millisecondsSinceEpoch,'),
    );
    expect(
      bodyOf(group, 'Future<void> _sendGroupReady('),
      contains('writtenAt: m.when.millisecondsSinceEpoch,'),
    );
  });

  test('the answer goes with the first item that is ready', () {
    for (final src in [chat, group]) {
      final body = bodyOf(src, 'Future<void> _sendPicked(');
      final carried = body.indexOf(r'ready.first.$1.replyTo = reply;');
      expect(carried, greaterThan(0));
      // after the readying, before any is sent
      expect(carried, greaterThan(body.indexOf('ready.add(')));
      expect(carried, lessThan(body.indexOf('shown: m')));
    }
  });

  test('a chat gone part way leaves no file made ready behind', () {
    for (final src in [chat, group]) {
      final body = bodyOf(src, 'Future<void> _sendPicked(');
      expect(body, contains('ready.skip(k)'));
      expect(body, contains('await shredFile(rest.path);'));
    }
    final photo = bodyOf(chat, 'Future<_Ready?> _readyPhoto(');
    final gone = photo.indexOf('if (!mounted) return null;');
    expect(gone, greaterThan(0));
    expect(gone, lessThan(photo.indexOf('mediaDirOf')));
  });

  test('a photo the phone has no room for leaves no part behind, and its '
      'bubble goes', () async {
    for (final (src, ready) in [
      (chat, 'Future<_Ready?> _readyPhoto('),
      (group, 'Future<_GReady?> _readyGroupPhoto('),
    ]) {
      final body = bodyOf(src, ready);
      expect(body, contains('await writeMadeCopy('), reason: ready);
      expect(body, isNot(contains('.writeAsBytes(')), reason: ready);
    }
    final dir = Directory.systemTemp.createTempSync('made_copy');
    addTearDown(() => dir.deleteSync(recursive: true));
    final ok = File('${dir.path}/a.jpg');
    expect(await writeMadeCopy(ok, Uint8List.fromList([1, 2, 3])), isTrue);
    expect(ok.readAsBytesSync(), [1, 2, 3]);
    // a write that fails, as a full phone's does
    final no = File('${dir.path}/gone/b.jpg');
    expect(await writeMadeCopy(no, Uint8List.fromList([1, 2, 3])), isFalse);
    expect(no.existsSync(), isFalse);
  });
}
