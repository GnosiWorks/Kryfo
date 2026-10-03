// SPDX-License-Identifier: GPL-3.0-or-later
// the engine remembers a relay delivery as seen only once the app says it
// kept it. one that throws is named back and comes again, the rest of its
// batch stays kept, and nothing is kept twice. a stranger's message past
// the cap is kept as it opened and let in on accept, or by the sweep when
// an accept left some behind. what opened is kept only under the session it
// opened in. signal spends a key on every open, so the stand-in opens each
// cipher once
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart' show PinResult, lockState;
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        QuietIdentity,
        heldWire,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/relay_poll.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/wipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _v = 'plain-friend-here';
const _s = 'some-stranger-here';
const _hs = 'hidden-stranger-one';

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

// signal held at its open until the test lets it go
class _GateIo extends _OnceIo {
  Completer<void>? gate;
  final asked = Completer<void>();
  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    if (!asked.isCompleted) asked.complete();
    final g = gate;
    if (g != null) await g.future;
    return super.decrypt(peer, cipher, flagKeyChange: flagKeyChange);
  }
}

// a database that fails once on the hash it is told to, and on the next
// badges it is told to, which an arrival writes before its row
class _Flaky extends ArrivalRows {
  _Flaky([super.container = HaloContainer.everyday]);
  String? failOn;
  var badgeFails = 0;
  // and on the next unparks, which come once its uid is claimed
  var unparkFails = 0;
  @override
  Future<void> unparkIfArchived(String haloId) async {
    if (unparkFails > 0) {
      unparkFails--;
      throw StateError('the database went away');
    }
    return super.unparkIfArchived(haloId);
  }

  // people its rows hold whom the session does not hide
  final shown = <String>{};
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async {
    final h = await super.heldChats();
    return (
      people: {
        for (final e in h.people.entries)
          if (!shown.contains(e.key)) e.key: e.value,
      },
      groups: h.groups,
    );
  }

  @override
  Future<void> setContactBadge(String haloId, String? tier) async {
    if (badgeFails > 0) {
      badgeFails--;
      throw StateError('the database went away');
    }
    return super.setContactBadge(haloId, tier);
  }

  @override
  Future<bool> alreadySeen(String hash) async {
    if (failOn != null && failOn == hash) {
      failOn = null;
      throw StateError('the database went away');
    }
    return super.alreadySeen(hash);
  }
}

class _World {
  _World([_OnceIo? io]) : io = io ?? _OnceIo();
  final live = _Flaky();
  final vault = _Flaky(HaloContainer.vault);
  final store = ArrivalStore();
  final _OnceIo io;
  late AppState app;

