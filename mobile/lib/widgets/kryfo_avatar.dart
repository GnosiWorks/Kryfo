// SPDX-License-Identifier: GPL-3.0-or-later
// avatar drawn from a seed string, or from a chosen face. the palette comes
// from the seed, so the same id draws the same avatar on every phone.

import 'package:flutter/material.dart';
import '../theme.dart';
import 'avatar_mark.dart';

// how many distinct avatars exist
int get avatarChoiceCount => _palettes.length * markCount * rotCount;
int get avatarPaletteCount => _palettes.length;

class KryfoAvatar extends StatelessWidget {
  final String seed;
  final double size;
  // null draws the seed's palette and serif initial. anything else is a
  // chosen face, packed in one int.
  final int? choice;
  const KryfoAvatar({
    super.key,
    required this.seed,
    required this.size,
    this.choice,
  });

  // a picture: its letters are drawn from the id, and a screen reader that
  // read them out would announce a name nobody gave
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: _draw());

  Widget _draw() {
    if (choice != null) return _markedAvatar(choice!, size);
    final b = _seedBytes(seed);
    final palette = _palettes[b[0] % _palettes.length];

    final parts = seed.split('-');
    final letter = (parts.isNotEmpty && parts[0].isNotEmpty)
        ? parts[0][0].toUpperCase()
        : '?';
    // first letters of the first three words: "TBB" for thumb-behave-boring
    final tag = List<int>.generate(3, (i) => i)
        .map(
          (i) => (i < parts.length && parts[i].isNotEmpty)
              ? parts[i][0].toUpperCase()
              : '',
        )
        .join();

    // divider and tag only when the avatar is large enough to read them
    final showFrame = size >= 40;

    // the letters are part of the drawing, sized to the circle: the phone's
    // font size would push the initial into the tag
    return MediaQuery.withNoTextScaling(
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.start, palette.end],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // serif initial, slightly above center to leave room for the tag
              Positioned(
                top: showFrame ? size * 0.14 : null,
                child: Text(
                  letter,
                  style: HaloType.serif(
                    size: size * (showFrame ? 0.52 : 0.46),
                    weight: FontWeight.w500,
                    italic: true,
                    color: palette.ink,
                    height: 1.0,
                  ),
                ),
              ),
              if (showFrame) ...[
                Positioned(
                  bottom: size * 0.27,
                  child: Container(
                    width: size * 0.30,
                    height: 0.7,
                    color: palette.mark.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  bottom: size * 0.12,
                  child: Text(
                    tag,
                    style: HaloType.mono(
                      size: size * 0.105,
                      color: palette.mark,
                      letter: size * 0.025,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// a choice is one int: palette, mark and rotation packed together

Widget _markedAvatar(int ch, double size) {
  final rot = ch % rotCount;
  final mark = (ch ~/ rotCount) % markCount;
  final pal = _palettes[(ch ~/ (rotCount * markCount)) % _palettes.length];
  return ClipOval(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pal.start, pal.end],
        ),
      ),
      child: CustomPaint(
        painter: AvatarMarkPainter(mark: mark, rot: rot, color: pal.ink),
        size: Size.square(size),
      ),
    ),
  );
}

class _Palette {
  final Color start;
  final Color end;
  // ink = the letter color. high contrast on the gradient.
  final Color ink;
  // mark = accent color used for the divider and tag.
  final Color mark;
  const _Palette(this.start, this.end, this.ink, this.mark);
}

List<_Palette> get _palettes => <_Palette>[
  // dark-bg palettes - cream letter, varied tag accents
  _Palette(
    HaloColors.ink,
    HaloColors.amberDeep,
    HaloColors.text,
    HaloColors.amber,
  ),
  _Palette(
    HaloColors.ink,
    HaloColors.violet,
    HaloColors.text,
    HaloColors.amber,
  ),
  _Palette(HaloColors.ink, HaloColors.rose, HaloColors.text, HaloColors.green),
  _Palette(HaloColors.ink, HaloColors.green, HaloColors.text, HaloColors.amber),
  _Palette(HaloColors.ink, HaloColors.amber, HaloColors.text, HaloColors.rose),
  _Palette(
    HaloColors.ink,
    HaloColors.violet,
    HaloColors.text,
    HaloColors.green,
  ),
  _Palette(
    HaloColors.ink,
    HaloColors.green,
    HaloColors.text,
    HaloColors.violet,
  ),
  _Palette(HaloColors.ink, HaloColors.rose, HaloColors.text, HaloColors.violet),
  _Palette(
    HaloColors.surface3,
    HaloColors.violet,
    HaloColors.text,
    HaloColors.rose,
  ),
  _Palette(
    HaloColors.surface3,
    HaloColors.amberDeep,
    HaloColors.text,
    HaloColors.green,
  ),
  _Palette(
    HaloColors.surface3,
    HaloColors.rose,
    HaloColors.text,
    HaloColors.amber,
  ),
  _Palette(
    HaloColors.line2,
    HaloColors.amberDeep,
    HaloColors.text,
    HaloColors.violet,
  ),
  _Palette(
    HaloColors.line2,
    HaloColors.green,
    HaloColors.text,
    HaloColors.rose,
  ),
  // bright palettes - ink letter, cream/dark tag
  _Palette(
    HaloColors.amberDeep,
    HaloColors.rose,
    HaloColors.ink,
    HaloColors.text,
  ),
  _Palette(HaloColors.amber, HaloColors.rose, HaloColors.ink, HaloColors.text),
  _Palette(
    HaloColors.amber,
    HaloColors.violet,
    HaloColors.ink,
    HaloColors.text,
  ),
  _Palette(
    HaloColors.amberDeep,
    HaloColors.violet,
    HaloColors.ink,
    HaloColors.text,
  ),
  _Palette(HaloColors.violet, HaloColors.rose, HaloColors.ink, HaloColors.text),
  _Palette(
    HaloColors.violet,
    HaloColors.amber,
    HaloColors.ink,
    HaloColors.text,
  ),
  _Palette(HaloColors.green, HaloColors.amber, HaloColors.ink, HaloColors.text),
  _Palette(HaloColors.amber, HaloColors.green, HaloColors.ink, HaloColors.text),
  _Palette(HaloColors.green, HaloColors.rose, HaloColors.ink, HaloColors.text),
  _Palette(HaloColors.rose, HaloColors.green, HaloColors.ink, HaloColors.text),
  _Palette(
    HaloColors.green,
    HaloColors.violet,
    HaloColors.ink,
    HaloColors.text,
  ),
];

// FNV-1a-like rolling mix produces a stable byte stream from a string.
List<int> _seedBytes(String s) {
  final out = <int>[];
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
    out.add(h & 0xFF);
    out.add((h >> 8) & 0xFF);
    out.add((h >> 16) & 0xFF);
    out.add((h >> 24) & 0xFF);
  }
  while (out.length < 16) {
    out.add(0);
  }
  return out;
}
