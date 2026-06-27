// halo_avatar.dart - procedural avatar from a seed string.
// gradient background, large italic serif initial, thin divider,
// and a 3-letter mono tag below. seed-driven palette so identical
// halo ids produce identical avatars across devices.

import 'package:flutter/material.dart';
import '../theme.dart';

class HaloAvatar extends StatelessWidget {
  final String seed;
  final double size;
  const HaloAvatar({super.key, required this.seed, required this.size});

  @override
  Widget build(BuildContext context) {
    final b = _seedBytes(seed);
    final palette = _palettes[b[0] % _palettes.length];

    final parts = seed.split('-');
    final letter = (parts.isNotEmpty && parts[0].isNotEmpty)
        ? parts[0][0].toUpperCase()
        : '?';
    // first letter of each of the first three words ("TBB" for thumb-behave-boring)
    final tag = List<int>.generate(3, (i) => i)
        .map(
          (i) => (i < parts.length && parts[i].isNotEmpty)
              ? parts[i][0].toUpperCase()
              : '',
        )
        .join();

    // show the divider + tag only when the avatar is large enough to be
    // legible. small ones get a clean drop-cap look.
    final showFrame = size >= 40;

    return ClipOval(
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
                  color: palette.mark.withOpacity(0.7),
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
    );
  }
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
  while (out.length < 16) out.add(0);
  return out;
}
