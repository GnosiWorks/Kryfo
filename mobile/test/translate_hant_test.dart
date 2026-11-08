// SPDX-License-Identifier: GPL-3.0-or-later
// readers of traditional chinese get the models' simplified output in
// traditional characters, with opencc's tables
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/foreign.dart';
import 'package:kryfo/translate/hant.dart';

import 'translate_fakes.dart';

String _gz(String p) => utf8.decode(gzip.decode(File(p).readAsBytesSync()));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a phrase wins over its characters', () {
    final c = HantConverter.parse('发\t發 髮\n头\t頭\n长\t長\n', '头发\t頭髮\n');
    expect(c.convert('头发很长'), '頭髮很長');
    expect(c.convert('发'), '發');
    // what the tables do not name stays
    expect(c.convert('hello 你'), 'hello 你');
    expect(c.convert(''), '');
  });

  test('the shipped tables', () async {
    final c = await HantConverter.load();
    expect(c.convert('头发'), '頭髮');
    expect(c.convert('后来'), '後來');
    expect(c.convert('皇后'), '皇后');
    expect(c.convert('干净'), '乾淨');
    expect(c.convert('我们明天见吧'), '我們明天見吧');
    expect(c.convert('Hello, 世界'), 'Hello, 世界');
    // taiwan's forms, as the app's own traditional strings use
    expect(c.convert('为什么'), '為什麼');
    expect(c.convert('里面'), '裡面');
    expect(c.convert('面条'), '麵條');
    // hong kong's
    expect(c.convert('为什么', HantForm.hk), '為什麼');
    expect(c.convert('里面', HantForm.hk), '裏面');
    expect(c.convert('台湾', HantForm.hk), '台灣');
    // opencc's standard forms, before either
    expect(c.convert('为什么', HantForm.none), '爲什麼');
    // the tables are opencc's own, unchanged
    final chars = _gz('assets/opencc/STCharacters.txt.gz');
    expect(chars.split('\n').where((l) => l.contains('\t')).length, 3980);
  });

  test('an offer into chinese says when the reader reads traditional', () {
    const g = LangGuess('en', 1);
    Offer? offer(String app, {String chosen = ''}) => offerFor(
      g,
      builtInCatalog,
      appLang: app,
      chosen: chosen,
      mine: readLangs(app, const []),
    );
    expect(offer('zh_Hant')!.hant, HantForm.tw);
    expect(offer('zh')!.hant, HantForm.none);
    expect(offer('de', chosen: 'zh_hant')!.hant, HantForm.tw);
    expect(offer('de', chosen: 'zh_HK')!.hant, HantForm.hk);
    expect(offer('zh_Hant', chosen: 'zh')!.hant, HantForm.none);
    // the same direction in another script is another translation
    expect(offer('zh_Hant') == offer('zh'), isFalse);
  });

  test('the hub writes traditional for a traditional reader', () async {
    final f = fakeHub(
      installed: true,
      app: 'zh_Hant',
      words: {'Hair is long': '头发很长', 'Why is it in there': '为什么在里面'},
    );
    await f.hub.ready();
    final o = f.hub.offer('Hair is long')!;
    expect(o.to, 'zh');
    expect(await f.hub.translate('Hair is long', o), '頭髮很長');
    expect(await f.hub.translate('Why is it in there', o), '為什麼在裡面');

    final s = fakeHub(
      installed: true,
      app: 'zh',
      words: {'Hair is long': '头发很长'},
    );
    await s.hub.ready();
    final so = s.hub.offer('Hair is long')!;
    expect(await s.hub.translate('Hair is long', so), '头发很长');
  });
}
