// SPDX-License-Identifier: GPL-3.0-or-later
// when a chat may send a typing frame: at the first edit, then at most one
// every five seconds, none while one is in flight, and a peer that could
// not be reached is held a minute, two, then five. only a keystroke or a
// paste in the focused composer counts as an edit
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/typing.dart';

void main() {
  late DateTime now;
  late TypingPacer pace;

  setUp(() {
    now = DateTime(2026, 10, 28, 12);
    pace = TypingPacer(clock: () => now);
  });

  bool go({String chat = 'c', String peer = 'p', bool ok = true}) {
    if (!pace.take(chat, peer: peer)) return false;
    pace.done(chat, peer: peer, ok: ok);
    return true;
  }

  test('the first edit sends, the next ones wait five seconds', () {
    expect(go(), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(go(), isFalse);
    now = now.add(const Duration(milliseconds: 3999));
    expect(go(), isFalse);
    now = now.add(const Duration(milliseconds: 1));
    expect(go(), isTrue);
  });

  test('sixty seconds of typing send at most thirteen frames', () {
    var n = 0;
    for (var ms = 0; ms <= 60000; ms += 150) {
      now = DateTime(2026, 10, 28, 12).add(Duration(milliseconds: ms));
      if (go()) n++;
    }
    expect(n, lessThanOrEqualTo(13));
    expect(n, greaterThanOrEqualTo(12));
  });

  test('one in flight holds the next', () {
    expect(pace.take('c', peer: 'p'), isTrue);
    now = now.add(const Duration(seconds: 6));
    expect(pace.take('c', peer: 'p'), isFalse);
    pace.done('c', peer: 'p', ok: true);
    expect(pace.take('c', peer: 'p'), isTrue);
  });

  test('a slot left unused still waits the gap', () {
    expect(pace.take('c', peer: 'p'), isTrue);
    pace.spent('c');
    now = now.add(const Duration(seconds: 2));
    expect(go(), isFalse);
    now = now.add(const Duration(seconds: 3));
    expect(go(), isTrue);
  });

  test('chats keep their own pace', () {
    expect(go(chat: 'a', peer: 'a'), isTrue);
    expect(go(chat: 'b', peer: 'b'), isTrue);
  });

  test('a failure holds that peer a minute, then two, then five', () {
    expect(go(ok: false), isTrue);
    expect(pace.heldFor('p'), const Duration(minutes: 1));
    now = now.add(const Duration(seconds: 59));
    expect(go(), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(go(ok: false), isTrue);
    expect(pace.heldFor('p'), const Duration(minutes: 2));
    now = now.add(const Duration(minutes: 2));
    expect(go(ok: false), isTrue);
    expect(pace.heldFor('p'), const Duration(minutes: 5));
    now = now.add(const Duration(minutes: 5));
    expect(go(ok: false), isTrue);
    expect(pace.heldFor('p'), const Duration(minutes: 5));
    // another peer is not held
    expect(go(chat: 'q', peer: 'q'), isTrue);
  });

  test('a success, or a new route, lets the peer go again', () {
    expect(go(ok: false), isTrue);
    pace.freshRoute();
    expect(pace.heldFor('p'), isNull);
    now = now.add(const Duration(seconds: 5));
    expect(go(ok: false), isTrue);
    now = now.add(const Duration(minutes: 1));
    expect(go(), isTrue);
    expect(pace.heldFor('p'), isNull);
    now = now.add(const Duration(seconds: 5));
    expect(go(ok: false), isTrue);
    expect(pace.heldFor('p'), const Duration(minutes: 1));
  });

  group('what counts as an edit', () {
    test('a keystroke in the focused field', () {
      expect(composerEdit('h', 'hi', byApp: false, focused: true), (
        userEdit: true,
        nonEmpty: true,
      ));
    });

    test('a draft put back or words handed in are the app\'s', () {
      expect(
        composerEdit('', 'kept draft', byApp: true, focused: true)?.userEdit,
        isFalse,
      );
    });

    test('a change while the field has no focus is not typing', () {
      expect(
        composerEdit(
          '',
          'shared words',
          byApp: false,
          focused: false,
        )?.userEdit,
        isFalse,
      );
    });

    test('an emptied field or a moved cursor sends nothing', () {
      expect(
        composerEdit('hi', '  ', byApp: false, focused: true)?.nonEmpty,
        isFalse,
      );
      expect(composerEdit('hi', 'hi', byApp: false, focused: true), isNull);
    });
  });
}
