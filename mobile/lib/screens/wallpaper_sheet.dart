// SPDX-License-Identifier: GPL-3.0-or-later
// the atmosphere picker for chats and groups. kept in the encrypted db and
// never sent: the other person sees their own. taps preview live behind the
// sheet; backing out puts the old one back.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atmosphere.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime;
import '../widgets/halo_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../l10n/l10n.dart';

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
                l10n.wallpaperAtmosphere,
                style: HaloType.serif(size: 18, color: HaloColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.wallpaperJustForYouThey,
                style: HaloType.sans(size: 12, color: HaloColors.text2),
              ),
              const SizedBox(height: 16),
              _Head(l10n.wallpaperMoods),
              const SizedBox(height: 10),
              _Swatches(
                items: [Atmo.none, ...moods],
                current: _pick,
                onPick: _choose,
                from: 0,
              ),
              const SizedBox(height: 16),
              _Head(l10n.wallpaperGradients),
              const SizedBox(height: 10),
              _Swatches(
                items: gradients,
                current: _pick,
                onPick: _choose,
                from: 7,
              ),
              const SizedBox(height: 16),
              _Head(l10n.wallpaperPatterns),
              const SizedBox(height: 10),
              _Swatches(
                items: patterns,
                current: _pick,
                onPick: _choose,
                from: 11,
              ),
              if (widget.allowPhoto) ...[
                const SizedBox(height: 16),
                _Head(l10n.wallpaperYourPhoto),
                const SizedBox(height: 10),
                // a picture from the gallery, copied into the app's own
                // folder and drawn behind this chat only
                PressScale(
                  label: l10n.wallpaperFromYourPhotos,
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
                          l10n.wallpaperFromYourPhotos,
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
                label: l10n.wallpaperKeepIt,
                onTap: () => Navigator.pop(context, _pick),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    l10n.wallpaperKeepIt,
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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: [
        for (final (i, a) in items.indexed)
          StaggerIn(
            index: from + i,
            child: _Swatch(atmo: a, on: a == current, onTap: () => onPick(a)),
          ),
      ],
    );
  }
}

// one atmosphere as a small round of itself: its gradient, its mood's tint
// or its pattern. the one in use wears an amber ring a gap away and a tick
// that pop in on the house spring; with less movement they only fade
class _Swatch extends StatelessWidget {
  final Atmo atmo;
  final bool on;
  final VoidCallback onTap;
  const _Swatch({required this.atmo, required this.on, required this.onTap});

  static const _size = 46.0;

  Decoration _face() {
    final a = atmo;
    if (a == Atmo.none) {
      return BoxDecoration(shape: BoxShape.circle, color: HaloColors.surface3);
    }
    if (atmoIsPattern(a)) {
      return BoxDecoration(shape: BoxShape.circle, color: HaloColors.surface2);
    }
    final mood = moodOf(a);
    if (mood != null) {
      final tint = Color.lerp(HaloColors.surface2, mood.base, 0.55)!;
      // lit from the top corner, the way the room's light falls
      return BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.5, -0.6),
          radius: 1.1,
          colors: [Color.lerp(tint, HaloColors.text, 0.12)!, tint],
        ),
      );
    }
    final accent = atmoAccent(a);
    final deep = Color.lerp(accent, HaloColors.ink, 0.55)!;
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.55),
          Color.lerp(accent, deep, 0.5)!.withValues(alpha: 0.35),
          deep.withValues(alpha: 0.5),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final spring = still ? Duration.zero : kHouseTime;
    return Semantics(
      button: true,
      selected: on,
      label: atmoLabel(atmo),
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.92,
        // the sheet clicks for the pick itself
        haptic: false,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: _size + 8,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // the ring, a gap away from the round
                  AnimatedOpacity(
                    opacity: on ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: AnimatedScale(
                      scale: on || still ? 1 : 0.86,
                      duration: spring,
                      curve: kHouseCurve,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: HaloColors.amber,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: _size,
                    height: _size,
                    decoration: _face(),
                    foregroundDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: HaloColors.line, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: atmo == Atmo.none
                        ? Icon(
                            Icons.not_interested,
                            size: 16,
                            color: HaloColors.text3,
                          )
                        : atmoIsPattern(atmo)
                        ? CustomPaint(
                            size: const Size(_size, _size),
                            painter: PatternPainter(atmo, scale: 0.55),
                          )
                        : null,
                  ),
                  // the tick, at the round's lower end
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: AnimatedScale(
                        scale: on || still ? 1 : 0.3,
                        duration: spring,
                        curve: kHouseCurve,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HaloColors.amber,
                            border: Border.all(
                              color: HaloColors.surface2,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: HaloColors.onAmber,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 62,
              child: Text(
                atmoLabel(atmo),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.mono(
                  size: 9.5,
                  color: on ? HaloColors.amber : HaloColors.text3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
