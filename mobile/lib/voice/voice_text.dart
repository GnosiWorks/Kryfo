// SPDX-License-Identifier: GPL-3.0-or-later
// what whisper says, made fit to show: its notes on sounds ("[BLANK_AUDIO]",
// "(silence)", "[MUSIC]") are no words, chinese comes in simplified
// characters whatever the model wrote, and the language it is asked to hear
// is one it knows. no language detection: the app says which one it is
import 'dart:convert' show utf8;
import 'dart:io' show File, Platform, gzip;
import 'dart:math' show max, min;

import 'package:flutter/services.dart';

import '../translate/detect.dart' show detectLanguage;
import '../translate/foreign.dart' show baseLang;

// the languages whisper hears, by its codes (whisper.cpp's g_lang)
final kWhisperLangs = {
  ...('en zh de es ru ko fr ja pt tr pl ca nl ar sv it id hi fi vi he uk el '
          'ms cs ro da hu ta no th ur hr bg lt la mi ml cy sk te fa lv bn sr '
          'az sl kn et mk br eu is hy ne mn bs kk sq sw gl mr pa si km sn yo '
          'so af oc ka be tg sd gu am yi lo uz fo ht ps tk nn mt sa lb my bo '
          'tl mg as tt haw ln ha ba jw su yue')
      .split(' '),
};

/// whisper's code for a language tag ("zh_Hant", "pt-BR", "nb"), or null
/// for one it does not hear
String? whisperLang(String? tag) {
  if (tag == null || tag.isEmpty) return null;
  final b = baseLang(tag);
  final w = switch (b) {
    'nb' => 'no',
    'iw' => 'he',
    'in' => 'id',
    'fil' => 'tl',
    'jv' => 'jw',
    _ => b,
  };
  return kWhisperLangs.contains(w) ? w : null;
}

/// the language a note is heard in: [theirs] for a note someone else sent,
/// when the chat's words say which one; the app's otherwise. english when
/// whisper knows neither
String noteLang({required bool mine, String? theirs, required String app}) =>
    (mine ? null : whisperLang(theirs)) ?? whisperLang(app) ?? 'en';

/// the language their recent words are in, newest first, when enough of
/// them say one clearly; null otherwise (and the app's language is used)
String? theirWordsLang(Iterable<String> newestFirst) {
  final words = newestFirst.take(12).join('\n');
  if (words.trim().isEmpty) return null;
  final g = detectLanguage(words);
  return g.share >= 0.6 ? whisperLang(g.lang) : null;
}

// a note on a sound, the whole segment: [BLANK_AUDIO], [ Silence ],
// (music), *coughs*, ♪
final _noteOnly = RegExp(
  r'^\s*(?:(?:\[[^\]]*\]|\([^)]*\)|\*[^*]*\*|[♪♫]+)\s*)+$',
);
// one in the middle of words: square brackets are never speech
final _noteIn = RegExp(r'\s*\[[^\]]*\]');

/// traditional characters into simplified, one at a time: the model's
/// mandarin can come out in either
class HansChars {
  final Map<int, String> _map;
  HansChars(this._map);

  static const asset = 'assets/opencc/STCharacters.txt.gz';

  /// from opencc's simplified-to-traditional table, turned round. a
  /// character that is itself a simplified one stays (著 in 著名), as does
  /// one with no single simplified form
  factory HansChars.parse(String table) {
    final simple = <int>{};
    final back = <int, String>{};
    final lines = table.split('\n');
    for (final line in lines) {
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      final s = line.substring(0, tab);
      if (s.runes.length == 1) simple.add(s.runes.first);
    }
    for (final line in lines) {
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      final s = line.substring(0, tab);
      if (s.runes.length != 1) continue;
      for (final t in line.substring(tab + 1).trim().split(' ')) {
        if (t.runes.length != 1) continue;
        final c = t.runes.first;
        if (simple.contains(c)) continue;
        back.putIfAbsent(c, () => s);
      }
    }
    return HansChars(back);
  }

