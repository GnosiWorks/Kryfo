// SPDX-License-Identifier: GPL-3.0-or-later
// pin entry over the whole app when locked. with biometrics on, the
// fingerprint prompt fires on entry; "use fingerprint" fires it again.

import 'dart:async';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import '../lock_state.dart';
import '../wipe.dart';
import '../widgets/fit_column.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';
import '../l10n/l10n.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.lock});
  // the app's own lock when null
  final LockState? lock;
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  bool _wrong = false;
  LockState get _lock => widget.lock ?? lockState;
  // counts the hold down once a second while the pad is held
  Timer? _holdTick;
  bool get _held => _lock.throttleLeft > Duration.zero;
  void _watchHold() {
    _holdTick?.cancel();
    if (!_held) return;
    _holdTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_held) _holdTick?.cancel();
    });
  }

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: 1,
  );
  late final Animation<double> _breathOpacity = Tween(
    begin: 0.15,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut));

  bool _breathed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // one breath in as the pad comes up, then it rests: a pad left up must
    // not keep drawing. still with less movement
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 1;
    } else if (!_breathed) {
      _breath.forward(from: 0);
    }
    _breathed = true;
  }

  @override
  void initState() {
    super.initState();
    _watchHold();
    _lock.addListener(_onLock);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fingerWhenInFront());
  }

  // the prompt only while the app is in front: the pad goes up as the app
  // leaves, and a prompt asked for then is gone on the way back
  AppLifecycleListener? _toFront;
  void _fingerWhenInFront() {
    if (!mounted || !_fingerReady) return;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _lock.tryBiometric();
      return;
    }
    _toFront ??= AppLifecycleListener(
      onResume: () {
        _toFront?.dispose();
        _toFront = null;
        if (mounted && _fingerReady) _lock.tryBiometric();
      },
    );
  }

  // fingerprint is on, but a finger added since (or an update) put it to
  // sleep until the PIN is typed once
  bool get _fingerOn => _lock.biometric && _lock.bioSupported;
  bool get _fingerReady => _fingerOn && !_lock.bioStale;

  void _onLock() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lock.removeListener(_onLock);
    _shake.dispose();
    _toFront?.dispose();
    _breath.dispose();
    _holdTick?.cancel();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_busy || _pin.length >= kPinMax) return;
    setState(() => _pin += d);
  }

  Future<void> _submit() async {
    if (_busy || _pin.length < kPinMin) return;
    setState(() => _busy = true);
    {
      final typed = _pin;
      // the digits leave the screen's hands as soon as they are handed on
      setState(() => _pin = '*' * typed.length);
      final result = await _lock.verifyPin(typed);
      if (result == PinResult.panic) {
        // silent wipe: the screen stays as if processing, then kryfo exits,
        // which looks like a crash
        await wipeHalo();
        return;
      }
      if ((result == PinResult.invalid || result == PinResult.throttled) &&
          mounted) {
        _watchHold();
        setState(() => _wrong = true);
        HapticFeedback.heavyImpact();
        await _shake.forward(from: 0);
        if (mounted) {
          setState(() {
            _wrong = false;
            _pin = '';
            _busy = false;
          });
        }
      }
    }
  }

  Widget _fingerButton() {
    return GestureDetector(
      key: const ValueKey('ready'),
      onTap: () => _lock.tryBiometric(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint, color: HaloColors.amber, size: 18),
            const SizedBox(width: 8),
            Text(
              l10n.lockUseFingerprint,
              style: HaloType.sans(size: 12.5, color: HaloColors.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fingerAsleep() {
    return Padding(
      key: const ValueKey('asleep'),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        l10n.lockFingerAfterPin,
        textAlign: TextAlign.center,
        style: HaloType.sans(size: 12.5, color: HaloColors.text2),
      ),
    );
  }

  void _back() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // the keyboard of the screen under it goes down as it comes up: the
      // pad stays where it is
      resizeToAvoidBottomInset: false,
      backgroundColor: HaloColors.ink,
      body: Stack(
        children: [
          // a slow amber breath behind the wordmark, like the reveal. one
          // gradient, painted once; only its opacity moves, on the compositor
          Positioned.fill(
            child: RepaintBoundary(
              child: FadeTransition(
                opacity: _breathOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.55),
                      radius: 0.8,
                      colors: [
                        HaloColors.amber.withValues(alpha: 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _lock,
              builder: (_, _) => FitColumn(
                children: [
                  const Spacer(flex: 3),
                  Text(
                    'Kryfo',
                    style: HaloType.serif(
                      size: 40,
                      color: HaloColors.amber,
                      italic: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(width: 28, height: 0.5, color: HaloColors.line2),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _held
                          ? tooManyTriesLine(_lock.throttleLeft)
                          : _wrong
                          ? l10n.lockNotIt
                          : l10n.lockYourPin,
                      key: ValueKey(_held ? 'held' : _wrong),
                      style: HaloType.sans(
                        size: 13,
                        color: _wrong || _held
                            ? HaloColors.rose
                            : HaloColors.text2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  PinDots(
                    filled: _pin.length,
                    color: HaloColors.amber,
                    wrong: _wrong,
                    shake: _shake,
                  ),
                  const SizedBox(height: 26),
                  if (_fingerOn)
                    AnimatedSwitcher(
                      duration: MediaQuery.of(context).disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: _fingerReady ? _fingerButton() : _fingerAsleep(),
                    ),
                  const Spacer(flex: 2),
                  PinPad(
                    onDigit: _onDigit,
                    onBack: _back,
                    onEnter: _submit,
                    canEnter: _pin.length >= kPinMin,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
