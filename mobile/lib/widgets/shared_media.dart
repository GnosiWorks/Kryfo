// SPDX-License-Identifier: GPL-3.0-or-later
// what a chat shared: its count over the first four, the last of them
// saying how many more. a tap on any opens them all. until the rows are
// read it holds four quiet tiles, so nothing wrong is ever on screen
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../theme.dart';
import 'ease_size.dart';
import 'halo_rows.dart';
import 'motion.dart' show motionStill;
import 'page_head.dart';
import 'press_scale.dart';
import 'swap.dart';

class SharedMediaSection extends StatelessWidget {
  final List<String> paths;
  final int count;
  // false while the rows are still being read
  final bool loaded;
  final VoidCallback? onOpen;
  const SharedMediaSection({
    super.key,
    required this.paths,
    required this.count,
    this.loaded = true,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (!loaded) {
      body = KeyedSubtree(
        key: const ValueKey('media-waiting'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageSection(l10n.groupInfoSharedMedia),
            _row((_, _) => const _BlankTile()),
          ],
        ),
      );
    } else if (count == 0) {
      body = Padding(
        key: const ValueKey('media-none'),
        padding: const EdgeInsets.only(top: 18),
        child: HaloGroup(
          children: [
            HaloRow(
              icon: Icons.photo_library_outlined,
              label: l10n.contactNothingSharedYet,
            ),
          ],
        ),
      );
    } else {
      final shown = paths.take(4).toList();
      final more = count - 3;
      body = Column(
        key: const ValueKey('media-some'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageSection(l10n.contactSharedMedia(whole(count))),
          PressScale(
            onTap: onOpen,
            scale: 0.98,
            label: l10n.contactSharedMedia(whole(count)),
            child: _row(
              (i, side) => i >= shown.length
                  ? const SizedBox.shrink()
                  : _Tile(
                      path: shown[i],
                      side: side,
                      more: i == 3 && count > 4 ? more : 0,
                    ),
            ),
          ),
        ],
      );
    }
    // the space eases to what came, and the new state fades over the old
    return EaseSize(child: FadeSwap(child: body));
  }

  Widget _row(Widget Function(int i, double side) tile) => LayoutBuilder(
    builder: (context, box) {
      const gap = 6.0;
      final side = (box.maxWidth - gap * 3) / 4;
      return Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            SizedBox.square(dimension: side, child: tile(i, side)),
          ],
        ],
      );
    },
  );
}

class _BlankTile extends StatelessWidget {
  const _BlankTile();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String path;
  final double side;
  // shown over the last tile: how many more there are
  final int more;
  const _Tile({required this.path, required this.side, this.more = 0});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: HaloColors.surface2),
          Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: (side * MediaQuery.devicePixelRatioOf(context)).round(),
            // a photo fades in as it decodes rather than blinking on
            frameBuilder: (_, child, frame, sync) => sync || still
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: child,
                  ),
            // a black square would read as a broken app, not a photo whose
            // file is gone
            errorBuilder: (_, _, _) => MissingTile(size: side),
          ),
          if (more > 0)
            ColoredBox(
              color: HaloColors.ink.withValues(alpha: 0.62),
              child: Center(
                child: Text(
                  '+${whole(more)}',
                  style: HaloType.mono(
                    size: 15,
                    color: HaloColors.amber,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// a photo whose file has gone, drawn so it does not look like a failed load
class MissingTile extends StatelessWidget {
  final double size;
  const MissingTile({super.key, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: HaloColors.surface2,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size * 0.32,
        color: HaloColors.text3,
      ),
    );
  }
}
