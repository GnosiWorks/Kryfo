// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker picked in the sheet flies to where its bubble lands, on the house
// spring with a small lift, still playing. the bubble shows its own copy once
// the flight is down, from the same frame.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/motion.dart' show houseSpring;
import 'sticker_pack.dart';
import 'sticker_view.dart';

/// where a flight comes down. the bubble puts [key] on its sticker box and
/// stays hidden until [landed]
class StickerLanding {
  final key = GlobalKey();
  final landed = ValueNotifier<bool>(false);
  // ms into the loop at touchdown
  double at = 0;

  /// the bubble's sticker box on screen, once it has been laid out
  Rect? get rect {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void land(double atMs) {
    if (landed.value) return;
    at = atMs;
    landed.value = true;
  }
}

/// starts a flight in the root overlay, from [from] to [landing]'s bubble,
/// heading for [fallback] until the bubble has a layout. [at] is where the
/// picked copy was in its loop. the callback it returns lands it at once;
/// [onGone] runs once it is off the screen, either way.
VoidCallback flySticker(
  BuildContext context, {
  required Sticker sticker,
  required Rect from,
  required double at,
  required StickerLanding landing,
  required Rect Function() fallback,
  VoidCallback? onGone,
}) {
  final flight = GlobalKey<_FlightState>();
  late final OverlayEntry entry;
  var gone = false;
  void remove() {
    if (gone) return;
    gone = true;
    entry.remove();
    onGone?.call();
  }

  entry = OverlayEntry(
    builder: (_) => _Flight(
      key: flight,
      sticker: sticker,
      from: from,
      at: at,
      landing: landing,
      fallback: fallback,
      onDone: remove,
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return () {
    if (gone) return;
    landing.land(flight.currentState?.now ?? math.max(at, 0.0));
    remove();
  };
}

class _Flight extends StatefulWidget {
  const _Flight({
    super.key,
    required this.sticker,
    required this.from,
    required this.at,
    required this.landing,
    required this.fallback,
    required this.onDone,
  });

  final Sticker sticker;
  final Rect from;
  final double at;
  final StickerLanding landing;
  final Rect Function() fallback;
  final VoidCallback onDone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with TickerProviderStateMixin {
  // 0 at the cell, 1 on the bubble
  late final AnimationController _t = AnimationController.unbounded(
    vsync: this,
  );
  // the bubble's copy fades in under this one, then this one goes
  late final AnimationController _handoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
  );
  final _view = GlobalKey();
  double? _lift;

  /// ms into the loop of the frame on screen
  double get now {
    final box = _view.currentContext?.findRenderObject();
    if (box is RenderSticker && box.time >= 0) return box.time;
    return math.max(widget.at, 0.0);
  }

  @override
  void initState() {
    super.initState();
    _t.animateWith(houseSpring(0, 1)).then((_) => _touchdown());
  }

  @override
  void dispose() {
    _t.dispose();
    _handoff.dispose();
    super.dispose();
  }

  void _touchdown() {
    if (!mounted) return;
    widget.landing.land(now);
    _handoff.forward().then((_) => widget.onDone());
  }

  Rect get _to => widget.landing.rect ?? widget.fallback();

  @override
  Widget build(BuildContext context) {
    // higher the further it goes, never much
    _lift ??= ((_to.center - widget.from.center).distance * 0.14).clamp(
      12.0,
      64.0,
    );
    return IgnorePointer(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _t,
            builder: (_, child) {
              final t = _t.value;
              final r = Rect.lerp(widget.from, _to, t)!;
              final up = math.sin(math.pi * t.clamp(0.0, 1.0)) * _lift!;
              return Positioned.fromRect(
                rect: r.shift(Offset(0, -up)),
                child: child!,
              );
            },
            child: StickerView(
              key: _view,
              sticker: widget.sticker,
              size: widget.from.shortestSide,
              start: math.max(widget.at, 0.0),
            ),
          ),
        ],
      ),
    );
  }
}
