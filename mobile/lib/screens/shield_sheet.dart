// SPDX-License-Identifier: GPL-3.0-or-later
// what the scam shield saw, one plain line per rule, then block, delete or
// ignore. no score, no percentage. the person decides.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../main.dart' show session, appState;
import '../theme.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/notice_banner.dart';
import '../widgets/press_scale.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import '../l10n/l10n.dart';
import '../scam_shield.dart';

// a stored flag, as the row in the shield table reads back.
class ShieldFlag {
  final String headline;
  final List<String> lines;
  const ShieldFlag(this.headline, this.lines);

  // a row with no headline is the shield saying it looked and found
  // nothing: shown as a quiet line, never as a flag
  static bool cleanRow(Map<String, Object?>? r) =>
      r != null && (r['headline'] as String? ?? '').isEmpty;

  static ShieldFlag? fromRow(Map<String, Object?>? r) {
    if (r == null || (r['dismissed'] as int? ?? 0) == 1) return null;
    if (cleanRow(r)) return null;
    // a flag an older build stored is english sentences, shown as they are
    try {
      final head = r['headline'] as String;
      final lines = [
        for (final e in jsonDecode(r['lines'] as String) as List)
          e is Map ? ShieldHit.fromJson(e).line : '$e',
      ];
      final headline = head.startsWith('{')
          ? shieldHeadline(ShieldHit.fromJson(jsonDecode(head) as Map))
          : head;
      return ShieldFlag(headline, lines);
    } catch (_) {
      return null;
    }
  }
}

enum ShieldChoice { block, delete, ignore }

// returns what was chosen, after doing it. null = dismissed the sheet.
Future<ShieldChoice?> showShieldSheet(
  BuildContext context,
  String haloId,
  ShieldFlag flag, {
  // a group member: nothing to delete, and block means everywhere
  bool group = false,
}) async {
  final choice = await showHaloSheet<ShieldChoice>(
    context,
    builder: (_) => _ShieldSheet(flag: flag, group: group),
  );
  if (choice == null) return null;
  HapticFeedback.selectionClick();
  switch (choice) {
    case ShieldChoice.block:
      await appState.block(haloId);
    case ShieldChoice.delete:
      await session.declineRequest(haloId);
    case ShieldChoice.ignore:
      await session.dismissShield(haloId);
  }
  await appState.refreshContacts();
  return choice;
}

class _ShieldSheet extends StatelessWidget {
  final ShieldFlag flag;
  final bool group;
  const _ShieldSheet({required this.flag, this.group = false});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            NoticeBanner(
              glyph: NoticeGlyph.shield,
              text: flag.headline,
              color: HaloColors.rose,
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < flag.lines.length; i++)
              _Line(order: i, text: flag.lines[i]),
            const SizedBox(height: 6),
            Text(
              l10n.shieldCheckedOnThisPhone,
              style: HaloType.mono(size: 10, color: HaloColors.text3),
            ),
            const SizedBox(height: 16),
            // three even buttons: long words shrink to fit, never break
            Row(
              children: [
                Expanded(
                  child: _Btn(
                    l10n.shieldBlock,
                    HaloColors.rose,
                    onTap: () => Navigator.pop(context, ShieldChoice.block),
                  ),
                ),
                if (!group) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Btn(
                      l10n.shieldDelete,
                      HaloColors.text,
                      onTap: () => Navigator.pop(context, ShieldChoice.delete),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: _Btn(
                    l10n.shieldIgnore,
                    HaloColors.text,
                    fill: true,
                    onTap: () => Navigator.pop(context, ShieldChoice.ignore),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatefulWidget {
  final int order;
  final String text;
  const _Line({required this.order, required this.text});
  @override
  State<_Line> createState() => _LineState();
}

class _LineState extends State<_Line> {
  double _t = 0;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 80 + 40 * widget.order), () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // in from the end of the line, and only a fade with less movement
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final still = motionStill(context);
    return AnimatedOpacity(
      opacity: _t,
      duration: const Duration(milliseconds: 240),
      child: AnimatedSlide(
        offset: Offset(still ? 0 : (1 - _t) * (rtl ? -0.04 : 0.04), 0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.rose,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.text,
                  style: HaloType.sans(
                    size: 14,
                    color: HaloColors.text,
                    height: 1.4,
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

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final bool fill;
  final VoidCallback onTap;
  const _Btn(this.label, this.color, {this.fill = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill ? HaloColors.surface3 : HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: HaloType.sans(
              size: 13,
              weight: fill ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
