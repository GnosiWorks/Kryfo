// SPDX-License-Identifier: GPL-3.0-or-later
// one way to open a sheet. same surface, same corner, same dim behind it and
// the same rise, so a sheet from the chat feels like a sheet from home.
import 'package:flutter/material.dart';

import '../theme.dart';

const kSheetRadius = 20.0;

Future<T?> showHaloSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  // true: the sheet manages its own height and scrolling. false, the
  // default: the content scrolls inside a ceiling of nine tenths of the
  // screen, and the keyboard pushes it up. sheets used to be capped at
  // nine sixteenths of the screen with no scroll, which on a short phone
  // cut the buttons off the shield sheet and the choice sheets.
  bool scroll = false,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: scroll
        ? builder
        : (ctx) {
            final mq = MediaQuery.of(ctx);
            // the keyboard inset is spent here, so content that pads for
            // it too (the confirm sheets) does not pad twice
            return Padding(
              padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
              child: MediaQuery.removeViewInsets(
                context: ctx,
                removeBottom: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
                  child: SingleChildScrollView(child: builder(ctx)),
                ),
              ),
            );
          },
    backgroundColor: HaloColors.surface2,
    barrierColor: HaloColors.ink.withValues(alpha: 0.62),
    isScrollControlled: true,
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
