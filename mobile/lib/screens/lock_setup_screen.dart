// SPDX-License-Identifier: GPL-3.0-or-later
// set or change the pin: four digits, then the same four again. a change
// asks for the pin there is first, as the advanced flows do, with the same
// misses and the same wipe pin
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';

import '../lock_state.dart';
import '../widgets/fit_column.dart';
import '../theme.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/pin_pad.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/swap.dart';
import '../wipe.dart';
import '../l10n/l10n.dart';

class LockSetupScreen extends StatefulWidget {
  const LockSetupScreen({super.key, this.lock, this.check = false});
  // the app's own lock when null
  final LockState? lock;
  // a pin is set: it is entered before a new one is chosen
  final bool check;
  @override
  State<LockSetupScreen> createState() => _LockSetupScreenState();
}

class _LockSetupScreenState extends State<LockSetupScreen>
    with SingleTickerProviderStateMixin {
  String _first = '';
  String _pin = '';
  late bool _checking = widget.check;
  bool _confirming = false;
  bool _mismatch = false;
  // why the pin entered to check was not taken
  String? _notIt;
  // the title comes in from where reading goes, or back from where it was
  bool _forward = true;

  LockState get _lock => widget.lock ?? lockState;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  // the moment between the fourth digit and the confirm step. taps are
  // ignored so a backspace cannot shorten the pin being kept
  bool _hold = false;

  void _onDigit(String d) {
    if (_hold || _pin.length >= kPinMax) return;
    setState(() {
      _pin += d;
      _mismatch = false;
      _notIt = null;
    });
  }

  // the pin there is, before a new one. a miss counts as on the lock
  // screen, and the wipe pin wipes
  Future<void> _check() async {
    setState(() => _hold = true);
    final r = await _lock.confirmPin(_pin);
    if (!mounted) return;
    if (r == PinResult.panic) {
      await wipeHalo();
      return;
    }
    if (r != PinResult.normal) {
      HapticFeedback.heavyImpact();
      setState(() {
        _hold = false;
        _mismatch = true;
        _notIt = r == PinResult.throttled
            ? tooManyTriesLine(_lock.throttleLeft)
            : l10n.lockNotIt;
      });
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _shake.forward(from: 0);
      }
      if (mounted) setState(() => _pin = '');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _hold = false;
      _checking = false;
      _forward = true;
      _pin = '';
    });
  }

  Future<void> _submit() async {
    if (_hold || _pin.length < kPinMin) return;
    if (_checking) return _check();
    if (!_confirming) {
      setState(() => _hold = true);
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
        _forward = true;
        _hold = false;
      });
      return;
    }
    if (_pin != _first) {
      HapticFeedback.heavyImpact();
      setState(() => _mismatch = true);
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _shake.forward(from: 0);
      }
      if (!mounted) return;
      setState(() {
        _first = '';
        _pin = '';
        _confirming = false;
        _forward = false;
      });
      return;
    }
    final ok = await _lock.setupPin(_pin);
    if (!ok) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      showHaloToast(context, l10n.pinPickDifferent);
      setState(() {
        _first = '';
        _pin = '';
        _confirming = false;
        _forward = false;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    if (mounted && _lock.bioSupported && !_lock.biometricShown) {
      final useBio = await showHaloSheet<bool>(
        context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  l10n.lockSetupUnlockWithFingerprint,
                  style: HaloType.serif(size: 20, color: HaloColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.lockSetupThePinStillWorks,
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
                const SizedBox(height: 16),
                HaloPrimaryButton(
                  label: l10n.lockSetupUseFingerprint,
                  onTap: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
                HaloGhostButton(
                  label: l10n.lockSetupPinOnly,
                  quiet: true,
                  onTap: () => Navigator.pop(ctx, false),
                ),
              ],
            ),
          ),
        ),
      );
      if (useBio == true) await _lock.setBiometric(true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final title = _checking
        ? l10n.flowEnterYourPin
        : _confirming
        ? l10n.lockSetupOnceMore
        : l10n.lockSetupSetAPin;
    final hint = _checking
        ? _notIt ?? l10n.flowEnterYourPinLine
        : _mismatch
        ? l10n.lockSetupThoseWereDifferentFrom
        : _confirming
        ? l10n.lockSetupTheSameFourDigits
        : l10n.lockSetupFourDigitsAnythingYou;
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
      ),
      body: SafeArea(
        child: FitColumn(
          children: [
            const Spacer(flex: 2),
            // the confirm step comes in from the side reading goes towards,
            // as the pin flow's pages do
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (c, a) {
                final rtl = Directionality.of(context) == TextDirection.rtl;
                final entering = c.key == ValueKey(title);
                final from = (_forward ? 1.0 : -1.0) * (rtl ? -1 : 1);
                return FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset((entering ? 0.18 : -0.18) * from, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: c,
                  ),
                );
              },
              child: Text(
                title,
                key: ValueKey(title),
                style: HaloType.serif(size: 30, color: HaloColors.text),
              ),
            ),
            const SizedBox(height: 8),
            // the line under the title changes the way the title does
            RiseSwap(
              alignment: Alignment.center,
              child: Text(
                hint,
                key: ValueKey('$hint$_mismatch'),
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13,
                  color: _mismatch ? HaloColors.rose : HaloColors.text2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            PinDots(
              filled: _pin.length,
              color: HaloColors.amber,
              wrong: _mismatch,
              shake: _shake,
            ),
            const Spacer(flex: 3),
            PinPad(
              onDigit: _onDigit,
              onBack: _back,
              onEnter: _submit,
              canEnter: _pin.length >= kPinMin,
              enabled: !_hold,
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
