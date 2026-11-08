// SPDX-License-Identifier: GPL-3.0-or-later
// a message is offered a translation when it is in a language the person
// does not read and there is a model for the way across. the app's
// language always counts as read; unsure and mixed guesses are left alone
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/foreign.dart';
import 'package:kryfo/translate/hant.dart' show HantForm;

import 'translate_fakes.dart';

const _cat = builtInCatalog;

Offer? _offer(
  String text, {
  String app = 'en',
  String chosen = '',
  List<String> mine = const [],
  TranslateCatalog cat = _cat,
}) => offerFor(
  detectLanguage(text),
  cat,
  appLang: app,
  chosen: chosen,
  mine: readLangs(app, mine),
);

void main() {
  test('chinese to an english reader, english to a chinese one', () {
    expect(_offer('你好，我们明天见吧'), const Offer('zh', 'en'));
    expect(
      _offer('Are you coming tomorrow?', app: 'zh'),
      const Offer('en', 'zh'),
    );
    expect(
      _offer('Are you coming tomorrow?', app: 'zh_Hant'),
      const Offer('en', 'zh', 'en', HantForm.tw),
    );
  });

  test('every language with packs is offered, through english too', () {
    // what the developer's phone showed nothing for: an english and german
    // reader, russian and arabic packs on the phone
    const mine = ['de'];
    expect(
      _offer('я позову больше людей в этот мессенджер', mine: mine),
      const Offer('ru', 'en'),
    );
    expect(
      _offer('مرحبا، كيف حالك اليوم؟', mine: mine),
      const Offer('ar', 'en'),
    );
    expect(
      _offer('Hallo, wir sehen uns morgen am Bahnhof', mine: mine),
      isNull,
    );
    expect(
      _offer('Merci, cela me fait plaisir', mine: mine),
      const Offer('fr', 'en'),
    );
    // a german app: russian into german, through english
    expect(
      _offer('Привет, увидимся завтра на вокзале', app: 'de'),
      const Offer('ru', 'de'),
    );
    expect(_cat.route('ru', 'de'), [('ru', 'en'), ('en', 'de')]);
    expect(
      _offer('سلام، حالت چطوره؟ فردا می‌بینمت', app: 'fr'),
      const Offer('fa', 'fr'),
    );
  });

  test('a language the person reads is not foreign', () {
    expect(_offer('Are you coming tomorrow?'), isNull);
    expect(_offer('你好，我们明天见吧', mine: ['zh']), isNull);
    // traditional and simplified are one language here
    expect(_offer('我們明天見吧，這個問題還沒說', mine: ['zh_Hant']), isNull);
    expect(_offer('我們明天見吧，這個問題還沒說', app: 'zh'), isNull);
  });

  test('traditional chinese says so, and uses the chinese model', () {
    final o = _offer('我們明天見吧，這個問題還沒說')!;
    expect(o.from, 'zh');
    expect(o.seen, 'zh_hant');
  });

  test('unsure, mixed or modelless guesses are left alone', () {
    expect(_offer('ok'), isNull);
    expect(_offer('明天のミーティングは何時ですか'), isNull);
    expect(isForeign(const LangGuess('zh', 0.5), {'en'}), isFalse);
    expect(isForeign(const LangGuess('zh', 0.9), {'en'}), isTrue);
    expect(isForeign(LangGuess.none, {'en'}), isFalse);
  });

  test('the target: the chosen one, the app\'s, or english when read', () {
    // a german reader with chinese alone: no way into german, and english
    // is not theirs
    expect(_offer('你好，我们明天见吧', app: 'de', cat: zhCatalog), isNull);
    // unless they read english too
    expect(
      _offer('你好，我们明天见吧', app: 'de', mine: ['en'], cat: zhCatalog),
      const Offer('zh', 'en'),
    );
    // a chosen target wins over the app's
    expect(
      _offer('你好，我们明天见吧', app: 'de', chosen: 'en'),
      const Offer('zh', 'en'),
    );
    // with every language: into german, through english
    expect(_offer('你好，我们明天见吧', app: 'de'), const Offer('zh', 'de'));
  });

  test('routes go through english when both legs are there', () {
    const cat = TranslateCatalog(
      base: 'https://example.invalid/',
      packs: [
        LangBundle(
          id: 'zh',
          gz: 1,
          disk: 1,
          pairs: ['zh-en', 'en-zh'],
          dirs: ['a', 'b'],
        ),
        LangBundle(
          id: 'de',
          gz: 1,
          disk: 1,
          pairs: ['de-en', 'en-de'],
          dirs: ['c', 'd'],
        ),
      ],
    );
    expect(cat.route('zh', 'de'), [('zh', 'en'), ('en', 'de')]);
    expect(cat.bundlesFor(cat.route('zh', 'de')!).map((b) => b.id), [
      'zh',
      'de',
    ]);
    expect(cat.route('zh', 'fr'), isNull);
    expect(cat.route('zh', 'zh'), isNull);
  });

  test('the built-in catalog is the engine manifest', () {
    final m =
        jsonDecode(File('../engine/translate/models.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(_cat.base, m['base']);
    // the engine's size classes (engine/translate/pad.go)
    const classes = [48 << 20, 96 << 20];
    final ids = <String>[];
    for (final p in m['pairs'] as List) {
      final id = '${p['from']}-${p['to']}';
      ids.add(id);
      var gz = 0, disk = 0;
      for (final f in p['files'] as List) {
        gz += f['gzSize'] as int;
        disk += f['size'] as int;
      }
      final b = _cat.bundle(id)!;
      final wire = classes.firstWhere(
        (c) => gz <= c,
        orElse: () => (gz + classes.last - 1) ~/ classes.last * classes.last,
      );
      expect(b.gz, wire, reason: id);
      expect(b.disk, disk, reason: id);
      expect(b.pairs, [id]);
      expect(b.dirs, ['${p['from']}${p['to']}-${p['arch']}']);
    }
    expect([for (final b in _cat.packs) b.id]..sort(), ids..sort());
    // every app language both ways; traditional chinese not apart
    expect(_cat.languages.toSet(), {
      'ar', 'de', 'es', 'fa', 'fr', 'hi', 'id', 'it', 'pl', 'pt', 'ru', //
      'tr', 'uk', 'vi', 'zh',
    });
    for (final l in _cat.languages) {
      expect(_cat.waysOf(l), LangWays.both, reason: l);
    }
  });

  test('the engine catalog parses, and junk does not', () {
    final c = TranslateCatalog.parse(
      '{"base":"https://h.example/","langs":[{"lang":"zh","gz":5,"disk":9,'
      '"pairs":["zh-en","en-zh"],"dirs":["x","y"]}]}',
    )!;
    expect(c.base, 'https://h.example/');
    expect(c.bundle('zh')!.disk, 9);
    expect(TranslateCatalog.parse('error: no'), isNull);
  });
}
