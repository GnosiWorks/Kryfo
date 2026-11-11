// SPDX-License-Identifier: GPL-3.0-or-later
// a reader of traditional chinese sees a transcript in traditional
// characters, taiwan's or hong kong's forms, while the kept words stay as
// the model wrote them; anyone else, and any other language, as heard
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/hant.dart';
import 'package:kryfo/voice/chat_transcripts.dart';
import 'package:kryfo/voice/hant_reader.dart';
import 'package:kryfo/voice/ui/transcript_line.dart';

import 'voice_tx_fakes.dart';

// the shipped tables, read from the checkout as the asset bundle would
Future<HantConverter> _tables() async {
  String read(String a) => utf8.decode(gzip.decode(File(a).readAsBytesSync()));
  return HantConverter.parse(
    read(HantConverter.charsAsset),
    read(HantConverter.phrasesAsset),
    tw: read(HantConverter.twAsset),
    hk: read(HantConverter.hkAsset),
  );
}

const _hans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
const _hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
const _tw = Locale('zh', 'TW');
const _hk = Locale('zh', 'HK');
const _cn = Locale('zh', 'CN');
const _en = Locale('en', 'US');

void main() {
  group('who reads traditional', () {
    test('kryfo in traditional chinese: taiwan\'s forms, hong kong\'s on a '
        'hong kong phone', () {
      expect(readerHant(app: 'zh_Hant', system: [_en]), HantForm.tw);
      expect(readerHant(app: 'zh_Hant', system: [_tw]), HantForm.tw);
      expect(readerHant(app: 'zh_Hant', system: [_hk]), HantForm.hk);
      expect(readerHant(app: 'zh_Hant', system: [_cn]), HantForm.tw);
    });

    test('kryfo in another language: the phone\'s first chinese decides', () {
      expect(readerHant(app: 'en', system: [_en, _tw]), HantForm.tw);
      expect(readerHant(app: 'en', system: [_hant]), HantForm.tw);
      expect(
        readerHant(
          app: 'de',
          system: [
            const Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hant',
              countryCode: 'HK',
            ),
          ],
        ),
        HantForm.hk,
      );
      expect(
        readerHant(app: 'en', system: [const Locale('zh', 'MO')]),
        HantForm.hk,
      );
      expect(readerHant(app: 'en', system: [_cn, _tw]), HantForm.none);
      expect(readerHant(app: 'en', system: [_hans]), HantForm.none);
      expect(
        readerHant(app: 'en', system: [const Locale('zh')]),
        HantForm.none,
      );
      expect(readerHant(app: 'en', system: [_en]), HantForm.none);
      // simplified written in taiwan is still simplified
      expect(
        readerHant(
          app: 'en',
          system: [
            const Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hans',
              countryCode: 'TW',
            ),
          ],
        ),
        HantForm.none,
      );
    });

    test('kryfo in simplified chinese reads simplified', () {
      expect(readerHant(app: 'zh', system: [_tw]), HantForm.none);
      expect(readerHant(app: 'zh', system: [_hk]), HantForm.none);
    });
  });

  group('the words shown', () {
    Future<String> shownAs(
      HantForm form,
      String text, [
      String lang = 'zh',
    ]) async {
      final f = fakeVoiceHub(hant: _tables, reader: () => form);
      f.hub.shown(text, lang);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return f.hub.shown(text, lang);
    }

    test(
      'real mandarin, one simplified character to many traditional',
      () async {
        const tw = {
          '我们明天在车站见吧': '我們明天在車站見吧',
          '她的头发很长': '她的頭髮很長',
          '我们发展经济': '我們發展經濟',
          '后来他回来了': '後來他回來了',
          '皇后来了': '皇后來了',
          '衣服很干净': '衣服很乾淨',
          '他是干部': '他是幹部',
          '我买了一只表': '我買了一隻表',
          '几点钟了': '幾點鐘了',
          '这里面积很大': '這裡面積很大',
          '我想吃面条': '我想吃麵條',
          '这个周末一起吃饭吧': '這個週末一起吃飯吧',
          '老板发烧了': '老闆發燒了',
          '为什么不说话': '為什麼不說話',
        };
        for (final e in tw.entries) {
          expect(await shownAs(HantForm.tw, e.key), e.value, reason: e.key);
        }
        // hong kong's forms where they differ
        expect(await shownAs(HantForm.hk, '为什么不说话'), '為什麼不説話');
        expect(await shownAs(HantForm.hk, '他们在里面等你'), '他們在裏面等你');
      },
    );

    test(
      'a simplified reader, or words in another language, as heard',
      () async {
        expect(await shownAs(HantForm.none, '她的头发很长'), '她的头发很长');
        // japanese kanji are no simplified chinese
        expect(await shownAs(HantForm.tw, '区役所に行きます', 'ja'), '区役所に行きます');
        expect(
          await shownAs(HantForm.tw, 'see you at three', 'en'),
          'see you at three',
        );
      },
    );

    test('tables that could not be read are asked for again', () async {
      var reads = 0;
      final f = fakeVoiceHub(
        hant: () {
          reads++;
          if (reads == 1) return Future.error(StateError('no asset'));
          return _tables();
        },
        reader: () => HantForm.tw,
      );
      expect(f.hub.shown('头发', 'zh'), '头发');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(f.hub.shown('头发', 'zh'), '头发');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(f.hub.shown('头发', 'zh'), '頭髮');
      expect(reads, 2);
    });

    test('the lock lets the tables go; they are read again after', () async {
      var reads = 0;
      final f = fakeVoiceHub(
        hant: () {
          reads++;
          return _tables();
        },
        reader: () => HantForm.tw,
      );
      f.hub.shown('头发', 'zh');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(f.hub.shown('头发', 'zh'), '頭髮');
      f.hub.lockedOut();
      f.hub.unlocked();
      expect(f.hub.shown('头发', 'zh'), '头发');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(f.hub.shown('头发', 'zh'), '頭髮');
      expect(reads, 2);
    });
  });

  testWidgets('the transcript under a note: traditional on screen, '
      'simplified kept', (t) async {
    final f = fakeVoiceHub(hant: _tables, reader: () => HantForm.tw);
    await f.hub.ready();
    final c = ChatTranscripts(f.hub, 'heron');
    addTearDown(c.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 304,
            child: VoiceTranscript(
              chat: c,
              uid: 'u1',
              path: '/n/u1.ogg',
              isOut: false,
              translation: null,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(() => c.open('u1', '/n/u1.ogg'));
    await t.pump();
    f.runner.jobs.last
      ..say('她的头发很长')
      ..end('zh');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('她的頭髮很長', findRichText: true), findsOneWidget);
    expect(find.textContaining('头发', findRichText: true), findsNothing);
    expect(c.of('u1').text, '她的头发很长');
    final kept = await t.runAsync(() => f.store.kept('heron'));
    expect(kept!['u1']!.text, '她的头发很长');
  });
}
