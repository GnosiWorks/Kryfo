// SPDX-License-Identifier: GPL-3.0-or-later
// a box that eases to its child's new height instead of jumping. with less
// movement it is simply the new size: an AnimatedSize given no time trips
// over its own layout
import 'package:flutter/material.dart';

class EaseSize extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;
  const EaseSize({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: child,
    );
  }
}
