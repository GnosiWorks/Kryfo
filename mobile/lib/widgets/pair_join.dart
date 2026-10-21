// SPDX-License-Identifier: GPL-3.0-or-later
// the joining side of a pairing code. six digits in, the invite they point
// at out, and nothing added until the person has matched its key number
// against the other phone's screen. the three words only name them: anyone
// can put them in an invite. a code that points at more than one invite is
// refused outright.
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../main.dart' show inviteKeyNumber, parseHaloUri;
import '../rooms.dart' show firstKryfoLink;
import '../theme.dart';
import 'kryfo_avatar.dart';
import 'motion.dart' show kHouseCurve, kHouseTime, motionStill;
import 'pair_code_panel.dart' show kPairCodeLife;
import 'halo_buttons.dart';
import 'press_scale.dart';

/// the engine's answer when no relay took a share or answered a lookup
const pairUnreached = 'error: unreached';

/// an engine error, worded for the person
String pairErrorText(String res) =>
    res == pairUnreached ? l10n.pairCodeUnreached : l10n.pairCodeFailed;

/// what a code's address held, if it is one invite and nothing else: the
/// number shown and the add both read this one string, so nothing after it
/// can name another key. an old card with no bundle is no code's invite
String? pairInviteExact(String payload) {
  if (payload.contains(RegExp(r'\s'))) return null;
  if (firstKryfoLink(payload) != payload) return null;
  final parsed = parseHaloUri(payload);
  if (parsed == null || parsed['bundle'] == null) return null;
  return payload;
}

/// the three words a fetched invite names, or null when it names none
String? pairInviteWords(String invite) {
  final exact = pairInviteExact(invite);
  return exact == null ? null : parseHaloUri(exact)?['id'];
}

/// the clock codes are counted on. tests set it to the fake one
DateTime Function() pairNow = DateTime.now;

/// typed digits as 0-9: persian and arabic-indic ones count, the rest goes
String pairDigits(String typed) {
  final b = StringBuffer();
  for (final r in typed.runes) {
    if (r >= 0x30 && r <= 0x39) {
      b.writeCharCode(r);
    } else if (r >= 0x6F0 && r <= 0x6F9) {
      b.writeCharCode(0x30 + r - 0x6F0);
    } else if (r >= 0x660 && r <= 0x669) {
      b.writeCharCode(0x30 + r - 0x660);
    }
  }
  return b.toString();
}

// an invite turned away with not them, until its code burns: the joiner
// cannot burn the code, so the same code is not offered again here. kept
// as a hash of code and invite, never in the clear
final _refused = <String, DateTime>{};

String _refusal(String code, String invite) =>
    sha256.convert(utf8.encode('$code\n$invite')).toString();

bool _wasRefused(String code, String invite) {
  final now = pairNow();
  _refused.removeWhere((_, until) => !until.isAfter(now));
  return _refused.containsKey(_refusal(code, invite));
}

@visibleForTesting
void forgetPairRefusals() => _refused.clear();

class PairJoin extends StatefulWidget {
  // the engine's answer for a code: an invite, "empty", "twice",
  // [pairUnreached] or another error
  final Future<String> Function(String code) fetch;
  // the app's own add path; its answer is the line to show afterwards
  final Future<String> Function(String invite) add;
  final void Function(String status) onAdded;
  // between looks while the other side has not shared yet
  final Duration retryGap;
  // the key number of a fetched invite, from the key its session runs on
  final String? Function(String invite) numberOf;
  const PairJoin({
    super.key,
    required this.fetch,
    required this.add,
    required this.onAdded,
    this.retryGap = const Duration(seconds: 4),
    this.numberOf = inviteKeyNumber,
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
  String? _number;
  String? _code;

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
    final code = pairDigits(_ctrl.text);
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
        // words, number and add all from this one exact string
        final exact = pairInviteExact(res);
        final words = exact == null ? null : pairInviteWords(exact);
        // no key that reads is no number to match, and nothing to add
        final number = words == null ? null : widget.numberOf(exact!);
        if (exact == null || words == null || number == null) {
          _say(l10n.pairCodeNothingAtThatCode);
          return;
        }
        if (_wasRefused(code, exact)) {
          HapticFeedback.heavyImpact();
          _ctrl.clear();
          _say(l10n.pairCodeNotAdded, warn: true);
          return;
        }
        HapticFeedback.lightImpact();
        setState(() {
          _busy = false;
          _status = '';
          _invite = exact;
          _words = words;
          _number = number;
          _code = code;
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
    final code = _code, invite = _invite;
    if (code != null && invite != null) {
      _refused[_refusal(code, invite)] = pairNow().add(kPairCodeLife);
    }
    _ctrl.clear();
    setState(() {
      _invite = null;
      _words = null;
      _number = null;
      _code = null;
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
                  number: _number!,
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
          enableIMEPersonalizedLearning: false,
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
        HaloPrimaryButton(
          label: _busy ? l10n.pairCodeLooking : l10n.pairCodeAddThem,
          busy: _busy,
          onTap: _join,
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
      ],
    );
  }
}

/// the invite a code led to, before anything is added: who it names, and
/// its key number to be matched against the other phone
class PairConfirm extends StatelessWidget {
  final String words;
  final String number;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onNotThem;
  const PairConfirm({
    super.key,
    required this.words,
    required this.number,
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
          const SizedBox(height: 20),
          PairKeyNumber(number: number, size: 22),
          const SizedBox(height: 12),
          Text(
            l10n.pairCodeNumberMatches,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13.5, color: HaloColors.text2),
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
                  l10n.pairCodeNumberDiffers,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(size: 13.5, color: HaloColors.text2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // an older Kryfo on the other side shows no number
          Text(
            l10n.pairCodeNoNumberThere,
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 12,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// a key number, four groups of five. digits in the same order on every
/// phone whatever its language, so two people can read them side by side
class PairKeyNumber extends StatelessWidget {
  final String number;
  final double size;
  const PairKeyNumber({super.key, required this.number, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final groups = number.split(' ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.pairCodeKeyNumber,
          textAlign: TextAlign.center,
          style: HaloType.sans(size: 11.5, color: HaloColors.text2),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: number,
          textDirection: TextDirection.ltr,
          excludeSemantics: true,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: size * 0.6,
              runSpacing: 6,
              children: [
                for (final g in groups)
                  Text(
                    g,
                    style: HaloType.mono(
                      size: size,
                      weight: FontWeight.w600,
                      color: HaloColors.amberText,
                      letter: 0.06,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// the sharer's own three words under the code, and the key number the
/// other side matches what it fetched against. no number when it did not
/// read: then there is nothing to match
class PairWordsTag extends StatelessWidget {
  final String words;
  final String? number;
  const PairWordsTag({super.key, required this.words, this.number});

  @override
  Widget build(BuildContext context) {
    final n = number;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 11),
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
          if (n != null) ...[
            const SizedBox(height: 10),
            PairKeyNumber(number: n),
            const SizedBox(height: 8),
            Text(
              l10n.pairCodeNumberMatches,
              textAlign: TextAlign.center,
              style: HaloType.sans(size: 12, color: HaloColors.text2),
            ),
          ],
        ],
      ),
    );
  }
}
