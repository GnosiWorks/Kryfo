// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';

void main() {
  test('the first kryfo: argument is the launch link', () {
    expect(launchLinkOf(const []), null);
    expect(launchLinkOf(const ['--x', 'https://kryfo.app']), null);
    expect(
      launchLinkOf(const ['--x', 'KRYFO://add?a=1', 'kryfo:b']),
      'KRYFO://add?a=1',
    );
    expect(launchLinkOf(['kryfo:${'a' * 9000}']), null);
  });

  test('taken once', () {
    deskLaunchLink = 'kryfo://add?a=1';
    expect(takeDeskLaunchLink()?.scheme, 'kryfo');
    expect(takeDeskLaunchLink(), null);
  });
}
