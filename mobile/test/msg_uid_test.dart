// SPDX-License-Identifier: GPL-3.0-or-later
// message, group and room ids: random, never the clock, and in the shape
// every other part of the app already takes
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show newMsgUid;

void main() {
  test('ids made one after the other all differ', () {
    final ids = {for (var i = 0; i < 5000; i++) newMsgUid()};
    expect(ids.length, 5000);
  });

  test('an id is lower case base36, 14 characters', () {
    for (var i = 0; i < 200; i++) {
      expect(newMsgUid(), matches(RegExp(r'^[0-9a-z]{14}$')));
    }
  });

  test('ids made in the same moment share no leading part', () {
    final ids = [for (var i = 0; i < 50; i++) newMsgUid()];
    final heads = {for (final u in ids) u.substring(0, 4)};
    expect(heads.length, greaterThan(45));
  });

  test('every character turns up in every place', () {
    final seen = List.generate(14, (_) => <String>{});
    for (var i = 0; i < 3000; i++) {
      final u = newMsgUid();
      for (var j = 0; j < 14; j++) {
        seen[j].add(u[j]);
      }
    }
    for (final s in seen) {
      expect(s.length, 36);
    }
  });

  test('the chat screens make their ids with the same function', () {
    for (final f in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src.contains('_newMsgUid'), isFalse, reason: f);
      expect(src.contains('newMsgUid()'), isTrue, reason: f);
    }
  });
}
