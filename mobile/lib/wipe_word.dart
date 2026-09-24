// SPDX-License-Identifier: GPL-3.0-or-later
// the word typed to confirm a wipe. keyboards differ: one types "xoa", another
// "xóa", composed or as a letter plus combining marks, in any case. so the
// word is compared lowercase and without accents. the english word is
// always accepted too.

const _accented =
    'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎďĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľŃńŅņŇňŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǞǟǠǡǦǧǨǩǪǫǬǭǰǴǵǸǹǺǻȀȁȂȃȄȅȆȇȈȉȊȋȌȍȎȏȐȑȒȓȔȕȖȗȘșȚțȞȟȦȧȨȩȪȫȬȭȮȯȰȱȲȳẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹđĐıøØłŁ';
const _plain =
    'aaaaaaceeeeiiiinooooouuuuyaaaaaaceeeeiiiinooooouuuuyyaaaaaaccccccccddeeeeeeeeeegggggggghhiiiiiiiiijjkkllllllnnnnnnoooooorrrrrrssssssssttttuuuuuuuuuuuuwwyyyzzzzzzoouuaaiioouuuuuuuuuuaaaaggkkoooojggnnaaaaaaeeeeiiiioooorrrruuuusstthhaaeeooooooooyyaaaaaaaaaaaaaaaaaaaaaaaaeeeeeeeeeeeeeeeeiiiioooooooooooooooooooooooouuuuuuuuuuuuuuyyyyyyyyddiooll';

// arabic-script letters a persian or an arabic keyboard spells differently
const _arabicForms = {
  0x0643: 'ک', // arabic kaf, typed for the persian word
  0x064A: 'ی', // arabic yeh
  0x0649: 'ی', // alef maksura
  0x0623: 'ا', // alef with hamza above
  0x0625: 'ا', // alef with hamza below
  0x0622: 'ا', // alef with madda
};

String _bare(String s) {
  final out = StringBuffer();
  for (final r in s.trim().toLowerCase().runes) {
    // a combining mark, left by a keyboard that does not compose
    if (r >= 0x0300 && r <= 0x036F) continue;
    // arabic vowel marks and the tatweel, the zero-width non-joiner and
    // direction marks: none of them changes the word
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) continue;
    if (r == 0x200C || r == 0x200E || r == 0x200F) continue;
    if (r >= 0x2066 && r <= 0x2069) continue;
    final a = _arabicForms[r];
    if (a != null) {
      out.write(a);
      continue;
    }
    final c = String.fromCharCode(r);
    final i = _accented.indexOf(c);
    out.write(i < 0 ? c : _plain[i]);
  }
  return out.toString();
}

bool isWipeWord(String? typed, String word) {
  if (typed == null) return false;
  final t = _bare(typed);
  return t.isNotEmpty && (t == _bare(word) || t == 'wipe');
}
