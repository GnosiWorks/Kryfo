// SPDX-License-Identifier: GPL-3.0-or-later
// the copy glyph beside something that copies. after a copy it turns into a
// tick for a moment, so the row itself says it worked, then turns back
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

class CopiedMark extends StatefulWidget {
  // bumped by the owner on every copy
  final int copies;
  final double size;
  final Color? color;
  final Color? done;
  const CopiedMark({
    super.key,
    required this.copies,
    this.size = 14,
    this.color,
    this.done,
  });

  @override
  State<CopiedMark> createState() => _CopiedMarkState();
}

class _CopiedMarkState extends State<CopiedMark>
    with SingleTickerProviderStateMixin {
  // 0 the copy glyph, 1 the tick
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 200),
  );
  Timer? _back;

  @override
  void didUpdateWidget(CopiedMark old) {
    super.didUpdateWidget(old);
    if (old.copies == widget.copies) return;
    _back?.cancel();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward(from: _c.value);
    }
    // held long enough to be seen, then back to what the row does
    _back = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 0;
      } else {
        _c.reverse();
      }
    });
  }

  @override
  void dispose() {
    _back?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.color ?? HaloColors.text3;
    final done = widget.done ?? HaloColors.green;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size + 4,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final v = _c.value;
            // the tick pops with a little overshoot, the glyph just fades
            final pop = _c.status == AnimationStatus.reverse
                ? v
                : Curves.easeOutBack.transform(v);
            return Stack(
              alignment: Alignment.center,
              children: [
                if (v < 1)
                  Opacity(
                    opacity: 1 - v,
                    child: Icon(
                      Icons.copy_outlined,
                      size: widget.size,
                      color: idle,
                    ),
                  ),
                if (v > 0)
                  Opacity(
                    opacity: v,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * pop,
                      child: Icon(
                        Icons.check_rounded,
                        size: widget.size + 2,
                        color: done,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
