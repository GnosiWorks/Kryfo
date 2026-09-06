// SPDX-License-Identifier: GPL-3.0-or-later
// lock_setup_screen.dart - first-time pin setup. enter pin twice, confirm.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lock_state.dart';
import '../theme.dart';

class LockSetupScreen extends StatefulWidget {
  const LockSetupScreen({super.key});
  @override
  State<LockSetupScreen> createState() => _LockSetupScreenState();
}

class _LockSetupScreenState extends State<LockSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  bool _mismatch = false;

  void _onDigit(String d) async {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _mismatch = false;
    });
    HapticFeedback.selectionClick();
    if (_pin.length == 4) {
      if (!_confirming) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          _first = _pin;
          _pin = '';
          _confirming = true;
        });
      } else {
        if (_pin == _first) {
          await lockState.setupPin(_pin);
          if (mounted && lockState.bioSupported) {
            final useBio = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: HaloColors.surface3,
                title: Text(
                  'unlock with fingerprint?',
                  style: HaloType.serif(size: 18, color: HaloColors.text),
                ),
                content: Text(
                  "you can still use your pin anytime - fingerprint is just faster.",
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'not now',
                      style: HaloType.sans(size: 13, color: HaloColors.text2),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(
                      'enable',
                      style: HaloType.sans(size: 13, color: HaloColors.amber),
                    ),
                  ),
                ],
              ),
            );
            if (useBio == true) await lockState.setBiometric(true);
          }
          if (mounted) Navigator.of(context).pop();
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _mismatch = true;
            _first = '';
            _pin = '';
            _confirming = false;
          });
        }
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
    final title = _confirming ? 'confirm pin' : 'set a pin';
    final hint = _mismatch
        ? "didn't match - try again"
        : (_confirming
              ? 'enter the same 4 digits'
              : '4 digits, anything you can remember');
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          'app lock',
          style: HaloType.serif(size: 18, color: HaloColors.text, italic: true),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              title,
              style: HaloType.serif(
                size: 28,
                color: HaloColors.text,
                weight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: HaloType.sans(
                size: 12,
                color: _mismatch ? HaloColors.rose : HaloColors.text2,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? HaloColors.amber : Colors.transparent,
                    border: Border.all(color: HaloColors.text3, width: 0.8),
                  ),
                );
              }),
            ),
            const Spacer(),
            _SetupKeypad(onDigit: _onDigit, onBack: _back),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _SetupKeypad extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onBack;
  const _SetupKeypad({required this.onDigit, required this.onBack});

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, {VoidCallback? onTap, bool isBack = false}) =>
        GestureDetector(
          onTap: onTap ?? () => onDigit(label),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            child: isBack
                ? Icon(
                    Icons.backspace_outlined,
                    color: HaloColors.text2,
                    size: 22,
                  )
                : Text(
                    label,
                    style: HaloType.serif(
                      size: 30,
                      color: HaloColors.text,
                      weight: FontWeight.w300,
                    ),
                  ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [btn('1'), btn('2'), btn('3')],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [btn('4'), btn('5'), btn('6')],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [btn('7'), btn('8'), btn('9')],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 72, height: 72),
              btn('0'),
              btn('', onTap: onBack, isBack: true),
            ],
          ),
        ],
      ),
    );
  }
}
