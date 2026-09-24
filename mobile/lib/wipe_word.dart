// SPDX-License-Identifier: GPL-3.0-or-later
// the word typed to confirm a wipe. keyboards differ: one types "xoa", another
// "xóa", composed or as a letter plus combining marks, in any case. so the
// word is compared lowercase and without accents. the english word is
// always accepted too.

import 'text_fold.dart';

String _bare(String s) => fold(s.trim());

bool isWipeWord(String? typed, String word) {
  if (typed == null) return false;
  final t = _bare(typed);
  return t.isNotEmpty && (t == _bare(word) || t == 'wipe');
}
