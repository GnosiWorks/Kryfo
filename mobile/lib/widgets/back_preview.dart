// SPDX-License-Identifier: GPL-3.0-or-later
// android's predictive back on a house route: while the back swipe is held
// the page shrinks toward 0.92 and slides with the edge it came from, the
// screen below shows, and letting go past the line pops it, else it springs
// back. never while the lock is up, never on a route that will not pop
// (PopScope canPop false, a route with its own back), never with reduced
// motion: those keep the plain back

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../lock_layer.dart' show lockBack;
import 'motion.dart' show motionStill;

// how far the page shrinks and slides at the end of the swipe
const kBackScale = 0.92;
const kBackShift = 0.06;

class BackPreview extends StatefulWidget {
  // the route's own animation
  final Animation<double> animation;
  // the page. it stays in one place in the tree whatever moves it, so a
  // swipe that springs back keeps every bit of its state
  final Widget child;
  const BackPreview({super.key, required this.animation, required this.child});

  @override
  State<BackPreview> createState() => _BackPreviewState();
}

class _BackPreviewState extends State<BackPreview> with WidgetsBindingObserver {
  ModalRoute<Object?>? _route;
  // the swipe this page took, from which edge
  bool _held = false;
  bool _fromLeft = true;
  // where the route's animation stood when the swipe let go past the line
  double? _letGoAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _may {
    final r = _route;
    return r != null &&
        mounted &&
        !lockBack.locked &&
        !motionStill(context) &&
        r.isCurrent &&
        r.popGestureEnabled;
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_may) return false;
    final r = _route! as TransitionRoute<Object?>;
    setState(() {
      _held = true;
      _letGoAt = null;
      _fromLeft = backEvent.swipeEdge == SwipeEdge.left;
    });
    HapticFeedback.selectionClick();
    r.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_held) return;
    (_route! as TransitionRoute<Object?>).handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    if (!_held) return;
    (_route! as TransitionRoute<Object?>).handleCancelBackGesture();
    _settle();
  }

  @override
  void handleCommitBackGesture() {
    if (!_held) return;
    final r = _route!;
    // the lock came up mid-swipe: nothing below is shown, the page stays
    if (lockBack.locked) {
      (r as TransitionRoute<Object?>).handleCancelBackGesture();
      _settle();
      return;
    }
    setState(() => _letGoAt = r.animation?.value ?? 1);
    (r as TransitionRoute<Object?>).handleCommitBackGesture();
  }

  // back to the page's own transition once the route has come to rest
  void _settle() {
    final a = _route?.animation;
    if (a == null || !a.isAnimating) {
      if (mounted) setState(() => _held = false);
      return;
    }
    late final AnimationStatusListener done;
    done = (s) {
      if (s.isAnimating) return;
      a.removeStatusListener(done);
      if (mounted) setState(() => _held = false);
    };
    a.addStatusListener(done);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animation;
    final still = motionStill(context);
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (context, page) {
        double opacity, scale = 1, dx = 0, rise = 0, round = 0;
        if (_held) {
          // 0 at rest, 1 at the end of the swipe. once let go the route
          // runs its pop from the top: the page stays where the finger
          // left it, goes a little further and fades out
          final from = _letGoAt;
          final double p;
          if (from == null) {
            p = (1 - a.value).clamp(0.0, 1.0);
            opacity = 1;
          } else {
            final left = (1 - from).clamp(0.0, 1.0);
            p = left + (1 - left) * 0.4 * (1 - a.value);
            opacity = a.value.clamp(0.0, 1.0);
          }
          final eased = Curves.easeOutCubic.transform(p);
          scale = 1 - (1 - kBackScale) * eased;
          dx = (_fromLeft ? 1 : -1) * kBackShift * eased;
          round = 28 * eased;
        } else {
          // the house transition: a short rise and fade, the fade alone
          // with reduced motion
          final t =
              (a.status == AnimationStatus.reverse
                      ? Curves.easeInCubic
                      : Curves.easeOutCubic)
                  .transform(a.value.clamp(0.0, 1.0));
          opacity = t;
          rise = still ? 0 : 0.035 * (1 - t);
        }
        return Opacity(
          opacity: opacity,
          child: FractionalTranslation(
            translation: Offset(dx, rise),
            child: Transform.scale(
              scale: scale,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(round),
                clipBehavior: round > 0 ? Clip.antiAlias : Clip.none,
                child: page,
              ),
            ),
          ),
        );
      },
    );
  }
}
