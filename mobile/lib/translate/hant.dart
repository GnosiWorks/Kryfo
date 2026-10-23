// SPDX-License-Identifier: GPL-3.0-or-later
// simplified chinese into traditional, for readers of traditional: the
// models write simplified only. opencc's tables (apache 2.0, in
// assets/opencc): s2t, the longest phrase first, then each character, then
// taiwan's or hong kong's variants, as opencc's s2tw and s2hk do.
import 'dart:convert' show utf8;
import 'dart:io' show gzip;

import 'package:flutter/services.dart';

// which traditional forms a reader uses: taiwan's, as the app's own
// traditional strings do, or hong kong's
enum HantForm { none, tw, hk }

// one opencc table: the longest match wins, a character alone last
class _Table {
  final Map<String, String> words;
  final Map<int, String> chars;
  final int longest;
  _Table(this.words, this.chars, this.longest);

  factory _Table.parse(Iterable<String> texts) {
    final w = <String, String>{};
    final c = <int, String>{};
    var longest = 1;
    for (final t in texts) {
      for (final (k, v) in _lines(t)) {
        final r = k.runes;
        if (r.length == 1) {
          c[r.first] = v;
        } else {
          w[k] = v;
          if (r.length > longest) longest = r.length;
        }
      }
    }
    return _Table(w, c, longest);
  }

  String convert(String s) {
    final r = s.runes.toList();
    final out = StringBuffer();
    var i = 0;
    while (i < r.length) {
      var took = 0;
      for (
        var n = longest < r.length - i ? longest : r.length - i;
        n >= 2;
        n--
      ) {
        final hit = words[String.fromCharCodes(r, i, i + n)];
        if (hit != null) {
          out.write(hit);
          took = n;
          break;
        }
      }
      if (took == 0) {
        final c = r[i];
        out.write(chars[c] ?? String.fromCharCode(c));
        took = 1;
      }
      i += took;
    }
    return out.toString();
  }
}

// the tables as opencc writes them: "from<tab>to [other...]" a line, the
// first form is the one used
Iterable<(String, String)> _lines(String s) sync* {
  for (final line in s.split('\n')) {
    final tab = line.indexOf('\t');
    if (tab <= 0) continue;
    final to = line.substring(tab + 1).split(' ').first.trim();
    if (to.isNotEmpty) yield (line.substring(0, tab), to);
  }
}

class HantConverter {
  final _Table _s2t;
  final _Table _tw;
  final _Table _hk;
  HantConverter._(this._s2t, this._tw, this._hk);

  // s2t's two tables, then each place's variants, as opencc's s2tw and
  // s2hk chain them
  factory HantConverter.parse(
    String chars,
    String phrases, {
    String tw = '',
    String hk = '',
  }) => HantConverter._(
    _Table.parse([chars, phrases]),
    _Table.parse([tw]),
    _Table.parse([hk]),
  );

  static const charsAsset = 'assets/opencc/STCharacters.txt.gz';
  static const phrasesAsset = 'assets/opencc/STPhrases.txt.gz';
  static const twAsset = 'assets/opencc/TWVariants.txt.gz';
  static const hkAsset = 'assets/opencc/HKVariants.txt.gz';

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
      tw: await read(twAsset),
      hk: await read(hkAsset),
    );
  }

  String convert(String s, [HantForm form = HantForm.tw]) {
    final t = _s2t.convert(s);
    return switch (form) {
      HantForm.none => t,
      HantForm.tw => _tw.convert(t),
      HantForm.hk => _hk.convert(t),
    };
  }
}
