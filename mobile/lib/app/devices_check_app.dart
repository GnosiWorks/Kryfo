// SPDX-License-Identifier: GPL-3.0-or-later
// a linked computer's start check in the app (link_check.dart): held from
// the moment its role is read, before the home paints, until its phone's
// pair was read to the bottom and opened. a removal found wipes it, a
// list that still names it lets everything held go. on a phone nothing
// here runs

part of '../main.dart';

// a removal taken: nothing more leaves while the wipe runs
bool _linkRemoved = false;

// the device state loaded (or failed to): the check reads nothing before
bool _devicesBooted = false;

bool _linkCheckRunning = false;

// the relay polls a drain waits on, each completed once its pass is done
final _afterPoll = <Completer<void>>[];

/// nothing of this linked computer leaves: its start check is not done,
/// or its phone removed it
bool get linkSendsHeld => linkCheck.value != null || _linkRemoved;

// the engine's own hold: what it sends again by itself goes nowhere either
@visibleForTesting
void Function(bool on) engineSendHold = (on) => engine.sendHold(on);

// a removal taken: held here and in the engine, for good
void _linkRemovedNow() {
  _linkRemoved = true;
  engineSendHold(true);
}

@visibleForTesting
void linkCheckResetForTest() {
  linkCheck.value = null;
  _linkRemoved = false;
  _devicesBooted = false;
  _linkCheckRunning = false;
  _afterPoll.clear();
}

@visibleForTesting
set devicesBootedForTest(bool on) => _devicesBooted = on;

@visibleForTesting
bool get linkRemovedForTest => _linkRemoved;

/// a linked device's end, as a removal or its own check brings it
@visibleForTesting
Future<void> linkedEndsForTest(LinkedEnd why) => _linkedEnds(why);

/// the role read as the boot starts, before the home paints: a linked
/// computer is held from here on, and its check starts
Future<void> _linkHoldAtStart() async {
  if (!linkedDevicesOn) return;
  try {
    _linkedRole = await linkedRoleOf(await live.open());
  } catch (e) {
    // read again before tor and by the device state; checked from there
    dlog('linked: role not read at the start (${e.runtimeType})');
    return;
  }
  _linkCheckStart();
}

// the check, once per process, on a linked computer only
void _linkCheckStart() {
  if (!linkedRole || _linkCheckRunning) return;
  _linkCheckRunning = true;
  linkCheck.value ??= LinkCheckStage.checking;
  engineSendHold(true);
  unawaited(_linkCheckOf().run());
}

LinkCheck _linkCheckOf() => LinkCheck(
  stage: linkCheck,
  standing: () async => _devicesBooted ? await _linkedStanding() : null,
  caught: _phonePairCaught,
  drained: _relayDrained,
  removed: _linkedEnds,
  confirmed: () {
    dlog('linked: still on my phone\'s list');
    if (!_linkRemoved) engineSendHold(false);
    appState._resumeEveryday();
    appState.notifyListeners();
  },
  over: () => haloWiping || deviceUnlinked.value != null,
  online: () => appState.online,
  routeUp: () => appState.linkUp,
);

/// the check as the app runs it, for a test's stand-ins
@visibleForTesting
LinkCheck linkCheckForTest({
  Future<LinkCaught> Function()? caught,
  Future<bool> Function()? drained,
  DateTime Function()? clock,
  Future<void> Function(Duration)? wait,
  bool Function()? online,
  bool Function()? routeUp,
}) {
  final c = _linkCheckOf();
  return LinkCheck(
    stage: c.stage,
    standing: c.standing,
    caught: caught ?? c.caught,
    drained: drained ?? c.drained,
    removed: c.removed,
    confirmed: c.confirmed,
    over: c.over,
    online: online ?? c.online,
    routeUp: routeUp ?? c.routeUp,
    clock: clock,
    wait: wait,
  );
}

// the pair my phone writes to this device on: its opener address, which
// its last word to a removed device may take, and the seeded one when a
// seed is held. listenAll listens on the same
Future<List<String>> _phonePairArgs() async {
  final m = await _devMeOf(kMainIdent);
  if (m == null || m.device == 1) return const [];
  final identity = devHex(m.identity);
  final pair = '${identity.substring(2)}/1/${m.device}';
  final s = await (await live.open()).query(
    'pairs',
    columns: ['seed'],
    where: 'ident = ? AND peer = ? AND their_device = 1 AND my_device = ?',
    whereArgs: [kMainIdent, identity, m.device],
    limit: 1,
  );
  final seed = s.isEmpty ? null : s.first['seed'];
  return [
    pair,
    if (seed is List<int> && seed.length == 32) '$pair.${devHex(seed)}',
  ];
}

Future<LinkCaught> _phonePairCaught() async {
  if (!_devicesBooted || _deviceReceive == null) return LinkCaught.none;
  final args = await _phonePairArgs();
  if (args.isEmpty) return LinkCaught.none;
  final got = [for (final a in args) engine.addrCaught(kMainIdent, a)];
  if (got.every((g) => g == '1')) return LinkCaught.all;
  if (got.every((g) => g == '1' || g == 'p')) return LinkCaught.some;
  return LinkCaught.none;
}

// two full passes of the relay poll that began after this: the first
// takes what the walk left in the inbox, the second what a walk still
// ending held back a moment longer
Future<bool> _relayDrained() async {
  for (var i = 0; i < 2; i++) {
    final c = Completer<void>();
    _afterPoll.add(c);
    try {
      await c.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _afterPoll.remove(c);
      return false;
    }
  }
  return true;
}

// a relay poll begins: the drains waiting on it
List<Completer<void>> _pollBegins() {
  final w = [..._afterPoll];
  _afterPoll.clear();
  return w;
}

void _pollEnds(List<Completer<void>> w) {
  for (final c in w) {
    if (!c.isCompleted) c.complete();
  }
}

/// a test's relay poll pass
@visibleForTesting
void relayPollPassForTest() => _pollEnds(_pollBegins());
