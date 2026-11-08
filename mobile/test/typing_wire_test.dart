// SPDX-License-Identifier: GPL-3.0-or-later
// the typing frame and the list of what a phone understands, on the wire:
// a typing frame carries nothing but the word and its time, is sealed to
// the size a short text is, and the list keeps out names it does not know
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/chat_shots.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/typing.dart';
import 'package:kryfo/wire_pad.dart';

import 'old_wire/envelope_051.dart' as v051;

// a 1:1 frame as the seal takes it: the block's word and the list on it
String sealed(String wrapped) {
  final body = shotsBodyOf(wrapped)!;
  capsPut(body);
  return padSeal(shotsPut(body, const ShotsWord(on: false, at: 0)));
}

void main() {
  test('a typing frame reads back as one, and holds nothing else', () {
    final env = unwrapMessage(wrapTyping(writtenAt: 1760000000123));
    expect(env.typing, isTrue);
    expect(env.writtenAt, 1760000000123);
    expect(env.message, '');
    expect(env.msgUid, isNull);
    expect(env.senderHaloId, isNull);
    expect(env.groupId, isNull);
    expect(env.fileB64, isNull);
  });

  test('a message is no typing frame', () async {
    expect(
      unwrapMessage(await wrapMessage('hi', msgUid: 'u1')).typing,
      isFalse,
    );
    expect(unwrapMessage('halo/1:{"ty":2,"w":5}').typing, isFalse);
  });

  test('sealed, it is as long as a short text', () async {
    final typing = sealed(wrapTyping(writtenAt: 1760000000123));
    final text = sealed(
      await wrapMessage('ok', msgUid: 'abcdefabcdefabcdef', writtenAt: 1),
    );
    expect(utf8Length(typing), kSealSizes.first);
    expect(utf8Length(text), kSealSizes.first);
    expect(unwrapMessage(unpad(typing)).typing, isTrue);
  });

  test('every 1:1 frame carries the list, and it reads back', () async {
    final body = shotsBodyOf(await wrapMessage('hi', msgUid: 'u1'))!;
    capsPut(body);
    final env = unwrapMessage('halo/1:${jsonEncode(body)}');
    // with linked devices on in every build, the devices word too
    expect(env.caps, myCaps);
    expect(env.caps, contains(kCapDevices));
    expect(env.caps, contains(kCapTyping));
    expect(unwrapMessage(await wrapMessage('hi')).caps, isNull);
  });

  test('a group frame has no 1:1 body to carry it', () async {
    expect(shotsBodyOf(await wrapMessage('hi', groupId: 'g1')), isNull);
  });

  test('names it does not know are kept out, a list too long or of other '
      'things is none', () {
    expect(capsFromWire(['ty', 'sp', 'zz']), ['ty']);
    expect(capsFromWire(<Object>[]), isEmpty);
    expect(capsFromWire(List.filled(kCapsMost + 1, 'ty')), isNull);
    expect(capsFromWire(['ty', 1]), isNull);
    expect(capsFromWire('ty'), isNull);
    expect(capsFromWire({'ty': 1}), isNull);
    expect(capsFromWire(null), isNull);
  });

  test('a row keeps the list one way, whatever order it came in', () {
    expect(capsText(['ty', 'ty']), 'ty');
    expect(capsOfText('ty'), {'ty'});
    expect(capsOfText('zz,ty'), {'ty'});
    expect(capsOfText(null), isEmpty);
    expect(capsOfText(''), isEmpty);
  });

  // why the list exists: a phone from before reads a typing frame as a
  // message with no words
  test('0.5.1 reads a typing frame as an empty text', () {
    final old = v051.unwrapMessage(wrapTyping(writtenAt: 5));
    expect(old.message, '');
    expect(old.msgUid, isNull);
    expect(old.groupId, isNull);
  });

  group('what a row keeps of the list', () {
    test('a newer frame with the list sets it, one without clears it', () {
      final set = capsAfter('', 0, carried: ['ty'], counts: false, written: 10);
      expect(set, (caps: 'ty', at: 10));
      final gone = capsAfter(
        'ty',
        10,
        carried: null,
        counts: true,
        written: 20,
      );
      expect(gone, (caps: '', at: -20));
    });

    test('the same list again writes nothing', () {
      expect(
        capsAfter('ty', 10, carried: ['ty'], counts: true, written: 30),
        isNull,
      );
    });

    test('a frame written before the last change changes nothing', () {
      expect(
        capsAfter('ty', 20, carried: null, counts: true, written: 15),
        isNull,
      );
      expect(
        capsAfter('', -20, carried: ['ty'], counts: false, written: 15),
        isNull,
      );
    });

    test('a frame about something else, with no list, says nothing', () {
      expect(
        capsAfter('ty', 10, carried: null, counts: false, written: 30),
        isNull,
      );
    });

    test('a message from a version without the time clears it', () {
      expect(capsAfter('ty', 10, carried: null, counts: true), (
        caps: '',
        at: 10,
      ));
      expect(capsAfter('', 0, carried: null, counts: true), isNull);
      expect(capsAfter('', 0, carried: ['ty'], counts: false), isNull);
    });
  });
}
