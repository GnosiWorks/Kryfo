// SPDX-License-Identifier: GPL-3.0-or-later
// what shows of a contact typing: a frame shows for seven seconds, a later
// one moves the end, their message ends it, and every chat goes off at
// once on a lock, a vault shut, a switch of session, the switch, the route
// or the app going to the back. each container's chat is its own
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/typing.dart';

class _Timer implements Timer {
  _Timer(this.after, this.fire);
  final Duration after;
  final void Function() fire;
  var live = true;
  @override
  void cancel() => live = false;
  @override
  bool get isActive => live;
  @override
  int get tick => 0;
}

void main() {
  late List<_Timer> timers;
  late TypingBoard board;
  final a = HaloContainer.everyday.chatKey('plain-friend-here');
  final b = HaloContainer.everyday.chatKey('other-friend-here');

  setUp(() {
    timers = [];
    board = TypingBoard(
      timer: (d, f) {
        final t = _Timer(d, f);
        timers.add(t);
        return t;
      },
    );
  });

  void runOut() {
    for (final t in timers.toList()) {
      if (t.live) {
        t.live = false;
        t.fire();
      }
    }
  }

  test('a frame shows, and goes seven seconds after it came', () {
    final seen = <bool>[];
    board.of(a).addListener(() => seen.add(board.showing(a)));
    board.heard(a);
    expect(board.showing(a), isTrue);
    expect(timers.single.after, kTypingShowFor);
    expect(kTypingShowFor, const Duration(seconds: 7));
    runOut();
    expect(board.showing(a), isFalse);
    expect(seen, [true, false]);
  });

  test('a later frame moves the end', () {
    board.heard(a);
    board.heard(a);
    expect(timers.where((t) => t.live), hasLength(1));
    expect(timers.first.live, isFalse);
    expect(board.showing(a), isTrue);
  });

  test('their message ends it, and nothing written before it shows', () {
    board.heard(a);
    board.message(a, 500);
    expect(board.showing(a), isFalse);
    expect(board.floorOf(a), 500);
    board.message(a, 300);
    expect(board.floorOf(a), 500);
    expect(board.floorOf(b), 0);
  });

  test('every chat goes off at once', () {
    board.heard(a);
    board.heard(b);
    board.clearAll();
    expect(board.showing(a), isFalse);
    expect(board.showing(b), isFalse);
    expect(timers.where((t) => t.live), isEmpty);
  });

  test('the same id in another container is another chat', () {
    final v = HaloContainer.vault.chatKey('plain-friend-here');
    board.heard(v);
    expect(board.showing(v), isTrue);
    expect(board.showing(a), isFalse);
  });
}
