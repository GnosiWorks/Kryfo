// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's pinned keys: every pinned key passes the self-check, and
// so does a card made here the way the app makes its own share link, while
// a card with a flipped signature, another identity or the wrong prekeys
// does not. the test card a debug build may carry is read in one guarded
// place only
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/main.dart'
    show haloUriV3, makePreKeyBundleB64, parseHaloUri;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart' show invitePreKeyId;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

Uint8List _b64(Object? s) => base64Decode(s as String);

// what a pinned key has to be for the chat with it to work at all
Future<List<String>> _problems(DevKey k) async {
  final out = <String>[];
  void need(bool ok, String what) {
    if (!ok) out.add('${k.keyId}: $what');
  }

  need(RegExp(r'^[a-z0-9]+$').hasMatch(k.keyId), 'key id');
  need(k.chatId == 'dev:${k.keyId}' && isDevChat(k.chatId), 'chat id');
  need(k.threeWords.isNotEmpty, 'three words');
  need(_hex64.hasMatch(k.xPub), 'xpub is 64 lowercase hex');
  need(_hex64.hasMatch(k.fc), 'fc is 64 lowercase hex');
  // relay only: an onion would say when the dev phone is online
  need(k.onion.isEmpty, 'no onion');
  final Map<String, Object?> j;
  try {
    j = Map<String, Object?>.from(
      jsonDecode(utf8.decode(base64Decode(k.bundle))) as Map,
    );
  } catch (_) {
    return [...out, '${k.keyId}: the bundle does not decode'];
  }
  try {
    final identity = _b64(j['identityKey']);
    need(
      _hex64.hasMatch(k.xPub) && _hex(identity) == _hex(pinnedIdentity(k)),
      'identityKey is 0x05 and the xpub',
    );
    // the call SignalSession makes on its own signed prekey
    need(
      Curve.verifySignature(
        Curve.decodePoint(identity, 0),
        _b64(j['signedPreKeyPublic']),
        _b64(j['signedPreKeySignature']),
      ),
      'the signed prekey signature verifies under the identity key',
    );
    need(j['preKeyId'] == invitePreKeyId, 'preKeyId is the kept invite key');
    need(j['signedPreKeyId'] == 1, 'signedPreKeyId is 1');
    need(j['deviceId'] == 1, 'deviceId is 1');
    // and a session builds from it, as a first send's would
    final store = InMemorySignalProtocolStore(
      generateIdentityKeyPair(),
      generateRegistrationId(false),
    );
    await SessionBuilder.fromSignalStore(
      store,
      SignalProtocolAddress(k.chatId, 1),
    ).processPreKeyBundle(
      PreKeyBundle(
        j['registrationId'] as int,
        j['deviceId'] as int,
        j['preKeyId'] as int,
        Curve.decodePoint(_b64(j['preKeyPublic']), 0),
        j['signedPreKeyId'] as int,
        Curve.decodePoint(_b64(j['signedPreKeyPublic']), 0),
        _b64(j['signedPreKeySignature']),
        IdentityKey(Curve.decodePoint(identity, 0)),
      ),
    );
  } catch (e) {
    out.add('${k.keyId}: the bundle does not build a session ($e)');
  }
  return out;
}

List<String> _listProblems(List<DevKey> keys) => [
  if (keys.map((k) => k.keyId).toSet().length != keys.length) 'key ids repeat',
  if (keys.isNotEmpty &&
      keys.where((k) => k.status == DevKeyStatus.current).length != 1)
    'not exactly one current key',
];

// a card made the way the dev phone makes its own: an x25519 identity, the
// signal store bootstrapped on it, the invite bundle and the v3 link
Future<({String link, Uint8List xPub, SignalSession ss})> _card(
  String words,
) async {
  final pair = Curve.generateKeyPair();
  final xPub = pair.publicKey.serialize().sublist(1);
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: xPub,
    xPrivBytes: pair.privateKey.serialize(),
  );
  final rnd = Random.secure();
  final fc = _hex([for (var i = 0; i < 32; i++) rnd.nextInt(256)]);
  final bundle = await makePreKeyBundleB64(ss);
  final link = haloUriV3(words, 'someplace.onion', bundle, fc);
  return (link: link, xPub: xPub, ss: ss);
}

// the card with its bundle changed by [edit]
DevKey _edited(DevKey k, void Function(Map<String, Object?>) edit) {
  final j = Map<String, Object?>.from(
    jsonDecode(utf8.decode(base64Decode(k.bundle))) as Map,
  );
  edit(j);
  return DevKey(
    keyId: k.keyId,
    threeWords: k.threeWords,
    xPub: k.xPub,
    bundle: base64Encode(utf8.encode(jsonEncode(j))),
    fc: k.fc,
  );
}

