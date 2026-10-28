// SPDX-License-Identifier: GPL-3.0-or-later
// the word typed to confirm a wipe. keyboards differ: one types "xoa", another
// "xóa", composed or as a letter plus combining marks, in any case. so the
// word is compared lowercase and without accents. the english word is
// always accepted too.

import 'text_fold.dart';

// hindi keyboards differ too: the nukta dot is often left off (precomposed
// or as a mark), and the chandrabindu typed as an anusvara. folded here, not
// in text_fold, because the search index keeps what text_fold made of it
const _devanagari = {
  0x0958: 'क',
  0x0959: 'ख',
  0x095A: 'ग',
  0x095B: 'ज',
  0x095C: 'ड',
  0x095D: 'ढ',
  0x095E: 'फ',
  0x095F: 'य',
  0x0901: 'ं',
  0x093C: '',
};

String _bare(String s) {
  final out = StringBuffer();
  for (final r in fold(s.trim()).runes) {
    out.write(_devanagari[r] ?? String.fromCharCode(r));
  }
  return out.toString();
}

bool isWipeWord(String? typed, String word) {
  if (typed == null) return false;
  final t = _bare(typed);
  return t.isNotEmpty && (t == _bare(word) || t == 'wipe');
}
