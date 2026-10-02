// SPDX-License-Identifier: GPL-3.0-or-later
// a catch-up comes back from the relays in any order. one sender's
// messages on one chain are opened in the order they were sent; everyone
// else keeps their place. real signal messages, sealed by real stores
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart';
import 'package:kryfo/send_order.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/signal_stores.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'mem_db.dart';
import 'source_body.dart';

typedef _Phone = ({SignalSession ss, String name});
typedef _Got = ({String peer, String cipher});

Future<_Phone> _phone(String name) async {
  final pair = Curve.generateKeyPair();
  final ss = SignalSession();
  await ss.bootstrap(
    database: MemDb(),
    xPubBytes: pair.publicKey.serialize().sublist(1),
    xPrivBytes: pair.privateKey.serialize(),
  );
  return (ss: ss, name: name);
}

Future<void> _start(_Phone from, _Phone to) async {
  final spk = await to.ss.signedPreKeyStore.loadSignedPreKey(1);
  final pk = await to.ss.preKeyStore.loadPreKey(invitePreKeyId);
  await SessionBuilder(
    from.ss.sessionStore,
    from.ss.preKeyStore,
    from.ss.signedPreKeyStore,
    from.ss.identityStore,
    SignalProtocolAddress(to.name, 1),
  ).processPreKeyBundle(
    PreKeyBundle(
      to.ss.registrationId,
      1,
      pk.id,
      pk.getKeyPair().publicKey,
      spk.id,
      spk.getKeyPair().publicKey,
      spk.signature,
      to.ss.identityKeyPair.getPublicKey(),
    ),
  );
}

Future<String> _open(_Phone at, _Phone from, String wireB64) async {
  final wire = base64Decode(wireB64);
  final body = Uint8List.fromList(wire.sublist(1));
  final c = SessionCipher(
    at.ss.sessionStore,
    at.ss.preKeyStore,
    at.ss.signedPreKeyStore,
    at.ss.identityStore,
    SignalProtocolAddress(from.name, 1),
  );
  final plain = wire[0] == CiphertextMessage.prekeyType
      ? await c.decrypt(PreKeySignalMessage(body))
      : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
  return utf8.decode(plain);
}

List<_Got> _ordered(List<_Got> batch, {bool Function(String)? lane}) =>
    inSendOrder(
      batch,
      peer: (m) => m.peer,
      cipher: (m) => m.cipher,
      lane: lane,
    );

