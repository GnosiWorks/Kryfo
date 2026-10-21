// SPDX-License-Identifier: GPL-3.0-or-later
// text under a raw route or an overlay entry has no material above it, and
// flutter draws it in its error style: a yellow double underline. every
// such page and entry stands on this.
import 'package:flutter/material.dart';

class TextGround extends StatelessWidget {
  final Widget child;
  const TextGround({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}
