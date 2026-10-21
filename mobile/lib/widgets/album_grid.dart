// SPDX-License-Identifier: GPL-3.0-or-later
// an album in a chat: its photos and videos in one grid (album.dart lays it
// out). a place still on its way holds its tile, so nothing moves when it
// lands. a tap opens the album viewer at that item.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../album.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../media_progress.dart';
import '../open_file.dart';
import '../theme.dart';
import 'decode_px.dart';
import 'halo_hero.dart';
import 'motion.dart' show motionStill;
import 'photo_viewer.dart' show PhotoTileFade;
import 'press_scale.dart';
import 'swap.dart';

/// the tag a tile and its page in the viewer share
Object albumHeroTag(String path) => ('album', path);

class AlbumTile {
  // the photo or the video as kept here. null while it is on its way
  final String? path;
  final bool video;
  // it came, and its file could not be kept
  final bool lost;
  // ours and still going: its own progress shows on it
  final String? sendingUid;
  const AlbumTile({
    this.path,
    this.video = false,
    this.lost = false,
    this.sendingUid,
  });
}

class AlbumGrid extends StatelessWidget {
  // a place each, null for one still on its way
  final List<AlbumTile?> tiles;
  final double width;
  // words under it: the bottom corners are the bubble's
  final bool captioned;
  final void Function(int index)? onOpen;
  final void Function(int index)? onLongPress;
  // the time and tick, in the bottom corner on the end side, or the start
  // side where something hangs at the end
  final Widget? stamp;
  final bool stampAtStart;
  const AlbumGrid({
    super.key,
    required this.tiles,
    required this.width,
    this.captioned = false,
    this.onOpen,
    this.onLongPress,
    this.stamp,
    this.stampAtStart = false,
    this.radius = 14,
  });

  // the bubble's own corners, so the grid's edges meet them
  final double radius;

