// SPDX-License-Identifier: GPL-3.0-or-later
// the house progress bar. a known amount glides to its new value; an
// unknown one is a short warm light moving along the track.
import 'package:flutter/material.dart';

import '../theme.dart';

class HaloBar extends StatelessWidget {
  /// 0..1, or null while the amount is not known yet
  final double? value;
  final double height;
  final Color? color;
  final Color? track;

  /// the first value grows out of zero instead of appearing at its place
  final bool grow;
  final Duration duration;

  const HaloBar({
    super.key,
    required this.value,
    this.height = 4,
    this.color,
    this.track,
    this.grow = false,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final fg = color ?? HaloColors.amber;
    final bg = track ?? HaloColors.surface3;
    final r = BorderRadius.circular(height);
    final v = value;
    if (v == null) {
      return _Sweep(height: height, color: fg, track: bg, still: still);
    }
    final end = v.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: grow ? 0 : end, end: end),
      duration: still ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (_, f, _) => ClipRRect(
        borderRadius: r,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: bg)),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: f,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fg, borderRadius: r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sweep extends StatefulWidget {
  final double height;
  final Color color;
  final Color track;
  final bool still;
  const _Sweep({
    required this.height,
    required this.color,
    required this.track,
    required this.still,
  });
  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _c.repeat();
  }

  @override
  void didUpdateWidget(_Sweep old) {
    super.didUpdateWidget(old);
    if (widget.still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.height);
    return ClipRRect(
      borderRadius: r,
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (_, box) {
            final w = box.maxWidth;
            final seg = w * 0.32;
            return AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                // still: a third of the track, lit and not moving
                final t = widget.still
                    ? 0.5
                    : Curves.easeInOutSine.transform(_c.value);
                final x = -seg + (w + seg) * t;
                return Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: widget.track)),
                    PositionedDirectional(
                      start: x,
                      top: 0,
                      bottom: 0,
                      width: seg,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: r,
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withValues(alpha: 0),
                              widget.color,
                              widget.color.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
