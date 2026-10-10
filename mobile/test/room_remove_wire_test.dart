// SPDX-License-Identifier: GPL-3.0-or-later
// a room's remove names, by a hash of each one's uid and content, the last
// messages the admin took from each key it takes out. a phone from 0.5.0 reads the same remove as it
// always did, and its own remove reads here as one that lets nothing more
// in. the 0.5.0 side is its decoder and encoder as they shipped
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart' show roomEntry, roomTextBody;

String _e(String uid) =>
    roomEntry('room00000001', uid, roomTextBody(message: uid));

// GroupControl as it shipped in v0.5.0, frozen
class _Old {
  final String type;
  final String? name;
  final List<String>? members;
  final List<Map<String, String>>? participants;
  final int? stamp;
  const _Old({
    required this.type,
    this.name,
    this.members,
    this.participants,
    this.stamp,
  });

  Map<String, dynamic> toWire() => {
    't': type,
    'n': ?name,
    'm': ?members,
    'p': ?participants,
    'v': ?stamp,
  };

  static _Old? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final membersRaw = raw['m'];
    final partsRaw = raw['p'];
    List<Map<String, String>>? parts;
    if (partsRaw is List) {
      parts = [];
      for (final e in partsRaw) {
        if (e is Map) {
          parts.add(e.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      }
    }
    final stamp = raw['v'];
    return _Old(
      type: (raw['t'] as String?) ?? '',
      name: raw['n'] as String?,
      members: membersRaw is List
          ? membersRaw.map((e) => e.toString()).toList()
          : null,
      participants: parts,
      stamp: stamp is int && stamp > 0 ? stamp : null,
    );
  }
}

final _k = 'b2' * 32;
final _j = 'c3' * 32;

Object? _overTheWire(Map<String, dynamic> w) => jsonDecode(jsonEncode(w));

void main() {
  final named = {
    _k: [_e('u1'), _e('u2')],
  };

  test('a remove keeps the messages it names over the wire', () {
    final gc = GroupControl(type: 'remove', members: [_k, _j], lateUids: named);
    final back = GroupControl.fromWire(_overTheWire(gc.toWire()))!;
    expect(back.type, 'remove');
    expect(back.members, [_k, _j]);
    expect(back.lateUids, named);
  });

  test('0.5.0 reads a new remove as the remove it always was', () {
    final gc = GroupControl(type: 'remove', members: [_k], lateUids: named);
    final old = _Old.fromWire(_overTheWire(gc.toWire()))!;
    expect(old.type, 'remove');
    expect(old.members, [_k]);
    expect(old.toWire(), {
      't': 'remove',
      'm': [_k],
    });
  });

  test('a remove from 0.5.0 names nothing, so nothing more comes in', () {
    const old = _Old(type: 'remove', members: ['k']);
    final back = GroupControl.fromWire(_overTheWire(old.toWire()))!;
    expect(back.type, 'remove');
    expect(back.members, ['k']);
    expect(back.lateUids, isNull);
  });

  test('what is not a short hash, or past the bounds, is not read', () {
    GroupControl? read(Object? lu) => GroupControl.fromWire(
      _overTheWire({
        't': 'remove',
        'm': [_k],
        'lu': lu,
      }),
    );
    expect(
      read({
        _k: ['u1', 7, _e('u1').toUpperCase()],
        _j: 'x',
      })!.lateUids,
      isNull,
    );
    expect(read([_k])!.lateUids, isNull);
    // at most 32 a key
    final many = read({
      _k: [for (var i = 0; i < 40; i++) _e('m$i')],
    })!.lateUids!;
    expect(many[_k], hasLength(32));
    // and no more keys than a group holds
    expect(
      read({
        for (var i = 0; i < 65; i++) 'k$i': [_e('u1')],
      })!.lateUids,
      isNull,
    );
  });

  test('a name is short, and holds neither the uid nor the words', () {
    final h = _e('u1');
    expect(h, hasLength(32));
    expect(h, isNot(contains('u1')));
    expect(_e('u1'), h);
    expect(_e('u2'), isNot(h));
  });
}
