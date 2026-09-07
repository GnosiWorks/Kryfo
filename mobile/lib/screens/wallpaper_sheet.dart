// SPDX-License-Identifier: GPL-3.0-or-later
// the wallpaper picker, shared by chats and groups. gradients and patterns,
// stored on this phone in the encrypted db, gone on wipe. nothing here is
// ever sent.
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import 'chat_screen.dart'
    show Atmo, atmoAccent, atmoLabel, atmoIsPattern, PatternPainter;

Future<Atmo?> showWallpaperSheet(BuildContext context, Atmo current) {
  final gradients = Atmo.values.where((a) => !atmoIsPattern(a)).toList();
  final patterns = Atmo.values.where(atmoIsPattern).toList();
  return showHaloSheet<Atmo>(
    context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 10),
            Text(
              'wallpaper',
              style: HaloType.serif(size: 18, color: HaloColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              'behind this conversation, on this phone only. gone on wipe.',
              style: HaloType.sans(size: 12, color: HaloColors.text2),
            ),
            const SizedBox(height: 16),
            _Head('gradients'),
            const SizedBox(height: 10),
            _Swatches(
              items: gradients,
              current: current,
              onPick: (a) => Navigator.pop(ctx, a),
            ),
            const SizedBox(height: 16),
            _Head('patterns'),
            const SizedBox(height: 10),
            _Swatches(
              items: patterns,
              current: current,
              onPick: (a) => Navigator.pop(ctx, a),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Head extends StatelessWidget {
  final String t;
  const _Head(this.t);
  @override
  Widget build(BuildContext context) => Text(
    t,
    style: HaloType.mono(
      size: 10,
      color: HaloColors.text3,
      letter: 0.14,
      weight: FontWeight.w600,
    ),
  );
}

class _Swatches extends StatelessWidget {
  final List<Atmo> items;
  final Atmo current;
  final ValueChanged<Atmo> onPick;
  const _Swatches({
    required this.items,
    required this.current,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: [
        for (final a in items)
          GestureDetector(
            onTap: () => onPick(a),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: a == Atmo.none
                        ? HaloColors.surface3
                        : atmoIsPattern(a)
                        ? HaloColors.surface2
                        : atmoAccent(a).withValues(alpha: 0.18),
                    border: Border.all(
                      color: a == current ? HaloColors.amber : HaloColors.line,
                      width: a == current ? 1.5 : 0.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: a == Atmo.none
                      ? Icon(
                          Icons.not_interested,
                          size: 16,
                          color: HaloColors.text3,
                        )
                      : atmoIsPattern(a)
                      ? CustomPaint(
                          size: const Size(46, 46),
                          painter: PatternPainter(a, scale: 0.55),
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  atmoLabel(a),
                  style: HaloType.mono(
                    size: 10,
                    color: a == current ? HaloColors.amber : HaloColors.text3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
