// SPDX-License-Identifier: GPL-3.0-or-later
// when a message is offered a translation at all: translation on, a
// language the person does not read and has not set to never offer, a
// confident guess and a few words. short texts, names, emoji and mixed
// scripts get nothing
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/foreign.dart';
import 'package:kryfo/translate/settings.dart';

import 'translate_fakes.dart';

const _zhLong = '我们明天在车站见吧';

void main() {
  test('the thresholds are named and where they were set', () {
    expect(kForeignShare, 0.6);
    expect(kOfferMinWords, 3.0);
  });

  test('rough words: characters count by the word, links and emoji not', () {
    expect(roughWords('see you tomorrow'), 3);
    expect(roughWords('你好'), closeTo(1.33, 0.01));
    expect(roughWords('我们明天在车站见吧'), 6);
    expect(roughWords('😀 🎉 👍👍'), 0);
    expect(roughWords('https://example.cn/路 @heron 12 345'), 0);
    expect(roughWords('ok 好的'), closeTo(2.33, 0.01));
  });

  group('for an english reader', () {
    final f = fakeHub();
    setUpAll(f.hub.ready);

    test('a few words of chinese are offered', () {
      final o = f.hub.offer(_zhLong);
      expect(o?.from, 'zh');
      expect(o?.to, 'en');
    });

    test('short texts are not', () {
      for (final s in ['你好', '你好吗', '谢谢你', '好的 ok', 'ok']) {
        expect(f.hub.offer(s), isNull, reason: s);
      }
    });

    test('names are not', () {
      for (final s in ['张伟', '王小明', 'Li Wei', 'Zhang Wei 张伟']) {
        expect(f.hub.offer(s), isNull, reason: s);
      }
    });

    test('emoji only is not', () {
      for (final s in ['😂😂😂', '🎉🎉🎉🎉🎉🎉', '❤️ 👍 🙏 😀']) {
        expect(f.hub.offer(s), isNull, reason: s);
      }
    });

    test('mixed scripts: offered only when one language clearly leads', () {
      // about as much english as chinese: the guess is not confident
      expect(detectLanguage('明天见 see you tomorrow').share, lessThan(0.6));
      expect(f.hub.offer('明天见 see you tomorrow'), isNull);
      // mostly chinese with a word of english
      expect(f.hub.offer('我们明天在车站见吧 ok'), isNotNull);
      // mostly english, which they read
      expect(f.hub.offer('see you at the station tomorrow 明天'), isNull);
    });

    test('a language there is no guess for is left alone', () {
      expect(f.hub.offer('Wir sehen uns morgen am Bahnhof'), isNull);
    });
  });

  test('a reader of chinese: english mixed in leads only when clear', () async {
    final f = fakeHub(app: 'zh');
    await f.hub.ready();
    expect(f.hub.offer('see you at the station tomorrow 明天')?.from, 'en');
    expect(f.hub.offer('明天见 see you tomorrow'), isNull);
    expect(f.hub.offer(_zhLong), isNull);
  });

  test('a language they read is not offered', () async {
    final f = fakeHub(settings: const TranslateSettings(mine: ['zh']));
    await f.hub.ready();
    expect(f.hub.offer(_zhLong), isNull);
  });

  test('never offer: off the offer until taken off the list', () async {
    final f = fakeHub();
    await f.hub.ready();
    await f.hub.neverFor('zh');
    expect(f.hub.offer(_zhLong), isNull);
    expect(f.store.settings.never, ['zh']);
    // not taken for a language they read
    expect(f.store.settings.mine, isEmpty);
    await f.hub.offerAgain('zh');
    expect(f.store.settings.never, isEmpty);
    expect(f.hub.offer(_zhLong), isNotNull);
  });

  test('translation off: nothing is offered, on: as before', () async {
    final f = fakeHub();
    await f.hub.ready();
    await f.hub.setOn(false);
    expect(f.store.settings.on, isFalse);
    expect(f.hub.offer(_zhLong), isNull);
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    expect(c.offer(_zhLong), isNull);
    expect(c.barOffer([_zhLong, _zhLong]), isNull);
    await f.hub.setOn(true);
    expect(f.hub.offer(_zhLong), isNotNull);
    expect(c.offer(_zhLong), isNotNull);
  });

  test('a chat applies the same rules', () async {
    final f = fakeHub();
    await f.hub.ready();
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    expect(c.offer(_zhLong), isNotNull);
    for (final s in ['你好', '张伟', '😂😂😂', '明天见 see you tomorrow']) {
      expect(c.offer(s), isNull, reason: s);
    }
  });

  test('on, never and always go through json', () {
    final s = TranslateSettings.fromJson(
      '{"on":false,"never":["zh","ja"],"always":["ko"]}',
    );
    expect(s.on, isFalse);
    expect(s.never, ['zh', 'ja']);
    final back = TranslateSettings.fromJson(jsonEncode(s.toJson()));
    expect(back.on, isFalse);
    expect(back.never, ['zh', 'ja']);
    // an older build's settings: on, nothing never offered
    final old = TranslateSettings.fromJson('{"mine":["de"]}');
    expect(old.on, isTrue);
    expect(old.never, isEmpty);
  });
}
