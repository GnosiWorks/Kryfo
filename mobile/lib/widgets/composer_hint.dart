// SPDX-License-Identifier: GPL-3.0-or-later
// the composer's placeholder: one line, shrunk to the field rather than cut.
// at 200% on a narrow phone the field beside the buttons holds only a letter
// of "Message" at full size
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';

class ComposerHint extends StatelessWidget {
  final String text;
  const ComposerHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => _ShrinkToFit(
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: HaloType.sans(size: 14, color: HaloColors.text3),
    ),
  );
}

// a fitted box whose baseline is the shrunk text's, so the field lines the
// word up with what is typed
class _ShrinkToFit extends SingleChildRenderObjectWidget {
  const _ShrinkToFit({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShrinkToFit(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderShrinkToFit r) =>
      r.textDirection = Directionality.of(context);
}

class _RenderShrinkToFit extends RenderFittedBox {
  _RenderShrinkToFit(TextDirection dir)
    : super(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        textDirection: dir,
      );

  static double _scale(Size outer, Size inner) {
    if (inner.isEmpty) return 1;
    return math.min(
      1,
      math.min(outer.width / inner.width, outer.height / inner.height),
    );
  }

  static double _place(Size outer, Size inner, double base) {
    final s = _scale(outer, inner);
    return (outer.height - inner.height * s) / 2 + base * s;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final c = child;
    final base = c?.getDistanceToActualBaseline(baseline);
    if (c == null || base == null) return null;
    return _place(size, c.size, base);
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final c = child;
    if (c == null) return null;
    const loose = BoxConstraints();
    final base = c.getDryBaseline(loose, baseline);
    if (base == null) return null;
    return _place(getDryLayout(constraints), c.getDryLayout(loose), base);
  }
}
