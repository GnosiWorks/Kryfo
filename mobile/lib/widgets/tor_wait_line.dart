// SPDX-License-Identifier: GPL-3.0-or-later
// rooms and pairing codes go through tor on every route (engine
// laneKeepsTor). on fast with tor not up yet they wait, and say why
import '../l10n/l10n.dart';
import '../main.dart' show AppState, appState, AppStateRoute;

/// the line, on fast while tor is not connected; null otherwise. tor's own
/// word counts, not the direct route's
String? torWaitLine([AppState? app]) {
  final a = app ?? appState;
  return torWaitLineFor(sendMode: a.sendMode, torUp: a.torCarries);
}

String? torWaitLineFor({required String sendMode, required bool torUp}) =>
    sendMode != 'private' && !torUp ? l10n.fastRoomsWaitForTor : null;
