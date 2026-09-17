// SPDX-License-Identifier: GPL-3.0-or-later
// pins, the parts both chats share. a pinned message is reached from one
// place, the pin in the header; nothing sits over the conversation.
import 'package:flutter/material.dart';

import '../theme.dart';

/// the pin in a chat header. always there, the way search is: quiet with
/// nothing pinned, amber with a count once something is.
class PinHeaderButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const PinHeaderButton({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    return IconButton(
      tooltip: on ? 'Pinned messages · $count' : 'Pinned messages',
      onPressed: onTap,
      icon: SizedBox(
        width: 26,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Transform.rotate(
                angle: 0.5,
                child: Icon(
                  on ? Icons.push_pin : Icons.push_pin_outlined,
                  color: on ? HaloColors.amber : HaloColors.text2,
                  size: 19,
                ),
              ),
            ),
            if (on)
              Positioned(
                right: -2,
                top: -1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3.5,
                    vertical: 0.5,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 99 ? '99' : '$count',
                    textAlign: TextAlign.center,
                    style: HaloType.mono(
                      size: 8.5,
                      weight: FontWeight.w600,
                      color: HaloColors.onAmber,
                      letter: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
