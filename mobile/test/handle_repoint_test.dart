// SPDX-License-Identifier: GPL-3.0-or-later
// the phone claims its handle again only when its invite changed since the
// registry last took one, and after start at a random moment between a few
// seconds and a minute. the handle page asks whose the handle is with a
// read and claims only when the registry holds something else. a refusal
// shows a fixed line, whatever the registry wrote.
import 'dart:math';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_repoint.dart';
import 'package:kryfo/l10n/l10n.dart';

const _key = 'ab12';
const _inv = 'kryfo://share?id=thumb-behave-boring&onion=x.onion&v=3';

class _Phone {
  _Phone({this.answer = 'ok', this.lookupBody = ''});
  String invite = _inv;
  String answer;
  String lookupBody;
  final store = <String, String>{'my_handle_bio': 'hi'};
  final claims = <(String, String, String)>[];
  final looked = <String>[];

  late final repoint = HandleRepoint(
    invite: () async => invite,
    claim: (h, i, b) async {
      claims.add((h, i, b));
      return answer;
    },
    lookup: (url) async {
      looked.add(url);
      return lookupBody;
    },
    myKey: () => _key,
    read: (k) async => store[k],
    write: (k, v) async => v == null ? store.remove(k) : store[k] = v,
  );
}

String _held(String key, String invite) =>
    '{"names":{"wren":"$key"},"invite":"$invite"}';

// a random source that always gives the same draw
class _Draw implements Random {
  _Draw(this.n);
  final int n;
  @override
  int nextInt(int max) => min(n, max - 1);
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  test('a changed invite is claimed once, and then not again', () async {
    final p = _Phone();
    expect(await p.repoint.repoint('wren'), 'ok');
    expect(p.claims, [('wren', _inv, 'hi')]);
    expect(await p.repoint.repoint('wren'), isNull);
    expect(p.claims, hasLength(1));

    p.invite = '$_inv&fc=ff';
    expect(await p.repoint.repoint('wren'), 'ok');
    expect(p.claims.last.$2, '$_inv&fc=ff');
    expect(await p.repoint.repoint('wren'), isNull);
    expect(p.claims, hasLength(2));
  });

  test('a handle let go of while the claim was being made is not claimed '
      'again', () async {
    final p = _Phone();
    var held = true;
    // the release lands while the invite and the bio are read
    p.store['my_handle_bio'] = 'hi';
    final r = p.repoint.repoint('wren', still: () => held);
    held = false;
    expect(await r, isNull);
    expect(p.claims, isEmpty);
  });

  test('a claim the registry refused is sent again next time', () async {
    final p = _Phone(answer: 'error: refused');
    expect(await p.repoint.repoint('wren'), 'error: refused');
    expect(p.store.containsKey(kHandleClaimedKey), isFalse);
    p.answer = 'ok';
    expect(await p.repoint.repoint('wren'), 'ok');
    expect(p.claims, hasLength(2));
  });

  test(
    'a claim the handle screen made counts, and forgetting clears it',
    () async {
      final p = _Phone();
      await p.repoint.claimed('wren', _inv);
      expect(await p.repoint.repoint('wren'), isNull);
      // another handle is another claim
      expect(await p.repoint.repoint('kite'), 'ok');
      await p.repoint.forget();
      expect(p.store.containsKey(kHandleClaimedKey), isFalse);
      expect(await p.repoint.repoint('kite'), 'ok');
      expect(p.claims, hasLength(2));
    },
  );

  test('after start it waits a few seconds to a minute, never none', () {
    expect(repointDelay(_Draw(0)), const Duration(seconds: 5));
    expect(repointDelay(_Draw(1 << 30)), const Duration(seconds: 60));
    final r = Random(7);
    final seen = <int>{};
    for (var i = 0; i < 2000; i++) {
      final d = repointDelay(r).inSeconds;
      expect(d, inInclusiveRange(5, 60));
      seen.add(d);
    }
    // spread over the whole minute, not bunched
    expect(seen.length, greaterThan(50));
  });

  test(
    'the handle page reads, and claims only what the registry lost',
    () async {
      // ours, at our invite: nothing sent
      var p = _Phone(lookupBody: _held(_key, _inv));
      expect(await p.repoint.check('wren'), HandleAtRegistry.mine);
      expect(p.claims, isEmpty);
      expect(p.looked.single, endsWith('/.well-known/kryfo.json?name=wren'));
      // and the next start sends nothing either
      expect(await p.repoint.repoint('wren'), isNull);

      // another key holds it: nothing sent
      p = _Phone(lookupBody: _held('ffff', _inv));
      expect(await p.repoint.check('wren'), HandleAtRegistry.foreign);
      expect(p.claims, isEmpty);

      // ours at an older invite: claimed again at once
      p = _Phone(lookupBody: _held(_key, 'kryfo://share?id=old'));
      await p.repoint.claimed('wren', _inv);
      expect(await p.repoint.check('wren'), HandleAtRegistry.mine);
      expect(p.claims.single.$2, _inv);

      // nobody holds it: claimed again at once
      p = _Phone(lookupBody: 'error: status 404');
      expect(await p.repoint.check('wren'), HandleAtRegistry.mine);
      expect(p.claims, hasLength(1));

      // and taken in between
      p = _Phone(lookupBody: 'error: status 404', answer: 'error: taken');
      expect(await p.repoint.check('wren'), HandleAtRegistry.foreign);

      // no answer: nothing sent, nothing concluded
      p = _Phone(lookupBody: 'error: get: timeout');
      expect(await p.repoint.check('wren'), HandleAtRegistry.unknown);
      expect(p.claims, isEmpty);
    },
  );

