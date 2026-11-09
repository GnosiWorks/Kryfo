// SPDX-License-Identifier: GPL-3.0-or-later
// every language in the catalog, both ways with english and to every other
// language through english, in one process with one worker, as a phone
// that is never restarted asks for them. the routes run always; the real
// models run where the host library and the packs are there:
//
//   KRYFO_TRANSLATE_LIB=<host libkryfo_translate.so>
//   KRYFO_TRANSLATE_MODELS=<dir that ktmodels fetch filled>
//
// with the host engine built (tool/host_engine.sh) for the catalog and
// the configs the phone gets
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/bergamot_ffi.dart';
import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/downloads.dart';
import 'package:kryfo/translate/engine_bridge.dart';
import 'package:kryfo/translate/foreign.dart';
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/settings.dart';

import 'host_engine.dart';
import 'translate_fakes.dart';

// one everyday line per language, long enough to be offered
const said = {
  'en':
      'Hello, how are you? I will come to your house tomorrow evening after work.',
  'ar': 'مرحبا، كيف حالك؟ سأزورك غدا في المساء بعد العمل.',
  'de':
      'Hallo, wie geht es dir? Ich komme morgen Abend nach der Arbeit zu dir nach Hause.',
  'es':
      'Hola, ¿cómo estás? Mañana por la noche iré a tu casa después del trabajo.',
  'fa': 'سلام، حالت چطور است؟ من فردا عصر بعد از کار به خانه تو می‌آیم.',
  'fr':
      'Bonjour, comment ça va ? Je viendrai chez toi demain soir après le travail.',
  'hi': 'नमस्ते, आप कैसे हैं? मैं कल शाम को काम के बाद आपके घर आऊंगा।',
  'id':
      'Halo, apa kabar? Besok malam saya akan datang ke rumah kamu setelah bekerja.',
  'it': 'Ciao, come stai? Domani sera verrò a casa tua dopo il lavoro.',
  'pl': 'Cześć, jak się masz? Jutro wieczorem przyjdę do ciebie po pracy.',
  'pt':
      'Olá, como você está? Amanhã à noite eu vou à sua casa depois do trabalho.',
  'ru': 'Привет, как у тебя дела? Я приду к тебе домой завтра вечером после работы.',
  'tr': 'Merhaba, nasılsın? Yarın akşam işten sonra senin evine geleceğim.',
  'uk': 'Привіт, як твої справи? Я прийду до тебе додому завтра ввечері після роботи.',
  'vi':
      'Xin chào, bạn có khỏe không? Tối mai tôi sẽ đến nhà bạn sau khi làm việc.',
  'zh': '你好，你今天怎么样？我明天晚上下班以后去你家。',
};
const _hant = '你好，你今天怎麼樣？我明天晚上下班以後去你家。';

// what a line in [lang] is written in, for the languages the guess cannot
// tell from a neighbour with the same letters
bool _inScript(String lang, String s) {
  bool any(int lo, int hi) => s.runes.any((r) => r >= lo && r <= hi);
  return switch (lang) {
    'ar' || 'fa' => any(0x0600, 0x06ff),
    'ru' || 'uk' => any(0x0400, 0x04ff),
    'hi' => any(0x0900, 0x097f),
    'zh' || 'zh_hant' => any(0x4e00, 0x9fff),
    _ => !any(0x0400, 0x04ff) && !any(0x0600, 0x06ff) && !any(0x4e00, 0x9fff),
  };
}

TranslationHub _hub(TranslateCatalog c, BergamotTranslator t, String app) {
  final backend = FakeBackend(c);
  for (final b in c.packs) {
    backend.finish(b.id);
  }
  backend.status = const FetchStatus('idle');
  backend.statuses.clear();
  late final TranslationHub hub;
  final downloads = ModelDownloads(
    backend: backend,
    onWifi: () async => true,
    wifiOnly: () => false,
    poll: const Duration(milliseconds: 100),
  );
  hub = TranslationHub(
    store: MemoryTranslateStore(const TranslateSettings(wifiOnly: false)),
    translator: t,
    downloads: downloads,
    catalog: c,
    appLang: () => app,
  );
  return hub;
}

