// SPDX-License-Identifier: GPL-3.0-or-later
// before someone accepts, two things can be sent to them. a photo or a file
// takes its slot only once it is cleaned and the developer chat has
// started, right before its row is written: nothing that is not sent ever
// holds one
import 'package:flutter_test/flutter_test.dart';

import 'source_body.dart';

void main() {
  final src = sourceOf('lib/screens/chat_screen.dart');
  final body = bodyOf(src, 'Future<void> _sendReady(');

  test('the slot is taken only once nothing can stop the send', () {
    final start = body.indexOf('_ensureDevStarted()');
    final locked = body.indexOf('if (_requestLocked)');
    final taken = body.indexOf('_sentCount++');
    final sent = body.indexOf('session.saveMessage(');
    expect(start, greaterThan(0));
    expect(locked, greaterThan(start));
    expect(taken, greaterThan(locked));
    expect(sent, greaterThan(taken));
    expect('return;'.allMatches(body.substring(taken, sent)), isEmpty);
    // no await between the last look and the slot: a second send cannot
    // slip past the cap
    final looked = body.indexOf('}', locked);
    expect('await'.allMatches(body.substring(looked, taken)), isEmpty);
  });

  test('a file and a photo both take it there and nowhere else', () {
    for (final fn in [
      'Future<void> _sendFileFrom(',
      'Future<void> _sendOneImage(',
      'Future<_Ready?> _readyFile(',
      'Future<_Ready?> _readyPhoto(',
    ]) {
      expect(bodyOf(src, fn), isNot(contains('_sentCount')), reason: fn);
    }
    expect(
      '_sentCount++'.allMatches(bodyOf(src, 'Future<void> _sendReady(')),
      hasLength(1),
    );
  });
}
