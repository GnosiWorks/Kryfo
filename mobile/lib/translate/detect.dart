// SPDX-License-Identifier: GPL-3.0-or-later
// a message's language for the translation models, by script and then a
// few common characters or words. no guess rather than a wrong one, and no
// guess for a language without packs. kept in dart so a message's words do
// not go to the engine for it

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
final _cyr = RegExp(r'\p{Script=Cyrillic}', unicode: true);
final _arab = RegExp(r'\p{Script=Arabic}', unicode: true);
final _deva = RegExp(r'\p{Script=Devanagari}', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);
final _space = RegExp(r'\s+');
final _wordCut = RegExp(r"[^\p{L}\p{M}']+", unicode: true);

LangGuess detectLanguage(String s) {
  var han = 0, kana = 0, hangul = 0, latin = 0, other = 0;
  var cyr = 0, arab = 0, deva = 0;
  var trad = 0, simp = 0;
  // the words without links and handles, lower case
  final kept = <String>[];
  for (final w in s.split(_space)) {
    if (w.isEmpty || _isLink(w)) continue;
    kept.add(w.toLowerCase());
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
      } else if (!_letter.hasMatch(c)) {
        continue;
      } else if (_latin.hasMatch(c)) {
        latin++;
      } else if (_cyr.hasMatch(c)) {
        cyr++;
      } else if (_arab.hasMatch(c)) {
        arab++;
      } else if (_deva.hasMatch(c)) {
        deva++;
      } else {
        other++;
      }
    }
  }
  // weigh scripts in rough words: a chinese word is a character or two, an
  // english one about five letters
  final cjk = (han + kana + hangul) / 1.5;
  final lat = latin / 5, cy = cyr / 5, ar = arab / 5, dv = deva / 5;
  final oth = other / 5;
  final all = cjk + lat + cy + ar + dv + oth;
  if (all < 1) return LangGuess.none;
  final top = [cjk, lat, cy, ar, dv, oth].reduce((a, b) => a > b ? a : b);
  if (cjk == top) {
    final n = han + kana + hangul;
    final share = cjk / all;
    if (kana > 0 && kana >= 0.1 * n) return LangGuess('ja', share);
    if (hangul >= han) return LangGuess('ko', share);
    if (trad > simp) return LangGuess('zh_hant', share);
    return LangGuess('zh', share);
  }
  final text = kept.join(' ');
  final String lang;
  final double share;
  if (lat == top) {
    final l = _latinLang(text);
    lang = l == 'en' && !_englishish(s) ? '' : l;
    share = lat / all;
  } else if (cy == top) {
    lang = _cyrillicLang(text);
    share = cy / all;
  } else if (ar == top) {
    lang = _arabicLang(text);
    share = ar / all;
  } else if (dv == top) {
    // marathi's own letter: the hindi model would read it wrong
    lang = text.contains('\u0933') ? '' : 'hi';
    share = dv / all;
  } else {
    return LangGuess.none;
  }
  return lang.isEmpty ? LangGuess.none : LangGuess(lang, share);
}

// the language with the most hits, when it is ahead of every other and
// backed by enough of the words; '' otherwise
String _bestOf(Map<String, int> score, int words) {
  var best = '', top = 0, next = 0;
  for (final e in score.entries) {
    if (e.value > top) {
      next = top;
      top = e.value;
      best = e.key;
    } else if (e.value > next) {
      next = e.value;
    }
  }
  if (top < 1 || top == next) return '';
  if (words > 3 && top / words < 0.2) return '';
  return best;
}

Iterable<String> _words(String text) =>
    text.split(_wordCut).where((w) => w.isNotEmpty);

void _hit(Map<String, int> score, String lang) =>
    score[lang] = (score[lang] ?? 0) + 1;

