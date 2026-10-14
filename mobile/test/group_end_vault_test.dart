// SPDX-License-Identifier: GPL-3.0-or-later
// a hidden group's end that comes while the hidden chats are shut waits
// sealed: nothing of the group moves, rings or shows until they open, and
// then it ends in their own container. a decoy's own group ends on the
// phone alone, and nothing of the real side reaches it. the databases,
// signal and the engine are stand-ins
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/group_end.dart';
import 'package:kryfo/lock_state.dart' show PinResult, lockState;
import 'package:kryfo/main.dart'
    show AppState, QuietIdentity, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';

import 'arrival_fakes.dart';

const _a = 'admin-of-group';
const _h = 'hidden-wreck-tone'; // the hidden group's admin
const _g = 'grp000000001';
const _g2 = 'g2hidden0001';

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
    await w.store.putHidden(
      _h,
      kHiddenPeer,
      peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
      1,
    );
    await w.store.putHidden(_g2, kHiddenGroup, groupCard(const []), 1);
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

  Future<String> end(String who, String g) => wrapMessage(
    '',
    groupId: g,
    groupControl: const GroupControl(type: 'end'),
    sender: asSender(who),
  );

  Future<String> said(String who, String g, String uid) =>
      wrapMessage('hi', groupId: g, msgUid: uid, sender: asSender(who));

  Future<void> open() async {
    useDatabasesForTest(live, await Session.withVault(live, vault));
    await app.drainSealed(vault, 'priv-A');
  }
}

void main() {
  test('a shut vault holds the end sealed, and its group ends in the vault '
      'on its next opening', () async {
    final w = await _World.make();
    await w.from(_h, await w.said(_h, _g2, 's1'));
    await w.from(_h, await w.end(_h, _g2));
    // shut: both wait sealed, and nothing of the group moved or rang
    expect(w.store.inbox, hasLength(2));
    expect(groupEndOf(w.vault.groupRows[_g2]), isNull);
    expect(w.vault.calls.where((c) => c.contains(_g2)), isEmpty);
    expect(w.live.groupRows.containsKey(_g2), isFalse);
    expect(w.io.unrang, isEmpty);
    expect(w.io.rang, isEmpty);
    await w.open();
    // in its own container: what came before the end went with it
    expect(groupEndOf(w.vault.groupRows[_g2])?.by, _h);
    expect(w.vault.msg('s1'), isNull);
    expect(w.vault.calls, contains('endGroup:$_g2'));
    // the everyday side is untouched
    expect(w.live.calls.where((c) => c.contains(_g2)), isEmpty);
    expect(groupEndOf(w.live.groupRows[_g]), isNull);
    // and what comes after stays out
    await w.from(_h, await w.said(_h, _g2, 's2'));
    expect(w.vault.msg('s2'), isNull);
  });

  test('a hidden group open in its vault ends there at once', () async {
    final w = await _World.make();
    useDatabasesForTest(w.live, await Session.withVault(w.live, w.vault));
    await w.app.drainSealed(w.vault, 'priv-A');
    await w.from(_h, await w.end(_h, _g2));
    expect(groupEndOf(w.vault.groupRows[_g2])?.by, _h);
    expect(groupEndOf(w.live.groupRows[_g]), isNull);
  });

  test('the real side\'s end never reaches the decoy, and a decoy ends its '
      'own group on the phone alone', () async {
    final w = await _World.make();
    final decoy = ArrivalRows(HaloContainer.decoy);
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
    await w.from(_a, await w.end(_a, _g));
    expect(groupEndOf(w.live.groupRows[_g])?.by, _a);
    expect(decoy.calls.where((c) => c.startsWith('endGroup')), isEmpty);
    w.app.revealGap = Duration.zero;
    addTearDown(() => lockState.inDecoy = false);
    await w.app.sessionFor(PinResult.decoy);
    w.io.sent.clear();
    expect(await w.app.endGroupAndAnnounce('d1'), isTrue);
    expect(groupEndOf(decoy.groupRows['d1'])?.by, 'quiet');
    // nothing leaves, nothing waits to, and the real side is as it was
    expect(w.io.sent, isEmpty);
    expect(decoy.ctlOut, isEmpty);
    expect(w.live.calls.where((c) => c.contains('d1')), isEmpty);
  });
}
