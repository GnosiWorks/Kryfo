// SPDX-License-Identifier: GPL-3.0-or-later
// the chats' menus: the card of actions under a long-pressed message, and
// the grouped rows of a chat's own menu sheet. one look in both chats, the
// actions that destroy something last and in rose.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'motion.dart';
import 'sheet_handle.dart';

// one thing a menu can do. no [onTap] leaves it out
class MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  // takes something away: set apart at the end, in rose
  final bool danger;
  // a colour of its own for the icon and label, like amber for edit
  final Color? tint;
  const MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.tint,
  });
}

// how long a staggered list takes to come in: each row a beat after the one
// before, the last settling on the house spring
Duration _staggered(int n, int beatMs) =>
    kHouseTime + Duration(milliseconds: beatMs * (n - 1).clamp(0, 12));

// row i of n coming in: a short rise and a fade, a beat after the one before
Widget _rowIn(
  Animation<double> a,
  int i,
  int n,
  int beatMs,
  double rise,
  Widget child,
) {
  final total = _staggered(n, beatMs).inMilliseconds;
  final start = (beatMs * i.clamp(0, 12)) / total;
  final end = (start + kHouseTime.inMilliseconds / total).clamp(0.0, 1.0);
  return AnimatedBuilder(
    animation: a,
    child: child,
    builder: (_, c) {
      final t = ((a.value - start) / (end - start)).clamp(0.0, 1.0);
      final m = kHouseCurve.transform(t);
      return Opacity(
        opacity: Curves.easeOut.transform((t * 1.6).clamp(0.0, 1.0)),
        child: Transform.translate(offset: Offset(0, rise * (1 - m)), child: c),
      );
    },
  );
}

// the actions for one message, as a card of icon rows. the rows follow each
// other in as the card grows out of the bubble; all at once, still, when the
// phone asks for no movement
class MessageMenuCard extends StatefulWidget {
  final List<MenuAction> actions;
  const MessageMenuCard({super.key, required this.actions});

  @override
  State<MessageMenuCard> createState() => _MessageMenuCardState();
}

class _MessageMenuCardState extends State<MessageMenuCard>
    with SingleTickerProviderStateMixin {
  static const _beat = 16;
  late final List<MenuAction> _live = [
    for (final a in widget.actions)
      if (a.onTap != null && !a.danger) a,
    for (final a in widget.actions)
      if (a.onTap != null && a.danger) a,
  ];
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: _staggered(_live.length, _beat),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.isAnimating || _in.isCompleted) return;
    if (motionStill(context)) {
      _in.value = 1;
    } else {
      _in.forward();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    if (live.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < live.length; i++) {
      final a = live[i];
      if (a.danger && i > 0 && !live[i - 1].danger) {
        rows.add(
          Container(
            height: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: HaloColors.line,
          ),
        );
      }
      rows.add(_rowIn(_in, i, live.length, _beat, 6, _MenuRow(action: a)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final MenuAction action;
  const _MenuRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final a = action;
    final ink = a.danger ? HaloColors.rose : (a.tint ?? HaloColors.text);
    final icon = a.danger ? HaloColors.rose : (a.tint ?? HaloColors.text2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        splashColor: ink.withValues(alpha: 0.08),
        highlightColor: ink.withValues(alpha: 0.05),
        onTap: () {
          HapticFeedback.selectionClick();
          a.onTap!();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 18, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(a.icon, size: 17, color: icon),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  a.label,
                  style: HaloType.sans(
                    size: 13.5,
                    color: ink,
                    weight: a.danger ? FontWeight.w500 : FontWeight.w400,
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

// one row of a chat's own menu: an icon on a small tinted tile, the words,
// and a quiet line under them when there is something to add
class MenuSheetRow {
  final IconData icon;
  final String label;
  final String? sub;
  // null leaves the row drawn but not tappable, with its reason in [sub]
  final VoidCallback? onTap;
  final bool danger;
  // the tile's colour when it is not amber: violet for hidden chats
  final Color? tint;
  const MenuSheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
    this.danger = false,
    this.tint,
  });
}

// a chat's menu on the house sheet: rows in rounded groups, each group a
// beat after the one above, the group that destroys things last
class MenuSheet extends StatefulWidget {
  final List<List<MenuSheetRow>> groups;
  const MenuSheet({super.key, required this.groups});

  @override
  State<MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<MenuSheet>
    with SingleTickerProviderStateMixin {
  static const _beat = 35;
  late final List<List<MenuSheetRow>> _groups = [
    for (final g in widget.groups)
      if (g.isNotEmpty) g,
  ];
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: _staggered(_groups.length, _beat),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.isAnimating || _in.isCompleted) return;
    if (motionStill(context)) {
      _in.value = 1;
    } else {
      _in.forward();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _groups.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 8),
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _rowIn(_in, i, n, _beat, 10, _SheetGroup(rows: _groups[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetGroup extends StatelessWidget {
  final List<MenuSheetRow> rows;
  const _SheetGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    final rose = rows.every((r) => r.danger);
    final line = rose
        ? HaloColors.rose.withValues(alpha: 0.3)
        : HaloColors.line;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: rose
            ? HaloColors.rose.withValues(alpha: 0.05)
            : HaloColors.surface3.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 58),
                child: Container(height: 0.5, color: line),
              ),
            _SheetRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final MenuSheetRow row;
  const _SheetRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final on = row.onTap != null;
    final hue = row.danger ? HaloColors.rose : (row.tint ?? HaloColors.amber);
    final ink = !on
        ? HaloColors.text3
        : row.danger
        ? HaloColors.rose
        : HaloColors.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: on
            ? () {
                HapticFeedback.selectionClick();
                row.onTap!();
              }
            : null,
        splashColor: hue.withValues(alpha: 0.08),
        highlightColor: hue.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: on ? hue.withValues(alpha: 0.13) : HaloColors.surface3,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  row.icon,
                  size: 17,
                  color: on ? hue : HaloColors.text3,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.label,
                      style: HaloType.sans(
                        size: 14.5,
                        color: ink,
                        weight: row.danger ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                    if (row.sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.sub!,
                        style: HaloType.sans(size: 12, color: HaloColors.text3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
