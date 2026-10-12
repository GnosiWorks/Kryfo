// SPDX-License-Identifier: GPL-3.0-or-later
// six digits you read out loud. the code points at your invite for ten
// minutes, works once, then the address is gone. your three words sit under
// it, and the key number of the invite, for the other phone to match before
// it adds you. shared by the invite page and the pairing screen.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appState, engine, inviteKeyNumber, sessionQuiet;
import '../quiet_wait.dart';
import '../theme.dart';
import 'ease_size.dart';
import 'halo_buttons.dart';
import 'swap.dart';
import 'motion.dart' show BreathDot, kHouseCurve, kHouseTime, motionStill;
import 'pair_join.dart'
    show PairWordsTag, pairErrorText, pairNow, pairUnreached;
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

// as long as the engine stamps an invite at a code to live
const kPairCodeLife = Duration(minutes: 10);

class PairCodePanel extends StatefulWidget {
  // compact drops the explanatory lines, for use under a qr
  final bool compact;
  // puts [invite] at a code and gives the engine's answer. tests stand in
  // for it
  final Future<String> Function(String code, String invite)? publish;
  // the invite a code points at: the session's own
  final Future<String> Function()? invite;
  const PairCodePanel({
    super.key,
    this.compact = false,
    this.publish,
    this.invite,
  });
  @override
  State<PairCodePanel> createState() => _PairCodePanelState();
}

// a code, when it burns, and the key number of the invite it points at
class PairCodeLive {
  PairCodeLive(this.box, this.code, this.burns, [this.number]);
  final String box;
  final String code;
  final DateTime burns;
  final String? number;
  // the engine took it: until then the panel says it is working
  bool shown = false;
  // its burning was said once, on a panel opened after it went
  bool told = false;
}

// the live code of each container, outside any panel: a card or tab left
// and opened again shows the code its invite is still up for. keyed by
// container, so no other container ever sees it
class PairCodes extends ChangeNotifier {
  final _live = <String, PairCodeLive>{};

  PairCodeLive? of(String box) => _live[box];

  PairCodeLive begin(String box, String code, [String? number]) {
    final c = PairCodeLive(box, code, pairNow().add(kPairCodeLife), number);
    _live[box] = c;
    notifyListeners();
    return c;
  }

  void ready(PairCodeLive c) {
    if (!identical(_live[c.box], c)) return;
    c.shown = true;
    notifyListeners();
  }

  void drop(PairCodeLive c) {
    if (!identical(_live[c.box], c)) return;
    _live.remove(c.box);
    notifyListeners();
  }

  // whole seconds to go, rounded up so a fresh code reads ten minutes
  int left(PairCodeLive c) {
    final ms = c.burns.difference(pairNow()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  @visibleForTesting
  void clear() => _live.clear();
}

class _PairCodePanelState extends State<PairCodePanel> {
  // what this panel shows, out of the shared store
  PairCodeLive? _on;
  String _status = '';
  bool _failed = false;
  Timer? _tick;

  PairCodes get _codes => appState.pairCodes;
  bool get _busy => _on != null && !_on!.shown;
  String? get _code => _on != null && _on!.shown ? _on!.code : null;
  int get _left => _on == null ? 0 : _codes.left(_on!);

  @override
  void initState() {
    super.initState();
    _codes.addListener(_sync);
    _sync(first: true);
  }

  @override
  void dispose() {
    _codes.removeListener(_sync);
    _tick?.cancel();
    super.dispose();
  }

  // the store's code for this container, counted down. one that burned is
  // gone and said so: a code that just vanished reads as a fault
  void _sync({bool first = false}) {
    if (!mounted) return;
    var c = _codes.of(appState.pairBox);
    var burned = false;
    if (c != null && _codes.left(c) <= 0) {
      burned = c.shown && !c.told;
      if (c.shown) c.told = true;
      c = null;
    }
    final was = _on;
    if (c == null && was != null && was.shown && _codes.left(was) <= 0) {
      was.told = true;
      burned = true;
    }
    if (c == null) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _sync());
    }
    final changed = !identical(c, was) || burned;
    _on = c;
    if (burned) {
      _failed = false;
      _status = l10n.pairCodePanelBurned;
    }
    // a tick only moves the count
    if (!first && (changed || c != null)) setState(() {});
  }

  // reading the invite, before the store holds the code
  bool _making = false;

