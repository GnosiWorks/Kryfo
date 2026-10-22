// SPDX-License-Identifier: GPL-3.0-or-later
// simplified chinese into traditional, for readers of traditional: the
// models write simplified only. opencc's s2t tables (apache 2.0, in
// assets/opencc), the longest phrase first, then each character, as
// opencc does.
import 'dart:convert' show utf8;
import 'dart:io' show gzip;

import 'package:flutter/services.dart';

class HantConverter {
  final Map<String, String> _phrases;
  final Map<int, String> _chars;
  final int _longest;
  HantConverter._(this._phrases, this._chars, this._longest);

  // the tables as opencc writes them: "from<tab>to [other...]" a line, the
  // first form is the one used
  factory HantConverter.parse(String chars, String phrases) {
    final c = <int, String>{};
    for (final (k, v) in _lines(chars)) {
      final r = k.runes;
      if (r.length == 1) c[r.first] = v;
    }
    final p = <String, String>{};
    var longest = 1;
    for (final (k, v) in _lines(phrases)) {
      final n = k.runes.length;
      if (n < 2) continue;
      p[k] = v;
      if (n > longest) longest = n;
    }
    return HantConverter._(p, c, longest);
  }

  static Iterable<(String, String)> _lines(String s) sync* {
    for (final line in s.split('\n')) {
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      final to = line.substring(tab + 1).split(' ').first.trim();
      if (to.isNotEmpty) yield (line.substring(0, tab), to);
    }
  }

  static const charsAsset = 'assets/opencc/STCharacters.txt.gz';
  static const phrasesAsset = 'assets/opencc/STPhrases.txt.gz';

  static Future<HantConverter> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<String> read(String a) async {
      final d = await b.load(a);
      return utf8.decode(
        gzip.decode(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes)),
      );
    }

    return HantConverter.parse(
      await read(charsAsset),
      await read(phrasesAsset),
    );
  }

  String convert(String s) {
    final r = s.runes.toList();
    final out = StringBuffer();
    var i = 0;
    while (i < r.length) {
      var took = 0;
      for (
        var n = _longest < r.length - i ? _longest : r.length - i;
        n >= 2;
        n--
      ) {
        final hit = _phrases[String.fromCharCodes(r, i, i + n)];
        if (hit != null) {
          out.write(hit);
          took = n;
          break;
        }
      }
      if (took == 0) {
        final c = r[i];
        out.write(_chars[c] ?? String.fromCharCode(c));
        took = 1;
      }
      i += took;
    }
    return out.toString();
  }
}
