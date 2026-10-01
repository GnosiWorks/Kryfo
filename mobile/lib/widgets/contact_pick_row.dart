// SPDX-License-Identifier: GPL-3.0-or-later
// a contact in a sheet that picks people: their name over their three
// words, and a check that pops in on the house curve
import 'package:flutter/material.dart';

import '../screens/home_screen.dart' show ContactPreview;
import '../theme.dart';
import 'kryfo_avatar.dart';
import 'motion.dart' show kHouseCurve, kHouseTime;
import 'press_scale.dart';

// one contact to pick. the face grows and gets an amber ring when chosen.
class ContactPickRow extends StatelessWidget {
  final ContactPreview contact;
  final bool picked;
  final VoidCallback onTap;
  const ContactPickRow({
    super.key,
    required this.contact,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact.nickname;
    final still = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      selected: picked,
      label: name ?? contact.haloId,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.98,
        // the sheet clicks for the pick itself
        haptic: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              AnimatedScale(
                scale: picked && !still ? 1.1 : 1.0,
                duration: still ? Duration.zero : kHouseTime,
                curve: kHouseCurve,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: picked ? HaloColors.amber : Colors.transparent,
                      width: 1.6,
                    ),
                  ),
                  child: KryfoAvatar(
                    seed: contact.avatarSeed,
                    size: 38,
                    choice: contact.avatar,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? contact.haloId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: name == null
                          ? HaloType.mono(
                              size: 12,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            )
                          : HaloType.sans(
                              size: 14,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            ),
                    ),
                    if (name != null)
                      Text(
                        contact.haloId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HaloType.mono(size: 10, color: HaloColors.text3),
                      ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
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
                  scale: picked || still ? 1 : 0.3,
                  duration: still ? Duration.zero : kHouseTime,
                  curve: kHouseCurve,
                  child: AnimatedOpacity(
                    opacity: picked ? 1 : 0,
                    duration: const Duration(milliseconds: 140),
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
    );
  }
}
