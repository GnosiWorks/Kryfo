// SPDX-License-Identifier: GPL-3.0-or-later
// "Typing" and three small dots after it, in reading order, as the chat
// header and the chat list show a contact typing. the dots rise one after
// another in reading direction; with motion off they stand still and no
// ticker runs
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart' show HaloColors, HaloType;
import 'motion.dart' show motionStill;
import 'swap.dart';

const kTypingDot = 3.5;
const kTypingWave = Duration(milliseconds: 1200);

class TypingMark extends StatefulWidget {
  const TypingMark({super.key, required this.color, this.dot = kTypingDot});

  final Color color;
  final double dot;

  @override
  State<TypingMark> createState() => _TypingMarkState();
}

class _TypingMarkState extends State<TypingMark> with TickerProviderStateMixin {
  AnimationController? _wave;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionStill(context)) {
      _wave?.dispose();
      _wave = null;
    } else {
      _wave ??= AnimationController(vsync: this, duration: kTypingWave)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _wave?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wave = _wave;
    return ExcludeSemantics(
      child: SizedBox(
        // the rise stays inside the line, so nothing around it moves
        height: widget.dot * 2.4,
        child: wave == null
            ? _row(null)
            : AnimatedBuilder(
                animation: wave,
                builder: (_, _) => _row(wave.value),
              ),
      ),
    );
  }

  Widget _row(double? t) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: i == 0 ? 0 : widget.dot * 0.7,
          ),
          child: _dot(t == null ? null : (t - i * 0.18) % 1.0),
        ),
    ],
  );

  // each dot lifts and brightens for the first part of its turn, then rests
  Widget _dot(double? ph) {
    final up = ph == null || ph > 0.4 ? 0.0 : math.sin(ph / 0.4 * math.pi);
    return Transform.translate(
      offset: Offset(0, -up * widget.dot * 0.4),
      child: Container(
        width: widget.dot,
        height: widget.dot,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(
            alpha: ph == null ? 0.8 : 0.45 + 0.55 * up,
          ),
        ),
      ),
    );
  }
}

/// the word and the dots on one line, ending in … at a big font size
class TypingLine extends StatelessWidget {
  const TypingLine({super.key, required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final color = style.color ?? HaloColors.amberText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            l10n.typingNow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        SizedBox(width: (style.fontSize ?? 12) * 0.4),
        TypingMark(color: color),
      ],
    );
  }
}

/// the typing line in the accent tone at [size], as both places show it
TextStyle typingStyle({required double size, bool mono = false}) => mono
    ? HaloType.mono(size: size, color: HaloColors.amberText)
    : HaloType.sans(size: size, color: HaloColors.amberText);

/// [child] while [showing] is off, the typing line in its place while it
/// is on: a rise in and out, instant with motion off. one line either way,
/// so what holds it keeps its height
class TypingSwap extends StatelessWidget {
  const TypingSwap({
    super.key,
    required this.showing,
    required this.style,
    required this.child,
  });

  final ValueListenable<bool> showing;
  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: showing,
    builder: (_, on, other) => RiseSwap(
      child: on
          ? TypingLine(key: const ValueKey('typing'), style: style)
          : KeyedSubtree(key: const ValueKey('other'), child: other!),
    ),
    child: child,
  );
}
