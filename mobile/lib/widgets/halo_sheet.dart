// SPDX-License-Identifier: GPL-3.0-or-later
// one way to open a sheet. same surface, same corner, same dim behind it and
// the same rise, so a sheet from the chat feels like a sheet from home.
import 'package:flutter/material.dart';

import '../theme.dart';

const kSheetRadius = 20.0;

Future<T?> showHaloSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  // tall sheets with a keyboard or a list want the whole height
  bool scroll = false,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: HaloColors.surface2,
    barrierColor: HaloColors.ink.withValues(alpha: 0.62),
    isScrollControlled: scroll,
    isDismissible: dismissible,
    enableDrag: dismissible,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kSheetRadius)),
    ),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      reverseDuration: Duration(milliseconds: 200),
      reverseCurve: Curves.easeInCubic,
    ),
  );
}
