// SPDX-License-Identifier: GPL-3.0-or-later
// the joining side of a pairing code. six digits in, the invite they point
// at out, and nothing added until the person has matched its face and three
// words against the other phone's screen. a code that points at more than
// one invite is refused outright.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'kryfo_avatar.dart';
import 'motion.dart' show kHouseCurve, kHouseTime, motionStill;
import 'press_scale.dart';

final _words = RegExp(r'^[a-z]+-[a-z]+-[a-z]+$');

/// the engine's answer when no relay took a share or answered a lookup
const pairUnreached = 'error: unreached';

/// an engine error, worded for the person
String pairErrorText(String res) =>
    res == pairUnreached ? l10n.pairCodeUnreached : l10n.pairCodeFailed;

/// the three words a fetched invite names, or null when it names none
String? pairInviteWords(String invite) {
  if (!invite.startsWith('kryfo://share')) return null;
  try {
    final id = Uri.parse(invite).queryParameters['id'];
    return id != null && _words.hasMatch(id) ? id : null;
  } catch (_) {
    return null;
  }
}

class PairJoin extends StatefulWidget {
  // the engine's answer for a code: an invite, "empty", "twice",
  // [pairUnreached] or another error
  final Future<String> Function(String code) fetch;
  // the app's own add path; its answer is the line to show afterwards
  final Future<String> Function(String invite) add;
  final void Function(String status) onAdded;
  // between looks while the other side has not shared yet
  final Duration retryGap;
  const PairJoin({
    super.key,
    required this.fetch,
    required this.add,
    required this.onAdded,
    this.retryGap = const Duration(seconds: 4),
  });

  @override
  State<PairJoin> createState() => _PairJoinState();
}

class _PairJoinState extends State<PairJoin> {
  final _ctrl = TextEditingController();
  String _status = '';
  // refused or failed: said in the warning colour
  bool _warn = false;
  bool _busy = false;
  bool _adding = false;
  String? _invite;
  String? _words;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _say(String s, {bool warn = false}) => setState(() {
    _busy = false;
    _status = s;
    _warn = warn;
  });

  Future<void> _join() async {
    final code = _ctrl.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      _say(l10n.pairCodeSixDigits);
      return;
    }
    setState(() {
      _busy = true;
      _status = l10n.pairCodeLooking;
      _warn = false;
    });

    // the other side may not have pressed share yet, so give it a few goes.
    // a look no relay answered says nothing about the code, so it is tried
    // again too, and only a look that was answered can call the code empty
    var answered = false;
    for (var attempt = 0; attempt < 3; attempt++) {
      final res = await widget.fetch(code);
      if (!mounted) return;
      if (res == 'twice') {
        HapticFeedback.heavyImpact();
        _ctrl.clear();
        _say(l10n.pairCodeUsedTwice, warn: true);
        return;
      }
      if (res.startsWith('kryfo://')) {
        final words = pairInviteWords(res);
        if (words == null) {
          _say(l10n.pairCodeNothingAtThatCode);
          return;
        }
        HapticFeedback.lightImpact();
        setState(() {
          _busy = false;
          _status = '';
          _invite = res;
          _words = words;
        });
        return;
      }
      if (res != pairUnreached && res.startsWith('error')) {
        _say(pairErrorText(res), warn: true);
        return;
      }
      if (res != pairUnreached) answered = true;
      if (attempt < 2) {
        setState(
          () => _status = answered
              ? l10n.pairCodeNothingThereYetTrying
              : l10n.pairCodeLooking,
        );
        await Future<void>.delayed(widget.retryGap);
        if (!mounted) return;
      }
    }
    answered
        ? _say(l10n.pairCodeNothingAtThatCode)
        : _say(l10n.pairCodeUnreached, warn: true);
  }

  Future<void> _add() async {
    final invite = _invite;
    if (invite == null || _adding) return;
    setState(() => _adding = true);
    final status = await widget.add(invite);
    if (!mounted) return;
    setState(() => _adding = false);
    widget.onAdded(status);
  }

  void _notThem() {
    _ctrl.clear();
    setState(() {
      _invite = null;
      _words = null;
      _status = l10n.pairCodeNotAdded;
      _warn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final confirm = _words != null;
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
          child: confirm
              ? PairConfirm(
                  key: const ValueKey('confirm'),
                  words: _words!,
                  busy: _adding,
                  onAdd: _add,
                  onNotThem: _notThem,
                )
              : KeyedSubtree(key: const ValueKey('entry'), child: _entry()),
        ),
      ],
    );
  }

  Widget _entry() {
    final still = motionStill(context);
    final status = _status.isEmpty
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _status,
              key: ValueKey(_status),
              style: _warn
                  ? HaloType.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: HaloColors.rose,
                    )
                  : HaloType.mono(size: 11, color: HaloColors.text2),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pairCodeTypeTheSixDigits,
          style: HaloType.sans(size: 13.5, color: HaloColors.text2),
        ),
        const SizedBox(height: 20),
        TextField(
          textDirection: TextDirection.ltr,
          controller: _ctrl,
          keyboardType: TextInputType.number,
          maxLength: 7,
          textAlign: TextAlign.center,
          onSubmitted: (_) {
            if (!_busy) _join();
          },
          style: HaloType.mono(
            size: 28,
            weight: FontWeight.w600,
            color: HaloColors.text,
            letter: 0.14,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: HaloType.mono(size: 28, color: HaloColors.text3),
            filled: true,
            fillColor: HaloColors.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HaloColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HaloColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: HaloColors.amber.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PressScale(
          scale: 0.97,
          onTap: _busy ? null : _join,
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _busy ? HaloColors.surface2 : HaloColors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _busy ? l10n.pairCodeLooking : l10n.pairCodeAddThem,
              style: HaloType.mono(
                size: 12,
                weight: FontWeight.w600,
                color: _busy ? HaloColors.text2 : HaloColors.onAmber,
              ),
            ),
          ),
        ),
        // with less movement the line is simply there
        if (still)
          status
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.topStart,
            child: status,
          ),
      ],
    );
  }
}

/// the invite a code led to, before anything is added: its face and three
/// words, to be matched against the other phone
class PairConfirm extends StatelessWidget {
  final String words;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onNotThem;
  const PairConfirm({
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
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 14),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        children: [
          // the face settles a beat after the card, so the eye lands on it
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0.86, end: 1),
            duration: still ? Duration.zero : kHouseTime,
            curve: kHouseCurve,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: KryfoAvatar(seed: words, size: 84),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.pairCodeIsThisThem,
            textAlign: TextAlign.center,
            style: HaloType.serif(size: 24, weight: FontWeight.w400),
          ),
          const SizedBox(height: 10),
          Text(
            words,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: HaloType.mono(
              size: 18,
              weight: FontWeight.w600,
              color: HaloColors.amber,
              letter: 0.02,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.pairCodeCheckMatches,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13.5, color: HaloColors.text2),
          ),
          const SizedBox(height: 22),
          PressScale(
            scale: 0.97,
            onTap: busy ? null : onAdd,
            child: AnimatedContainer(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: busy ? HaloColors.surface3 : HaloColors.amber,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                l10n.commonAdd,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: busy ? HaloColors.text2 : HaloColors.onAmber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          PressScale(
            scale: 0.97,
            onTap: busy ? null : onNotThem,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  l10n.pairCodeNotThem,
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

/// the sharer's own three words under the code, so the other side has
/// something to match what it fetched against
class PairWordsTag extends StatelessWidget {
  final String words;
  const PairWordsTag({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.pairCodePanelYourWords,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 11.5, color: HaloColors.text2),
          ),
          const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}
