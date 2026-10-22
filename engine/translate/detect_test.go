// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import "testing"

func TestDetect(t *testing.T) {
	cases := map[string]string{
		"你好，我们明天见吧":                               "zh",
		"这个问题我还没想好怎么说":                            "zh",
		"我們明天見吧，這個問題還沒說":                          "zh_hant",
		"今天天气很好":                                  "zh",
		"明天のミーティングは何時ですか":                         "ja",
		"오늘 저녁에 시간 있어요?":                          "ko",
		"Are you coming to the meeting tomorrow?": "en",
		"thanks!":                    "en",
		"I'll be there in 5 minutes": "en",
		"我在 https://example.org/a/b/c/d/e 看到的": "zh",
		"ok 好的，我知道了":                           "zh",
		"Ich komme morgen nicht ins Büro":      "",
		"Je ne sais pas encore":                "",
		"Привет, как дела?":                    "",
		"ok":                                   "",
		"lol":                                  "",
		"👍👍":                                   "",
		"12345 !!!":                            "",
		"":                                     "",
		"https://example.org/only/a/link":      "",
	}
	for in, want := range cases {
		if got := Detect(in); got.Lang != want {
			t.Errorf("%q: %q (%.2f), want %q", in, got.Lang, got.Share, want)
		}
	}
}

func TestDetectShare(t *testing.T) {
	if g := Detect("我们走吧"); g.Share != 1 {
		t.Fatalf("all chinese: %v", g)
	}
	g := Detect("我们走吧 see you at the station")
	if g.Lang == "" || g.Share >= 1 || g.Share <= 0 {
		t.Fatalf("mixed: %v", g)
	}
}

func TestScriptPairs(t *testing.T) {
	for r := range simpOnly {
		if tradOnly[r] {
			t.Errorf("%c is on both sides", r)
		}
	}
	if len(simpOnly) < 80 || len(simpOnly) != len(tradOnly) {
		t.Fatalf("%d simplified, %d traditional", len(simpOnly), len(tradOnly))
	}
}
