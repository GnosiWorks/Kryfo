// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"strings"
	"unicode"
)

// Guess is what Detect makes of a message. Lang is "" when it cannot tell
// or the language is one there is no model for yet. Share is how much of
// the message's letters back the guess, from 0 to 1.
type Guess struct {
	Lang  string
	Share float64
}

// Detect guesses the language of a chat message, for the languages there
// are models for: chinese (simplified "zh", traditional "zh_hant") and
// english, and japanese and korean so their kanji and hanja are not taken
// for chinese. it goes by script, then by a few common characters or
// words, which is enough to pick a model for a message of a few words; a
// general detector (cld2, fasttext) is for when more languages come.
func Detect(s string) Guess {
	var han, kana, hangul, latin, other int
	var trad, simp int
	for _, w := range strings.Fields(s) {
		if isLink(w) {
			continue
		}
		for _, r := range w {
			switch {
			case unicode.Is(unicode.Han, r):
				han++
				if tradOnly[r] {
					trad++
				} else if simpOnly[r] {
					simp++
				}
			case unicode.In(r, unicode.Hiragana, unicode.Katakana):
				kana++
			case unicode.Is(unicode.Hangul, r):
				hangul++
			case unicode.Is(unicode.Latin, r):
				latin++
			case unicode.IsLetter(r):
				other++
			}
		}
	}
	// weigh scripts in rough words: a chinese word is a character or two,
	// an english one about five letters
	cjk := float64(han+kana+hangul) / 1.5
	lat := float64(latin) / 5
	oth := float64(other) / 5
	all := cjk + lat + oth
	if all < 1 {
		return Guess{}
	}
	switch {
	case cjk >= lat && cjk >= oth:
		n := float64(han + kana + hangul)
		share := cjk / all
		switch {
		case kana > 0 && float64(kana) >= 0.1*n:
			return Guess{"ja", share}
		case hangul >= han:
			return Guess{"ko", share}
		case trad > simp:
			return Guess{"zh_hant", share}
		}
		return Guess{"zh", share}
	case lat >= oth:
		if englishish(s) {
			return Guess{"en", lat / all}
		}
	}
	return Guess{}
}

func isLink(w string) bool {
	w = strings.ToLower(w)
	return strings.HasPrefix(w, "http://") || strings.HasPrefix(w, "https://") ||
		strings.HasPrefix(w, "www.") || strings.HasPrefix(w, "@")
}

// latin text is taken for english when enough of its words are common
// english ones. a short message with none ("ok", "lol") stays unknown.
func englishish(s string) bool {
	words, hits := 0, 0
	for _, w := range strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return !unicode.IsLetter(r) && r != '\''
	}) {
		if !isASCIIWord(w) {
			if strings.IndexFunc(w, func(r rune) bool { return r >= 0x80 && unicode.Is(unicode.Latin, r) }) >= 0 {
				// accents and the like: some other latin language
				return false
			}
			// a word in another script is the other part of a mixed message
			continue
		}
		words++
		if englishWords[w] {
			hits++
		}
	}
	if words == 0 {
		return false
	}
	if words <= 3 {
		return hits >= 1
	}
	return float64(hits)/float64(words) >= 0.2
}

func isASCIIWord(w string) bool {
	for i := 0; i < len(w); i++ {
		if w[i] >= 0x80 {
			return false
		}
	}
	return true
}

var englishWords = setOf(strings.Fields(`the a an and or but if of to in on at for with from by
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
	i'm you're it's don't can't won't didn't isn't that's let's i'll i've`))

func setOf[T comparable](xs []T) map[T]bool {
	m := make(map[T]bool, len(xs))
	for _, x := range xs {
		m[x] = true
	}
	return m
}

// common characters written one way in simplified and another in
// traditional chinese, as pairs. only ones neither script also uses for
// something else, so a hit says which script it is.
const scriptPairs = `个個 们們 这這 说說 时時 国國 会會 来來 对對 为為 发發 过過 还還 没沒
	开開 关關 问問 题題 现現 实實 学學 习習 东東 车車 长長 门門 见見 话話 语語
	吗嗎 让讓 给給 谁誰 应應 该該 经經 进進 动動 种種 头頭 样樣 当當 从從 两兩
	机機 电電 买買 卖賣 钱錢 号號 书書 写寫 爱愛 觉覺 听聽 难難 边邊 带帶 气氣
	业業 线線 网網 页頁 级級 结結 点點 万萬 与與 产產 务務 员員 报報 场場 处處
	节節 计計 认認 识識 读讀 请請 谢謝 欢歡 乐樂 体體 华華 岁歲 广廣 记記 张張
	陈陳 刘劉 杨楊 黄黃 赵趙 吴吳 饭飯 馆館 鸡雞 鱼魚 鸟鳥 马馬 贵貴 钟鐘`

var simpOnly, tradOnly = func() (map[rune]bool, map[rune]bool) {
	s, t := map[rune]bool{}, map[rune]bool{}
	for _, p := range strings.Fields(scriptPairs) {
		r := []rune(p)
		if len(r) == 2 && r[0] != r[1] {
			s[r[0]] = true
			t[r[1]] = true
		}
	}
	return s, t
}()
