// SPDX-License-Identifier: GPL-3.0-or-later
// the wallpaper picker for chats, groups and the default under appearance.
// kept in the encrypted db and never sent: the other person sees their own.
// taps preview live behind the sheet; backing out puts the old one back.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atmosphere.dart';
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime;
import '../widgets/halo_sheet.dart';
import '../widgets/halo_rows.dart' show HaloSection;
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../l10n/l10n.dart';

// what the sheet hands back when the person wants a photo of their own
// behind the chat instead of an atmosphere
class WallpaperFromPhotos {
  const WallpaperFromPhotos();
}

// what it hands back when the chat is to follow the default again
class WallpaperDefault {
  const WallpaperDefault();
}

// an Atmo to keep, a WallpaperFromPhotos to go and pick one, a
// WallpaperDefault, or null for no change. [allowDefault] offers the default
// first, [followsDefault] and [hasPhoto] say what is in use now
Future<Object?> showWallpaperSheet(
  BuildContext context,
  Atmo current, {
  ValueChanged<Atmo>? onPreview,
  VoidCallback? onPreviewDefault,
  bool allowPhoto = false,
  bool allowDefault = false,
  bool followsDefault = false,
  bool hasPhoto = false,
}) {
  return showHaloSheet<Object>(
    context,
    scroll: true,
    builder: (ctx) => _Picker(
      current: followsDefault && allowDefault
          ? const WallpaperDefault()
          : hasPhoto
          ? null
          : current,
      onPreview: onPreview,
      onPreviewDefault: onPreviewDefault,
      allowPhoto: allowPhoto,
      allowDefault: allowDefault,
    ),
  );
}

class _Picker extends StatefulWidget {
  // an Atmo, a WallpaperDefault, or null for the photo in use
  final Object? current;
  final ValueChanged<Atmo>? onPreview;
  final VoidCallback? onPreviewDefault;
  final bool allowPhoto;
  final bool allowDefault;
  const _Picker({
    required this.current,
    this.onPreview,
    this.onPreviewDefault,
    this.allowPhoto = false,
    this.allowDefault = false,
  });
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late Object? _pick = widget.current;

  // a null swatch is the default's
  void _choose(Atmo? a) {
    HapticFeedback.selectionClick();
    setState(() => _pick = a ?? const WallpaperDefault());
    if (a == null) {
      widget.onPreviewDefault?.call();
    } else {
      widget.onPreview?.call(a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moods = Atmo.values.where(atmoIsMood).toList();
    final gradients = Atmo.values
        .where((a) => a != Atmo.none && !atmoIsPattern(a) && !atmoIsMood(a))
        .toList();
    final patterns = Atmo.values.where(atmoIsPattern).toList();
    final cell = _cellWidth(context, widget.allowDefault);
    final current = _pick is WallpaperDefault ? null : _pick;
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
              HaloSection(l10n.wallpaperMoods, flush: true),
              _Swatches(
                items: [if (widget.allowDefault) null, Atmo.none, ...moods],
                current: current,
                defaultOn: _pick is WallpaperDefault,
                onPick: _choose,
                from: 0,
                cell: cell,
              ),
              HaloSection(l10n.wallpaperGradients, flush: true),
              _Swatches(
                items: gradients,
                current: current,
                onPick: _choose,
                from: 7,
                cell: cell,
              ),
              HaloSection(l10n.wallpaperPatterns, flush: true),
              _Swatches(
                items: patterns,
                current: current,
                onPick: _choose,
                from: 11,
                cell: cell,
              ),
              if (widget.allowPhoto) ...[
                HaloSection(l10n.wallpaperYourPhoto, flush: true),
                // a picture from the gallery, copied into the app's own
                // folder and drawn behind this chat only
                PressScale(
                  label: l10n.wallpaperFromYourPhotos,
                  onTap: () =>
                      Navigator.pop(context, const WallpaperFromPhotos()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // the photo in use
                      border: Border.all(
                        color: _pick == null
                            ? HaloColors.amber
                            : HaloColors.line,
                        width: _pick == null ? 1.5 : 1,
                      ),
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

// the widest word of any name, at least 62: names wrap, words never break
double _cellWidth(BuildContext context, bool withDefault) {
  final scaler = MediaQuery.textScalerOf(context);
  final dir = Directionality.of(context);
  var w = 62.0;
  for (final name in [
    if (withDefault) l10n.wallpaperDefault,
    for (final a in Atmo.values) atmoLabel(a),
  ]) {
    final p = TextPainter(
      text: TextSpan(text: name, style: _Swatch.label(HaloColors.text2)),
      textDirection: dir,
      textScaler: scaler,
    )..layout();
    w = math.max(w, p.minIntrinsicWidth.ceilToDouble());
    p.dispose();
  }
  return w;
}

class _Swatches extends StatelessWidget {
  // null is the default's
  final List<Atmo?> items;
  final Object? current;
  final bool defaultOn;
  final ValueChanged<Atmo?> onPick;
  final int from;
  final double cell;
  const _Swatches({
    required this.items,
    required this.current,
    this.defaultOn = false,
    required this.onPick,
    required this.from,
    required this.cell,
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
            child: _Swatch(
              atmo: a,
              on: a == null ? defaultOn : a == current,
              width: cell,
              onTap: () => onPick(a),
            ),
          ),
      ],
    );
  }
}

// one atmosphere as a small round of itself: its gradient, its mood's tint
// or its pattern, and null the default. the one in use wears an amber ring
// a gap away and a tick that pop in on the house spring; with reduced motion
// they only fade
class _Swatch extends StatelessWidget {
  final Atmo? atmo;
  final bool on;
  final double width;
  final VoidCallback onTap;
  const _Swatch({
    required this.atmo,
    required this.on,
    required this.width,
    required this.onTap,
  });

  static const _size = 46.0;

  static TextStyle label(Color color) => HaloType.mono(size: 9.5, color: color);

  String get _name => atmo == null ? l10n.wallpaperDefault : atmoLabel(atmo!);

  Decoration _face() {
    final a = atmo;
    if (a == null) {
      return BoxDecoration(shape: BoxShape.circle, color: HaloColors.surface2);
    }
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
      label: _name,
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
                    child: atmo == null
                        ? Icon(
                            Icons.wallpaper_outlined,
                            size: 17,
                            color: HaloColors.text2,
                          )
                        : atmo == Atmo.none
                        ? Icon(
                            Icons.not_interested,
                            size: 16,
                            color: HaloColors.text2,
                          )
                        : atmoIsPattern(atmo!)
                        ? CustomPaint(
                            size: const Size(_size, _size),
                            painter: PatternPainter(atmo!, scale: 0.55),
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
              width: width,
              child: Text(
                _name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: label(on ? HaloColors.amber : HaloColors.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
