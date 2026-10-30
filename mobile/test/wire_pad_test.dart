// SPDX-License-Identifier: GPL-3.0-or-later
// every frame is filled out to one of five sizes inside its encryption. a
// plain message and an opener of every kind land on one gift wrap size and
// one count of tor cells, the filler is sealed with the rest, and 0.5.0 and
// 0.5.1 read a filled envelope as they read it without the filler. the
// gift wrap sizes are worked out from the rumor's length the way nip-44
// pads it; engine/wire_pad_test.go wraps those lengths for real
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_frame.dart' show devOutFrame;
import 'package:kryfo/invites.dart'
    show helloOfWire, helloWireOf, kHelloWireLength;
import 'package:kryfo/main.dart' show makePreKeyBundleB64;
import 'package:kryfo/media_resend.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/stranger_gate.dart'
    show kShelfBytes, kShelfFileSlices, kShelfPlaces;
import 'package:kryfo/wire_pad.dart';
import 'signal_kit.dart';

import 'mem_db.dart';
import 'old_wire/envelope_050.dart' as v050;
import 'old_wire/envelope_051.dart' as v051;

// the five gift wraps, as engine/wire_pad_test.go has them
const _wraps = [3949, 8729, 27841, 55149, 76993];
// a plain message's signal wire at each seal size, and an opener's
const _plainWire = [1200, 3760, 14000, 28252, 40604];
const _openerWire = [1312, 3872, 14112, 28364, 40716];
// tor cells a line of each size takes on the onion, plain or opener
const _cells = [3, 8, 29, 57, 82];

int _b64(int n) => 4 * ((n + 2) ~/ 3);

int _nip44Pad(int l) {
  if (l <= 32) return 32;
  var np = 1;
  while (np < l) {
    np <<= 1;
  }
  final chunk = np <= 256 ? 32 : np ~/ 8;
  return chunk * ((l - 1) ~/ chunk + 1);
}

int _nip44(int l) => _b64(67 + _nip44Pad(l));

// the event a relay stores for a rumor content of [n] characters: rumor,
// seal and gift wrap json around each other
int _wrapOf(int n) => 445 + _nip44(343 + _nip44(206 + n));

// relay data cells for one line and its newline
int _cellsOf(int n) => (n + 1 + 497) ~/ 498;

typedef _Phone = ({SignalSession ss, String name});

Future<_Phone> _phone(String name) async {
  final pair = testKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, name: name);
}

Future<void> _start(_Phone from, _Phone to) async {
  await from.ss.processBundle(
    to.name,
    lsBundleOf(from.ss.lib, await to.ss.makeBundleB64()),
  );
}

// what the other side's signal opens a wire to, filler and all
Future<String> _open(_Phone at, String from, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final plain = await at.ss.open(from, wire[0], body);
  return utf8.decode(plain);
}

// everything a parser makes of an envelope, for any version's class
Map<String, Object?> _read(dynamic u) => {
  'm': u.message,
  'powText': u.powText,
  'h': u.senderHaloId,
  'e': u.senderEdPub,
  'o': u.senderOnion,
  'x': u.senderXPub,
  'av': u.senderAvatar,
  'b': u.burnSeconds,
  'u': u.msgUid,
  'r': [u.reaction?.targetUid, u.reaction?.emoji],
  'pn': [u.pin?.targetUid, u.pin?.pinned],
  'ed': [u.edit?.targetUid, u.edit?.newText],
  'q': u.replyTo,
  'g': u.groupId,
  'gc': [
    u.groupControl?.type,
    u.groupControl?.name,
    u.groupControl?.members,
    u.groupControl?.participants,
    u.groupControl?.stamp,
  ],
  'i': u.imageB64,
  'un': u.unsend,
  'f': u.fileB64,
  'fn': u.fileName,
  'vo': u.voice,
  'vd': u.voiceDisguised,
  'pv': u.preview,
  'mid': u.mediaId,
  'ci': u.chunkIndex,
  'ct': u.chunkTotal,
  'pi': u.pvImg,
  'rs': u.roster,
  'rp': u.rosterParticipants,
  'pw': u.powNonce,
  'pb': u.powBitsUsed,
  'bg': u.supporterBadge,
  'dr': u.deliveredUid,
  'sc': u.secure,
  'in': [u.intro?.haloId, u.intro?.onion, u.intro?.xPub, u.intro?.note],
  'nd': [u.need?.mediaId, u.need?.indices],
  'cr': u.canResend,
  'pl': u.poll,
  'vt': [u.vote?.pollUid, u.vote?.choices, u.vote?.seq],
  'pc': [u.pollClose?.pollUid, u.pollClose?.finalVotes],
  'st': u.sticker,
  'sp': u.supportMarker,
  'w': u.writtenAt,
};

