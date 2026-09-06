import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/scam_shield.dart';

// every rule the shield ships with, one way it should fire and one way it
// must stay quiet. the shield only advises, but a false alarm on a friend
// is the fastest way to get it switched off.

List<String> _codes(ShieldResult r) => r.hits.map((h) => h.code).toList();

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

  group('impersonation', () {
    const contacts = [
      ShieldContact('thumb-behave-boring', nickname: 'alice', avatar: 7),
      ShieldContact('candle-rope-sunday', nickname: null, avatar: 3),
    ];

    test('a homoglyph id flags with the contact named', () {
      final r = checkImpersonation('thumb-bеhave-boring', null, contacts);
      expect(r.flagged, true);
      expect(r.headline, 'this name matches alice');
      expect(_codes(r), ['name_match']);
    });

    test('one edit away flags, two do not', () {
      expect(
        checkImpersonation('thumb-behave-borins', null, contacts).flagged,
        true,
      );
      expect(
        checkImpersonation('thumb-behave-borixx', null, contacts).flagged,
        false,
      );
    });

    test('an id that reads as a nickname flags', () {
      final r = checkImpersonation('Alice', null, contacts);
      expect(r.flagged, true);
      expect(r.hits.first.line, 'name matches your contact alice');
    });

    test('the same face only ever adds to a near match', () {
      final r = checkImpersonation('thumb-behave-borins', 7, contacts);
      expect(_codes(r), ['name_match', 'face_match']);
      expect(
        checkImpersonation('river-stone-moon', 7, contacts).flagged,
        false,
      );
    });

    test('the contact themselves is not their own impostor', () {
      expect(
        checkImpersonation('thumb-behave-boring', 7, contacts).flagged,
        false,
      );
    });

    test('a contact with no nickname is named by id', () {
      final r = checkImpersonation('candle-rope-sundae', null, contacts);
      expect(r.headline, 'this name matches candle-rope-sunday');
    });
  });

  group('content', () {
    test('crypto addresses by shape', () {
      expect(
        _codes(scanFirstMessage('send to 1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2')),
        ['crypto_address'],
      );
      expect(
        _codes(
          scanFirstMessage(
            'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq works too',
          ),
        ),
        ['crypto_address'],
      );
      expect(
        _codes(
          scanFirstMessage('eth 0x52908400098527886E0F7030069857D2E4169EE7'),
        ),
        ['crypto_address'],
      );
      expect(
        _codes(
          scanFirstMessage(
            '4AdUndXHHZ6cfufTMvppY6JwXNouMBzSkbLYfpAV5Usx3skxNgYeYTRj5UzqtReoS44qo9mtmXCqY45DJ852K5Jv2684Rge',
          ),
        ),
        ['crypto_address'],
      );
      expect(scanFirstMessage('my number is 0612345678').hits, isEmpty);
    });

    test('money next to urgency, not money on its own', () {
      expect(
        _codes(scanFirstMessage('i need the payment today or it expires')),
        ['money_rush'],
      );
      expect(
        scanFirstMessage(
          'the payment went through last month, thanks again for lunch. '
          'anyway, unrelated, can we meet now?',
        ).hits,
        isEmpty,
      );
    });

    test('an ask to move apps needs the ask', () {
      expect(_codes(scanFirstMessage('add me on telegram @notascam')), [
        'move_app',
      ]);
      expect(_codes(scanFirstMessage('whatsapp me later')), ['move_app']);
      expect(scanFirstMessage('telegram is down again lol').hits, isEmpty);
    });

    test('lookalike hosts', () {
      expect(lookalikeHost('paypa1.com'), true);
      expect(lookalikeHost('paypal.com'), false);
      expect(lookalikeHost('secure.paypal.com'), false);
      expect(lookalikeHost('gоogle.com'), true); // cyrillic o
      expect(lookalikeHost('binance.co'), true);
      expect(lookalikeHost('example.org'), false);
      expect(
        _codes(scanFirstMessage('verify here https://coinbase.co/login')),
        ['lookalike_url'],
      );
      expect(scanFirstMessage('see https://github.com/x/y').hits, isEmpty);
    });

    test('a long opener is one point, never a flag alone', () {
      final long = List.filled(90, 'hello').join(' ');
      final r = scanFirstMessage(long);
      expect(_codes(r), ['long_opener']);
      expect(r.flagged, false);
    });

    test('asks for a code or seed', () {
      expect(
        _codes(scanFirstMessage('what is the verification code you got?')),
        ['secret_ask'],
      );
      expect(_codes(scanFirstMessage('send me your seed phrase to sync')), [
        'secret_ask',
      ]);
      expect(scanFirstMessage('the door code is 4412').hits, isEmpty);
    });

    test('two rules flag, one does not', () {
      final one = scanFirstMessage('add me on telegram');
      expect(one.flagged, false);
      expect(one.headline, null);
      final two = scanFirstMessage(
        'add me on telegram, i need the transfer now before it expires',
      );
      expect(two.flagged, true);
      expect(two.headline, 'looks like a scam');
    });

    test('a normal hello stays quiet', () {
      expect(
        scanFirstMessage(
          'hey, sam gave me your kryfo. climbing thursday? '
          'bring the rope, i have the quickdraws.',
        ).hits,
        isEmpty,
      );
    });
  });

  test('joined check puts the name first', () {
    final r = shieldCheck(
      strangerId: 'thumb-behave-borins',
      strangerAvatar: null,
      firstMessage: 'send me your seed phrase now',
      contacts: const [ShieldContact('thumb-behave-boring', nickname: 'alice')],
    );
    expect(r.flagged, true);
    expect(_codes(r), ['name_match', 'secret_ask']);
    expect(r.headline, 'this name matches alice');
  });
}
