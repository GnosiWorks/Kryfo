// SPDX-License-Identifier: GPL-3.0-or-later
// pin entry over the whole app when locked. with biometrics on, the
// fingerprint prompt fires on entry; "use fingerprint" fires it again.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lock_state.dart';
import '../wipe.dart';
import '../widgets/fit_column.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  bool _wrong = false;
  // counts the hold down once a second while the pad is held
  Timer? _holdTick;
  bool get _held => lockState.throttleLeft > Duration.zero;
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
  )..repeat(reverse: true);
  late final Animation<double> _breathOpacity = Tween(
    begin: 0.15,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    _watchHold();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (lockState.biometric && lockState.bioSupported) {
        lockState.tryBiometric();
      }
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    _breath.dispose();
    _holdTick?.cancel();
    super.dispose();
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) {
      setState(() => _busy = true);
      final result = await lockState.verifyPin(_pin);
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

  void _back() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              animation: lockState,
              builder: (_, _) => FitColumn(
                children: [
                  const Spacer(flex: 3),
                  Text(
                    'kryfo',
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
                          ? l10n.lockTooManyTriesS(
                              whole(lockState.throttleLeft.inSeconds + 1),
                            )
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
                  if (lockState.biometric && lockState.bioSupported)
                    GestureDetector(
                      onTap: () => lockState.tryBiometric(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: HaloColors.surface2,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: HaloColors.line,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fingerprint,
                              color: HaloColors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.lockUseFingerprint,
                              style: HaloType.sans(
                                size: 12.5,
                                color: HaloColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(flex: 2),
                  PinPad(onDigit: _onDigit, onBack: _back, enabled: !_busy),
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