  test('a lookup answer is read for this handle only', () {
    HandleAtRegistry j(String body) =>
        judgeHandle(body, 'wren', myKey: _key, myInvite: _inv);
    expect(j(_held(_key, _inv)), HandleAtRegistry.mine);
    expect(j(_held(_key.toUpperCase(), _inv)), HandleAtRegistry.mine);
    expect(j(_held(_key, 'x')), HandleAtRegistry.stale);
    expect(j(_held('ffff', _inv)), HandleAtRegistry.foreign);
    expect(
      j('{"names":{"kite":"$_key"},"invite":"$_inv"}'),
      HandleAtRegistry.unknown,
    );
    expect(j('not json'), HandleAtRegistry.unknown);
    expect(j('error: status 404'), HandleAtRegistry.missing);
    expect(j('error: status 502'), HandleAtRegistry.unknown);
    expect(
      judgeHandle(_held(_key, _inv), 'wren', myKey: '', myInvite: _inv),
      HandleAtRegistry.unknown,
    );
  });

  test('the mark names the handle and the invite', () {
    expect(claimMark('wren', _inv), claimMark('wren', _inv));
    expect(claimMark('wren', _inv), isNot(claimMark('kite', _inv)));
    expect(claimMark('wren', _inv), isNot(claimMark('wren', '$_inv&x=1')));
    expect(claimMark('wren', _inv), hasLength(64));
  });

  group('a refusal shows a fixed line', () {
    tearDown(() => setL10nLocale(const Locale('en')));

    for (final lang in ['en', 'de', 'ar']) {
      test(lang, () {
        setL10nLocale(Locale(lang));
        expect(
          handleRefusalLine('error: taken', 'wren'),
          l10n.handleThatHandleIsTaken,
        );
        expect(
          handleRefusalLine('error: not yours', 'wren'),
          l10n.handleIsNotYoursOn('wren'),
        );
        expect(
          handleRefusalLine('error: clock', 'wren'),
          l10n.handleCheckClock,
        );
        for (final other in [
          'error: refused',
          'error: bad answer from the registry',
          'error: Update now at https://example.com',
          'error: dial tcp: i/o timeout',
          '',
        ]) {
          expect(handleRefusalLine(other, 'wren'), l10n.handleRegistryFailed);
        }
      });
    }
  });

  group('the repoint after start', () {
    test('waits for tor, which carries every registry call', () {
      final g = RepointGate();
      expect(g.want(torUp: false), isFalse);
      expect(g.want(torUp: true), isTrue);
      g.going();
      expect(g.want(torUp: true), isFalse);
    });

    test('a try with no answer is never taken as done, and goes again later '
        'each time', () {
      final g = RepointGate()..going();
      expect(g.settled('error: context deadline exceeded'), repointRetry(1));
      expect(g.want(torUp: true), isTrue);
      final waits = <Duration?>[];
      for (var i = 0; i < 6; i++) {
        g.going();
        waits.add(g.settled('error: tor client: tor not started'));
      }
      expect(waits, [
        for (final m in [2, 4, 8, 15, 15, 15]) Duration(minutes: m),
      ]);
      expect(g.want(torUp: true), isTrue);
    });

    test('a new invite or handle is put to the registry again, even after '
        'one was taken', () {
      final g = RepointGate()..going();
      expect(g.settled('ok'), isNull);
      expect(g.want(torUp: true), isFalse);
      g.reset();
      expect(g.want(torUp: true), isTrue);
      g.going();
      // and its failure is retried, never left as done
      expect(g.settled('error: registry not reached'), repointRetry(1));
      expect(g.want(torUp: true), isTrue);
    });

    test('claims are a second apart, as the registry orders them', () {
      expect(repointApart, greaterThan(const Duration(seconds: 1)));
    });

    test('an answer, or nothing to send, is done for the run', () {
      for (final r in [null, 'ok', 'error: taken', 'error: not yours']) {
        final g = RepointGate()..going();
        expect(g.settled(r), isNull, reason: '$r');
        expect(g.want(torUp: true), isFalse, reason: '$r');
      }
    });

    test('one put back, as a decoy opens, is armed again', () {
      final g = RepointGate()..going();
      g.putBack();
      expect(g.want(torUp: true), isTrue);
    });
  });
}
