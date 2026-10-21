// SPDX-License-Identifier: GPL-3.0-or-later
// how both chats send what the preview gives back: its bubbles show at
// once and the cleaning follows; the camera's clip goes through the
// preview too; before they accept, the preview takes only the slots left;
// a big file is asked about inside the preview, not after it
import 'package:flutter_test/flutter_test.dart';

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

  test('before they accept, the preview takes only the slots left', () {
    final body = bodyOf(chat, 'Future<MediaSendResult?> _preview(');
    expect(body, contains('final room = _roomLeft;'));
    expect(body, contains('max: room,'));
    expect(body, contains('request: room < kPickMax,'));
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
}
