// SPDX-License-Identifier: GPL-3.0-or-later
// a pairing by an eight digit code (identity v4 6): the sharer shows the
// code, the joiner types it, the engine runs cpace over the relays and each
// side gets the other's one-time invite once both tags held. then each
// person sees who it is and adds them: the joiner starts the session, the
// sharer waits for its opener on the invite it sealed (3.4b). the code,
// the keys and the run stay in the engine; this side holds a handle.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// the engine's answer when no relay took a share or answered a lookup
const pairUnreached = 'error: unreached';

/// as long as a code is shown for
const kPairCodeLife = Duration(minutes: 10);

/// how long a joiner looks for an offer before it says nothing is there
const kPairLookFor = Duration(seconds: 60);

/// a joiner waiting this long on its answer is told what to check
const kPairStillAfter = Duration(seconds: 30);

/// the clock codes are counted on. tests set it to the fake one
DateTime Function() pairNow = DateTime.now;

// what may sit between typed digits, as the engine skips them: spaces,
// dashes, bidi marks, no-break spaces and the non-breaking hyphen
bool _skipped(int r) =>
    r == 0x20 ||
    r == 0x2d ||
    r == 0xa0 ||
    r == 0x202f ||
    r == 0x2011 ||
    r == 0x200e ||
    r == 0x200f ||
    r == 0x61c ||
    (r >= 0x2066 && r <= 0x2069);

// the digit r stands for in the scripts the app's languages type
int? _digit(int r) {
  for (final zero in const [0x30, 0x660, 0x6f0, 0x966, 0xff10]) {
    if (r >= zero && r <= zero + 9) return r - zero;
  }
  return null;
}

/// typed digits as 0-9, as the engine folds them; null when anything but
/// digits and what may sit between them was typed
String? pairDigits(String typed) {
  final b = StringBuffer();
  for (final r in typed.runes) {
    if (_skipped(r)) continue;
    final d = _digit(r);
    if (d == null) return null;
    b.writeCharCode(0x30 + d);
  }
  return b.toString();
}

/// eight digits as shown and read out: NN NNN NNN. fewer as far as typed
String pairCodeShown(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 2 || i == 5) b.write(' ');
    b.write(digits[i]);
  }
  return b.toString();
}

/// six digits: a code from a Kryfo before 0.6, which has no pake. nothing
/// pairs with it, and the person is told both phones need 0.6
bool pairOldCode(String typed) => pairDigits(typed)?.length == 6;

/// my side's one-time invite, sealed to the other side in the run
class PairMine {
  const PairMine(this.kin4, [this.row]);
  final Uint8List kin4;
  // the app's own row for it, to spend or keep
  final Object? row;
}

/// the other side's invite, read as a link is read
class PairPeer {
  const PairPeer({required this.link, required this.id, this.invite});
  // the v4 link of their KIN4, what the add takes
  final String link;
  // their three words
  final String id;
  // the read invite, for the sharer's row
  final Object? invite;
}

/// what the run shows under the code or the field
enum PairLine {
  none,
  making,
  inviteNotReady,
  unreached,
  failed,
  looking,
  nothingYet,
  nothingAtCode,
  waiting,
  stillWaiting,
  wrongTyped,
  threeWrong,
  burned,
  ranOut,
  tooManyTries,
  unanswered,
  oldCode,
  eightDigits,
  notAdded,
}

/// where a run is
enum PairPhase { idle, making, live, matched, adding, added, ended }

/// what a run needs from the engine and the app; tests stand in for it
class PairHooks {
  const PairHooks({
    required this.invite,
    required this.share,
    required this.join,
    required this.step,
    required this.close,
    required this.read,
    required this.hold,
    required this.add,
    required this.drop,
  });

  /// a fresh one-time invite of mine, null while none can be made
  final Future<PairMine?> Function() invite;

  /// "ok", the handle and the code, or [pairUnreached] or another error
  final Future<String> Function(Uint8List invite) share;

  /// "ok" and the handle, or "error: old", "error: code", "error: tries"
  final Future<String> Function(String code, Uint8List invite) join;

  /// one round: look, wait n, unreached, done b64, error: ...
  final Future<String> Function(int handle) step;

  /// the engine's run wiped
  final Future<void> Function(int handle) close;

  /// their KIN4 read with every reader check, null when it does not read
  final Future<PairPeer?> Function(Uint8List kin4) read;

  /// sharer: their opener is waited for on my invite once they are added,
  /// and nothing else opens there meanwhile
  final Future<void> Function(PairMine mine, PairPeer peer) hold;

  /// the add: the line to show after it (empty when a chat opening is
  /// the answer) and whether they are in
  final Future<(String, bool)> Function(
    PairPeer peer,
    PairMine mine, {
    required bool sharer,
  })
  add;

  /// my invite let go: no one will open on it
  final Future<void> Function(PairMine mine) drop;
}

