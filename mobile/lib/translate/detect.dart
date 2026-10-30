// SPDX-License-Identifier: GPL-3.0-or-later
// a message's language for the translation models, by script and then a
// few common characters or words. no guess rather than a wrong one. kept in
// dart so a message's words do not go to the engine for it

class LangGuess {
  // '' when there is no guess
  final String lang;
  // how much of the message's letters back the guess, 0 to 1
  final double share;
  const LangGuess(this.lang, this.share);
  static const none = LangGuess('', 0);

  @override
  bool operator ==(Object other) =>
      other is LangGuess && other.lang == lang && other.share == share;
  @override
  int get hashCode => Object.hash(lang, share);
  @override
  String toString() => 'LangGuess($lang, ${share.toStringAsFixed(2)})';
}

final _han = RegExp(r'\p{Script=Han}', unicode: true);
final _kana = RegExp(
  r'[\p{Script=Hiragana}\p{Script=Katakana}]',
  unicode: true,
);
final _hangul = RegExp(r'\p{Script=Hangul}', unicode: true);
final _latin = RegExp(r'\p{Script=Latin}', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);
final _space = RegExp(r'\s+');
final _wordCut = RegExp(r"[^\p{L}']+", unicode: true);

LangGuess detectLanguage(String s) {
  var han = 0, kana = 0, hangul = 0, latin = 0, other = 0;
  var trad = 0, simp = 0;
  for (final w in s.split(_space)) {
    if (w.isEmpty || _isLink(w)) continue;
    for (final r in w.runes) {
      final c = String.fromCharCode(r);
      if (_han.hasMatch(c)) {
        han++;
        if (_tradOnly.contains(r)) {
          trad++;
        } else if (_simpOnly.contains(r)) {
          simp++;
        }
      } else if (_kana.hasMatch(c)) {
        kana++;
      } else if (_hangul.hasMatch(c)) {
        hangul++;
      } else if (_latin.hasMatch(c)) {
        latin++;
      } else if (_letter.hasMatch(c)) {
        other++;
      }
    }
  }
  // weigh scripts in rough words: a chinese word is a character or two, an
  // english one about five letters
  final cjk = (han + kana + hangul) / 1.5;
  final lat = latin / 5;
  final oth = other / 5;
  final all = cjk + lat + oth;
  if (all < 1) return LangGuess.none;
  if (cjk >= lat && cjk >= oth) {
    final n = han + kana + hangul;
    final share = cjk / all;
    if (kana > 0 && kana >= 0.1 * n) return LangGuess('ja', share);
    if (hangul >= han) return LangGuess('ko', share);
    if (trad > simp) return LangGuess('zh_hant', share);
    return LangGuess('zh', share);
  }
  if (lat >= oth && _englishish(s)) return LangGuess('en', lat / all);
  return LangGuess.none;
}

// about how many words a message has: a chinese or japanese word is a
// character or two, elsewhere words are what spaces split. links, handles,
// numbers and emoji are not words
double roughWords(String s) {
  var cjk = 0, words = 0;
  for (final w in s.split(_space)) {
    if (w.isEmpty || _isLink(w)) continue;
    var letters = 0;
    for (final r in w.runes) {
      final c = String.fromCharCode(r);
      if (_han.hasMatch(c) || _kana.hasMatch(c)) {
        cjk++;
      } else if (_letter.hasMatch(c)) {
        letters++;
      }
    }
    if (letters > 0) words++;
  }
  return words + cjk / 1.5;
}

bool _isLink(String w) {
  final l = w.toLowerCase();
  return l.startsWith('http://') ||
      l.startsWith('https://') ||
      l.startsWith('www.') ||
      l.startsWith('@');
}

// latin text is taken for english when enough of its words are common
// english ones. a short message with none ("ok", "lol") stays unknown
bool _englishish(String s) {
  var words = 0, hits = 0;
  for (final w in s.toLowerCase().split(_wordCut)) {
    if (w.isEmpty) continue;
    if (!_ascii(w)) {
      // accents and the like: some other latin language
      if (w.runes.any(
        (r) => r >= 0x80 && _latin.hasMatch(String.fromCharCode(r)),
      )) {
        return false;
      }
      // a word in another script is the other part of a mixed message
      continue;
    }
    words++;
    if (_englishWords.contains(w)) hits++;
  }
  if (words == 0) return false;
  if (words <= 3) return hits >= 1;
  return hits / words >= 0.2;
}

bool _ascii(String w) => w.codeUnits.every((c) => c < 0x80);

final _englishWords =
    '''the a an and or but if of to in on at for with from by
	about as into like through after over between out up down off than so not no yes
	i me my mine you your yours he him his she her it its we us our they them their
	this that these those what which who whom whose when where why how
	is am are was were be been being have has had do does did done will would shall
	should can could may might must let get got go going went come came see saw know
	think want need make made say said tell told give gave take took look find
	there here now then just also very too only really well still even again ever
	all any some many much more most other such own same each every both few
	hi hello hey thanks thank please sorry okay good great sure right new one two
	today tomorrow yesterday time day night week year people thing way
	i'm you're it's don't can't won't didn't isn't that's let's i'll i've'''
        .split(_space)
        .where((w) => w.isNotEmpty)
        .toSet();

// common characters written one way in simplified and another in
// traditional chinese, as pairs. only ones neither script also uses for
// something else, so a hit says which script it is
const _scriptPairs = '''个個 们們 这這 说說 时時 国國 会會 来來 对對 为為 发發 过過 还還 没沒
	开開 关關 问問 题題 现現 实實 学學 习習 东東 车車 长長 门門 见見 话話 语語
	吗嗎 让讓 给給 谁誰 应應 该該 经經 进進 动動 种種 头頭 样樣 当當 从從 两兩
	机機 电電 买買 卖賣 钱錢 号號 书書 写寫 爱愛 觉覺 听聽 难難 边邊 带帶 气氣
	业業 线線 网網 页頁 级級 结結 点點 万萬 与與 产產 务務 员員 报報 场場 处處
	节節 计計 认認 识識 读讀 请請 谢謝 欢歡 乐樂 体體 华華 岁歲 广廣 记記 张張
	陈陳 刘劉 杨楊 黄黃 赵趙 吴吳 饭飯 馆館 鸡雞 鱼魚 鸟鳥 马馬 贵貴 钟鐘''';

final (Set<int>, Set<int>) _pairs = () {
  final s = <int>{}, t = <int>{};
  for (final p in _scriptPairs.split(_space)) {
    final r = p.runes.toList();
    if (r.length == 2 && r[0] != r[1]) {
      s.add(r[0]);
      t.add(r[1]);
    }
  }
  return (s, t);
}();
Set<int> get _simpOnly => _pairs.$1;
Set<int> get _tradOnly => _pairs.$2;
