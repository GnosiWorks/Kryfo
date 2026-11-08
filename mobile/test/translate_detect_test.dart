// SPDX-License-Identifier: GPL-3.0-or-later
// the language guess, and no guess rather than a wrong one
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/detect.dart';

void main() {
  test('scripts, mixes, links and short words', () {
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
      'Ich komme morgen nicht ins Büro': 'de',
      'Je ne sais pas encore': 'fr',
      'Привет, как дела?': 'ru',
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

  test('every language with packs', () {
    const cases = {
      // russian and ukrainian, by letters and by words
      'Привет, увидимся завтра на вокзале': 'ru',
      'вы реальный человек или просто бот?': 'ru',
      'я позову больше людей в этот мессенджер': 'ru',
      'у вас есть версия для мак?': 'ru',
      'именно интел процессор': 'ru',
      'Привіт, побачимося завтра на вокзалі': 'uk',
      'Як справи, що робиш?': 'uk',
      'Дякую, все добре': 'uk',
      // arabic and persian
      'مرحبا، كيف حالك اليوم؟': 'ar',
      'شكرا جزيلا على المساعدة': 'ar',
      'سلام، حالت چطوره؟ فردا می‌بینمت': 'fa',
      'من فردا به دانشگاه می‌روم': 'fa',
      'नमस्ते, आप कैसे हैं? कल मिलते हैं': 'hi',
      // latin
      'Was machst du heute Abend?': 'de',
      'Hallo, wir sehen uns morgen am Bahnhof': 'de',
      'Merci, cela me fait plaisir': 'fr',
      "Bonjour, comment ça va aujourd'hui ?": 'fr',
      '¿Dónde estás? Te espero en la estación': 'es',
      'Hola, gracias por todo, nos vemos mañana': 'es',
      'Vamos a la playa mañana': 'es',
      'Obrigado, tudo bem com você?': 'pt',
      'Ciao, come stai? Ci vediamo domani': 'it',
      'Dziękuję bardzo, do zobaczenia jutro': 'pl',
      'Merhaba, nasılsın? Yarın görüşürüz': 'tr',
      'Saya tidak tahu apa yang terjadi': 'id',
      'Xin chào, bạn có khỏe không?': 'vi',
      // english stays english
      'I thought it was a few people who leaked it': 'en',
      'Was it you who sent the photo?': 'en',
    };
    for (final e in cases.entries) {
      expect(detectLanguage(e.key).lang, e.value, reason: e.key);
    }
  });

  test('no guess for a language without packs, or one too unsure', () {
    const cases = [
      // bulgarian, serbian, belarusian, kazakh
      'Благодаря, ще се видим утре',
      'Хвала, видимо се сутра ујутру',
      'Дзякуй, убачымся заўтра',
      'Рақмет, ертең кездесеміз',
      // urdu, marathi
      'آپ کیسے ہیں؟ کل ملتے ہیں',
      'तुम्ही कसे आहात? उद्या भेटूळ',
      // dutch, czech, swedish, romanian, hungarian
      'Hallo, ik zie je morgen op het station',
      'Děkuji, uvidíme se zítra ráno',
      'Tack så mycket, vi ses i morgon',
      'Mulțumesc, ne vedem mâine dimineață',
      'Köszönöm szépen, holnap találkozunk',
      // greek, hebrew, thai
      'Ευχαριστώ, τα λέμε αύριο',
      'תודה, נתראה מחר',
      'ขอบคุณครับ แล้วพบกันพรุ่งนี้',
      // russian and ukrainian letters both
      'привіт, ты где',
    ];
    for (final s in cases) {
      expect(detectLanguage(s).lang, '', reason: s);
    }
  });

  test('a mention or a link is not counted', () {
    expect(detectLanguage('@wren 你好').lang, 'zh');
    expect(detectLanguage('www.example.org').lang, '');
  });
}