final _r = Random(7);
String _hex(int n) =>
    [for (var i = 0; i < n; i++) '0123456789abcdef'[_r.nextInt(16)]].join();
String _bytes64(int n) =>
    base64Encode([for (var i = 0; i < n; i++) _r.nextInt(256)]);
String _uid() => [
  for (var i = 0; i < 14; i++)
    'abcdefghijklmnopqrstuvwxyz0123456789'[_r.nextInt(36)],
].join();
String _words(int n) {
  const w = ['see', 'you', 'at', 'the', 'café', 'tonight', 'ok', 'later'];
  final b = StringBuffer();
  while (b.length < n) {
    b.write(w[_r.nextInt(w.length)]);
    b.write(' ');
  }
  return b.toString().substring(0, n);
}

final _me = SenderInfo(
  haloId: 'velvet-harbor-quiet',
  edPub: _hex(64),
  onion: '${'a' * 56}.onion',
  xPub: _hex(64),
  avatar: 17,
);
const _at = 1760000000000;

// every kind of 1:1 and group envelope, as the app builds it, with the
// size it is filled to
Future<Map<String, (String, int)>> _kinds() async {
  final mid = _uid();
  final g = _uid();
  Future<String> slice(int bytes, int i) => wrapMessage(
    '',
    msgUid: mid,
    imageB64: _bytes64(bytes),
    mediaId: mid,
    chunkIndex: i,
    chunkTotal: 9,
    canResend: true,
    sender: _me,
    writtenAt: _at,
  );
  Future<String> create(int n) {
    final parts = [
      for (var i = 0; i < n; i++)
        {'h': 'member-number-$i', 'o': _me.onion, 'x': _hex(64)},
    ];
    return wrapMessage(
      '',
      groupId: g,
      groupControl: GroupControl(
        type: 'create',
        name: 'Family',
        members: [for (final p in parts) p['h']!],
        participants: parts,
        stamp: _at,
      ),
      sender: _me,
      writtenAt: _at,
    );
  }

  return {
    'receipt': (
      await wrapMessage('', deliveredUid: _uid(), sender: _me, writtenAt: _at),
      0,
    ),
    'reaction': (
      await wrapMessage(
        '',
        reaction: ReactionFrame(targetUid: _uid(), emoji: '👍'),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'unsend': (
      await wrapMessage('', unsend: _uid(), sender: _me, writtenAt: _at),
      0,
    ),
    'pin': (
      await wrapMessage(
        '',
        pin: PinFrame(targetUid: _uid(), pinned: true),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'edit': (
      await wrapMessage(
        '',
        edit: EditFrame(targetUid: _uid(), newText: _words(40)),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'short text': (
      await wrapMessage('ok', msgUid: _uid(), sender: _me, writtenAt: _at),
      0,
    ),
    'text with reply and timer': (
      await wrapMessage(
        _words(200),
        msgUid: _uid(),
        replyTo: _uid(),
        burnSeconds: 3600,
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'sticker': (
      await wrapMessage(
        '',
        sticker: 'fokia:wave:1',
        msgUid: _uid(),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'poll': (
      await wrapMessage(
        _words(60),
        poll: {
          'o': [for (var i = 0; i < 4; i++) _words(20)],
          'm': 0,
        },
        msgUid: _uid(),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'vote': (
      await wrapMessage(
        '',
        vote: VoteFrame(pollUid: _uid(), choices: const [1], seq: 3),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'missing slices': (
      await wrapMessage(
        '',
        need: NeedFrame(_uid(), [for (var i = 0; i < 20; i++) i * 3]),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'introduction': (
      await wrapMessage(
        '',
        intro: IntroFrame(
          haloId: 'amber-cloud-river',
          onion: _me.onion,
          xPub: _hex(64),
          edPub: _hex(64),
          avatar: 3,
          fc: _hex(64),
          note: _words(80),
        ),
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'opener with proof of work': (
      await wrapMessage(
        _words(40),
        msgUid: _uid(),
        powNonce: 1234567,
        powBitsUsed: powBits,
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'group text': (
      await wrapMessage(
        _words(40),
        msgUid: _uid(),
        groupId: g,
        sender: _me,
        writtenAt: _at,
      ),
      0,
    ),
    'dev chat text': (
      devOutFrame(await wrapMessage(_words(40), msgUid: _uid(), sender: _me))!,
      0,
    ),
    'long text': (
      await wrapMessage(
        _words(1500),
        msgUid: _uid(),
        sender: _me,
        writtenAt: _at,
      ),
      1,
    ),
    'group of five': (await create(5), 1),
    'very long text': (
      await wrapMessage(
        _words(6000),
        msgUid: _uid(),
        sender: _me,
        writtenAt: _at,
      ),
      2,
    ),
    'group of fifty': (await create(50), 2),
    'media slice': (await slice(12288, 3), 3),
    'last media slice': (await slice(700, 8), 3),
    'whole file in one': (
      await wrapMessage(
        '',
        msgUid: mid,
        fileB64: _bytes64(12288),
        fileName: 'voice.m4a',
        voice: true,
        sender: _me,
        writtenAt: _at,
      ),
      3,
    ),
    'longest a relay takes': (
      await wrapMessage(
        _words(25000),
        msgUid: _uid(),
        sender: _me,
        writtenAt: _at,
      ),
      4,
    ),
  };
}

void main() {
  group('the filler', () {
    test('fills a frame to exactly the size it goes to', () async {
      final w = await wrapMessage('hi', sender: _me, writtenAt: _at);
      final p = padSeal(w);
      expect(p, startsWith('halo/1:{"pz":"000'));
      expect(utf8Length(p), kSealSizes[0]);
      expect(unpad(p), w);
      // filling a filled frame changes nothing
      expect(padSeal(p), p);
      final r = padRumor(w);
      expect(rumorLength(r), kRumorSizes[0]);
      expect(unpad(r), w);
    });

    test('is zeros alone, the same every time', () async {
      final w = await wrapMessage(_words(100), sender: _me, writtenAt: _at);
      final p = padSeal(w);
      expect(padSeal(w), p);
      final j = jsonDecode(p.substring('halo/1:'.length)) as Map;
      expect(j[kPadField], matches(RegExp(r'^0+$')));
    });

    test('a bundle frame is filled as json', () {
      final f = jsonEncode({'halo_ctl': 'bundle', 'from': 'a', 'want': true});
      final p = padRumor(f);
      expect(p, startsWith('{"pz":"000'));
      expect(rumorLength(p), kRumorSizes[0]);
      final j = jsonDecode(p) as Map;
      expect(j['halo_ctl'], 'bundle');
      expect(j['want'], true);
      expect(unpad(p), f);
    });

    test('an empty object and a signal wire', () {
      expect(unpad(padSeal('halo/1:{}')), 'halo/1:{}');
      expect(jsonDecode(padRumor('{}')), isA<Map>());
      // what a seal made is base64 and goes as it is
      const wire = 'AwoQabcd+/==';
      expect(padRumor(wire), wire);
      expect(padSeal('plain words'), 'plain words');
      expect(unpad('halo/1:{"pz":"0a0","m":""}'), 'halo/1:{"pz":"0a0","m":""}');
    });

    test('a rumor counts what its json escapes', () {
      // engine/wire_pad_test.go escapes the same string to 19 characters
      expect(rumorLength('a"b\\c\u0001é😀'), 19);
      final w =
          'halo/1:${jsonEncode({'m': 'say "hi" \\ to ünïcode 😀\n', 'w': _at})}';
      expect(rumorLength(padRumor(w)), kRumorSizes[0]);
    });

    test('a frame past the largest size rounds up to whole multiples', () {
      String text(int n) => 'halo/1:${jsonEncode({'m': 'x' * n})}';
      final step = kSealSizes.last + 1;
      expect(utf8Length(padSeal(text(kSealSizes.last))), 2 * step - 1);
      expect(utf8Length(padSeal(text(2 * step))), 3 * step - 1);
      // up to the longest line the onion door takes
      expect(utf8Length(padSeal(text(3 * step))), kSealOnionMost);
      // past it nothing is sealed, so no size of its own goes out
      expect(utf8Length(padSeal(text(kSealOnionMost - 30))), kSealOnionMost);
      expect(
        () => padSeal(text(kSealOnionMost)),
        throwsA(isA<FrameTooLarge>()),
      );
      // no relay takes a rumor past the last size: it is left as it is
      final big = text(kRumorSizes.last);
      expect(padRumor(big), big);
    });

    test('a slice of a file in several fills to the slice size', () async {
      final mid = _uid();
      final last = await wrapMessage(
        '',
        msgUid: mid,
        imageB64: 'AAAA',
        mediaId: mid,
        chunkIndex: 4,
        chunkTotal: 5,
        sender: _me,
      );
      expect(utf8Length(padSeal(last)), kSealSizes[3]);
      expect(rumorLength(padRumor(last)), kRumorSizes[3]);
      // a file in one piece is any other message
      final one = await wrapMessage(
        '',
        msgUid: mid,
        imageB64: 'AAAA',
        sender: _me,
      );
      expect(utf8Length(padSeal(one)), kSealSizes[0]);
    });
  });

  group('on the wire', () {
    late _Phone alice, bob, carol;
    setUpAll(() async {
      // the sessions every chat held before 0.6, classic ones the old
      // library made: bob answers alice on theirs, plain messages. carol
      // never heard back from bob: every seal is an opener
      alice = (ss: await fixtureStore('alice'), name: 'alice');
      bob = (ss: await fixtureStore('bob'), name: 'bob');
      carol = (ss: await fixtureStore('carol'), name: 'carol');
    });

    test('a post-quantum opener is filled smaller, lands on the second '
        'gift wrap as a plain message does, and one too big waits for the '
        'answer', () async {
      expect(kPqOpenerSeal, kSealSizes[1] - kPqOpenerExtra);
      final a = await _phone('a');
      final b = await _phone('b');
      await _start(a, b);
      final held = <String>[];
      var waited = 0;
      for (final MapEntry(key: kind, value: (env, k))
          in (await _kinds()).entries) {
        final fits = padSealOpener(env) != null;
        if (!fits) {
          final before = await a.ss.sessionStore.load('b');
          await expectLater(
            a.ss.encryptTo('b', env),
            throwsA(isA<WaitsForAnswer>()),
            reason: kind,
          );
          // nothing of the seal is kept
          expect(await a.ss.sessionStore.load('b'), before, reason: kind);
          held.add(env);
          waited++;
          continue;
        }
        expect(k, 0, reason: '$kind fits an opener only from the first size');
        final w = await a.ss.encryptTo('b', env);
        expect(base64Decode(w)[0], kLsPreKey, reason: kind);
        expect(_wrapOf(w.length), _wraps[1], reason: kind);
        expect(_cellsOf(w.length), _cells[1], reason: kind);
        expect(343 + _nip44(206 + w.length), lessThanOrEqualTo(65535));
        expect(unpad(await _open(b, 'a', w)), env, reason: kind);
      }
      // every kind of the second size and up waits
      expect(waited, greaterThan(0));
      // their answer settles the session: what waited goes plain, each on
      // its own size
      final told = <String>[];
      a.ss.onAnswered = told.add;
      await _open(a, 'b', await b.ss.encryptTo('a', 'hey'));
      expect(told, ['b']);
      for (final env in held) {
        final w = await a.ss.encryptTo('b', env);
        expect(base64Decode(w)[0], kLsWhisper);
        expect(_wraps, contains(_wrapOf(w.length)));
        expect(343 + _nip44(206 + w.length), lessThanOrEqualTo(65535));
        expect(unpad(await _open(b, 'a', w)), env);
      }
    });

    test('an opener is no longer on the wire than a plain message of the '
        'second size', () async {
      final a = await _phone('a');
      final b = await _phone('b');
      await _start(a, b);
      final openers = <int>{};
      for (var i = 0; i < 4; i++) {
        openers.add(
          (await a.ss.encryptTo('b', padSealOpener('{"m":"x"}')!)).length,
        );
      }
      await _open(b, 'a', await a.ss.encryptTo('b', 'hi'));
      await _open(a, 'b', await b.ss.encryptTo('a', 'hey'));
      final plain = <int>{};
      final full = padSeal('{"m":"${'w' * (kSealSizes[1] - 60)}"}');
      expect(utf8Length(full), kSealSizes[1]);
      for (var i = 0; i < 6; i++) {
        final w = await a.ss.encryptTo('b', full);
        plain.add(w.length);
        await _open(b, 'a', w);
        await _open(a, 'b', await b.ss.encryptTo('a', full));
      }
      // ignore: avoid_print
      print('pq opener wire $openers, plain at the second size $plain');
      for (final n in openers) {
        expect(n, lessThanOrEqualTo(plain.reduce(max)));
        expect(_wrapOf(n), _wraps[1]);
        expect(_cellsOf(n), _cells[1]);
      }
    });

    test('a hello lands on a v4 opener\'s gift wrap and cells, whatever '
        'its nonce, and reads back without its filler', () {
      // KHL1, a version, the invite answered, the owner, a one-time
      // invite with its bundle and the signature (3.3)
      final hello = Uint8List.fromList([
        ...ascii.encode('KHL1'),
        ...List.filled(1 + 16 + 33 + 2069 + 64, 7),
      ]);
      for (final nonce in [0, 7, 123456, 999999999999999]) {
        final w = helloWireOf(hello, nonce);
        expect(_wrapOf(rumorLength(w)), _wraps[1]);
        expect(_wrapOf(rumorLength(w)), _wrapOf(_openerWire[1]));
        expect(_cellsOf(w.length), _cells[1]);
        final back = helloOfWire(w)!;
        expect(back.nonce, nonce);
        expect(back.hello, hello);
      }
      final b64 = base64Encode(hello);
      expect(helloOfWire('$b64.12.000'), isNotNull);
      expect(helloOfWire('$b64.12.001'), isNull);
      expect(helloOfWire('$b64.12.'), isNull);
      expect(helloOfWire('$b64.12.0.0'), isNull);
    });

    test('a hello too long to pad is refused, never sent unpadded', () {
      // the longest hello that still takes a filler, with the longest nonce
      final room = (kHelloWireLength - '.999999999999999.0'.length) ~/ 4 * 3;
      final fits = Uint8List(room);
      expect(helloWireOf(fits, 999999999999999).length, kHelloWireLength);
      expect(
        () => helloWireOf(Uint8List(room + 3), 999999999999999),
        throwsArgumentError,
      );
      for (final n in [kHelloWireLength ~/ 4 * 3, 4000]) {
        expect(() => helloWireOf(Uint8List(n), 0), throwsArgumentError);
      }
    });

    test('an opener filler that does not fit is refused', () {
      expect(padSealOpener('{"m":"${'w' * 2000}"}'), isNull);
      expect(utf8Length(padSealOpener('{"m":"hi"}')!), kPqOpenerSeal);
      expect(unpad(padSealOpener('{"m":"hi"}')!), '{"m":"hi"}');
    });

    test('a post-quantum session seals plain messages to the same five '
        'gift wraps', () async {
      final a = await _phone('a');
      final b = await _phone('b');
      await _start(a, b);
      await _open(b, 'a', await a.ss.encryptTo('b', 'hi'));
      await _open(a, 'b', await b.ss.encryptTo('a', 'hey'));
      for (var k = 0; k < 5; k++) {
        final env = padSeal('{"m":"${'w' * (kSealSizes[k] - 60)}"}');
        expect(utf8Length(env), kSealSizes[k]);
        for (var i = 0; i < 6; i++) {
          final there = await a.ss.encryptTo('b', env);
          final back = await b.ss.encryptTo('a', env);
          for (final w in [there, back]) {
            expect(base64Decode(w)[0], kLsWhisper);
            // the pq ratchet's part rides in some messages and not others
            expect(w.length - _plainWire[k], inInclusiveRange(0, 64));
            expect(_wrapOf(w.length), _wraps[k], reason: '$k');
            expect(_cellsOf(w.length), _cells[k], reason: '$k');
          }
          await _open(b, 'a', there);
          await _open(a, 'b', back);
        }
      }
    });

    test(
      'a frame filled to a burst\'s size lands on that size\'s gift wrap',
      () async {
        final a = await _phone('a');
        final b = await _phone('b');
        await _start(a, b);
        await _open(b, 'a', await a.ss.encryptTo('b', 'hi'));
        await _open(a, 'b', await b.ss.encryptTo('a', 'hey'));
        for (final env in [
          '{"m":"hi"}',
          await wrapMessage('hi', msgUid: _uid(), sender: _me, writtenAt: _at),
        ]) {
          for (var k = 0; k < 5; k++) {
            final to = padSealTo(env, kSealSizes[k]);
            expect(utf8Length(to), kSealSizes[k], reason: '$k');
            expect(unpad(to), unpad(env));
            for (var i = 0; i < 4; i++) {
              final w = await a.ss.encryptTo('b', env, size: kSealSizes[k]);
              expect(base64Decode(w)[0], kLsWhisper);
              expect(_wrapOf(w.length), _wraps[k], reason: '$k');
              expect(_cellsOf(w.length), _cells[k], reason: '$k');
              expect(unpad(await _open(b, 'a', w)), unpad(env));
              await _open(a, 'b', await b.ss.encryptTo('a', 'ok'));
            }
          }
        }
        // a frame past the burst's size keeps its own
        final big = '{"m":"${'w' * (kSealSizes[1] - 60)}"}';
        expect(padSealTo(big, kSealSizes[0]), padSeal(big));
        // an opener goes at the second size alone
        final c = await _phone('c');
        await _start(a, c);
        for (final k in [0, 2, 3, 4]) {
          await expectLater(
            a.ss.encryptTo('c', '{"m":"hi"}', size: kSealSizes[k]),
            throwsA(isA<WaitsForAnswer>()),
            reason: '$k',
          );
        }
        final w = await a.ss.encryptTo('c', '{"m":"hi"}', size: kSealSizes[1]);
        expect(base64Decode(w)[0], kLsPreKey);
        expect(_wrapOf(w.length), _wraps[1]);
      },
    );

    test('the five sizes wrap and cross the onion as one each', () {
      for (var k = 0; k < 5; k++) {
        expect(_wrapOf(_plainWire[k]), _wraps[k]);
        expect(_wrapOf(_openerWire[k]), _wraps[k]);
        expect(_wrapOf(kRumorSizes[k]), _wraps[k]);
        expect(_cellsOf(_plainWire[k]), _cells[k]);
        expect(_cellsOf(_openerWire[k]), _cells[k]);
      }
      // the largest a relay takes: a seal past it no longer fits nip-44
      expect(343 + _nip44(206 + _openerWire[4]), lessThanOrEqualTo(65535));
    });

    test('every kind lands on its size, plain or as an opener', () async {
      final seen = <int>{};
      for (final MapEntry(key: kind, value: (env, k))
          in (await _kinds()).entries) {
        final plain = await bob.ss.encryptTo('alice', env);
        final opener = await carol.ss.encryptTo('bob', env);
        expect(base64Decode(plain)[0], kLsWhisper);
        expect(base64Decode(opener)[0], kLsPreKey);
        expect(plain.length, _plainWire[k], reason: kind);
        // carol's opener names a one-time prekey, a shorter id than the
        // invite's: a few characters under the invite opener's size
        expect(
          opener.length,
          inInclusiveRange(_openerWire[k] - 8, _openerWire[k]),
          reason: kind,
        );
        expect(_wrapOf(plain.length), _wraps[k], reason: kind);
        expect(_wrapOf(opener.length), _wraps[k], reason: kind);
        seen.add(k);
        // and it opens to what was sent
        expect(unpad(await _open(alice, 'bob', plain)), env, reason: kind);
      }
      expect(seen, {0, 1, 2, 3, 4});
    });

    test('room and bundle frames wrap to the same sizes', () async {
      final pub = _hex(64);
      final g = _uid();
      final mid = _uid();
      Future<String> room(String w, int n) async =>
          roomFrame(w, pub, number: n)!;
      final frames = <String, (String, int)>{
        'room text': (
          await room(
            await wrapMessage(
              _words(40),
              msgUid: _uid(),
              groupId: g,
              sender: _me,
            ),
            12,
          ),
          0,
        ),
        'room join': (
          await room(
            await wrapMessage(
              '',
              groupId: g,
              groupControl: const GroupControl(type: 'join'),
              sender: _me,
            ),
            1,
          ),
          0,
        ),
        'room last slice': (
          await room(
            await wrapMessage(
              '',
              msgUid: mid,
              groupId: g,
              imageB64: _bytes64(900),
              mediaId: mid,
              chunkIndex: 8,
              chunkTotal: 9,
              sender: _me,
            ),
            14,
          ),
          3,
        ),
        // the card carries the kyber prekey now: the second size
        'bundle frame': (
          jsonEncode({
            'halo_ctl': 'bundle',
            'from': _me.haloId,
            'bundle': await makePreKeyBundleB64(alice.ss),
            'want': true,
            'since': _at,
          }),
          1,
        ),
      };
      for (final MapEntry(key: kind, value: (f, k)) in frames.entries) {
        final p = padRumor(f);
        expect(rumorLength(p), kRumorSizes[k], reason: kind);
        expect(_wrapOf(rumorLength(p)), _wraps[k], reason: kind);
      }
    });

    test('texts of any length in one size seal to the same bytes', () async {
      final lengths = <int>{};
      for (final n in [0, 1, 17, 90, 250, 400, 500]) {
        final env = await wrapMessage(
          _words(n),
          msgUid: _uid(),
          sender: _me,
          writtenAt: _at,
        );
        lengths.add((await bob.ss.encryptTo('alice', env)).length);
      }
      expect(lengths, {_plainWire[0]});
    });

    test('a receipt is the size of a short text', () async {
      final receipt = await alice.ss.encryptTo(
        'bob',
        await wrapMessage('', deliveredUid: _uid(), sender: _me),
      );
      final text = await alice.ss.encryptTo(
        'bob',
        await wrapMessage('see you', msgUid: _uid(), sender: _me),
      );
      expect(receipt.length, text.length);
    });

    test('the last slice of a file is the size of a full one', () async {
      final mid = _uid();
      Future<String> slice(int bytes, int i) async => alice.ss.encryptTo(
        'bob',
        await wrapMessage(
          '',
          msgUid: mid,
          fileB64: _bytes64(bytes),
          fileName: 'notes.pdf',
          mediaId: mid,
          chunkIndex: i,
          chunkTotal: 3,
          canResend: true,
          sender: _me,
        ),
      );
      final full = await slice(12288, 0);
      final last = await slice(10, 2);
      expect(last.length, full.length);
    });

    test('a frame too big for any route is not sealed', () async {
      final huge = 'halo/1:${jsonEncode({'m': 'x' * kSealOnionMost})}';
      await expectLater(
        bob.ss.encryptTo('alice', huge),
        throwsA(isA<FrameTooLarge>()),
      );
      // the session goes on as it was
      final env = await wrapMessage('after', sender: _me);
      expect(
        unpad(await _open(alice, 'bob', await bob.ss.encryptTo('alice', env))),
        env,
      );
    });

    test('a stranger\'s shelf has the room it had before the filler', () {
      // the largest file a stranger may leave, in opener slices, and a short
      // opener in every other place. 0.5.1 sealed them to 22496 and 588
      int room(int slice, int short) =>
          kShelfBytes - kShelfFileSlices * slice - (kShelfPlaces - 1) * short;
      expect(
        room(_openerWire[3], _openerWire[0]),
        greaterThanOrEqualTo((16 << 20) - kShelfFileSlices * 22496 - 19 * 588),
      );
    });

    test('the filler is inside the seal', () async {
      final env = await wrapMessage('hi', msgUid: _uid(), sender: _me);
      final wire = await bob.ss.encryptTo('alice', env);
      // what the other side's signal opens: the filler came through it
      final opened = await _open(alice, 'bob', wire);
      expect(opened, startsWith('halo/1:{"pz":"000'));
      expect(utf8Length(opened), kSealSizes[0]);
      // and nothing of it shows outside: the wire is signal's base64,
      // the size of the filled frame sealed
      final raw = base64Decode(wire);
      expect(raw.length, 16 * (kSealSizes[0] ~/ 16 + 1) + 52);
      expect(latin1.decode(raw, allowInvalid: true), isNot(contains('000000')));
    });
  });

  group('older versions', () {
    test('0.5.0 and 0.5.1 read a filled envelope as an unfilled one', () async {
      final kinds = await _kinds();
      for (final MapEntry(key: kind, value: (env, _)) in kinds.entries) {
        for (final filled in [padSeal(env), padRumor(env)]) {
          expect(filled, isNot(env));
          expect(
            _read(v050.unwrapMessage(filled)),
            _read(v050.unwrapMessage(env)),
            reason: '0.5.0 $kind',
          );
          expect(
            _read(v051.unwrapMessage(filled)),
            _read(v051.unwrapMessage(env)),
            reason: '0.5.1 $kind',
          );
          expect(
            _read(unwrapMessage(filled)),
            _read(unwrapMessage(env)),
            reason: kind,
          );
        }
      }
    });

    test('a filled room frame reads as it did', () async {
      final w = await wrapMessage(
        _words(40),
        msgUid: _uid(),
        groupId: _uid(),
        sender: _me,
      );
      final f = roomFrame(w, _hex(64), number: 7)!;
      final p = padRumor(f);
      expect(_read(v050.unwrapMessage(p)), _read(v050.unwrapMessage(f)));
      expect(_read(v051.unwrapMessage(p)), _read(v051.unwrapMessage(f)));
      expect(roomFramePlace(p), roomFramePlace(f));
    });
  });
}
