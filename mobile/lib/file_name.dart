// SPDX-License-Identifier: GPL-3.0-or-later
// a file's name as kryfo shows it, saves it and hands it on: one name for
// all three. what hides what a name says goes (direction marks, invisible
// fillers, joiners outside the scripts that need them), letters are put in
// one composed form, and the last extension is the only one
import 'dart:convert' show utf8;

import 'package:flutter/widgets.dart' show StringCharacters;

import 'bidi_safe.dart';
import 'compose_table.dart';

// characters that hide what a name says or break it on another system
bool _hidden(int r) =>
    r < 0x20 ||
    (r >= 0x7F && r <= 0x9F) ||
    r == 0xAD ||
    r == 0x034F ||
    r == 0x115F ||
    r == 0x1160 ||
    r == 0x180E ||
    r == 0x200B ||
    r == 0x2028 ||
    r == 0x2029 ||
    (r >= 0x2060 && r <= 0x2064) ||
    r == 0x2800 ||
    r == 0x3164 ||
    (r >= 0xFE00 && r <= 0xFE0F) ||
    r == 0xFEFF ||
    r == 0xFFA0 ||
    (r >= 0xFFF9 && r <= 0xFFFB) ||
    (r >= 0xE0000 && r <= 0xE007F) ||
    (r >= 0xE0100 && r <= 0xE01EF);

const _zwnj = 0x200C;
const _zwj = 0x200D;

// the scripts whose letters a joiner changes: arabic, syriac, nko,
// mongolian and the indic ones
bool _joins(int r) =>
    (r >= 0x0600 && r <= 0x08FF) ||
    (r >= 0x0900 && r <= 0x0DFF) ||
    (r >= 0x1800 && r <= 0x18AF) ||
    (r >= 0xFB50 && r <= 0xFDFF) ||
    (r >= 0xFE70 && r <= 0xFEFC);

bool _mark(int r) =>
    (r >= 0x0300 && r <= 0x036F) ||
    (r >= 0x1AB0 && r <= 0x1AFF) ||
    (r >= 0x1DC0 && r <= 0x1DFF) ||
    (r >= 0x20D0 && r <= 0x20FF) ||
    (r >= 0xFE20 && r <= 0xFE2F);

final Map<int, int> _compose = () {
  final m = <int, int>{};
  for (var i = 0; i + 2 < kComposePairs.length; i += 3) {
    m[kComposePairs[i] << 16 | kComposePairs[i + 1]] = kComposePairs[i + 2];
  }
  return m;
}();

/// [runes] composed the way nfc composes them: a letter and the marks after
/// it become one where unicode has one, hangul jamo by rule
List<int> composed(List<int> runes) {
  final out = <int>[];
  for (final r in runes) {
    if (out.isNotEmpty) {
      final last = out.last;
      // hangul: a leading consonant and a vowel, then a trailing consonant
      if (last >= 0x1100 && last <= 0x1112 && r >= 0x1161 && r <= 0x1175) {
        out.last = 0xAC00 + ((last - 0x1100) * 21 + (r - 0x1161)) * 28;
        continue;
      }
      if (last >= 0xAC00 &&
          last <= 0xD7A3 &&
          (last - 0xAC00) % 28 == 0 &&
          r > 0x11A7 &&
          r <= 0x11C2) {
        out.last = last + (r - 0x11A7);
        continue;
      }
      if (r < 0x10000 && last < 0x10000) {
        final c = _compose[last << 16 | r];
        if (c != null) {
          out.last = c;
          continue;
        }
      }
    }
    out.add(r);
  }
  return out;
}

/// [name] with nothing hidden in it and its letters composed, the rest as
/// the sender wrote it
String shownFileName(String? name) {
  final rs = unmarked(name ?? '').runes.where((r) => !_hidden(r)).toList();
  final kept = <int>[];
  for (var i = 0; i < rs.length; i++) {
    final r = rs[i];
    if (r == _zwj || r == _zwnj) {
      final before = kept.isEmpty ? -1 : kept.last;
      final after = i + 1 < rs.length ? rs[i + 1] : -1;
      if (!_joins(before) || !_joins(after)) continue;
    }
    kept.add(r);
  }
  final s = String.fromCharCodes(composed(kept)).trim();
  return s.isEmpty ? 'file' : s;
}

const _reserved = r'/\:*?"<>|';

final _extShape = RegExp(r'^[A-Za-z0-9]{1,10}$');

String _noMarks(String s) =>
    String.fromCharCodes(s.runes.where((r) => !_mark(r)));

int _bytes(String s) => utf8.encode(s).length;

/// a name fit to show, save or hand to another app: nothing hidden, no
/// folder, no leading dot, no mark on or just before the extension, one
/// extension only (photo.jpg.apk is photo_jpg.apk), at most [maxBytes] of
/// utf-8 cut between whole letters. [installerExt] is the extension an app
/// installer must end in when its name does not say so, [isExt] the
/// extensions a double one is folded for
String cleanFileName(
  String? name, {
  String? installerExt,
  required bool Function(String ext) isExt,
  required bool Function(String ext) isInstallerExt,
  int maxBytes = 200,
}) {
  var s = String.fromCharCodes(
    shownFileName(
      name,
    ).runes.map((r) => _reserved.contains(String.fromCharCode(r)) ? 0x5F : r),
  );
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');
  if (s.isEmpty) s = 'file';
  var stem = s;
  var ext = '';
  final dot = s.lastIndexOf('.');
  if (dot > 0) {
    final e = _noMarks(s.substring(dot + 1));
    if (_extShape.hasMatch(e)) {
      stem = s.substring(0, dot);
      ext = e;
      // a mark right before the dot reads as part of the extension
      final rs = stem.runes.toList();
      while (rs.isNotEmpty && _mark(rs.last)) {
        rs.removeLast();
      }
      stem = String.fromCharCodes(rs);
    }
  }
  final parts = stem.split('.');
  final b = StringBuffer(parts.first);
  for (final p in parts.skip(1)) {
    b
      ..write(isExt(_noMarks(p).toLowerCase()) ? '_' : '.')
      ..write(p);
  }
  stem = b.toString();
  if (installerExt != null && !isInstallerExt(ext.toLowerCase())) {
    if (ext.isNotEmpty) stem = '${stem}_$ext';
    ext = installerExt;
  }
  final tail = ext.isEmpty ? '' : '.$ext';
  final room = maxBytes - _bytes(tail);
  if (_bytes(stem) > room) {
    final cut = StringBuffer();
    var used = 0;
    for (final g in stem.characters) {
      final n = _bytes(g);
      if (used + n > room) break;
      cut.write(g);
      used += n;
    }
    stem = cut.toString();
  }
  stem = stem.replaceAll(RegExp(r'[\s.]+$'), '');
  if (stem.isEmpty) stem = 'file';
  return '$stem$tail';
}
