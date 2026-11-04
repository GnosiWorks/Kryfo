// SPDX-License-Identifier: GPL-3.0-or-later
// eight digits you read out loud. the first two pick a meeting place on the
// relays, the last six never leave the phone: the other side proves it
// typed them without sending them, and each gets the other's one-time
// invite. a wrong code is a try, and three end it. the code shows for ten
// minutes; once it matched the person sees who it is and adds them. shared
// by the invite page and the pairing screen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState, pairHooks, AppStateSession;
import '../pair_flow.dart';
import '../theme.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import 'ease_size.dart';
import 'halo_buttons.dart';
import 'motion.dart' show BreathDot, kHouseCurve, kHouseTime, motionStill;
import 'pair_join.dart' show PairMatched, pairLineText;
import 'swap.dart';

export '../pair_flow.dart' show PairCodes, kPairCodeLife;

class PairCodePanel extends StatefulWidget {
  // compact drops the explanatory lines, for use under a qr
  final bool compact;
  // what a new run is made on; the app's own by default, tests stand in
  final PairHooks Function()? hooks;
  // the add went through: its line (empty when a chat opening is the
  // answer)
  final void Function(String status)? onAdded;
  const PairCodePanel({
    super.key,
    this.compact = false,
    this.hooks,
    this.onAdded,
  });
  @override
  State<PairCodePanel> createState() => _PairCodePanelState();
}

class _PairCodePanelState extends State<PairCodePanel> {
  PairRun? _on;
  Timer? _tick;
  int _wrongSeen = 0;

  PairCodes get _codes => appState.pairCodes;

  @override
  void initState() {
    super.initState();
    _sync(first: true);
    _codes.addListener(_sync);
  }

  @override
  void dispose() {
    _codes.removeListener(_sync);
    _on?.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  // the store's run for this container, followed. one whose end was said
  // on a panel before goes: a line that stays reads as a fault
  void _sync({bool first = false}) {
    if (!mounted) return;
    var r = _codes.of(appState.pairBox);
    if (first && r != null && r.phase == PairPhase.ended && r.told) {
      _codes.drop(appState.pairBox);
      r = null;
    }
    if (!identical(r, _on)) {
      _on?.removeListener(_changed);
      _on = r?..addListener(_changed);
      _wrongSeen = r?.wrong ?? 0;
    }
    _ticking();
    if (!first) setState(() {});
  }

  void _ticking() {
    final live = _on?.phase == PairPhase.live;
    if (live) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _changed() {
    final r = _on;
    if (!mounted || r == null) return;
    if (r.wrong > _wrongSeen) {
      _wrongSeen = r.wrong;
      HapticFeedback.heavyImpact();
    }
    if (r.phase == PairPhase.matched) HapticFeedback.lightImpact();
    if (r.phase == PairPhase.added) {
      HapticFeedback.lightImpact();
      final said = r.added ?? '';
      _codes.drop(appState.pairBox);
      if (said.isNotEmpty) showHaloToast(context, said);
      widget.onAdded?.call(said);
      return;
    }
    _ticking();
    setState(() {});
  }

  Future<void> _make() async {
    final r = _on;
    if (r != null && (r.busy || r.phase == PairPhase.live)) return;
    HapticFeedback.selectionClick();
    final run = _codes.begin(appState.pairBox, (widget.hooks ?? pairHooks)());
    await run.start();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final r = _on;
    final view = switch (r?.phase) {
      PairPhase.live => 'live',
      PairPhase.matched || PairPhase.adding => 'matched',
      _ => 'idle',
    };
    // the code settles in on the house spring as the card eases to its
    // height, so the buttons under it move instead of jumping. with reduced
    // motion it swaps
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
        child: switch (view) {
          'live' => _liveView(r!),
          'matched' => PairMatched(
            key: const ValueKey('matched'),
            words: r!.peer!.id,
            busy: r.phase == PairPhase.adding,
            onAdd: r.confirm,
            onNotThem: r.notThem,
          ),
          _ => _idle(r),
        },
      ),
    );
  }

