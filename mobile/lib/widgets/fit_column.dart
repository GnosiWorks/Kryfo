// SPDX-License-Identifier: GPL-3.0-or-later
// a column for a whole screen: on a tall phone a spacer still pushes the
// button to the bottom, on a short one or with a large display zoom the page
// scrolls instead of dropping the button under the navigation bar.
import 'package:flutter/material.dart';

class FitColumn extends StatelessWidget {
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;
  const FitColumn({
    super.key,
    this.padding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (c.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
