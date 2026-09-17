// SPDX-License-Identifier: GPL-3.0-or-later
// a photo has no height until its file decodes: the row is laid out a few
// pixels tall and grows a moment later. in a chat that is every photo row,
// every time it is built, and anything that scrolled to a message just
// before the growth ends up somewhere else. once a row has been measured
// its height is kept for the life of the process, and the next build
// starts at that height instead of at nothing.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

final Map<String, double> _heights = {};

class RememberedHeight extends SingleChildRenderObjectWidget {
  /// what the height belongs to: the file, and the width it was laid out at
  final String id;
  const RememberedHeight({super.key, required this.id, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _Render(id);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _Render).id = id;
  }
}

class _Render extends RenderProxyBox {
  _Render(this._id);
  String _id;
  set id(String v) {
    if (v == _id) return;
    _id = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    final known = _heights[_id] ?? 0;
    final floor = math.min(
      math.max(constraints.minHeight, known),
      constraints.maxHeight,
    );
    c.layout(constraints.copyWith(minHeight: floor), parentUsesSize: true);
    size = c.size;
    // an undecoded image and an error stub are both short; neither is the
    // height worth keeping
    if (size.height > 24 && size.height.isFinite) _heights[_id] = size.height;
  }
}
