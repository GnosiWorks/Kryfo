// SPDX-License-Identifier: GPL-3.0-or-later
// the album field on the wire: it goes and comes back whole, a broken one
// reads as none, and 0.5.0 and 0.5.1 read an album item as the photo it is
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart';
import 'package:kryfo/message_envelope.dart';

import 'old_wire/envelope_050.dart' as v050;
import 'old_wire/envelope_051.dart' as v051;

const _id = '0123456789abcdef';

Future<String> _slice({AlbumTag? album, String caption = ''}) => wrapMessage(
  caption,
  msgUid: 'u1',
  imageB64: base64Encode([1, 2, 3, 4]),
  mediaId: 'u1',
  chunkIndex: 1,
  chunkTotal: 3,
  burnSeconds: 30,
  secure: true,
  replyTo: 'q1',
  album: album,
  writtenAt: 1700000000000,
);

void main() {
  test('the tag goes and comes back', () async {
    const tag = AlbumTag(_id, 5, 2);
    final env = unwrapMessage(await _slice(album: tag, caption: 'hi'));
    expect(env.album, tag);
    expect(env.message, 'hi');
    expect(env.msgUid, 'u1');
    expect(env.chunkIndex, 1);
    expect(env.secure, isTrue);
  });

  test('the field is small and on the wire as al', () async {
    final w = await _slice(album: const AlbumTag(_id, 3, 0));
    final body = jsonDecode(w.substring('halo/1:'.length)) as Map;
    expect(body['al'], {'id': _id, 'n': 3, 'i': 0});
  });

  test('no album, no field', () async {
    final w = await _slice();
    expect(w.contains('"al"'), isFalse);
    expect(unwrapMessage(w).album, isNull);
  });

  test('a broken tag reads as none', () {
    for (final bad in <Object?>[
      'x',
      {'id': _id, 'n': 1, 'i': 0},
      {'id': _id, 'n': 3, 'i': 3},
      {'id': _id, 'n': 3, 'i': -1},
      {'id': _id, 'n': 99, 'i': 0},
      {'id': _id, 'n': 3.5, 'i': 0},
      {'id': 'ZZZZ', 'n': 3, 'i': 0},
      {'id': 7, 'n': 3, 'i': 0},
      {'n': 3, 'i': 0},
    ]) {
      final w = 'halo/1:${jsonEncode({'m': '', 'u': 'u1', 'al': bad})}';
      expect(unwrapMessage(w).album, isNull, reason: '$bad');
    }
  });

  test('a row keeps the same tag', () {
    const tag = AlbumTag(_id, 4, 3);
    expect(AlbumTag.ofRow(tag.toRow()), tag);
    expect(AlbumTag.ofRow(const {}), isNull);
  });

  group('older phones', () {
    test('0.5.0 reads an album item as the photo it is', () async {
      final w = await _slice(album: const AlbumTag(_id, 5, 0), caption: 'c');
      final plain = await _slice(caption: 'c');
      final a = v050.unwrapMessage(w);
      final b = v050.unwrapMessage(plain);
      expect(a.message, 'c');
      expect(a.msgUid, b.msgUid);
      expect(a.imageB64, b.imageB64);
      expect(a.mediaId, b.mediaId);
      expect(a.chunkIndex, b.chunkIndex);
      expect(a.chunkTotal, b.chunkTotal);
      expect(a.burnSeconds, b.burnSeconds);
      expect(a.secure, b.secure);
      expect(a.replyTo, b.replyTo);
      expect(a.writtenAt, b.writtenAt);
    });

    test('0.5.1 reads an album item as the photo it is', () async {
      final w = await _slice(album: const AlbumTag(_id, 5, 4));
      final plain = await _slice();
      final a = v051.unwrapMessage(w);
      final b = v051.unwrapMessage(plain);
      expect(a.message, '');
      expect(a.msgUid, b.msgUid);
      expect(a.imageB64, b.imageB64);
      expect(a.mediaId, b.mediaId);
      expect(a.chunkIndex, b.chunkIndex);
      expect(a.chunkTotal, b.chunkTotal);
      expect(a.burnSeconds, b.burnSeconds);
      expect(a.secure, b.secure);
      expect(a.replyTo, b.replyTo);
      expect(a.writtenAt, b.writtenAt);
    });

    test('a video item reads as a file there', () async {
      final w = await wrapMessage(
        '',
        msgUid: 'v1',
        fileB64: base64Encode([9, 9]),
        fileName: 'video.mp4',
        album: const AlbumTag(_id, 2, 1),
      );
      final a = v050.unwrapMessage(w);
      final b = v051.unwrapMessage(w);
      expect([a.fileName, b.fileName], ['video.mp4', 'video.mp4']);
      expect(a.fileB64, base64Encode([9, 9]));
      expect(b.fileB64, base64Encode([9, 9]));
      expect([a.msgUid, b.msgUid], ['v1', 'v1']);
    });
  });
}
