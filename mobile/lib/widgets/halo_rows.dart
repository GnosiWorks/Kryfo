// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';
import 'halo_switch.dart';

class HaloSection extends StatelessWidget {
  final String label;
  const HaloSection(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 4, 8),
      child: Text(
        label,
        style: HaloType.mono(size: 10.5, color: HaloColors.text3, letter: 0.06),
      ),
    );
  }
}

// one rounded surface holding a section's rows, a hairline between each
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
                padding: const EdgeInsetsDirectional.only(start: 58),
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
  // one plain line under the label saying what the switch does
  final String? hint;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool rose;
  // an on or off setting: a switch stands in for the value and the chevron
  final bool? toggled;
  const HaloRow({
    super.key,
    required this.label,
    this.value,
    this.hint,
    this.onTap,
    this.icon,
    this.rose = false,
    this.toggled,
  });

  @override
  Widget build(BuildContext context) {
    // once the 14pt label renders past ~19 two columns stop fitting on a
    // phone, so a long value goes under the label instead of wrapping
    final on = toggled;
    final v = on != null ? '' : value ?? '';
    final stacked =
        v.length > 16 || MediaQuery.of(context).textScaler.scale(14) > 19;
    final fg = rose ? HaloColors.rose : HaloColors.text;
    final tile = rose
        ? HaloColors.rose.withValues(alpha: 0.12)
        : HaloColors.amberSoft;
    final ink = rose ? HaloColors.rose : HaloColors.amber;
    final row = InkWell(
      onTap: onTap,
      splashColor: ink.withValues(alpha: 0.08),
      highlightColor: ink.withValues(alpha: 0.08),
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
                      padding: const EdgeInsetsDirectional.only(
                        top: 3,
                        end: 10,
                      ),
                      child: Text(
                        hint!,
                        style: HaloType.sans(
                          size: 12.5,
                          color: HaloColors.text2,
                          height: 1.35,
                        ),
                      ),
                    ),
                  if (v.isNotEmpty && stacked)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 4,
                        end: 10,
                      ),
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
            if (on != null) ...[
              const SizedBox(width: 10),
              ExcludeSemantics(
                child: HaloSwitch(
                  value: on,
                  onChanged: onTap == null ? null : (_) => onTap!(),
                ),
              ),
            ] else if (onTap != null) ...[
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
    if (on == null) return row;
    return Semantics(toggled: on, child: row);
  }
}
