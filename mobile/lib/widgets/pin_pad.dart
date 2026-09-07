// SPDX-License-Identifier: GPL-3.0-or-later
// the pin pad and the four dots, shared by the lock screen and both setup
// screens so they feel like one thing. round keys that press, dots that
// land with a small overshoot, a shake when a pin is wrong.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class PinDots extends StatelessWidget {
  final int filled;
  final Color color;
  final bool wrong;
  // 0..1 while a wrong pin shakes, null when still
  final Animation<double>? shake;
  const PinDots({
    super.key,
    required this.filled,
    required this.color,
    this.wrong = false,
    this.shake,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final on = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: SizedBox(
            width: 16,
            height: 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: HaloColors.line2, width: 1),
                  ),
                ),
                AnimatedScale(
                  scale: on ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: on ? Curves.easeOutBack : Curves.easeIn,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: wrong ? HaloColors.rose : color,
                      boxShadow: [
                        BoxShadow(
                          color: (wrong ? HaloColors.rose : color).withValues(
                            alpha: 0.45,
                          ),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
    final s = shake;
    if (s == null) return row;
    return AnimatedBuilder(
      animation: s,
      child: row,
      builder: (_, child) {
        // three quick swings that die out
        final t = s.value;
        final dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

class PinPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBack;
  final bool enabled;
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBack,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: keys),
    );
    Widget d(String n) =>
        _Key(label: n, onTap: enabled ? () => onDigit(n) : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([d('1'), d('2'), d('3')]),
        row([d('4'), d('5'), d('6')]),
        row([d('7'), d('8'), d('9')]),
        row([
          const SizedBox(width: 92, height: 72),
          d('0'),
          _Key(icon: Icons.backspace_outlined, onTap: enabled ? onBack : null),
        ]),
      ],
    );
  }
}

class _Key extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _Key({this.label, this.icon, this.onTap});
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bare = widget.icon != null;
    return SizedBox(
      width: 92,
      height: 72,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null
              ? null
              : (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: AnimatedScale(
            scale: _down ? 0.88 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bare
                    ? Colors.transparent
                    : _down
                    ? HaloColors.amber.withValues(alpha: 0.18)
                    : HaloColors.surface2,
                border: bare
                    ? null
                    : Border.all(
                        color: _down ? HaloColors.amber : HaloColors.line,
                        width: 0.6,
                      ),
              ),
              child: bare
                  ? Icon(widget.icon, size: 22, color: HaloColors.text2)
                  : Text(
                      widget.label!,
                      style: HaloType.serif(
                        size: 27,
                        weight: FontWeight.w300,
                        color: HaloColors.text,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
