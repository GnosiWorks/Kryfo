// SPDX-License-Identifier: GPL-3.0-or-later
// the pin pad and its dots, shared by the lock screen and the setup screens
// so they feel like one thing. a pin is 4 to 12 digits, a hidden chats pin 6
// to 12, and goes in with the enter key, never on its own, so when it goes in
// says nothing of its length.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

/// the shortest and the longest pin
const kPinMin = 4;
const kPinMax = 12;

/// the shortest hidden chats pin
const kVaultPinMin = 6;

class PinDots extends StatelessWidget {
  final int filled;
  final Color color;
  final bool wrong;
  // 0..1 while a wrong pin shakes, null when still
  final Animation<double>? shake;
  // the places shown before any digit: as many as the shortest pin takes
  final int min;
  const PinDots({
    super.key,
    required this.filled,
    required this.color,
    this.wrong = false,
    this.shake,
    this.min = kPinMin,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // the shortest pin's places to start with, then one more for each digit
    // past it
    final places = math.max(min, filled).clamp(min, kPinMax);
    final gap = places > 8 ? 5.0 : 11.0;
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(places, (i) {
        final on = i < filled;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gap),
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
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
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
    // with less movement the rose dots say it. the shake's clock still
    // runs, so the timing stays the same
    if (s == null || still) return row;
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
  // the enter key; dimmed and silent until [canEnter]
  final VoidCallback? onEnter;
  final bool canEnter;
  final bool enabled;
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBack,
    this.onEnter,
    this.canEnter = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
          if (onEnter == null)
            const SizedBox(width: 92, height: 72)
          else
            AnimatedOpacity(
              opacity: canEnter ? 1 : 0.35,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: _Key(
                icon: Icons.check_rounded,
                semantic: l10n.commonDone,
                strong: canEnter,
                onTap: enabled && canEnter ? onEnter : null,
              ),
            ),
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
  // what a screen reader says for an icon key
  final String? semantic;
  // the enter key once a pin can go in: amber
  final bool strong;
  const _Key({
    this.label,
    this.icon,
    this.onTap,
    this.semantic,
    this.strong = false,
  });
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bare = widget.icon != null;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
            duration: still ? Duration.zero : const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
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
                  ? Icon(
                      widget.icon,
                      size: widget.strong ? 26 : 22,
                      color: widget.strong
                          ? HaloColors.amber
                          : HaloColors.text2,
                      semanticLabel: widget.semantic,
                    )
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
