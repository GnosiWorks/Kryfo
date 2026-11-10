// SPDX-License-Identifier: GPL-3.0-or-later
// rooms and pairing codes go through tor on every route: on fast with tor
// not up they say why they wait, and nowhere else
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show AppState, AppStateRoute;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:kryfo/widgets/tor_wait_line.dart';

void main() {
  test('only on fast while tor is not connected', () {
    expect(
      torWaitLineFor(sendMode: 'balanced', torUp: false),
      l10n.fastRoomsWaitForTor,
    );
    expect(torWaitLineFor(sendMode: 'balanced', torUp: true), isNull);
    // the private route waits on tor for everything, and says so already
    expect(torWaitLineFor(sendMode: 'private', torUp: false), isNull);
  });

  test('tor connected with the direct route down says nothing', () {
    final app = AppState()..sendModeForTest = 'balanced';
    app.setTorStatusForTest(TorStatus.bootstrapped);
    app.setRouteOKForTest(false);
    expect(torWaitLine(app), isNull);
    app.setTorStatusForTest(TorStatus.starting);
    expect(torWaitLine(app), l10n.fastRoomsWaitForTor);
  });
}
