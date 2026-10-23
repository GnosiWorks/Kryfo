// SPDX-License-Identifier: GPL-3.0-or-later
// the one reading of the connection that the home pill and the tor sheet
// both show. each takes its words, colour and route picture from here, so
// the two cannot say different things
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'l10n/l10n.dart';
import 'l10n/numbers.dart' show percent;
import 'pill_grace.dart';
import 'widgets/motion.dart' show GraphHold, TorStatus;

/// how long a bare connecting may stand before it says how far tor is
const pillPatience = Duration(seconds: 30);

/// how long relay mode's relay may fail before the pill says so, the
/// spell after which the engine reads an onion route down
const kRelayDownAfter = Duration(seconds: 20);

enum LinkKind {
  /// no network
  offline,

  /// tor stopped on purpose, between check-ins
  off,

  /// tor starting, early on
  connecting,

  /// tor starting for a while: how far it is
  climbing,

  /// tor's route is up and no relay has answered through it
  relayWait,

  /// a relay answered through tor, or did a moment ago
  ready,

  /// relay mode, its relay answering
  relay,

  /// relay mode, its relay not answering
  relayDown,

  /// fast mode
  fast,
}

@immutable
class LinkView {
  const LinkView({
    required this.kind,
    required this.status,
    required this.pct,
    this.held = false,
    this.recheckAt,
  });

  final LinkKind kind;

  /// tor's own status, as the engine said it
  final TorStatus status;
  final int pct;

  /// ready only through the grace of a short drop
  final bool held;

  /// when the reading changes by time alone, null when it does not
  final DateTime? recheckAt;

  /// the pill's words
  String get text => switch (kind) {
    LinkKind.offline => l10n.appOffline,
    LinkKind.off => l10n.appTorOff,
    LinkKind.connecting => l10n.appConnecting2,
    LinkKind.climbing => l10n.appConnecting(percent(pct / 100)),
    LinkKind.relayWait => l10n.appWaitingForARelay,
    LinkKind.ready => l10n.appTorReady,
    LinkKind.relay => l10n.appViaRelay,
    LinkKind.relayDown => l10n.appRelayNotAnswering,
    LinkKind.fast => l10n.appFast,
  };

  /// what a screen reader hears, once per change of kind: a climbing
  /// percent is not a new state
  String get spoken => kind == LinkKind.climbing ? l10n.appConnecting2 : text;

  /// the sheet's line: the pill's words, and for a ready route how far tor
  /// has published us
  String get line {
    if (kind == LinkKind.off) return l10n.appTorIsOff;
    if (kind != LinkKind.ready) return text;
    return switch (status) {
      TorStatus.reachable => l10n.appConnectedRoutedThrough3,
      TorStatus.publishing => l10n.appReadyToSendPublishing,
      TorStatus.bootstrapped => l10n.appReadyToSendFinishing,
      _ => l10n.appTorReady,
    };
  }

  /// the sheet's line as a screen reader hears it
  String get spokenLine => kind == LinkKind.climbing ? spoken : line;

  /// the sheet's explanation under its line, null when nothing needs one
  String? get detail => switch (kind) {
    LinkKind.off => l10n.appTorIsOffTurn,
    LinkKind.offline => l10n.onboardingKryfoBuildsAPrivateRouteBefore,
    LinkKind.relayWait => l10n.appTorNoRelayYet,
    LinkKind.ready when status == TorStatus.reachable => null,
    _ => l10n.appTheFirstConnectionTakes,
  };

  /// another send mode is a way out of anything but no network
  bool get offerModes => detail != null && kind != LinkKind.offline;

  GraphHold get graph => switch (kind) {
    LinkKind.offline => GraphHold.offline,
    LinkKind.relayWait => GraphHold.relay,
    _ => GraphHold.none,
  };

  /// the stage the route picture shows. a ready held through a bounce
  /// keeps the route up rather than starting it over
  TorStatus get graphStatus =>
      kind == LinkKind.ready && status.index < TorStatus.bootstrapped.index
      ? TorStatus.bootstrapped
      : status;

  /// the route the send mode uses carries, or did a moment ago: what every
  /// screen that says connected means
  bool get connected =>
      kind == LinkKind.ready || kind == LinkKind.relay || kind == LinkKind.fast;

  /// the dot pulses only while tor is still coming up
  bool get pulsing => kind == LinkKind.connecting || kind == LinkKind.climbing;

  @override
  bool operator ==(Object other) =>
      other is LinkView &&
      other.kind == kind &&
      other.status == status &&
      other.pct == pct &&
      other.held == held;

  @override
  int get hashCode => Object.hash(kind, status, pct, held);

  @override
  String toString() => 'LinkView($kind, $status, $pct%, held: $held)';
}

/// the reading for one moment. [usable] is the engine's verdict that a relay
/// answered through tor (AppState.torUsable), [usableAt] when the status
/// poll last saw it, [tryingSince] when tor began trying, [relayDownSince]
/// when relay mode's relay stopped answering
LinkView linkViewOf({
  required String mode,
  required TorStatus status,
  required int pct,
  required bool online,
  required bool usable,
  required DateTime? usableAt,
  required DateTime? tryingSince,
  required DateTime? relayDownSince,
  required DateTime now,
}) {
  LinkView v(LinkKind k, {bool held = false, DateTime? at}) =>
      LinkView(kind: k, status: status, pct: pct, held: held, recheckAt: at);
  final off = status == TorStatus.off;
  // offline is offline in every mode, but tor stopped on purpose says so
  if (!online && !(mode == 'private' && off)) return v(LinkKind.offline);
  if (mode == 'balanced') {
    final since = relayDownSince;
    if (since == null) return v(LinkKind.relay);
    final at = since.add(kRelayDownAfter);
    return now.isBefore(at) ? v(LinkKind.relay, at: at) : v(LinkKind.relayDown);
  }
  if (mode == 'fast') return v(LinkKind.fast);
  if (off) return v(LinkKind.off);
  if (usable) return v(LinkKind.ready);
  final grace = pillGraceEnds(
    usable: usable,
    usableAt: usableAt,
    status: status,
    online: online,
    now: now,
  );
  if (grace != null) return v(LinkKind.ready, held: true, at: grace);
  // tor up and nothing through: exactly that, at once. only a start still
  // climbing waits a while before it shows a percent
  if (status != TorStatus.starting) return v(LinkKind.relayWait);
  // with no clock started there is nothing to count from
  final until = tryingSince?.add(pillPatience);
  if (until == null || now.isBefore(until)) {
    return v(LinkKind.connecting, at: until);
  }
  return v(LinkKind.climbing);
}

/// one timer for the moment a reading changes by time alone
class LinkClock {
  Timer? _t;
  DateTime? _for;

  void arm(DateTime? at, VoidCallback fire) {
    if (at == _for && (_t?.isActive ?? false)) return;
    cancel();
    if (at == null) return;
    _for = at;
    final left = at.difference(DateTime.now());
    _t = Timer(
      left.isNegative ? Duration.zero : left + const Duration(milliseconds: 50),
      () {
        _for = null;
        fire();
      },
    );
  }

  void cancel() {
    _t?.cancel();
    _t = null;
    _for = null;
  }
}
