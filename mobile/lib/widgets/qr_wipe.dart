// SPDX-License-Identifier: GPL-3.0-or-later
// a code that assembles corner to corner, the way reading goes, instead of
// fading in. it waits a beat so the card around it has settled first
import 'package:flutter/material.dart';

class QrWipe extends StatefulWidget {
  final Widget child;
  // false keeps it hidden, for a code still on its way
  final bool shown;
  const QrWipe({super.key, required this.child, this.shown = true});

  @override
  State<QrWipe> createState() => _QrWipeState();
}

class _QrWipeState extends State<QrWipe> with SingleTickerProviderStateMixin {
  // the first third is the beat before it starts
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );
  static const _soft = 0.18;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _go();
  }

  @override
  void didUpdateWidget(QrWipe old) {
    super.didUpdateWidget(old);
    if (!old.shown && widget.shown) _go();
  }

  void _go() {
    if (!widget.shown || _c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        if (!widget.shown) return Opacity(opacity: 0, child: child);
        if (_c.isCompleted) return child!;
        final t = Curves.easeOutCubic.transform(
          const Interval(0.36, 1).transform(_c.value),
        );
        final edge = -_soft + (1 + 2 * _soft) * t;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            begin: AlignmentDirectional.topStart.resolve(dir),
            end: AlignmentDirectional.bottomEnd.resolve(dir),
            colors: const [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, edge.clamp(0.0, 1.0), (edge + _soft).clamp(0.0, 1.0), 1],
          ).createShader(r),
          child: child,
        );
      },
    );
  }
}
