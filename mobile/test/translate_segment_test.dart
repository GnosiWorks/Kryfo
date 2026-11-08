// SPDX-License-Identifier: GPL-3.0-or-later
// a message goes to the model whole, in one call: a sentence over several
// lines as one text, line breaks between sentences kept as they were, a
// long text cut at sentence ends only where the input limit needs it, and
// links, @mentions and emojis never shown to the model and put back as
// they were
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/foreign.dart';
import 'package:kryfo/translate/hant.dart';
import 'package:kryfo/translate/segment.dart';

import 'translate_fakes.dart';

// what each ask became, marked, so where it went shows
String _marked(MessagePlan p) => p.fill([for (final a in p.asks) '<$a>']);

void main() {
  group('lines', () {
    test('a sentence over three lines is one text', () {
      final p = planMessage('get\na\ngrip');
      expect(p.asks, ['get a grip']);
      expect(_marked(p), '<get a grip>');
    });

    test('line breaks between sentences stay exactly', () {
      const text = 'Hi there.\nHow are you?\n\n  See you soon\nBye';
      final p = planMessage(text);
      expect(p.asks, ['Hi there.', 'How are you?', 'See you soon', 'Bye']);
      expect(
        _marked(p),
        '<Hi there.>\n<How are you?>\n\n  <See you soon>\n<Bye>',
      );
      // nothing lost: the asks back as they were give the message
      expect(p.fill(p.asks), text);
    });

    test('a line that goes on joins the next, a list item does not', () {
      final p = planMessage(
        'we could meet at the station,\nThen walk\n- bread\n- milk',
      );
      expect(p.asks, [
        'we could meet at the station, Then walk',
        '- bread',
        '- milk',
      ]);
    });

    test('chinese lines join without a space, sentences stay apart', () {
      final p = planMessage('我今天下班有点晚，\n大概八点到家。\n你呢？');
      expect(p.asks, ['我今天下班有点晚，大概八点到家。', '你呢？']);
      expect(_marked(p), '<我今天下班有点晚，大概八点到家。>\n<你呢？>');
    });

    test('carriage returns and blank lines are kept', () {
      const text = 'One.\r\n\r\nTwo.';
      final p = planMessage(text);
      expect(p.asks, ['One.', 'Two.']);
      expect(p.fill(p.asks), text);
    });

    test('nothing to translate asks nothing', () {
      for (final t in [
        '',
        '   ',
        '😂😂',
        '123 !!!',
        'https://kryfo.app',
        '@sun-cat-blue',
      ]) {
        final p = planMessage(t);
        expect(p.asks, isEmpty, reason: t);
        expect(p.fill(const []), t);
      }
    });
  });

  group('kept out of the model', () {
    const cases = {
      'look at this https://kryfo.app/a?b=1&c=(2) now': [
        'https://kryfo.app/a?b=1&c=(2)',
      ],
      'see www.example.org/x.': ['www.example.org/x'],
      '@sun-cat-blue are you coming?': ['@sun-cat-blue'],
      'thanks @moon-red-fox.': ['@moon-red-fox'],
      'get a grip 😂👍🏽': ['😂👍🏽'],
      'family 👨‍👩‍👧 trip 🇩🇪 #️⃣ ok ❤️': ['👨‍👩‍👧', '🇩🇪', '#️⃣', '❤️'],
      '好的👌明天见': ['👌'],
    };
    cases.forEach((text, kept) {
      test(text, () {
        final p = planMessage(text);
        for (final k in kept) {
          for (final a in p.asks) {
            expect(a.contains(k), isFalse, reason: 'asked $a');
          }
        }
        // upper-cased answers: every kept thing back unchanged, in place
        final out = p.fill([for (final a in p.asks) a.toUpperCase()]);
        var at = 0;
        for (final k in kept) {
          final i = out.indexOf(k, at);
          expect(i, greaterThanOrEqualTo(0), reason: '$k in $out');
          at = i + k.length;
        }
        expect(p.fill(p.asks), text);
      });
    });

    test('an email is not a mention', () {
      final p = planMessage('write to me@example.org');
      expect(p.asks, ['write to me@example.org']);
    });
  });

  group('long messages', () {
    test('cut at sentence ends, only where the limit needs it', () {
      final sentences = [
        for (var i = 0; i < 30; i++)
          'This is sentence number $i of a long story.',
      ];
      final text = sentences.join(' ');
      final p = planMessage(text);
      expect(p.asks.length, greaterThan(1));
      expect(p.asks.length, lessThan(sentences.length));
      for (final a in p.asks) {
        expect(modelTokens(a), lessThanOrEqualTo(kModelLimit));
        expect(a.endsWith('story.'), isTrue, reason: a);
      }
      expect(p.fill(p.asks), text);
    });

    test('a short text is never cut', () {
      final p = planMessage('One. Two. Three.');
      expect(p.asks, ['One. Two. Three.']);
    });

    test('one sentence over the limit: at clauses, then spaces', () {
      final text = List.filled(60, 'and then we went on, walking').join(' ');
      final p = planMessage(text);
      expect(p.asks.length, greaterThan(1));
      for (final a in p.asks) {
        expect(modelTokens(a), lessThanOrEqualTo(kModelLimit));
        if (a != p.asks.last) expect(a.endsWith(','), isTrue, reason: a);
      }
      expect(p.fill(p.asks), text);
      final words = List.filled(400, 'word').join(' ');
      final q = planMessage(words);
      for (final a in q.asks) {
        expect(modelTokens(a), lessThanOrEqualTo(kModelLimit));
        expect(a.startsWith('word') && a.endsWith('word'), isTrue);
      }
      expect(q.fill(q.asks), words);
    });

    test('chinese is counted by characters', () {
      final text = List.filled(40, '我们明天一起去公园散步。').join();
      final p = planMessage(text);
      expect(p.asks.length, greaterThan(1));
      for (final a in p.asks) {
        expect(modelTokens(a), lessThanOrEqualTo(kModelLimit));
        expect(a.endsWith('。'), isTrue);
      }
      expect(p.fill(p.asks), text);
    });
  });

  group('the hub', () {
    test('a multi-line message is one call, its breaks kept', () async {
      final f = fakeHub(
        installed: true,
        words: {
          'get a grip': '振作点',
          'Hi there.': '你好。',
          'How are you?': '你好吗？',
        },
      );
      await f.hub.downloads.refresh('zh');
      const o = Offer('en', 'zh');
      expect(await f.hub.translate('get\na\ngrip', o), '振作点');
      expect(f.translator.batches, [1]);
      expect(
        await f.hub.translate('Hi there.\n\nHow are you?', o),
        '你好。\n\n你好吗？',
      );
      expect(f.translator.batches, [1, 2]);
      expect(f.translator.asked, [
        'en-zh:get a grip',
        'en-zh:Hi there.',
        'en-zh:How are you?',
      ]);
    });

    test('links, mentions and emojis come back as they were', () async {
      final f = fakeHub(installed: true, words: {'look at this': '看看这个'});
      await f.hub.downloads.refresh('zh');
      final out = await f.hub.translate(
        '@sun-cat-blue look at this 😂 https://kryfo.app/x',
        const Offer('en', 'zh'),
      );
      expect(out, '@sun-cat-blue 看看这个 😂 https://kryfo.app/x');
      expect(f.translator.asked, ['en-zh:look at this']);
    });

    test('emojis alone are not sent at all', () async {
      final f = fakeHub(installed: true);
      await f.hub.downloads.refresh('zh');
      expect(await f.hub.translate('😂👍', const Offer('zh', 'en')), '😂👍');
      expect(f.translator.asked, isEmpty);
    });

    test('traditional forms touch the words only', () async {
      final f = fakeHub(installed: true, words: {'see you': '这个'});
      await f.hub.downloads.refresh('zh');
      final out = await f.hub.translate(
        'see you @sun-cat-blue',
        const Offer('en', 'zh', null, HantForm.tw),
      );
      expect(out, endsWith(' @sun-cat-blue'));
      expect(out, isNot(startsWith('这个')));
    });
  });

  group('the gap between sentences is the target\'s', () {
    test('chinese into english: a space after each sentence', () async {
      const zh = '我今天下班有点晚。大概八点到家。你先吃饭吧。';
      final f = fakeHub(
        installed: true,
        words: {
          zh: "I'm a little late at work today.About eight I'll be home.Eat first.",
        },
      );
      await f.hub.downloads.refresh('zh');
      expect(
        await f.hub.translate(zh, const Offer('zh', 'en')),
        "I'm a little late at work today. About eight I'll be home. Eat first.",
      );
    });

    test('english into chinese: none after 。', () async {
      const en = 'We went to the market. Then we bought bread.';
      final f = fakeHub(installed: true, words: {en: '我们去了市场。 然后我们买了面包。'});
      await f.hub.downloads.refresh('zh');
      expect(
        await f.hub.translate(en, const Offer('en', 'zh')),
        '我们去了市场。然后我们买了面包。',
      );
    });

    test('pieces cut at sentence ends join with the target\'s gap', () {
      final zh = List.filled(30, '我们明天早上九点在车站见面。').join();
      final p = planMessage(zh);
      expect(p.asks.length, greaterThan(1));
      final out = p.fill([for (final _ in p.asks) 'See you.'], to: 'en');
      expect(out, List.filled(p.asks.length, 'See you.').join(' '));
      final en = List.filled(40, 'We meet at nine at the station.').join(' ');
      final q = planMessage(en);
      expect(q.asks.length, greaterThan(1));
      expect(
        q.fill([for (final _ in q.asks) '见面。'], to: 'zh'),
        List.filled(q.asks.length, '见面。').join(),
      );
    });

    test('line breaks stay, abbreviations and numbers are left', () {
      final p = planMessage('明天见。\n别忘了带伞。');
      expect(
        p.fill(['See you tomorrow.', "Don't forget the umbrella."], to: 'en'),
        "See you tomorrow.\nDon't forget the umbrella.",
      );
      final q = planMessage('See you.\n\nBring it.');
      expect(q.fill(['见。', '带上。'], to: 'zh'), '见。\n\n带上。');
      final r = planMessage('八点');
      expect(
        r.fill(['at 8 a.m. or 3.5 hours later.'], to: 'en'),
        'at 8 a.m. or 3.5 hours later.',
      );
      expect(r.fill(['انتهى.ثم'], to: 'ar'), 'انتهى. ثم');
    });
  });
}
