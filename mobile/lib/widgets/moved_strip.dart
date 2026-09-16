// SPDX-License-Identifier: GPL-3.0-or-later
// what stands where the composer was, on a phone whose identity has moved.
// the engine is not running, so a message typed here would sit in the
// outbox forever; better that there is nowhere to type it.
import 'package:flutter/material.dart';

import '../theme.dart';

class MovedStrip extends StatelessWidget {
  const MovedStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: HaloColors.text3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This kryfo has moved to another device. Nothing sent from '
                'here reaches anyone.',
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
