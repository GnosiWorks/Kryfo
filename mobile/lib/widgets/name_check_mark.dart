// SPDX-License-Identifier: GPL-3.0-or-later
// beside three words a request, an introduction or a group gave. anyone
// can give any words, so they read as not checked until they are added by
// a camera scan or the safety number is verified
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

class NameCheckMark extends StatelessWidget {
  const NameCheckMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.nameNotChecked,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 1, 6, 2),
          decoration: BoxDecoration(
            color: HaloColors.warn.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: HaloColors.warn.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, size: 10, color: HaloColors.warn),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  l10n.nameNotChecked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(size: 10, color: HaloColors.warnText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
