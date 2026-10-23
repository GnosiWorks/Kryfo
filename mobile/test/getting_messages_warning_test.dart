// SPDX-License-Identifier: GPL-3.0-or-later
// with a pin on and the message shown, the row into the notification
// choices says what that gives away in the warning's own rose, under it
import 'package:flutter_test/flutter_test.dart';

import 'source_body.dart';

void main() {
  test('the preview warning on getting messages is rose', () {
    final src = sourceOf('lib/screens/getting_messages_screen.dart');
    final at = src.indexOf('l10n.gettingMessagesWhatShows');
    expect(at, greaterThan(0));
    final after = src.substring(at);
    final warn = after.indexOf('l10n.gettingMessagesShowsMessageTextIn');
    expect(warn, greaterThan(0));
    final open = after.lastIndexOf('Unfold(', warn);
    expect(
      after.substring(open, warn),
      contains('open: lockState.lockOn && _show == NotifShow.all'),
    );
    final style = after.substring(
      warn,
      after.indexOf(')', after.indexOf('color:', warn)),
    );
    expect(style, contains('HaloColors.rose'));
    // no longer a row hint, which draws in text2
    expect(after.substring(0, warn), isNot(contains('hint:')));
  });
}
