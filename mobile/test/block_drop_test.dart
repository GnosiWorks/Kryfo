// SPDX-License-Identifier: GPL-3.0-or-later
// what someone blocked sends while the block holds is dropped for good: a
// copy of it after the unblock, sent again or held by the relays, never
// lands in requests or the chat. what they send after the unblock does.
// what an ended block alone turns away by its stamp is not noted, so a
// copy sent again lands, and the last ten minutes before the unblock are
// given to a slow clock. a span judges by when it was written, which the
// envelope carries on every retry, so a copy wrapped again after the
// unblock stays out; a sender without it is judged by the wrap time. the
// block takes what of theirs is in the shade with it, outside the decoy.
// signal and the database are the app's stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

// a friend, and a stranger whose request was blocked
const _f = 'plain-friend-here';
const _s = 'guitar-present-kid';

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// as signal: a cipher opens once
class _OnceIo extends ArrivalIo {
  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    final r = await super.decrypt(peer, cipher, flagKeyChange: flagKeyChange);
    if (r != null) opens.remove(cipher);
    return r;
  }
}

class _Rows extends ArrivalRows {
  _Rows([super.container = HaloContainer.everyday]);

  @override
  Future<void> dropHeld(String peerId) async => heldRows.remove(peerId);

  @override
  Future<Set<String>> blockedIds() async => {
    for (final p in people.values)
      if (p['blocked'] == 1) p['halo_id'] as String,
  };
}

