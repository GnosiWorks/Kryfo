// SPDX-License-Identifier: GPL-3.0-or-later
// a zip's glance in its bubble: the archive mark, its first few files and
// folders, and how many more. from the sender's summary before the file is
// here, from the file's own directory once it is (zip_glance.dart). drawn
// as the word document's glance is: the bubble's ground, its type scale,
// its fade where more follows
import 'package:flutter/material.dart';

import '../file_kind.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import '../zip_glance.dart';
import 'file_badge.dart';
import 'media_bubbles.dart' show fileGlyph, humanFileSize;
import 'motion.dart' show motionStill;
import 'preview_bleed.dart';

class ArchiveGlance extends StatelessWidget {
  final ZipGlance glance;
  final bool isOut;
  const ArchiveGlance({super.key, required this.glance, required this.isOut});

  @override
  Widget build(BuildContext context) {
    final g = glance;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final fg = isOut ? HaloColors.onAmber : HaloColors.text;
    final mark = isOut ? HaloColors.onAmber : fileToneColor(FileTone.zip);
    final body = HaloType.sans(size: 12, color: fg, height: 1.35);
    final small = HaloType.mono(size: 10, color: fg);
    final more = g.more;
    final tail = [
      if (more > 0) l10n.archiveMore(whole(more)),
      if (g.unpacked case final u?) l10n.archiveUnpacked(humanFileSize(u)),
    ].join(' \u00b7 ');
    Color toneOf(ZipTop t) {
      if (isOut) return HaloColors.onAmber;
      if (t.folder) return mark;
      final ext = extOf(t.name);
      return fileToneColor(fileToneOf(FileFacts(kindOfName(t.name), ext)));
    }

    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, t) in g.top.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 3),
            child: Row(
              children: [
                Icon(
                  t.folder
                      ? Icons.folder_outlined
                      : fileGlyph(kindOfName(t.name)),
                  size: 14,
                  color: toneOf(t),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: t.folder ? '${t.name}/' : t.name),
                        if (t.folder)
                          TextSpan(
                            text:
                                ' \u00b7 ${l10n.filesCount(t.files, whole(t.files))}',
                            style: small,
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: scaler,
                    style: body,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    return Container(
      width: kFilePreviewGlanceWidth,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.06),
        borderRadius: previewRadius(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ZipMark(color: mark, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ZIP \u00b7 ${l10n.filesCount(g.count, whole(g.count))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: small,
                ),
              ),
              if (g.locked) ...[
                Icon(Icons.lock_outline_rounded, size: 12, color: fg),
                const SizedBox(width: 3),
                Text(l10n.archiveProtected, textScaler: scaler, style: small),
              ],
            ],
          ),
          if (g.top.isNotEmpty) ...[
            const SizedBox(height: 7),
            if (more > 0)
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0x26FFFFFF),
                  ],
                  stops: [0, 0.72, 1],
                ).createShader(r),
                child: rows,
              )
            else
              rows,
          ],
          if (tail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(tail, maxLines: 2, textScaler: scaler, style: small),
          ],
        ],
      ),
    );
  }
}

/// the width a glance is laid out at outside a bubble
const kFilePreviewGlanceWidth = 236.0;

// zips read on this phone, by path: gone at the lock
final Map<String, ZipGlance> _kept = {};

/// a zip's glance read now, if it was read before
ZipGlance? zipGlanceNow(String path) => _kept[path];

/// reads and keeps [path]'s glance; null when it is no zip it can read
Future<ZipGlance?> zipGlanceKept(String path) async {
  final had = _kept[path];
  if (had != null) return had;
  if (picturesShut.value) return null;
  final g = await zipGlanceOf(path);
  if (g == null || picturesShut.value) return null;
  if (_kept.length > 24) _kept.remove(_kept.keys.first);
  return _kept[path] = g;
}

/// the lock lets go of every zip's glance
void forgetZipGlances() => _kept.clear();

/// [path] is going: its glance with it
void forgetZipGlanceOf(String path) => _kept.remove(path);

/// a zip on this phone, its glance read from its own directory
class ArchiveGlanceOf extends StatefulWidget {
  final String path;
  final bool isOut;
  const ArchiveGlanceOf({super.key, required this.path, required this.isOut});

  @override
  State<ArchiveGlanceOf> createState() => _ArchiveGlanceOfState();
}

class _ArchiveGlanceOfState extends State<ArchiveGlanceOf> {
  late ZipGlance? _g = zipGlanceNow(widget.path);
  late final bool _hadIt = _g != null;

  @override
  void initState() {
    super.initState();
    picturesShut.addListener(_lock);
    if (_g == null) _read();
  }

  @override
  void didUpdateWidget(ArchiveGlanceOf old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _g = zipGlanceNow(widget.path);
      if (_g == null) _read();
    }
  }

  @override
  void dispose() {
    picturesShut.removeListener(_lock);
    super.dispose();
  }

  void _lock() {
    if (picturesShut.value) {
      forgetZipGlances();
      if (mounted) setState(() => _g = null);
    } else {
      _read();
    }
  }

  Future<void> _read() async {
    final p = widget.path;
    final g = await zipGlanceKept(p);
    if (!mounted || p != widget.path || g == null) return;
    setState(() => _g = g);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    if (g == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: motionStill(context) || _hadIt ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (_, v, c) => Opacity(opacity: v, child: c),
      child: ArchiveGlance(glance: g, isOut: widget.isOut),
    );
  }
}
