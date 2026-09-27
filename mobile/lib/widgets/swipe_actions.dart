// SPDX-License-Identifier: GPL-3.0-or-later
// a row that takes a swipe either way for an action. what the swipe will do
// is drawn behind it: the glyph grows with the drag, its round fills once
// the swipe has gone far enough, with a click, and its word shows under it.
// the row always slides back; the action says what came of it. with less
// movement the glyph is simply there and only its round changes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'motion.dart';

class SwipeAction {
  final IconData icon;
  final String label;
  final Color color;
  // what fills the round's glyph once it is lit
  final Color ink;
  final Future<void> Function() onDone;
  const SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.ink,
    required this.onDone,
  });
}

class SwipeActions extends StatefulWidget {
  final Key rowKey;
  // from the start side toward the end, and back
  final SwipeAction start;
  final SwipeAction end;
  final Widget child;
  const SwipeActions({
    super.key,
    required this.rowKey,
    required this.start,
    required this.end,
    required this.child,
  });

  // how far, as a share of the row, before letting go does the action
  static const threshold = 0.4;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> {
  final _pull = ValueNotifier<(double, bool)>((0, false));

  @override
  void dispose() {
    _pull.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: widget.rowKey,
      dismissThresholds: const {
        DismissDirection.startToEnd: SwipeActions.threshold,
        DismissDirection.endToStart: SwipeActions.threshold,
      },
      onUpdate: (d) {
        if (d.reached && !d.previousReached) HapticFeedback.selectionClick();
        _pull.value = (d.progress, d.reached);
      },
      background: _Behind(action: widget.start, atStart: true, pull: _pull),
      secondaryBackground: _Behind(
        action: widget.end,
        atStart: false,
        pull: _pull,
      ),
      confirmDismiss: (dir) async {
        await (dir == DismissDirection.endToStart ? widget.end : widget.start)
            .onDone();
        return false;
      },
      child: widget.child,
    );
  }
}

class _Behind extends StatelessWidget {
  final SwipeAction action;
  final bool atStart;
  final ValueNotifier<(double, bool)> pull;
  const _Behind({
    required this.action,
    required this.atStart,
    required this.pull,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Container(
      color: HaloColors.surface2,
      alignment: atStart
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      padding: EdgeInsetsDirectional.only(
        start: atStart ? 20 : 0,
        end: atStart ? 0 : 20,
      ),
      child: ValueListenableBuilder<(double, bool)>(
        valueListenable: pull,
        builder: (_, p, _) {
          final (progress, lit) = p;
          // the glyph reaches its size where the swipe starts to count
          final grown = (progress / SwipeActions.threshold).clamp(0.0, 1.0);
          final scale = still
              ? 1.0
              : 0.55 + 0.45 * Curves.easeOut.transform(grown);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit
                        ? action.color
                        : action.color.withValues(alpha: 0.12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    action.icon,
                    size: 19,
                    color: lit ? action.ink : action.color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: still ? 1 : grown,
                child: Text(
                  action.label,
                  maxLines: 1,
                  style: HaloType.mono(
                    size: 9.5,
                    weight: FontWeight.w600,
                    color: action.color,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
