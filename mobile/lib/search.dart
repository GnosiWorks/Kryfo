// SPDX-License-Identifier: GPL-3.0-or-later
// search across every chat, on this phone. the words sit in a full-text
// index inside the encrypted database and leave it with the message.
// the index and a query hold the same folded text (text_fold.dart), so
// "cafe" finds "café". chinese has no spaces: each character is a token
// and a query is a phrase of them.
import 'dart:convert';

import 'polls.dart';
import 'text_fold.dart';

/// characters written without spaces between words: each one a token
bool isCjk(int r) =>
    (r >= 0x4E00 && r <= 0x9FFF) || // unified ideographs
    (r >= 0x3400 && r <= 0x4DBF) || // extension a
    (r >= 0x20000 && r <= 0x2A6DF) || // extension b
    (r >= 0xF900 && r <= 0xFAFF) || // compatibility ideographs
    (r >= 0x3040 && r <= 0x30FF) || // hiragana, katakana
    (r >= 0xAC00 && r <= 0xD7AF); // hangul syllables

/// the text as the index keeps it
String indexText(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    final f = foldRune(r);
    if (f.isEmpty) continue;
    if (isCjk(r)) {
      out
        ..write(' ')
        ..write(f)
        ..write(' ');
    } else {
      out.write(f);
    }
  }
  return out.toString();
}

/// the words a message row is found by: its text, a poll's answers, a
/// file's name, the title of the link it carries. a sticker has none: its
/// text is an emoji, which the index would drop anyway.
String searchBody(Map<String, Object?> r) {
  if (r['sticker'] != null) return '';
  final parts = <String>[(r['plaintext'] as String?) ?? ''];
  final poll = PollSpec.parse(r['poll']);
  if (poll != null) parts.addAll(poll.options);
  final name = r['file_name'] as String?;
  if (name != null && name != 'voice.wav') parts.add(name);
  final pv = r['preview'];
  if (pv is String && pv.contains('"title"')) {
    try {
      final t = (jsonDecode(pv) as Map)['title'];
      if (t is String) parts.add(t);
    } catch (_) {}
  }
  return indexText(parts.where((x) => x.trim().isNotEmpty).join('\n'));
}

/// what a person typed, as terms: folded, split on spaces. a run of
/// chinese characters is one term of its own.
List<String> queryTerms(String raw) {
  final terms = <String>[];
  for (final word in raw.trim().split(RegExp(r'\s+'))) {
    final w = StringBuffer();
    final cjk = StringBuffer();
    void flushW() {
      if (w.isNotEmpty) terms.add(w.toString());
      w.clear();
    }

    void flushC() {
      if (cjk.isNotEmpty) terms.add(cjk.toString());
      cjk.clear();
    }

    for (final r in word.runes) {
      final f = foldRune(r);
      if (f.isEmpty) continue;
      if (isCjk(r)) {
        flushW();
        cjk.write(f);
      } else {
        flushC();
        w.write(f);
      }
    }
    flushW();
    flushC();
  }
  // punctuation alone finds nothing and only confuses the match syntax
  return [
    for (final t in terms)
      if (t.runes.any((r) => _wordy(r))) t,
  ];
}

bool _wordy(int r) =>
    isCjk(r) ||
    (r >= 0x30 && r <= 0x39) ||
    (r >= 0x61 && r <= 0x7A) ||
    r > 0x7F && !_punct(r);

bool _punct(int r) =>
    (r >= 0x2000 && r <= 0x206F) || // general punctuation
    (r >= 0x3000 && r <= 0x303F) || // cjk punctuation
    (r >= 0xFF00 && r <= 0xFF0F) ||
    r == 0x060C || // arabic comma
    r == 0x061B ||
    r == 0x061F ||
    r == 0x066A ||
    r == 0x066B ||
    r == 0x066C ||
    r == 0x06D4;