  static Future<_World> make({bool hidden = false, _OnceIo? io}) async {
    final w = _World(io);
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.io.sessions = [_v, _s];
    if (hidden) {
      // a stranger of the hidden chats who has had their two
      w.vault.person(_hs, onion: 'o-$_hs', xpub: 'x-$_hs', accepted: 0);
      await w.vault.saveMessage(_hs, 'in', 'one', msgUid: 'h1');
      await w.vault.saveMessage(_hs, 'in', 'two', msgUid: 'h2');
      await w.store.putHidden(
        _hs,
        kHiddenPeer,
        peerCard(RouterCard(_hs, 'o-$_hs', 'x-$_hs', backPaired: true)),
        1,
      );
      await w.store.putMeta('pub', 'pub-A');
    }
    final router = VaultRouter(w.store, ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<({String peer, String cipher})> text(
    String from,
    String uid, {
    String? body,
  }) async {
    final cipher = 'cipher-$uid';
    io.opens[cipher] = (
      from,
      await wrapMessage(
        body ?? 'text $uid',
        msgUid: uid,
        sender: SenderInfo(
          haloId: from,
          edPub: 'ed-$from',
          onion: 'o-$from',
          xPub: 'x-$from',
        ),
      ),
    );
    return (peer: 'x-$from', cipher: cipher);
  }

  List<Object?> kept(String from, {ArrivalRows? db}) => [
    for (final m in (db ?? live).msgs)
      if (m['peer_id'] == from && m['direction'] == 'in') m['msg_uid'],
  ];
}

String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 200));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('relay_ack');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => docs.deleteSync(recursive: true));

  test(
    'one that throws is named back, the rest of the batch is kept',
    () async {
      final w = await _World.make();
      final batch = [
        await w.text(_v, 'u1'),
        await w.text(_v, 'u2'),
        await w.text(_v, 'u3'),
      ];
      w.live.failOn = sha256Hex(batch[1].cipher);
      final failed = await w.app.receiveRelay(batch);
      expect(failed, {1});
      expect(w.kept(_v), ['u1', 'u3']);
      // the engine offers it again
      expect(await w.app.receiveRelay([batch[1]]), isEmpty);
      expect(w.kept(_v), ['u1', 'u3', 'u2']);
    },
  );

  test('one that throws after it was kept is not kept twice', () async {
    final w = await _World.make();
    final batch = [await w.text(_v, 'u1'), await w.text(_v, 'u2')];
    var once = true;
    w.live.onSave = () {
      if (once) {
        once = false;
        throw StateError('the disk is full');
      }
    };
    final failed = await w.app.receiveRelay(batch);
    expect(failed, {0});
    expect(w.kept(_v), ['u1', 'u2']);
    expect(await w.app.receiveRelay([batch[0]]), isEmpty);
    expect(w.kept(_v), ['u1', 'u2']);
  });

  test('a stranger past the cap is kept and lands after accept', () async {
    final w = await _World.make();
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    await w.live.saveMessage(_s, 'in', 'one', msgUid: 's1');
    await w.live.saveMessage(_s, 'in', 'two', msgUid: 's2');
    final third = await w.text(_s, 's3', body: 'three');
    // held, and so kept: the engine may forget it
    expect(await w.app.receiveRelay([third]), isEmpty);
    expect(w.kept(_s), ['s1', 's2']);
    expect(w.live.heldCiphers[_s], hasLength(1));
    w.live.people[_s]!['accepted'] = 1;
    await w.app.afterAccept(_s);
    await _settle();
    expect(w.kept(_s), ['s1', 's2', 's3']);
    expect(w.live.heldCiphers[_s], isNull);
  });

  test('one that fails after it opened goes in when it comes again', () async {
    final w = await _World.make();
    final m = await w.text(_v, 'u1');
    w.live.badgeFails = 1;
    expect(await w.app.receiveRelay([m]), {0});
    expect(w.kept(_v), isEmpty);
    // signal does not open it a second time
    expect(await w.app.receiveRelay([m]), isEmpty);
    expect(w.kept(_v), ['u1']);
  });

  test('one that fails as it is written goes in when it comes again', () async {
    final w = await _World.make();
    final m = await w.text(_v, 'u1');
    w.live.unparkFails = 1;
    expect(await w.app.receiveRelay([m]), {0});
    expect(w.kept(_v), isEmpty);
    expect(await w.app.receiveRelay([m]), isEmpty);
    expect(w.kept(_v), ['u1']);
  });

  test('a held one that fails to go in on accept stays held', () async {
    final w = await _World.make();
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    await w.live.saveMessage(_s, 'in', 'one', msgUid: 's1');
    await w.live.saveMessage(_s, 'in', 'two', msgUid: 's2');
    final held = [
      await w.text(_s, 's3', body: 'three'),
      await w.text(_s, 's4', body: 'four'),
    ];
    expect(await w.app.receiveRelay(held), isEmpty);
    expect(w.live.heldCiphers[_s], hasLength(2));
    w.live.people[_s]!['accepted'] = 1;
    w.live.badgeFails = 1;
    await w.app.afterAccept(_s);
    await _settle();
    expect(w.kept(_s), ['s1', 's2', 's4']);
    expect(w.live.heldCiphers[_s], hasLength(1));
    await w.app.afterAccept(_s);
    await _settle();
    expect(w.kept(_s), ['s1', 's2', 's4', 's3']);
    expect(w.live.heldCiphers[_s], isNull);
  });

  test('a sealed one past the cap is held in its vault', () async {
    final w = await _World.make(hidden: true);
    final c = 'cipher-h3';
    w.io.opens[c] = (
      _hs,
      await wrapMessage(
        'three',
        msgUid: 'h3',
        sender: SenderInfo(
          haloId: _hs,
          edPub: 'ed-$_hs',
          onion: 'o-$_hs',
          xPub: 'x-$_hs',
        ),
      ),
    );
    await w.app.receiveOnion([c]);
    await _settle();
    expect(w.store.inbox, hasLength(1));
    useDatabasesForTest(w.live, await Session.withVault(w.live, w.vault));
    await w.app.drainSealed(w.vault, 'priv-A');
    expect(w.store.inbox, isEmpty);
    expect(w.kept(_hs, db: w.vault), ['h1', 'h2']);
    expect(w.vault.heldCiphers[_hs], hasLength(1));
    w.vault.people[_hs]!['accepted'] = 1;
    await w.app.afterAccept(_hs);
    await _settle();
    expect(w.kept(_hs, db: w.vault), ['h1', 'h2', 'h3']);
  });

  test('every hold goes to the container the cap named', () {
    final app = File('lib/main.dart').readAsStringSync();
    final holds = RegExp(r'\.holdCipher\(').allMatches(app).toList();
    expect(holds, hasLength(greaterThanOrEqualTo(5)));
    for (final h in holds) {
      final before = app.substring(h.start - 200, h.start);
      expect(
        before,
        contains('e is _HeldIn ? e.into'),
        reason: app.substring(h.start - 120, h.start + 40),
      );
    }
  });

  test('the poll names the places in its batch, past entries it skipped', () {
    final b = parseRelayPoll(
      '{"k":"7","m":[{"t":"a","c":"1"},{"t":2,"c":"x"},{"t":"b","c":"2"}]}',
    );
    expect(b.token, '7');
    expect(b.msgs, [(peer: 'a', cipher: '1'), (peer: 'b', cipher: '2')]);
    expect(failedPlaces(b, {1}), [2]);
    expect(failedPlaces(b, {0, 5}), [0]);
  });

  test('the poll timer confirms after the batch, with what failed', () {
    final app = File('lib/main.dart').readAsStringSync();
    final at = app.indexOf('final batch = engine.nostrPoll();');
    expect(at, greaterThan(0));
    final loop = app.substring(at, app.indexOf('} finally {', at));
    expect(
      loop.indexOf('await receiveRelay(batch.msgs)'),
      lessThan(loop.indexOf('engine.nostrAck(batch.token, failedPlaces(')),
    );
  });

  group('what was opened goes with the session it was opened under', () {
    // a message that opened and failed to go in, as the retry finds it
    Future<({String peer, String cipher})> failedOnce(_World w) async {
      final m = await w.text(_v, 'u1');
      w.live.badgeFails = 1;
      expect(await w.app.receiveRelay([m]), {0});
      expect(w.kept(_v), isEmpty);
      return m;
    }

    test('a switch to the decoy drops it', () async {
      final w = await _World.make();
      final m = await failedOnce(w);
      await w.app.useDecoyForTest(
        ArrivalRows(HaloContainer.decoy),
        const QuietIdentity(
          id: 'quiet',
          edPub: 'ed-quiet',
          xPub: 'x-quiet',
          onion: '',
          invite: '',
        ),
      );
      w.app.revealGap = Duration.zero;
      addTearDown(() => lockState.inDecoy = false);
      await w.app.sessionFor(PinResult.decoy);
      await _settle();
      expect(await w.app.receiveRelay([m]), isEmpty);
      expect(w.kept(_v), isEmpty);
    });

    test('the vault shutting drops it', () async {
      final w = await _World.make(hidden: true);
      useDatabasesForTest(w.live, await Session.withVault(w.live, w.vault));
      final m = await failedOnce(w);
      w.app.lockingUp();
      await _settle();
      expect(await w.app.receiveRelay([m]), isEmpty);
      expect(w.kept(_v), isEmpty);
      expect(w.kept(_v, db: w.vault), isEmpty);
    });

    test('a wipe drops it as it starts', () async {
      final w = await _World.make();
      final m = await failedOnce(w);
      final exit = wipeExit;
      wipeExit = (_) {};
      addTearDown(() {
        wipeExit = exit;
        haloWiping = false;
      });
      await wipeHalo();
      haloWiping = false;
      expect(await w.app.receiveRelay([m]), isEmpty);
      expect(w.kept(_v), isEmpty);
    });

    test('an open begun before the drop is not kept after it', () async {
      final io = _GateIo()..gate = Completer<void>();
      final w = await _World.make(io: io);
      final m = await w.text(_v, 'u1');
      w.live.badgeFails = 1;
      final first = w.app.receiveRelay([m]);
      await io.asked.future;
      wipeForget();
      io.gate!.complete();
      expect(await first, {0});
      expect(await w.app.receiveRelay([m]), isEmpty);
      expect(w.kept(_v), isEmpty);
    });
  });

  group('the shelf of someone accepted already', () {
    Future<void> shelve(_World w) async {
      w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
      await w.live.saveMessage(_s, 'in', 'one', msgUid: 's1');
      await w.live.saveMessage(_s, 'in', 'two', msgUid: 's2');
      expect(
        await w.app.receiveRelay([
          await w.text(_s, 's3', body: 'three'),
          await w.text(_s, 's4', body: 'four'),
        ]),
        isEmpty,
      );
      expect(w.live.heldCiphers[_s], hasLength(2));
    }

    test('goes in on the sweep, a stranger\'s stays', () async {
      final w = await _World.make();
      await shelve(w);
      // accepted, and the accept died before it let anything in
      w.live.people[_s]!['accepted'] = 1;
      // a stranger whose two went, so the cap would not hold them
      const x = 'another-stranger';
      w.live.person(x, onion: 'o-$x', xpub: 'x-$x', accepted: 0);
      await w.live.holdCipher(
        x,
        heldWire(await wrapMessage('hi', msgUid: 'x1', sender: asSender(x))),
      );
      await w.app.letHeldIn(w.live);
      expect(w.kept(_s), ['s1', 's2', 's3', 's4']);
      expect(w.live.heldCiphers[_s], isNull);
      expect(w.kept(x), isEmpty);
      expect(w.live.heldCiphers[x], hasLength(1));
      expect(w.live.calls, isNot(contains('heldOf:$x')));
    });

    test('one that fails on the sweep stays for the next', () async {
      final w = await _World.make();
      await shelve(w);
      w.live.people[_s]!['accepted'] = 1;
      w.live.badgeFails = 1;
      await w.app.letHeldIn(w.live);
      expect(w.kept(_s), ['s1', 's2', 's4']);
      expect(w.live.heldCiphers[_s], hasLength(1));
      await w.app.letHeldIn(w.live);
      expect(w.kept(_s), ['s1', 's2', 's4', 's3']);
      expect(w.live.heldCiphers[_s], isNull);
    });

    test('an accept and the sweep let each row in once', () async {
      final w = await _World.make();
      await shelve(w);
      w.live.people[_s]!['accepted'] = 1;
      await Future.wait([w.app.afterAccept(_s), w.app.letHeldIn(w.live)]);
      await _settle();
      expect(w.kept(_s), ['s1', 's2', 's3', 's4']);
      expect(w.live.calls.where((c) => c.startsWith('forgetHeld:')), [
        'forgetHeld:1',
        'forgetHeld:2',
      ]);
    });

    test('the vault\'s goes into the vault, only while it is open, and a '
        'decoy\'s never goes anywhere', () async {
      final w = await _World.make(hidden: true);
      await w.vault.holdCipher(
        _hs,
        heldWire(
          await wrapMessage('three', msgUid: 'h3', sender: asSender(_hs)),
        ),
      );
      w.vault.people[_hs]!['accepted'] = 1;
      final decoy = _Flaky(HaloContainer.decoy);
      decoy.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
      await decoy.holdCipher(
        _v,
        heldWire(await wrapMessage('d', msgUid: 'd1', sender: asSender(_v))),
      );
      // shut: its rows wait
      await w.app.letHeldIn(w.vault);
      expect(w.vault.calls, isNot(contains('heldOfAccepted')));
      expect(w.vault.heldCiphers[_hs], hasLength(1));
      // a decoy takes nothing in, whichever session is open
      await w.app.letHeldIn(decoy);
      useDatabasesForTest(w.live, Session(decoy));
      await w.app.letHeldIn(decoy);
      expect(decoy.calls, isNot(contains('heldOfAccepted')));
      expect(decoy.heldCiphers[_v], hasLength(1));
      expect(w.kept(_v), isEmpty);
      // open: into the vault, never the everyday side
      useDatabasesForTest(w.live, await Session.withVault(w.live, w.vault));
      await w.app.letHeldIn(w.vault);
      expect(w.kept(_hs, db: w.vault), ['h1', 'h2', 'h3']);
      expect(w.vault.heldCiphers[_hs], isNull);
      expect(w.kept(_hs), isEmpty);
    });

    test('a vault row for someone it does not hide stays in it', () async {
      final w = await _World.make(hidden: true);
      const y = 'kept-in-the-vault';
      w.vault.person(y, onion: 'o-$y', xpub: 'x-$y');
      w.vault.shown.add(y);
      await w.vault.holdCipher(
        y,
        heldWire(await wrapMessage('y', msgUid: 'y1', sender: asSender(y))),
      );
      useDatabasesForTest(w.live, await Session.withVault(w.live, w.vault));
      await w.app.letHeldIn(w.vault);
      expect(w.kept(y), isEmpty);
      expect(w.live.people[y], isNull);
      expect(w.vault.heldCiphers[y], hasLength(1));
    });

    test('the sweep runs once signal is up at a start, and as the vault '
        'opens', () {
      final app = File('lib/main.dart').readAsStringSync();
      final boot = app.indexOf('_signalBoot = _bootSignal().whenComplete(');
      expect(boot, greaterThan(0));
      expect(
        app.substring(boot, app.indexOf('});', boot)),
        contains('unawaited(letHeldIn(live));'),
      );
      final shown = app.indexOf('Future<void> _vaultShown(HaloDb v)');
      final body = app.substring(shown, app.indexOf('\n  }\n', shown));
      expect(
        body.indexOf('unawaited(letHeldIn(v));'),
        greaterThan(body.indexOf('await _unseal();')),
      );
    });
  });
}
