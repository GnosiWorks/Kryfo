// SPDX-License-Identifier: GPL-3.0-or-later
// the typing indicator. in a 1:1 chat a contact sees "Typing" while you
// write to them, and you see theirs, only while both of you share it. the
// frame is a sealed signal message straight to their onion, never through
// a relay, the outbox or a first-contact address. nothing about it is
// written to disk on either phone
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';
import 'router.dart' show RouteTo;

/// the envelope's word for a typing frame, and for what a phone understands
const kTypingWire = 'ty';
const kCapsWire = 'cp';

/// the names a capability list may hold, and what this build puts on
/// every 1:1 frame it seals
const kCapTyping = 'ty';
const kKnownCaps = {kCapTyping};
const kMyCaps = [kCapTyping];

// a list longer than this is no phone's, and is read as none
const kCapsMost = 16;

/// at most one frame to a chat this often
const kTypingEvery = Duration(seconds: 5);

/// how long a frame shows. a second over the sender's gap, so tor's
/// jitter does not blink it off between two frames
const kTypingShowFor = Duration(seconds: 7);

/// how long a failed send holds the next ones to that peer, step by step
const kTypingBackoff = [
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
];

/// a typing frame: no text, no uid, no sender fields. 'w' orders it
/// against the sender's messages. the seal adds 'ss' and 'cp' and fills it
/// to the size a short text is
String wrapTyping({required int writtenAt}) =>
    'halo/1:{"$kTypingWire":1,"w":$writtenAt}';

/// the capability list as the wire has it: the names this build knows,
/// null when there is none or it is no list of names
List<String>? capsFromWire(Object? raw) {
  if (raw is! List || raw.length > kCapsMost) return null;
  if (raw.any((e) => e is! String)) return null;
  return [
    for (final e in raw)
      if (kKnownCaps.contains(e)) e as String,
  ];
}

/// [body], a 1:1 frame's json, with this phone's list on it
void capsPut(Map<String, dynamic> body) => body[kCapsWire] = kMyCaps;

/// caps as a contact row keeps them
String capsText(List<String> caps) => (caps.toSet().toList()..sort()).join(',');

Set<String> capsOfText(String? s) => {
  for (final c in (s ?? '').split(','))
    if (kKnownCaps.contains(c)) c,
};

/// what a contact row's caps become after a 1:1 frame written at
/// [written], or null when they stay. [carried]: the list it had, null for
/// none. [counts]: a message of theirs, which every phone with the list
/// puts it on. [at] is when the row last changed by their clock, negative
/// when that frame came without a list, so a late older frame changes
/// nothing. the row is written only when what it says changes
({String caps, int at})? capsAfter(
  String was,
  int at, {
  required List<String>? carried,
  required bool counts,
  int? written,
}) {
  if (carried == null && !counts) return null;
  final next = carried == null ? '' : capsText(carried);
  if (written == null || written <= 0) {
    // a version from before 'w' has no list either
    return carried == null && was.isNotEmpty ? (caps: '', at: at) : null;
  }
  if (next == was || written <= at.abs()) return null;
  return (caps: next, at: carried == null ? -written : written);
}

/// the switch, the pace and the board, as the app state holds them
class Typing {
  Typing({DateTime Function()? clock, TypingBoard? board})
    : pacer = TypingPacer(clock: clock),
      board = board ?? TypingBoard();

  final TypingPacer pacer;
  final TypingBoard board;
  // the everyday identity's switch, read at the start
  bool on = true;
  bool watching = false;
}

// ---- the switch ----

const kTypingOnKey = 'kryfo.typing.on';

/// on by default. each identity has its own; a vault reads the one it
/// extends, and the decoy's changes nothing
Future<bool> loadTypingOn([HaloContainer c = HaloContainer.everyday]) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(c.key(kTypingOnKey)) ?? true;
}

Future<void> saveTypingOn(
  bool on, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(c.key(kTypingOnKey), on);
}

// ---- gates ----

/// what a typing frame to a chat needs, every one of it
class TypingSendFacts {
  const TypingSendFacts({
    required this.switchOn,
    required this.decoy,
    required this.held,
    required this.locked,
    required this.inFront,
    required this.onScreen,
    required this.oneToOne,
    required this.accepted,
    required this.backPaired,
    required this.blocked,
    required this.peerCan,
    required this.hasOnion,
    required this.privateRoute,
    required this.torUsable,
    required this.linkUp,
    required this.userEdit,
    required this.nonEmpty,
    this.bridges = false,
    this.archived = false,
  });

  final bool switchOn;
  // a decoy session, or a decoy over the everyday one
  final bool decoy;
  // the everyday identity is held quiet, or being wiped
  final bool held;
  final bool locked;
  final bool inFront;
  // the chat is the one open on screen
  final bool onScreen;
  // a contact's chat: no group, room, notes, saved or developer's chat
  final bool oneToOne;
  final bool accepted;
  final bool backPaired;
  // either way this phone knows of
  final bool blocked;
  // their phone has said it understands typing
  final bool peerCan;
  final bool hasOnion;
  final bool privateRoute;
  final bool torUsable;
  final bool linkUp;
  // a keystroke or a paste, never a draft put back or words handed in
  final bool userEdit;
  final bool nonEmpty;
  // tor goes through a bridge: the network is one to keep typing from
  final bool bridges;
  final bool archived;
}

bool typingMaySend(TypingSendFacts f) =>
    f.switchOn &&
    !f.decoy &&
    !f.held &&
    !f.locked &&
    f.inFront &&
    f.onScreen &&
    f.oneToOne &&
    f.accepted &&
    f.backPaired &&
    !f.blocked &&
    f.peerCan &&
    f.hasOnion &&
    f.privateRoute &&
    f.torUsable &&
    f.linkUp &&
    f.userEdit &&
    f.nonEmpty &&
    !f.bridges &&
    !f.archived;