DevKey _key(String id, int n, {DevKeyStatus status = DevKeyStatus.current}) =>
    DevKey(
      keyId: id,
      threeWords: 'word-$n-$id',
      xPub: n.toRadixString(16).padLeft(2, '0') * 32,
      bundle: 'b$n',
      fc: (n + 1).toRadixString(16).padLeft(2, '0') * 32,
      status: status,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => useDevKeysForTest(null));

  test('every pinned key passes the self-check', () async {
    expect(invitePreKeyId, 999999);
    // the list as built, and a test card when this run was given one
    final keys = {...kDevKeys, ...devKeys}.toList();
    for (final k in keys) {
      expect(await _problems(k), isEmpty, reason: k.keyId);
    }
    expect(_listProblems(kDevKeys), isEmpty);
    expect(_listProblems(devKeys), isEmpty);
  });

  group('a card made as the app makes its share link', () {
    late ({String link, Uint8List xPub, SignalSession ss}) card;
    late DevKey k;

    setUpAll(() async {
      card = await _card('plain-test-card');
      k = DevKey.fromLink(card.link, keyId: 'x1')!;
    });

    test('reads with the app parser and passes the self-check', () async {
      expect(await _problems(k), isEmpty);
      expect(_listProblems([k]), isEmpty);
      // the parser hands the bundle back byte for byte
      expect(parseHaloUri(card.link)!['bundle'], k.bundle);
      expect(k.keyId, 'x1');
      expect(k.chatId, 'dev:x1');
      expect(k.threeWords, 'plain-test-card');
      expect(k.status, DevKeyStatus.current);
      // relay only: the link's onion is not pinned
      expect(k.onion, isEmpty);
      // the signal identity is the x25519 key itself
      expect(k.xPub, _hex(card.xPub));
      expect(
        pinnedIdentity(k),
        card.ss.identityKeyPair.getPublicKey().serialize(),
      );
      expect(pinnedIdentity(k), hasLength(33));
    });

    test('a flipped signature byte fails', () async {
      final bad = _edited(k, (j) {
        final sig = _b64(j['signedPreKeySignature']);
        sig[10] ^= 0x01;
        j['signedPreKeySignature'] = base64Encode(sig);
      });
      final p = await _problems(bad);
      expect(p, contains(contains('signature verifies')));
      expect(p, contains(contains('does not build a session')));
    });

    test('another identity behind the same xpub fails', () async {
      final other = DevKey.fromLink(
        (await _card('other-test-card')).link,
        keyId: 'x2',
      )!;
      final bad = DevKey(
        keyId: k.keyId,
        threeWords: k.threeWords,
        xPub: k.xPub,
        bundle: other.bundle,
        fc: k.fc,
      );
      expect(
        await _problems(bad),
        contains(contains('identityKey is 0x05 and the xpub')),
      );
      // and the other card on its own is fine
      expect(await _problems(other), isEmpty);
    });

    test('the wrong prekeys fail', () async {
      final one = _edited(k, (j) => j['preKeyId'] = 3);
      expect(await _problems(one), contains(contains('preKeyId')));
      final signed = _edited(k, (j) => j['signedPreKeyId'] = 2);
      expect(await _problems(signed), contains(contains('signedPreKeyId')));
    });

    test('bad fields fail', () async {
      DevKey w({String? xPub, String? fc, String? onion, String? bundle}) =>
          DevKey(
            keyId: k.keyId,
            threeWords: k.threeWords,
            xPub: xPub ?? k.xPub,
            bundle: bundle ?? k.bundle,
            fc: fc ?? k.fc,
            onion: onion ?? '',
          );
      expect(
        await _problems(w(xPub: k.xPub.toUpperCase())),
        contains(contains('xpub')),
      );
      expect(
        await _problems(w(fc: k.fc.substring(2))),
        contains(contains('fc')),
      );
      expect(
        await _problems(w(onion: 'someplace.onion')),
        contains(contains('onion')),
      );
      expect(
        await _problems(w(bundle: 'not a bundle')),
        contains(contains('does not decode')),
      );
    });

    test('the list: one current key, ids never twice', () {
      expect(_listProblems(const []), isEmpty);
      expect(_listProblems([k]), isEmpty);
      expect(_listProblems([k, k]), hasLength(2));
      final old = DevKey.fromLink(
        card.link,
        keyId: 'x0',
        status: DevKeyStatus.previous,
      )!;
      expect(_listProblems([k, old]), isEmpty);
      expect(_listProblems([old]), ['not exactly one current key']);
    });

    test('a link that is not a v3 card makes no key', () {
      final p = parseHaloUri(card.link)!;
      String link({String v = '3', String? bundle, String? fc}) =>
          'kryfo://share?id=${p['id']}&onion=o&v=$v'
          '&bundle=${bundle ?? p['bundle']}${fc == null ? '' : '&fc=$fc'}';
      expect(DevKey.fromLink(link(fc: p['fc']), keyId: 'a'), isNotNull);
      expect(
        DevKey.fromLink(
          link(v: '2', fc: p['fc']),
          keyId: 'a',
        ),
        isNull,
      );
      expect(DevKey.fromLink(link(), keyId: 'a'), isNull);
      expect(DevKey.fromLink(link(fc: 'z' * 64), keyId: 'a'), isNull);
      expect(
        DevKey.fromLink(
          link(bundle: 'e30=', fc: p['fc']),
          keyId: 'a',
        ),
        isNull,
      );
      // an identity key without its type byte
      final j = jsonDecode(utf8.decode(base64Decode(p['bundle']!))) as Map;
      j['identityKey'] = base64Encode(card.xPub);
      final short = base64Encode(utf8.encode(jsonEncode(j)));
      expect(
        DevKey.fromLink(
          link(bundle: short, fc: p['fc']),
          keyId: 'a',
        ),
        isNull,
      );
      expect(DevKey.fromLink('https://kryfo.app', keyId: 'a'), isNull);
      // a hex address in capitals reads as the same address
      expect(
        DevKey.fromLink(link(fc: p['fc']!.toUpperCase()), keyId: 'a')!.fc,
        p['fc'],
      );
    });
  });

  group('the helpers', () {
    test('an empty list: no key, and nothing is the developer', () {
      useDevKeysForTest(const []);
      final k = _key('m1', 1);
      expect(currentDevKey, isNull);
      expect(devKeyById('m1'), isNull);
      expect(devKeyByXPub(k.xPub), isNull);
      expect(devKeyByFc(k.fc), isNull);
      expect(devKeyByXPub(''), isNull);
      expect(devKeyByFc(''), isNull);
    });

    test('lookups by id, xpub and first-contact address', () {
      final m2 = _key('m2', 2);
      final m1 = _key('m1', 4, status: DevKeyStatus.previous);
      final m0 = _key('m0', 6, status: DevKeyStatus.retired);
      useDevKeysForTest([m0, m1, m2]);
      expect(currentDevKey, same(m2));
      expect(devKeyById('m1'), same(m1));
      expect(devKeyById('m9'), isNull);
      // retired keys are still known: the gate refuses them by name
      expect(devKeyByXPub(m0.xPub), same(m0));
      expect(devKeyByXPub(m1.xPub.toUpperCase()), same(m1));
      expect(devKeyByFc(m2.fc.toUpperCase()), same(m2));
      expect(devKeyByFc(m2.xPub), isNull);
    });

    test('dev ids, and the 33 bytes libsignal compares', () {
      expect(isDevChat('dev:m1'), isTrue);
      expect(isDevChat('dev:'), isTrue);
      expect(isDevChat('dev-fox-river'), isFalse);
      expect(isDevChat('Dev:m1'), isFalse);
      expect(isDevChat('amber-dev:x'), isFalse);
      final k = _key('m1', 0xab);
      expect(pinnedIdentity(k), [0x05, ...List.filled(32, 0xab)]);
      expect(DevKey.chatIdOf('m7'), 'dev:m7');
    });
  });

  // a release never trusts a test card, and nothing else can ask for one
  test('the test card is read in one guarded getter, nowhere else', () {
    final read = RegExp(r'''fromEnvironment\(\s*['"]KRYFO_DEV_CARD['"]''');
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final code = [
        for (final l in f.readAsLinesSync())
          if (!l.trimLeft().startsWith('//')) l,
      ].join('\n');
      for (final _ in read.allMatches(code)) {
        hits.add(f.path);
      }
      if (f.path != 'lib/devchat/dev_key.dart' &&
          code.contains('KRYFO_DEV_CARD')) {
        hits.add('${f.path} names it');
      }
    }
    expect(hits, ['lib/devchat/dev_key.dart']);
    final src = File('lib/devchat/dev_key.dart').readAsStringSync();
    final start = src.indexOf('List<DevKey> get devKeys {');
    expect(start, greaterThan(-1));
    final body = src.substring(start, src.indexOf('\n}\n', start));
    final guard = body.indexOf('if (kReleaseMode) return kDevKeys;');
    expect(guard, greaterThan(-1));
    expect(body.indexOf(read), greaterThan(guard));
    // the only name in code for it is this read
    final code = [
      for (final l in src.split('\n'))
        if (!l.trimLeft().startsWith('//')) l,
    ].join('\n');
    expect('KRYFO_DEV_CARD'.allMatches(code), hasLength(1));
  });
}
