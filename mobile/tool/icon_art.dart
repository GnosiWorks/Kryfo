// SPDX-License-Identifier: GPL-3.0-or-later
// writes the plain app icons' android art from lib/app_icon_art.dart: the
// adaptive icon (background, foreground, themed layer), a full icon for
// android 7, and the notification glyphs. a test checks the files match.
//
// usage: dart run tool/icon_art.dart   (from mobile/, after the art changes)
import 'dart:io';

import 'package:kryfo/app_icon_art.dart';

const res = 'android/app/src/main/res';

String _n(double v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.')
      ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : s;
}

String _hex(int argb) =>
    '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

String _rectPath(ArtRect s) {
  final r = s.r, w = s.w - 2 * r, h = s.h - 2 * r;
  return 'M${_n(s.x + r)},${_n(s.y)} h${_n(w)} '
      'a${_n(r)},${_n(r)} 0 0 1 ${_n(r)},${_n(r)} v${_n(h)} '
      'a${_n(r)},${_n(r)} 0 0 1 ${_n(-r)},${_n(r)} h${_n(-w)} '
      'a${_n(r)},${_n(r)} 0 0 1 ${_n(-r)},${_n(-r)} v${_n(-h)} '
      'a${_n(r)},${_n(r)} 0 0 1 ${_n(r)},${_n(-r)} z';
}

String _path(ArtShape s, String pad) => switch (s) {
  ArtCircle c =>
    '$pad<path\n'
        '$pad    android:fillColor="${_hex(c.color)}"\n'
        '$pad    android:pathData="M${_n(c.cx - c.r)},${_n(c.cy)} '
        'a${_n(c.r)},${_n(c.r)} 0 1,0 ${_n(2 * c.r)},0 '
        'a${_n(c.r)},${_n(c.r)} 0 1,0 ${_n(-2 * c.r)},0 z" />',
  ArtRect r when r.stroke == null =>
    '$pad<path\n'
        '$pad    android:fillColor="${_hex(r.color)}"\n'
        '$pad    android:pathData="${_rectPath(r)}" />',
  ArtRect r =>
    '$pad<path\n'
        '$pad    android:strokeColor="${_hex(r.color)}"\n'
        '$pad    android:strokeWidth="${_n(r.stroke!)}"\n'
        '$pad    android:pathData="${_rectPath(r)}" />',
  ArtLine l =>
    '$pad<path\n'
        '$pad    android:strokeColor="${_hex(l.color)}"\n'
        '$pad    android:strokeWidth="${_n(l.width)}"\n'
        '$pad    android:strokeLineCap="round"\n'
        '$pad    android:pathData="M${_n(l.x1)},${_n(l.y1)} '
        'L${_n(l.x2)},${_n(l.y2)}" />',
};

const _head = '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!-- written by tool/icon_art.dart from lib/app_icon_art.dart -->\n';

String _vector({
  required double size,
  required double viewport,
  required List<String> body,
}) =>
    '$_head<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="${_n(size)}dp"\n'
    '    android:height="${_n(size)}dp"\n'
    '    android:viewportWidth="${_n(viewport)}"\n'
    '    android:viewportHeight="${_n(viewport)}">\n'
    '${body.join('\n')}\n'
    '</vector>\n';

String _group(List<ArtShape> shapes, {double scale = 1, double shift = 0}) {
  final open = '    <group\n'
      '        android:scaleX="${_n(scale)}"\n'
      '        android:scaleY="${_n(scale)}"\n'
      '        android:translateX="${_n(shift)}"\n'
      '        android:translateY="${_n(shift)}">';
  return [open, for (final s in shapes) _path(s, '        '), '    </group>']
      .join('\n');
}

// the glyph on the themed layer: 44 units across, in the middle of 108
const _monoScale = 44 / 24;
const _monoShift = (108 - 44) / 2;

/// every file the art makes, by its path under mobile/
Map<String, String> artFiles() {
  final out = <String, String>{};
  for (final MapEntry(key: name, value: art) in plainArt.entries) {
    final id = 'ic_icon_$name';
    out['$res/drawable/${id}_front.xml'] = _vector(
      size: 108,
      viewport: 108,
      body: [for (final s in art.front) _path(s, '    ')],
    );
    out['$res/drawable/${id}_mono.xml'] = _vector(
      size: 108,
      viewport: 108,
      body: [_group(art.glyph, scale: _monoScale, shift: _monoShift)],
    );
    out['$res/mipmap-anydpi-v26/$id.xml'] =
        '$_head<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/${id}_bg"/>\n'
        '    <foreground android:drawable="@drawable/${id}_front"/>\n'
        '    <monochrome android:drawable="@drawable/${id}_mono"/>\n'
        '</adaptive-icon>\n';
    // android 7 has no adaptive icons: the middle 72 of the canvas on a
    // rounded square of the background
    out['$res/mipmap/$id.xml'] = _vector(
      size: 48,
      viewport: 72,
      body: [
        _group([
          ArtRect(18, 18, 72, 72, 16, art.background),
          ...art.front,
        ], shift: -18),
      ],
    );
    out['$res/drawable/ic_plain_$name.xml'] = _vector(
      size: 24,
      viewport: 24,
      body: [for (final s in art.glyph) _path(s, '    ')],
    );
  }
  out['$res/drawable/ic_plain_dot.xml'] = _vector(
    size: 24,
    viewport: 24,
    body: [for (final s in dotGlyph) _path(s, '    ')],
  );
  out['$res/values/icon_art.xml'] =
      '$_head<resources>\n'
      '${[for (final e in plainArt.entries) '    <color name="ic_icon_${e.key}_bg">${_hex(e.value.background)}</color>'].join('\n')}\n'
      '</resources>\n';
  return out;
}

void main() {
  for (final e in artFiles().entries) {
    File(e.key)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(e.value);
    stdout.writeln(e.key);
  }
}
