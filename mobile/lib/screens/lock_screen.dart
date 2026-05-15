// lock_screen.dart — pin entry over the entire app when locked.
// 4-digit pin, custom keypad, no system keyboard. wrong pin shakes.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lock_state.dart';
import '../theme.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  bool _wrong = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _pin.length >= 4) return;
    setState(() => _pin += d);
    HapticFeedback.selectionClick();
    if (_pin.length == 4) {
      setState(() => _busy = true);
      final ok = await lockState.verifyPin(_pin);
      if (!ok && mounted) {
        setState(() {
          _wrong = true;
          _pin = '';
          _busy = false;
        });
        HapticFeedback.heavyImpact();
        await _shake.forward(from: 0);
        if (mounted) setState(() => _wrong = false);
      }
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text('halo',
                style: HaloType.serif(
                    size: 36, color: HaloColors.amber, italic: true)),
            const SizedBox(height: 16),
            Text('enter your pin',
                style: HaloType.sans(size: 13, color: HaloColors.text2)),
            const SizedBox(height: 36),
            AnimatedBuilder(
              animation: _shake,
              builder: (_, child) {
                final dx = _wrong
                    ? (8 * (1 - _shake.value)) *
                        (((_shake.value * 12) % 2).toInt() == 0 ? 1 : -1)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_wrong ? HaloColors.rose : HaloColors.amber)
                          : Colors.transparent,
                      border: Border.all(
                        color: HaloColors.text3,
                        width: 0.8,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Spacer(flex: 1),
            _Keypad(onDigit: _onDigit, onBack: _back),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onBack;
  const _Keypad({required this.onDigit, required this.onBack});

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, {VoidCallback? onTap, bool isBack = false}) {
      return GestureDetector(
        onTap: onTap ?? () => onDigit(label),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: isBack
              ? const Icon(Icons.backspace_outlined,
                  color: Color(0xFFAAAAAA), size: 22)
              : Text(
                  label,
                  style: HaloType.serif(
                      size: 30, color: HaloColors.text, weight: FontWeight.w300),
                ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            btn('1'), btn('2'), btn('3'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            btn('4'), btn('5'), btn('6'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            btn('7'), btn('8'), btn('9'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const SizedBox(width: 72, height: 72),
            btn('0'),
            btn('', onTap: onBack, isBack: true),
          ]),
        ],
      ),
    );
  }
}
