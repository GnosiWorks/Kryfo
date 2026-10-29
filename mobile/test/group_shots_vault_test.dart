// SPDX-License-Identifier: GPL-3.0-or-later
// a hidden group's screenshot block while its vault is shut: what comes
// waits sealed and nothing is answered, as a phone that is offline. on the
// next opening the state is taken there, its admin hears this app's bits,
// and a group this phone runs works out again who can. a decoy's group is
// on for everyone at once and nothing leaves the phone. the databases,
// signal and the engine are stand-ins
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/typing.dart' show kCapGroupShots;
import 'package:kryfo/container.dart';
import 'package:kryfo/group_shots.dart';
import 'package:kryfo/lock_state.dart' show PinResult, lockState;
import 'package:kryfo/main.dart'
    show
        AppState,
        QuietIdentity,
        useDatabasesForTest,
        AppStateGroupLanes,
        AppStateGroupShots,
        groupCapsGap,
        groupShotsEvery,
        AppStateScreen,
        AppStateVault,
        AppStateSession,
        AppStateReceive;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _a = 'admin-of-group';
const _h = 'hidden-wreck-tone'; // the hidden group's admin
const _g = 'grp000000001';
const _g2 = 'g2hidden0001'; // _h runs it
const _g3 = 'g3hidden0001'; // this phone runs it, with _h
const _g4 = 'g4hidden0001'; // _h runs it too

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final vault = ArrivalRows(HaloContainer.vault);
  final store = ArrivalStore();
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_a, onion: 'o-$_a', xpub: 'x-$_a');
    w.live.group(_g, ['me', _a], admin: _a);
    w.vault.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    w.vault.group(_g2, ['me', _h], admin: _h);
    w.vault.group(_g3, ['me', _h], admin: 'me');
    w.vault.groupRows[_g3]!['is_admin'] = 1;
    await w.store.putHidden(
      _h,
      kHiddenPeer,
      peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
      1,
    );
    await w.store.putHidden(_g2, kHiddenGroup, groupCard(const []), 1);
    await w.store.putHidden(_g3, kHiddenGroup, groupCard(const []), 1);
    await w.store.putMeta('pub', 'pub-A');
    final router = VaultRouter(w.store, ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<void> from(String who, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<String> shots(String who, String g, GroupShotsWord w) => wrapMessage(
    '',
    groupId: g,
    groupControl: GroupControl(type: 'shots', shots: w),
    sender: asSender(who),
  );

  Future<String> said(String who, String g, String uid) =>
      wrapMessage('hi', groupId: g, msgUid: uid, sender: asSender(who));

  Future<void> open() async {
    useDatabasesForTest(live, await Session.withVault(live, vault));
    await app.drainSealed(vault, 'priv-A');
    await app.groupShotsAtOpenForTest(vault);
    await app.ctlPassForTest;
  }

  // the answers a hidden group waits to send, once their time is up
  Future<void> later() async {
    for (var i = 0; i < 20 && app.capsLaterForTest > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await app.ctlPassForTest;
  }

  void shut() => useDatabasesForTest(live, Session(live));

  List<UnwrappedMessage> to(String member) => [
    for (final (_, c) in io.sent)
      if (c.startsWith('to $member '))
        unwrapMessage(c.substring('to $member '.length)),
  ];

  List<UnwrappedMessage> ctls(String member, String type) => [
    for (final m in to(member))
      if (m.groupControl?.type == type) m,
  ];
}

final _later = DateTime.now().millisecondsSinceEpoch + 60000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    groupCapsGap = () => Duration.zero;
    groupShotsEvery = Duration.zero;
  });

  test('a shut vault seals the state and answers nothing; on its opening '
      'the state is taken and its admin hears this app\'s bits', () async {
    final w = await _World.make();
    await w.from(
      _h,
      await w.shots(_h, _g2, GroupShotsWord(on: true, all: false, at: _later)),
    );
    // shut: it waits sealed, and nothing moved or went
    expect(w.store.inbox, hasLength(1));
    expect(GroupShots.ofRow(w.vault.groupRows[_g2]).on, isFalse);
    expect(w.vault.calls.where((c) => c.contains(_g2)), isEmpty);
    expect(w.live.groupRows.containsKey(_g2), isFalse);
    await w.app.ctlPassForTest;
    expect(w.ctls(_h, 'caps'), isEmpty);
    // the everyday update tells the everyday group's admin alone
    await w.app.announceCapsForTest(w.live);
    await w.app.ctlPassForTest;
    expect(w.ctls(_a, 'caps'), hasLength(1));
    expect(w.ctls(_h, 'caps'), isEmpty);
    await w.open();
    final s = GroupShots.ofRow(w.vault.groupRows[_g2]);
    expect(s.on, isTrue);
    expect(s.blocking, isTrue);
    await w.later();
    // one answer, from the vault: for the state and the update alike
    final caps = w.ctls(_h, 'caps');
    expect(caps, hasLength(1));
    expect(caps.single.groupId, _g2);
    expect(caps.single.caps, contains(kCapGroupShots));
    // the everyday side keeps nothing of it
    expect(w.live.rowWrites.where((c) => c.contains(_g2)), isEmpty);
    expect(w.live.groupRows.containsKey(_g2), isFalse);
  });

  test('at the opening nothing goes at once: the answers wait their '
      'turn, one after another', () async {
    final w = await _World.make();
    groupCapsGap = () => const Duration(milliseconds: 150);
    w.vault.group(_g4, ['me', _h], admin: _h);
    await w.store.putHidden(_g4, kHiddenGroup, groupCard(const []), 1);
    await w.open();
    expect(w.ctls(_h, 'caps'), isEmpty);
    expect(w.app.capsLaterForTest, 2);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await w.app.ctlPassForTest;
    expect(w.ctls(_h, 'caps'), hasLength(1));
    expect(w.app.capsLaterForTest, 1);
    // the vault shuts before the next: it waits for the next opening
    w.shut();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await w.app.ctlPassForTest;
    expect(w.ctls(_h, 'caps'), hasLength(1));
    expect(w.app.capsLaterForTest, 0);
  });

  test('an admin already told through an everyday group, or a 1:1 frame, '
      'hears nothing from a hidden group at the opening', () async {
    final w = await _World.make();
    w.live.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    w.live.group('gl', ['me', _h], admin: _h);
    w.live.groupRows['gl']!['shots_told'] = 1;
    await w.open();
    await w.later();
    expect(w.ctls(_h, 'caps'), isEmpty);
    expect(w.app.capsLaterForTest, 0);
    expect(GroupShots.ofRow(w.vault.groupRows[_g2]).told, 1);
  });

  test('a 1:1 frame to the admin counts as told', () async {
    final w = await _World.make();
    await w.app.shotsOnWire(_h, 'halo/1:{"m":"hi","w":5}');
    await w.open();
    await w.later();
    expect(w.ctls(_h, 'caps'), isEmpty);
  });

  test('a group this phone runs in the vault counts again only once it '
      'opens', () async {
    final w = await _World.make();
    await w.open();
    await w.app.setGroupShots(_g3, true);
    await w.app.ctlPassForTest;
    expect(GroupShots.ofRow(w.vault.groupRows[_g3]).waiting, isTrue);
    expect(w.ctls(_h, 'shots').single.groupControl!.shots!.all, isFalse);
    w.shut();
    w.io.sent.clear();
    // their app says it can while the vault is shut: nothing moves
    await w.from(_h, await w.said(_h, _g3, 'm1'));
    expect(GroupShots.ofRow(w.vault.groupRows[_g3]).forAll, isFalse);
    await w.app.ctlPassForTest;
    expect(w.ctls(_h, 'shots'), isEmpty);
    await w.open();
    expect(GroupShots.ofRow(w.vault.groupRows[_g3]).forAll, isTrue);
    expect(w.ctls(_h, 'shots').last.groupControl!.shots!.all, isTrue);
  });

  test(
    'a decoy\'s group is on for everyone at once, and nothing leaves',
    () async {
      final w = await _World.make();
      final decoy = ArrivalRows(HaloContainer.decoy);
      decoy.person(_a, onion: 'o-$_a', xpub: 'x-$_a');
      decoy.group('d1', ['quiet', _a], admin: 'quiet');
      decoy.groupRows['d1']!['is_admin'] = 1;
      await w.app.useDecoyForTest(
        decoy,
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
      w.io.sent.clear();
      await w.app.setGroupShots('d1', true);
      final s = GroupShots.ofRow(decoy.groupRows['d1'], quiet: true);
      expect(s.on, isTrue);
      expect(s.forAll, isTrue);
      expect(
        w.app.groups.singleWhere((g) => g.groupId == 'd1').shotsForAll,
        isTrue,
      );
      // nothing leaves, nothing waits to, and the real side is as it was
      expect(w.io.sent, isEmpty);
      expect(decoy.ctlOut, isEmpty);
      expect(w.live.calls.where((c) => c.contains('d1')), isEmpty);
      // and no update announce runs for it
      await w.app.announceCapsForTest(decoy);
      expect(decoy.ctlOut, isEmpty);
    },
  );
}
