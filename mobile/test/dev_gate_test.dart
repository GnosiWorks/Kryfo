// SPDX-License-Identifier: GPL-3.0-or-later
// the dev gate: the engine's 1:1 doors reach the developer's keys only for
// the dev chat, the way it was started. nothing is sent before the first
// send, nothing after a delete, nothing for another chat or key. and an id
// or card from the wire is his only by his keys, never by his words
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_gate.dart';
import 'package:kryfo/devchat/dev_key.dart';

String _x(int n) => n.toRadixString(16).padLeft(2, '0') * 32;

// a bundle as far as the gate reads one: its identity key
String _bundle(String xPub) => base64Encode(
  utf8.encode(
    jsonEncode({
      'identityKey': base64Encode([
        5,
        for (var i = 0; i < 64; i += 2)
          int.parse(xPub.substring(i, i + 2), radix: 16),
      ]),
    }),
  ),
);

DevKey _key(
  String id,
  int n, {
  DevKeyStatus status = DevKeyStatus.current,
  String onion = '',
}) => DevKey(
  keyId: id,
  threeWords: 'calm-$id-stone',
  xPub: _x(n),
  bundle: _bundle(_x(n)),
  fc: _x(n + 1),
  onion: onion,
  status: status,
);

final _m1 = _key('m1', 0x11);
final _m2 = _key('m2', 0x22);
final _other = _x(0x33);
final _otherFc = _x(0x34);

DevChatRow _row(DevState s, {String keyId = 'm1', String? priv}) => DevChatRow(
  state: s,
  keyId: keyId,
  createdAt: 1,
  anonXPriv: priv ?? (s == DevState.anon ? 'anon-priv' : null),
);

bool _tok(String c) => c == 'minted';

// the calls a door made, as a stand-in for the engine
class _Out {
  final calls = <String>[];

  Future<String> out() async {
    calls.add('out');
    return 'ok';
  }

  Future<String> room(String priv) async {
    calls.add('room $priv');
    return 'ok';
  }
}

