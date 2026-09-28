// SPDX-License-Identifier: GPL-3.0-or-later
// what a frame to or from the developer may carry. every frame the app can
// build, alone and in random mixes, is put through the rewrite for an
// anonymous chat: nothing of the everyday identity (its three words, keys,
// onion, first-contact address, face, tier, handle) and no other contact
// comes out, a group, an introduction or a poll does not come out at all,
// and the message comes out as it went in. the same for a chat with three
// words, minus the onion, face and tier. what comes from him is held to
// his pinned key and to what his chat may carry. the token set, the
// support marker, and each guard broken once to show the checks catch it
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_frame.dart';
import 'package:kryfo/devchat/dev_gate.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;

import 'dev_frames.dart';

const _dev = 'dev:m1';

// the developer's pinned key
final _m1 = DevKey(
  keyId: 'm1',
  threeWords: 'scare-raven-rare',
  xPub: '0f' * 32,
  bundle: 'bundle-m1',
  fc: '1e' * 32,
);

String _rndHex(Random r, int bytes) => [
  for (var i = 0; i < bytes; i++)
    r.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

// the name made for an anonymous chat
final _anonEdPriv = _rndHex(Random(7), 64);
final _anonXPriv = _rndHex(Random(8), 32);
final _self = DevSelf.ofKeys('made-for-this', _anonEdPriv, _anonXPriv)!;

// the rewrite, checked the way every frame is checked below
Future<List<String>> _check(
  Set<String> on, {
  required bool anon,
  String? Function(String, {DevSelf? anon}) rule = devOutFrame,
}) async {
  final problems = <String>[];
  final frame = await buildFrame(on);
  final out = rule(frame, anon: anon ? _self : null);
  if (frameRefused(on, anon: anon)) {
    if (out != null) {
      problems.addAll(['went out: $on', ...frameLeaks(out, anon: anon)]);
    }
    return problems;
  }
  if (out == null) return ['did not go out: $on'];
  problems.addAll(frameLeaks(out, anon: anon));
  final j = frameJson(out);
  if (j['sp'] != kDevSupport) problems.add('no marker');
  if (on.contains('sender')) {
    final want = anon
        ? [_self.id, _self.edPub, _self.xPub]
        : [everydayWords, everydayEd, everydayX];
    if ([j['h'], j['e'], j['x']].join() != want.join()) {
      problems.add('the sender is not the one meant');
    }
  }
  // the chat loses nothing it needs
  final was = frameRead(frame);
  final now = frameRead(out);
  for (final k in was.keys) {
    if ('${was[k]}' != '${now[k]}') problems.add('$k changed');
  }
  return problems;
}

void main() {
  setUp(() => useDevKeysForTest([_m1]));
  tearDown(() => useDevKeysForTest(null));

  group('out: every frame the app can build', () {
    // read off the source, so a new field fails here until it is sorted
    test('every field and every parameter of wrapMessage is sorted', () async {
      final src = File('lib/message_envelope.dart').readAsStringSync();
      final start = src.indexOf('Future<String> wrapMessage(');
      final body = src.substring(
        start,
        src.indexOf('\nUnwrappedMessage ', start),
      );
      final keys = {
        for (final m in RegExp(r"body\['(\w+)'\]").allMatches(body)) m[1]!,
      };
      final sorted = {
        ...kDevKept,
        ...kDevPow,
        ...kDevSender,
        ...kDevIgnored,
        ...kDevNever,
        kDevMarker,
      };
      expect(keys.difference(sorted), isEmpty);
      // no key is in two places
      final all = [
        ...kDevKept,
        ...kDevPow,
        ...kDevSender,
        ...kDevIgnored,
        ...kDevNever,
        kDevMarker,
      ];
      expect(all.toSet().length, all.length);
      expect(keys, hasLength(greaterThan(35)));
      final sig = body.substring(0, body.indexOf(') async {'));
      final params = {
        for (final line in sig.split('\n'))
          if (RegExp(r'(\w+)(?:\s*=\s*[^,]+)?,$').firstMatch(line.trim())
              case final m?)
            m[1]!,
      }..remove('plain');
      expect(params, frameParams.keys.toSet());
      // the frame with every field on carries every key the source writes
      final full = frameJson(
        await buildFrame({...frameParams.keys}),
      ).keys.toSet();
      expect(keys.difference(full), isEmpty);
    });

    test('each call site\'s frame, anonymous and with three words', () async {
      for (final e in madeFrames.entries) {
        for (final anon in [true, false]) {
          expect(
            await _check(e.value, anon: anon),
            isEmpty,
            reason: '${e.key}, ${anon ? 'anonymous' : 'three words'}',
          );
        }
      }
    });

    test('each field alone, and all of them at once', () async {
      for (final anon in [true, false]) {
        for (final k in frameParams.keys) {
          expect(await _check({k}, anon: anon), isEmpty, reason: k);
          expect(await _check({k, 'sender'}, anon: anon), isEmpty, reason: k);
        }
        expect(await _check({...frameParams.keys}, anon: anon), isEmpty);
        final safe = {...frameParams.keys}.difference(neverParams);
        expect(await _check(safe, anon: anon), isEmpty);
      }
    });

    test('a thousand random mixes of every field', () async {
      final r = Random(20260928);
      final keys = frameParams.keys.toList();
      final safe = [
        for (final k in keys)
          if (!neverParams.contains(k)) k,
      ];
      var went = 0;
      for (var i = 0; i < 1000; i++) {
        // half of them from the fields that may go, so most of those go
        final on = {
          for (final k in i.isEven ? safe : keys)
            if (r.nextInt(10) < 3) k,
        };
        final anon = i % 4 < 2;
        expect(await _check(on, anon: anon), isEmpty, reason: '$on');
        if (!frameRefused(on, anon: anon)) went++;
      }
      expect(went, greaterThan(400));
    });

    test('a group, an introduction or a poll never goes, nor anything '
        'unknown', () async {
      for (final k in neverParams) {
        expect(
          devOutFrame(await buildFrame({k, 'sender'}), anon: _self),
          isNull,
        );
        expect(devOutFrame(await buildFrame({k, 'sender'})), isNull);
      }
      final plain = frameJson(await buildFrame({'sender', 'msgUid'}));
      for (final odd in ['zz', 'p', 'hd', 'fc', 'n']) {
        final withOdd = 'halo/1:${jsonEncode({...plain, odd: 'x'})}';
        expect(devOutFrame(withOdd, anon: _self), isNull, reason: odd);
        expect(devOutFrame(withOdd), isNull, reason: odd);
      }
      expect(devOutFrame('hello'), isNull);
      expect(devOutFrame('halo/1:[1]'), isNull);
      expect(devOutFrame('halo/1:{not json'), isNull);
    });

    test('an anonymous voice note goes disguised or not at all', () async {
      final raw = await buildFrame({'sender', 'fileB64', 'voice'});
      expect(devOutFrame(raw, anon: _self), isNull);
      // with three words it is the person's own voice anyway
      expect(devOutFrame(raw), isNotNull);
      final masked = await buildFrame({
        'sender',
        'fileB64',
        'voice',
        'voiceDisguised',
      });
      expect(frameJson(devOutFrame(masked, anon: _self)!)['vd'], 1);
    });

    test('the proof of work still holds on his side', () async {
      const text = 'a first message to marios';
      final nonce = grindPow(text, powBits);
      final frame = await wrapMessage(
        text,
        powNonce: nonce,
        powBitsUsed: powBits,
        sender: frameParams['sender'] as SenderInfo,
      );
      for (final anon in [_self, null]) {
        final got = unwrapMessage(devOutFrame(frame, anon: anon)!);
        expect(got.message, text);
        expect(got.powNonce, nonce);
        expect(
          verifyPow(got.powText ?? got.message, got.powNonce!, powBits),
          isTrue,
        );
      }
    });

    test('three words: the person\'s own name and keys, no onion, face or '
        'tier', () async {
      final out = frameJson(
        devOutFrame(await buildFrame({'sender', 'msgUid', 'supporterBadge'}))!,
      );
      expect(out['h'], everydayWords);
      expect(out['e'], everydayEd);
      expect(out['x'], everydayX);
      expect(out['o'], '');
      expect(out.containsKey('av'), isFalse);
      expect(out.containsKey('bg'), isFalse);
      expect(out['sp'], kDevSupport);
    });

    test('the made name comes from its keys', () {
      expect(_self.id, 'made-for-this');
      expect(_self.edPub, _anonEdPriv.substring(64));
      final pair = Curve.generateKeyPairFromPrivate([
        for (var i = 0; i < 64; i += 2)
          int.parse(_anonXPriv.substring(i, i + 2), radix: 16),
      ]);
      expect(
        _self.xPub,
        [
          for (final b in pair.publicKey.serialize().sublist(1))
            b.toRadixString(16).padLeft(2, '0'),
        ].join(),
      );
      // keys that do not read make no name
      for (final (id, ed, x) in [
        (null, _anonEdPriv, _anonXPriv),
        ('', _anonEdPriv, _anonXPriv),
        (' made', _anonEdPriv, _anonXPriv),
        ('made', null, _anonXPriv),
        ('made', 'ab' * 32, _anonXPriv),
        ('made', _anonEdPriv, null),
        ('made', _anonEdPriv, 'zz' * 32),
        ('made', _anonEdPriv, 'ab' * 31),
      ]) {
        expect(DevSelf.ofKeys(id, ed, x), isNull, reason: '$id $ed $x');
      }
    });
  });

  group('in: what comes from him', () {
    SenderInfo his({String? h, String? x}) => SenderInfo(
      haloId: h ?? _m1.threeWords,
      edPub: '2a' * 32,
      onion: 'hisonion.onion',
      xPub: x ?? _m1.xPub,
      avatar: 5,
    );

    Future<String> from(Set<String> on, {SenderInfo? sender}) async {
      final j = frameJson(await buildFrame(on));
      if (on.contains('sender')) {
        final s = sender ?? his();
        j
          ..['h'] = s.haloId
          ..['e'] = s.edPub
          ..['o'] = s.onion
          ..['x'] = s.xPub
          ..['av'] = s.avatar;
      }
      return 'halo/1:${jsonEncode(j)}';
    }

    test('his message and what hangs off it, as he sent it', () async {
      for (final e in madeFrames.entries) {
        final on = e.value;
        final frame = await from(on);
        final got = devInFrame(_dev, frame);
        if (on.any(neverParams.contains)) {
          expect(got, isNull, reason: e.key);
          continue;
        }
        expect(got, isNotNull, reason: e.key);
        final a = frameRead(frame);
        final b = frameRead(got!);
        for (final k in a.keys) {
          // the proof of work is only asked of a first contact
          if (k == 'pw' || k == 'pb') continue;
          expect('${b[k]}', '${a[k]}', reason: '${e.key}: $k');
        }
        final u = unwrapMessage(got);
        expect(u.senderAvatar, isNull, reason: e.key);
        expect(u.supporterBadge, isNull, reason: e.key);
        if (on.contains('sender')) {
          expect(u.senderHaloId, _m1.threeWords);
          expect(u.senderXPub, _m1.xPub);
        }
      }
    });

    test('a group, an introduction or a poll from him is dropped whole, in '
        'any mix', () async {
      final r = Random(5);
      final keys = frameParams.keys.toList();
      for (var i = 0; i < 300; i++) {
        final on = {
          for (final k in keys)
            if (r.nextInt(10) < 3) k,
        };
        final got = devInFrame(_dev, await from(on));
        if (on.any(neverParams.contains)) {
          expect(got, isNull, reason: '$on');
        } else {
          final u = unwrapMessage(got!);
          expect(u.groupId, isNull);
          expect(u.groupControl, isNull);
          expect(u.roster, isNull);
          expect(u.rosterParticipants, isNull);
          expect(u.intro, isNull);
          expect(u.poll, isNull);
          expect(u.vote, isNull);
          expect(u.pollClose, isNull);
          expect(u.senderAvatar, isNull);
          expect(u.supporterBadge, isNull);
        }
      }
    });

    test('his face, his tier and anything unknown are left out', () async {
      final j = frameJson(await from({'sender', 'msgUid', 'supporterBadge'}));
      j['zz'] = {'h': everydayWords};
      j['hd'] = everydayHandle;
      final got = frameJson(devInFrame(_dev, 'halo/1:${jsonEncode(j)}')!);
      expect(got.keys.toSet(), {'m', 'u', 'h', 'e', 'o', 'x'});
    });

    test('who it says sent it must be his pinned key', () async {
      // his words, and his key where it names one
      expect(devInFrame(_dev, await from({'sender', 'msgUid'})), isNotNull);
      expect(
        devInFrame(
          _dev,
          await from({'sender'}, sender: his(x: _m1.xPub.toUpperCase())),
        ),
        isNotNull,
      );
      // a reaction or an unsend names nobody
      expect(devInFrame(_dev, await from({'reaction'})), isNotNull);
      expect(devInFrame(_dev, await from({'unsend'})), isNotNull);
      // anyone else's words or key
      for (final s in [
        his(h: everydayWords),
        his(h: 'Scare-Raven-Rare'),
        his(h: ''),
        his(x: everydayX),
        his(x: ''),
      ]) {
        expect(
          devInFrame(_dev, await from({'sender', 'msgUid'}, sender: s)),
          isNull,
          reason: '${s.haloId} ${s.xPub}',
        );
      }
      final j = frameJson(await from({'sender', 'msgUid'}));
      expect(
        devInFrame(_dev, 'halo/1:${jsonEncode({...j, 'h': null})}'),
        isNull,
      );
      expect(devInFrame(_dev, 'halo/1:${jsonEncode({...j, 'x': 7})}'), isNull);
    });

    test('only for a dev chat of a pinned key that still works', () async {
      final frame = await from({'sender', 'msgUid'});
      for (final peer in [
        'dev:m2',
        'DEV:m1',
        ' dev:m1',
        'dev:',
        everydayWords,
      ]) {
        expect(devInFrame(peer, frame), isNull, reason: peer);
      }
      expect(devInFrame(_dev, 'hello'), isNull);
      expect(devInFrame(_dev, 'halo/1:{not json'), isNull);
      useDevKeysForTest([
        DevKey(
          keyId: 'm1',
          threeWords: _m1.threeWords,
          xPub: _m1.xPub,
          bundle: _m1.bundle,
          fc: _m1.fc,
          status: DevKeyStatus.previous,
        ),
      ]);
      expect(devInFrame(_dev, frame), isNotNull);
      useDevKeysForTest([
        DevKey(
          keyId: 'm1',
          threeWords: _m1.threeWords,
          xPub: _m1.xPub,
          bundle: _m1.bundle,
          fc: _m1.fc,
          status: DevKeyStatus.retired,
        ),
      ]);
      expect(devInFrame(_dev, frame), isNull);
      useDevKeysForTest(const []);
      expect(devInFrame(_dev, frame), isNull);
    });
  });

  group('the token set', () {
    test('a cipher it made, for ten minutes, and nothing else', () {
      var now = DateTime(2026, 9, 28, 12);
      final t = DevTokens(now: () => now);
      t.mint('cipher-a');
      expect(t.has('cipher-a'), isTrue);
      expect(t.has('cipher-b'), isFalse);
      expect(t.has('cipher-a '), isFalse);
      // a slice goes out up to three times as the same cipher
      now = now.add(const Duration(minutes: 9, seconds: 59));
      expect(t.has('cipher-a'), isTrue);
      expect(t.has('cipher-a'), isTrue);
      now = now.add(const Duration(seconds: 1));
      expect(t.has('cipher-a'), isFalse);
      expect(t.length, 0);
      t.mint('cipher-c');
      t.clear();
      expect(t.has('cipher-c'), isFalse);
    });

    test('bounded: past the cap the oldest go first', () {
      final t = DevTokens(cap: 3);
      for (final c in ['a', 'b', 'c', 'd']) {
        t.mint(c);
      }
      expect(
        [
          for (final c in ['a', 'b', 'c', 'd']) t.has(c),
        ],
        [false, true, true, true],
      );
      // minted again, a cipher is the newest
      t.mint('b');
      t.mint('e');
      expect(
        [
          for (final c in ['b', 'c', 'd', 'e']) t.has(c),
        ],
        [true, false, true, true],
      );
    });

    test('the one gate asks the one set', () {
      const r = DevChatRow(
        state: DevState.anon,
        keyId: 'm1',
        anonId: 'made-for-this',
        anonXPriv: 'anon-priv',
        createdAt: 1,
      );
      devTokens.clear();
      expect(devGate.minted('sealed-here'), isFalse);
      expect(
        DevGate.relayWay(r, _m1, 'sealed-here', devGate.minted),
        DevWay.refused,
      );
      devTokens.mint('sealed-here');
      expect(devGate.minted('sealed-here'), isTrue);
      expect(
        DevGate.relayWay(r, _m1, 'sealed-here', devGate.minted),
        const DevWay.room('anon-priv'),
      );
      devTokens.clear();
    });
  });

  group('the support marker', () {
    test('rides the envelope and reads back', () async {
      final w = await wrapMessage('hi', supportMarker: 1);
      expect(frameJson(w)['sp'], 1);
      expect(unwrapMessage(w).supportMarker, 1);
      expect(unwrapMessage(await wrapMessage('hi')).supportMarker, isNull);
      // one that does not read is none, and the rest still reads
      final odd = 'halo/1:${jsonEncode({'m': 'hi', 'u': 'x1', 'sp': 'two'})}';
      expect(unwrapMessage(odd).supportMarker, isNull);
      expect(unwrapMessage(odd).msgUid, 'x1');
    });

    test('every frame to him carries it, whatever it said before', () async {
      final j = frameJson(await buildFrame({'msgUid'}))..['sp'] = 2;
      final out = devOutFrame('halo/1:${jsonEncode(j)}', anon: _self)!;
      expect(frameJson(out)['sp'], kDevSupport);
      expect(frameJson(devOutFrame(await buildFrame({'reaction'}))!)['sp'], 1);
    });
  });

  // the checks above would catch each guard gone
  group('each guard, broken once, is caught', () {
    test('the rewrite passing frames through', () async {
      String? through(String w, {DevSelf? anon}) => w;
      final caught = [
        for (final e in madeFrames.entries)
          ...await _check(e.value, anon: true, rule: through),
      ];
      expect(caught, contains('carries $everydayWords'));
      expect(caught, contains('carries $everydayOnion'));
      expect(caught, contains('carries $friendId'));
      expect(caught, contains('av'));
      expect(caught, contains('went out: ${madeFrames['introduction']}'));
    });

    test('the rewrite keeping the sender', () async {
      String? keeps(String w, {DevSelf? anon}) => devOutFrame(w);

      final caught = await _check(
        madeFrames['text opener']!,
        anon: true,
        rule: keeps,
      );
      expect(caught, contains('carries $everydayWords'));
      expect(caught, contains('the sender is not the one meant'));
    });

    test('the rewrite letting a group or an introduction by', () async {
      String? lets(String w, {DevSelf? anon}) {
        final j = frameJson(w)..removeWhere((k, _) => kDevNever.contains(k));
        return devOutFrame('halo/1:${jsonEncode(j)}', anon: anon);
      }

      for (final kind in ['introduction', 'group control', 'poll', 'vote']) {
        expect(await _check(madeFrames[kind]!, anon: true, rule: lets), [
          'went out: ${madeFrames[kind]}',
        ]);
      }
    });

    test('the voice rule gone', () async {
      String? loud(String w, {DevSelf? anon}) {
        final j = frameJson(w);
        final raw = j['vo'] == 1 && j['vd'] != 1;
        if (raw) j['vd'] = 1;
        final out = devOutFrame('halo/1:${jsonEncode(j)}', anon: anon);
        if (out == null || !raw) return out;
        return 'halo/1:${jsonEncode(frameJson(out)..remove('vd'))}';
      }

      expect(await _check(madeFrames['voice note']!, anon: true, rule: loud), [
        'went out: ${madeFrames['voice note']}',
      ]);
    });

    test('the inbound allowlist taking everything', () async {
      String? all(String peer, String w) => w;
      final j = frameJson(
        await buildFrame({'groupId', 'groupControl', 'sender'}),
      );
      final got = all(_dev, 'halo/1:${jsonEncode(j)}');
      expect(unwrapMessage(got!).groupControl, isNotNull);
      expect(devInFrame(_dev, 'halo/1:${jsonEncode(j)}'), isNull);
    });

    test('the sender check gone', () async {
      final forged = frameJson(await buildFrame({'sender', 'msgUid'}));
      final text = 'halo/1:${jsonEncode(forged)}';
      String? unchecked(String peer, String w) => w;
      expect(unwrapMessage(unchecked(_dev, text)!).senderHaloId, everydayWords);
      expect(devInFrame(_dev, text), isNull);
    });

    test('the gate taking any cipher', () {
      const r = DevChatRow(
        state: DevState.anon,
        keyId: 'm1',
        anonXPriv: 'anon-priv',
        createdAt: 1,
      );
      final ctl = jsonEncode({'halo_ctl': 'bundle', 'from': everydayWords});
      expect(DevGate.relayWay(r, _m1, ctl, (_) => true).go, isTrue);
      expect(DevGate.relayWay(r, _m1, ctl, DevTokens().has), DevWay.refused);
    });
  });
}
