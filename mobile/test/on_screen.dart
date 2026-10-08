// SPDX-License-Identifier: GPL-3.0-or-later
// where a screen reader's node sits on the screen, in logical pixels
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Rect onScreen(WidgetTester t, SemanticsNode n) {
  var r = n.rect;
  for (SemanticsNode? x = n; x != null; x = x.parent) {
    if (x.transform != null) r = MatrixUtils.transformRect(x.transform!, r);
  }
  final dpr = t.view.devicePixelRatio;
  return Rect.fromLTRB(
    r.left / dpr,
    r.top / dpr,
    r.right / dpr,
    r.bottom / dpr,
  );
}
