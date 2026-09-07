// SPDX-License-Identifier: GPL-3.0-or-later
// panic_setup_screen.dart - the wipe pin. entered on the lock screen it
// silently wipes kryfo and exits; to whoever is holding the phone it looks
// like the app crashed. must differ from the real pin.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lock_state.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';

class PanicSetupScreen extends StatefulWidget {
  const PanicSetupScreen({super.key});
  @override
  State<PanicSetupScreen> createState() => _PanicSetupScreenState();
}

class _PanicSetupScreenState extends State<PanicSetupScreen>
    with SingleTickerProviderStateMixin {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  String? _error;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _fail(String why) async {
    HapticFeedback.heavyImpact();
    setState(() => _error = why);
    await _shake.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _first = '';
      _pin = '';
      _confirming = false;
    });
  }

  Future<void> _onDigit(String d) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length != 4) return;
    if (!_confirming) {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }
    if (_pin != _first) {
      await _fail('those were different. from the top.');
      return;
    }
    final ok = await lockState.setupPanicPin(_pin);
    if (!ok) {
      await _fail('that is your real pin. pick another.');
      return;
    }
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final title = _confirming ? 'once more' : 'set a wipe pin';
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
      ),
      body: SafeArea(
        child: Column(
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
              _error ??
                  (_confirming
                      ? 'the same four digits'
                      : 'the second pin wipes everything.'),
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13,
                color: _error != null ? HaloColors.rose : HaloColors.text2,
              ),
            ),
            const SizedBox(height: 32),
            PinDots(
              filled: _pin.length,
              color: HaloColors.rose,
              wrong: _error != null,
              shake: _shake,
            ),
            const Spacer(flex: 3),
            PinPad(onDigit: _onDigit, onBack: _back),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
