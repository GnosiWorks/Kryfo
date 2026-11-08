// SPDX-License-Identifier: GPL-3.0-or-later
// the status line as a computer shows it: a network that wants a sign-in is
// signed into from the browser, so no button for android's wi-fi page
import 'bridge_mode.dart';
import 'desktop/desktop_mode.dart' show onDesktop;
import 'l10n/l10n.dart';

BridgeLine deskBridgeLine(BridgeLine l) =>
    !onDesktop || l.detailKind != 'captive'
    ? l
    : BridgeLine(
        head: l.head,
        detail: l10n.bridgesThisNetworkWantsAShown,
        detailKind: l.detailKind,
        tone: l.tone,
        moving: l.moving,
        progress: l.progress,
        clockMs: l.clockMs,
        offerRelay: l.offerRelay,
      );
