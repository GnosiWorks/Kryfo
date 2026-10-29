// SPDX-License-Identifier: GPL-3.0-or-later
// home's one-time card after the update that made relay and fast one
// route: what fast is now, in one honest line, and private a tap away.

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'press_scale.dart';

class RouteMergedCard extends StatelessWidget {
  final VoidCallback onGotIt;
  final VoidCallback onPrivate;
  const RouteMergedCard({
    super.key,
    required this.onGotIt,
    required this.onPrivate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 8, 18),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        border: Border.all(color: HaloColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HaloColors.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 22,
                  color: HaloColors.amberText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.homeMergedTitle,
                    style: HaloType.sans(size: 17, weight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: onGotIt,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: HaloColors.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Text(
              l10n.homeMergedLine,
              style: HaloType.sans(
                size: 15,
                color: HaloColors.text,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // the two answers flow onto a second line in longer languages
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(label: l10n.homeMergedGotIt, filled: true, onTap: onGotIt),
              _Pill(
                label: l10n.homeMergedUsePrivate,
                filled: false,
                onTap: onPrivate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: PressScale(
        scale: 0.96,
        onTap: onTap,
        // about 44 high at the usual size, taller with the text
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: filled ? HaloColors.text : null,
            border: filled ? null : Border.all(color: HaloColors.line2),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 14,
              weight: FontWeight.w500,
              color: filled ? HaloColors.surface : HaloColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
