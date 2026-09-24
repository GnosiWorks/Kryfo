// SPDX-License-Identifier: GPL-3.0-or-later
// what can go into a chat, as a grid of round tiles that pop in one after
// another. a tap closes the sheet first, then does the thing.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'press_scale.dart';
import 'sheet_handle.dart';

class AttachItem {
  final Widget Function(Color color) icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;
  const AttachItem({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });
}

class AttachGrid extends StatefulWidget {
  final List<AttachItem> items;
  const AttachGrid({super.key, required this.items});
  @override
  State<AttachGrid> createState() => _AttachGridState();
}

class _AttachGridState extends State<AttachGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _in.value = 1;
      } else {
        _in.forward();
      }
    });
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (_, box) {
                final w = box.maxWidth / 3;
                return Wrap(
                  children: [
                    for (final (i, it) in items.indexed)
                      SizedBox(
                        width: w,
                        child: _pop(i, _Tile(item: it)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pop(int i, Widget child) {
    final start = (i * 0.07).clamp(0.0, 0.5);
    final curve = Interval(start, start + 0.5, curve: Curves.easeOutBack);
    final fade = Interval(start, start + 0.4, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: _in,
      builder: (_, c) {
        final v = curve.transform(_in.value);
        return Opacity(
          opacity: fade.transform(_in.value),
          child: Transform.scale(scale: 0.82 + 0.18 * v, child: c),
        );
      },
      child: child,
    );
  }
}

class _Tile extends StatelessWidget {
  final AttachItem item;
  const _Tile({required this.item});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.92,
      haptic: false,
      label: item.label,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        item.onTap();
      },
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.tint.withValues(alpha: 0.14),
                  border: Border.all(
                    color: item.tint.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: IconTheme(
                  data: IconThemeData(color: item.tint, size: 25),
                  child: SizedBox(
                    width: 25,
                    height: 25,
                    child: item.icon(item.tint),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HaloType.sans(size: 12.5, color: HaloColors.text2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