// latin text: common words, and letters only one language here uses. a
// letter of a language with no pack (czech, hungarian, romanian, the nordic
// and baltic ones) means no guess. english keeps a tie when the text has
// no accented letter, as before
String _latinLang(String text) {
  if (text.runes.any(_latinVeto.contains)) return '';
  final score = <String, int>{};
  var words = 0;
  for (final w in _words(text)) {
    if (!w.runes.any((r) => _latin.hasMatch(String.fromCharCode(r)))) {
      continue;
    }
    words++;
    for (final e in _latinCommon.entries) {
      if (e.value.contains(w)) _hit(score, e.key);
    }
    for (final e in _latinMarks.entries) {
      if (w.runes.any(e.value.contains)) _hit(score, e.key);
    }
  }
  // ¿ ¡
  if (text.contains('¿') || text.contains('¡')) _hit(score, 'es');
  final en = score.remove('en') ?? 0;
  final rest = score.values.fold(0, (a, b) => a > b ? a : b);
  if (en > rest || (en > 0 && en == rest && !_accented(text))) {
    return words > 3 && en / words < 0.2 ? '' : 'en';
  }
  final best = _bestOf(score, words);
  // dutch is listed so its words are not taken for german
  return best == 'nl' ? '' : best;
}

bool _accented(String text) =>
    text.runes.any((r) => r >= 0x80 && _latin.hasMatch(String.fromCharCode(r)));

// russian and ukrainian by their own letters, else by common words, and
// russian when nothing says otherwise. bulgarian, serbian, belarusian and
// the rest get no guess
String _cyrillicLang(String text) {
  var ru = 0, uk = 0, hard = 0;
  for (final r in text.runes) {
    if (_ruLetters.contains(r)) {
      ru++;
    } else if (_ukLetters.contains(r)) {
      uk++;
    } else if (r == 0x044a) {
      // ъ: rare in russian, common in bulgarian
      hard++;
    } else if ((r < 0x0430 || r > 0x044f) &&
        _cyr.hasMatch(String.fromCharCode(r))) {
      return '';
    }
  }
  if (ru > 0 && uk > 0) return '';
  if (uk > 0) return 'uk';
  if (ru > 0) return 'ru';
  final score = <String, int>{if (hard > 0) 'bg': hard};
  var words = 0;
  for (final w in _words(text)) {
    words++;
    for (final e in _cyrCommon.entries) {
      if (e.value.contains(w)) _hit(score, e.key);
    }
  }
  final ruHits = score.remove('ru') ?? 0;
  final rest = score.values.fold(0, (a, b) => a > b ? a : b);
  if (ruHits >= rest) return 'ru';
  final best = _bestOf(score, words);
  return best == 'bg' ? '' : best;
}

// arabic and persian by the letters each writes yeh and kaf with, persian's
// own letters and joiner, and arabic's article. urdu, pashto, kurdish and
// the rest get no guess
String _arabicLang(String text) {
  var fa = 0, ar = 0;
  for (final r in text.runes) {
    if (_arabVeto.contains(r)) return '';
    if (_faLetters.contains(r)) fa++;
    if (_arLetters.contains(r)) ar++;
  }
  for (final w in _words(text)) {
    if (w.startsWith('\u0627\u0644')) ar++;
  }
  if (fa > ar) return 'fa';
  if (ar > fa) return 'ar';
  return '';
}

Set<int> _runes(String s) => s.runes.toSet();

Set<String> _set(String s) =>
    s.split(_space).where((w) => w.isNotEmpty).toSet();

// ы э ё; і ї є ґ
final _ruLetters = _runes('\u044b\u044d\u0451');
final _ukLetters = _runes('\u0456\u0457\u0454\u0491');
// پ چ ژ گ ک ی and the zero width non-joiner; ة ي ك ى أ إ ؤ
final _faLetters = _runes('\u067e\u0686\u0698\u06af\u06a9\u06cc\u200c');
final _arLetters = _runes('\u0629\u064a\u0643\u0649\u0623\u0625\u0624');
// urdu, pashto, kurdish, sindhi and uyghur letters
final _arabVeto = _runes(
  '\u0679\u0688\u0691\u06ba\u06d2\u06d3\u06c1\u06c2\u06c6\u06ce'
  '\u06d5\u0695\u06b5\u067c\u0681\u0685\u0689\u0693\u0696\u069a'
  '\u06ab\u06bc\u06cd\u06d0\u06ad\u06c7\u06cb\u06c8',
);
// czech, slovak, croatian, hungarian, romanian, nordic, baltic, icelandic
final _latinVeto = _runes('řěůčšžťďľĺŕőűåøæėųįāēīūðþ\u0219\u021b\u0163');