/// one pairing, the sharer's or the joiner's
class PairRun extends ChangeNotifier {
  PairRun.share(this.hooks, {this.gap = const Duration(seconds: 3)})
    : sharer = true;
  PairRun.join(this.hooks, {this.gap = const Duration(seconds: 3)})
    : sharer = false;

  final PairHooks hooks;
  final bool sharer;
  // between two rounds; the engine keeps its own floor
  final Duration gap;

  PairPhase phase = PairPhase.idle;
  PairLine line = PairLine.none;
  // said in the warning colour
  bool warn = false;
  // the sharer's code as shown, and when it burns
  String? code;
  DateTime? burns;
  // wrong codes the sharer saw
  int wrong = 0;
  PairPeer? peer;
  // the add's own line, once added
  String? added;

  // its end was said on a panel once: a panel opened after drops it
  bool told = false;

  int? _h;
  PairMine? _mine;
  bool _gone = false;
  Timer? _burn;
  DateTime? _since;
  DateTime? _waitSince;

  bool get busy => phase == PairPhase.making || phase == PairPhase.adding;

  void _set(PairLine l, {bool warn = false}) {
    line = l;
    this.warn = warn;
    if (!_gone) notifyListeners();
  }

  /// the sharer's start: an invite, the engine's offer up, the code shown
  Future<void> start() async {
    if (!sharer || phase != PairPhase.idle) return;
    phase = PairPhase.making;
    _set(PairLine.making);
    final mine = await hooks.invite();
    if (_gone) return _letGo(mine);
    if (mine == null) {
      phase = PairPhase.ended;
      return _set(PairLine.inviteNotReady);
    }
    _mine = mine;
    // the count starts now, not on the answer, so it never runs past the
    // offer the engine stamps as it puts it up
    burns = pairNow().add(kPairCodeLife);
    final res = await hooks.share(mine.kin4);
    if (_gone) {
      final h = _handleOf(res);
      if (h != null) unawaited(hooks.close(h));
      return _letGo(mine);
    }
    final parts = res.split(' ');
    final h = _handleOf(res);
    if (h == null || parts.length != 5) {
      phase = PairPhase.ended;
      await _dropMine();
      return _set(
        res == pairUnreached ? PairLine.unreached : PairLine.failed,
        warn: true,
      );
    }
    _h = h;
    code = parts.sublist(2).join(' ');
    phase = PairPhase.live;
    _set(PairLine.waiting);
    // burned on the second the count says, not on the next round
    _burn = Timer(burns!.difference(pairNow()), () {
      if (phase == PairPhase.live) unawaited(_end(PairLine.burned));
    });
    unawaited(_loop());
  }

  /// the joiner's start with what was typed
  Future<void> begin(String typed) async {
    if (sharer || busy || phase == PairPhase.live) return;
    final digits = pairDigits(typed);
    if (digits != null && digits.length == 6) {
      phase = PairPhase.idle;
      return _set(PairLine.oldCode, warn: true);
    }
    if (digits == null || digits.length != 8) {
      phase = PairPhase.idle;
      return _set(PairLine.eightDigits, warn: true);
    }
    phase = PairPhase.making;
    _set(PairLine.looking);
    final mine = await hooks.invite();
    if (_gone) return _letGo(mine);
    if (mine == null) {
      phase = PairPhase.ended;
      return _set(PairLine.inviteNotReady, warn: true);
    }
    _mine = mine;
    final res = await hooks.join(digits, mine.kin4);
    if (_gone) {
      final h = _handleOf(res);
      if (h != null) unawaited(hooks.close(h));
      return _letGo(mine);
    }
    final h = _handleOf(res);
    if (h == null) {
      phase = PairPhase.ended;
      await _dropMine();
      return switch (res) {
        'error: old' => _set(PairLine.oldCode, warn: true),
        'error: code' => _set(PairLine.eightDigits, warn: true),
        'error: tries' => _set(PairLine.tooManyTries, warn: true),
        pairUnreached => _set(PairLine.unreached, warn: true),
        _ => _set(PairLine.failed, warn: true),
      };
    }
    _h = h;
    _since = pairNow();
    phase = PairPhase.live;
    _set(PairLine.looking);
    unawaited(_loop());
  }

  static int? _handleOf(String res) {
    final p = res.split(' ');
    return p.length >= 2 && p[0] == 'ok' ? int.tryParse(p[1]) : null;
  }

  Future<void> _loop() async {
    while (!_gone && phase == PairPhase.live && _h != null) {
      if (sharer && !pairNow().isBefore(burns!)) {
        await _end(PairLine.burned);
        return;
      }
      final res = await hooks.step(_h!);
      if (_gone || phase != PairPhase.live) return;
      await _took(res);
      if (_gone || phase != PairPhase.live) return;
      await Future<void>.delayed(gap);
    }
  }

