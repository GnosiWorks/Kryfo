// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat's face: the Kryfo ring on amber, with the tick of a
// key built into the app at its corner. no face is drawn from his words
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../lock_guard.dart' show LockGuard, lockGuard;
import '../theme.dart';
import 'motion.dart' show motionStill;

// the ring flies from the row into the chat once its header draws it too
const kDevFaceHero = 'dev-face';

// the tick pops once a run, the first time a row shows it
bool _popped = false;

@visibleForTesting
void popDevTickAgainForTest() => _popped = false;

// the lock the pop asks: the app's own, or one a test stands in
LockGuard devTickGuard = lockGuard;

class DevAvatar extends StatefulWidget {
  const DevAvatar({
    super.key,
    this.size = 44,
    this.tick = true,
    this.pop = false,
  });

  final double size;
  final bool tick;
  // pop the tick in, the first time only
  final bool pop;

  @override
  State<DevAvatar> createState() => _DevAvatarState();
}

class _DevAvatarState extends State<DevAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final CurvedAnimation _curve;
  late final Animation<double> _scale;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _scale = Tween(begin: 0.6, end: 1.0).animate(_curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.pop || !widget.tick || _popped) return;
    _popped = true;
    // under the lock nobody sees it, and with less movement it simply is
    if (devTickGuard.isLocked() || motionStill(context)) return;
    _c.value = 0;
    // after the row itself has come in
    _wait = Timer(const Duration(milliseconds: 220), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final face = Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HaloColors.amberSoft,
        border: Border.all(
          color: HaloColors.amber.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: DevRing(size: s * 0.62),
    );
    if (!widget.tick) return ExcludeSemantics(child: face);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(child: face),
        PositionedDirectional(
          end: -1,
          bottom: -1,
          child: Semantics(
            label: l10n.devPinned,
            child: ScaleTransition(
              scale: _scale,
              child: DevTick(size: (s * 0.32).clamp(12.0, 22.0)),
            ),
          ),
        ),
      ],
    );
  }
}

// the ring alone, as the splash draws it
class DevRing extends StatelessWidget {
  const DevRing({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _RingPainter()),
  );
}

// the tick of a key the app was built with, cut out of what it sits on
class DevTick extends StatelessWidget {
  const DevTick({super.key, this.size = 14, this.cut});
  final double size;
  final Color? cut;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: HaloColors.amber,
      border: Border.all(color: cut ?? HaloColors.surface, width: size * 0.107),
    ),
    child: Icon(
      Icons.check,
      size: size * 0.57,
      color: cut ?? HaloColors.surface,
    ),
  );
}

// kryfo_ring.svg: a glow under a ring that runs light to deep amber
class _RingPainter extends CustomPainter {
  const _RingPainter();

  static const _light = Color(0xFFFBC56B);
  static const _mid = Color(0xFFF59E0B);
  static const _deep = Color(0xFFC96A06);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // the svg's units, grown so the ring fills the box and not its margin
    final k = size.width / 512 * 1.2;
    final r = 184.3 * k;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 51.2 * k
        ..color = _mid.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15.4 * k),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 38.4 * k
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_light, _mid, _deep],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}