  @override
  Widget build(BuildContext context) {
    final n = tiles.length;
    final cells = albumCells(n, width);
    // a place still coming opens the viewer over what is here, so no tile
    // is a dead end
    final any = tiles.any((t) => t?.path != null);
    final h = albumHeight(n, width);
    final r = Radius.circular(radius);
    return Semantics(
      container: true,
      label: l10n.albumLabel(whole(n)),
      child: ClipRRect(
        borderRadius: captioned
            ? BorderRadius.vertical(top: r)
            : BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: h,
          child: Stack(
            children: [
              for (final c in cells)
                PositionedDirectional(
                  start: c.rect.left,
                  top: c.rect.top,
                  width: c.rect.width,
                  height: c.rect.height,
                  child: _Cell(
                    key: ValueKey(c.slot),
                    // a wide photo in a tall tile is cropped to its height
                    width: math.max(c.rect.width, c.rect.height),
                    tile: tiles[c.slot],
                    at: c.slot,
                    of: n,
                    more: c.more,
                    onOpen: any ? onOpen : null,
                    onLongPress: onLongPress,
                  ),
                ),
              if (stamp case final s?)
                PositionedDirectional(
                  start: stampAtStart ? 8 : null,
                  end: stampAtStart ? null : 8,
                  bottom: 8,
                  child: s,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final AlbumTile? tile;
  // the tile's width here, what its photo is decoded at
  final double width;
  final int at;
  final int of;
  final int more;
  final void Function(int index)? onOpen;
  final void Function(int index)? onLongPress;
  const _Cell({
    super.key,
    required this.width,
    required this.tile,
    required this.at,
    required this.of,
    required this.more,
    this.onOpen,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = tile;
    final path = t?.path;
    final video = t?.video ?? false;
    final lost = t?.lost ?? false;
    final what = t == null
        ? l10n.albumOnItsWay
        : lost
        ? l10n.chatPhotoUnavailable
        : t.video
        ? l10n.videoBubbleVideo
        : l10n.appPhoto;
    final Widget face = FadeSwap(
      child: lost
          ? const _Lost(key: ValueKey('lost'))
          : path == null
          ? _Arriving(key: const ValueKey('wait'))
          : KeyedSubtree(
              key: ValueKey(path),
              child: HaloHero(
                tag: albumHeroTag(path),
                flightShuttleBuilder: (_, a, _, _, _) =>
                    albumFlight(a, path, video: video, radius: 4),
                child: video
                    ? _VideoFace(path: path)
                    : _PhotoFace(path: path, width: width),
              ),
            ),
    );
    return Semantics(
      container: true,
      button: onOpen != null,
      label: '$what, ${l10n.albumCounter(whole(at + 1), whole(of))}',
      value: more > 0 ? l10n.albumMore(whole(more)) : null,
      excludeSemantics: true,
      onTap: onOpen == null ? null : () => onOpen!(at),
      child: PressScale(
        scale: 0.97,
        haptic: false,
        onTap: onOpen == null ? null : () => onOpen!(at),
        onLongPress: onLongPress == null ? null : () => onLongPress!(at),
        child: Stack(
          fit: StackFit.expand,
          children: [
            face,
            if (video && path != null) _VideoMarks(path: path),
            if (t?.sendingUid case final uid?) _Progress(uid: uid),
            if (more > 0)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Text(
                    '+${whole(more)}',
                    style: HaloType.sans(
                      size: 26,
                      weight: FontWeight.w600,
                      color: Colors.white,
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

class _PhotoFace extends StatelessWidget {
  final String path;
  final double width;
  const _PhotoFace({required this.path, required this.width});

  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    fit: BoxFit.cover,
    gaplessPlayback: true,
    cacheWidth: decodePx(context, width),
    frameBuilder: (_, child, frame, sync) =>
        PhotoTileFade(shown: sync || frame != null, child: child),
    errorBuilder: (_, _, _) => const _Lost(),
  );
}

class _VideoFace extends StatefulWidget {
  final String path;
  const _VideoFace({required this.path});
  @override
  State<_VideoFace> createState() => _VideoFaceState();
}

class _VideoFaceState extends State<_VideoFace> {
  late VideoInfo? _info = videoInfoNow(widget.path);

  @override
  void initState() {
    super.initState();
    if (_info == null) {
      videoInfoFor(widget.path).then((i) {
        if (mounted && i != null) setState(() => _info = i);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jpeg = _info?.jpeg;
    return FadeSwap(
      child: jpeg == null
          ? ColoredBox(key: const ValueKey('none'), color: HaloColors.surface3)
          : Image.memory(
              jpeg,
              key: const ValueKey('frame'),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}

// a play mark in the middle and the length in the top corner
class _VideoMarks extends StatefulWidget {
  final String path;
  const _VideoMarks({required this.path});
  @override
  State<_VideoMarks> createState() => _VideoMarksState();
}

class _VideoMarksState extends State<_VideoMarks> {
  late Duration? _len = videoInfoNow(widget.path)?.length;

  @override
  void initState() {
    super.initState();
    if (_len == null) {
      videoInfoFor(widget.path).then((i) {
        if (mounted && i != null) setState(() => _len = i.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final len = _len;
    return IgnorePointer(
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 26,
                color: HaloColors.amber,
              ),
            ),
          ),
          if (len != null && len > Duration.zero)
            PositionedDirectional(
              start: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  videoLength(len),
                  style: HaloType.mono(size: 9.5, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// a place whose item has not landed: a quiet box with a slow mark
class _Arriving extends StatelessWidget {
  const _Arriving({super.key});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return ColoredBox(
      color: HaloColors.surface2,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            // a still ring where the phone asks for no movement
            value: still ? 0.3 : null,
            color: HaloColors.amber,
            backgroundColor: HaloColors.line,
          ),
        ),
      ),
    );
  }
}

class _Lost extends StatelessWidget {
  const _Lost({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: HaloColors.surface2,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 20,
        color: HaloColors.text2,
      ),
    ),
  );
}

// ours on its way: how far, on the tile it is
class _Progress extends StatelessWidget {
  final String uid;
  const _Progress({required this.uid});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: mediaProgressTick,
    builder: (_, _, _) {
      final v = mediaSendProgress[uid];
      return IgnorePointer(
        child: AnimatedOpacity(
          opacity: v == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (v ?? 0).clamp(0.04, 1.0)),
                duration: motionStill(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                builder: (_, f, _) => CircularProgressIndicator(
                  strokeWidth: 2.4,
                  value: f,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// a tile between the grid and the viewer: its crop opening to the whole
/// frame, the corners easing from the tile's to none
Widget albumFlight(
  Animation<double> a,
  String path, {
  required bool video,
  double radius = 0,
}) => AnimatedBuilder(
  animation: a,
  builder: (_, _) => ClipRRect(
    borderRadius: BorderRadius.circular(radius * (1 - a.value)),
    child: video
        ? switch (videoInfoNow(path)?.jpeg) {
            final j? => Image.memory(j, fit: BoxFit.cover),
            _ => const ColoredBox(color: Colors.black),
          }
        : Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true),
  ),
);
