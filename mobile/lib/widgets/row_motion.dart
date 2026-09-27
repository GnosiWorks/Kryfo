// SPDX-License-Identifier: GPL-3.0-or-later
// rows coming and going in a list that is rebuilt whole: a new row grows
// in, one that went stays drawn where it was while it folds away (FadeFold),
// and the rest keep their place in the order they are given.
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'burn_fade.dart' show FadeFold;
import 'motion.dart' show motionStill;

class RowSet<T> {
  final String Function(T row) keyOf;
  // called when a row that went has finished folding and is let go
  final VoidCallback onGone;
  RowSet({required this.keyOf, required this.onGone});

  List<T> _rows = const [];
  final Map<String, Timer> _leaving = {};
  final Set<String> _fresh = {};

  /// the rows to draw, leaving ones included
  List<T> get rows => _rows;

  bool leaving(T row) => _leaving.containsKey(keyOf(row));

  /// new since the rows before: grows in. true for one build only
  bool fresh(T row) => _fresh.contains(keyOf(row));

  /// the first rows: drawn as they are
  void start(List<T> now) => _rows = List.of(now);

  /// the rows now, in their order, with each row that went kept where it
  /// was until it has folded. [quiet] takes changes as they are, with no
  /// motion: under the lock nothing is being watched
  void update(List<T> now, {bool quiet = false}) {
    _fresh.clear();
    final keys = {for (final r in now) keyOf(r)};
    final had = {for (final r in _rows) keyOf(r)};
    for (final r in now) {
      final k = keyOf(r);
      _leaving.remove(k)?.cancel();
      if (!had.contains(k) && !quiet) _fresh.add(k);
    }
    final out = List<T>.of(now);
    for (var at = 0; at < _rows.length; at++) {
      final r = _rows[at];
      final k = keyOf(r);
      if (keys.contains(k)) continue;
      if (quiet) {
        _leaving.remove(k)?.cancel();
        continue;
      }
      _leaving[k] ??= Timer(FadeFold.gone, () {
        _leaving.remove(k);
        _rows = [
          for (final x in _rows)
            if (keyOf(x) != k) x,
        ];
        onGone();
      });
      out.insert(at.clamp(0, out.length), r);
    }
    _rows = out;
  }

  /// the growing is spent once the rows that asked have been built
  void built() => _fresh.clear();

  void dispose() {
    for (final t in _leaving.values) {
      t.cancel();
    }
    _leaving.clear();
  }
}

// a row that is new to a list: it opens its own height and fades up,
// pushing the rows under it down rather than jumping them. only a fade when
// the phone asks for no movement. the same widgets stand around the row
// before and after, so its state is kept
class GrowIn extends StatefulWidget {
  // only read when the row is first built
  final bool active;
  final Widget child;
  const GrowIn({super.key, required this.active, required this.child});

  static const time = Duration(milliseconds: 320);

  @override
  State<GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<GrowIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (!widget.active) return;
    _c = AnimationController(vsync: this, duration: GrowIn.time)..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedBuilder(
      animation: _c ?? kAlwaysCompleteAnimation,
      child: widget.child,
      builder: (_, child) {
        final t = _c?.value ?? 1;
        final h = still ? 1.0 : Curves.easeOutCubic.transform(t);
        final o = still
            ? t
            : Curves.easeOut.transform(((t - 0.2) / 0.8).clamp(0.0, 1.0));
        return ClipRect(
          clipBehavior: h < 1 ? Clip.hardEdge : Clip.none,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: h,
            child: Opacity(opacity: o, child: child),
          ),
        );
      },
    );
  }
}
