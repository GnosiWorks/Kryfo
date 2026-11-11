// SPDX-License-Identifier: GPL-3.0-or-later
// a bubble's taps: a double tap reacts with the first quick reaction, a
// single tap waits out the double tap window first. a bubble that cannot
// take a reaction gets its single tap at once
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'chat_parts.dart' show kQuickReactions;
import 'motion.dart';

/// the reaction a double tap puts on
String get kDoubleTapReaction => kQuickReactions.first;

/// how long a single tap waits for a second: shorter than flutter's 300
const kReactTapWindow = Duration(milliseconds: 220);

// two taps further apart than this are two single taps
const _slop = 48.0;

class ReactTaps extends StatefulWidget {
  const ReactTaps({
    super.key,
    required this.child,
    this.onTap,
    this.onReact,
    this.onLongPress,
    this.onSecondaryTap,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  // the default reaction toggled: true when it went on. null when this
  // message takes none
  final bool Function()? onReact;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final HitTestBehavior behavior;

  @override
  State<ReactTaps> createState() => _ReactTapsState();
}

class _ReactTapsState extends State<ReactTaps> {
  Timer? _wait;
  Offset? _first;

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  void _up(TapUpDetails d) {
    final react = widget.onReact;
    if (react == null) {
      widget.onTap?.call();
      return;
    }
    final first = _first;
    if (_wait != null &&
        first != null &&
        (d.globalPosition - first).distance <= _slop) {
      _wait!.cancel();
      _wait = null;
      _first = null;
      // one going on rings with the bubble's flash; one coming off here
      if (!react()) {
        HapticFeedback.lightImpact();
      } else if (mounted && !motionStill(context)) {
        _popHeart(context, d.globalPosition);
      }
      return;
    }
    // one waiting from elsewhere on the bubble was a single tap of its own
    if (_wait != null) {
      _wait!.cancel();
      widget.onTap?.call();
    }
    _first = d.globalPosition;
    _wait = Timer(kReactTapWindow, () {
      _wait = null;
      _first = null;
      if (mounted) widget.onTap?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taps = widget.onTap != null || widget.onReact != null;
    final react = widget.onReact;
    final detector = GestureDetector(
      behavior: widget.behavior,
      onTapUp: taps ? _up : null,
      onLongPress: widget.onLongPress,
      onSecondaryTap: widget.onSecondaryTap,
      child: widget.child,
    );
    if (react == null) return detector;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.chatReactHeart): () => react(),
      },
      child: detector,
    );
  }
}

/// the reaction pops at [at], rises and fades: gone in 400 ms
void _popHeart(BuildContext context, Offset at) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Material(
      type: MaterialType.transparency,
      child: _HeartPop(at: at, done: () => entry.remove()),
    ),
  );
  overlay.insert(entry);
}

class _HeartPop extends StatefulWidget {
  const _HeartPop({required this.at, required this.done});
  final Offset at;
  final VoidCallback done;

  @override
  State<_HeartPop> createState() => _HeartPopState();
}

class _HeartPopState extends State<_HeartPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward().whenComplete(widget.done);

  // 0 to 1.2 and back to 1 on the house spring, then it rises and goes
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: kHouseCurve)),
      weight: 45,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          final rise = Curves.easeOutCubic.transform(t) * 24;
          final fade = t < 0.55 ? 1.0 : 1 - (t - 0.55) / 0.45;
          return Stack(
            children: [
              Positioned(
                left: widget.at.dx - size / 2,
                top: widget.at.dy - size / 2 - rise,
                width: size,
                height: size,
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.scale(scale: _scale.value, child: child),
                ),
              ),
            ],
          );
        },
        child: Center(
          child: Text(
            kDoubleTapReaction,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}
