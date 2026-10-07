// SPDX-License-Identifier: GPL-3.0-or-later
// a room joined off a link and not let in yet. the creator's phone lets a
// joiner in by sending its roster; until then nobody reads the joiner's
// key, so the room waits instead of taking messages that go nowhere. after
// kRoomJoinWait it says the room is not answering, and offers to knock
// again or leave. the waiting ring breathes on, still with less movement.
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../rooms.dart';
import '../theme.dart';
import 'halo_buttons.dart';
import 'motion.dart' show motionStill;
import 'swap.dart';

// the join's state now, and a rebuild when the wait runs out
mixin _JoinClock<T extends StatefulWidget> on State<T> {
  int? get joiningAt;
  Timer? _t;

  RoomJoin get join =>
      roomJoinState(joiningAt, DateTime.now().millisecondsSinceEpoch);

  void armJoinClock() {
    _t?.cancel();
    _t = null;
    final at = joiningAt;
    if (join != RoomJoin.waiting || at == null) return;
    final left =
        at +
        kRoomJoinWait.inMilliseconds -
        DateTime.now().millisecondsSinceEpoch;
    // nothing left to wait for: never a timer that sets itself again
    if (left <= 0) return;
    _t = Timer(Duration(milliseconds: left), () {
      if (!mounted) return;
      setState(() {});
      // early by a hair: once more for the rest
      armJoinClock();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

/// the line a waiting room shows where a live one shows its clock: on the
/// chat list and in the room's header
class RoomJoinLine extends StatefulWidget {
  final int joiningAt;
  final double size;
  const RoomJoinLine({super.key, required this.joiningAt, this.size = 10});

  @override
  State<RoomJoinLine> createState() => _RoomJoinLineState();
}

class _RoomJoinLineState extends State<RoomJoinLine>
    with _JoinClock<RoomJoinLine> {
  @override
  int? get joiningAt => widget.joiningAt;

  @override
  void initState() {
    super.initState();
    armJoinClock();
  }

  @override
  void didUpdateWidget(covariant RoomJoinLine old) {
    super.didUpdateWidget(old);
    if (old.joiningAt != widget.joiningAt) armJoinClock();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = join == RoomJoin.waiting;
    final label = waiting
        ? l10n.roomJoinWaitingToJoin
        : l10n.roomJoinNotAnswering;
    return RiseSwap(
      child: Text(
        label,
        key: ValueKey(waiting),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HaloType.mono(
          size: widget.size,
          color: waiting ? HaloColors.violet : HaloColors.amber,
        ),
      ),
    );
  }
}

/// what a waiting room shows in place of its thread
class RoomJoinPanel extends StatefulWidget {
  final String name;
  final int joiningAt;
  final VoidCallback onTryAgain;
  final VoidCallback onLeave;
  const RoomJoinPanel({
    super.key,
    required this.name,
    required this.joiningAt,
    required this.onTryAgain,
    required this.onLeave,
  });

  @override
  State<RoomJoinPanel> createState() => _RoomJoinPanelState();
}

class _RoomJoinPanelState extends State<RoomJoinPanel>
    with _JoinClock<RoomJoinPanel> {
  @override
  int? get joiningAt => widget.joiningAt;

  @override
  void initState() {
    super.initState();
    armJoinClock();
  }

  @override
  void didUpdateWidget(covariant RoomJoinPanel old) {
    super.didUpdateWidget(old);
    if (old.joiningAt != widget.joiningAt) armJoinClock();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = join == RoomJoin.waiting;
    // rises in once, as an empty chat does
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, motionStill(context) ? 0 : (1 - t) * 12),
            child: child,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: FadeSwap(
            child: waiting
                ? _Waiting(key: const ValueKey('waiting'), name: widget.name)
                : _Silent(
                    key: const ValueKey('silent'),
                    onTryAgain: widget.onTryAgain,
                    onLeave: widget.onLeave,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  final String name;
  const _Waiting({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Knock(color: HaloColors.violet, icon: Icons.meeting_room_outlined),
          const SizedBox(height: 22),
          Text(
            l10n.roomJoinWaitingFor(name),
            textAlign: TextAlign.center,
            style: HaloType.serif(
              size: 22,
              weight: FontWeight.w300,
              italic: true,
              color: HaloColors.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.roomJoinWaitingLine,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
        ],
      ),
    );
  }
}

class _Silent extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onLeave;
  const _Silent({super.key, required this.onTryAgain, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Knock(
            color: HaloColors.amber,
            icon: Icons.no_meeting_room_outlined,
            still: true,
          ),
          const SizedBox(height: 22),
          Text(
            l10n.roomJoinNoAnswer,
            textAlign: TextAlign.center,
            style: HaloType.serif(
              size: 22,
              weight: FontWeight.w300,
              italic: true,
              color: HaloColors.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.roomJoinMayHaveEnded,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
          const SizedBox(height: 26),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HaloPrimaryButton(
                  label: l10n.commonTryAgain,
                  onTap: onTryAgain,
                ),
                const SizedBox(height: 10),
                HaloGhostButton(
                  label: l10n.groupInfoLeave,
                  onTap: onLeave,
                  quiet: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// a door glyph in a soft disc, rings going out from it while it knocks
class _Knock extends StatefulWidget {
  final Color color;
  final IconData icon;
  final bool still;
  const _Knock({required this.color, required this.icon, this.still = false});

  @override
  State<_Knock> createState() => _KnockState();
}

class _KnockState extends State<_Knock> with SingleTickerProviderStateMixin {
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _go();
  }

  @override
  void didUpdateWidget(covariant _Knock old) {
    super.didUpdateWidget(old);
    _go();
  }

  void _go() {
    if (widget.still || motionStill(context)) {
      _out.stop();
      _out.value = 0;
    } else if (!_out.isAnimating) {
      _out.repeat();
    }
  }

  @override
  void dispose() {
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    const core = 60.0;
    const size = 104.0;
    Widget ring(double phase) => AnimatedBuilder(
      animation: _out,
      builder: (_, _) {
        if (!_out.isAnimating) return const SizedBox.shrink();
        final t = Curves.easeOut.transform((_out.value + phase) % 1);
        final d = core + (size - core) * t;
        return Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: c.withValues(alpha: 0.35 * (1 - t)),
              width: 1,
            ),
          ),
        );
      },
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(0),
          ring(0.5),
          Container(
            width: core,
            height: core,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.14),
              border: Border.all(color: c.withValues(alpha: 0.3), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(widget.icon, color: c, size: 25),
          ),
        ],
      ),
    );
  }
}