// letters only one of these languages uses
final Map<String, Set<int>> _latinMarks = {
  'de': _runes('äß'),
  'fr': _runes('èêëîïûùœ'),
  'es': _runes('ñ'),
  'pt': _runes('ãõ'),
  'it': _runes('ìò'),
  'pl': _runes('ąęłńśźżć'),
  'tr': _runes('ğı'),
  // vietnamese: its own vowels, and every letter with two marks
  'vi': {..._runes('ơưđ'), for (var r = 0x1ea0; r <= 0x1ef9; r++) r},
};

final Map<String, Set<String>> _latinCommon = {
  'en': _englishWords,
  'de': _set('''der die das und ist nicht ich du er sie wir ihr es ein eine
	einen dem den des mit auf für von zu im ins auch aber noch schon wie was wer
	wo wann warum ja nein danke bitte hallo gut sehr mein dein kann habe hast
	hat sind bin bist wird werden morgen heute oder wenn dann weil nur mal doch
	jetzt hier gibt keine kein mich dich uns euch alles viel'''),
  'fr': _set('''le la les un une des du et est pas je tu il elle nous vous
	ils elles ce cette ces que qui quoi ne dans pour avec sur au aux mais ou où
	oui non merci bonjour salut très bien suis sont ai avez avons fait faire
	c'est j'ai qu'il pourquoi comment quand aussi encore plus moi toi mon ma mes
	ton ta tes son sa ses leur cela ça'''),
  'es': _set('''el la los las una unos unas del y que es por para con su sus lo
	le se me te mi tu yo él ella nosotros ellos qué cómo cuándo dónde porque
	pero muy más también ya bien sí gracias hola buenos buenas todo está estoy
	estás son soy eres hay tiene tengo hacer'''),
  'pt': _set('''o os um uma do da dos das em na é que não com para por mas mais
	muito também já bem sim obrigado obrigada olá oi tudo está estou você vocês
	eu ele ela nós eles isso isto aqui ser tem tenho fazer como quando onde'''),
  'it': _set('''il lo la gli di del della dei è che non per con ma più anche già
	bene sì grazie ciao buongiorno tutto sono sei siamo ho hai ha abbiamo io lui
	lei noi voi loro questo questa quello come quando dove perché molto cosa
	fare essere'''),
  'pl': _set('''w z na nie się że jest jak co ale tak czy od po za dla mi mnie
	ci ty ja my wy ona oni już jeszcze bardzo dziękuję dzięki cześć dzień
	dobry proszę tylko może być mam masz są jestem jesteś tam też'''),
  'tr': _set('''bir ve bu da ne için ben sen çok var yok mi mı mu mü evet hayır
	teşekkürler teşekkür merhaba nasıl değil ama gibi daha sonra şimdi burada
	neden ile her şey iyi güzel misin musun benim senin biz siz onlar'''),
  'id': _set('''yang dan di ini itu tidak saya kamu aku apa ada untuk dengan ke
	dari akan sudah bisa juga tapi terima kasih selamat pagi baik sama dia
	mereka kita kami belum lagi sangat bagaimana kenapa mau'''),
  'vi': _set('''không tôi bạn là có và của được này cảm ơn xin chào những một
	người đi với cho anh em'''),
  'nl': _set('''de het een en is niet ik je dat van op te zijn wat maar met voor
	ook hij zij wij jij er naar dan nog wel geen bedankt hallo goed heel hebben
	heb heeft kan'''),
};

// common words of russian, ukrainian and bulgarian with none of their own
// letters in them
final Map<String, Set<String>> _cyrCommon = {
  // words both write the same (завтра, там, тут, буду) are in neither
  'ru': _set('''как что да нет привет спасибо хорошо меня тебя он она они мы
	вы вот уже только если или где когда почему можно надо очень сейчас
	сегодня пожалуйста мне тебе его ее здравствуйте был была будет может могу
	какой какая какое с еще тоже чтобы иду жду говорит можешь будешь хочешь
	делаешь делать потом теперь куда вечера спать позвонить ничего давай
	пока тогда'''),
  'uk': _set('''як що та але це ні мене тебе дякую будь ласка привіт чому коли
	де зараз сьогодні його вона вони ми ви мені тобі можна треба дуже який
	яка яке якого з вже ще ти теж також бо чи щоб куди тому нема йду йти
	чекаю вдома добре гарно гарний гарного каже кажу можеш будеш хочеш робиш
	робити котра трохи тепер вечора спати подзвони подзвонити'''),
  'bg': _set('''какво съм сме сте ще аз това тази този искам благодаря здравей
	много защо кога къде как да'''),
};

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
