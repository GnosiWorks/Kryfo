// SPDX-License-Identifier: GPL-3.0-or-later
// a chat on a wide desktop window keeps its thread and composer at a width
// that reads well, centred, with the wallpaper still edge to edge. the
// phone is never wider than this, and never asks
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../desktop/desktop_mode.dart' show onDesktop;

/// the widest a chat's thread and composer get
const kReadWidth = 720.0;

/// the thread: [builder] gets the room to leave on each side, and below it
/// the screen reads as [kReadWidth] wide, so bubbles size to the column
class ReadWidth extends StatelessWidget {
  final Widget Function(BuildContext context, double side) builder;
  const ReadWidth({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!onDesktop) return builder(context, 0);
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(0.0, (box.maxWidth - kReadWidth) / 2);
        if (side == 0) return builder(context, 0);
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(size: Size(kReadWidth, mq.size.height)),
          child: Builder(builder: (c) => builder(c, side)),
        );
      },
    );
  }
}

/// a line under the thread, as the composer, centred at [kReadWidth]
class ReadColumn extends StatelessWidget {
  final Widget child;
  const ReadColumn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!onDesktop) return child;
    return ReadWidth(
      builder: (_, side) => side == 0
          ? child
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: side),
              child: child,
            ),
    );
  }
}

/// a chat's lines around its thread, each at reading width. the thread
/// itself, the one that expands, keeps the whole width for its wallpaper
List<Widget> readLines(List<Widget> lines) => !onDesktop
    ? lines
    : [for (final w in lines) w is Flexible ? w : ReadColumn(child: w)];
