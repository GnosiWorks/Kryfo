// SPDX-License-Identifier: GPL-3.0-or-later
// text folded for comparing: lowercase, no accents, and the arabic-script
// letters keyboards spell differently made one. the wipe word and search
// both compare this way, so "xoa" finds "xóa" and a persian word typed with
// an arabic kaf finds the one written with the persian one.

const _accented =
    'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎďĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľŃńŅņŇňŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǞǟǠǡǦǧǨǩǪǫǬǭǰǴǵǸǹǺǻȀȁȂȃȄȅȆȇȈȉȊȋȌȍȎȏȐȑȒȓȔȕȖȗȘșȚțȞȟȦȧȨȩȪȫȬȭȮȯȰȱȲȳẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹđĐıøØłŁ';
const _plain =
    'aaaaaaceeeeiiiinooooouuuuyaaaaaaceeeeiiiinooooouuuuyyaaaaaaccccccccddeeeeeeeeeegggggggghhiiiiiiiiijjkkllllllnnnnnnoooooorrrrrrssssssssttttuuuuuuuuuuuuwwyyyzzzzzzoouuaaiioouuuuuuuuuuaaaaggkkoooojggnnaaaaaaeeeeiiiioooorrrruuuusstthhaaeeooooooooyyaaaaaaaaaaaaaaaaaaaaaaaaeeeeeeeeeeeeeeeeiiiioooooooooooooooooooooooouuuuuuuuuuuuuuyyyyyyyyddiooll';

final Map<int, String> _latin = {
  for (var i = 0; i < _accented.length; i++) _accented.codeUnitAt(i): _plain[i],
};

// letters people type another way: ss for the german sharp s, e for the
// russian yo
const _spelled = {0x00DF: 'ss', 0x1E9E: 'ss', 0x0451: 'е', 0x0401: 'е'};

// arabic-script letters a persian or an arabic keyboard spells differently
const _arabicForms = {
  0x0643: 'ک', // arabic kaf, typed for the persian word
  0x064A: 'ی', // arabic yeh
  0x0649: 'ی', // alef maksura
  0x0623: 'ا', // alef with hamza above
  0x0625: 'ا', // alef with hamza below
  0x0622: 'ا', // alef with madda
};

/// true for marks that never change a word: combining accents, arabic
/// vowel marks and the tatweel, the zero-width non-joiner and direction
/// marks
bool _dropped(int r) =>
    (r >= 0x0300 && r <= 0x036F) ||
    (r >= 0x064B && r <= 0x065F) ||
    r == 0x0670 ||
    r == 0x0640 ||
    r == 0x200C ||
    r == 0x200D ||
    r == 0x200E ||
    r == 0x200F ||
    (r >= 0x2066 && r <= 0x2069);

/// one character folded: '' when it is a mark to drop
String foldRune(int r) {
  if (_dropped(r)) return '';
  final a = _arabicForms[r] ?? _spelled[r];
  if (a != null) return a;
  final lower = String.fromCharCode(r).toLowerCase();
  if (lower.length == 1) {
    final l = _latin[lower.codeUnitAt(0)];
    if (l != null) return l;
  }
  // a lowercase form that brought a combining mark with it (turkish İ)
  final out = StringBuffer();
  for (final c in lower.runes) {
    if (!_dropped(c)) out.writeCharCode(c);
  }
  return out.toString();
}

/// the whole text folded
String fold(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    out.write(foldRune(r));
  }
  return out.toString();
}
