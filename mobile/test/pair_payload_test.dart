// SPDX-License-Identifier: GPL-3.0-or-later
// what a code's address held is taken only as one invite and nothing more:
// a second copy of a part, or anything after the link, would show one key's
// number while the add built on another. the number on the card is the
// number of the key the add then uses, read off the real invite. an old
// card with no bundle is no code's invite. the decoy's invite carries its
// bundle encoded, so any byte of it reads back as it was
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/key_number.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        buildHaloUri,
        haloUriV3,
        inviteKeyNumber,
        makePreKeyBundleB64,
        parseHaloUri,
        quietInviteUri;
import 'package:kryfo/rooms.dart' show firstKryfoLink;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/pair_join.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;

import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;

const _w = 'thumb-behave-boring';

String _bundle(int fill) => base64Encode(
  utf8.encode(
    jsonEncode({
      'registrationId': 1,
      'deviceId': 1,
      'preKeyId': 1,
      'preKeyPublic': base64Encode([5, ...List.filled(32, 9)]),
      'signedPreKeyId': 1,
      'signedPreKeyPublic': base64Encode([5, ...List.filled(32, 8)]),
      'signedPreKeySignature': base64Encode(List.filled(64, 7)),
      'identityKey': base64Encode([5, ...List.filled(32, fill)]),
    }),
  ),
);

String _part(String b) => Uri.encodeQueryComponent(b);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final alice = _bundle(1), mallory = _bundle(2);
  final aliceNum = keyNumber([5, ...List.filled(32, 1)]);

  test('a payload that runs on past its link is no invite', () {
    final split =
        'kryfo://share?id=$_w&onion=m.onion&v=3'
        '&bundle=${_part(mallory)}'
        '\n&bundle=${_part(alice)}';
    // the add would read the first line, the number the whole
    expect(firstKryfoLink(split), isNot(split));
    expect(pairInviteExact(split), isNull);
    expect(pairInviteWords(split), isNull);
    expect(parseHaloUri(split), isNull);
    expect(inviteKeyNumber(split), isNull);
  });

  test('a part given twice is no invite, anywhere', () {
    final twice =
        'kryfo://share?id=$_w&onion=m.onion&v=3'
        '&bundle=${_part(mallory)}&bundle=${_part(alice)}';
    expect(parseHaloUri(twice), isNull);
    expect(inviteKeyNumber(twice), isNull);
    expect(pairInviteExact(twice), isNull);
    expect(
      parseHaloUri('kryfo://share?id=$_w&id=other-words-here&onion=o&xpub=ab'),
      isNull,
    );
    // once each, it reads
    final once =
        'kryfo://share?id=$_w&onion=m.onion&v=3&bundle=${_part(alice)}';
    expect(parseHaloUri(once), isNotNull);
    expect(pairInviteExact(once), once);
    expect(inviteKeyNumber(once), aliceNum);
  });

  test('an old card with no bundle is no code\'s invite', () {
    final old = buildHaloUri(_w, 'o.onion', 'ab' * 32);
    expect(parseHaloUri(old), isNotNull);
    expect(pairInviteExact(old), isNull);
    expect(pairInviteWords(old), isNull);
  });

  testWidgets('a split payload at a code shows nothing and adds nothing', (
    t,
  ) async {
    phone(t);
    pairNow = () => t.binding.clock.now();
    final split =
        'kryfo://share?id=$_w&onion=m.onion&v=3'
        '&bundle=${_part(mallory)}'
        '\n&bundle=${_part(alice)}';
    final added = <String>[];
    await t.pumpWidget(
      app(
        Scaffold(
          body: PairJoin(
            fetch: (_) async => split,
            add: (i) async {
              added.add(i);
              return '';
            },
            onAdded: (_) {},
            retryGap: Duration.zero,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), '482913');
    await t.tap(find.text(l10n.pairCodeAddThem));
    await t.pumpAndSettle();
    expect(find.byType(PairConfirm), findsNothing);
    expect(find.text(l10n.pairCodeNothingAtThatCode), findsOneWidget);
    for (final g in aliceNum!.split(' ')) {
      expect(find.text(g), findsNothing);
    }
    expect(added, isEmpty);
  });

  testWidgets('end to end: the card shows the number of the key the add '
      'gets, and the add gets that exact invite', (t) async {
    phone(t);
    pairNow = () => t.binding.clock.now();
    late SignalSession ss;
    late String invite;
    await t.runAsync(() async {
      final pair = Curve.generateKeyPair();
      ss = SignalSession();
      await ss.bootstrap(
        database: MemDb(),
        xPubBytes: pair.publicKey.serialize().sublist(1),
        xPrivBytes: pair.privateKey.serialize(),
      );
      invite = haloUriV3(
        _w,
        'o.onion',
        _part(await makePreKeyBundleB64(ss)),
        'ab' * 32,
      );
    });
    final own = keyNumber(ss.identityKeyPair.getPublicKey().serialize())!;
    final added = <String>[];
    await t.pumpWidget(
      app(
        Scaffold(
          body: PairJoin(
            fetch: (_) async => invite,
            add: (i) async {
              added.add(i);
              return '';
            },
            onAdded: (_) {},
            retryGap: Duration.zero,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), '482913');
    await t.tap(find.text(l10n.pairCodeAddThem));
    await t.pumpAndSettle();
    expect(find.byType(PairConfirm), findsOneWidget);
    for (final g in own.split(' ')) {
      expect(find.text(g), findsOneWidget);
    }
    await t.tap(find.text(l10n.commonAdd));
    await t.pumpAndSettle();
    expect(added, [invite]);
    expect(inviteKeyNumber(added.single), own);
  });

  test('the decoy\'s invite reads back the bundle it was made with', () {
    // every byte base64 has that a query reads as something else
    const bundle = 'ab+cd/ef==';
    for (final fc in ['ab' * 32, 'error: none']) {
      final uri = quietInviteUri(_w, 'q.onion', bundle, fc);
      expect(uri, isNot(contains(' ')));
      final p = parseHaloUri(uri);
      expect(p?['bundle'], bundle, reason: fc);
      expect(p?['v'], fc.startsWith('error') ? '2' : '3');
    }
    // and it is what the decoy hands out
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains('invite: quietInviteUri(id, onion, bundle, fc)'));
  });

  test('one proof-of-work check for a first contact, shared', () {
    final src = File('lib/main.dart').readAsStringSync();
    // the gate and a deleted chat's words ask the same thing
    expect(RegExp(r'verifyPow\(').allMatches(src), hasLength(1));
    expect(
      RegExp(
        r'!vouched && fromBackPair && !firstPowHolds\(env\)',
      ).hasMatch(src),
      isTrue,
    );
    expect(RegExp(r'firstPowHolds\(env\) &&').hasMatch(src), isTrue);
  });
}