  Future<void> _make() async {
    if (_busy || _making) return;
    HapticFeedback.selectionClick();
    // Random.secure: a guessable code is one someone else can stand in
    // front of
    final r = Random.secure();
    final code = List.generate(6, (_) => r.nextInt(10)).join();
    if (appState.sessionOnion.isEmpty) {
      setState(() {
        _failed = false;
        _status = l10n.pairCodePanelYourInviteIsNot;
      });
      return;
    }
    setState(() {
      _failed = false;
      _status = l10n.pairCodePanelPuttingYourInviteIn;
    });
    // the number shown is read off the very invite put at the code
    _making = true;
    final String invite;
    try {
      invite = await (widget.invite ?? appState.sessionInvite)();
    } finally {
      _making = false;
    }
    // the engine stamps the invite's life as it builds it, and a publish
    // over a slow route takes a while: the count starts now, not on the
    // answer, so it never runs past the invite. the code is the store's,
    // so a panel left before the answer still leaves it live
    final c = _codes.begin(appState.pairBox, code, inviteKeyNumber(invite));
    final res = await (widget.publish ?? _publish)(code, invite);
    if (res.startsWith('error')) {
      _codes.drop(c);
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = pairErrorText(res);
      });
      return;
    }
    _codes.ready(c);
    if (mounted) setState(() => _status = '');
  }

  // a quiet session never reaches the relays: it answers as unreachable
  // ones would
  static Future<String> _publish(String code, String invite) => sessionQuiet
      ? unreachedLater(pairUnreached)
      : engine.pairCodePublish(code, invite);

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    // the code settles in on the house spring as the card eases to its
    // height, so the buttons under it move instead of jumping. with less
    // movement it simply swaps
    return EaseSize(
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : kHouseTime,
        reverseDuration: still
            ? Duration.zero
            : const Duration(milliseconds: 160),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a.drive(
            CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut)),
          ),
          child: ScaleTransition(
            scale: a
                .drive(CurveTween(curve: kHouseCurve))
                .drive(Tween<double>(begin: 0.94, end: 1)),
            child: c,
          ),
        ),
        layoutBuilder: (top, gone) =>
            Stack(alignment: Alignment.topCenter, children: [...gone, ?top]),
        child: _code == null ? _idle() : _liveView(),
      ),
    );
  }

  Widget _idle() {
    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            l10n.pairCodePanelReadSixDigitsOut,
            style: HaloType.sans(size: 13.5, color: HaloColors.text2),
          ),
          const SizedBox(height: 22),
        ],
        // under a qr it is the other way, so it stays the quieter one
        if (widget.compact)
          HaloGhostButton(
            label: _busy
                ? l10n.pairCodePanelWorking
                : l10n.pairCodePanelOrMakeASix,
            onTap: _busy ? null : _make,
          )
        else
          HaloPrimaryButton(
            label: _busy
                ? l10n.pairCodePanelWorking
                : l10n.pairCodePanelOrMakeASix,
            busy: _busy,
            onTap: _make,
          ),
        // a new line rises in over the last, and the card eases to it
        EaseSize(
          child: _status.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: RiseSwap(
                    alignment: Alignment.center,
                    child: Text(
                      _status,
                      key: ValueKey(_status),
                      textAlign: TextAlign.center,
                      style: HaloType.mono(
                        size: 10.5,
                        color: _failed ? HaloColors.rose : HaloColors.text2,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _liveView() {
    final mm = whole(_left ~/ 60);
    final ss = twoDigits(_left % 60);
    return Column(
      key: const ValueKey('live'),
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            copySensitive(_code!);
            showHaloToast(context, l10n.pairCodePanelCodeCopied);
          },
          child: Text(
            '${_code!.substring(0, 3)} ${_code!.substring(3)}',
            // digits read out in order, whatever the language
            textDirection: TextDirection.ltr,
            style: HaloType.mono(
              size: widget.compact ? 34 : 40,
              weight: FontWeight.w600,
              color: HaloColors.amber,
              letter: 0.16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        PairWordsTag(words: appState.sessionId, number: _on?.number),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathDot(color: HaloColors.amber, size: 6),
            const SizedBox(width: 8),
            Text(
              l10n.pairCodePanelBurnsIn(mm, ss),
              style: HaloType.mono(size: 11, color: HaloColors.text2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          widget.compact
              ? l10n.pairCodePanelTheyTapAddChoose
              : l10n.pairCodePanelTheyOpenKryfoTap,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 12.5, color: HaloColors.text2),
        ),
      ],
    );
  }
}
