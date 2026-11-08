// SPDX-License-Identifier: GPL-3.0-or-later
// the security update: other pins typed once, so each moves under the
// phone's pin key. every pin typed gets the same answer at the same moment,
// a wrong one too, and none of them opens, wipes or switches anything. Done
// ends it for good.
import 'dart:async';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../lock_state.dart';
import '../pass_rules.dart';
import '../pin_shield.dart';
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/pass_pad.dart';
import '../widgets/pin_pad.dart';
import '../widgets/press_scale.dart';
import '../widgets/swap.dart';

class UpdatePinsScreen extends StatefulWidget {
  const UpdatePinsScreen({super.key, this.lock});
  // the app's own lock when null
  final LockState? lock;
  @override
  State<UpdatePinsScreen> createState() => _UpdatePinsScreenState();
}

class _UpdatePinsScreenState extends State<UpdatePinsScreen> with PinShield {
  String _pin = '';
  bool _busy = false;
  bool _letters = false;
  // what the last pin got back: null before any
  CardAnswer? _answer;
  // how many pins went in, so the answer rises in again each time
  int _taken = 0;
  Timer? _holdTick;

  LockState get _lock => widget.lock ?? lockState;

  @override
  void dispose() {
    _holdTick?.cancel();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_busy || _pin.length >= kPinMax) return;
    setState(() => _pin += d);
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_busy || passLength(_pin) < kPinMin) return;
    final typed = _pin;
    setState(() {
      _busy = true;
      _pin = '*' * passLength(typed);
    });
    final a = await _lock.cardTry(typed);
    if (!mounted) return;
    // one feel for every pin: nothing here may tell one from another
    HapticFeedback.lightImpact();
    setState(() {
      _answer = a;
      _taken++;
      _pin = '';
      _busy = false;
    });
    if (a == CardAnswer.held) _watchHold();
  }

  void _watchHold() {
    _holdTick?.cancel();
    _holdTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_lock.throttleLeft == Duration.zero) _holdTick?.cancel();
    });
  }

  Future<void> _done() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    await _lock.cardFinished();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final held = _lock.throttleLeft > Duration.zero;
    final line = held
        ? tooManyTriesLine(_lock.throttleLeft)
        : switch (_answer) {
            CardAnswer.taken => l10n.cardAnswer,
            CardAnswer.unavailable => keyNoteLine(_lock),
            CardAnswer.held => tooManyTriesLine(_lock.throttleLeft),
            null => l10n.cardLine,
          };
    return Scaffold(
      backgroundColor: HaloColors.ink,
      resizeToAvoidBottomInset: _letters,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: PressScale(
              onTap: _busy ? null : _done,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  l10n.commonDone,
                  style: HaloType.sans(
                    size: 15,
                    weight: FontWeight.w600,
                    color: HaloColors.amberText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FitColumn(
          children: [
            const Spacer(flex: 2),
            Text(
              l10n.cardType,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 30, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Semantics(
                liveRegion: true,
                child: RiseSwap(
                  alignment: Alignment.center,
                  child: Text(
                    line,
                    key: ValueKey('$line$_taken'),
                    textAlign: TextAlign.center,
                    style: HaloType.sans(size: 13, color: HaloColors.text),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            PinDots(
              filled: passLength(_pin),
              color: HaloColors.amber,
              letters: _letters,
            ),
            const Spacer(flex: 3),
            PassPad(
              letters: _letters,
              onLetters: (v) => setState(() {
                _letters = v;
                _pin = '';
              }),
              onDigit: _onDigit,
              onBack: _back,
              onText: (t) => setState(() => _pin = t),
              text: _pin,
              onEnter: _submit,
              canEnter: passLength(_pin) >= kPinMin && !held,
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
