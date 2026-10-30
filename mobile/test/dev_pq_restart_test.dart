// SPDX-License-Identifier: GPL-3.0-or-later
// the dev chat's pq restart on the pinned card (DECIDED 2026-10-28: his
// main invite never expires): a chat started on a classic card goes over
// to pq at its next seal once the pinned card carries a kyber prekey, his
// phone opens the opener on its held record and the invite's keys, his
// answer says so on the seat, and the classic states can go after it. a
// classic card, as m1 is, changes nothing. the 0.7.4 fixture's held chat
// stands in: alice is his phone, bob the person writing to him
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/dev_lane.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart' show lsBundleOf;

import 'mem_db.dart';
import 'pq_restart_kit.dart';

const _chat = 'dev:t9';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Phone his;
  late Phone mine;
  late List<String> over;

  setUp(() async {
    if (needsShim != false) return;
    his = await fixturePhone('alice');
    mine = await fixturePhone('bob');
    expect(await mine.read('alice', fixtureWire('a6')), 'a6 pending');
    expect(await his.read('bob', await mine.seal('alice', 'b0')), 'b0');
    // the dev chat runs on the held session, under its own id
    final s = mine.ls!;
    await s.sessionStore.store(_chat, (await s.sessionStore.load('alice'))!);
    over = [];
  });

  tearDown(() => useDevKeysForTest(null));

  // his card: the main invite's keys his phone made, as the pin carries it
  Future<DevKey> pqCard() async {
    final h = his.ls!;
    final k = await h.makeInviteKeys('9' * 32);
    final card = base64Encode(
      utf8.encode(
        jsonEncode({
          'registrationId': h.registrationId,
          'deviceId': 1,
          'signedPreKeyId': k.spk.id,
          'signedPreKeyPublic': base64Encode(k.spk.public),
          'signedPreKeySignature': base64Encode(k.spk.signature),
          'kyberPreKeyId': k.kyber.id,
          'kyberPreKeyPublic': base64Encode(k.kyber.public),
          'kyberPreKeySignature': base64Encode(k.kyber.signature),
          'identityKey': base64Encode(h.identity.public),
        }),
      ),
    );
    return DevKey(
      keyId: 't9',
      threeWords: 'test-dev-card',
      xPub: hexOf(h.identity.public.sublist(1)),
      bundle: card,
      fc: 'ab' * 32,
    );
  }

  // the dev chat keeps his pinned key alone, once the build pins it
  Future<DevLane> laneFor(DevKey k) async {
    useDevKeysForTest([k]);
    await mine.ls!.identityStore.saw(_chat, his.ls!.identity.public);
    final rows = MemDb();
    rows.insert('contacts', {
      'halo_id': _chat,
      'onion': '',
      'xpub': k.xPub,
      'first_seen': 1,
      'last_seen': 1,
    });
    return DevLane(
      chat: () async => const DevChatRow(
        state: DevState.everyday,
        keyId: 't9',
        createdAt: 1,
        startedAt: 1,
      ),
      open: () async => rows,
      everyday: () => mine.ls!,
      frame: (w, {anon}) => w,
    )..onPqOver = over.add;
  }

  test('a classic chat goes over to pq on the pinned pq card: his phone '
      'opens the opener on its held record, his answer says so, and the '
      'classic states can go', () async {
    final card = await pqCard();
    final lane = await laneFor(card);
    mine.ls!.onPqOver = over.add;
    expect((await mine.ls!.sessionInfo(_chat))!.version, 3);
    final opener = await lane.encrypt(_chat, 'on pq now');
    expect(base64Decode(opener)[0], kLsPreKey);
    final s = (await mine.ls!.sessionInfo(_chat))!;
    expect(s.version, 4);
    expect(s.archived.map((x) => x.version), contains(3));
    // a second seal before his answer is the same opener's, nothing built
    final again = await lane.encrypt(_chat, 'still waiting');
    expect(base64Decode(again)[0], kLsPreKey);
    expect(
      (await mine.ls!.sessionInfo(
        _chat,
      ))!.archived.where((x) => x.version == 4),
      isEmpty,
    );
    // his phone: on the held record, the main invite's keys
    expect(await his.read('bob', opener), 'on pq now');
    expect(await his.read('bob', again), 'still waiting');
    final theirs = (await his.ls!.sessionInfo('bob'))!;
    expect(theirs.version, 4);
    expect(theirs.archived.map((x) => x.version), contains(3));
    // his answer: the seat says its side is over, and the next seal is plain
    final answer = await his.seal('bob', 'heard you');
    expect(base64Decode(answer)[0], kLsWhisper);
    expect(await mine.read(_chat, answer), 'heard you');
    expect(over, [_chat]);
    final next = await lane.encrypt(_chat, 'plain now');
    expect(base64Decode(next)[0], kLsWhisper);
    expect(await mine.ls!.dropClassic(_chat), greaterThan(0));
    expect(
      (await mine.ls!.sessionInfo(_chat))!.archived.where((x) => x.version < 4),
      isEmpty,
    );
  }, skip: needsShim);

  test('another key on his card\'s keys is a key change on the held chat, '
      'never a silent restart, and a card on another key restarts nothing '
      'here', () async {
    // a card whose key is not the one the chat runs on: nothing built
    final other = Phone();
    await other.openLs();
    final k = await other.ls!.makeInviteKeys('8' * 32);
    final bundle = other.ls!.lib.bundleBuild(
      registrationId: other.ls!.registrationId,
      deviceId: 1,
      preKeyId: null,
      preKey: null,
      signedPreKeyId: k.spk.id,
      signedPreKey: k.spk.public,
      signedPreKeySignature: k.spk.signature,
      kyberPreKeyId: k.kyber.id,
      kyberPreKey: k.kyber.public,
      kyberPreKeySignature: k.kyber.signature,
      identityKey: other.ls!.identity.public,
    );
    expect(
      await mine.ls!.restartFrom(_chat, bundle, classicOnly: true),
      isFalse,
    );
    expect((await mine.ls!.sessionInfo(_chat))!.version, 3);
    final card = await pqCard();
    // a real restart from the seat reads as no change of key
    final lane = await laneFor(card);
    final real = base64Decode(await lane.encrypt(_chat, 'from the seat'));
    var moved = 0;
    await his.ls!.open(
      'bob',
      real[0],
      Uint8List.fromList(real.sublist(1)),
      moved: () => moved++,
    );
    expect(moved, 0);
    // someone else builds on his pinned card and writes on the seat's name:
    // the store says the key moved, which the app holds and shows as for
    // any chat (this isn't them, the new number line)
    final eve = Phone();
    await eve.openLs();
    await eve.ls!.processBundle('alice', lsBundleOf(eve.ls!.lib, card.bundle));
    final forged = base64Decode(await eve.seal('alice', 'not the seat'));
    expect(forged[0], kLsPreKey);
    await his.ls!.open(
      'bob',
      forged[0],
      Uint8List.fromList(forged.sublist(1)),
      moved: () => moved++,
    );
    expect(moved, 1);
  }, skip: needsShim);

  test('a classic card, as m1 is, starts nothing', () async {
    final classic = DevKey(
      keyId: 't9',
      threeWords: 'test-dev-card',
      xPub: hexOf(his.ls!.identity.public.sublist(1)),
      bundle: await his.classicCard(),
      fc: 'ab' * 32,
    );
    final lane = await laneFor(classic);
    final w = await lane.encrypt(_chat, 'classic still');
    expect(base64Decode(w)[0], kLsWhisper);
    expect((await mine.ls!.sessionInfo(_chat))!.version, 3);
    expect(await his.read('bob', w), 'classic still');
  }, skip: needsShim);
}
