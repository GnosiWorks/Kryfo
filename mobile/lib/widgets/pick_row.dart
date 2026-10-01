// SPDX-License-Identifier: GPL-3.0-or-later
// a contact to tick, for a new group or for adding members: the name they
// were given with the id under it, the face they chose, a tick that fills
import 'package:flutter/material.dart';

import '../theme.dart';
import 'kryfo_avatar.dart';
import 'motion.dart' show motionStill;
import 'press_scale.dart';

class PickRow extends StatelessWidget {
  final String id;
  final String? nickname;
  final String seed;
  final int? face;
  final bool picked;
  final VoidCallback onTap;
  final double size;
  final EdgeInsetsGeometry padding;
  const PickRow({
    super.key,
    required this.id,
    this.nickname,
    required this.seed,
    this.face,
    required this.picked,
    required this.onTap,
    this.size = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final name = nickname ?? id;
    final d = motionStill(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    // one node: the name, a button, ticked or not
    return Semantics(
      container: true,
      button: true,
      selected: picked,
      label: name,
      child: PressScale(
        scale: 0.98,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                KryfoAvatar(seed: seed, size: size, choice: face),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HaloType.sans(
                          size: 14,
                          weight: FontWeight.w500,
                          color: HaloColors.text,
                        ),
                      ),
                      if (nickname != null)
                        Text(
                          id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.text3,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: d,
                  curve: Curves.easeOutCubic,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: picked ? HaloColors.amber : Colors.transparent,
                    border: Border.all(
                      color: picked ? HaloColors.amber : HaloColors.line2,
                      width: 1.4,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedScale(
                    duration: d,
                    curve: Curves.easeOutBack,
                    scale: picked ? 1 : 0.4,
                    child: AnimatedOpacity(
                      duration: d,
                      opacity: picked ? 1 : 0,
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: HaloColors.onAmber,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
