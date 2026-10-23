// SPDX-License-Identifier: GPL-3.0-or-later
// the plain app icons, drawn once here: the android launcher art and
// notification glyphs are written from this by tool/icon_art.dart, and the
// icon screen paints the same shapes. plain dart, so the tool runs it too.
// our own shapes and colours, like no phone's own app and no brand's

/// a shape on an icon's canvas: 108 units across for the launcher art,
/// 24 for a glyph
sealed class ArtShape {
  const ArtShape();
}

class ArtCircle extends ArtShape {
  final double cx, cy, r;
  final int color;
  const ArtCircle(this.cx, this.cy, this.r, this.color);
}

class ArtRect extends ArtShape {
  final double x, y, w, h, r;
  final int color;
  // outlined at this width when set, filled when null
  final double? stroke;
  const ArtRect(this.x, this.y, this.w, this.h, this.r, this.color, {this.stroke});
}

// round ends at both points
class ArtLine extends ArtShape {
  final double x1, y1, x2, y2, width;
  final int color;
  const ArtLine(this.x1, this.y1, this.x2, this.y2, this.width, this.color);
}

class IconArt {
  // the launcher's background layer
  final int background;
  // the launcher's foreground layer, on 108 units with the middle 66 safe
  final List<ArtShape> front;
  // one colour on 24 units: the notification icon, and scaled up, the
  // themed icon's layer
  final List<ArtShape> glyph;
  const IconArt({
    required this.background,
    required this.front,
    required this.glyph,
  });
}

const _white = 0xFFFFFFFF;

const notesArt = IconArt(
  background: 0xFFD9C9A3,
  front: [
    ArtRect(34, 29, 40, 50, 5, 0xFFFFF8EA),
    ArtLine(41, 41, 67, 41, 3.2, 0xFFA8956E),
    ArtLine(41, 49, 67, 49, 3.2, 0xFFA8956E),
    ArtLine(41, 57, 67, 57, 3.2, 0xFFA8956E),
    ArtLine(41, 65, 58, 65, 3.2, 0xFFA8956E),
  ],
  glyph: [
    ArtRect(5, 3, 14, 18, 2.2, _white, stroke: 1.8),
    ArtLine(8.5, 8, 15.5, 8, 1.6, _white),
    ArtLine(8.5, 11.5, 15.5, 11.5, 1.6, _white),
    ArtLine(8.5, 15, 13, 15, 1.6, _white),
  ],
);

const weatherArt = IconArt(
  background: 0xFF4A6A8A,
  front: [
    ArtCircle(60, 47, 11, 0xFFF4C25B),
    ArtCircle(44, 61, 10, 0xFFF2F5F8),
    ArtCircle(56, 57, 12, 0xFFF2F5F8),
    ArtCircle(67, 64, 8, 0xFFF2F5F8),
    ArtRect(34, 61, 41, 11, 5.5, 0xFFF2F5F8),
  ],
  glyph: [
    // apart from the cloud by a gap, or the two read as one shape
    ArtCircle(17.6, 6.2, 2.9, _white),
    ArtCircle(8, 15, 3.5, _white),
    ArtCircle(12.5, 13, 4.2, _white),
    ArtCircle(16.5, 16, 2.8, _white),
    ArtRect(4.5, 15, 14.8, 4.3, 2.15, _white),
  ],
);

const tasksArt = IconArt(
  background: 0xFF5F8268,
  front: [
    ArtRect(36, 32, 12, 12, 3, _white, stroke: 3),
    ArtLine(39.2, 38.2, 41.6, 40.6, 2.8, _white),
    ArtLine(41.6, 40.6, 45.2, 35.6, 2.8, _white),
    ArtLine(54, 38, 72, 38, 3.5, 0xFFE3ECE5),
    ArtRect(36, 48, 12, 12, 3, _white, stroke: 3),
    ArtLine(54, 54, 72, 54, 3.5, 0xFFE3ECE5),
    ArtRect(36, 64, 12, 12, 3, _white, stroke: 3),
    ArtLine(54, 70, 66, 70, 3.5, 0xFFE3ECE5),
  ],
  glyph: [
    ArtRect(4, 3, 4.6, 4.6, 1.1, _white, stroke: 1.4),
    ArtLine(5.3, 5.4, 6.1, 6.2, 1.2, _white),
    ArtLine(6.1, 6.2, 7.4, 4.5, 1.2, _white),
    ArtLine(12, 5.3, 20, 5.3, 1.8, _white),
    ArtRect(4, 9.5, 4.6, 4.6, 1.1, _white, stroke: 1.4),
    ArtLine(12, 11.8, 20, 11.8, 1.8, _white),
    ArtRect(4, 16, 4.6, 4.6, 1.1, _white, stroke: 1.4),
    ArtLine(12, 18.3, 17, 18.3, 1.8, _white),
  ],
);

const newsArt = IconArt(
  background: 0xFF3A3F45,
  front: [
    ArtRect(31, 32, 46, 44, 5, 0xFFF1EEE8),
    ArtLine(37, 40, 71, 40, 4, 0xFF3A3F45),
    ArtRect(37, 47, 14, 12, 2, 0xFFA9B1B9),
    ArtLine(56, 49, 71, 49, 2.6, 0xFF8D949C),
    ArtLine(56, 56, 71, 56, 2.6, 0xFF8D949C),
    ArtLine(37, 65, 71, 65, 2.6, 0xFF8D949C),
    ArtLine(37, 71, 62, 71, 2.6, 0xFF8D949C),
  ],
  glyph: [
    ArtRect(3.5, 4.5, 17, 15, 2, _white, stroke: 1.7),
    ArtLine(6.5, 8, 17.5, 8, 1.8, _white),
    ArtRect(6.3, 10.5, 4.5, 4, 0.8, _white),
    ArtLine(12.8, 11.3, 17.5, 11.3, 1.4, _white),
    ArtLine(12.8, 14, 17.5, 14, 1.4, _white),
    ArtLine(6.5, 17, 17.5, 17, 1.4, _white),
  ],
);

// kryfo's own icon keeps its art; with plain notifications its glyph is a
// dot, the ring being kryfo's mark
const dotGlyph = <ArtShape>[ArtCircle(12, 12, 5, _white)];

/// the plain icons by the name android and dart both call them
const plainArt = {
  'notes': notesArt,
  'weather': weatherArt,
  'tasks': tasksArt,
  'news': newsArt,
};