/// the full-text match for [raw], or null when there is nothing to look
/// for. every term has to be there; a latin or arabic term matches the
/// start of a word ("pizz" finds "pizza"), a chinese one its characters in
/// a row.
String? ftsMatch(String raw) {
  final terms = queryTerms(raw);
  if (terms.isEmpty) return null;
  final parts = <String>[];
  for (final t in terms) {
    // quotes are the only thing a term could use to break out of its
    // string in the match syntax; they are not letters anyway
    final clean = t.replaceAll('"', ' ').trim();
    if (clean.isEmpty) continue;
    if (clean.runes.any(isCjk)) {
      parts.add('"${indexText(clean).trim().split(RegExp(r'\s+')).join(' ')}"');
    } else {
      // the index splits on anything that is not a letter or digit; a
      // term with punctuation inside becomes a phrase of its pieces
      final pieces = clean
          .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
          .where((p) => p.isNotEmpty)
          .toList();
      if (pieces.isEmpty) continue;
      parts.add('"${pieces.join(' ')}"*');
    }
  }
  return parts.isEmpty ? null : parts.join(' ');
}

/// where the terms stand in the original text, for the highlight. found on
/// the folded text and mapped back, so the accents and marks the person did
/// not type are still lit.
List<(int, int)> matchRanges(String text, String raw) {
  final terms = queryTerms(raw);
  if (terms.isEmpty || text.isEmpty) return const [];
  // the folded text, and for each of its code units the original index
  final folded = StringBuffer();
  final from = <int>[];
  var i = 0;
  for (final r in text.runes) {
    final width = r > 0xFFFF ? 2 : 1;
    final f = foldRune(r);
    for (var k = 0; k < f.length; k++) {
      from.add(i);
    }
    folded.write(f);
    i += width;
  }
  from.add(text.length);
  final hay = folded.toString();
  final found = <(int, int)>[];
  for (final t in terms) {
    var at = 0;
    while (true) {
      final hit = hay.indexOf(t, at);
      if (hit < 0) break;
      final start = from[hit];
      final endIdx = hit + t.length;
      // end at the original character after the last folded one
      var end = endIdx < from.length ? from[endIdx] : text.length;
      if (end <= start) end = start + 1;
      found.add((start, end));
      at = hit + t.length;
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final r in found) {
    if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// a line of the message around its first match, with the ranges moved
/// to fit it. short messages come whole.
({String text, List<(int, int)> ranges}) snippet(
  String text,
  List<(int, int)> ranges, {
  int before = 28,
  int length = 140,
}) {
  final flat = text.replaceAll('\n', ' ');
  if (flat.length <= length || ranges.isEmpty) {
    final cut = flat.length <= length ? flat : '${flat.substring(0, length)}…';
    return (
      text: cut,
      ranges: [
        for (final r in ranges)
          if (r.$1 < length) (r.$1, r.$2 > length ? length : r.$2),
      ],
    );
  }
  var start = ranges.first.$1 - before;
  if (start < 0) start = 0;
  // start at a word, not inside one
  if (start > 0) {
    final space = flat.indexOf(' ', start);
    if (space >= 0 && space < ranges.first.$1) start = space + 1;
  }
  var end = start + length;
  if (end > flat.length) end = flat.length;
  final lead = start > 0 ? '…' : '';
  final tail = end < flat.length ? '…' : '';
  final shift = lead.length - start;
  return (
    text: '$lead${flat.substring(start, end)}$tail',
    ranges: [
      for (final r in ranges)
        if (r.$1 >= start && r.$1 < end)
          (r.$1 + shift, (r.$2 > end ? end : r.$2) + shift),
    ],
  );
}

/// what a filter keeps
enum SearchKind { all, photos, videos, files, links }

const videoExts = ['mp4', 'mov', 'webm', 'mkv', 'm4v', '3gp'];

/// the sql condition on messages (as m) for a filter; '' for all
String kindWhere(SearchKind k) => switch (k) {
  SearchKind.all => '',
  SearchKind.photos => 'm.media_path IS NOT NULL',
  SearchKind.videos =>
    '(m.file_path IS NOT NULL AND (${[for (final e in videoExts) "lower(m.file_name) LIKE '%.$e'"].join(' OR ')}))',
  SearchKind.files =>
    "(m.file_path IS NOT NULL AND m.file_name IS NOT NULL AND m.file_name != 'voice.wav' AND NOT (${[for (final e in videoExts) "lower(m.file_name) LIKE '%.$e'"].join(' OR ')}))",
  SearchKind.links =>
    "(m.preview IS NOT NULL OR m.plaintext LIKE '%http://%' OR m.plaintext LIKE '%https://%' OR m.plaintext LIKE '%kryfo://%')",
};