/// what a typing frame that came in needs before it shows
class TypingShowFacts {
  const TypingShowFacts({
    required this.viaOnion,
    required this.switchOn,
    required this.privateRoute,
    required this.decoy,
    required this.locked,
    required this.inFront,
    required this.route,
    required this.contact,
    required this.blocked,
    required this.dev,
    required this.group,
    required this.written,
    required this.floor,
    this.bridges = false,
    this.archived = false,
  });

  // it came in through the onion door, opened under a known session
  final bool viaOnion;
  final bool switchOn;
  final bool privateRoute;
  final bool decoy;
  final bool locked;
  final bool inFront;
  final RouteTo route;
  // an accepted, back-paired contact's row in the container it routes to
  final bool contact;
  final bool blocked;
  final bool dev;
  final bool group;
  // its 'w', and the newest 'w' of a message of theirs shown since
  final int? written;
  final int floor;
  final bool bridges;
  final bool archived;
}

bool typingMayShow(TypingShowFacts f) =>
    f.viaOnion &&
    f.switchOn &&
    f.privateRoute &&
    !f.decoy &&
    !f.locked &&
    f.inFront &&
    (f.route == RouteTo.everyday || f.route == RouteTo.vault) &&
    f.contact &&
    !f.blocked &&
    !f.dev &&
    !f.group &&
    f.written != null &&
    f.written! > f.floor &&
    !f.bridges &&
    !f.archived;

/// what a change of the composer's words says: null for none (the cursor
/// moved). [byApp]: the app put them there, a draft put back or words
/// handed in. only a keystroke or a paste in the focused field is an edit
({bool userEdit, bool nonEmpty})? composerEdit(
  String was,
  String now, {
  required bool byApp,
  required bool focused,
}) => now == was
    ? null
    : (userEdit: !byApp && focused, nonEmpty: now.trim().isNotEmpty);

// ---- sending pace ----

/// when a chat may send. a frame goes at the edit that comes once
/// [kTypingEvery] has passed since the last, never on a timer of its own:
/// one stops typing, and the other side clears [kTypingShowFor] after the
/// last frame. a send in flight holds the next, a failed one holds that
/// peer for a while
class TypingPacer {
  TypingPacer({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _last = <String, DateTime>{};
  final _flying = <String>{};
  final _fails = <String, int>{};
  final _heldTill = <String, DateTime>{};

  /// [chat] may send now. true takes the slot: [done] or [spent] follows
  bool take(String chat, {required String peer}) {
    final now = _clock();
    if (_flying.contains(chat)) return false;
    final held = _heldTill[peer];
    if (held != null && now.isBefore(held)) return false;
    final last = _last[chat];
    if (last != null && now.difference(last) < kTypingEvery) return false;
    _last[chat] = now;
    _flying.add(chat);
    return true;
  }

  /// the slot [take] gave went unused: a gate held, or the seal would not.
  /// asked again after the same gap, as gates change slowly
  void spent(String chat) => _flying.remove(chat);

  /// the send [take] let go is over
  void done(String chat, {required String peer, required bool ok}) {
    _flying.remove(chat);
    if (ok) {
      _fails.remove(peer);
      _heldTill.remove(peer);
      return;
    }
    final n = (_fails[peer] ?? 0) + 1;
    _fails[peer] = n;
    final step = kTypingBackoff[(n - 1).clamp(0, kTypingBackoff.length - 1)];
    _heldTill[peer] = _clock().add(step);
  }

  /// a new route or a new tor: what failed before may go now
  void freshRoute() {
    _fails.clear();
    _heldTill.clear();
  }

  @visibleForTesting
  void reset() {
    _last.clear();
    _flying.clear();
    freshRoute();
  }

  @visibleForTesting
  Duration? heldFor(String peer) {
    final t = _heldTill[peer];
    return t?.difference(_clock());
  }
}

// ---- what shows ----

/// who is typing now, by chat key (HaloContainer.chatKey). in memory only,
/// and apart from the app state's notifier, so a frame repaints the one
/// header and the one row that show it
class TypingBoard {
  TypingBoard({Timer Function(Duration, void Function())? timer})
    : _timer = timer ?? Timer.new;

  final Timer Function(Duration, void Function()) _timer;
  final _shown = <String, ValueNotifier<bool>>{};
  final _ends = <String, Timer>{};
  final _floor = <String, int>{};

  /// whether [key] shows typing, to listen to
  ValueListenable<bool> of(String key) =>
      _shown.putIfAbsent(key, () => ValueNotifier(false));

  bool showing(String key) => _shown[key]?.value ?? false;

  /// the newest 'w' of their messages shown in [key] since the start
  int floorOf(String key) => _floor[key] ?? 0;

  /// a frame from [key]'s contact: it shows, until [kTypingShowFor] from now
  void heard(String key) {
    _ends.remove(key)?.cancel();
    _ends[key] = _timer(kTypingShowFor, () => _off(key));
    (of(key) as ValueNotifier<bool>).value = true;
  }

  /// a message of theirs shown in [key]: what showed goes, and no frame
  /// written before it shows after it
  void message(String key, int? writtenAt) {
    if (writtenAt != null && writtenAt > floorOf(key)) {
      _floor[key] = writtenAt;
    }
    _off(key);
  }

  /// everything off: a lock, a vault shut, a switch of session, the switch
  /// off, a route off the onion, the app sent to the back, a wipe
  void clearAll() {
    for (final k in _ends.keys.toList()) {
      _off(k);
    }
  }

  void _off(String key) {
    _ends.remove(key)?.cancel();
    final n = _shown[key];
    if (n != null) n.value = false;
  }
}
