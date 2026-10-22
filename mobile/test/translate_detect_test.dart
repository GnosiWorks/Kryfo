// SPDX-License-Identifier: GPL-3.0-or-later
// the dart guess says what the engine's says (engine/translate/detect_test.go
// has the same cases), and nothing rather than a wrong guess
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/detect.dart';

void main() {
  test('the engine cases', () {
    const cases = {
      '你好，我们明天见吧': 'zh',
      '这个问题我还没想好怎么说': 'zh',
      '我們明天見吧，這個問題還沒說': 'zh_hant',
      '今天天气很好': 'zh',
      '明天のミーティングは何時ですか': 'ja',
      '오늘 저녁에 시간 있어요?': 'ko',
      'Are you coming to the meeting tomorrow?': 'en',
      'thanks!': 'en',
      "I'll be there in 5 minutes": 'en',
      '我在 https://example.org/a/b/c/d/e 看到的': 'zh',
      'ok 好的，我知道了': 'zh',
      'Ich komme morgen nicht ins Büro': '',
      'Je ne sais pas encore': '',
      'Привет, как дела?': '',
      'ok': '',
      'lol': '',
      '👍👍': '',
      '12345 !!!': '',
      '': '',
      'https://example.org/only/a/link': '',
    };
    for (final e in cases.entries) {
      expect(detectLanguage(e.key).lang, e.value, reason: e.key);
    }
  });

  test('share: whole, and part of a mixed message', () {
    expect(detectLanguage('我们走吧').share, 1);
    final g = detectLanguage('我们走吧 see you at the station');
    expect(g.lang, isNotEmpty);
    expect(g.share, greaterThan(0));
    expect(g.share, lessThan(1));
  });

  test('a mention or a link is not counted', () {
    expect(detectLanguage('@wren 你好').lang, 'zh');
    expect(detectLanguage('www.example.org').lang, '');
  });
}
