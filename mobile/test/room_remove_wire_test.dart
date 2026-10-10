// SPDX-License-Identifier: GPL-3.0-or-later
// a room's remove carries the last frame the admin took from each key it
// takes out. a phone from before reads the same remove without it, and a
// remove from such a phone reads here as one that lets nothing more in
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart' show roomFrame;

final _k = 'b2' * 32;
final _j = 'c3' * 32;

GroupControl? _overTheWire(Map<String, dynamic> w) =>
    GroupControl.fromWire(jsonDecode(jsonEncode(w)));

void main() {
  test('a remove keeps the last frame of each key over the wire', () {
    final gc = GroupControl(
      type: 'remove',
      members: [_k, _j],
      lastFrames: {_k: 7},
    );
    final back = _overTheWire(gc.toWire())!;
    expect(back.type, 'remove');
    expect(back.members, [_k, _j]);
    expect(back.lastFrames, {_k: 7});
  });

  test('a remove from a phone before it has no numbers', () {
    final old = {
      't': 'remove',
      'm': [_k],
    };
    final back = _overTheWire(old)!;
    expect(back.members, [_k]);
    expect(back.lastFrames, isNull);
  });

  test('a phone before it reads every field it knows as before', () {
    final plain = GroupControl(type: 'remove', members: [_k]);
    final carried = GroupControl(
      type: 'remove',
      members: [_k],
      lastFrames: {_k: 3},
    );
    // the one key added, every other as an older version writes it
    expect(plain.toWire().containsKey('rn'), isFalse);
    expect(Map.of(carried.toWire())..remove('rn'), plain.toWire());
    // and a field it does not know is passed over, as here
    final unknown = _overTheWire({...plain.toWire(), 'zz': 1})!;
    expect(unknown.type, 'remove');
    expect(unknown.members, [_k]);
  });

  test('numbers that are not whole and above none are not read', () {
    final back = _overTheWire({
      't': 'remove',
      'm': [_k],
      'rn': {_k: '7', _j: -1, 'x': 3.5, 'y': 0},
    })!;
    expect(back.lastFrames, isNull);
    expect(
      _overTheWire({
        't': 'remove',
        'm': [_k],
        'rn': [_k, 7],
      })!.lastFrames,
      isNull,
    );
  });

  test('a room frame says its number, and nothing else reads as one', () async {
    final wrapped = await wrapMessage(
      'hi',
      groupId: 'room00000001',
      sender: SenderInfo(haloId: _k, edPub: '', onion: '', xPub: ''),
    );
    expect(unwrapMessage(wrapped).roomNumber, isNull);
    expect(unwrapMessage(roomFrame(wrapped, _k, number: 4)!).roomNumber, 4);
    expect(unwrapMessage(roomFrame(wrapped, _k)!).roomNumber, isNull);
    final j = jsonDecode(wrapped.substring('halo/1:'.length)) as Map;
    for (final bad in ['4', -2, 0, 1.5]) {
      final w = 'halo/1:${jsonEncode({...j, 'rn': bad})}';
      expect(unwrapMessage(w).roomNumber, isNull, reason: '$bad');
    }
  });
}
