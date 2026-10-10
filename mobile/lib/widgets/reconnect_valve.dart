// SPDX-License-Identifier: GPL-3.0-or-later
// the way out for a send that has waited on tor too long: one plain line and
// one button. reconnect first, and when tor will not take that, a restart
// that keeps every queued message
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../tor_valve.dart';
import 'chat_parts.dart' show GrowSwap;
import 'motion.dart' show motionStill;
import 'press_scale.dart';

class ReconnectValve extends StatefulWidget {
  const ReconnectValve({
    super.key,
    required this.valve,
    required this.waiting,
    required this.private,
    required this.quiet,
    required this.linkUp,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 8),
  });

  final TorValve valve;

  /// a send is going and has not gone yet
  final bool waiting;
  final bool private;
  final bool quiet;
  final bool linkUp;
  final EdgeInsetsGeometry margin;

  @override
  State<ReconnectValve> createState() => _ReconnectValveState();
}

class _ReconnectValveState extends State<ReconnectValve> {
  DateTime? _since;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.valve.addListener(_changed);
    _follow();
  }

  @override
  void didUpdateWidget(ReconnectValve old) {
    super.didUpdateWidget(old);
    if (!identical(old.valve, widget.valve)) {
      old.valve.removeListener(_changed);
      widget.valve.addListener(_changed);
    }
    _follow();
  }

  @override
  void dispose() {
    widget.valve.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  // the wait is timed from when this screen first saw it, and a clock runs
  // only while something waits: the stage moves on time alone
  void _follow() {
    widget.valve.sawLink(widget.linkUp);
    if (!widget.waiting) {
      _since = null;
      _tick?.cancel();
      _tick = null;
      return;
    }
    _since ??= widget.valve.now();
    _tick ??= Timer.periodic(const Duration(seconds: 5), (_) => _changed());
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.valve;
    final stage = v.stageFor(
      private: widget.private,
      quiet: widget.quiet,
      waitingSince: _since,
      linkUp: widget.linkUp,
    );
    // working only shows where the strip already was
    final shown = stage != ValveStage.hidden && (_since != null || v.busy);
    return GrowSwap(
      alignment: Alignment.topCenter,
      child: !shown
          ? const SizedBox(key: ValueKey('valve-none'), width: 1)
          : _card(context, stage),
    );
  }

  Widget _card(BuildContext context, ValveStage stage) {
    final restart = stage == ValveStage.restart;
    final busy = stage == ValveStage.working;
    final tint = restart ? HaloColors.rose : HaloColors.amber;
    final still = motionStill(context);
    final line = restart
        ? l10n.valveCouldNotReconnect
        : l10n.valveStillConnecting;
    return Container(
      key: const ValueKey('valve'),
      margin: widget.margin,
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: still ? 0 : 200),
              child: Text(
                line,
                key: ValueKey(line),
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text,
                ).copyWith(height: 1.35),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Pill(
            ink: restart ? HaloColors.amberInk : HaloColors.onAmber,
            label: busy
                ? l10n.homeReconnecting
                : restart
                ? l10n.valveRestartKryfo
                : l10n.homeReconnect,
            fill: tint,
            onTap: busy
                ? null
                : restart
                ? widget.valve.tryRestart
                : widget.valve.tryReconnect,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final Color ink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final text = Text(
      label,
      key: ValueKey(label),
      style: HaloType.mono(size: 11.5, color: ink, weight: FontWeight.w600),
    );
    return PressScale(
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: Duration(milliseconds: still ? 0 : 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: onTap == null ? fill.withValues(alpha: 0.45) : fill,
            borderRadius: BorderRadius.circular(999),
          ),
          // no movement asked for: the label just changes. an animated
          // size of no length re-dirties itself in layout
          child: still
              ? text
              : AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: text,
                ),
        ),
      ),
    );
  }
}
