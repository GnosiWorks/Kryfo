// SPDX-License-Identifier: GPL-3.0-or-later
// typing on the app's two sides. a contact's frame through the onion door
// shows in their chat and leaves nothing behind: no row, no seen hash, no
// receipt, no ring. the same frame on a relay, from anyone not an added
// contact, for a chat shut in the vault or while a decoy is on screen does
// nothing at all. a frame goes only to the contact's door, never to a
// relay, the outbox or a first-contact address, and a failed one holds
// the next. signal, the engine and the databases are stand-ins
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart' show BridgeChoice, BridgeSetup;
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStateBridges,
        AppStateDelivery,
        AppStateReceive,
        AppStateRoute,
        AppStateTyping,
        HaloEngine,
        claimChat,
        releaseChat,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/typing.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _f = 'plain-friend-here'; // a contact who added this phone back
const _na = 'new-friend-here'; // added, not added back yet
const _s = 'guitar-present-kid'; // a request
const _b = 'blocked-one-here'; // blocked
const _o = 'old-phone-here'; // a contact on a version without typing
const _h = 'hidden-friend-here'; // a chat the vault holds

class _Engine implements HaloEngine {
  @override
  String myXPubkey() => 'x-me';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Vault extends ArrivalRows {
  _Vault() : super(HaloContainer.vault);
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: {_h: true}, groups: <String>{});
}

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final decoy = ArrivalRows(HaloContainer.decoy);
  final vault = _Vault();
  final store = ArrivalStore();
  final io = ArrivalIo();
  late AppState app;
  var _next = 0;

  static Future<_World> make({bool hidden = false}) async {
    final w = _World();
    w.live.person(_f, onion: 'o-$_f', xpub: 'x-$_f');
    w.live.people[_f]!['caps'] = kCapTyping;
    w.live.person(_na, onion: 'o-$_na', xpub: 'x-$_na', backPaired: 0);
    w.live.people[_na]!['caps'] = kCapTyping;
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.live.person(_b, onion: 'o-$_b', xpub: 'x-$_b');
    w.live.people[_b]!['caps'] = kCapTyping;
    w.live.people[_b]!['blocked'] = 1;
    w.live.person(_o, onion: 'o-$_o', xpub: 'x-$_o');
    w.decoy.person(_f, onion: 'o-$_f', xpub: 'x-$_f');
    w.vault.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    w.vault.people[_h]!['caps'] = kCapTyping;
    if (hidden) {
      await w.store.putHidden(
        _h,
        kHiddenPeer,
        peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
        1,
      );
      await w.store.putMeta('pub', 'pub-A');
    }
    final router = VaultRouter(w.store, ArrivalSeal());
    await router.load();
    useEngineForTest(_Engine());
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    w.app.sendModeForTest = 'private';
    w.app.setTorStatusForTest(TorStatus.reachable);
    w.app.setRouteOKForTest(true);
    w.app.inFrontForTest = true;
    w.everyday();
    return w;
  }

  void everyday() => useDatabasesForTest(live, Session(live));
  void inDecoy() => useDatabasesForTest(live, Session(decoy));
  Future<void> vaultOpen() async =>
      useDatabasesForTest(live, await Session.withVault(live, vault));

  String key(String who, [HaloContainer c = HaloContainer.everyday]) =>
      c.chatKey(who);

  bool showing(String who, [HaloContainer c = HaloContainer.everyday]) =>
      app.typing.board.showing(key(who, c));

  // a frame from [who] through the onion door, under their session
  Future<String> typingFrom(String who, {int? at, String? group}) async {
    final c = 't${_next++}';
    var w = wrapTyping(writtenAt: at ?? DateTime.now().millisecondsSinceEpoch);
    if (group != null) {
      w = w.replaceFirst('{', '{"g":"$group",');
    }
    io.opens[c] = (who, w.replaceFirst('}', ',"cp":["ty"]}'));
    await app.receiveOnion([c]);
    return c;
  }

  Future<void> textFrom(String who, String uid, {int? at}) async {
    final c = 'c${_next++}';
    io.opens[c] = (
      who,
      await wrapMessage(
        'hi',
        msgUid: uid,
        writtenAt: at,
        sender: asSender(who),
      ),
    );
    await app.receiveOnion([c]);
  }

  // what the receive side wrote for a frame: rows, seen marks, rings
  List<String> get leftBehind => [
    ...live.rowWrites,
    ...decoy.rowWrites,
    ...vault.rowWrites,
    for (final c in live.calls)
      if (c.startsWith('markSeen')) c,
    ...io.rang,
    for (final (to, _) in io.sent) to,
  ];

  List<String> get typingSends => [
    for (final (to, _) in io.sent)
      if (to.startsWith('typing ')) to,
  ];

  Future<void> type(String who) =>
      app.typingEdit(who, userEdit: true, nonEmpty: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    lockState.openForTest();
  });

  tearDown(() {
    for (final p in [_f, _na, _s, _b, _o, _h]) {
      releaseChat(p);
    }
  });

  group('coming in', () {
    test('a contact\'s frame shows and leaves nothing behind', () async {
      final w = await _World.make();
      await w.typingFrom(_f);
      expect(w.showing(_f), isTrue);
      expect(w.leftBehind, isEmpty);
      expect(w.live.msgs, isEmpty);
      expect(w.live.seen, isEmpty);
      expect(w.live.calls, isNot(contains('markBackPaired:$_f')));
    });

    test('their message ends it, and a frame older than it never '
        'shows', () async {
      final w = await _World.make();
      await w.typingFrom(_f, at: 1000);
      await w.textFrom(_f, 'm1', at: 2000);
      expect(w.showing(_f), isFalse);
      await w.typingFrom(_f, at: 1500);
      expect(w.showing(_f), isFalse);
      await w.typingFrom(_f, at: 2500);
      expect(w.showing(_f), isTrue);
    });

    test('on a relay it is dropped, and nothing is filed', () async {
      final w = await _World.make();
      w.io.opens['r1'] = (_f, wrapTyping(writtenAt: 5));
      await w.app.receiveRelay([(peer: 'x-$_f', cipher: 'r1')]);
      expect(w.showing(_f), isFalse);
      expect(w.live.msgs, isEmpty);
      expect(w.live.rowWrites, isEmpty);
      expect(w.io.rang, isEmpty);
    });

    test('from a request, a blocked contact or one not added back, '
        'nothing', () async {
      final w = await _World.make();
      for (final who in [_s, _b, _na]) {
        await w.typingFrom(who);
        expect(w.showing(who), isFalse, reason: who);
      }
      expect(w.leftBehind, isEmpty);
      expect(w.live.people[_s]!['accepted'], 0);
    });

    test('from someone with no session here, nothing and no request', () async {
      final w = await _World.make();
      w.io.sessions = ['gone-friend-here'];
      w.io.opens['p1'] = ('gone-friend-here', wrapTyping(writtenAt: 5));
      await w.app.receiveOnion(['p1']);
      expect(w.live.people, isNot(contains('gone-friend-here')));
      expect(w.leftBehind, isEmpty);
    });

    test('a frame that names a group is dropped', () async {
      final w = await _World.make();
      await w.typingFrom(_f, group: 'grp000000001');
      expect(w.showing(_f), isFalse);
      expect(w.live.msgs, isEmpty);
    });

    test('with my switch off or my route off the onion, nothing', () async {
      final w = await _World.make();
      w.app.typing.on = false;
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
      w.app.typing.on = true;
      w.app.sendModeForTest = 'balanced';
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
    });

    test('behind the lock, in the back or in the decoy, nothing', () async {
      final w = await _World.make();
      lockState.openForTest(enabled: true);
      lockState.lock();
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
      lockState.openForTest();
      w.app.inFrontForTest = false;
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
      w.app.inFrontForTest = true;
      w.inDecoy();
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
      expect(w.showing(_f, HaloContainer.decoy), isFalse);
      expect(w.decoy.rowWrites, isEmpty);
    });

    test('a hidden chat while its vault is shut: no seal, no count, '
        'nothing shown', () async {
      final w = await _World.make(hidden: true);
      await w.typingFrom(_h);
      expect(w.store.inbox, isEmpty);
      expect(w.showing(_h), isFalse);
      expect(w.showing(_h, HaloContainer.vault), isFalse);
      expect(w.leftBehind, isEmpty);
    });

    test('a hidden chat while its vault is open shows under the vault\'s '
        'key', () async {
      final w = await _World.make(hidden: true);
      await w.vaultOpen();
      await w.typingFrom(_h);
      expect(w.showing(_h, HaloContainer.vault), isTrue);
      expect(w.showing(_h), isFalse);
      expect(w.app.typingKey(_h), HaloContainer.vault.chatKey(_h));
    });

    test('a lock, the back or a switch of session clears it all', () async {
      final w = await _World.make();
      await w.app.loadTypingPref();
      await w.typingFrom(_f);
      lockState.openForTest(enabled: true);
      lockState.lock();
      expect(w.showing(_f), isFalse);
      lockState.openForTest();
      await w.typingFrom(_f);
      w.app.appInFront(false);
      expect(w.showing(_f), isFalse);
      w.app.inFrontForTest = true;
      await w.typingFrom(_f);
      await w.app.setTypingOn(false);
      expect(w.showing(_f), isFalse);
    });
  });

  group('a lock or a decoy that comes while a frame is read', () {
    test('a lock during the reads leaves nothing showing behind it', () async {
      final w = await _World.make();
      await w.app.loadTypingPref();
      w.live.onTakeCaps = () {
        lockState.openForTest(enabled: true);
        lockState.lock();
      };
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
      lockState.openForTest();
      w.live.onTakeCaps = null;
    });

    test('a decoy switch during the reads leaves nothing showing', () async {
      final w = await _World.make();
      w.live.onTakeCaps = w.inDecoy;
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
      w.live.onTakeCaps = null;
    });

    test(
      'a frame that opened a session is marked seen and never shows',
      () async {
        final w = await _World.make();
        final opener = base64Encode([3, 1, 2, 3, 4, 5]);
        w.io.opens[opener] = (_f, wrapTyping(writtenAt: 5));
        await w.app.receiveOnion([opener]);
        expect(w.showing(_f), isFalse);
        expect(w.live.seen, hasLength(1));
        expect(w.live.msgs, isEmpty);
        expect(w.io.rang, isEmpty);
      },
    );
  });

  group('bridges and the archive', () {
    const viaBridge =
        '{"mode":"auto","phase":"connected","method":"obfs4","source":"builtin"}';
    const direct = '{"mode":"auto","phase":"connected","method":"direct"}';

    test('while a bridge carries tor nothing goes and nothing shows, and it '
        'comes back by itself after', () async {
      final w = await _World.make();
      claimChat(_f);
      await w.typingFrom(_f);
      expect(w.showing(_f), isTrue);
      w.app.takeBridgeStatus(viaBridge);
      expect(w.app.typingBridged, isTrue);
      // what showed goes at once
      expect(w.showing(_f), isFalse);
      await w.typingFrom(_f);
      expect(w.showing(_f), isFalse);
      await w.type(_f);
      expect(w.io.sent, isEmpty);
      w.app.takeBridgeStatus(direct);
      expect(w.app.typingBridged, isFalse);
      w.app.typing.pacer.reset();
      await w.type(_f);
      expect(w.typingSends, ['typing o-$_f']);
      await w.typingFrom(_f);
      expect(w.showing(_f), isTrue);
    });

    test(
      'automatic trying a bridge while tor already carries holds it off',
      () async {
        final w = await _World.make();
        claimChat(_f);
        w.app.takeBridgeStatus(
          '{"mode":"auto","phase":"trying","method":"obfs4",'
          '"source":"builtin","can_send":true}',
        );
        expect(w.app.torUsable, isTrue);
        expect(w.app.typingBridged, isTrue);
        await w.type(_f);
        await w.typingFrom(_f);
        expect(w.io.sent, isEmpty);
        expect(w.showing(_f), isFalse);
      },
    );

    test('between two steps, while old bridge lines still carry tor, it '
        'stays off', () async {
      final w = await _World.make();
      claimChat(_f);
      w.app.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","method":"","can_send":true,'
        '"on_bridge":true}',
      );
      expect(w.app.typingBridged, isTrue);
      await w.type(_f);
      expect(w.io.sent, isEmpty);
      w.app.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","method":"","can_send":true}',
      );
      expect(w.app.typingBridged, isFalse);
    });

    test('a bridge picked by hand holds it off before it connects', () async {
      final w = await _World.make();
      claimChat(_f);
      w.app.bridgeSetupForTest = const BridgeSetup(
        choice: BridgeChoice.snowflake,
      );
      expect(w.app.typingBridged, isTrue);
      await w.type(_f);
      await w.typingFrom(_f);
      expect(w.io.sent, isEmpty);
      expect(w.showing(_f), isFalse);
    });

    test('an archived chat neither sends nor shows', () async {
      final w = await _World.make();
      w.live.people[_f]!['archived'] = 1;
      claimChat(_f);
      await w.type(_f);
      await w.typingFrom(_f);
      expect(w.io.sent, isEmpty);
      expect(w.showing(_f), isFalse);
    });
  });

  group('what their phone understands', () {
    test('a frame with the list sets it once, the same list again writes '
        'nothing, a message without one clears it', () async {
      final w = await _World.make();
      final body = (await wrapMessage(
        'hi',
        msgUid: 'u1',
        writtenAt: 10,
      )).replaceFirst('{', '{"cp":["ty"],');
      w.io.opens['a'] = (_o, body);
      await w.app.receiveOnion(['a']);
      expect(w.live.people[_o]!['caps'], 'ty');
      expect(w.live.capsWrites, 1);
      final again = (await wrapMessage(
        'hi',
        msgUid: 'u2',
        writtenAt: 20,
      )).replaceFirst('{', '{"cp":["ty"],');
      w.io.opens['b'] = (_o, again);
      await w.app.receiveOnion(['b']);
      expect(w.live.capsWrites, 1);
      w.io.opens['c'] = (
        _o,
        await wrapMessage('hi', msgUid: 'u3', writtenAt: 30),
      );
      await w.app.receiveOnion(['c']);
      expect(w.live.people[_o]!['caps'], '');
    });
  });

  group('going out', () {
    test('a keystroke in a contact\'s chat goes to their door alone', () async {
      final w = await _World.make();
      claimChat(_f);
      await w.type(_f);
      expect(w.typingSends, ['typing o-$_f']);
      expect(w.io.sent, hasLength(1));
      expect(w.io.typingSeals.single, startsWith('$_f halo/1:{"ty":1,"w":'));
      expect(w.live.rowWrites, isEmpty);
      expect(w.live.calls.where((c) => c.contains('outbox')), isEmpty);
    });

    test('nothing goes off the onion route, to an old phone, a request, '
        'someone blocked or not added back, or a chat not on screen', () async {
      final w = await _World.make();
      for (final who in [_o, _s, _b, _na]) {
        claimChat(who);
        await w.type(who);
      }
      releaseChat(_na);
      claimChat(_f);
      w.app.sendModeForTest = 'balanced';
      await w.type(_f);
      w.app.sendModeForTest = 'fast';
      await w.type(_f);
      releaseChat(_f);
      w.app.sendModeForTest = 'private';
      await w.type(_f);
      expect(w.io.sent, isEmpty);
      expect(w.io.typingSeals, isEmpty);
    });

    test('nothing goes from the decoy, behind the lock, or with the switch '
        'off', () async {
      final w = await _World.make();
      claimChat(_f);
      w.inDecoy();
      await w.type(_f);
      w.everyday();
      w.app.typing.on = false;
      await w.type(_f);
      w.app.typing.on = true;
      lockState.openForTest(enabled: true);
      lockState.lock();
      await w.type(_f);
      expect(w.io.sent, isEmpty);
    });

    test('words the app put there, or an empty field, send nothing', () async {
      final w = await _World.make();
      claimChat(_f);
      await w.app.typingEdit(_f, userEdit: false, nonEmpty: true);
      await w.app.typingEdit(_f, userEdit: true, nonEmpty: false);
      expect(w.io.sent, isEmpty);
    });

    test('a key waiting on a check, a session not answered yet or one a '
        'restore brought back seals nothing', () async {
      final w = await _World.make();
      claimChat(_f);
      for (final why in ['held', 'opener', 'afresh']) {
        w.io.typingRefuse = why;
        await w.type(_f);
        expect(w.io.sent, isEmpty, reason: why);
        w.app.typing.pacer.reset();
      }
    });

    test('a lock, a decoy or the back during the seal sends nothing', () async {
      final w = await _World.make();
      claimChat(_f);
      w.io.onTypingSeal = () {
        lockState.openForTest(enabled: true);
        lockState.lock();
      };
      await w.type(_f);
      lockState.openForTest();
      w.app.typing.pacer.reset();
      w.io.onTypingSeal = w.inDecoy;
      await w.type(_f);
      w.everyday();
      w.app.typing.pacer.reset();
      w.io.onTypingSeal = () => w.app.inFrontForTest = false;
      await w.type(_f);
      expect(w.io.sent, isEmpty);
      expect(w.io.typingSeals, hasLength(3));
      // nothing went, so nothing holds the peer
      expect(w.app.typing.pacer.heldFor(_f), isNull);
    });

    test('a failure holds the next tries to that peer', () async {
      final w = await _World.make();
      claimChat(_f);
      w.io.typingAnswer = 'error: not delivered';
      await w.type(_f);
      expect(w.typingSends, hasLength(1));
      expect(
        w.app.typing.pacer.heldFor(_f),
        greaterThan(const Duration(seconds: 59)),
      );
      expect(w.io.sent.where((s) => !s.$1.startsWith('typing ')), isEmpty);
    });

    test('a vault chat goes while the vault is open', () async {
      final w = await _World.make(hidden: true);
      await w.vaultOpen();
      claimChat(_h);
      await w.type(_h);
      expect(w.typingSends, ['typing o-$_h']);
    });
  });

  test('nothing about typing reaches a relay', () async {
    final w = await _World.make();
    claimChat(_f);
    for (var i = 0; i < 5; i++) {
      w.app.typing.pacer.reset();
      await w.type(_f);
      await w.typingFrom(_f);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    w.io.typingAnswer = 'error: timeout';
    w.app.typing.pacer.reset();
    await w.type(_f);
    expect(
      w.io.sent.where(
        (s) => s.$1.startsWith('relay ') || s.$1.startsWith('fc '),
      ),
      isEmpty,
    );
  });
}
