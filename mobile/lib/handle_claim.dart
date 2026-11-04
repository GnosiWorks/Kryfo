// SPDX-License-Identifier: GPL-3.0-or-later
// asking the registry about a handle and claiming it: the handle screen and
// the onboarding's name step share these checks, so both say the same

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'invite_share.dart' show readyInvite;
import 'main.dart' show appState, engine, sessionQuiet, AppStateProfile;
import 'quiet_wait.dart';

final handleShape = RegExp(r'^[a-z0-9_]{3,20}$');

/// the invite a claim hands the registry. a test hands in its own
@visibleForTesting
Future<String?> Function() claimInvite = readyInvite;

const _unreached = 'error: bad answer from the registry';

/// claims on their way to the registry. while one runs the key must stay:
/// the registry may already hold this key's invite under the name
final claimsInFlight = ValueNotifier<int>(0);
bool get claimInFlight => claimsInFlight.value > 0;

class HandleClaimer extends ChangeNotifier {
  final TextEditingController ctrl;
  HandleClaimer(this.ctrl);

  /// '', 'shape', 'checking', 'free', 'taken', or the registry's error
  String state = '';
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
    _changed();
  }

  void onTyped(String v) {
    _debounce?.cancel();
    asking(false);
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
      final r = !sessionQuiet
          ? await engine.handleCheck(h)
          : kDecoyLooksUp
          ? await engine.decoyHandleCheck(h)
          : await unreachedLater(_unreached);
      if (_gone) return;
      // typed on since: the answer is for a name no longer in the field
      if (typed != h) return;
      asking(false);
      state = r;
      _changed();
    });
  }

  /// 'ok' once the registry holds it, or what it said. null: nothing to claim
  Future<String?> claim({String bio = ''}) async {
    final h = typed;
    if (h.isEmpty || state != 'free' || busy) return null;
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
          : await engine.handleClaim(h, uri, bio);
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
    _gone = true;
    _debounce?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }
}