  Widget _idle(PairRun? r) {
    final busy = r != null && r.busy;
    if (r != null && r.phase == PairPhase.ended) r.told = true;
    final line = r == null ? '' : pairLineText(r.line, sharer: true);
    final warn = r?.warn ?? false;
    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            l10n.pairCodePanelReadEightDigitsOut,
            style: HaloType.sans(size: 13.5, color: HaloColors.text2),
          ),
          const SizedBox(height: 22),
        ],
        // under a qr it is the other way, so it stays the quieter one
        if (widget.compact)
          HaloGhostButton(
            label: busy
                ? l10n.pairCodePanelWorking
                : l10n.pairCodePanelOrMakeACode,
            onTap: busy ? null : _make,
          )
        else
          HaloPrimaryButton(
            label: busy
                ? l10n.pairCodePanelWorking
                : l10n.pairCodePanelOrMakeACode,
            busy: busy,
            onTap: _make,
          ),
        // a new line rises in over the last, and the card eases to it
        EaseSize(
          child: line.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: RiseSwap(
                    alignment: Alignment.center,
                    child: Text(
                      line,
                      key: ValueKey(line),
                      textAlign: TextAlign.center,
                      style: warn
                          ? HaloType.sans(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: HaloColors.roseText,
                            )
                          : HaloType.mono(size: 10.5, color: HaloColors.text2),
                    ),
                  ),
                ),
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 14),
          Text(
            l10n.pairCodeBothNeed06Shown,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 12, color: HaloColors.text2),
          ),
        ],
      ],
    );
  }

  Widget _liveView(PairRun r) {
    final left = _codes.left(r);
    final mm = whole(left ~/ 60);
    final ss = twoDigits(left % 60);
    final code = r.code ?? '';
    final line = pairLineText(r.line, sharer: true);
    return Column(
      key: const ValueKey('live'),
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            copySensitive(code.replaceAll(' ', ''));
            showHaloToast(context, l10n.pairCodePanelCodeCopied);
          },
          child: Semantics(
            label: code,
            textDirection: TextDirection.ltr,
            excludeSemantics: true,
            child: _CodeDigits(code: code, size: widget.compact ? 32 : 38),
          ),
        ),
        const SizedBox(height: 14),
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
              : l10n.pairCodePanelTheyOpenKryfoEight,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 12.5, color: HaloColors.text2),
        ),
        // a wrong try, said in the warning colour until the next line
        EaseSize(
          child: line.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RiseSwap(
                    alignment: Alignment.center,
                    child: Text(
                      line,
                      key: ValueKey(line),
                      textAlign: TextAlign.center,
                      style: r.warn
                          ? HaloType.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: HaloColors.roseText,
                            )
                          : HaloType.sans(size: 12.5, color: HaloColors.text2),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// the code in its three groups, each digit rising in a beat after the one
/// before. still with reduced motion. digits in the same order whatever
/// the language, so two people read them alike
class _CodeDigits extends StatelessWidget {
  final String code;
  final double size;
  const _CodeDigits({required this.code, required this.size});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final style = HaloType.mono(
      size: size,
      weight: FontWeight.w600,
      color: HaloColors.amberText,
      letter: 0.12,
    );
    var i = 0;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final ch in code.split(''))
            if (ch == ' ')
              SizedBox(width: size * 0.42)
            else
              _Rise(
                still: still,
                delay: Duration(milliseconds: 28 * i++),
                child: Text(ch, style: style),
              ),
        ],
      ),
    );
  }
}

class _Rise extends StatefulWidget {
  final bool still;
  final Duration delay;
  final Widget child;
  const _Rise({required this.still, required this.delay, required this.child});
  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: kHouseTime);
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (widget.still) {
      _c.value = 1;
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _c.drive(CurveTween(curve: kHouseCurve));
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Opacity(
        opacity: _c.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - a.value) * 10),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
