// SPDX-License-Identifier: GPL-3.0-or-later
// the joining side of a pair code: eight digits in, a cpace run over the
// relays, and once the code matched on both phones the person sees who it
// is and adds them. a six digit code is an older Kryfo's and says so. the
// card both sides show when the code matched lives here too
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../pair_flow.dart';
import '../theme.dart';
import 'halo_buttons.dart';
import 'kryfo_avatar.dart';
import 'motion.dart' show BreathDot, kHouseCurve, kHouseTime, motionStill;
import 'press_scale.dart';
import 'swap.dart';
import 'tor_wait_line.dart';

export '../pair_flow.dart' show pairUnreached;

/// what a run's line says, on the sharer's side or the joiner's
String pairLineText(PairLine l, {required bool sharer}) => switch (l) {
  PairLine.none => '',
  PairLine.making => l10n.pairCodePanelPuttingYourInviteIn,
  PairLine.inviteNotReady => l10n.pairCodePanelYourInviteIsNot,
  PairLine.unreached => torWaitLine() ?? l10n.pairCodeUnreached,
  PairLine.failed => l10n.pairCodeFailed,
  PairLine.looking => l10n.pairCodeLooking,
  PairLine.nothingYet => l10n.pairCodeNothingThereYetTrying,
  PairLine.nothingAtCode => l10n.pairCodeNothingAtThatCode,
  PairLine.waiting => sharer ? '' : l10n.pairCodeWaitingForThem,
  PairLine.stillWaiting => l10n.pairCodeStillWaiting,
  PairLine.wrongTyped => l10n.pairCodePanelWrongTyped,
  PairLine.threeWrong => l10n.pairCodePanelThreeWrong,
  PairLine.burned => l10n.pairCodePanelBurned,
  PairLine.ranOut => l10n.pairCodeRanOut,
  PairLine.tooManyTries => l10n.pairCodeTooManyTries,
  PairLine.unanswered => l10n.pairCodeUnanswered,
  PairLine.oldCode => l10n.pairCodeOldCodeShown,
  PairLine.eightDigits => l10n.pairCodeEightDigits,
  PairLine.notAdded =>
    sharer ? l10n.pairCodePanelNotAdded : l10n.pairCodeNotAdded,
};

/// digits typed in any of the app's scripts, shown as NN NNN NNN while
/// typed. anything that is not a digit is left out
class PairCodeFormatter extends TextInputFormatter {
  const PairCodeFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final b = StringBuffer();
    for (final r in newValue.text.runes) {
      final d = pairDigits(String.fromCharCode(r));
      if (d != null && d.length == 1) b.write(d);
    }
    var digits = b.toString();
    if (digits.length > 8) digits = digits.substring(0, 8);
    final shown = pairCodeShown(digits);
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
  }
}

class PairJoin extends StatefulWidget {
  // makes the run; tests hand in one on stand-in hooks
  final PairRun Function() run;
  // the add went through: its line (empty when a chat opening is the
  // answer)
  final void Function(String status) onAdded;
  const PairJoin({super.key, required this.run, required this.onAdded});

  @override
  State<PairJoin> createState() => _PairJoinState();
}