class _World {
  _World([HaloContainer c = HaloContainer.everyday]) : live = _Rows(c);
  final _Rows live;
  final io = _OnceIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make({bool decoy = false}) async {
    final w = _World(decoy ? HaloContainer.decoy : HaloContainer.everyday);
    w.live.person(_f, onion: 'o-$_f', xpub: 'x-$_f');
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.io.sessions = [_f, _s];
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  // one copy of the message [uid] on the wire: each send of it, the first
  // or a retry, is a cipher of its own. [written]: when it was written,
  // the same on every copy. [old]: from a version that does not say
  Future<({String peer, String cipher})> copy(
    String from,
    String uid, {
    int? written,
    bool old = false,
    String? group,
  }) async {
    final cipher = 'cipher-$uid-${_n++}';
    var wire = await wrapMessage(
      'text $uid',
      msgUid: uid,
      groupId: group,
      writtenAt: written,
      sender: SenderInfo(
        haloId: from,
        edPub: 'ed-$from',
        onion: 'o-$from',
        xPub: 'x-$from',
      ),
    );
    if (old) {
      final j = jsonDecode(wire.substring('halo/1:'.length)) as Map;
      j.remove('w');
      wire = 'halo/1:${jsonEncode(j)}';
    }
    io.opens[cipher] = (from, wire);
    return (peer: 'x-$from', cipher: cipher);
  }

  // any frame of theirs on the wire, a cipher of its own
  ({String peer, String cipher}) frame(String from, String wire) {
    final cipher = 'cipher-frame-${_n++}';
    io.opens[cipher] = (from, wire);
    return (peer: 'x-$from', cipher: cipher);
  }

  static SenderInfo sender(String from) => SenderInfo(
    haloId: from,
    edPub: 'ed-$from',
    onion: 'o-$from',
    xPub: 'x-$from',
  );

  // anything that went out to them, on any lane
  List<(String, String)> sentTo(String who) => [
    for (final s in io.sent)
      if (s.$1.endsWith('-$who')) s,
  ];

  List<Object?> kept(String from) => [
    for (final m in live.msgs)
      if (m['peer_id'] == from && m['direction'] == 'in') m['msg_uid'],
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('block_drop');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => docs.deleteSync(recursive: true));

  for (final who in [_f, _s]) {
    final kind = who == _f ? 'a friend' : 'a stranger';
    test('$kind blocked: what they send then stays out after the unblock, '
        'whichever lane brings it again', () async {
      final w = await _World.make();
      await w.app.block(who);
      await w.app.receiveRelay([await w.copy(who, 'req3b')]);
      await w.app.receiveOnion([(await w.copy(who, 'req3c')).cipher]);
      expect(w.kept(who), isEmpty);
      expect(w.io.rang, isEmpty);
      expect(w.io.ticksFor('req3b'), isEmpty, reason: 'no tick while blocked');

      await w.app.unblock(who);
      // their phone sends each again, as a retry does: a new cipher, the
      // same message
      await w.app.receiveRelay([await w.copy(who, 'req3b')]);
      await w.app.receiveOnion([(await w.copy(who, 'req3c')).cipher]);
      await w.app.receiveRelay([await w.copy(who, 'req3c')]);
      expect(w.kept(who), isEmpty);
      expect(w.io.rang, isEmpty);

      // and what they write now comes in
      await w.app.receiveRelay([await w.copy(who, 'req4')]);
      expect(w.kept(who), ['req4']);
    });

    // the block held two hours and ended a minute ago
    Future<(_World, int, int)> blockedAWhile() async {
      final w = await _World.make();
      await w.app.block(who);
      await w.app.unblock(who);
      final now = DateTime.now().millisecondsSinceEpoch;
      final to = now - 60000;
      w.live.blockSpans[who] = [(to - 2 * 3600000, to)];
      return (w, to - 2 * 3600000, to);
    }

    test('$kind blocked: what the relays held back while the block held '
        'stays out after the unblock, and a clock a few minutes slow loses '
        'nothing sent after it', () async {
      final (w, from, to) = await blockedAWhile();
      // listening again, the relay hands over what it kept for them: none
      // of it was ever seen here. a stranger's two are kept, so three
      await w.app.receiveRelay(
        [
          await w.copy(who, 'req3b'),
          await w.copy(who, 'late'),
          await w.copy(who, 'req4'),
        ],
        written: [from + 3600000, to - 5 * 60000, to + 60000],
      );
      expect(w.kept(who), unorderedEquals(['late', 'req4']));
    });

    // a block of under three minutes that ended forty seconds ago
    Future<(_World, int, int, int)> blockedMinutes() async {
      final w = await _World.make();
      await w.app.block(who);
      await w.app.unblock(who);
      final now = DateTime.now().millisecondsSinceEpoch;
      final to = now - 40000;
      final from = to - 170000;
      w.live.blockSpans[who] = [(from, to)];
      return (w, from, to, now);
    }

    test('$kind blocked: what they wrote while the block held stays out '
        'when their phone sends it again after the unblock, each copy '
        'wrapped anew', () async {
      final (w, from, _, now) = await blockedMinutes();
      final x = from + 30000;
      // a retry the relay held from while the block held, and one wrapped
      // after the unblock: both say when X was written
      await w.app.receiveRelay(
        [
          await w.copy(who, 'req3b', written: x),
          await w.copy(who, 'req3b', written: x),
        ],
        written: [from + 120000, now - 1000],
      );
      expect(w.kept(who), isEmpty);
      expect(w.io.rang, isEmpty);
      expect(w.io.ticksFor('req3b'), isEmpty);
      // what they write now comes in
      await w.app.receiveRelay(
        [await w.copy(who, 'req4b', written: now - 2000)],
        written: [now - 2000],
      );
      expect(w.kept(who), ['req4b']);
    });

    test('$kind blocked: a retry wrapped after a long block ended stays out '
        'by when it was written', () async {
      final (w, from, _) = await blockedAWhile();
      final now = DateTime.now().millisecondsSinceEpoch;
      await w.app.receiveRelay(
        [await w.copy(who, 'held', written: from + 3600000)],
        written: [now],
      );
      expect(w.kept(who), isEmpty);
      // their clock five minutes slow, written after the unblock and sent
      // at once: its own wrap time says how slow, and it comes in
      await w.app.receiveRelay(
        [await w.copy(who, 'slow', written: now - 5 * 60000)],
        written: [now - 5 * 60000],
      );
      // written before the block on a phone that was offline, sent while
      // it held: written outside it, so it comes in
      await w.app.receiveRelay(
        [await w.copy(who, 'offline', written: from - 600000)],
        written: [from + 3600000],
      );
      expect(w.kept(who), ['slow', 'offline']);
    });

    test('$kind blocked: from a version that does not say when it was '
        'written, the wrap time is judged as before', () async {
      final (w, from, to) = await blockedAWhile();
      await w.app.receiveRelay(
        [
          await w.copy(who, 'old-during', old: true),
          await w.copy(who, 'old-after', old: true),
        ],
        written: [from + 3600000, to + 30000],
      );
      expect(w.kept(who), ['old-after']);
    });

    test('$kind blocked: a written time past the wrap is not believed, and '
        'one far ahead of this clock is taken as now', () async {
      final (w, from, _) = await blockedAWhile();
      final now = DateTime.now().millisecondsSinceEpoch;
      await w.app.receiveRelay(
        [await w.copy(who, 'ahead', written: now + 86400000)],
        written: [from + 3600000],
      );
      expect(w.kept(who), isEmpty);
      // with no wrap time from the lane, a stamp a day ahead is now
      await w.app.receiveOnion([
        (await w.copy(who, 'ahead2', written: now + 86400000)).cipher,
      ]);
      expect(w.kept(who), ['ahead2']);
    });

    test('$kind blocked: what an ended block alone turns away is not noted, '
        'so a copy that comes again without a stamp is let in', () async {
      final (w, from, _) = await blockedAWhile();
      await w.app.receiveRelay(
        [await w.copy(who, 'skewed')],
        written: [from + 3600000],
      );
      expect(w.kept(who), isEmpty);
      expect(w.live.blockedDrops[who] ?? const {}, isEmpty);
      // their clock may be what put it there: sent again, it comes in
      await w.app.receiveOnion([(await w.copy(who, 'skewed')).cipher]);
      expect(w.kept(who), ['skewed']);
    });
  }

  for (final who in [_f, _s]) {
    final kind = who == _f ? 'a friend' : 'a stranger';

    test('$kind blocked: their address is still listened on, and what comes '
        'while the block holds is dropped by this clock and noted', () async {
      final w = await _World.make();
      await w.app.block(who);
      expect(w.io.unheard, isEmpty, reason: 'a block listens on');
      w.io.listened.clear();
      await w.app.subscribePeer(who);
      expect(w.io.listened, ['x-$who']);

      final before = w.live.calls.length;
      // a text, a file in slices and a receipt of theirs, each stamped as
      // written long after any span would end: this clock decides
      final later = DateTime.now().millisecondsSinceEpoch + 3600000;
      await w.app.receiveRelay([
        await w.copy(who, 'during', written: later),
        w.frame(
          who,
          await wrapMessage(
            '',
            mediaId: 'clip',
            chunkIndex: 0,
            chunkTotal: 2,
            fileB64: base64Encode([1, 2, 3]),
            fileName: 'a.bin',
            sender: _World.sender(who),
          ),
        ),
        w.frame(
          who,
          await wrapMessage(
            '',
            deliveredUid: 'mine-1',
            sender: _World.sender(who),
          ),
        ),
      ]);
      expect(w.kept(who), isEmpty);
      expect(w.live.blockedDrops[who], {'during', 'clip'});
      expect(w.live.delivered, isEmpty, reason: 'no tick from them');
      final asked = w.live.calls.sublist(before);
      for (final c in [
        'markDelivered',
        'markBackPaired',
        'saveMessage',
        'putMediaChunk',
        'bumpUnread',
        'holdCipher',
      ]) {
        expect(asked.where((a) => a.startsWith(c)), isEmpty, reason: c);
      }
      expect(w.io.rang, isEmpty);
      expect(w.sentTo(who), isEmpty, reason: 'nothing goes back');
    });

    // a copy wrapped three minutes before the unblock passes the stamp as
    // a slow clock. its noted uid keeps it out
    test('$kind blocked: a copy of what came while the block held, wrapped '
        'three minutes before the unblock, stays out after it', () async {
      final w = await _World.make();
      await w.app.block(who);
      final now = DateTime.now().millisecondsSinceEpoch;
      final to = now - 1000;
      final x = to - 3 * 60000;
      await w.app.receiveRelay(
        [await w.copy(who, 'x3', written: x)],
        written: [x],
      );
      expect(w.live.blockedDrops[who], {'x3'});
      await w.app.unblock(who);
      w.live.blockSpans[who] = [(x - 60000, to)];
      // the sender's retry and a restore's resend, each a cipher of its own
      await w.app.receiveRelay(
        [await w.copy(who, 'x3', written: x)],
        written: [x],
      );
      await w.app.receiveOnion([(await w.copy(who, 'x3', written: x)).cipher]);
      expect(w.kept(who), isEmpty);
      expect(w.io.rang, isEmpty);
      expect(w.io.ticksFor('x3'), isEmpty);
      expect(w.sentTo(who), isEmpty);

      // written after the unblock: in, rung and ticked
      await w.app.receiveRelay(
        [await w.copy(who, 'after', written: now)],
        written: [now],
      );
      await pumpEventQueue();
      expect(w.kept(who), ['after']);
      expect(w.io.rang, [who]);
      expect(w.io.ticksFor('after'), isNotEmpty);
    });
  }

  test('a reaction, edit, unsend, pin, vote, group control or introduction '
      'from someone blocked changes nothing', () async {
    final w = await _World.make();
    const g = 'grp-of-blocked';
    w.live.group(g, ['me', _f], admin: _f);
    await w.app.receiveRelay([await w.copy(_f, 't1')]);
    expect(w.kept(_f), ['t1']);
    await w.app.block(_f);
    final before = w.live.calls.length;
    final from = _World.sender(_f);
    final frames = [
      await wrapMessage(
        '',
        reaction: const ReactionFrame(targetUid: 't1', emoji: 'x'),
        sender: from,
      ),
      await wrapMessage(
        '',
        edit: const EditFrame(targetUid: 't1', newText: 'changed'),
        sender: from,
      ),
      await wrapMessage('', unsend: 't1', sender: from),
      await wrapMessage(
        '',
        pin: const PinFrame(targetUid: 't1', pinned: true),
        sender: from,
      ),
      await wrapMessage(
        '',
        vote: const VoteFrame(pollUid: 't1', choices: [0], seq: 1),
        sender: from,
      ),
      await wrapMessage(
        '',
        groupId: g,
        groupControl: const GroupControl(type: 'rename', name: 'taken'),
        sender: from,
      ),
      await wrapMessage(
        '',
        intro: const IntroFrame(
          haloId: 'someone-new-here',
          onion: 'o-new',
          xPub: 'x-new',
        ),
        sender: from,
      ),
    ];
    await w.app.receiveRelay([for (final f in frames) w.frame(_f, f)]);
    final asked = w.live.calls.sublist(before);
    for (final c in [
      'addReaction',
      'removeReaction',
      'editMessage',
      'deleteMessage',
      'setPinned',
      'putPollVote',
      'renameGroup',
      'createGroup',
      'addGroupMember',
      'syncGroupMembers',
      'upsertContactStub',
      'addVouch',
    ]) {
      expect(asked.where((a) => a.startsWith(c)), isEmpty, reason: c);
    }
    expect(w.kept(_f), ['t1']);
    expect(w.live.groupRows[g]!['name'], g);
    expect(w.live.blockedDrops[_f] ?? const {}, isEmpty);
    expect(w.sentTo(_f), isEmpty);

    // the same reaction once unblocked is theirs to make
    await w.app.unblock(_f);
    await w.app.receiveRelay([w.frame(_f, frames.first)]);
    expect(w.live.calls.where((a) => a.startsWith('addReaction')), isNotEmpty);
  });

  test('a block takes their notifications out of the shade', () async {
    final w = await _World.make();
    await w.app.receiveRelay([await w.copy(_s, 'req1')]);
    expect(w.io.rang, [_s]);
    await w.app.block(_s);
    expect(w.io.unrang, [_s]);
  });

  test('a block in the decoy takes nothing out of the shade: it showed '
      'nothing, and the same words may be someone the everyday app '
      'shows', () async {
    final w = await _World.make(decoy: true);
    await w.app.block(_s);
    expect(w.live.people[_s]!['blocked'], 1);
    expect(w.io.unrang, isEmpty);
  });

  test('a group message from someone blocked a while is judged the same way: '
      'written while the block held, it stays out when the owed send brings '
      'it again; written after, it comes in', () async {
    final w = await _World.make();
    const g = 'grp-block-span';
    w.live.group(g, ['me', _f], admin: _f);
    await w.app.block(_f);
    await w.app.unblock(_f);
    final now = DateTime.now().millisecondsSinceEpoch;
    final to = now - 60000;
    final from = to - 2 * 3600000;
    w.live.blockSpans[_f] = [(from, to)];
    await w.app.receiveRelay(
      [
        await w.copy(_f, 'g-during', written: from + 3600000, group: g),
        await w.copy(_f, 'g-after', written: to + 30000, group: g),
      ],
      written: [now - 1000, now - 1000],
    );
    final inGroup = [
      for (final m in w.live.msgs)
        if (m['group_id'] == g) m['msg_uid'],
    ];
    expect(inGroup, ['g-after']);
  });

  test(
    'a friend\'s message after a block and an unblock is theirs again',
    () async {
      final w = await _World.make();
      await w.app.receiveRelay([await w.copy(_f, 'u1')]);
      await w.app.block(_f);
      await w.app.unblock(_f);
      // a copy of one that came before the block is the one already here
      await w.app.receiveRelay([await w.copy(_f, 'u1')]);
      await w.app.receiveRelay([await w.copy(_f, 'u2')]);
      expect(w.kept(_f), ['u1', 'u2']);
    },
  );
}