  Future<void> _took(String res) async {
    final now = pairNow();
    if (res.startsWith('done ')) {
      final Uint8List theirs;
      try {
        theirs = base64Decode(res.substring(5));
      } catch (_) {
        return _end(PairLine.failed, warn: true);
      }
      final h = _h;
      _h = null;
      _burn?.cancel();
      if (h != null) unawaited(hooks.close(h));
      final p = await hooks.read(theirs);
      if (_gone) return;
      if (p == null || _mine == null) return _end(PairLine.failed, warn: true);
      if (sharer) await hooks.hold(_mine!, p);
      if (_gone) return;
      peer = p;
      phase = PairPhase.matched;
      return _set(PairLine.none);
    }
    if (res.startsWith('wait ')) {
      final n = int.tryParse(res.substring(5)) ?? 0;
      if (sharer) {
        if (n > wrong) {
          wrong = n;
          return _set(PairLine.wrongTyped, warn: true);
        }
        if (wrong == 0) _set(PairLine.waiting);
        return;
      }
      _waitSince ??= now;
      return _set(
        now.difference(_waitSince!) >= kPairStillAfter
            ? PairLine.stillWaiting
            : PairLine.waiting,
      );
    }
    if (res == 'look') {
      if (now.difference(_since ?? now) >= kPairLookFor) {
        return _end(PairLine.nothingAtCode);
      }
      return _set(
        now.difference(_since ?? now) >= const Duration(seconds: 12)
            ? PairLine.nothingYet
            : PairLine.looking,
      );
    }
    if (res == 'unreached') {
      if (!sharer && now.difference(_since ?? now) >= kPairLookFor) {
        return _end(PairLine.unreached, warn: true);
      }
      // a sharer's code stays up: one round no relay answered is not the end
      if (!sharer || wrong == 0) _set(PairLine.unreached);
      return;
    }
    return _end(switch (res) {
      'error: tries' => sharer ? PairLine.threeWrong : PairLine.tooManyTries,
      'error: expired' => sharer ? PairLine.burned : PairLine.ranOut,
      'error: unanswered' => PairLine.unanswered,
      _ => PairLine.failed,
    }, warn: res != 'error: expired' || !sharer);
  }

  Future<void> _end(PairLine l, {bool warn = false}) async {
    phase = PairPhase.ended;
    _burn?.cancel();
    final h = _h;
    _h = null;
    if (h != null) await hooks.close(h);
    await _dropMine();
    _set(l, warn: warn);
  }

  Future<void> _dropMine() async {
    final m = _mine;
    _mine = null;
    if (m != null) await hooks.drop(m);
  }

  Future<void> _letGo(PairMine? mine) async {
    if (mine != null) await hooks.drop(mine);
  }

  /// the person adds them. the joiner's own invite goes after: the sharer
  /// never opens on it, the joiner starts
  Future<void> confirm() async {
    final p = peer, m = _mine;
    if (phase != PairPhase.matched || p == null || m == null) return;
    phase = PairPhase.adding;
    _set(PairLine.none);
    final (status, ok) = await hooks.add(p, m, sharer: sharer);
    if (!sharer || !ok) await _dropMine();
    _mine = null;
    added = status;
    phase = ok ? PairPhase.added : PairPhase.ended;
    if (ok) return _set(PairLine.none);
    // the add said why it did not take
    _set(PairLine.none, warn: true);
  }

  /// not who they expected: nothing is added and my invite goes
  Future<void> notThem() async {
    if (phase != PairPhase.matched) return;
    peer = null;
    await _end(PairLine.notAdded);
  }

  /// the screen went: the engine's run and my invite go, unless the add
  /// already took them
  Future<void> cancel() async {
    if (_gone) return;
    _gone = true;
    _burn?.cancel();
    final h = _h;
    _h = null;
    if (h != null) await hooks.close(h);
    if (phase != PairPhase.added) await _dropMine();
  }

  @override
  void dispose() {
    unawaited(cancel());
    super.dispose();
  }
}

/// the sharer's run of each container, outside any panel: a card or tab
/// left and opened again shows the code its offer is still up for. keyed
/// by container, so no other container ever sees it
class PairCodes extends ChangeNotifier {
  final _live = <String, PairRun>{};

  PairRun? of(String box) => _live[box];

  /// a new run for [box], the one before let go
  PairRun begin(String box, PairHooks hooks) {
    _live.remove(box)?.cancel();
    final r = PairRun.share(hooks);
    _live[box] = r;
    notifyListeners();
    return r;
  }

  void drop(String box) {
    final r = _live.remove(box);
    if (r == null) return;
    unawaited(r.cancel());
    notifyListeners();
  }

  /// whole seconds to go, rounded up so a fresh code reads ten minutes
  int left(PairRun r) {
    final b = r.burns;
    if (b == null) return 0;
    final ms = b.difference(pairNow()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  @visibleForTesting
  void clear() {
    for (final r in _live.values) {
      unawaited(r.cancel());
    }
    _live.clear();
  }
}
