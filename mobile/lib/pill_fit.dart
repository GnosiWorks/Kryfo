// SPDX-License-Identifier: GPL-3.0-or-later
// the home pill's words in the room the header leaves them: at the reader's
// text size where they fit, smaller only down to the smallest text the
// header uses, on two lines at most, broken between words, never inside
// one. a phrase that still does not fit takes its short form
import 'package:flutter/widgets.dart';

/// the smallest the pill's words are drawn, the header's own smallest text
const kPillMinPx = 9.5;

/// the pill's words at their size: 11, grown with large text to this
const kPillMaxScale = 1.15;

const kPillPx = 11.0;

@immutable
class PillFit {
  const PillFit(this.text, this.scale, {required this.fits});
  final String text;

  /// the factor on [kPillPx] the words are drawn at
  final double scale;

  /// false only when not even the short form fits at [kPillMinPx]
  final bool fits;

  double get px => kPillPx * scale;
}

final _fits =
    <(String, String?, double, double, TextDirection, int), PillFit>{};

/// the words and size for [text] (and its [short] form, when there is one)
/// in [room] logical pixels, for a reader whose text scale is [userScale].
/// [style] carries the font, not the colour. kept per input: the pill asks
/// every frame its dot pulses
PillFit fitPill({
  required String text,
  String? short,
  required TextStyle style,
  required double room,
  required double userScale,
  required TextDirection direction,
}) {
  final key = (text, short, room, userScale, direction, style.hashCode);
  final kept = _fits[key];
  if (kept != null) return kept;
  if (_fits.length > 256) _fits.clear();
  final top = userScale.clamp(1.0, kPillMaxScale);
  const least = kPillMinPx / kPillPx;
  PillFit? at(String words) {
    for (var s = top; s >= least - 1e-9; s -= 0.01) {
      if (_fitsAt(words, style, room, s, direction)) {
        return PillFit(words, s, fits: true);
      }
    }
    return null;
  }

  final fit =
      at(text) ??
      (short == null ? null : at(short)) ??
      PillFit(short ?? text, least, fits: false);
  return _fits[key] = fit;
}

bool _fitsAt(
  String words,
  TextStyle style,
  double room,
  double scale,
  TextDirection direction,
) {
  final scaler = TextScaler.linear(scale);
  // every word on a line of its own width
  for (final w in words.split(' ')) {
    final p = TextPainter(
      text: TextSpan(text: w, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    final wide = p.width > room;
    p.dispose();
    if (wide) return false;
  }
  final p = TextPainter(
    text: TextSpan(text: words, style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 2,
  )..layout(maxWidth: room);
  final over = p.didExceedMaxLines;
  p.dispose();
  return !over;
}
