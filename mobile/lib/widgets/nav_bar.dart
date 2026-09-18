// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'stroke_icon.dart';

enum HaloTab { chats, tools, support, me }

const _labels = {
  HaloTab.chats: 'Chats',
  HaloTab.tools: 'Tools',
  HaloTab.support: 'Support',
  HaloTab.me: 'Me',
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
          for (final t in HaloTab.values)
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
    if (!widget.on) {
      _c.value = 0;
    } else if (still) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
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
    final ink = on ? HaloColors.amber : HaloColors.warm;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 58,
                height: 29,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) {
                    final pop = Curves.easeOutBack.transform(_c.value);
                    final v = _c.value;
                    final hop = v <= 0 || v >= 0.8
                        ? 0.0
                        : -3.0 * (1 - ((v - 0.4) / 0.4).abs());
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (on)
                          Opacity(
                            opacity: v.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.4 + 0.6 * pop,
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
                          offset: Offset(0, on ? hop : 0),
                          child: StrokeIcon(
                            [_icons[widget.tab]!],
                            size: 21,
                            color: ink,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textScaler: scale,
                  style: HaloType.sans(
                    size: 11,
                    weight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? HaloColors.text : HaloColors.warm,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
