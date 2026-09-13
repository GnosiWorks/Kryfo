// SPDX-License-Identifier: GPL-3.0-or-later
// the atmosphere picker, shared by chats and groups. moods, gradients and
// patterns, stored on this phone in the encrypted db, gone on wipe. nothing
// here is ever sent: the other person sees their own. each tap previews
// live behind the sheet; keep it to stay, back out to put the old one back.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atmosphere.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';

// what the sheet hands back when the person wants a photo of their own
// behind the chat instead of an atmosphere
class WallpaperFromPhotos {
  const WallpaperFromPhotos();
}

// an Atmo to keep, a WallpaperFromPhotos to go and pick one, or null
Future<Object?> showWallpaperSheet(
  BuildContext context,
  Atmo current, {
  ValueChanged<Atmo>? onPreview,
  bool allowPhoto = false,
}) {
  return showHaloSheet<Object>(
    context,
    scroll: true,
    builder: (ctx) =>
        _Picker(current: current, onPreview: onPreview, allowPhoto: allowPhoto),
  );
}

class _Picker extends StatefulWidget {
  final Atmo current;
  final ValueChanged<Atmo>? onPreview;
  final bool allowPhoto;
  const _Picker({
    required this.current,
    this.onPreview,
    this.allowPhoto = false,
  });
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late Atmo _pick = widget.current;

  void _choose(Atmo a) {
    HapticFeedback.selectionClick();
    setState(() => _pick = a);
    widget.onPreview?.call(a);
  }

  @override
  Widget build(BuildContext context) {
    final moods = Atmo.values.where(atmoIsMood).toList();
    final gradients = Atmo.values
        .where((a) => a != Atmo.none && !atmoIsPattern(a) && !atmoIsMood(a))
        .toList();
    final patterns = Atmo.values.where(atmoIsPattern).toList();
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 10),
              Text(
                'Atmosphere',
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Just for you. They see their own.',
                style: HaloType.sans(size: 12, color: HaloColors.text2),
              ),
              const SizedBox(height: 16),
              _Head('moods'),
              const SizedBox(height: 10),
              _Swatches(
                items: [Atmo.none, ...moods],
                current: _pick,
                onPick: _choose,
                from: 0,
              ),
              const SizedBox(height: 16),
              _Head('gradients'),
              const SizedBox(height: 10),
              _Swatches(
                items: gradients,
                current: _pick,
                onPick: _choose,
                from: 7,
              ),
              const SizedBox(height: 16),
              _Head('patterns'),
              const SizedBox(height: 10),
              _Swatches(
                items: patterns,
                current: _pick,
                onPick: _choose,
                from: 11,
              ),
              if (widget.allowPhoto) ...[
                const SizedBox(height: 16),
                _Head('your photo'),
                const SizedBox(height: 10),
                // a picture from the gallery, copied into the app's own
                // folder and drawn behind this chat only
                PressScale(
                  label: 'From your photos',
                  onTap: () =>
                      Navigator.pop(context, const WallpaperFromPhotos()),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: HaloColors.line),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_outlined,
                          size: 16,
                          color: HaloColors.text2,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'From your photos',
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PressScale(
                label: 'Keep it',
                onTap: () => Navigator.pop(context, _pick),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    'Keep it',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w600,
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
  final int from;
  const _Swatches({
    required this.items,
    required this.current,
    required this.onPick,
    required this.from,
  });

  Color _fill(Atmo a) {
    if (a == Atmo.none) return HaloColors.surface3;
    if (atmoIsPattern(a)) return HaloColors.surface2;
    final mood = moodOf(a);
    if (mood != null) {
      return Color.lerp(HaloColors.surface2, mood.base, 0.55)!;
    }
    return atmoAccent(a).withValues(alpha: 0.18);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: [
        for (final (i, a) in items.indexed)
          StaggerIn(
            index: from + i,
            child: GestureDetector(
              onTap: () => onPick(a),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _fill(a),
                      border: Border.all(
                        color: a == current
                            ? HaloColors.amber
                            : HaloColors.line,
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
                  SizedBox(
                    width: 62,
                    child: Text(
                      atmoLabel(a),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.mono(
                        size: 9.5,
                        color: a == current
                            ? HaloColors.amber
                            : HaloColors.text3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
