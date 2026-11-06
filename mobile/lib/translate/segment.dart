// SPDX-License-Identifier: GPL-3.0-or-later
// a message as the model gets it. the model reads each line of a text as a
// text of its own, so a sentence over three lines came out word by word.
// here a message goes in one call: the lines of one sentence joined, its
// line breaks between sentences kept as they were, links, @mentions and
// emojis kept out of the model and put back unchanged, and a long text cut
// at sentence ends only where the model's input limit needs it.

// what the model takes in one piece, in estimated tokens: bergamot breaks a
// sentence at 128 wherever it is, so ours stay under that
const kModelLimit = 100;

// links, @mentions and emojis: never shown to the model
final _keep = RegExp(
  r'(?:https?://|www\.)[^\s]+'
  r'|(?<![\p{L}\p{N}_@])@[\p{L}\p{N}_][\p{L}\p{N}_.\-]*'
  r'|(?:\p{Extended_Pictographic}|\p{Regional_Indicator}|[#*0-9]️?⃣)'
  r'(?:[️‍\p{Emoji_Modifier}\p{Extended_Pictographic}\p{Regional_Indicator}\u{E0020}-\u{E007F}])*',
  unicode: true,
  caseSensitive: false,
);
// what a link or mention does not end with
final _linkTail = RegExp(r'''[.,;:!?'"”’»]+$''');
final _mentionTail = RegExp(r'[.\-]+$');

final _letter = RegExp(r'[\p{L}]', unicode: true);
final _han = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]',
  unicode: true,
);
final _upper = RegExp(r'^[\p{Lu}\p{Lt}]', unicode: true);
final _lower = RegExp(r'^\p{Ll}', unicode: true);
final _ends = RegExp(r'''[.!?…。！？‼⁉]["'”’»」』）)\]]*$''');
final _goesOn = RegExp(r'[,，、;；:：\-\u2013\u2014(（]$');
final _bullet = RegExp(r'^(?:[-*•·]|\d+[.)])\s');
final _space = RegExp(r'\s');
// where a long text may be cut: after a sentence, else a clause, else a space
final _sentenceEnd = RegExp(
  r'''[.!?…]["'”’»)\]]*\s+|[。！？][」』）]*\s*''',
  unicode: true,
);
final _clauseEnd = RegExp(r'[,;:，；、：]\s*');
final _gap = RegExp(r'\s+');

// how many tokens the model will likely make of s
int modelTokens(String s) {
  var han = 0, other = 0;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (_han.hasMatch(c)) {
      han++;
    } else if (!_space.hasMatch(c)) {
      other++;
    }
  }
  return han + (other + 3) ~/ 4;
}

// a message cut for the model: what it is asked, and how the answers go
// back between what it never saw
class MessagePlan {
  // what the model is asked, in order, in one call
  final List<String> asks;
  // the message in order: a String is kept as it is, an int is that ask's
  // answer
  final List<Object> parts;
  const MessagePlan._(this.asks, this.parts);

  // [to]: the language the answers are in. its own gap goes between
  // sentences, not the source's: a space after . ! ? in spaced scripts,
  // none after 。！？ in chinese and japanese. line breaks stay as they are
  String fill(List<String> answers, {String? to}) {
    if (answers.length != asks.length) {
      throw ArgumentError('${answers.length} answers for ${asks.length}');
    }
    final close = to != null && closedUp(to);
    final out = [
      for (final p in parts) p is int ? _regap(answers[p].trim(), to) : p,
    ];
    final b = StringBuffer();
    for (var i = 0; i < out.length; i++) {
      var piece = out[i] as String;
      final prev = i > 0 && parts[i - 1] is int ? out[i - 1] as String : null;
      if (to != null && prev != null) {
        if (parts[i] is int) {
          // two answers with nothing kept between: a cut at a sentence end
          if (!close && _latinEnd.hasMatch(prev)) b.write(' ');
        } else if (close &&
            i + 1 < out.length &&
            parts[i + 1] is int &&
            piece.trim().isEmpty &&
            !piece.contains('\n') &&
            _cjkEnd.hasMatch(prev)) {
          piece = '';
        }
      }
      b.write(piece);
    }
    return b.toString();
  }
}

// languages written with no gap between sentences
bool closedUp(String lang) {
  final l = lang.toLowerCase();
  return l == 'zh' ||
      l.startsWith('zh_') ||
      l.startsWith('zh-') ||
      l == 'ja' ||
      l.startsWith('ja_');
}

// a sentence end, with the quotes and brackets that close it
final _latinEnd = RegExp(r'''[.!?…؟]["'”’»)\]]*$''');
final _cjkEnd = RegExp(r'[。！？][」』）]*$');
// a sentence end with a capital or a caseless letter right after it, and
// a full-width one with spaces after it
final _tightEnd = RegExp(
  r'''([.!?…؟]["'”’»)\]]*)(?=[\p{Lu}\p{Lt}\p{Lo}])''',
  unicode: true,
);
final _looseCjk = RegExp(r'([。！？][」』）]*)[ \t\u3000]+(?=\S)');

// one answer with its target's gaps between sentences
String _regap(String s, String? to) {
  if (to == null) return s;
  if (closedUp(to)) return s.replaceAllMapped(_looseCjk, (m) => m[1]!);
  return s.replaceAllMapped(_tightEnd, (m) => '${m[1]} ');
}

