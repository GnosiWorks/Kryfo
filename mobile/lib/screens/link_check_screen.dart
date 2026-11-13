// SPDX-License-Identifier: GPL-3.0-or-later
// what a linked computer shows as it starts, before any chat: it reads
// its phone's latest list of devices first. over everything, the lock
// included, until the list named it or the chats show read only
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/motion.dart' show BreathDot;
import '../widgets/stagger_in.dart';

class LinkCheckScreen extends StatelessWidget {
  const LinkCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StaggerIn(
                      index: 0,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: HaloColors.amber.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: HaloColors.amber,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    StaggerIn(
                      index: 1,
                      child: Text(
                        l10n.linkCheckTitle,
                        textAlign: TextAlign.center,
                        style: HaloType.serif(size: 24, color: HaloColors.text),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaggerIn(
                      index: 2,
                      child: Text(
                        l10n.linkCheckLine,
                        textAlign: TextAlign.center,
                        style: HaloType.sans(
                          size: 14.5,
                          color: HaloColors.text,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    StaggerIn(
                      index: 3,
                      child: ExcludeSemantics(
                        child: BreathDot(color: HaloColors.amber, size: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
