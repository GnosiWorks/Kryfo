// SPDX-License-Identifier: GPL-3.0-or-later
// what a quiet session answers in place of the network comes after a wait
// of two to eight seconds, the same for every stand-in: the handle checks,
// pair codes and gif search
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/quiet_wait.dart';

void main() {
  test('the wait is two to eight seconds', () {
    for (var i = 0; i < 200; i++) {
      final d = quietWait();
      expect(d.inMilliseconds, inInclusiveRange(2000, 8000));
    }
  });

  test('the answer comes after the wait, not before', () async {
    quietWait = () => const Duration(milliseconds: 300);
    String? got;
    unreachedLater('error: unreached').then((v) => got = v);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(got, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(got, 'error: unreached');
  });

  test('every stand-in answers through it', () {
    final sites = {
      'lib/handle_claim.dart': 3,
      'lib/app/pair_codes_app.dart': 2,
      'lib/gifs/gif_source.dart': 2,
      'lib/app/links.dart': 1,
      'lib/screens/search_screen.dart': 1,
    };
    for (final MapEntry(key: f, value: n) in sites.entries) {
      final src = File(f).readAsStringSync();
      expect(RegExp(r'unreachedLater\(').allMatches(src).length, n, reason: f);
      // no quiet answer handed back at once
      expect(src, isNot(contains('sessionQuiet ? _unreached')), reason: f);
      expect(src, isNot(contains('sessionQuiet ? pairUnreached')), reason: f);
      expect(
        src,
        isNot(contains('if (quiet()) return const GifPage')),
        reason: f,
      );
    }
  });

  test('the decoy\'s lookups go on its own lane, and its claim and code '
      'share never go', () {
    String src(String f) => File(f).readAsStringSync();
    expect(src('lib/app/links.dart'), contains('engine.decoyTorGetJson'));
    expect(
      src('lib/screens/search_screen.dart'),
      contains('engine.decoyTorPost(url, body)'),
    );
    final claim = src('lib/handle_claim.dart');
    expect(claim, contains('engine.decoyHandleCheck(h)'));
    expect(claim, contains('final uri = sessionQuiet ? null'));
    // a quiet pairing makes no invite and reaches no relay, on either side
    final pair = src('lib/app/pair_codes_app.dart');
    expect(
      pair,
      contains('PairHooks pairHooks() => sessionQuiet\n    ? PairHooks('),
    );
    expect(pair, contains('share: (_) => unreachedLater(pairUnreached),'));
    expect(pair, contains('join: (_, _) => unreachedLater(pairUnreached),'));
    expect(pair, contains('invite: () async => PairMine(Uint8List(0)),'));
    expect(
      pair,
      contains('if (sessionQuiet || !signalSession.ready) return null;'),
    );
    expect(
      src('lib/app/state_session.dart'),
      contains('engine.decoyLaneNew()'),
    );
  });
}
