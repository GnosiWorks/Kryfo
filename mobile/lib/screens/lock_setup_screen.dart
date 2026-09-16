// SPDX-License-Identifier: GPL-3.0-or-later
// lock_setup_screen.dart - set or change the pin. four digits, then the
// same four again.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lock_state.dart';
import '../widgets/fit_column.dart';
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/pin_pad.dart';
import '../widgets/sheet_handle.dart';

class LockSetupScreen extends StatefulWidget {
  const LockSetupScreen({super.key});
  @override
  State<LockSetupScreen> createState() => _LockSetupScreenState();
}

class _LockSetupScreenState extends State<LockSetupScreen>
    with SingleTickerProviderStateMixin {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  bool _mismatch = false;
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

  Future<void> _onDigit(String d) async {
    if (_hold || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _mismatch = false;
    });
    if (_pin.length != 4) return;
    if (!_confirming) {
      setState(() => _hold = true);
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
        _hold = false;
      });
      return;
    }
    if (_pin != _first) {
      HapticFeedback.heavyImpact();
      setState(() => _mismatch = true);
      await _shake.forward(from: 0);
      if (!mounted) return;
      setState(() {
        _first = '';
        _pin = '';
        _confirming = false;
      });
      return;
    }
    final ok = await lockState.setupPin(_pin);
    if (!ok) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      showHaloToast(context, 'That is your wipe pin. Pick another.');
      setState(() {
        _first = '';
        _pin = '';
        _confirming = false;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    if (mounted && lockState.bioSupported && !lockState.biometric) {
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
                  'Unlock with fingerprint?',
                  style: HaloType.serif(size: 20, color: HaloColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  'The pin still works whenever you want it. This is just faster.',
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HaloColors.amber,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      'Use fingerprint',
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: HaloColors.onAmber,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        'Pin only',
                        style: HaloType.sans(size: 13, color: HaloColors.text2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (useBio == true) await lockState.setBiometric(true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final title = _confirming ? 'Once more' : 'Set a pin';
    final hint = _mismatch
        ? 'Those were different. From the top.'
        : _confirming
        ? 'The same four digits'
        : 'Four digits, anything you will remember';
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(a),
                  child: c,
                ),
              ),
              child: Text(
                title,
                key: ValueKey(title),
                style: HaloType.serif(size: 30, color: HaloColors.text),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: HaloType.sans(
                size: 13,
                color: _mismatch ? HaloColors.rose : HaloColors.text2,
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
            PinPad(onDigit: _onDigit, onBack: _back, enabled: !_hold),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
