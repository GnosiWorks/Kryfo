// SPDX-License-Identifier: GPL-3.0-or-later
// each rule once firing and once quiet: a false alarm on a friend is the
// fastest way to get the shield switched off
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/scam_shield.dart';

List<String> _codes(String text) =>
    scanRequest(text).hits.map((h) => h.code).toList();

void main() {
  group('normalise', () {
    test('folds case, accents, homoglyphs and whitespace', () {
      expect(normaliseName('  Alice   Müller '), 'alice muller');
      // cyrillic a, e, o, p, c, x
      expect(normaliseName('аlіcе'), 'alice');
      expect(normaliseName('b0b 1ee'), 'bob lee');
      expect(normaliseName('СаРА'), 'capa');
    });
  });

  group('a name like a contact\'s', () {
    const contacts = [
      ShieldContact('thumb-behave-boring', nickname: 'alice'),
      ShieldContact('candle-rope-sunday'),
    ];

    test('a homoglyph id flags with the contact named', () {
      final r = checkImpersonation('thumb-bеhave-boring', contacts);
      expect(r.flagged, isTrue);
      expect(r.lead, const ShieldHit('name_match', 'alice'));
    });

    test('one edit away flags, two do not', () {
      expect(
        checkImpersonation('thumb-behave-borins', contacts).flagged,
        isTrue,
      );
      expect(
        checkImpersonation('thumb-behave-borixx', contacts).flagged,
        isFalse,
      );
    });

    test('an id that reads as a nickname flags', () {
      expect(checkImpersonation('Alice', contacts).flagged, isTrue);
    });

    test('the contact itself is not flagged', () {
      expect(
        checkImpersonation('thumb-behave-boring', contacts).flagged,
        false,
      );
    });

    test('a contact without a nickname is named by id', () {
      expect(
        checkImpersonation('candle-rope-sundae', contacts).lead?.who,
        'candle-rope-sunday',
      );
    });
  });

  group('asks for a code, a pin or recovery words', () {
    test('fires on an ask', () {
      expect(_codes('what is the verification code you got?'), ['asks_secret']);
      expect(_codes('send me your seed phrase to sync'), ['asks_secret']);
      expect(_codes('I sent my whatsapp code to you by mistake, forward it'), [
        'asks_secret',
      ]);
      expect(_codes('enter your 12 words on the restore page'), [
        'asks_secret',
      ]);
      expect(_codes('Продиктуйте код из СМС'), ['asks_secret']);
      expect(_codes('请把验证码发给我'), ['asks_secret']);
    });

    test('quiet on a mention, advice or an everyday code', () {
      expect(_codes('the door code is 4412'), isEmpty);
      expect(_codes('send me the code for the website'), isEmpty);
      expect(_codes('what is the wifi password at the cabin?'), isEmpty);
      expect(_codes('drop me a pin when you get there'), isEmpty);
      expect(_codes('never share your seed phrase with anyone'), isEmpty);
      expect(_codes("don't give your password to anyone"), isEmpty);
      expect(_codes('Gib niemals dein Passwort weiter.'), isEmpty);
      expect(_codes('Ne donnez jamais votre mot de passe.'), isEmpty);
      expect(_codes('the booking confirmation code is ABX42'), isEmpty);
    });
  });

  group('money asked for in a hurry', () {
    test('fires on an ask with a rush', () {
      expect(_codes('can you send me £450 urgently for the rent'), [
        'pay_rush',
      ]);
      expect(_codes('buy me two \$100 steam cards right now'), ['pay_rush']);
      expect(_codes('pay to bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq asap'), [
        'pay_rush',
      ]);
      expect(_codes('Срочно переведи 15000 рублей на карту'), ['pay_rush']);
      expect(_codes('Kannst du mir dringend 500 € überweisen?'), ['pay_rush']);
      expect(_codes('Anne acil 2000 TL lazım'), ['pay_rush']);
    });

    test('quiet on money alone, a rush alone, or an offer', () {
      expect(_codes('the payment went through, thanks for lunch'), isEmpty);
      expect(_codes('urgent: the meeting moved to 3pm'), isEmpty);
      expect(
        _codes("I'll send you the money for the tickets right away"),
        isEmpty,
      );
      expect(_codes('Ich überweise dir das Geld sofort'), isEmpty);
      expect(_codes('send me 5 bucks for the coffee, no hurry'), isEmpty);
      expect(_codes('can you pay me back for the pizza asap?'), isEmpty);
      expect(
        _codes("I'm busy right now, can you send me the money tomorrow?"),
        isEmpty,
      );
      expect(
        _codes(
          'my donation address is '
          'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
        ),
        isEmpty,
      );
    });
  });

  group('easy money promised', () {
    test('fires on a promise', () {
      expect(_codes('guaranteed returns of 30% weekly'), ['profit_promise']);
      expect(_codes('double your bitcoin in 24 hours'), ['profit_promise']);
      expect(_codes('Lucro garantido todo mês'), ['profit_promise']);
    });
    test('quiet on numbers that are not a promise', () {
      expect(_codes('my battery drops 20% a day'), isEmpty);
      expect(_codes('guaranteed to be a fun hike'), isEmpty);
      expect(_codes('bitcoin is up 5% today'), isEmpty);
    });
  });

  group('kryfo or a support desk', () {
    test('fires on a claim', () {
      expect(_codes('Hello, this is the Kryfo support team.'), [
        'fake_support',
      ]);
      expect(_codes('Kryfo Security: your keys expired'), ['fake_support']);
      expect(_codes('This is Binance customer support.'), ['fake_support']);
      expect(_codes('Your account will be suspended in 24 hours'), [
        'fake_support',
      ]);
      expect(_codes('Biz Kryfo destek ekibiyiz'), ['fake_support']);
    });
    test('quiet on talk about them', () {
      expect(_codes('Is this the official Kryfo app?'), isEmpty);
      expect(_codes("I'm a huge fan of the Kryfo team's work"), isEmpty);
      expect(_codes('The Kryfo support for bridges works great'), isEmpty);
      expect(_codes('Is this the Kryfo team?'), isEmpty);
      expect(_codes("I'm from the support group at the library"), isEmpty);
      expect(_codes('Hi from the Google developer group meetup'), isEmpty);
      expect(_codes('your old account was blocked?'), isEmpty);
      expect(_codes('Fehler im Kryfo Support-Chat gefragt'), isEmpty);
    });
  });

  group('lookalike links', () {
    test('spots lookalike hosts', () {
      expect(lookalikeHost('paypa1.com'), isTrue);
      expect(lookalikeHost('gоogle.com'), isTrue); // cyrillic o
      expect(lookalikeHost('binance.co'), isTrue);
      expect(lookalikeHost('paypal.com.login-help.ru'), isTrue);
      expect(lookalikeHost('appleid.apple.com.verify-id.co'), isTrue);
      expect(lookalikeHost('secure-paypa1-login.com'), isTrue);
      expect(lookalikeHost('metamask-io.com'), isTrue);
      expect(_codes('verify here https://coinbase.co/login'), [
        'lookalike_link',
      ]);
    });
    test('real sites stay quiet', () {
      expect(lookalikeHost('paypal.com'), isFalse);
      expect(lookalikeHost('secure.paypal.com'), isFalse);
      expect(lookalikeHost('amazon.com.au'), isFalse);
      expect(lookalikeHost('www.amazon.com.au'), isFalse);
      expect(lookalikeHost('apple.co'), isFalse);
      expect(lookalikeHost('paypal.me'), isFalse);
      expect(lookalikeHost('münchen.de'), isFalse);
      expect(lookalikeHost('apple-pie-recipes.com'), isFalse);
      expect(lookalikeHost('example.org'), isFalse);
      expect(_codes('see https://github.com/x/y'), isEmpty);
      // two scripts, one per label, is a missing space, not a lookalike
      expect(_codes('OK.Спасибо'), isEmpty);
    });
  });

  group('what a request shows', () {
    test('the lead is the sharpest rule', () {
      final r = shieldCheck(
        strangerId: 'thumb-behave-borins',
        text: 'this is the kryfo team, send me your seed phrase now',
        contacts: const [ShieldContact('thumb-behave-boring', nickname: 'al')],
      );
      expect(r.hits.map((h) => h.code), [
        'name_match',
        'fake_support',
        'asks_secret',
      ]);
      expect(r.lead?.code, 'name_match');
    });

    test('one line: what was noticed and what to do, never a shout', () {
      for (final h in const [
        ShieldHit('name_match', 'alice'),
        ShieldHit('other_key', 'amber-fox-river'),
        ShieldHit('fake_support'),
        ShieldHit('asks_secret'),
        ShieldHit('lookalike_link'),
        ShieldHit('pay_rush'),
        ShieldHit('profit_promise'),
      ]) {
        final line = ShieldFlag(h).line;
        expect(line, startsWith(h.noticed!));
        expect(line, contains("Don't send money or codes"));
        expect(line, isNot(contains('!')));
        expect(line.toLowerCase(), isNot(contains('scam')));
      }
    });

    test('a clean request says nothing', () {
      expect(scanRequest('hey, climbing thursday?').flagged, isFalse);
      expect(scanRequest('').flagged, isFalse);
    });
  });

  group('a stored row', () {
    Map<String, Object?> row(ShieldHit h, {int dismissed = 0}) => {
      'headline': jsonEncode(h.toJson()),
      'lines': jsonEncode([h.toJson()]),
      'dismissed': dismissed,
    };

    test('reads back as its line', () {
      final f = ShieldFlag.fromRow(row(const ShieldHit('asks_secret')));
      expect(f?.line, l10n.scamShieldWarning(l10n.scamShieldAsksForSecret));
    });

    test('stores codes, never the words', () {
      final r = row(const ShieldHit('name_match', 'alice'));
      expect(r['lines'], isNot(contains('matches')));
    });

    test('dismissed, missing or clean shows nothing', () {
      expect(
        ShieldFlag.fromRow(row(const ShieldHit('asks_secret'), dismissed: 1)),
        isNull,
      );
      expect(ShieldFlag.fromRow(null), isNull);
      expect(
        ShieldFlag.fromRow({'headline': '', 'lines': '[]', 'dismissed': 0}),
        isNull,
      );
    });

    test('a flag an older build made on a dropped rule stays quiet', () {
      for (final old in [
        {'headline': '{"code":"scam"}', 'lines': '[{"code":"move_app"}]'},
        {'headline': '{"code":"scam"}', 'lines': '[{"code":"long_opener"}]'},
        {'headline': 'Looks like a scam', 'lines': '["Contains a crypto"]'},
      ]) {
        expect(ShieldFlag.fromRow({...old, 'dismissed': 0}), isNull);
      }
      // a name match an older build stored still shows
      expect(
        ShieldFlag.fromRow({
          'headline': '{"code":"name_match","who":"alice"}',
          'lines': '[{"code":"name_match","who":"alice"}]',
          'dismissed': 0,
        })?.lead.code,
        'name_match',
      );
    });

    test('only an old clean row may be written over', () {
      expect(
        shieldRowOpen({'headline': '', 'lines': '[]', 'dismissed': 0}),
        isTrue,
      );
      expect(shieldRowOpen(row(const ShieldHit('asks_secret'))), isFalse);
      expect(
        shieldRowOpen({'headline': '', 'lines': '[]', 'dismissed': 1}),
        isFalse,
      );
    });
  });
}
