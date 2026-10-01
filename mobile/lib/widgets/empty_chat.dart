// SPDX-License-Identifier: GPL-3.0-or-later
// what a conversation with nothing in it yet shows: a glyph in a soft glow,
// a line to start with and a word under it. it rises in once, and only
// fades when the phone asks for no movement.
import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';

class EmptyChat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line;
  // amber for a chat or a group, violet for a burner room
  final Color? tint;
  const EmptyChat({
    super.key,
    required this.icon,
    required this.title,
    required this.line,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = tint ?? HaloColors.amber;
    final soft = tint == null
        ? HaloColors.amberSoft
        : c.withValues(alpha: 0.14);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, motionStill(context) ? 0 : (1 - t) * 12),
            child: child,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: soft,
                  border: Border.all(
                    color: c.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: c, size: 25),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: HaloType.serif(
                  size: 24,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                line,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