void main() {
  late _Phone me;
  late _Phone alice;
  late _Phone carol;

  setUp(() async {
    me = await _phone('me');
    alice = await _phone('alice');
    carol = await _phone('carol');
    await _start(alice, me);
    await _start(carol, me);
  });

  Future<List<String>> said(_Phone from, List<String> words) async => [
    for (final w in words) await from.ss.encryptTo('me', w),
  ];

  test('one sender\'s openers go back in the order they were sent', () async {
    final a = await said(alice, ['are you free?', 'at 6', 'at the station']);
    final batch = [
      (peer: 'x-alice', cipher: a[2]),
      (peer: 'x-alice', cipher: a[0]),
      (peer: 'x-alice', cipher: a[1]),
    ];
    final out = _ordered(batch);
    expect(
      [for (final m in out) await _open(me, alice, m.cipher)],
      ['are you free?', 'at 6', 'at the station'],
    );
  });

  test('plain messages on one chain too, others keep their places', () async {
    // a reply makes alice's next ones plain messages on a new chain
    expect(await _open(me, alice, (await said(alice, ['hi'])).single), 'hi');
    final back = await me.ss.encryptTo('alice', 'hey');
    expect(await _open(alice, me, back), 'hey');
    final a = await said(alice, ['one', 'two', 'three', 'four']);
    final c = await said(carol, ['c0']);
    final batch = <_Got>[
      (peer: 'x-alice', cipher: a[3]),
      (peer: 'x-carol', cipher: c[0]),
      (peer: 'x-alice', cipher: a[1]),
      (peer: 'room:abc', cipher: 'not signal'),
      (peer: 'x-alice', cipher: a[0]),
      (peer: 'x-alice', cipher: a[2]),
    ];
    final out = _ordered(batch);
    expect(out[1], batch[1]);
    expect(out[3], batch[3]);
    final alices = [
      for (final m in out)
        if (m.peer == 'x-alice') await _open(me, alice, m.cipher),
    ];
    expect(alices, ['one', 'two', 'three', 'four']);
  });

  test('a lane many senders share is left as it came', () async {
    final a = await said(alice, ['a0', 'a1']);
    final batch = [
      (peer: 'firstcontact', cipher: a[1]),
      (peer: 'firstcontact', cipher: a[0]),
    ];
    expect(_ordered(batch, lane: (p) => p == 'firstcontact'), batch);
  });

  // two strangers write first, their openers shuffled together on the one
  // lane every stranger shares
  test('strangers\' openers are put in order, each apart', () async {
    final a = await said(alice, ['a0', 'a1', 'a2']);
    final c = await said(carol, ['c0', 'c1', 'c2']);
    final batch = <_Got>[
      (peer: 'firstcontact', cipher: c[2]),
      (peer: 'firstcontact', cipher: a[1]),
      (peer: 'firstcontact', cipher: c[0]),
      (peer: 'firstcontact', cipher: a[2]),
      (peer: 'firstcontact', cipher: a[0]),
      (peer: 'firstcontact', cipher: c[1]),
    ];
    final out = _ordered(batch, lane: keepsArrivalOrder);
    final alices = {...a};
    // every place keeps the sender it had
    for (var i = 0; i < batch.length; i++) {
      expect(
        alices.contains(out[i].cipher),
        alices.contains(batch[i].cipher),
        reason: 'place $i',
      );
    }
    expect(
      [
        for (final m in out)
          if (alices.contains(m.cipher)) await _open(me, alice, m.cipher),
      ],
      ['a0', 'a1', 'a2'],
    );
    expect(
      [
        for (final m in out)
          if (!alices.contains(m.cipher)) await _open(me, carol, m.cipher),
      ],
      ['c0', 'c1', 'c2'],
    );
  });

  test('only room frames keep the order they came in', () {
    expect(keepsArrivalOrder('room:abc'), isTrue);
    expect(keepsArrivalOrder('roomfc:abc'), isTrue);
    expect(keepsArrivalOrder('firstcontact'), isFalse);
    expect(keepsArrivalOrder('ab' * 32), isFalse);
  });

  group('room frames', () {
    // a frame off [from]'s lane, as the relay layer hands it over
    Future<_Got> frame(String from, int? n, String text, {String? gc}) async {
      final w = await wrapMessage(
        text,
        groupId: 'room1',
        groupControl: gc == null ? null : GroupControl(type: gc),
        sender: SenderInfo(haloId: from, edPub: '', onion: '', xPub: ''),
      );
      return (peer: 'room:mine:$from', cipher: roomFrame(w, from, number: n)!);
    }

    List<String> texts(List<_Got> out) => [
      for (final m in out) unwrapMessage(m.cipher).message,
    ];

    List<_Got> sorted(List<_Got> batch) => roomsInSendOrder(
      batch,
      peer: (m) => m.peer,
      place: (m) => roomFramePlace(m.cipher),
    );

    test('each lane by its numbers, in the places it had', () async {
      final batch = [
        await frame('x', 3, 'x3'),
        (peer: 'x-alice', cipher: 'not a room'),
        await frame('y', 2, 'y2'),
        await frame('x', 1, 'x1'),
        await frame('y', 1, 'y1'),
        await frame('x', 2, 'x2'),
      ];
      final out = sorted(batch);
      expect(out[1], batch[1]);
      expect([for (final m in out) m.peer], [for (final m in batch) m.peer]);
      expect(texts([out[0], out[3], out[5]]), ['x1', 'x2', 'x3']);
      expect(texts([out[2], out[4]]), ['y1', 'y2']);
    });

    test('a frame with no number keeps its place', () async {
      final batch = [
        await frame('x', 2, 'x2'),
        await frame('x', null, 'old'),
        await frame('x', 1, 'x1'),
      ];
      expect(texts(sorted(batch)), ['x1', 'old', 'x2']);
    });

    test('a leave or a removal goes after the rest of the batch', () async {
      final batch = [
        await frame('c', 7, '', gc: 'remove'),
        await frame('x', 3, '', gc: 'leave'),
        await frame('x', 2, 'bye'),
        (peer: 'x-alice', cipher: 'not a room'),
        await frame('y', null, '', gc: 'leave'),
        await frame('y', null, 'later'),
        await frame('c', 6, 'hi'),
      ];
      final out = sorted(batch);
      expect(
        [
          for (final m in out)
            m.peer.startsWith('room:')
                ? unwrapMessage(m.cipher).groupControl?.type ??
                      unwrapMessage(m.cipher).message
                : m.cipher,
        ],
        // the creator's hi was written before its removal
        ['hi', 'bye', 'not a room', 'later', 'leave', 'leave', 'remove'],
      );
      expect(out.map((m) => m.peer).toSet(), batch.map((m) => m.peer).toSet());
    });

    test('the drop box lane and other lanes are not touched', () async {
      final batch = [
        (peer: 'roomfc:mine', cipher: (await frame('x', 2, 'b')).cipher),
        (peer: 'roomfc:mine', cipher: (await frame('x', 1, 'a')).cipher),
        (peer: 'x-alice', cipher: 'one'),
      ];
      expect(sorted(batch), batch);
    });

    test('a frame carries its number and nothing of who sent it', () async {
      final w = await wrapMessage(
        'hi',
        groupId: 'room1',
        sender: SenderInfo(haloId: 'me', edPub: 'e', onion: 'o', xPub: 'x'),
      );
      expect(roomFramePlace(roomFrame(w, 'k', number: 5)!), (
        number: 5,
        shrinks: false,
      ));
      expect(roomFramePlace(roomFrame(w, 'k')!).number, isNull);
      expect(roomFramePlace('not a frame'), (number: null, shrinks: false));
    });
  });

  test('the relay receiver sorts with that rule', () {
    final app = sourceOf('lib/main.dart');
    final from = app.indexOf('Future<void> receiveRelay(');
    // up to its loop: the body holds a brace in a string further on
    final head = app.substring(from, app.indexOf('for (final m in', from));
    final sort = callsOf(head, 'inSendOrder(').single;
    expect(sort, contains('lane: keepsArrivalOrder'));
    // and the room frames after it, by their own numbers
    final rooms = callsOf(head, 'roomsInSendOrder(').single;
    expect(rooms, contains('roomFramePlace(m.cipher)'));
  });
}
