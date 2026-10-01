// SPDX-License-Identifier: GPL-3.0-or-later
// the top of a person's page or a group's: the big face drifts up at half
// the page's speed, shrinks and dims as the page scrolls, and the bar above
// takes over its name. still when the phone asks for no movement, where the
// name in the bar only fades.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'motion.dart' show motionStill;

double _offset(ScrollController c) =>
    c.hasClients && c.positions.length == 1 ? c.positions.first.pixels : 0;

class ParallaxHead extends StatelessWidget {
  final ScrollController controller;
  final Widget child;
  // how far the page scrolls before the head has gone as small as it goes
  final double travel;
  const ParallaxHead({
    super.key,
    required this.controller,
    required this.child,
    this.travel = 150,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (_, child) {
        final off = _offset(controller).clamp(0.0, travel * 2);
        final p = (off / travel).clamp(0.0, 1.0);
        if (still) return child!;
        // held inside its own box, so it sinks behind the page's top edge
        // rather than showing through the gaps of what follows
        return ClipRect(
          clipBehavior: off > 0 ? Clip.hardEdge : Clip.none,
          child: Transform.translate(
            offset: Offset(0, off * 0.45),
            child: Transform.scale(
              scale: 1 - 0.25 * p,
              alignment: Alignment.bottomCenter,
              child: Opacity(opacity: 1 - 0.75 * p, child: child),
            ),
          ),
        );
      },
    );
  }
}

// what the bar above shows once the head has scrolled away: fades in over
// the last stretch, with a hairline under the bar
class HeadTitle extends StatelessWidget {
  final ScrollController controller;
  final String title;
  // where the page's own title has passed under the bar
  final double from;
  const HeadTitle({
    super.key,
    required this.controller,
    required this.title,
    this.from = 150,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final o = ((_offset(controller) - from) / 40).clamp(0.0, 1.0);
        return Opacity(
          opacity: o,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HaloType.serif(size: 17, color: HaloColors.text),
          ),
        );
      },
    );
  }
}

// the hairline under a page's bar, there once the page has scrolled under it.
// a list that starts at the bottom passes [under], how far its content runs
// up past the bar, since its offset says nothing about the top
class HeadLine extends StatelessWidget implements PreferredSizeWidget {
  final ScrollController? controller;
  final ValueListenable<double>? under;
  const HeadLine({super.key, this.controller, this.under})
    : assert(controller != null || under != null);

  @override
  Size get preferredSize => const Size.fromHeight(0.5);

  @override
  Widget build(BuildContext context) {
    final u = under;
    return AnimatedBuilder(
      animation: u ?? controller!,
      builder: (_, _) => Container(
        height: 0.5,
        color: HaloColors.line.withValues(
          alpha: ((u?.value ?? _offset(controller!)) / 24).clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

// the small mono heading over a section of a page, with an action or two
// at its end
class PageSection extends StatelessWidget {
  final String label;
  final List<Widget> actions;
  const PageSection(this.label, {super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 18, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.mono(
                size: 10,
                color: HaloColors.text3,
                weight: FontWeight.w500,
                letter: 0.14,
              ),
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 6), a],
        ],
      ),
    );
  }
}

// the bar over a list page off home: back, the title with a line under it
// when there is one, its actions at the end, and the hairline once the
// list scrolls under it. one shape for every such page
class PageBar extends StatelessWidget {
  final String title;
  final Widget? sub;
  final List<Widget> actions;
  final ScrollController? controller;
  // in place of [controller], for a list that starts at the bottom
  final ValueListenable<double>? under;
  const PageBar({
    super.key,
    required this.title,
    this.sub,
    this.actions = const [],
    this.controller,
    this.under,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final u = under;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 8, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.commonBack,
                icon: Icon(
                  Icons.chevron_left,
                  color: HaloColors.text2,
                  size: 26,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.serif(size: 22, color: HaloColors.text),
                    ),
                    if (sub != null) ...[const SizedBox(height: 2), sub!],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        if (c != null || u != null) HeadLine(controller: c, under: u),
      ],
    );
  }
}
