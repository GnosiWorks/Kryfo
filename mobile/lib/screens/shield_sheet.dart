// SPDX-License-Identifier: GPL-3.0-or-later
// what the scam shield saw, one plain line per rule, then block, delete or
// ignore. no score, no percentage. the person decides.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../main.dart' show db, appState;
import '../theme.dart';
import '../widgets/notice_banner.dart';

// a stored flag, as the row in the shield table reads back.
class ShieldFlag {
  final String headline;
  final List<String> lines;
  const ShieldFlag(this.headline, this.lines);

  static ShieldFlag? fromRow(Map<String, Object?>? r) {
    if (r == null || (r['dismissed'] as int? ?? 0) == 1) return null;
    try {
      final lines = (jsonDecode(r['lines'] as String) as List)
          .map((e) => e.toString())
          .toList();
      return ShieldFlag(r['headline'] as String, lines);
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
  ShieldFlag flag,
) async {
  final choice = await showModalBottomSheet<ShieldChoice>(
    context: context,
    backgroundColor: HaloColors.surface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _ShieldSheet(flag: flag),
  );
  if (choice == null) return null;
  HapticFeedback.selectionClick();
  switch (choice) {
    case ShieldChoice.block:
      await db.setBlocked(haloId, true);
    case ShieldChoice.delete:
      await db.declineRequest(haloId);
    case ShieldChoice.ignore:
      await db.dismissShield(haloId);
  }
  await appState.refreshContacts();
  return choice;
}

class _ShieldSheet extends StatelessWidget {
  final ShieldFlag flag;
  const _ShieldSheet({required this.flag});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HaloColors.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
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
              'checked on this phone. nothing was sent anywhere.',
              style: HaloType.mono(size: 10, color: HaloColors.text3),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Btn(
                  'block',
                  HaloColors.rose,
                  onTap: () => Navigator.pop(context, ShieldChoice.block),
                ),
                const SizedBox(width: 8),
                _Btn(
                  'delete',
                  HaloColors.text,
                  onTap: () => Navigator.pop(context, ShieldChoice.delete),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Btn(
                    'ignore',
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
    return AnimatedOpacity(
      opacity: _t,
      duration: const Duration(milliseconds: 240),
      child: AnimatedSlide(
        offset: Offset((1 - _t) * 0.04, 0),
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

class _Btn extends StatefulWidget {
  final String label;
  final Color color;
  final bool fill;
  final VoidCallback onTap;
  const _Btn(this.label, this.color, {this.fill = false, required this.onTap});
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.fill ? HaloColors.surface3 : HaloColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HaloColors.line, width: 0.5),
          ),
          child: Text(
            widget.label,
            style: HaloType.sans(
              size: 13,
              weight: widget.fill ? FontWeight.w600 : FontWeight.w400,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
