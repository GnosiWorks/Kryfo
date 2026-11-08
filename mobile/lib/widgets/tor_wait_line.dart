// SPDX-License-Identifier: GPL-3.0-or-later
// rooms and pairing codes go through tor on every route (engine
// laneKeepsTor). on fast with tor not up yet they wait, and say why
import '../l10n/l10n.dart';
import '../main.dart' show appState, AppStateRoute;

/// the line, on fast while tor is not connected; null otherwise
String? torWaitLine() =>
    torWaitLineFor(sendMode: appState.sendMode, torUp: appState.torUsable);

String? torWaitLineFor({required String sendMode, required bool torUp}) =>
    sendMode != 'private' && !torUp ? l10n.fastRoomsWaitForTor : null;
