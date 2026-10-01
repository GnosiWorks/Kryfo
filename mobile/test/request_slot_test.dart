// SPDX-License-Identifier: GPL-3.0-or-later
// before someone accepts, two things can be sent to them. a file that is
// not sent, because it could not be cleaned or the developer chat would not
// start, gives its slot back, so the composer does not lock on nothing
import 'package:flutter_test/flutter_test.dart';

import 'source_body.dart';

void main() {
  final body = bodyOf(
    sourceOf('lib/screens/chat_screen.dart'),
    'Future<void> _sendFileFrom(',
  );

  test('every way out after the slot is taken gives it back', () {
    final taken = body.indexOf('_sentCount++');
    final sent = body.indexOf('session.saveMessage(');
    expect(taken, greaterThan(0));
    expect(sent, greaterThan(taken));
    final between = body.substring(taken, sent);
    final outs = 'return;'.allMatches(between).length;
    expect(outs, 3);
    expect('giveBack();'.allMatches(between).length, outs);
  });

  test('and gives back only what it took', () {
    expect(body, contains('final slot = _requestPending;'));
    expect(
      body,
      contains('if (slot && mounted) setState(() => _sentCount--);'),
    );
  });
}
