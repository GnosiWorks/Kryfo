// SPDX-License-Identifier: GPL-3.0-or-later
// several messages picked at once: "Select" in a message's menu starts it,
// then a tap on a row picks it or lets it go. the head becomes a bar with
// how many are picked and what can be done with all of them: copy and
// forward only when every one may leave the chat (viewer_rules.dart). back
// or the cross ends it
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../theme.dart';
import 'motion.dart' show kHouseCurve, motionStill;
import 'press_scale.dart';

/// a row while messages are picked: a round mark at its start, a soft wash
/// while it is picked, and a tap that picks it or lets it go
class SelectRow extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  final Widget child;
  const SelectRow({
    super.key,
    required this.on,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final time = still ? Duration.zero : const Duration(milliseconds: 180);
    return Semantics(
      selected: on,
      button: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: time,
          curve: kHouseCurve,
          color: on ? HaloColors.amberSoft : Colors.transparent,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: AnimatedContainer(
                  duration: time,
                  curve: kHouseCurve,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? HaloColors.amber : Colors.transparent,
                    border: Border.all(
                      color: on ? HaloColors.amber : HaloColors.line2,
                      width: 2,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: time,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: on
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('on'),
                            size: 14,
                            color: HaloColors.onAmber,
                          )
                        : const SizedBox.shrink(key: ValueKey('off')),
                  ),
                ),
              ),
              // the bubble keeps its look; its own taps wait until the
              // picking ends
              Expanded(child: IgnorePointer(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// the head while messages are picked
class SelectBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  // null leaves the action out: not every picked one may do it
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  const SelectBar({
    super.key,
    required this.count,
    required this.onClose,
    this.onCopy,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    Widget act(
      IconData icon,
      String label,
      VoidCallback? f, {
      bool rose = false,
    }) => AnimatedOpacity(
      opacity: f == null ? 0 : 1,
      duration: still ? Duration.zero : const Duration(milliseconds: 160),
      child: IgnorePointer(
        ignoring: f == null,
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: PressScale(
            scale: 0.86,
            onTap: f,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: 22,
                color: rose ? HaloColors.rose : HaloColors.text,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 6,
        8,
        6,
      ),
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(bottom: BorderSide(color: HaloColors.line)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.selectDone,
            excludeSemantics: true,
            child: PressScale(
              scale: 0.86,
              onTap: onClose,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: HaloColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: count.toDouble()),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                builder: (_, v, _) {
                  final n = v.round();
                  return Text(
                    l10n.selectCount(n, whole(n)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.sans(
                      size: 16,
                      weight: FontWeight.w600,
                      color: HaloColors.text,
                    ),
                  );
                },
              ),
            ),
          ),
          act(Icons.copy_rounded, l10n.commonCopy, onCopy),
          act(Icons.forward_rounded, l10n.chatForward, onForward),
        ],
      ),
    );
  }
}
