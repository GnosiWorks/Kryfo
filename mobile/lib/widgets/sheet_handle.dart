// SPDX-License-Identifier: GPL-3.0-or-later
// the short bar at the top of every bottom sheet. one widget so every sheet
// gets the same one and none forgets it.
import 'package:flutter/material.dart';
import '../theme.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: HaloColors.line2,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