  static HansChars? _loaded;

  /// the table from the app's assets, read once
  static Future<HansChars> load([AssetBundle? bundle]) async {
    final had = _loaded;
    if (had != null && bundle == null) return had;
    final d = await (bundle ?? rootBundle).load(asset);
    final h = HansChars.parse(
      utf8.decode(
        gzip.decode(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes)),
      ),
    );
    if (bundle == null) _loaded = h;
    return h;
  }

  String convert(String s) {
    final out = StringBuffer();
    for (final c in s.runes) {
      out.write(_map[c] ?? String.fromCharCode(c));
    }
    return out.toString();
  }
}

/// a segment as it is shown: '' when it held only notes on sounds
String cleanSegment(String text, {HansChars? hans}) {
  if (_noteOnly.hasMatch(text)) return '';
  var t = text.contains('[') ? text.replaceAll(_noteIn, '') : text;
  if (t.trim().isEmpty) return '';
  if (hans != null) t = hans.convert(t);
  // the model said back the line that leads it to simplified characters
  if (_isPrompt(t)) return '';
  return t;
}

/// the line kryfo_voice.c gives the model before mandarin (KV_ZH_PROMPT)
const kZhPrompt = '以下是普通话的句子。';

final _notWords = RegExp(r'[\s。，,.!?！？、：:；;]', unicode: true);
bool _isPrompt(String t) {
  final bare = t.replaceAll(_notWords, '');
  return bare.isNotEmpty && bare == kZhPrompt.replaceAll(_notWords, '');
}

/// how many threads a run takes: the phone's fast cores (those within a
/// quarter of the fastest one's top speed), at most 8 and at most half the
/// cores. the rest stay for the ui, its raster thread, the app's other work
/// and the kernel's memory work: whisper's threads wait for each other at
/// every step, so one that loses its core stalls them all. on 8 slow cores
/// 8 threads run several times slower in the app than alone and lmkd kills
/// apps around it; 4 take about what they take alone. [maxFreq] reads one
/// core's top speed in khz, null when it cannot be read
int voiceThreads({int? cores, int? Function(int core)? maxFreq}) {
  final n = cores ?? _cores();
  final read = maxFreq ?? _maxFreq;
  final f = [for (var i = 0; i < n; i++) read(i)];
  int fit(int t) => t.clamp(1, max(1, min(8, n ~/ 2)));
  if (f.any((x) => x == null || x <= 0)) return fit(4);
  final top = f.fold<int>(0, (a, b) => b! > a ? b : a);
  return fit(f.where((x) => x! * 4 >= top * 3).length);
}

// every core the phone has, online now or not: an idle phone takes cores
// offline, and numberOfProcessors counts only the online ones
int _cores() {
  try {
    final n = cpuListCount(
      File('/sys/devices/system/cpu/present').readAsStringSync(),
    );
    if (n != null) return n;
  } catch (_) {}
  return Platform.numberOfProcessors;
}

/// how many cpus a kernel cpu list names ("0-7", "0-3,6,7"); null for one
/// it cannot read
int? cpuListCount(String list) {
  var n = 0;
  for (final part in list.trim().split(',')) {
    final m = RegExp(r'^(\d+)(?:-(\d+))?$').firstMatch(part.trim());
    if (m == null) return null;
    final a = int.parse(m.group(1)!);
    final b = m.group(2) == null ? a : int.parse(m.group(2)!);
    if (b < a) return null;
    n += b - a + 1;
  }
  return n == 0 ? null : n;
}

int? _maxFreq(int core) {
  try {
    return int.tryParse(
      File(
        '/sys/devices/system/cpu/cpu$core/cpufreq/cpuinfo_max_freq',
      ).readAsStringSync().trim(),
    );
  } catch (_) {
    return null;
  }
}