class _PairJoinState extends State<PairJoin>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  PairRun? _run;
  // a line said before any run, or after one ended, and an add's own
  PairLine _line = PairLine.none;
  String _said = '';
  bool _warn = false;

  @override
  void dispose() {
    _run?.removeListener(_changed);
    _run?.dispose();
    _ctrl.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _changed() {
    final r = _run;
    if (!mounted || r == null) return;
    if (r.phase == PairPhase.added) {
      HapticFeedback.lightImpact();
      widget.onAdded(r.added ?? '');
      return;
    }
    if (r.phase == PairPhase.matched) HapticFeedback.lightImpact();
    if (r.phase == PairPhase.ended) {
      if (r.warn) _nudge();
      _said = r.added ?? '';
      _line = r.line;
      _warn = r.warn;
    }
    setState(() {});
  }

  // a code that did not take: a buzz, and the field shakes once
  void _nudge() {
    HapticFeedback.heavyImpact();
    if (!motionStill(context)) _shake.forward(from: 0);
  }

  Future<void> _join() async {
    final live = _run;
    if (live != null &&
        (live.busy ||
            live.phase == PairPhase.live ||
            live.phase == PairPhase.matched)) {
      return;
    }
    // a six digit code or a short one is said at once, with no run
    if (pairOldCode(_ctrl.text) || pairDigits(_ctrl.text)?.length != 8) {
      setState(() {
        _line = pairOldCode(_ctrl.text)
            ? PairLine.oldCode
            : PairLine.eightDigits;
        _said = '';
        _warn = true;
      });
      _nudge();
      return;
    }
    live?.removeListener(_changed);
    live?.dispose();
    final r = widget.run();
    _run = r..addListener(_changed);
    setState(() {
      _line = PairLine.none;
      _said = '';
      _warn = false;
    });
    await r.begin(_ctrl.text);
  }

  Future<void> _notThem() async {
    await _run?.notThem();
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final r = _run;
    final matched =
        r != null &&
        r.peer != null &&
        (r.phase == PairPhase.matched || r.phase == PairPhase.adding);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        AnimatedSwitcher(
          duration: still ? Duration.zero : kHouseTime,
          reverseDuration: still
              ? Duration.zero
              : const Duration(milliseconds: 160),
          // the spring only moves the scale: its overshoot is no opacity
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
          child: matched
              ? PairMatched(
                  key: const ValueKey('matched'),
                  words: r.peer!.id,
                  busy: r.phase == PairPhase.adding,
                  onAdd: r.confirm,
                  onNotThem: _notThem,
                )
              : KeyedSubtree(key: const ValueKey('entry'), child: _entry()),
        ),
      ],
    );
  }

  Widget _entry() {
    final still = motionStill(context);
    final r = _run;
    final running =
        r != null && (r.phase == PairPhase.making || r.phase == PairPhase.live);
    final line = running ? r.line : _line;
    final warn = running ? r.warn : _warn;
    final text = !running && _said.isNotEmpty
        ? _said
        : pairLineText(line, sharer: false);
    final waits = running && r.phase == PairPhase.live;
    final status = text.isEmpty
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: RiseSwap(
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                key: ValueKey(text),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (waits && !warn) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: BreathDot(color: HaloColors.amber, size: 6),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      text,
                      style: warn
                          ? HaloType.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: HaloColors.roseText,
                            )
                          : HaloType.sans(size: 13, color: HaloColors.text2),
                    ),
                  ),
                ],
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pairCodeTypeTheEightDigits,
          style: HaloType.sans(size: 13.5, color: HaloColors.text2),
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _shake,
          builder: (_, child) {
            // three swings, smaller each time
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: TextField(
            textDirection: TextDirection.ltr,
            controller: _ctrl,
            enabled: !running,
            enableIMEPersonalizedLearning: false,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.number,
            inputFormatters: const [PairCodeFormatter()],
            textAlign: TextAlign.center,
            onChanged: (_) {
              if (_line != PairLine.none || _said.isNotEmpty) {
                setState(() {
                  _line = PairLine.none;
                  _said = '';
                  _warn = false;
                });
              }
            },
            onSubmitted: (_) => _join(),
            style: HaloType.mono(
              size: 28,
              weight: FontWeight.w600,
              color: HaloColors.text,
              letter: 0.14,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '00 000 000',
              hintStyle: HaloType.mono(size: 28, color: HaloColors.text2),
              filled: true,
              fillColor: HaloColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: HaloColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: warn
                      ? HaloColors.roseText.withValues(alpha: 0.6)
                      : HaloColors.line,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: HaloColors.amber.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        HaloPrimaryButton(
          label: running ? l10n.pairCodeLooking : l10n.pairCodeAddThem,
          busy: running,
          onTap: running ? null : _join,
        ),
        // reduced motion: the line without animation
        if (still)
          status
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.topStart,
            child: status,
          ),
        const SizedBox(height: 18),
        Text(
          l10n.pairCodeBothNeed06Shown,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 12, color: HaloColors.text2),
        ),
      ],
    );
  }
}

/// the other side, once the code matched on both phones: who they are,
/// and the add. nothing is added before the person says so
class PairMatched extends StatelessWidget {
  final String words;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onNotThem;
  const PairMatched({
    super.key,
    required this.words,
    required this.onAdd,
    required this.onNotThem,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        children: [
          // the face settles a beat after the card
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0.86, end: 1),
            duration: still ? Duration.zero : kHouseTime,
            curve: kHouseCurve,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: KryfoAvatar(seed: words, size: 64),
          ),
          const SizedBox(height: 12),
          // a name, as they gave it
          Text(
            words,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: HaloType.mono(
              size: 15,
              weight: FontWeight.w600,
              color: HaloColors.text,
              letter: 0.02,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: HaloColors.green),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.pairCodeMatched,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(size: 13.5, color: HaloColors.text2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          HaloPrimaryButton(label: l10n.commonAdd, busy: busy, onTap: onAdd),
          const SizedBox(height: 4),
          PressScale(
            scale: 0.97,
            onTap: busy ? null : onNotThem,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  l10n.pairCodeNotThem,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(size: 13.5, color: HaloColors.text2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
