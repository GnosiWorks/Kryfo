// SPDX-License-Identifier: GPL-3.0-or-later
// the home's inbox pin follows the inbox, not the developer's own phone: a
// computer linked to it shows the pin too. pumping the whole shell would
// prove nothing more than what it hands the home
import 'package:flutter_test/flutter_test.dart';

import 'source_body.dart';

void main() {
  test('the shell hands the home the inbox count wherever the inbox shows', () {
    final shell = sourceOf('lib/app/shell.dart');
    expect(
      shell,
      contains('support: appState.devInbox ? appState.supportWaiting : null,'),
    );
    expect(shell, isNot(contains('appState.devMode ? appState.support')));
  });
}