void main() {
  const c = builtInCatalog;
  final langs = c.languages;

  group('routes', () {
    test('every catalog language goes both ways with english', () {
      expect(langs.toSet(), said.keys.toSet()..remove('en'));
      for (final l in langs) {
        expect(c.waysOf(l), LangWays.both, reason: l);
        expect(c.route(l, 'en'), [(l, 'en')], reason: l);
        expect(c.route('en', l), [('en', l)], reason: l);
        expect(c.packsOf(l).map((b) => b.id).toSet(), {'$l-en', 'en-$l'});
      }
    });

    test('every pair of languages goes through english, both ways', () {
      for (final a in langs) {
        for (final b in langs) {
          if (a == b) continue;
          expect(c.route(a, b), [(a, 'en'), ('en', b)], reason: '$a-$b');
          expect(
            c.bundlesFor(c.route(a, b)!).map((p) => p.id),
            ['$a-en', 'en-$b'],
            reason: '$a-$b',
          );
        }
      }
    });

    test('every line is guessed as its language and offered to english', () {
      final hub = fakeHub(installed: true, catalog: c).hub;
      for (final l in langs) {
        expect(detectLanguage(said[l]!).lang, l, reason: l);
        expect(hub.offer(said[l]!)?.from, l, reason: l);
        expect(hub.offer(said[l]!)?.to, 'en', reason: l);
      }
      expect(detectLanguage(said['en']!).lang, 'en');
    });
  });

  final lib = Platform.environment['KRYFO_TRANSLATE_LIB'];
  final dir = Platform.environment['KRYFO_TRANSLATE_MODELS'];
  final why = lib == null || dir == null
      ? 'needs KRYFO_TRANSLATE_LIB and KRYFO_TRANSLATE_MODELS'
      : !File(lib).existsSync()
      ? 'no library at $lib'
      : !loadHostEngine()
      ? 'needs the host engine (tool/host_engine.sh)'
      : null;

  group('the real models', skip: why, () {
    final engine = FfiTranslateEngine();
    late BergamotTranslator t;
    late TranslationHub hub;
    final log = <String>[];

    setUpAll(() {
      t = BergamotTranslator(
        lib: lib!,
        config: (f, to) => engine.config(f, to, dir!),
        installed: (_, _) => true,
      );
      hub = _hub(c, t, 'en');
    });

    tearDownAll(() async {
      await t.close();
      final out = Platform.environment['KRYFO_TRANSLATE_LOG'];
      if (out != null) File(out).writeAsStringSync('${log.join('\n')}\n');
    });

    // every line's english, so a pivot that stopped there shows
    final viaEnglish = <String>{};

    Future<String> say(String text, String from, String to) async {
      final out = await hub.translate(text, Offer(from, to));
      log.add('$from-$to\t$out');
      if (to == 'en') viaEnglish.add(out);
      return out;
    }

    void looksLike(String out, String to, String step) {
      expect(out.trim(), isNotEmpty, reason: step);
      expect(_inScript(to, out), isTrue, reason: '$step: $out');
      // every line opens with a question: a lost sentence shows here
      expect(out, contains(RegExp('[?؟？]')), reason: '$step lost one: $out');
      // the guess tells the latin languages apart; a short or odd line
      // may come back unsure, never as another language
      final g = detectLanguage(out).lang;
      // italian and others share words with english: an english guess is
      // fine as long as the line is not the english step itself
      if (g.isEmpty || (g == 'en' && to != 'en' && !viaEnglish.contains(out))) {
        return;
      }
      expect(baseLang(g), baseLang(to), reason: '$step: $out');
    }

    test('the engine names the same packs as the app', () async {
      final got = engine.catalog();
      expect(got, isNotNull);
      expect(got!.packs.map((b) => b.id), c.packs.map((b) => b.id));
      for (final b in got.packs) {
        expect(await engine.installed(b.id, dir!), isTrue, reason: b.id);
      }
    });

    test('every direction with english, one after another', () async {
      for (final l in langs) {
        looksLike(await say(said[l]!, l, 'en'), 'en', '$l-en');
        looksLike(await say(said['en']!, 'en', l), l, 'en-$l');
      }
      // the traditional packs, not offered, still open beside the rest
      final into = await t.translate(_hant, from: 'zh_hant', to: 'en');
      log.add('zh_hant-en\t$into');
      looksLike(into, 'en', 'zh_hant-en');
      final back = await t.translate(said['en']!, from: 'en', to: 'zh_hant');
      log.add('en-zh_hant\t$back');
      expect(_inScript('zh', back), isTrue, reason: back);
    }, timeout: const Timeout(Duration(minutes: 20)));

    test('every pair through english, both ways', () async {
      for (final a in langs) {
        for (final b in langs) {
          if (a == b) continue;
          final out = await say(said[a]!, a, b);
          expect(viaEnglish, isNot(contains(out)), reason: '$a-$b: $out');
          looksLike(out, b, '$a-$b');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 60)));

    test('a reader of another language is offered the way there', () async {
      for (final app in ['de', 'ar', 'zh']) {
        final h = _hub(c, t, app);
        await h.ready();
        for (final l in langs) {
          if (l == app) continue;
          final o = h.offer(said[l]!);
          expect(o, Offer(l, app), reason: '$app reads $l');
          expect(await h.blockFor(o!), isNull, reason: '$app reads $l');
          looksLike(await h.translate(said[l]!, o), app, '$l-$app offered');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 20)));

    test('after the worker closes every direction opens again', () async {
      await hub.away();
      looksLike(await say(said['ru']!, 'ru', 'ar'), 'ar', 'ru-ar again');
      looksLike(await say(said['zh']!, 'zh', 'ru'), 'ru', 'zh-ru again');
    });

    test('the background mid-pivot lets both legs finish first', () async {
      await hub.away();
      final out = say(said['de']!, 'de', 'zh');
      // the app goes to the background while the first leg runs
      await Future<void>.delayed(Duration.zero);
      await hub.away();
      expect(t.idle.awayPending, isTrue);
      looksLike(await out, 'zh', 'de-zh mid-pivot');
      expect(t.idle.awayPending, isFalse);
      expect(t.idle.busy, 0);
    });
  });
}