void main() {
  setUp(() => useDevKeysForTest([_m1, _m2]));
  tearDown(() => useDevKeysForTest(null));

  group('the table', () {
    test('nothing is sent before the user writes, or after a delete', () {
      for (final r in [null, _row(DevState.fresh), _row(DevState.gone)]) {
        expect(DevGate.relayWay(r, _m1, 'minted', _tok), DevWay.refused);
        expect(
          DevGate.firstContactWay(r, _m1, _m1, 'minted', _tok),
          DevWay.refused,
        );
        expect(DevGate.listenWay(r, _m1), DevWay.refused);
        expect(
          DevGate.onionWay(r, _key('m1', 0x11, onion: 'x.onion')),
          DevWay.refused,
        );
        expect(DevGate.roomOk(r, _m1, 'anon-priv'), isFalse);
      }
    });

    test('everyday: the pinned lanes pass as they are', () {
      final r = _row(DevState.everyday);
      expect(DevGate.relayWay(r, _m1, 'anything', _tok), DevWay.pass);
      expect(
        DevGate.firstContactWay(r, _m1, _m1, 'anything', _tok),
        DevWay.pass,
      );
      expect(DevGate.listenWay(r, _m1), DevWay.pass);
      // relay only: no onion is pinned, so none is reached
      expect(DevGate.onionWay(r, _m1), DevWay.refused);
      expect(
        DevGate.onionWay(r, _key('m1', 0x11, onion: 'dev.onion')),
        DevWay.pass,
      );
      // an everyday chat never goes out as a room name
      expect(DevGate.roomOk(r, _m1, 'anon-priv'), isFalse);
    });

    test('anonymous: only its own ciphers, and only as its own name', () {
      final r = _row(DevState.anon);
      expect(
        DevGate.relayWay(r, _m1, 'minted', _tok),
        const DevWay.room('anon-priv'),
      );
      expect(DevGate.relayWay(r, _m1, 'bundle json', _tok), DevWay.refused);
      expect(
        DevGate.firstContactWay(r, _m1, _m1, 'minted', _tok),
        const DevWay.room('anon-priv'),
      );
      expect(
        DevGate.firstContactWay(r, _m1, _m1, 'other', _tok),
        DevWay.refused,
      );
      expect(DevGate.listenWay(r, _m1), const DevWay.room('anon-priv'));
      expect(
        DevGate.onionWay(r, _key('m1', 0x11, onion: 'dev.onion')),
        DevWay.refused,
      );
      expect(DevGate.roomOk(r, _m1, 'anon-priv'), isTrue);
      expect(DevGate.roomOk(r, _m1, 'anon-priv', ok: false), isFalse);
      expect(DevGate.roomOk(r, _m1, 'someone-else'), isFalse);
      // an anonymous chat that lost its name reaches no one
      final lost = _row(DevState.anon, priv: '');
      expect(DevGate.relayWay(lost, _m1, 'minted', _tok), DevWay.refused);
      expect(DevGate.listenWay(lost, _m1), DevWay.refused);
      expect(DevGate.roomOk(lost, _m1, ''), isFalse);
    });

    test('a chat reaches its own key only, and a retired key no one', () {
      final onM2 = _row(DevState.everyday, keyId: 'm2');
      expect(DevGate.relayWay(onM2, _m1, 'x', _tok), DevWay.refused);
      expect(DevGate.relayWay(onM2, _m2, 'x', _tok), DevWay.pass);
      final previous = _key('m1', 0x11, status: DevKeyStatus.previous);
      final retired = _key('m1', 0x11, status: DevKeyStatus.retired);
      final r = _row(DevState.everyday);
      expect(DevGate.relayWay(r, previous, 'x', _tok), DevWay.pass);
      expect(DevGate.relayWay(r, retired, 'x', _tok), DevWay.refused);
      expect(DevGate.listenWay(r, retired), DevWay.refused);
      expect(
        DevGate.roomOk(_row(DevState.anon), retired, 'anon-priv'),
        isFalse,
      );
    });

    test('a first contact goes to the pinned fc of the same key', () {
      final r = _row(DevState.everyday);
      expect(DevGate.firstContactWay(r, _m1, null, 'x', _tok), DevWay.refused);
      expect(DevGate.firstContactWay(r, null, _m1, 'x', _tok), DevWay.refused);
      expect(DevGate.firstContactWay(r, _m1, _m2, 'x', _tok), DevWay.refused);
    });
  });

  group('the doors', () {
    test('a call naming no pinned key goes out without a look', () async {
      var reads = 0;
      final gate = DevGate(
        chat: () async {
          reads++;
          return _row(DevState.fresh);
        },
      );
      final o = _Out();
      await gate.nostrSend(_other, 'c', out: o.out, room: o.room);
      await gate.sendFirstContact(
        _other,
        _otherFc,
        'c',
        out: o.out,
        room: o.room,
      );
      await gate.sendTo('someone.onion', out: o.out);
      await gate.listen(_other, out: o.out, room: o.room);
      await gate.roomSend('p', _other, 'c', out: o.out);
      await gate.roomSendFirstContact('p', _other, _otherFc, 'c', out: o.out);
      await gate.roomListen('p', _other, out: o.out);
      expect(o.calls, List.filled(7, 'out'));
      expect(reads, 0);
    });

    test('fresh and gone: every door naming a pinned key is shut', () async {
      for (final s in [DevState.fresh, DevState.gone]) {
        final gate = DevGate(chat: () async => _row(s), minted: _tok);
        final o = _Out();
        final said = [
          await gate.nostrSend(_m1.xPub, 'minted', out: o.out, room: o.room),
          await gate.sendFirstContact(
            _m1.xPub,
            _m1.fc,
            'minted',
            out: o.out,
            room: o.room,
          ),
          // the fc alone names him too
          await gate.sendFirstContact(
            _other,
            _m1.fc,
            'minted',
            out: o.out,
            room: o.room,
          ),
          await gate.listen(_m1.xPub, out: o.out, room: o.room),
          await gate.roomSend('anon-priv', _m1.xPub, 'minted', out: o.out),
          await gate.roomSendFirstContact(
            'anon-priv',
            _m1.xPub,
            _m1.fc,
            'minted',
            out: o.out,
          ),
          await gate.roomListen('anon-priv', _m1.xPub, out: o.out),
        ];
        expect(said, everyElement(kDevRefused));
        expect(o.calls, isEmpty);
      }
    });

    test('a pinned onion is shut but for an everyday chat', () async {
      useDevKeysForTest([_key('m1', 0x11, onion: 'devphone.onion')]);
      final o = _Out();
      final fresh = DevGate(chat: () async => _row(DevState.fresh));
      for (final a in [
        'devphone.onion',
        'DEVPHONE.onion',
        'http://devphone.onion:80/x',
      ]) {
        expect(await fresh.sendTo(a, out: o.out), kDevRefused);
      }
      final anon = DevGate(chat: () async => _row(DevState.anon));
      expect(await anon.sendTo('devphone.onion', out: o.out), kDevRefused);
      expect(o.calls, isEmpty);
      final everyday = DevGate(chat: () async => _row(DevState.everyday));
      expect(await everyday.sendTo('devphone.onion', out: o.out), 'ok');
      expect(o.calls, ['out']);
    });

    test('everyday: out as asked', () async {
      final gate = DevGate(chat: () async => _row(DevState.everyday));
      final o = _Out();
      await gate.nostrSend(
        _m1.xPub.toUpperCase(),
        'c',
        out: o.out,
        room: o.room,
      );
      await gate.sendFirstContact(
        _m1.xPub,
        _m1.fc,
        'c',
        out: o.out,
        room: o.room,
      );
      await gate.listen(_m1.xPub, out: o.out, room: o.room);
      expect(o.calls, ['out', 'out', 'out']);
      // but never to his fc under another key
      expect(
        await gate.sendFirstContact(
          _other,
          _m1.fc,
          'c',
          out: o.out,
          room: o.room,
        ),
        kDevRefused,
      );
      expect(await gate.roomSend('p', _m1.xPub, 'c', out: o.out), kDevRefused);
      expect(o.calls, hasLength(3));
    });

    test('anonymous: through the room exports as its own name', () async {
      final gate = DevGate(chat: () async => _row(DevState.anon), minted: _tok);
      final o = _Out();
      await gate.nostrSend(_m1.xPub, 'minted', out: o.out, room: o.room);
      await gate.sendFirstContact(
        _m1.xPub,
        _m1.fc,
        'minted',
        out: o.out,
        room: o.room,
      );
      await gate.listen(_m1.xPub, out: o.out, room: o.room);
      expect(o.calls, List.filled(3, 'room anon-priv'));
      o.calls.clear();
      // what the chat's own encrypt did not make stays
      expect(
        await gate.nostrSend(
          _m1.xPub,
          '{"halo_ctl":"bundle"}',
          out: o.out,
          room: o.room,
        ),
        kDevRefused,
      );
      expect(o.calls, isEmpty);
      // the reroute itself passes as that name, and only as it
      await gate.roomSend('anon-priv', _m1.xPub, 'minted', out: o.out);
      await gate.roomSendFirstContact(
        'anon-priv',
        _m1.xPub,
        _m1.fc,
        'minted',
        out: o.out,
      );
      await gate.roomListen('anon-priv', _m1.xPub, out: o.out);
      expect(o.calls, ['out', 'out', 'out']);
      o.calls.clear();
      final shut = [
        await gate.roomSend('room-key', _m1.xPub, 'minted', out: o.out),
        await gate.roomSend('anon-priv', _m1.xPub, 'other', out: o.out),
        await gate.roomSendFirstContact(
          'anon-priv',
          _m1.xPub,
          _otherFc,
          'minted',
          out: o.out,
        ),
        await gate.roomListen('room-key', _m1.xPub, out: o.out),
      ];
      expect(shut, everyElement(kDevRefused));
      expect(o.calls, isEmpty);
    });

    test('no chat to read, or one that will not read, shuts him out', () async {
      final o = _Out();
      final none = DevGate();
      expect(
        await none.nostrSend(_m1.xPub, 'c', out: o.out, room: o.room),
        kDevRefused,
      );
      final broken = DevGate(chat: () async => throw StateError('locked'));
      expect(
        await broken.nostrSend(_m1.xPub, 'c', out: o.out, room: o.room),
        kDevRefused,
      );
      await broken.listen(_m1.xPub, out: o.out, room: o.room);
      expect(o.calls, isEmpty);
      // everyone else still goes out
      await broken.nostrSend(_other, 'c', out: o.out, room: o.room);
      expect(o.calls, ['out']);
    });

    test('a call that cannot wait says whether it names him', () {
      final gate = DevGate();
      expect(gate.names(xPub: _m1.xPub), isTrue);
      expect(gate.names(fc: _m2.fc), isTrue);
      expect(gate.names(xPub: _other, fc: _otherFc), isFalse);
      useDevKeysForTest(const []);
      expect(gate.names(xPub: _m1.xPub), isFalse);
    });
  });

  group('who the wire says is him', () {
    test('an id: a dev chat id, his words or his key', () {
      for (final id in [
        'dev:m1',
        'DEV:m9',
        ' dev:x',
        _m1.threeWords,
        _m1.threeWords.toUpperCase(),
        _m2.threeWords,
        _m1.xPub,
        _m2.xPub.toUpperCase(),
      ]) {
        expect(devIdClaim(id), isTrue, reason: id);
      }
      for (final id in ['calm-river-stone', 'devious-fox-run', _other, '']) {
        expect(devIdClaim(id), isFalse, reason: id);
      }
      // a retired key's words are no one else's either
      useDevKeysForTest([_key('m1', 0x11, status: DevKeyStatus.retired), _m2]);
      expect(devIdClaim(_m1.threeWords), isTrue);
    });

    test('a card: its id, its x key or its first-contact address', () {
      expect(devCardClaim(id: 'amber-fox-run', xPub: _m1.xPub), isTrue);
      expect(devCardClaim(id: 'amber-fox-run', fc: _m2.fc), isTrue);
      expect(devCardClaim(id: _m1.threeWords), isTrue);
      expect(
        devCardClaim(id: 'amber-fox-run', xPub: _other, fc: _otherFc),
        isFalse,
      );
      expect(devCardClaim(id: 'amber-fox-run', xPub: '', fc: ''), isFalse);
    });

    test('a link: his key opens his chat, his words with another refuse', () {
      String words(DevKey k) => k.threeWords;
      expect(
        devCardOf(id: 'amber-fox-run', bundle: _bundle(_other)),
        DevCard.none,
      );
      expect(devCardOf(id: words(_m1), bundle: _m1.bundle), DevCard.dev);
      // his key under other words is still his key
      expect(devCardOf(id: 'amber-fox-run', bundle: _m1.bundle), DevCard.dev);
      expect(
        devCardOf(id: words(_m1), bundle: _bundle(_other)),
        DevCard.mismatch,
      );
      expect(devCardOf(id: words(_m1), bundle: _m2.bundle), DevCard.mismatch);
      expect(
        devCardOf(id: words(_m1), bundle: 'not a bundle'),
        DevCard.mismatch,
      );
      // a v1 card carries its key as an xpub
      expect(devCardOf(id: words(_m1), xPub: _m1.xPub), DevCard.dev);
      expect(devCardOf(id: words(_m1), xPub: _other), DevCard.mismatch);
      expect(devCardOf(id: words(_m1)), DevCard.mismatch);
      // an id only this phone makes is no card's
      expect(devCardOf(id: 'dev:m1', bundle: _m1.bundle), DevCard.refused);
      // with nothing pinned, only that
      useDevKeysForTest(const []);
      expect(devCardOf(id: words(_m1), bundle: _m1.bundle), DevCard.none);
      expect(devCardOf(id: 'dev:m1'), DevCard.refused);
    });

    test('a bundle names the key it carries', () {
      expect(devKeyByBundle(_m2.bundle)?.keyId, 'm2');
      expect(devKeyByBundle(_bundle(_other)), isNull);
      expect(devKeyByBundle('%%%'), isNull);
      expect(devKeyByBundle(base64Encode(utf8.encode('[1]'))), isNull);
    });
  });

  // read off the source: every 1:1 door of the engine asks the gate, and
  // the raw calls behind them are reached from those doors alone
  test('the engine asks the gate at every door', () {
    final src = File('lib/main.dart').readAsStringSync();
    final start = src.indexOf('class HaloEngine {');
    final end = src.indexOf('\n}\n', start);
    expect(start, isNonNegative);
    final engine = src.substring(start, end);
    String body(String sig) {
      final i = engine.indexOf(sig);
      expect(i, isNonNegative, reason: sig);
      final next = engine.indexOf('\n\n', i);
      return engine.substring(i, next < 0 ? engine.length : next);
    }

    final doors = {
      'Future<String> nostrSend(': ['devGate.nostrSend(', '_sendOnIsolate('],
      'void nostrSubscribeBg(': ['devGate', '.listen(', '_subscribeOnIsolate('],
      'Future<String> sendFirstContact(': [
        'devGate.sendFirstContact(',
        '_fcSendOnIsolate(',
      ],
      'Future<String> sendTo(': ['devGate.sendTo(', '_sendOnIsolate('],
      'String nostrSubscribe(': ['devGate.names(xPub:', '_nostrSubscribe('],
      'Future<String> roomSend(': ['devGate.roomSend(', "'HaloRoomSend'"],
      'Future<String> roomSendFirstContact(': [
        'devGate.roomSendFirstContact(',
        "'HaloRoomSendFirstContact'",
      ],
      'void roomSubscribeBg(': ['.roomListen(', "'HaloRoomSubscribe'"],
    };
    for (final e in doors.entries) {
      final b = body(e.key);
      for (final need in e.value) {
        expect(b, contains(need), reason: '${e.key} lacks $need');
      }
      // the gate is asked before anything leaves
      final gate = b.indexOf('devGate');
      expect(gate, isNonNegative, reason: e.key);
      for (final raw in e.value.skip(1)) {
        expect(gate, lessThan(b.indexOf(raw)), reason: e.key);
      }
    }
    int count(String s) => s.allMatches(src).length;
    // the doors above, plus each helper's own definition
    expect(count('_sendOnIsolate('), 3);
    expect(count('_fcSendOnIsolate('), 2);
    expect(count('_subscribeOnIsolate('), 2);
    expect(count('_nostrSubscribe('), 1);
    expect(count("'HaloRoomSend'"), 1);
    expect(count("'HaloRoomSendFirstContact'"), 1);
    expect(count("'HaloRoomSubscribe'"), 1);
  });
}