MessagePlan planMessage(String text, {int limit = kModelLimit}) {
  final asks = <String>[];
  final parts = <Object>[];
  void keep(String s) {
    if (s.isEmpty) return;
    if (parts.isNotEmpty && parts.last is String) {
      parts.last = '${parts.last}$s';
    } else {
      parts.add(s);
    }
  }

  void ask(String s) {
    for (final (piece, gap) in _cut(s, limit)) {
      if (_letter.hasMatch(piece)) {
        parts.add(asks.length);
        asks.add(piece);
      } else {
        keep(piece);
      }
      keep(gap);
    }
  }

  var at = 0;
  for (final m in _keep.allMatches(text)) {
    var tok = m[0]!;
    if (tok.startsWith('@')) {
      tok = tok.replaceFirst(_mentionTail, '');
    } else if (tok.contains('://') || tok.toLowerCase().startsWith('www.')) {
      tok = tok.replaceFirst(_linkTail, '');
      // a closing bracket is the link's only when it opened one
      while (tok.endsWith(')') && !tok.contains('(')) {
        tok = tok.substring(0, tok.length - 1);
      }
    }
    _prose(text.substring(at, m.start), ask, keep);
    keep(tok);
    at = m.start + tok.length;
  }
  _prose(text.substring(at), ask, keep);
  return MessagePlan._(asks, parts);
}

// prose between kept things: its lines grouped into sentences
void _prose(String s, void Function(String) ask, void Function(String) keep) {
  if (s.isEmpty) return;
  final lines = s.split('\n');
  var i = 0;
  while (i < lines.length) {
    if (i > 0) keep('\n');
    final line = lines[i];
    if (line.trim().isEmpty) {
      keep(line);
      i++;
      continue;
    }
    // this line and those that go on its sentence
    var j = i;
    while (j + 1 < lines.length &&
        lines[j + 1].trim().isNotEmpty &&
        !_keepBreak(lines[j].trim(), lines[j + 1].trim())) {
      j++;
    }
    final first = lines[i], last = lines[j];
    final lead = first.substring(0, first.length - first.trimLeft().length);
    final trail = last.substring(last.trimRight().length);
    final b = StringBuffer(lines[i].trim());
    for (var k = i + 1; k <= j; k++) {
      final next = lines[k].trim();
      final prev = lines[k - 1].trim();
      final cjk =
          _han.hasMatch(prev.substring(prev.length - 1)) ||
          _han.hasMatch(next.substring(0, 1));
      b
        ..write(cjk ? '' : ' ')
        ..write(next);
    }
    keep(lead);
    final words = b.toString();
    if (_letter.hasMatch(words)) {
      ask(words);
    } else {
      // punctuation or numbers alone: nothing to translate
      keep(words);
    }
    keep(trail);
    i = j + 1;
  }
}

// whether a line break stays: between two sentences, before a list item or
// a new sentence. a break inside a sentence becomes a space, since the
// translated words have no place for it
bool _keepBreak(String prev, String next) {
  if (_ends.hasMatch(prev)) return true;
  if (_goesOn.hasMatch(prev)) return false;
  if (_bullet.hasMatch(next)) return true;
  final firstLetter = _letter.firstMatch(next);
  if (firstLetter == null || firstLetter.start != 0) return true;
  if (_upper.hasMatch(next)) return true;
  if (_lower.hasMatch(next)) return false;
  // scripts without case
  return true;
}

// s in pieces the model takes whole, each with the gap that followed it
List<(String, String)> _cut(String s, int limit) =>
    _pack(_pieces(s, '', limit, 0), limit);

// cut at sentence ends first; a piece still over the limit at clauses, then
// at spaces, then anywhere
final _cuts = [_sentenceEnd, _clauseEnd, _gap];

List<(String, String)> _pieces(String s, String gap, int limit, int level) {
  if (modelTokens(s) <= limit) return [(s, gap)];
  if (level == _cuts.length) {
    final runes = s.runes.toList();
    return [
      for (var k = 0; k < runes.length; k += limit)
        (
          String.fromCharCodes(
            runes.sublist(k, (k + limit).clamp(0, runes.length)),
          ),
          k + limit >= runes.length ? gap : '',
        ),
    ];
  }
  final parts = _split(s, _cuts[level]);
  return [
    for (var i = 0; i < parts.length; i++)
      ..._pieces(
        parts[i].$1,
        i == parts.length - 1 ? gap : parts[i].$2,
        limit,
        level + 1,
      ),
  ];
}

// s cut after each match of re, each piece with the match's whitespace as
// its gap; the punctuation stays with the piece
List<(String, String)> _split(String s, RegExp re) {
  final out = <(String, String)>[];
  var at = 0;
  for (final m in re.allMatches(s)) {
    if (m.end >= s.length) break;
    final mark = m[0]!.trimRight();
    out.add((
      s.substring(at, m.start + mark.length),
      m[0]!.substring(mark.length),
    ));
    at = m.end;
  }
  out.add((s.substring(at), ''));
  return out;
}

// pieces next to each other go back together while they fit, so a text is
// cut only where the limit needs it
List<(String, String)> _pack(List<(String, String)> pieces, int limit) {
  final out = <(String, String)>[];
  for (final (p, g) in pieces) {
    if (out.isNotEmpty) {
      final (q, h) = out.last;
      final joined = '$q$h$p';
      if (modelTokens(joined) <= limit) {
        out.last = (joined, g);
        continue;
      }
    }
    out.add((p, g));
  }
  return out;
}
