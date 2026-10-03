// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../theme.dart';
import 'stroke_icon.dart';
import '../l10n/l10n.dart';

enum HaloTab { chats, tools, support, me }

// the tabs on the bar. the play build has no support tab
List<HaloTab> get shownTabs => [
  for (final t in HaloTab.values)
    if (!kPlayBuild || t != HaloTab.support) t,
];

Map<HaloTab, String> get _labels => {
  HaloTab.chats: l10n.navBarChats,
  HaloTab.tools: l10n.navBarTools,
  HaloTab.support: l10n.navBarSupport,
  HaloTab.me: l10n.navBarMe,
};

const _icons = {
  HaloTab.chats:
      'M4.5 6.8A2.8 2.8 0 0 1 7.3 4h9.4a2.8 2.8 0 0 1 2.8 2.8v6.4a2.8 2.8 0 0 1-2.8 2.8H11l-4.3 3.4V16a2.8 2.8 0 0 1-2.2-2.8z',
  HaloTab.tools:
      'M14.8 6.2a4.2 4.2 0 0 0-5.6 5.3L4 16.7 7.3 20l5.2-5.2a4.2 4.2 0 0 0 5.3-5.6l-2.5 2.5-2.7-.6-.6-2.7z',
  HaloTab.support:
      'M12 19.5s-7-4.3-7-9.6A3.9 3.9 0 0 1 12 7.6a3.9 3.9 0 0 1 7 2.3c0 5.3-7 9.6-7 9.6z',
  HaloTab.me:
      'M15.6 8.5a3.6 3.6 0 1 1-7.2 0 3.6 3.6 0 1 1 7.2 0zM5 19.5c1.3-3.4 4-4.9 7-4.9s5.7 1.5 7 4.9',
};

class HaloNavBar extends StatelessWidget {
  final HaloTab active;
  final ValueChanged<HaloTab> onPick;
  final VoidCallback? onMeLongPress;
  const HaloNavBar({
    super.key,
    required this.active,
    required this.onPick,
    this.onMeLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 7),
      child: Row(
        children: [
          for (final t in shownTabs)
            Expanded(
              child: _NavTab(
                tab: t,
                on: t == active,
                onTap: () => onPick(t),
                onLongPress: t == HaloTab.me ? onMeLongPress : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatefulWidget {
  final HaloTab tab;
  final bool on;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _NavTab({
    required this.tab,
    required this.on,
    required this.onTap,
    this.onLongPress,
  });
  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.on ? 1 : 0,
  );

  @override
  void didUpdateWidget(_NavTab old) {
    super.didUpdateWidget(old);
    if (widget.on == old.on) return;
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _c.value = widget.on ? 1 : 0;
    } else if (widget.on) {
      _c.forward(from: 0);
    } else {
      // the pill it leaves shrinks back while the new one pops, so the
      // two overlap instead of one blinking out
      _c.animateBack(0, duration: const Duration(milliseconds: 160));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    final label = _labels[widget.tab]!;
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Semantics(
      container: true,
      button: true,
      selected: on,
      label: label,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!on) HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final v = _c.value.clamp(0.0, 1.0);
              // in: the pill pops with a hop. out: it shrinks and fades
              final pill = on
                  ? 0.4 + 0.6 * Curves.easeOutBack.transform(v)
                  : 0.8 + 0.2 * v;
              final hop = !on || v <= 0 || v >= 0.8
                  ? 0.0
                  : -3.0 * (1 - ((v - 0.4) / 0.4).abs());
              // the ink follows the pill, so colour never jumps ahead of it
              final ink = Color.lerp(HaloColors.warm, HaloColors.amber, v)!;
              final word = Color.lerp(HaloColors.warm, HaloColors.text, v)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 58,
                    height: 29,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (v > 0)
                          Opacity(
                            opacity: v,
                            child: Transform.scale(
                              scale: pill,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: HaloColors.amber.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        Transform.translate(
                          offset: Offset(0, hop),
                          child: StrokeIcon(
                            [_icons[widget.tab]!],
                            size: 21,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // a gap to the next tab's word, even when a long one shrinks
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        textScaler: scale,
                        style: HaloType.sans(
                          size: 11,
                          weight: on ? FontWeight.w600 : FontWeight.w400,
                          color: word,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
