// SPDX-License-Identifier: GPL-3.0-or-later
// a timed message that came in starts its clock when it is first read: the
// chat in view with the app in front, no lock or decoy over it, and its row
// on screen. a row the list built just past the edge is not read.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dlog.dart';
import 'widgets/row_anchor.dart';

/// [ro] shows inside its scroll view: half of it, or half the view for a
/// row taller than that
bool rowInView(RenderObject ro) {
  final viewport = RenderAbstractViewport.maybeOf(ro);
  if (ro is! RenderBox || viewport is! RenderBox) return false;
  final row = ro;
  final view = viewport as RenderBox;
  if (!row.attached || !row.hasSize || !view.hasSize) return false;
  final box = MatrixUtils.transformRect(
    row.getTransformTo(view),
    Offset.zero & row.size,
  );
  final shown = box.intersect(Offset.zero & view.size);
  if (shown.width <= 0 || shown.height <= 0) return false;
  return shown.height >= math.min(box.height, view.size.height) / 2;
}

class ReadBurns {
  ReadBurns({
    required this.anchors,
    required this.reading,
    required this.waiting,
    required this.light,
  });

  final RowAnchors anchors;
  // the chat can be read at all: in view, the app in front, nothing over it
  final bool Function() reading;
  // the ids of the rows whose clock waits
  final Iterable<String> Function() waiting;
  // the rows read just now; their clocks are written before this completes
  final Future<void> Function(List<String> ids) light;

  final Set<String> _going = {};
  bool _asked = false;
  bool _gone = false;

  /// looks once this frame is laid out. cheap to call often
  void look() {
    if (_asked || _gone || waiting().isEmpty) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _asked = false;
      check();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// the waiting rows on screen now start their clocks
  void check() {
    if (_gone || !reading()) return;
    final due = [
      for (final id in waiting())
        if (!_going.contains(id) && _shown(id)) id,
    ];
    if (due.isEmpty) return;
    _going.addAll(due);
    unawaited(
      light(due)
          .catchError((Object e) => dlog('read burn: not lit ($e)'))
          .whenComplete(() => _going.removeAll(due)),
    );
  }

  bool _shown(String id) {
    final c = anchors.of(id);
    if (c == null || !c.mounted) return false;
    final ro = c.findRenderObject();
    return ro != null && rowInView(ro);
  }

  void dispose() => _gone = true;
}
