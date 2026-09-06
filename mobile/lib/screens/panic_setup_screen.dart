// SPDX-License-Identifier: GPL-3.0-or-later
// panic_setup_screen.dart - set a panic pin distinct from the
// normal pin. entering it on the lock screen silently wipes kryfo
// and exits. for coercion scenarios where you want plausible
// deniability - to the attacker it looks like the app crashed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lock_state.dart';
import '../theme.dart';

class PanicSetupScreen extends StatefulWidget {
  const PanicSetupScreen({super.key});
  @override
  State<PanicSetupScreen> createState() => _PanicSetupScreenState();
}

class _PanicSetupScreenState extends State<PanicSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  String? _error;

  void _onDigit(String d) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    HapticFeedback.selectionClick();
    if (_pin.length != 4) return;

    if (!_confirming) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }

    if (_pin != _first) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = "didn't match. try again.";
        _first = '';
        _pin = '';
        _confirming = false;
      });
      return;
    }

    final ok = await lockState.setupPanicPin(_pin);
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = "panic pin can't be the same as your normal pin.";
        _first = '';
        _pin = '';
        _confirming = false;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          'panic pin',
          style: HaloType.serif(size: 22, color: HaloColors.text, italic: true),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "this pin will silently wipe kryfo when entered on the lock screen. it must be different from your normal pin.",
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _confirming ? 'confirm panic pin' : 'set panic pin',
              style: HaloType.serif(
                size: 16,
                color: HaloColors.text,
                italic: true,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? HaloColors.rose : HaloColors.surface3,
                    border: Border.all(color: HaloColors.line, width: 0.5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(size: 12, color: HaloColors.rose),
                ),
              ),
            const Spacer(),
            _Pad(onDigit: _onDigit, onBack: _back),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBack;
  const _Pad({required this.onDigit, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: rows
            .map(
              (r) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: r.map((d) {
                  if (d.isEmpty) return const SizedBox(width: 64, height: 64);
                  if (d == 'back') {
                    return SizedBox(
                      width: 64,
                      height: 64,
                      child: InkWell(
                        onTap: onBack,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Icon(
                            Icons.backspace_outlined,
                            color: HaloColors.text2,
                            size: 22,
                          ),
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: InkWell(
                      onTap: () => onDigit(d),
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Text(
                          d,
                          style: HaloType.serif(
                            size: 26,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}
