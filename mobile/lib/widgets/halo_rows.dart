// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';

class HaloSection extends StatelessWidget {
  final String label;
  const HaloSection(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 8),
      child: Text(
        label,
        style: HaloType.mono(size: 10.5, color: HaloColors.text3, letter: 0.06),
      ),
    );
  }
}

// one rounded surface holding a section's rows, a hairline between each.
// the page used to be a stack of separate cards, one per row.
class HaloGroup extends StatelessWidget {
  final List<Widget> children;
  final bool rose;
  const HaloGroup({super.key, required this.children, this.rose = false});
  @override
  Widget build(BuildContext context) {
    final line = rose
        ? HaloColors.rose.withValues(alpha: 0.35)
        : HaloColors.line;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: rose
            ? HaloColors.rose.withValues(alpha: 0.05)
            : HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Container(height: 0.5, color: line),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class HaloRow extends StatelessWidget {
  final String label;
  final String? value;
  // one plain line under the label. toggles showed on/off and nothing
  // about what the switch actually does.
  final String? hint;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool rose;
  const HaloRow({
    super.key,
    required this.label,
    this.value,
    this.hint,
    this.onTap,
    this.icon,
    this.rose = false,
  });

  @override
  Widget build(BuildContext context) {
    // 14pt is the label size; once it renders past ~19 the two-column layout
    // stops fitting on a phone. a short value sits on the right, a sentence
    // goes under the label instead of wrapping into ribbons.
    final v = value ?? '';
    final stacked =
        v.length > 16 || MediaQuery.of(context).textScaler.scale(14) > 19;
    final fg = rose ? HaloColors.rose : HaloColors.text;
    final tile = rose
        ? HaloColors.rose.withValues(alpha: 0.12)
        : HaloColors.amberSoft;
    final ink = rose ? HaloColors.rose : HaloColors.amber;
    return InkWell(
      onTap: onTap,
      splashColor: ink.withValues(alpha: 0.08),
      highlightColor: ink.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tile,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon ?? Icons.circle_outlined, size: 17, color: ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: HaloType.sans(size: 14, color: fg)),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3, right: 10),
                      child: Text(
                        hint!,
                        style: HaloType.mono(
                          size: 10.5,
                          color: HaloColors.text3,
                        ),
                      ),
                    ),
                  if (v.isNotEmpty && stacked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 10),
                      child: Text(
                        v,
                        style: HaloType.sans(size: 13, color: HaloColors.text2),
                      ),
                    ),
                ],
              ),
            ),
            if (v.isNotEmpty && !stacked) ...[
              const SizedBox(width: 8),
              Text(v, style: HaloType.sans(size: 13, color: HaloColors.text2)),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: rose ? ink : HaloColors.text3,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
