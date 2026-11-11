// SPDX-License-Identifier: GPL-3.0-or-later
// asking the registry about a handle and claiming it: the handle screen and
// the onboarding's name step share these checks, so both say the same

import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'handle_repoint.dart' show claimSeen;
import 'invite_share.dart' show readyInvite;
import 'main.dart'
    show
        appState,
        engine,
        linkedRole,
        sessionQuiet,
        AppStateProfile,
        AppStateRoute;
import 'quiet_wait.dart';

final handleShape = RegExp(r'^[a-z0-9_]{3,20}$');

/// the invite a claim hands the registry. a test hands in its own
@visibleForTesting
Future<String?> Function() claimInvite = readyInvite;

const _unreached = 'error: bad answer from the registry';

/// what a check says while tor does not carry: the registry was not asked
const kNoTor = 'error: no tor';

/// names to offer for [h] when it is taken: the name with a few random
/// digits, cut so the whole still fits the rule. nothing of the person in it
List<String> handleCandidates(String h, Random r, {int n = 3}) {
  final out = <String>[];
  var guard = 0;
  while (out.length < n && guard++ < 20) {
    final digits = 2 + r.nextInt(2);
    final tail =
        '${r.nextInt(9) + 1}'
        '${List.generate(digits - 1, (_) => r.nextInt(10)).join()}';
    final sep = r.nextBool() ? '_' : '';
    final room = 20 - sep.length - tail.length;
    final base = h.length > room ? h.substring(0, room) : h;
    final c = '$base$sep$tail';
    if (handleShape.hasMatch(c) && c != h && !out.contains(c)) out.add(c);
  }
  return out;
}

/// the registry's answer for a name: a test hands in its own
@visibleForTesting
Future<String> Function(String handle)? handleCheckForTest;

/// claims on their way to the registry. while one runs the key must stay:
/// the registry may already hold this key's invite under the name
final claimsInFlight = ValueNotifier<int>(0);
bool get claimInFlight => claimsInFlight.value > 0;

class HandleClaimer extends ChangeNotifier {
  final TextEditingController ctrl;
  HandleClaimer(this.ctrl);

  /// '', 'shape', 'checking', 'free', 'taken', or the registry's error
  String state = '';

  /// a name the registry said is free, offered while the typed one is
  /// taken. null until one is found
  String? suggestion;
  final _random = Random.secure();
  bool busy = false;

  /// a registry call past [slowAfter]: over a cold circuit it can take most
  /// of a minute, and the page says so rather than look stuck
  bool slow = false;
  static const slowAfter = Duration(seconds: 10);

  Timer? _debounce;
  Timer? _slowTimer;
  bool _gone = false;

  String get typed => ctrl.text.trim().toLowerCase();
  bool get free => state == 'free';

  void _changed() {
    if (!_gone) notifyListeners();
  }

  void asking(bool on) {
    _slowTimer?.cancel();
    slow = false;
    if (on) {
      _slowTimer = Timer(slowAfter, () {
        slow = true;
        _changed();
      });
    }
  }

  void reset() {
    _debounce?.cancel();
    asking(false);
    state = '';
    suggestion = null;
    _changed();
  }

  void onTyped(String v) {
    _debounce?.cancel();
    asking(false);
    suggestion = null;
    final h = v.trim().toLowerCase();
    if (h.isEmpty) {
      state = '';
      _changed();
      return;
    }
    // a name the registry would refuse is never asked about
    if (!handleShape.hasMatch(h)) {
      state = 'shape';
      _changed();
      return;
    }
    state = 'checking';
    _changed();
    // wait for typing to stop before asking the registry
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // a quiet session checks on a lane of its own (kDecoyLooksUp), as
      // its lookups do, or answers as an unreachable registry would. its
      // claim never goes
      asking(true);
      final r = await _check(h);
      if (_gone) return;
      // typed on since: the answer is for a name no longer in the field
      if (typed != h) return;
      asking(false);
      state = r;
      _changed();
      if (r == 'taken') unawaited(_suggest(h));
      _waitForTor(r == kNoTor);
    });
  }

  // a check that found no tor is asked again once tor comes up: on the
  // move from down to up, never on every change while it is up
  bool _torWatch = false;
  bool _torWas = false;
  void _waitForTor(bool on) {
    if (on == _torWatch || _gone) return;
    _torWatch = on;
    _torWas = appState.servicesReady;
    on ? appState.addListener(_torMoved) : appState.removeListener(_torMoved);
  }

  void _torMoved() {
    final up = appState.servicesReady;
    final cameUp = up && !_torWas;
    _torWas = up;
    if (!cameUp || state != kNoTor) return;
    _waitForTor(false);
    onTyped(ctrl.text);
  }

  // a quiet session checks on a lane of its own (kDecoyLooksUp), as its
  // lookups do, or answers as an unreachable registry would
  Future<String> _check(String h) async {
    final test = handleCheckForTest;
    if (test != null) return test(h);
    // the registry is reached over tor on every route: without it nothing
    // goes, and the line says tor rather than the registry
    if (!appState.servicesReady) return kNoTor;
    return !sessionQuiet
        ? await engine.handleCheck(h)
        : kDecoyLooksUp
        ? await engine.decoyHandleCheck(h)
        : await unreachedLater(_unreached);
  }

  // one free name like [h], asked of the registry before it is shown. the
  // first that is free; none when none of a few is
  Future<void> _suggest(String h) async {
    if (handleCheckForTest == null && sessionQuiet && !kDecoyLooksUp) return;
    for (final c in handleCandidates(h, _random)) {
      final String r;
      try {
        r = await _check(c);
      } catch (_) {
        return;
      }
      if (_gone || typed != h || state != 'taken') return;
      if (r == 'free') {
        suggestion = c;
        _changed();
        return;
      }
      // the registry out of reach: no more asking
      if (r != 'taken') return;
    }
  }

  /// the offered name goes into the field, and is checked as typed
  void useSuggestion() {
    final c = suggestion;
    if (c == null) return;
    ctrl.value = TextEditingValue(
      text: c,
      selection: TextSelection.collapsed(offset: c.length),
    );
    onTyped(c);
  }

  /// 'ok' once the registry holds it, or what it said. null: nothing to claim
  Future<String?> claim({String bio = ''}) async {
    final h = typed;
    // a handle is the phone's: a linked device claims none
    if (h.isEmpty || state != 'free' || busy || linkedRole) return null;
    busy = true;
    claimsInFlight.value++;
    asking(true);
    _changed();
    try {
      // same invite the qr code carries, so the registry only holds what is
      // already public. on a first start it waits for the onion: the registry
      // takes no invite without one
      final uri = sessionQuiet ? null : await claimInvite();
      final r = sessionQuiet
          ? await unreachedLater(_unreached)
          : uri == null
          ? _unreached
          : await claimSeen(
              h,
              uri,
              await engine.handleClaim(h, uri, bio),
              lookup: engine.ownHandleGetJson,
              myKey: engine.myEdPubkey,
            );
      // kept even when the page is gone: the registry already holds it
      if (r == 'ok') await appState.setMyHandle(h, bio: bio, invite: uri);
      return r;
    } finally {
      claimsInFlight.value--;
      busy = false;
      asking(false);
      _changed();
    }
  }

  /// the registry answers a quiet session after a wait like this one
  static Future<String> unreached() => unreachedLater(_unreached);

  @override
  void dispose() {
    _waitForTor(false);
    _gone = true;
    _debounce?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }
}
